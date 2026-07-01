import express from 'express';
import { getDb } from '../database/db.js';
import { authenticateToken } from '../utils/auth.js';
import logger from '../utils/logger.js';

const router = express.Router();
router.use(authenticateToken);

// Get AI insights
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

// AI companion chat (mock — swap in a real LLM later)
router.post('/chat', (req, res) => {
  try {
    const responses = [
      "I'm here to help! How are you feeling today?",
      "That's great to hear. Remember to stay hydrated and take your medications on time.",
      "I understand. If you're experiencing any concerning symptoms, please contact your caregiver.",
      "Your wellness journey is important. Would you like to complete today's check-in?",
      "I'm glad you're taking care of yourself. Keep up the great work!"
    ];
    res.json({
      message: responses[Math.floor(Math.random() * responses.length)],
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    logger.error('AI chat error:', error);
    res.status(500).json({ error: 'Failed to process chat message' });
  }
});

// Generate wellness summary
router.get('/summary/:patientId', (req, res) => {
  try {
    const { patientId } = req.params;
    const db = getDb();

    const wellnessData = db.prepare(`
      SELECT * FROM wellness_checkins
      WHERE patient_id = ? AND date >= date('now', '-7 days')
      ORDER BY date DESC
    `).all(patientId);

    const medicationData = db.prepare(`
      SELECT COUNT(*) as total,
             SUM(CASE WHEN status = 'taken' THEN 1 ELSE 0 END) as taken
      FROM medication_logs ml
      JOIN medications m ON ml.medication_id = m.id
      WHERE m.patient_id = ?
        AND ml.scheduled_time >= datetime('now', '-7 days')
    `).get(patientId);

    const total = medicationData?.total ?? 0;
    const taken = medicationData?.taken ?? 0;
    const adherenceRate = total > 0 ? Math.round((taken / total) * 100) : 100;

    const summary = {
      period: '7 days',
      checkinsCompleted: wellnessData.length,
      medicationAdherence: adherenceRate,
      trends: [],
      recommendations: [
        'Continue completing daily wellness check-ins',
        'Maintain consistent medication schedule',
        'Stay hydrated and get adequate rest'
      ]
    };

    if (wellnessData.length >= 2) {
      const [recent, previous] = wellnessData;
      if (recent.energy < previous.energy - 2)
        summary.trends.push({ type: 'energy', direction: 'declining', severity: 'medium' });
      if (recent.pain > previous.pain + 2)
        summary.trends.push({ type: 'pain', direction: 'increasing', severity: 'medium' });
      if (recent.mood < previous.mood - 2)
        summary.trends.push({ type: 'mood', direction: 'declining', severity: 'low' });
    }

    res.json({ summary });
  } catch (error) {
    logger.error('Generate summary error:', error);
    res.status(500).json({ error: 'Failed to generate summary' });
  }
});

export default router;
