import express from 'express';
import { getDb } from '../database/db.js';
import { authenticateToken } from '../utils/auth.js';
import logger from '../utils/logger.js';

const router = express.Router();
router.use(authenticateToken);

// Get care notes for patient
router.get('/:patientId', (req, res) => {
  try {
    const db = getDb();
    const notes = db.prepare(`
      SELECT cn.*, u.first_name, u.last_name
      FROM care_notes cn
      LEFT JOIN users u ON cn.caregiver_id = u.id
      WHERE cn.patient_id = ?
      ORDER BY cn.created_at DESC
    `).all(req.params.patientId);
    res.json({ notes });
  } catch (error) {
    logger.error('Get care notes error:', error);
    res.status(500).json({ error: 'Failed to retrieve care notes' });
  }
});

// Create care note
router.post('/', (req, res) => {
  try {
    const { patientId, noteType, content } = req.body;
    const caregiverId = req.user.id;

    const db = getDb();
    const result = db.prepare(`
      INSERT INTO care_notes (patient_id, caregiver_id, note_type, content)
      VALUES (?, ?, ?, ?)
    `).run(patientId, caregiverId, noteType ?? null, content);

    const note = db.prepare('SELECT * FROM care_notes WHERE id = ?').get(result.lastInsertRowid);
    res.status(201).json({ note });
  } catch (error) {
    logger.error('Create care note error:', error);
    res.status(500).json({ error: 'Failed to create care note' });
  }
});

// Update care note
router.put('/:noteId', (req, res) => {
  try {
    const { noteType, content } = req.body;

    const db = getDb();
    db.prepare(`
      UPDATE care_notes SET
        note_type = COALESCE(?, note_type),
        content = COALESCE(?, content),
        updated_at = CURRENT_TIMESTAMP
      WHERE id = ?
    `).run(noteType ?? null, content ?? null, req.params.noteId);

    const note = db.prepare('SELECT * FROM care_notes WHERE id = ?').get(req.params.noteId);
    if (!note) return res.status(404).json({ error: 'Care note not found' });
    res.json({ note });
  } catch (error) {
    logger.error('Update care note error:', error);
    res.status(500).json({ error: 'Failed to update care note' });
  }
});

export default router;
