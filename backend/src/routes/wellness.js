import express from 'express';
import { getDb } from '../database/db.js';
import { authenticateToken } from '../utils/auth.js';
import logger from '../utils/logger.js';

const router = express.Router();
router.use(authenticateToken);

// Create wellness check-in
router.post('/', async (req, res) => {
  try {
    const {
      patientId,
      energy = 5, fatigue = 5, pain = 5, mood = 5,
      sleepQuality = 5, breathing = 5, mobility = 5, balance = 5,
      speechClarity = 5, appetite = 5, hydration = 5,
      swallowingDifficulty = 5, weight, notes
    } = req.body;

    const db = getDb();
    const today = new Date().toISOString().split('T')[0];

    const result = await db.prepare(`
      INSERT INTO wellness_checkins (
        patient_id, date, energy, fatigue, pain, mood, sleep_quality,
        breathing, mobility, balance, speech_clarity, appetite,
        hydration, swallowing_difficulty, weight, notes
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      patientId, today, energy, fatigue, pain, mood, sleepQuality,
      breathing, mobility, balance, speechClarity, appetite,
      hydration, swallowingDifficulty, weight ?? null, notes ?? null
    );

    // Wellness score: higher is better, pain/fatigue/swallowing are inverted
    const avgScore = Math.round(
      ((energy + (11 - fatigue) + (11 - pain) + mood + sleepQuality +
        breathing + mobility + balance + speechClarity + appetite +
        hydration + (11 - swallowingDifficulty)) / 12) * 10
    );

    await db.prepare('UPDATE patients SET wellness_score = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
      .run(avgScore, patientId);

    const checkin = await db.prepare('SELECT * FROM wellness_checkins WHERE id = ?').get(result.lastInsertRowid);
    res.status(201).json({ checkin, wellnessScore: avgScore });
  } catch (error) {
    logger.error('Create wellness check-in error:', error);
    res.status(500).json({ error: 'Failed to create check-in' });
  }
});

// Get wellness history for patient
router.get('/:patientId', async (req, res) => {
  try {
    const days = parseInt(req.query.days) || 30;
    const db = getDb();
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - days);
    const cutoffDate = cutoff.toISOString().split('T')[0];

    const checkins = await db.prepare(`
      SELECT * FROM wellness_checkins
      WHERE patient_id = ?
        AND date >= ?
      ORDER BY date DESC
    `).all(req.params.patientId, cutoffDate);

    res.json({ checkins });
  } catch (error) {
    logger.error('Get wellness history error:', error);
    res.status(500).json({ error: 'Failed to retrieve wellness history' });
  }
});

// Get today's check-in
router.get('/:patientId/today', async (req, res) => {
  try {
    const db = getDb();
    const today = new Date().toISOString().split('T')[0];
    const checkin = await db.prepare(`
      SELECT * FROM wellness_checkins
      WHERE patient_id = ? AND date = ?
    `).get(req.params.patientId, today);

    res.json({ checkin: checkin ?? null, completed: !!checkin });
  } catch (error) {
    logger.error('Get today check-in error:', error);
    res.status(500).json({ error: 'Failed to retrieve check-in' });
  }
});

export default router;
