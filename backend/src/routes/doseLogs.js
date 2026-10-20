import express from 'express';
import { getDb } from '../database/db.js';
import { authenticateToken } from '../utils/auth.js';
import logger from '../utils/logger.js';
import { evaluateManualDose } from '../services/doseRules.js';
import {
  todayTotals, persistEvaluation, guardDoseRequest, guardPatient,
} from '../services/doseStore.js';

const router = express.Router();
router.use(authenticateToken);

router.post('/manual', async (req, res) => {
  try {
    const { patientId, medicationId, pillCount, localDate } = req.body ?? {};
    const db = getDb();
    let err = await guardDoseRequest(db, req.user, { patientId, localDate });
    if (!err && !(Number.isInteger(medicationId) && medicationId > 0)) {
      err = { status: 400, error: 'medicationId must be a positive integer' };
    }
    if (!err && !(Number.isInteger(pillCount) && pillCount >= 1)) {
      err = { status: 400, error: 'pillCount must be an integer of at least 1' };
    }
    if (!err) err = await guardPatient(db, req.user, patientId);
    if (err) return res.status(err.status).json({ error: err.error });

    const medication = await db.prepare(
      'SELECT * FROM medications WHERE id = ? AND patient_id = ? AND is_active = 1',
    ).get(medicationId, patientId);
    if (!medication) return res.status(404).json({ error: 'Medication not found' });

    const totals = await todayTotals(db, patientId, localDate);
    const result = evaluateManualDose({ medication, pillCount, todayTotal: totals[medicationId] ?? 0 });
    const evaluation = result.status === 'pass'
      ? { ...result, doses: [{ medicationId, pillCount, strengthVerified: false }] }
      : result;
    const check = await persistEvaluation(db, {
      patientId, user: req.user, source: 'manual', evaluation,
      detections: [], localDate, medsById: new Map([[medication.id, medication]]),
    });
    res.status(201).json({ check });
  } catch (error) {
    logger.error('Manual dose error:', error);
    res.status(500).json({ error: 'Failed to record dose' });
  }
});

export default router;
