import express from 'express';
import { pool } from '../db.js';

const router = express.Router();

// Create wellness check-in
router.post('/', async (req, res) => {
  try {
    const { patientId, energy, mood, pain, notes } = req.body;

    const result = await pool.query(
      `INSERT INTO wellness_checkins (patient_id, date, energy, mood, pain, notes)
       VALUES ($1, CURRENT_DATE, $2, $3, $4, $5)
       RETURNING *`,
      [patientId, energy, mood, pain, notes]
    );

    // Calculate wellness score (simplified)
    const score = Math.round(((energy + mood + (11 - pain)) / 3) * 10);
    
    await pool.query(
      'UPDATE patients SET wellness_score = $1 WHERE id = $2',
      [score, patientId]
    );

    res.status(201).json({ checkin: result.rows[0], wellnessScore: score });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get wellness history
router.get('/:patientId', async (req, res) => {
  try {
    const { patientId } = req.params;

    const result = await pool.query(
      `SELECT * FROM wellness_checkins 
       WHERE patient_id = $1 
       ORDER BY date DESC
       LIMIT 30`,
      [patientId]
    );

    res.json({ checkins: result.rows });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

export default router;
