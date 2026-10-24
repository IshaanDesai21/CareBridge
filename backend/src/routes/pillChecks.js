import express from 'express';
import { getDb } from '../database/db.js';
import { authenticateToken } from '../utils/auth.js';
import logger from '../utils/logger.js';
import catalog from '../data/pillCatalog.json' with { type: 'json' };
import { evaluatePillCheck } from '../services/doseRules.js';
import {
  todayTotals, persistEvaluation, stripBoxes, validateDetections, guardDoseRequest, guardPatient,
} from '../services/doseStore.js';

const router = express.Router();
router.use(authenticateToken);

router.post('/', async (req, res) => {
  try {
    const { patientId, localDate, detections } = req.body ?? {};
    const db = getDb();
    let err = await guardDoseRequest(db, req.user, { patientId, localDate });
    if (!err) {
      const detErr = validateDetections(detections);
      if (detErr) err = { status: 400, error: detErr };
    }
    if (!err) err = await guardPatient(db, req.user, patientId);
    if (err) return res.status(err.status).json({ error: err.error });

    const medications = await db.prepare(
      'SELECT * FROM medications WHERE patient_id = ? AND is_active = 1',
    ).all(patientId);
    const totals = await todayTotals(db, patientId, localDate, medications);
    const evaluation = evaluatePillCheck({ detections, medications, todayTotals: totals, catalog });
    const check = await persistEvaluation(db, {
      patientId, user: req.user, source: 'photo', evaluation,
      detections: stripBoxes(detections), localDate,
      medsById: new Map(medications.map((m) => [m.id, m])),
    });
    res.status(201).json({ check });
  } catch (error) {
    logger.error('Pill check error:', error);
    res.status(500).json({ error: 'Failed to record pill check' });
  }
});

export default router;
