import express from 'express';
import { getDb } from '../database/db.js';
import { authenticateToken } from '../utils/auth.js';
import logger from '../utils/logger.js';

const router = express.Router();
router.use(authenticateToken);

// Get appointments for patient
router.get('/:patientId', async (req, res) => {
  try {
    const upcoming = req.query.upcoming !== 'false';
    const db = getDb();

    let sql = 'SELECT * FROM appointments WHERE patient_id = ?';
    const params = [req.params.patientId];
    if (upcoming) {
      sql += ' AND appointment_date >= ?';
      params.push(new Date().toISOString());
    }
    sql += ' ORDER BY appointment_date ASC';

    const appointments = await db.prepare(sql).all(...params);
    res.json({ appointments });
  } catch (error) {
    logger.error('Get appointments error:', error);
    res.status(500).json({ error: 'Failed to retrieve appointments' });
  }
});

// Create appointment
router.post('/', async (req, res) => {
  try {
    const {
      patientId, title, type, providerName, location,
      appointmentDate, durationMinutes, notes, questions
    } = req.body;

    const db = getDb();
    const result = await db.prepare(`
      INSERT INTO appointments (
        patient_id, title, type, provider_name, location,
        appointment_date, duration_minutes, notes, questions
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      patientId, title, type ?? null, providerName ?? null, location ?? null,
      appointmentDate, durationMinutes ?? 30, notes ?? null,
      questions ? JSON.stringify(questions) : null
    );

    const appointment = await db.prepare('SELECT * FROM appointments WHERE id = ?').get(result.lastInsertRowid);
    res.status(201).json({ appointment });
  } catch (error) {
    logger.error('Create appointment error:', error);
    res.status(500).json({ error: 'Failed to create appointment' });
  }
});

// Update appointment
router.put('/:appointmentId', async (req, res) => {
  try {
    const {
      title, type, providerName, location, appointmentDate,
      durationMinutes, notes, questions, followUpTasks
    } = req.body;

    const db = getDb();
    await db.prepare(`
      UPDATE appointments SET
        title = COALESCE(?, title),
        type = COALESCE(?, type),
        provider_name = COALESCE(?, provider_name),
        location = COALESCE(?, location),
        appointment_date = COALESCE(?, appointment_date),
        duration_minutes = COALESCE(?, duration_minutes),
        notes = COALESCE(?, notes),
        questions = COALESCE(?, questions),
        follow_up_tasks = COALESCE(?, follow_up_tasks),
        updated_at = CURRENT_TIMESTAMP
      WHERE id = ?
    `).run(
      title ?? null, type ?? null, providerName ?? null, location ?? null,
      appointmentDate ?? null, durationMinutes ?? null, notes ?? null,
      questions ? JSON.stringify(questions) : null,
      followUpTasks ? JSON.stringify(followUpTasks) : null,
      req.params.appointmentId
    );

    const appointment = await db.prepare('SELECT * FROM appointments WHERE id = ?').get(req.params.appointmentId);
    if (!appointment) return res.status(404).json({ error: 'Appointment not found' });
    res.json({ appointment });
  } catch (error) {
    logger.error('Update appointment error:', error);
    res.status(500).json({ error: 'Failed to update appointment' });
  }
});

// Delete appointment
router.delete('/:appointmentId', async (req, res) => {
  try {
    const db = getDb();
    const info = await db.prepare('DELETE FROM appointments WHERE id = ?').run(req.params.appointmentId);
    if (info.changes === 0) return res.status(404).json({ error: 'Appointment not found' });
    res.json({ message: 'Appointment deleted successfully' });
  } catch (error) {
    logger.error('Delete appointment error:', error);
    res.status(500).json({ error: 'Failed to delete appointment' });
  }
});

export default router;
