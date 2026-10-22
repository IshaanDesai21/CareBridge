import express from 'express';
import { getDb } from '../database/db.js';
import { authenticateToken } from '../utils/auth.js';
import logger from '../utils/logger.js';
import {
  isPosInt, parseId, validDate, textError, roleGuard, guardPatient, loadOwned,
} from '../services/entryGuards.js';

const router = express.Router();
router.use(authenticateToken);

const send = (res, err) => res.status(err.status).json({ error: err.error });

router.post('/', async (req, res) => {
  try {
    const { patientId, content, localDate } = req.body ?? {};
    const db = getDb();
    let err = roleGuard(req.user, ['patient'], 'Only patients can write patient notes');
    if (!err && !isPosInt(patientId)) err = { status: 400, error: 'patientId must be a positive integer' };
    if (!err && !validDate(localDate)) err = { status: 400, error: 'localDate must be YYYY-MM-DD' };
    if (!err) {
      const t = textError(content, 'content');
      if (t) err = { status: 400, error: t };
    }
    if (!err) err = await guardPatient(db, req.user, patientId);
    if (err) return send(res, err);

    const result = await db.prepare(
      'INSERT INTO patient_notes (patient_id, author_user_id, content, local_date) VALUES (?, ?, ?, ?)',
    ).run(patientId, req.user.id, content.trim(), localDate);
    const note = await db.prepare('SELECT * FROM patient_notes WHERE id = ?').get(result.lastInsertRowid);
    res.status(201).json({ note });
  } catch (error) {
    logger.error('Create patient note error:', error);
    res.status(500).json({ error: 'Failed to create note' });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const db = getDb();
    const id = parseId(req.params.id);
    let err = roleGuard(req.user, ['patient'], 'Only patients can write patient notes');
    if (!err && !id) err = { status: 400, error: 'Invalid id' };
    if (!err) {
      const t = textError(req.body?.content, 'content');
      if (t) err = { status: 400, error: t };
    }
    if (!err) err = (await loadOwned(db, 'patient_notes', 'author_user_id', id, req.user, 'Note')).err;
    if (err) return send(res, err);

    await db.prepare('UPDATE patient_notes SET content = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
      .run(req.body.content.trim(), id);
    const note = await db.prepare('SELECT * FROM patient_notes WHERE id = ?').get(id);
    res.json({ note });
  } catch (error) {
    logger.error('Update patient note error:', error);
    res.status(500).json({ error: 'Failed to update note' });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    const db = getDb();
    const id = parseId(req.params.id);
    let err = roleGuard(req.user, ['patient'], 'Only patients can write patient notes');
    if (!err && !id) err = { status: 400, error: 'Invalid id' };
    if (!err) err = (await loadOwned(db, 'patient_notes', 'author_user_id', id, req.user, 'Note')).err;
    if (err) return send(res, err);

    await db.prepare('DELETE FROM patient_notes WHERE id = ?').run(id);
    res.json({ success: true });
  } catch (error) {
    logger.error('Delete patient note error:', error);
    res.status(500).json({ error: 'Failed to delete note' });
  }
});

export default router;
