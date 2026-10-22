import express from 'express';
import { getDb } from '../database/db.js';
import { authenticateToken } from '../utils/auth.js';
import logger from '../utils/logger.js';
import {
  isPosInt, parseId, localDateError, textError, roleGuard, guardPatient, loadOwned, MEAL_TYPES,
} from '../services/entryGuards.js';

const router = express.Router();
router.use(authenticateToken);

const WRITERS = ['patient', 'caregiver', 'organization'];
const ROLE_MSG = 'Family members cannot write meals';
const send = (res, err) => res.status(err.status).json({ error: err.error });

router.post('/', async (req, res) => {
  try {
    const { patientId, mealType, description, localDate } = req.body ?? {};
    const db = getDb();
    let err = roleGuard(req.user, WRITERS, ROLE_MSG);
    if (!err && !isPosInt(patientId)) err = { status: 400, error: 'patientId must be a positive integer' };
    if (!err) err = localDateError(localDate);
    if (!err && !MEAL_TYPES.includes(mealType)) err = { status: 400, error: 'Invalid mealType' };
    if (!err) {
      const t = textError(description, 'description');
      if (t) err = { status: 400, error: t };
    }
    if (!err) err = await guardPatient(db, req.user, patientId);
    if (err) return send(res, err);

    const result = await db.prepare(
      'INSERT INTO meals (patient_id, author_user_id, meal_type, description, local_date) VALUES (?, ?, ?, ?, ?)',
    ).run(patientId, req.user.id, mealType, description.trim(), localDate);
    const meal = await db.prepare('SELECT * FROM meals WHERE id = ?').get(result.lastInsertRowid);
    res.status(201).json({ meal });
  } catch (error) {
    logger.error('Create meal error:', error);
    res.status(500).json({ error: 'Failed to create meal' });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const { mealType, description } = req.body ?? {};
    const db = getDb();
    const id = parseId(req.params.id);
    let err = roleGuard(req.user, WRITERS, ROLE_MSG);
    if (!err && !id) err = { status: 400, error: 'Invalid id' };
    if (!err && mealType !== undefined && !MEAL_TYPES.includes(mealType)) err = { status: 400, error: 'Invalid mealType' };
    if (!err && description !== undefined) {
      const t = textError(description, 'description');
      if (t) err = { status: 400, error: t };
    }
    if (!err) err = (await loadOwned(db, 'meals', 'author_user_id', id, req.user, 'Meal')).err;
    if (err) return send(res, err);

    await db.prepare(`
      UPDATE meals SET meal_type = COALESCE(?, meal_type), description = COALESCE(?, description),
        updated_at = CURRENT_TIMESTAMP WHERE id = ?
    `).run(mealType ?? null, description === undefined ? null : description.trim(), id);
    const meal = await db.prepare('SELECT * FROM meals WHERE id = ?').get(id);
    res.json({ meal });
  } catch (error) {
    logger.error('Update meal error:', error);
    res.status(500).json({ error: 'Failed to update meal' });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    const db = getDb();
    const id = parseId(req.params.id);
    let err = roleGuard(req.user, WRITERS, ROLE_MSG);
    if (!err && !id) err = { status: 400, error: 'Invalid id' };
    if (!err) err = (await loadOwned(db, 'meals', 'author_user_id', id, req.user, 'Meal')).err;
    if (err) return send(res, err);

    await db.prepare('DELETE FROM meals WHERE id = ?').run(id);
    res.json({ success: true });
  } catch (error) {
    logger.error('Delete meal error:', error);
    res.status(500).json({ error: 'Failed to delete meal' });
  }
});

export default router;
