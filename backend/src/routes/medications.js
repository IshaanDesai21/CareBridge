import express from 'express';
import { getDb } from '../database/db.js';
import { authenticateToken } from '../utils/auth.js';
import logger from '../utils/logger.js';

const router = express.Router();
router.use(authenticateToken);

// Get all medications for patient
router.get('/:patientId', async (req, res) => {
  try {
    const db = getDb();
    const medications = await db.prepare(`
      SELECT * FROM medications WHERE patient_id = ? AND is_active = 1 ORDER BY name ASC
    `).all(req.params.patientId);
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
      startDate, endDate, pharmacyName, pharmacyPhone
    } = req.body;

    const db = getDb();
    const result = await db.prepare(`
      INSERT INTO medications (
        patient_id, name, dosage, frequency, instructions,
        start_date, end_date, pharmacy_name, pharmacy_phone
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      patientId, name, dosage ?? null, frequency ?? null, instructions ?? null,
      startDate ?? null, endDate ?? null, pharmacyName ?? null, pharmacyPhone ?? null
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
    const { name, dosage, frequency, instructions, endDate, pharmacyName, pharmacyPhone, isActive } = req.body;

    const db = getDb();
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
        updated_at = CURRENT_TIMESTAMP
      WHERE id = ?
    `).run(
      name ?? null, dosage ?? null, frequency ?? null, instructions ?? null,
      endDate ?? null, pharmacyName ?? null, pharmacyPhone ?? null,
      isActive !== undefined ? (isActive ? 1 : 0) : null,
      req.params.medicationId
    );

    const medication = await db.prepare('SELECT * FROM medications WHERE id = ?').get(req.params.medicationId);
    if (!medication) return res.status(404).json({ error: 'Medication not found' });
    res.json({ medication });
  } catch (error) {
    logger.error('Update medication error:', error);
    res.status(500).json({ error: 'Failed to update medication' });
  }
});

// Delete medication (medication_logs rows cascade via ON DELETE CASCADE)
router.delete('/:medicationId', async (req, res) => {
  try {
    const db = getDb();
    const result = await db.prepare('DELETE FROM medications WHERE id = ?').run(req.params.medicationId);
    if (result.changes === 0) return res.status(404).json({ error: 'Medication not found' });
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
    const result = await db.prepare(`
      INSERT INTO medication_logs (medication_id, scheduled_time, taken_time, status, notes)
      VALUES (?, ?, ?, ?, ?)
    `).run(req.params.medicationId, scheduledTime, takenTime ?? null, status ?? 'taken', notes ?? null);

    const log = await db.prepare('SELECT * FROM medication_logs WHERE id = ?').get(result.lastInsertRowid);
    res.status(201).json({ log });
  } catch (error) {
    logger.error('Log medication error:', error);
    res.status(500).json({ error: 'Failed to log medication' });
  }
});

export default router;
