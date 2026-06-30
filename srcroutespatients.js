import express from 'express';
import { pool } from '../db.js';

const router = express.Router();

// Get all patients
router.get('/', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT p.*, u.email, u.first_name, u.last_name 
       FROM patients p
       JOIN users u ON p.user_id = u.id
       ORDER BY p.wellness_score ASC`
    );
    res.json({ patients: result.rows });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

export default router;
