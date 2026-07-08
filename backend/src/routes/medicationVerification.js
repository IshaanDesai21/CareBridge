import express from 'express';
import { getDb } from '../database/db.js';
import { authenticateToken } from '../utils/auth.js';
import logger from '../utils/logger.js';

const router = express.Router();
router.use(authenticateToken);

router.post('/verify/:medicationId', async (req, res) => {
  try {
    const { medicationId } = req.params;
    const { pills } = req.body;

    if (!pills || !Array.isArray(pills) || pills.length === 0) {
      return res.status(400).json({ error: 'pills is required and must be a non-empty array' });
    }

    const db = getDb();

    const medication = await db.prepare('SELECT * FROM medications WHERE id = ?').get(medicationId);
    if (!medication) {
      return res.status(404).json({ error: 'Medication not found' });
    }

    const expectedName = medication.name.toLowerCase();
    const detectedNames = pills.map(p => p.name.toLowerCase());
    const allMatch = detectedNames.every(name => name === expectedName);

    const verification = {
      medicationId,
      status: allMatch ? 'match' : 'mismatch',
      expected: medication.name,
      detected: pills,
      timestamp: new Date().toISOString(),
    };

    await db.prepare(
      'INSERT INTO verification_logs (medication_id, status, expected_name, detected_pills, verified_by) VALUES (?, ?, ?, ?, ?)'
    ).run(medicationId, verification.status, medication.name, JSON.stringify(pills), req.user.id);

    res.json({ verification });
  } catch (error) {
    logger.error('Verification error:', error);
    res.status(500).json({ error: 'Verification failed' });
  }
});

export default router;
