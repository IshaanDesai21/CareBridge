import express from 'express';
import { query } from '../database/connection.js';
import { authenticateToken } from '../utils/auth.js';
import logger from '../utils/logger.js';

const router = express.Router();
router.use(authenticateToken);

// Get journal entries for patient
router.get('/:patientId', async (req, res) => {
  try {
    const { patientId } = req.params;

    const result = await query(
      `SELECT * FROM journal_entries 
       WHERE patient_id = $1 
       ORDER BY created_at DESC`,
      [patientId]
    );

    res.json({ entries: result.rows });
  } catch (error) {
    logger.error('Get journal entries error:', error);
    res.status(500).json({ error: 'Failed to retrieve journal entries' });
  }
});

// Create journal entry
router.post('/', async (req, res) => {
  try {
    const { patientId, title, content, mood, isShared } = req.body;

    const result = await query(
      `INSERT INTO journal_entries (patient_id, title, content, mood, is_shared)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [patientId, title, content, mood, isShared || false]
    );

    res.status(201).json({ entry: result.rows[0] });
  } catch (error) {
    logger.error('Create journal entry error:', error);
    res.status(500).json({ error: 'Failed to create journal entry' });
  }
});

// Update journal entry
router.put('/:entryId', async (req, res) => {
  try {
    const { entryId } = req.params;
    const { title, content, mood, isShared } = req.body;

    const result = await query(
      `UPDATE journal_entries 
       SET title = COALESCE($1, title),
           content = COALESCE($2, content),
           mood = COALESCE($3, mood),
           is_shared = COALESCE($4, is_shared),
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $5
       RETURNING *`,
      [title, content, mood, isShared, entryId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Journal entry not found' });
    }

    res.json({ entry: result.rows[0] });
  } catch (error) {
    logger.error('Update journal entry error:', error);
    res.status(500).json({ error: 'Failed to update journal entry' });
  }
});

// Delete journal entry
router.delete('/:entryId', async (req, res) => {
  try {
    const { entryId } = req.params;

    const result = await query(
      'DELETE FROM journal_entries WHERE id = $1 RETURNING id',
      [entryId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Journal entry not found' });
    }

    res.json({ message: 'Journal entry deleted successfully' });
  } catch (error) {
    logger.error('Delete journal entry error:', error);
    res.status(500).json({ error: 'Failed to delete journal entry' });
  }
});

export default router;
