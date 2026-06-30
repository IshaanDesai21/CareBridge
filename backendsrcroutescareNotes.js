import express from 'express';
import { query } from '../database/connection.js';
import { authenticateToken } from '../utils/auth.js';
import logger from '../utils/logger.js';

const router = express.Router();
router.use(authenticateToken);

// Get care notes for patient
router.get('/:patientId', async (req, res) => {
  try {
    const { patientId } = req.params;

    const result = await query(
      `SELECT cn.*, u.first_name, u.last_name 
       FROM care_notes cn
       LEFT JOIN users u ON cn.caregiver_id = u.id
       WHERE cn.patient_id = $1 
       ORDER BY cn.created_at DESC`,
      [patientId]
    );

    res.json({ notes: result.rows });
  } catch (error) {
    logger.error('Get care notes error:', error);
    res.status(500).json({ error: 'Failed to retrieve care notes' });
  }
});

// Create care note
router.post('/', async (req, res) => {
  try {
    const { patientId, noteType, content } = req.body;
    const caregiverId = req.user.id;

    const result = await query(
      `INSERT INTO care_notes (patient_id, caregiver_id, note_type, content)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [patientId, caregiverId, noteType, content]
    );

    res.status(201).json({ note: result.rows[0] });
  } catch (error) {
    logger.error('Create care note error:', error);
    res.status(500).json({ error: 'Failed to create care note' });
  }
});

// Update care note
router.put('/:noteId', async (req, res) => {
  try {
    const { noteId } = req.params;
    const { noteType, content } = req.body;

    const result = await query(
      `UPDATE care_notes 
       SET note_type = COALESCE($1, note_type),
           content = COALESCE($2, content),
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $3
       RETURNING *`,
      [noteType, content, noteId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Care note not found' });
    }

    res.json({ note: result.rows[0] });
  } catch (error) {
    logger.error('Update care note error:', error);
    res.status(500).json({ error: 'Failed to update care note' });
  }
});

export default router;
