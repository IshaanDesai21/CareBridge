import express from 'express';
import { getDb } from '../database/db.js';
import { authenticateToken } from '../utils/auth.js';
import logger from '../utils/logger.js';

const router = express.Router();
router.use(authenticateToken);

const NVIDIA_KEY = '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';
const NVIDIA_URL = 'https://integrate.api.nvidia.com/v1';

// Model for companion chat — fast conversational responses
const CHAT_MODEL = 'deepseek-ai/deepseek-v4-flash';
// Model for clinical summaries / handoff overviews
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
    top_p: 0.95,
    max_tokens: maxTokens,
    stream: false
  };
  if (model === CHAT_MODEL) {
    body.extra_body = { chat_template_kwargs: { thinking: true, reasoning_effort: 'high' } };
  }
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
  // Extract reasoning if present, then return content
  const content = msg.content || '';
  return stripThinkTags(content);
}

// ─── Patient AI Overview ──────────────────────────────────────────────────────
// Collects all patient data and generates a clinical handoff overview paragraph.
router.get('/overview/:patientId', async (req, res) => {
  try {
    const { patientId } = req.params;
    const db = getDb();

    const patient = db.prepare(`
      SELECT p.*, u.first_name, u.last_name, u.email
      FROM patients p JOIN users u ON p.user_id = u.id
      WHERE p.id = ?
    `).get(patientId);
    if (!patient) return res.status(404).json({ error: 'Patient not found' });

    const checkins = db.prepare(`
      SELECT * FROM wellness_checkins WHERE patient_id = ?
      ORDER BY created_at DESC LIMIT 7
    `).all(patientId);

    const meds = db.prepare(`
      SELECT name, dosage, frequency FROM medications
      WHERE patient_id = ? AND is_active = 1
    `).all(patientId);

    const notes = db.prepare(`
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
    db.prepare(`
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
router.get('/insights/:patientId', (req, res) => {
  try {
    const db = getDb();
    const insights = db.prepare(`
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

// ─── AI companion chat ────────────────────────────────────────────────────────
router.post('/chat', async (req, res) => {
  try {
    const { message, patientGender } = req.body;
    const db = getDb();

    // Pull companion info from patient record
    const patientRecord = db.prepare(`
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

    let reply;
    if (NVIDIA_KEY && message) {
      // Pass a short history for context (last 10 turns), system prompt injected by callAI
      const history = Array.isArray(req.body.history) ? req.body.history.slice(-10) : [];
      const userTurn = { role: 'user', content: message };
      reply = await callAI(systemPrompt, [...history, userTurn], 512, CHAT_MODEL);
    } else {
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
    res.json({ message: reply, companionName, timestamp: new Date().toISOString() });
  } catch (error) {
    logger.error('AI chat error:', error.message);
    res.status(500).json({ error: 'Failed to process chat message' });
  }
});

// ─── Wellness summary ─────────────────────────────────────────────────────────
router.get('/summary/:patientId', async (req, res) => {
  try {
    const { patientId } = req.params;
    const db = getDb();
    const wellnessData = db.prepare(`
      SELECT * FROM wellness_checkins
      WHERE patient_id = ? AND date >= date('now', '-7 days')
      ORDER BY date DESC
    `).all(patientId);

    const medData = db.prepare(`
      SELECT COUNT(*) as total,
             SUM(CASE WHEN status = 'taken' THEN 1 ELSE 0 END) as taken
      FROM medication_logs ml
      JOIN medications m ON ml.medication_id = m.id
      WHERE m.patient_id = ? AND ml.scheduled_time >= datetime('now', '-7 days')
    `).get(patientId);

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
