import express from 'express';
import { query } from '../database/connection.js';
import { authenticateToken } from '../utils/auth.js';
import logger from '../utils/logger.js';

const router = express.Router();
router.use(authenticateToken);

// Get appointments for patient
router.get('/:patientId', async (req, res) => {
  try {
    const { patientId } = req.params;
    const { upcoming = true } = req.query;

    let queryText = `SELECT * FROM appointments WHERE patient_id = $1`;
    
    if (upcoming === 'true') {
      queryText += ` AND appointment_date >= CURRENT_TIMESTAMP`;
    }
    
    queryText += ` ORDER BY appointment_date ASC`;

    const result = await query(queryText, [patientId]);

    res.json({ appointments: result.rows });
  } catch (error) {
    logger.error('Get appointments error:', error);
    res.status(500).json({ error: 'Failed to retrieve appointments' });
  }
});

// Create appointment
router.post('/', async (req, res) => {
  try {
    const {
      patientId,
      title,
      type,
      providerName,
      location,
      appointmentDate,
      durationMinutes,
      notes,
      questions
    } = req.body;

    const result = await query(
      `INSERT INTO appointments (
        patient_id, title, type, provider_name, location,
        appointment_date, duration_minutes, notes, questions
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      RETURNING *`,
      [patientId, title, type, providerName, location, appointmentDate, durationMinutes, notes, questions]
    );

    res.status(201).json({ appointment: result.rows[0] });
  } catch (error) {
    logger.error('Create appointment error:', error);
    res.status(500).json({ error: 'Failed to create appointment' });
  }
});

// Update appointment
router.put('/:appointmentId', async (req, res) => {
  try {
    const { appointmentId } = req.params;
    const {
      title,
      type,
      providerName,
      location,
      appointmentDate,
      durationMinutes,
      notes,
      questions,
      followUpTasks
    } = req.body;

    const result = await query(
      `UPDATE appointments 
       SET title = COALESCE($1, title),
           type = COALESCE($2, type),
           provider_name = COALESCE($3, provider_name),
           location = COALESCE($4, location),
           appointment_date = COALESCE($5, appointment_date),
           duration_minutes = COALESCE($6, duration_minutes),
           notes = COALESCE($7, notes),
           questions = COALESCE($8, questions),
           follow_up_tasks = COALESCE($9, follow_up_tasks),
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $10
       RETURNING *`,
      [title, type, providerName, location, appointmentDate, durationMinutes, notes, questions, followUpTasks, appointmentId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Appointment not found' });
    }

    res.json({ appointment: result.rows[0] });
  } catch (error) {
    logger.error('Update appointment error:', error);
    res.status(500).json({ error: 'Failed to update appointment' });
  }
});

// Delete appointment
router.delete('/:appointmentId', async (req, res) => {
  try {
    const { appointmentId } = req.params;

    const result = await query(
      'DELETE FROM appointments WHERE id = $1 RETURNING id',
      [appointmentId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Appointment not found' });
    }

    res.json({ message: 'Appointment deleted successfully' });
  } catch (error) {
    logger.error('Delete appointment error:', error);
    res.status(500).json({ error: 'Failed to delete appointment' });
  }
});

export default router;
