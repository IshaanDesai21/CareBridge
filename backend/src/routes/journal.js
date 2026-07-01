import express from 'express';
import { getDb } from '../database/db.js';
import { authenticateToken } from '../utils/auth.js';
import logger from '../utils/logger.js';

const router = express.Router();
router.use(authenticateToken);

// Get journal entries
router.get('/:patientId', (req, res) => {
  try {
    const db = getDb();
    const entries = db.prepare(
      'SELECT * FROM journal_entries WHERE patient_id = ? ORDER BY created_at DESC'
    ).all(req.params.patientId);
    res.json({ entries });
  } catch (error) {
    logger.error('Get journal entries error:', error);
    res.status(500).json({ error: 'Failed to retrieve journal entries' });
  }
});

// Create journal entry
router.post('/', (req, res) => {
  try {
    const { patientId, title, content, mood, isShared } = req.body;

    const db = getDb();
    const result = db.prepare(`
      INSERT INTO journal_entries (patient_id, title, content, mood, is_shared)
      VALUES (?, ?, ?, ?, ?)
    `).run(patientId, title ?? null, content ?? null, mood ?? null, isShared ? 1 : 0);

    const entry = db.prepare('SELECT * FROM journal_entries WHERE id = ?').get(result.lastInsertRowid);
    res.status(201).json({ entry });
  } catch (error) {
    logger.error('Create journal entry error:', error);
    res.status(500).json({ error: 'Failed to create journal entry' });
  }
});

// Update journal entry
router.put('/:entryId', (req, res) => {
  try {
    const { title, content, mood, isShared } = req.body;

    const db = getDb();
    db.prepare(`
      UPDATE journal_entries SET
        title = COALESCE(?, title),
        content = COALESCE(?, content),
        mood = COALESCE(?, mood),
        is_shared = COALESCE(?, is_shared),
        updated_at = CURRENT_TIMESTAMP
      WHERE id = ?
    `).run(
      title ?? null, content ?? null, mood ?? null,
      isShared !== undefined ? (isShared ? 1 : 0) : null,
      req.params.entryId
    );

    const entry = db.prepare('SELECT * FROM journal_entries WHERE id = ?').get(req.params.entryId);
    if (!entry) return res.status(404).json({ error: 'Journal entry not found' });
    res.json({ entry });
  } catch (error) {
    logger.error('Update journal entry error:', error);
    res.status(500).json({ error: 'Failed to update journal entry' });
  }
});

// Delete journal entry
router.delete('/:entryId', (req, res) => {
  try {
    const db = getDb();
    const info = db.prepare('DELETE FROM journal_entries WHERE id = ?').run(req.params.entryId);
    if (info.changes === 0) return res.status(404).json({ error: 'Journal entry not found' });
    res.json({ message: 'Journal entry deleted successfully' });
  } catch (error) {
    logger.error('Delete journal entry error:', error);
    res.status(500).json({ error: 'Failed to delete journal entry' });
  }
});

export default router;
