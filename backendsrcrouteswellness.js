import express from 'express';
import { query } from '../database/connection.js';
import { authenticateToken } from '../utils/auth.js';
import logger from '../utils/logger.js';

const router = express.Router();
router.use(authenticateToken);

// Create wellness check-in
router.post('/', async (req, res) => {
  try {
    const {
      patientId,
      energy,
      fatigue,
      pain,
      mood,
      sleepQuality,
      breathing,
      mobility,
      balance,
      speechClarity,
      appetite,
      hydration,
      swallowingDifficulty,
      weight,
      notes
    } = req.body;

    const result = await query(
      `INSERT INTO wellness_checkins (
        patient_id, date, energy, fatigue, pain, mood, sleep_quality,
        breathing, mobility, balance, speech_clarity, appetite, 
        hydration, swallowing_difficulty, weight, notes
      ) VALUES ($1, CURRENT_DATE, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
      RETURNING *`,
      [
        patientId, energy, fatigue, pain, mood, sleepQuality, breathing,
        mobility, balance, speechClarity, appetite, hydration,
        swallowingDifficulty, weight, notes
      ]
    );

    // Update wellness score (simple calculation for MVP)
    const avgScore = Math.round(
      ((energy + (11 - fatigue) + (11 - pain) + mood + sleepQuality + 
        breathing + mobility + balance + speechClarity + appetite + 
        hydration + (11 - swallowingDifficulty)) / 12) * 10
    );

    await query(
      'UPDATE patients SET wellness_score = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2',
      [avgScore, patientId]
    );

    res.status(201).json({ checkin: result.rows[0], wellnessScore: avgScore });
  } catch (error) {
    logger.error('Create wellness check-in error:', error);
    res.status(500).json({ error: 'Failed to create check-in' });
  }
});

// Get wellness history for patient
router.get('/:patientId', async (req, res) => {
  try {
    const { patientId } = req.params;
    const { days = 30 } = req.query;

    const result = await query(
      `SELECT * FROM wellness_checkins 
       WHERE patient_id = $1 
       AND date >= CURRENT_DATE - INTERVAL '${parseInt(days)} days'
       ORDER BY date DESC`,
      [patientId]
    );

    res.json({ checkins: result.rows });
  } catch (error) {
    logger.error('Get wellness history error:', error);
    res.status(500).json({ error: 'Failed to retrieve wellness history' });
  }
});

// Get today's check-in
router.get('/:patientId/today', async (req, res) => {
  try {
    const { patientId } = req.params;

    const result = await query(
      `SELECT * FROM wellness_checkins 
       WHERE patient_id = $1 AND date = CURRENT_DATE`,
      [patientId]
    );

    if (result.rows.length === 0) {
      return res.json({ checkin: null, completed: false });
    }

    res.json({ checkin: result.rows[0], completed: true });
  } catch (error) {
    logger.error('Get today check-in error:', error);
    res.status(500).json({ error: 'Failed to retrieve check-in' });
  }
});

export default router;
