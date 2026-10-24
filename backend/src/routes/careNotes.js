import express from 'express';
import { getDb } from '../database/db.js';
import { authenticateToken } from '../utils/auth.js';
import logger from '../utils/logger.js';
import { canAccessPatient } from '../utils/patientAccess.js';
import {
  isPosInt, parseId, localDateError, textError, roleGuard, guardPatient, loadOwned, NOTE_TYPES,
} from '../services/entryGuards.js';

const router = express.Router();
router.use(authenticateToken);

// Get care notes for patient
router.get('/:patientId', async (req, res) => {
  try {
    const db = getDb();
    const patientId = parseId(req.params.patientId);
    if (!patientId) return res.status(400).json({ error: 'Invalid patientId' });
    if (!(await canAccessPatient(db, req.user, patientId))) return res.status(403).json({ error: 'Access denied' });
    const notes = await db.prepare(`
      SELECT cn.*, u.first_name, u.last_name
      FROM care_notes cn
      LEFT JOIN users u ON cn.caregiver_id = u.id
      WHERE cn.patient_id = ?
      ORDER BY cn.created_at DESC
    `).all(patientId);
    res.json({ notes });
  } catch (error) {
    logger.error('Get care notes error:', error);
    res.status(500).json({ error: 'Failed to retrieve care notes' });
  }
});

const WRITERS = ['caregiver', 'organization'];
const ROLE_MSG = 'Only caregivers can write care notes';
const send = (res, err) => res.status(err.status).json({ error: err.error });

// Create care note (localDate is optional: the web dashboard posts without it)
router.post('/', async (req, res) => {
  try {
    const { patientId, noteType, content, localDate } = req.body ?? {};
    const db = getDb();
    let err = roleGuard(req.user, WRITERS, ROLE_MSG);
    if (!err && !isPosInt(patientId)) err = { status: 400, error: 'patientId must be a positive integer' };
    if (!err && localDate != null) err = localDateError(localDate);
    if (!err && noteType != null && !NOTE_TYPES.includes(noteType)) err = { status: 400, error: 'Invalid noteType' };
    if (!err) {
      const t = textError(content, 'content');
      if (t) err = { status: 400, error: t };
    }
    if (!err) err = await guardPatient(db, req.user, patientId);
    if (err) return send(res, err);

    const result = await db.prepare(`
      INSERT INTO care_notes (patient_id, caregiver_id, note_type, content, local_date)
      VALUES (?, ?, ?, ?, ?)
    `).run(patientId, req.user.id, noteType ?? null, content.trim(), localDate ?? null);

    const note = await db.prepare('SELECT * FROM care_notes WHERE id = ?').get(result.lastInsertRowid);
    res.status(201).json({ note });
  } catch (error) {
    logger.error('Create care note error:', error);
    res.status(500).json({ error: 'Failed to create care note' });
  }
});

// Update care note (author only)
router.put('/:noteId', async (req, res) => {
  try {
    const { noteType, content } = req.body ?? {};
    const db = getDb();
    const id = parseId(req.params.noteId);
    let err = roleGuard(req.user, WRITERS, ROLE_MSG);
    if (!err && !id) err = { status: 400, error: 'Invalid id' };
    if (!err && noteType != null && !NOTE_TYPES.includes(noteType)) err = { status: 400, error: 'Invalid noteType' };
    if (!err && content != null) {
      const t = textError(content, 'content');
      if (t) err = { status: 400, error: t };
    }
    if (!err) err = (await loadOwned(db, 'care_notes', 'caregiver_id', id, req.user, 'Care note')).err;
    if (err) return send(res, err);

    await db.prepare(`
      UPDATE care_notes SET
        note_type = COALESCE(?, note_type),
        content = COALESCE(?, content),
        updated_at = CURRENT_TIMESTAMP
      WHERE id = ?
    `).run(noteType ?? null, content == null ? null : content.trim(), id);

    const note = await db.prepare('SELECT * FROM care_notes WHERE id = ?').get(id);
    res.json({ note });
  } catch (error) {
    logger.error('Update care note error:', error);
    res.status(500).json({ error: 'Failed to update care note' });
  }
});

export default router;
