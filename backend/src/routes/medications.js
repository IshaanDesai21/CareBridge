import express from 'express';
import { getDb } from '../database/db.js';
import { authenticateToken } from '../utils/auth.js';
import logger from '../utils/logger.js';
import { canAccessPatient } from '../utils/patientAccess.js';
import { parseId } from '../services/entryGuards.js';

const router = express.Router();
router.use(authenticateToken);

const WRITE_ROLES = ['caregiver', 'organization', 'patient'];
const MAX_DOSING = 20;
const FORMS = ['tablet', 'capsule'];

/** Role (403) then patient access (403) for medication writes. Returns {status, error} or null. */
async function guardWrite(db, user, patientId) {
  if (!WRITE_ROLES.includes(user?.role)) return { status: 403, error: 'Not allowed to change medications' };
  if (!(await canAccessPatient(db, user, patientId))) return { status: 403, error: 'Access denied' };
  return null;
}

/** Load a medication by route id: 400 bad id, 404 missing, then write guard on its patient. Returns { err, row }. */
async function loadForWrite(db, user, rawId) {
  if (!WRITE_ROLES.includes(user?.role)) return { err: { status: 403, error: 'Not allowed to change medications' } };
  const id = parseId(rawId);
  if (!id) return { err: { status: 400, error: 'medicationId must be a positive integer' } };
  const row = await db.prepare('SELECT * FROM medications WHERE id = ?').get(id);
  if (!row) return { err: { status: 404, error: 'Medication not found' } };
  const err = await guardWrite(db, user, row.patient_id);
  return err ? { err } : { row, id };
}

const present = (v) => v !== undefined && v !== null;
const dosingInt = (v) => Number.isInteger(v) && v > 0 && v <= MAX_DOSING;

/** Validate dosing fields that are present. Returns an error string or null. */
function dosingError({ pillsPerDoseMin, pillsPerDoseMax, dosesPerDay, form }) {
  for (const [k, v] of Object.entries({ pillsPerDoseMin, pillsPerDoseMax, dosesPerDay })) {
    if (present(v) && !dosingInt(v)) return `${k} must be a whole number from 1 to ${MAX_DOSING}`;
  }
  if (present(form) && !FORMS.includes(form)) return 'form must be tablet or capsule';
  return null;
}
const rangeError = (min, max) =>
  (present(min) && present(max) && min > max ? 'pillsPerDoseMin must not exceed pillsPerDoseMax' : null);

// Get all medications for patient
router.get('/:patientId', async (req, res) => {
  try {
    const patientId = parseId(req.params.patientId);
    if (!patientId) return res.status(400).json({ error: 'patientId must be a positive integer' });
    const db = getDb();
    if (!(await canAccessPatient(db, req.user, patientId))) return res.status(403).json({ error: 'Access denied' });
    const medications = await db.prepare(`
      SELECT * FROM medications WHERE patient_id = ? AND is_active = 1
    `).all(patientId);
    // Sorted here rather than in SQL: names are encrypted at rest, so the
    // database can't order them meaningfully.
    medications.sort((a, b) => String(a.name ?? '').localeCompare(String(b.name ?? ''), undefined, { sensitivity: 'base' }));
    res.json({ medications });
  } catch (error) {
    logger.error('Get medications error:', error);
    res.status(500).json({ error: 'Failed to retrieve medications' });
  }
});

// Create medication
router.post('/', async (req, res) => {
  try {
    const {
      patientId, name, dosage, frequency, instructions,
      startDate, endDate, pharmacyName, pharmacyPhone,
      form, strength, pillsPerDoseMin, pillsPerDoseMax, dosesPerDay, asNeeded
    } = req.body;

    // If only one end of the pills-per-dose range is given, use it for both.
    const minPills = pillsPerDoseMin ?? pillsPerDoseMax ?? null;
    const maxPills = pillsPerDoseMax ?? pillsPerDoseMin ?? null;

    const pid = parseId(patientId);
    if (!pid) return res.status(400).json({ error: 'patientId must be a positive integer' });
    const db = getDb();
    const err = await guardWrite(db, req.user, pid);
    if (err) return res.status(err.status).json({ error: err.error });
    const vErr = dosingError({ pillsPerDoseMin, pillsPerDoseMax, dosesPerDay, form }) ?? rangeError(minPills, maxPills);
    if (vErr) return res.status(400).json({ error: vErr });

    const result = await db.prepare(`
      INSERT INTO medications (
        patient_id, name, dosage, frequency, instructions,
        start_date, end_date, pharmacy_name, pharmacy_phone,
        form, strength, pills_per_dose_min, pills_per_dose_max, doses_per_day, as_needed
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      pid, name, dosage ?? null, frequency ?? null, instructions ?? null,
      startDate ?? null, endDate ?? null, pharmacyName ?? null, pharmacyPhone ?? null,
      form ?? null, strength ?? dosage ?? null, minPills, maxPills,
      dosesPerDay ?? null, asNeeded ? 1 : 0
    );

    const medication = await db.prepare('SELECT * FROM medications WHERE id = ?').get(result.lastInsertRowid);
    res.status(201).json({ medication });
  } catch (error) {
    logger.error('Create medication error:', error);
    res.status(500).json({ error: 'Failed to create medication' });
  }
});

// Update medication
router.put('/:medicationId', async (req, res) => {
  try {
    const { name, dosage, frequency, instructions, endDate, pharmacyName, pharmacyPhone, isActive,
      form, strength, pillsPerDoseMin, pillsPerDoseMax, dosesPerDay, asNeeded } = req.body;

    const db = getDb();
    const { err, row, id } = await loadForWrite(db, req.user, req.params.medicationId);
    if (err) return res.status(err.status).json({ error: err.error });
    const vErr = dosingError({ pillsPerDoseMin, pillsPerDoseMax, dosesPerDay, form })
      ?? rangeError(pillsPerDoseMin ?? row.pills_per_dose_min, pillsPerDoseMax ?? row.pills_per_dose_max);
    if (vErr) return res.status(400).json({ error: vErr });
    await db.prepare(`
      UPDATE medications SET
        name = COALESCE(?, name),
        dosage = COALESCE(?, dosage),
        frequency = COALESCE(?, frequency),
        instructions = COALESCE(?, instructions),
        end_date = COALESCE(?, end_date),
        pharmacy_name = COALESCE(?, pharmacy_name),
        pharmacy_phone = COALESCE(?, pharmacy_phone),
        is_active = COALESCE(?, is_active),
        form = COALESCE(?, form),
        strength = COALESCE(?, strength),
        pills_per_dose_min = COALESCE(?, pills_per_dose_min),
        pills_per_dose_max = COALESCE(?, pills_per_dose_max),
        doses_per_day = COALESCE(?, doses_per_day),
        as_needed = COALESCE(?, as_needed),
        updated_at = CURRENT_TIMESTAMP
      WHERE id = ?
    `).run(
      name ?? null, dosage ?? null, frequency ?? null, instructions ?? null,
      endDate ?? null, pharmacyName ?? null, pharmacyPhone ?? null,
      isActive !== undefined ? (isActive ? 1 : 0) : null,
      form ?? null, strength ?? null, pillsPerDoseMin ?? null, pillsPerDoseMax ?? null,
      dosesPerDay ?? null, asNeeded !== undefined ? (asNeeded ? 1 : 0) : null,
      id
    );

    const medication = await db.prepare('SELECT * FROM medications WHERE id = ?').get(id);
    if (!medication) return res.status(404).json({ error: 'Medication not found' });
    res.json({ medication });
  } catch (error) {
    logger.error('Update medication error:', error);
    res.status(500).json({ error: 'Failed to update medication' });
  }
});

// Delete medication: soft delete so dose history (dose_logs, medication_logs) is never cascaded away
// and still counts toward the drug's daily maximum.
router.delete('/:medicationId', async (req, res) => {
  try {
    const db = getDb();
    const { err, id } = await loadForWrite(db, req.user, req.params.medicationId);
    if (err) return res.status(err.status).json({ error: err.error });
    await db.prepare('UPDATE medications SET is_active = 0, updated_at = CURRENT_TIMESTAMP WHERE id = ?').run(id);
    res.json({ success: true });
  } catch (error) {
    logger.error('Delete medication error:', error);
    res.status(500).json({ error: 'Failed to delete medication' });
  }
});

// Log medication taken
router.post('/:medicationId/log', async (req, res) => {
  try {
    const { scheduledTime, takenTime, status, notes } = req.body;

    const db = getDb();
    const { err, id } = await loadForWrite(db, req.user, req.params.medicationId);
    if (err) return res.status(err.status).json({ error: err.error });
    const result = await db.prepare(`
      INSERT INTO medication_logs (medication_id, scheduled_time, taken_time, status, notes)
      VALUES (?, ?, ?, ?, ?)
    `).run(id, scheduledTime, takenTime ?? null, status ?? 'taken', notes ?? null);

    const log = await db.prepare('SELECT * FROM medication_logs WHERE id = ?').get(result.lastInsertRowid);
    res.status(201).json({ log });
  } catch (error) {
    logger.error('Log medication error:', error);
    res.status(500).json({ error: 'Failed to log medication' });
  }
});

export default router;
