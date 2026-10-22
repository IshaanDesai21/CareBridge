import express from 'express';
import { getDb } from '../database/db.js';
import { authenticateToken } from '../utils/auth.js';
import logger from '../utils/logger.js';
import { evaluateManualDose, drugKeyFor, duplicateMedicationProblem } from '../services/doseRules.js';
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

    // Another active row for the same drug makes the daily maximum ambiguous: fail like the photo engine.
    const key = drugKeyFor(medication.name);
    const active = await db.prepare(
      'SELECT * FROM medications WHERE patient_id = ? AND is_active = 1',
    ).all(patientId);
    const sameDrug = active.filter((m) => drugKeyFor(m.name) === key);
    let result;
    if (sameDrug.length > 1) {
      result = { status: 'fail', problems: [duplicateMedicationProblem(key)] };
    } else {
      const totals = await todayTotals(db, patientId, localDate, [medication]);
      result = evaluateManualDose({ medication, pillCount, todayTotal: totals[medication.id] ?? 0 });
    }
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
