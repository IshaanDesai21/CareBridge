import express from 'express';
import { getDb } from '../database/db.js';
import { authenticateToken } from '../utils/auth.js';
import logger from '../utils/logger.js';

const router = express.Router();
router.use(authenticateToken);

const NVIDIA_KEY = process.env.NVIDIA_API_KEY;
const NVIDIA_URL = process.env.NVIDIA_BASE_URL || 'https://integrate.api.nvidia.com/v1';

// Single NVIDIA-hosted model used for both companion chat and clinical
// summaries/handoffs. gpt-oss-20b returns its chain-of-thought in a separate
// `reasoning_content` field and the final answer in `content`.
const CHAT_MODEL = 'openai/gpt-oss-20b';
const SUMMARY_MODEL = 'openai/gpt-oss-20b';

function stripThinkTags(text) {
  if (!text) return text;
  return text.replace(/<think>[\s\S]*?<\/think>/gi, '').trim();
}

async function callAI(systemPrompt, messages, maxTokens = 1024, model = CHAT_MODEL) {
  const body = {
    model,
    messages: [
      { role: 'system', content: systemPrompt },
      ...(Array.isArray(messages) ? messages : [{ role: 'user', content: messages }])
    ],
    temperature: 1,
    top_p: 1,
    // gpt-oss-20b spends part of the token budget on hidden reasoning before the
    // final answer, so give it real headroom or replies come back empty/truncated.
    max_tokens: Math.max(maxTokens, 1024),
    stream: false
  };
  const res = await fetch(`${NVIDIA_URL}/chat/completions`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${NVIDIA_KEY}` },
    body: JSON.stringify(body)
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`AI API error ${res.status}: ${err}`);
  }
  const data = await res.json();
  const msg = data.choices[0].message;
  // The real answer is in `content`; `reasoning_content` holds the hidden
  // chain-of-thought which we deliberately drop. Also strip any <think> tags.
  return stripThinkTags(msg.content || '');
}

// ─── Patient AI Overview ──────────────────────────────────────────────────────
// Collects all patient data and generates a clinical handoff overview paragraph.
router.get('/overview/:patientId', async (req, res) => {
  try {
    if (!NVIDIA_KEY) {
      return res.status(503).json({
        error: 'AI is not configured on the server. Set NVIDIA_API_KEY in backend/.env and restart.'
      });
    }
    const { patientId } = req.params;
    const db = getDb();

    const patient = await db.prepare(`
      SELECT p.*, u.first_name, u.last_name, u.email
      FROM patients p JOIN users u ON p.user_id = u.id
      WHERE p.id = ?
    `).get(patientId);
    if (!patient) return res.status(404).json({ error: 'Patient not found' });

    const checkins = await db.prepare(`
      SELECT * FROM wellness_checkins WHERE patient_id = ?
      ORDER BY created_at DESC LIMIT 7
    `).all(patientId);

    const meds = await db.prepare(`
      SELECT name, dosage, frequency FROM medications
      WHERE patient_id = ? AND is_active = 1
    `).all(patientId);

    const notes = await db.prepare(`
      SELECT cn.*, u.first_name || ' ' || u.last_name AS caregiver_name
      FROM care_notes cn
      LEFT JOIN users u ON cn.caregiver_id = u.id
      WHERE cn.patient_id = ?
      ORDER BY cn.created_at DESC LIMIT 10
    `).all(patientId);

    const diagnoses = JSON.parse(patient.diagnoses || '[]');
    const allergies = JSON.parse(patient.allergies || '[]');

    const systemPrompt = `You are a clinical documentation assistant for CareBridge, a healthcare coordination platform.
Write concise, professional clinical handoff summaries that caregivers actually use.
Use plain language. Highlight trends, risks, and what the incoming caregiver needs to know immediately.
Output only the summary text — no headers, no bullet points, no preamble.`;

    const userPrompt = `Generate a brief clinical handoff overview for ${patient.first_name} ${patient.last_name}.

Diagnoses: ${diagnoses.join(', ') || 'Not specified'}
Allergies: ${allergies.join(', ') || 'NKDA'}
Current Wellness Score: ${patient.wellness_score}/100

Active Medications:
${meds.length ? meds.map(m => `  - ${m.name} ${m.dosage} (${m.frequency})`).join('\n') : '  None recorded'}

Recent Wellness Check-ins (newest first):
${checkins.length ? checkins.map(c =>
  `  [${c.created_at?.split('T')[0] || 'recent'}] Energy: ${c.energy ?? '—'}, Mood: ${c.mood ?? '—'}, Pain: ${c.pain ?? '—'}, Notes: ${c.notes || 'None'}`
).join('\n') : '  No recent check-ins'}

Recent Care Team Notes:
${notes.length ? notes.map(n =>
  `  [${n.caregiver_name || 'Caregiver'}] (${n.note_type}): ${n.content}`
).join('\n') : '  No notes recorded'}

Write a 3-4 sentence handoff summary covering: current status, key concerns, and one specific recommendation for the next shift.`;

    const overview = await callAI(systemPrompt, userPrompt, 1024, SUMMARY_MODEL);

    // Cache as an AI insight so it shows in the insights tab too
    await db.prepare(`
      INSERT INTO ai_insights (patient_id, insight_type, title, description, severity)
      VALUES (?, 'summary', 'AI Handoff Overview', ?, 'low')
    `).run(patientId, overview);

    res.json({ overview });
  } catch (error) {
    logger.error('AI overview error:', error.message);
    res.status(500).json({ error: error.message || 'Failed to generate overview' });
  }
});

// ─── Get AI insights ──────────────────────────────────────────────────────────
router.get('/insights/:patientId', async (req, res) => {
  try {
    const db = getDb();
    const insights = await db.prepare(`
      SELECT * FROM ai_insights
      WHERE patient_id = ?
      ORDER BY created_at DESC
      LIMIT 20
    `).all(req.params.patientId);
    res.json({ insights });
  } catch (error) {
    logger.error('Get AI insights error:', error);
    res.status(500).json({ error: 'Failed to retrieve insights' });
  }
});

// ─── Chat history ──────────────────────────────────────────────────────────────
// GET /api/ai/chat/history — the last N turns for the current user, oldest first
router.get('/chat/history', async (req, res) => {
  try {
    const db = getDb();
    const limit = Math.min(parseInt(req.query.limit, 10) || 50, 200);
    const rows = await db.prepare(`
      SELECT id, role, content, created_at FROM chat_messages
      WHERE user_id = ? ORDER BY created_at DESC LIMIT ?
    `).all(req.user.id, limit);
    res.json({ messages: rows.reverse() });
  } catch (error) {
    logger.error('Get chat history error:', error);
    res.status(500).json({ error: 'Failed to retrieve chat history' });
  }
});

// ─── AI companion chat ────────────────────────────────────────────────────────
router.post('/chat', async (req, res) => {
  try {
    const { message, patientGender } = req.body;
    const db = getDb();

    if (message) {
      await db.prepare(`INSERT INTO chat_messages (user_id, role, content) VALUES (?, 'user', ?)`)
        .run(req.user.id, message);
    }

    // Pull companion info from patient record
    const patientRecord = await db.prepare(`
      SELECT p.ai_companion_name, p.ai_companion_gender, p.gender, u.first_name
      FROM patients p JOIN users u ON p.user_id = u.id
      WHERE p.user_id = ?
    `).get(req.user.id);

    const companionName = patientRecord?.ai_companion_name || 'Alex';
    const companionGender = patientRecord?.ai_companion_gender || 'neutral';
    const patientFirst = patientRecord?.first_name || 'there';
    const userGender = patientGender || patientRecord?.gender || 'unknown';

    const genderPronoun = userGender === 'male' ? 'him' : userGender === 'female' ? 'her' : 'them';
    const companionPronoun = companionGender === 'male' ? 'he/him' : companionGender === 'female' ? 'she/her' : 'they/them';

    const systemPrompt = `You are ${companionName}, a warm and caring AI companion for ${patientFirst} through the CareBridge app. 
Your pronouns are ${companionPronoun}.
${patientFirst}'s pronouns are ${genderPronoun === 'him' ? 'he/him' : genderPronoun === 'her' ? 'she/her' : 'they/them'}.

Your personality:
- Genuinely warm, upbeat, and caring — like a trusted friend who always has time to listen
- Curious about ${patientFirst}'s day, feelings, interests, memories, and stories
- Witty but never sarcastic, always encouraging
- You remember you're talking to an older adult — be clear, patient, and never condescending

Topics you love talking about:
- How their day is going, what made them smile today
- Their hobbies, favourite memories, family, food they enjoy
- Light current events, nature, music, TV shows they like
- You can also help with health questions if they bring it up, but you don't push it

Rules:
- Keep responses SHORT — 1 to 3 sentences max, conversational
- Never diagnose or replace medical advice
- If someone seems very distressed or mentions self-harm, gently encourage them to call their caregiver or a helpline
- Never say you are "just an AI" — be present and real in your responses
- Sign off naturally, never robotically`;

    let reply = null;
    if (NVIDIA_KEY && message) {
      // Prefer the server's own memory of this conversation (chat_messages) over
      // whatever the client sends, so the companion remembers across app launches.
      // Exclude the user turn we just inserted — it's appended explicitly below.
      const storedHistory = (await db.prepare(`
        SELECT role, content FROM chat_messages
        WHERE user_id = ? ORDER BY created_at DESC LIMIT 21
      `).all(req.user.id)).reverse();
      // The user turn we just inserted is the last row — drop it, it's re-added explicitly below
      const history = storedHistory.slice(0, -1);
      const userTurn = { role: 'user', content: message };
      try {
        reply = await callAI(systemPrompt, [...history, userTurn], 2048, CHAT_MODEL);
      } catch (err) {
        // Upstream AI failure shouldn't kill the conversation — fall through to
        // the canned companion lines below.
        logger.error('AI chat upstream error:', err.message);
      }
    }
    if (!reply) {
      // Warm fallbacks in the companion's voice
      const fallbacks = [
        `It's so good to hear from you, ${patientFirst}! What's been on your mind today?`,
        `I was just thinking about you! How are you feeling right now?`,
        `That's really interesting — tell me more!`,
        `I love that. You always have the best stories.`,
        `How's your day been going? I hope there was at least one good moment in it.`,
        `I'm here and I'm listening. What's going on?`
      ];
      reply = fallbacks[Math.floor(Math.random() * fallbacks.length)];
    }

    await db.prepare(`INSERT INTO chat_messages (user_id, role, content) VALUES (?, 'assistant', ?)`)
      .run(req.user.id, reply);

    res.json({ message: reply, companionName, timestamp: new Date().toISOString() });
  } catch (error) {
    logger.error('AI chat error:', error.message);
    res.status(500).json({ error: 'Failed to process chat message' });
  }
});

// ─── Medication label parsing (scan-to-add) ────────────────────────────────────
// Takes raw OCR text lifted off a medication label/bottle by the on-device
// scanner and asks the model to extract structured fields. Returns null for
// name if the text doesn't look like a medication label at all.
router.post('/parse-medication', async (req, res) => {
  try {
    const { text } = req.body;
    if (!text || !text.trim()) {
      return res.status(400).json({ error: 'No scanned text provided' });
    }

    const fallbackParse = () => {
      const lines = text.split('\n').map(l => l.trim()).filter(Boolean);
      return { name: lines[0] || null, dosage: null, frequency: null, instructions: null, confidence: 'low' };
    };

    if (!NVIDIA_KEY) {
      return res.json({ medication: fallbackParse() });
    }

    const systemPrompt = `You are a pharmacy label parser. You are given raw, possibly noisy OCR text lifted from a
prescription medication bottle or box label. Extract structured fields. Respond with ONLY a single JSON object,
no markdown fences, no commentary, matching exactly this shape:
{"name": string|null, "dosage": string|null, "frequency": string|null, "instructions": string|null, "isMedication": boolean}

Rules:
- "name": the drug name, capitalized normally (e.g. "Lisinopril"). Strip dosage/manufacturer noise.
- "dosage": strength like "10mg" or "500 mg". Null if not present.
- "frequency": how often it's taken, in plain English (e.g. "Once daily", "Twice a day with food"). Null if not present.
- "instructions": any other directions on the label (e.g. "Take with food", "Do not drink alcohol"). Null if none.
- "isMedication": false if this text clearly isn't a medication label (e.g. random object, no drug name found).
- Never invent information that isn't implied by the text.`;

    // gpt-oss-20b reasons before answering and can burn the whole token budget on
    // reasoning alone for a JSON-extraction task like this — give it enough headroom.
    const raw = await callAI(systemPrompt, `OCR text:\n${text}`, 900, SUMMARY_MODEL);

    let parsed;
    try {
      const cleaned = raw.replace(/```json|```/g, '').trim();
      parsed = JSON.parse(cleaned);
    } catch {
      logger.error('parse-medication: model did not return valid JSON:', raw);
      return res.json({ medication: fallbackParse() });
    }

    if (!parsed.isMedication || !parsed.name) {
      return res.json({ medication: { name: null, dosage: null, frequency: null, instructions: null, confidence: 'none' } });
    }

    res.json({
      medication: {
        name: parsed.name,
        dosage: parsed.dosage ?? null,
        frequency: parsed.frequency ?? null,
        instructions: parsed.instructions ?? null,
        confidence: 'high'
      }
    });
  } catch (error) {
    logger.error('Parse medication error:', error.message);
    res.status(500).json({ error: 'Failed to parse medication label' });
  }
});

// ─── Wellness summary ─────────────────────────────────────────────────────────
router.get('/summary/:patientId', async (req, res) => {
  try {
    const { patientId } = req.params;
    const db = getDb();
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
    const cutoffDate = sevenDaysAgo.toISOString().split('T')[0];
    const wellnessData = await db.prepare(`
      SELECT * FROM wellness_checkins
      WHERE patient_id = ? AND date >= ?
      ORDER BY date DESC
    `).all(patientId, cutoffDate);

    const medData = await db.prepare(`
      SELECT COUNT(*) as total,
             SUM(CASE WHEN status = 'taken' THEN 1 ELSE 0 END) as taken
      FROM medication_logs ml
      JOIN medications m ON ml.medication_id = m.id
      WHERE m.patient_id = ? AND ml.scheduled_time >= ?
    `).get(patientId, sevenDaysAgo.toISOString());

    const total = medData?.total ?? 0;
    const taken = medData?.taken ?? 0;
    const adherenceRate = total > 0 ? Math.round((taken / total) * 100) : 100;

    const trends = [];
    if (wellnessData.length >= 2) {
      const [recent, previous] = wellnessData;
      if (recent.energy < previous.energy - 2) trends.push({ type: 'energy', direction: 'declining', severity: 'medium' });
      if (recent.pain > previous.pain + 2) trends.push({ type: 'pain', direction: 'increasing', severity: 'high' });
      if (recent.mood < previous.mood - 2) trends.push({ type: 'mood', direction: 'declining', severity: 'low' });
    }

    res.json({
      summary: {
        period: '7 days',
        checkinsCompleted: wellnessData.length,
        medicationAdherence: adherenceRate,
        trends,
        recommendations: [
          'Continue completing daily wellness check-ins',
          'Maintain consistent medication schedule',
          'Stay hydrated and get adequate rest'
        ]
      }
    });
  } catch (error) {
    logger.error('Generate summary error:', error);
    res.status(500).json({ error: 'Failed to generate summary' });
  }
});

export default router;
