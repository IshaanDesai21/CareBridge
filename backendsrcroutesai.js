import express from 'express';
import { query } from '../database/connection.js';
import { authenticateToken } from '../utils/auth.js';
import logger from '../utils/logger.js';

const router = express.Router();
router.use(authenticateToken);

// Get AI insights for patient
router.get('/insights/:patientId', async (req, res) => {
  try {
    const { patientId } = req.params;

    const result = await query(
      `SELECT * FROM ai_insights 
       WHERE patient_id = $1 
       ORDER BY created_at DESC
       LIMIT 20`,
      [patientId]
    );

    res.json({ insights: result.rows });
  } catch (error) {
    logger.error('Get AI insights error:', error);
    res.status(500).json({ error: 'Failed to retrieve insights' });
  }
});

// AI companion chat (simple mock for MVP)
router.post('/chat', async (req, res) => {
  try {
    const { patientId, message } = req.body;

    // This is a mock response - in production, integrate with OpenAI or similar
    const responses = [
      "I'm here to help! How are you feeling today?",
      "That's great to hear. Remember to stay hydrated and take your medications on time.",
      "I understand. If you're experiencing any concerning symptoms, please contact your caregiver.",
      "Your wellness journey is important. Would you like to complete today's check-in?",
      "I'm glad you're taking care of yourself. Keep up the great work!"
    ];

    const response = responses[Math.floor(Math.random() * responses.length)];

    res.json({ 
      message: response,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    logger.error('AI chat error:', error);
    res.status(500).json({ error: 'Failed to process chat message' });
  }
});

// Generate wellness summary
router.get('/summary/:patientId', async (req, res) => {
  try {
    const { patientId } = req.params;

    // Get recent wellness data
    const wellnessData = await query(
      `SELECT * FROM wellness_checkins 
       WHERE patient_id = $1 
       AND date >= CURRENT_DATE - INTERVAL '7 days'
       ORDER BY date DESC`,
      [patientId]
    );

    // Get medication adherence
    const medicationData = await query(
      `SELECT COUNT(*) as total, 
              SUM(CASE WHEN status = 'taken' THEN 1 ELSE 0 END) as taken
       FROM medication_logs ml
       JOIN medications m ON ml.medication_id = m.id
       WHERE m.patient_id = $1 
       AND ml.scheduled_time >= CURRENT_TIMESTAMP - INTERVAL '7 days'`,
      [patientId]
    );

    const adherenceRate = medicationData.rows[0].total > 0 
      ? Math.round((medicationData.rows[0].taken / medicationData.rows[0].total) * 100)
      : 100;

    // Simple summary generation
    const summary = {
      period: '7 days',
      checkinsCompleted: wellnessData.rows.length,
      medicationAdherence: adherenceRate,
      trends: [],
      recommendations: [
        'Continue completing daily wellness check-ins',
        'Maintain consistent medication schedule',
        'Stay hydrated and get adequate rest'
      ]
    };

    // Analyze trends (simplified for MVP)
    if (wellnessData.rows.length >= 2) {
      const recent = wellnessData.rows[0];
      const previous = wellnessData.rows[1];

      if (recent.energy < previous.energy - 2) {
        summary.trends.push({ type: 'energy', direction: 'declining', severity: 'medium' });
      }
      if (recent.pain > previous.pain + 2) {
        summary.trends.push({ type: 'pain', direction: 'increasing', severity: 'medium' });
      }
      if (recent.mood < previous.mood - 2) {
        summary.trends.push({ type: 'mood', direction: 'declining', severity: 'low' });
      }
    }

    res.json({ summary });
  } catch (error) {
    logger.error('Generate summary error:', error);
    res.status(500).json({ error: 'Failed to generate summary' });
  }
});

export default router;
