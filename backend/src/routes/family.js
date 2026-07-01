import express from 'express';
import { getDb } from '../database/db.js';
import { authenticateToken } from '../utils/auth.js';
import logger from '../utils/logger.js';

const router = express.Router();
router.use(authenticateToken);

// Get linked patient for the current family user
router.get('/patient', (req, res) => {
  try {
    const db = getDb();
    const patient = db.prepare(`
      SELECT p.*, u.email, u.first_name, u.last_name
      FROM family_patient_links fpl
      JOIN patients p ON fpl.patient_id = p.id
      JOIN users u ON p.user_id = u.id
      WHERE fpl.family_user_id = ?
      LIMIT 1
    `).get(req.user.id);

    res.json({ patient: patient || null, linked: !!patient });
  } catch (error) {
    logger.error('Get family patient error:', error);
    res.status(500).json({ error: 'Failed to get linked patient' });
  }
});

// Link family user to patient via join code
router.post('/link', (req, res) => {
  try {
    const { code } = req.body;
    if (!code) return res.status(400).json({ error: 'Join code required' });

    const db = getDb();
    const record = db.prepare('SELECT * FROM join_codes WHERE code = ?').get(code.toUpperCase().trim());
    if (!record) return res.status(404).json({ error: 'Invalid join code' });

    const existing = db.prepare(
      'SELECT id FROM family_patient_links WHERE family_user_id = ? AND patient_id = ?'
    ).get(req.user.id, record.patient_id);

    if (existing) return res.status(400).json({ error: 'Already linked to this patient' });

    db.prepare(
      'INSERT INTO family_patient_links (family_user_id, patient_id) VALUES (?, ?)'
    ).run(req.user.id, record.patient_id);

    const patient = db.prepare(`
      SELECT p.*, u.email, u.first_name, u.last_name
      FROM patients p JOIN users u ON p.user_id = u.id
      WHERE p.id = ?
    `).get(record.patient_id);

    res.json({ success: true, patient });
  } catch (error) {
    logger.error('Family link error:', error);
    res.status(500).json({ error: 'Failed to link to patient' });
  }
});

export default router;
