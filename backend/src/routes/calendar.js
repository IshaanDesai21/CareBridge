import express from 'express';
import { getDb } from '../database/db.js';
import { authenticateToken } from '../utils/auth.js';
import logger from '../utils/logger.js';
import { parseId, validDate, guardPatient } from '../services/entryGuards.js';
import { buildMonth, buildDay } from '../services/calendarAggregate.js';

const router = express.Router();
router.use(authenticateToken);

const MONTH_RE = /^\d{4}-(0[1-9]|1[0-2])$/;

router.get('/:patientId', async (req, res) => {
  try {
    const month = req.query.month;
    if (typeof month !== 'string' || !MONTH_RE.test(month)) return res.status(400).json({ error: 'Invalid month' });
    const patientId = parseId(req.params.patientId);
    if (!patientId) return res.status(400).json({ error: 'Invalid patientId' });
    const db = getDb();
    const err = await guardPatient(db, req.user, patientId);
    if (err) return res.status(err.status).json({ error: err.error });

    const like = `${month}-%`;
    const col = async (sql, ...params) => (await db.prepare(sql).all(...params)).map((r) => r.d);
    const checkinDates = await col(
      'SELECT DISTINCT date AS d FROM wellness_checkins WHERE patient_id = ? AND date LIKE ?', patientId, like);
    const doseDates = await col(
      'SELECT DISTINCT local_date AS d FROM dose_logs WHERE patient_id = ? AND local_date LIKE ?', patientId, like);
    const flagDates = await col(
      `SELECT DISTINCT local_date AS d FROM pill_checks
       WHERE patient_id = ? AND status = 'fail' AND resolved_by_check_id IS NULL AND local_date LIKE ?`,
      patientId, like);
    const noteDates = [
      ...(await col('SELECT DISTINCT local_date AS d FROM patient_notes WHERE patient_id = ? AND local_date LIKE ?', patientId, like)),
      ...(await col(
        // Legacy notes (NULL local_date) use the server-date of created_at; may be off by a day near midnight.
        `SELECT DISTINCT COALESCE(local_date, to_char(created_at, 'YYYY-MM-DD')) AS d FROM care_notes
         WHERE patient_id = ? AND COALESCE(local_date, to_char(created_at, 'YYYY-MM-DD')) LIKE ?`,
        patientId, like)),
    ];
    const mealDates = await col(
      'SELECT DISTINCT local_date AS d FROM meals WHERE patient_id = ? AND local_date LIKE ?', patientId, like);

    res.json(buildMonth({ month, checkinDates, doseDates, flagDates, noteDates, mealDates }));
  } catch (error) {
    logger.error('Calendar month error:', error);
    res.status(500).json({ error: 'Failed to load calendar' });
  }
});

router.get('/:patientId/day/:date', async (req, res) => {
  try {
    const { date } = req.params;
    const patientId = parseId(req.params.patientId);
    if (!patientId) return res.status(400).json({ error: 'Invalid patientId' });
    if (!validDate(date)) return res.status(400).json({ error: 'Invalid date' });
    const db = getDb();
    const err = await guardPatient(db, req.user, patientId);
    if (err) return res.status(err.status).json({ error: err.error });

    const checkins = await db.prepare(
      'SELECT * FROM wellness_checkins WHERE patient_id = ? AND date = ? ORDER BY created_at, id',
    ).all(patientId, date);
    const medications = await db.prepare(
      'SELECT id, name, strength, doses_per_day, as_needed, is_active FROM medications WHERE patient_id = ?',
    ).all(patientId);
    const doseLogs = await db.prepare(`
      SELECT dl.id, dl.medication_id, m.name, m.strength, dl.pill_count, dl.source, dl.strength_verified, dl.given_at
      FROM dose_logs dl JOIN medications m ON m.id = dl.medication_id
      WHERE dl.patient_id = ? AND dl.local_date = ?
      ORDER BY dl.given_at, dl.id
    `).all(patientId, date);
    const failedChecks = await db.prepare(`
      SELECT id, created_at, source, problems, resolved_by_check_id FROM pill_checks
      WHERE patient_id = ? AND status = 'fail' AND resolved_by_check_id IS NULL AND local_date = ?
      ORDER BY created_at, id
    `).all(patientId, date);
    const meals = await db.prepare(`
      SELECT ml.id, ml.meal_type, ml.description, ml.author_user_id, ml.created_at,
             u.first_name AS author_first_name, u.last_name AS author_last_name
      FROM meals ml LEFT JOIN users u ON u.id = ml.author_user_id
      WHERE ml.patient_id = ? AND ml.local_date = ?
      ORDER BY ml.created_at, ml.id
    `).all(patientId, date);
    const careNotes = await db.prepare(`
      SELECT cn.id, cn.caregiver_id, cn.content, cn.created_at,
             u.first_name AS author_first_name, u.last_name AS author_last_name
      FROM care_notes cn LEFT JOIN users u ON u.id = cn.caregiver_id
      WHERE cn.patient_id = ?
        -- legacy NULL local_date: server-date of created_at (may be off by a day near midnight)
        AND (cn.local_date = ? OR (cn.local_date IS NULL AND to_char(cn.created_at, 'YYYY-MM-DD') = ?))
      ORDER BY cn.created_at, cn.id
    `).all(patientId, date, date);
    const patientNotes = await db.prepare(`
      SELECT pn.id, pn.author_user_id, pn.content, pn.created_at,
             u.first_name AS author_first_name, u.last_name AS author_last_name
      FROM patient_notes pn LEFT JOIN users u ON u.id = pn.author_user_id
      WHERE pn.patient_id = ? AND pn.local_date = ?
      ORDER BY pn.created_at, pn.id
    `).all(patientId, date);

    res.json({ day: buildDay({ date, checkins, medications, doseLogs, failedChecks, meals, careNotes, patientNotes }) });
  } catch (error) {
    logger.error('Calendar day error:', error);
    res.status(500).json({ error: 'Failed to load day' });
  }
});

export default router;
