// Private patient<->family group conversation. Participation is a pure ownership/link check
// (isConversationParticipant): caregivers and organizations are never participants and
// there is deliberately no role-based or organization-wide read path.
import express from 'express';
import { getDb } from '../database/db.js';
import { authenticateToken } from '../utils/auth.js';
import logger from '../utils/logger.js';
import { sendToUser } from '../utils/ws.js';
import { isConversationParticipant, conversationParticipantIds } from '../utils/patientAccess.js';
import { parseId } from '../services/entryGuards.js';

const router = express.Router();
router.use(authenticateToken);

const MAX_CONTENT = 2000;
const DEFAULT_LIMIT = 50;
const MAX_LIMIT = 100;

const MESSAGE_SELECT = `
  SELECT m.id, m.patient_id, m.sender_user_id, m.content, m.created_at,
         u.first_name, u.last_name, u.role
  FROM family_messages m
  LEFT JOIN users u ON u.id = m.sender_user_id`;

const toMessage = (r) => ({
  id: r.id,
  patientId: r.patient_id,
  senderUserId: r.sender_user_id,
  senderName: [r.first_name, r.last_name].filter(Boolean).join(' '),
  senderRole: r.role ?? null,
  content: r.content,
  createdAt: r.created_at,
});

const bad = (res, error) => res.status(400).json({ error });
const denied = (res) => res.status(403).json({ error: 'Access denied' });

// Unread counts for every conversation the caller participates in (0-count entries included).
// Declared before /:patientId so "unread" is never parsed as an id.
router.get('/unread', async (req, res) => {
  try {
    const db = getDb();
    const me = req.user.id;
    const rows = await db.prepare(`
      SELECT c.patient_id, COUNT(m.id) AS unread_count
      FROM (
        SELECT id AS patient_id FROM patients WHERE user_id = ?
        UNION
        SELECT patient_id FROM family_patient_links WHERE family_user_id = ?
      ) c
      LEFT JOIN family_message_reads r ON r.user_id = ? AND r.patient_id = c.patient_id
      LEFT JOIN family_messages m ON m.patient_id = c.patient_id
        AND m.id > COALESCE(r.last_read_message_id, 0)
        AND m.sender_user_id IS DISTINCT FROM ?
      GROUP BY c.patient_id
      ORDER BY c.patient_id
    `).all(me, me, me, me);
    res.json({ unread: rows.map((r) => ({ patientId: r.patient_id, count: Number(r.unread_count) })) });
  } catch (error) {
    logger.error('Get unread messages error:', error);
    res.status(500).json({ error: 'Failed to get unread counts' });
  }
});

router.get('/:patientId', async (req, res) => {
  try {
    const patientId = parseId(req.params.patientId);
    if (!patientId) return bad(res, 'Invalid patientId');

    const { before, limit } = req.query ?? {};
    let lim = DEFAULT_LIMIT;
    if (limit !== undefined) {
      lim = /^\d+$/.test(String(limit)) ? Number(limit) : NaN;
      if (!Number.isInteger(lim) || lim < 1 || lim > MAX_LIMIT) return bad(res, `limit must be an integer 1-${MAX_LIMIT}`);
    }
    let beforeId = null;
    if (before !== undefined) {
      beforeId = parseId(before);
      if (!beforeId) return bad(res, 'before must be a positive integer');
    }

    const db = getDb();
    if (!(await isConversationParticipant(db, req.user.id, patientId))) return denied(res);

    const rows = beforeId
      ? await db.prepare(`${MESSAGE_SELECT} WHERE m.patient_id = ? AND m.id < ? ORDER BY m.id DESC LIMIT ?`)
        .all(patientId, beforeId, lim)
      : await db.prepare(`${MESSAGE_SELECT} WHERE m.patient_id = ? ORDER BY m.id DESC LIMIT ?`)
        .all(patientId, lim);
    res.json({ messages: rows.map(toMessage).sort((a, b) => a.id - b.id) });
  } catch (error) {
    logger.error('Get messages error:', error);
    res.status(500).json({ error: 'Failed to get messages' });
  }
});

router.post('/:patientId/read', async (req, res) => {
  try {
    const patientId = parseId(req.params.patientId);
    if (!patientId) return bad(res, 'Invalid patientId');
    const lastRead = req.body?.lastReadMessageId;
    if (!Number.isInteger(lastRead) || lastRead <= 0) return bad(res, 'lastReadMessageId must be a positive integer');

    const db = getDb();
    if (!(await isConversationParticipant(db, req.user.id, patientId))) return denied(res);

    await db.prepare(`
      INSERT INTO family_message_reads (user_id, patient_id, last_read_message_id)
      VALUES (?, ?, ?)
      ON CONFLICT (user_id, patient_id) DO UPDATE SET
        last_read_message_id = GREATEST(family_message_reads.last_read_message_id, EXCLUDED.last_read_message_id)
      RETURNING user_id
    `).run(req.user.id, patientId, lastRead);
    res.json({ ok: true });
  } catch (error) {
    logger.error('Mark messages read error:', error);
    res.status(500).json({ error: 'Failed to mark messages read' });
  }
});

router.post('/:patientId', async (req, res) => {
  try {
    const patientId = parseId(req.params.patientId);
    if (!patientId) return bad(res, 'Invalid patientId');

    const db = getDb();
    if (!(await isConversationParticipant(db, req.user.id, patientId))) return denied(res);

    const raw = req.body?.content;
    const content = typeof raw === 'string' ? raw.trim() : '';
    if (!content) return bad(res, 'content is required');
    if (content.length > MAX_CONTENT) return bad(res, `content must be at most ${MAX_CONTENT} characters`);

    // db.run appends RETURNING id and exposes it as lastInsertRowid.
    const result = await db.prepare(
      'INSERT INTO family_messages (patient_id, sender_user_id, content) VALUES (?, ?, ?)',
    ).run(patientId, req.user.id, content);
    const row = await db.prepare(`${MESSAGE_SELECT} WHERE m.id = ?`).get(result.lastInsertRowid);
    const message = toMessage(row);

    const recipients = (await conversationParticipantIds(db, patientId))
      .filter((id) => String(id) !== String(req.user.id));
    for (const id of recipients) {
      try {
        sendToUser(id, { type: 'family_message', patientId, message });
      } catch (e) {
        logger.warn('Family message push failed:', e);
      }
    }

    res.status(201).json({ message });
  } catch (error) {
    logger.error('Send message error:', error);
    res.status(500).json({ error: 'Failed to send message' });
  }
});

export default router;
