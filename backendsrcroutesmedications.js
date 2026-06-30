import express from 'express';
import { query } from '../database/connection.js';
import { authenticateToken } from '../utils/auth.js';
import logger from '../utils/logger.js';

const router = express.Router();
router.use(authenticateToken);

// Get all medications for patient
router.get('/:patientId', async (req, res) => {
  try {
    const { patientId } = req.params;

    const result = await query(
      `SELECT * FROM medications 
       WHERE patient_id = $1 AND is_active = true
       ORDER BY name ASC`,
      [patientId]
    );

    res.json({ medications: result.rows });
  } catch (error) {
    logger.error('Get medications error:', error);
    res.status(500).json({ error: 'Failed to retrieve medications' });
  }
});

// Create medication
router.post('/', async (req, res) => {
  try {
    const {
      patientId,
      name,
      dosage,
      frequency,
      instructions,
      startDate,
      endDate,
      pharmacyName,
      pharmacyPhone
    } = req.body;

    const result = await query(
      `INSERT INTO medications (
        patient_id, name, dosage, frequency, instructions,
        start_date, end_date, pharmacy_name, pharmacy_phone
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      RETURNING *`,
      [patientId, name, dosage, frequency, instructions, startDate, endDate, pharmacyName, pharmacyPhone]
    );

    res.status(201).json({ medication: result.rows[0] });
  } catch (error) {
    logger.error('Create medication error:', error);
    res.status(500).json({ error: 'Failed to create medication' });
  }
});

// Update medication
router.put('/:medicationId', async (req, res) => {
  try {
    const { medicationId } = req.params;
    const {
      name,
      dosage,
      frequency,
      instructions,
      endDate,
      pharmacyName,
      pharmacyPhone,
      isActive
    } = req.body;

    const result = await query(
      `UPDATE medications 
       SET name = COALESCE($1, name),
           dosage = COALESCE($2, dosage),
           frequency = COALESCE($3, frequency),
           instructions = COALESCE($4, instructions),
           end_date = COALESCE($5, end_date),
           pharmacy_name = COALESCE($6, pharmacy_name),
           pharmacy_phone = COALESCE($7, pharmacy_phone),
           is_active = COALESCE($8, is_active),
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $9
       RETURNING *`,
      [name, dosage, frequency, instructions, endDate, pharmacyName, pharmacyPhone, isActive, medicationId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Medication not found' });
    }

    res.json({ medication: result.rows[0] });
  } catch (error) {
    logger.error('Update medication error:', error);
    res.status(500).json({ error: 'Failed to update medication' });
  }
});

// Log medication taken
router.post('/:medicationId/log', async (req, res) => {
  try {
    const { medicationId } = req.params;
    const { scheduledTime, takenTime, status, notes } = req.body;

    const result = await query(
      `INSERT INTO medication_logs (medication_id, scheduled_time, taken_time, status, notes)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [medicationId, scheduledTime, takenTime, status, notes]
    );

    res.status(201).json({ log: result.rows[0] });
  } catch (error) {
    logger.error('Log medication error:', error);
    res.status(500).json({ error: 'Failed to log medication' });
  }
});

export default router;
