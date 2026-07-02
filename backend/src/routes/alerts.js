import express from 'express';
import { getDb } from '../database/db.js';
import { authenticateToken } from '../utils/auth.js';
import { sendToUser } from '../utils/ws.js';
import logger from '../utils/logger.js';

const router = express.Router();
router.use(authenticateToken);

// POST /api/alerts — patient sends a call/help request
router.post('/', async (req, res) => {
  try {
    const { message, isUrgent = false } = req.body;
    const db = getDb();

    const patient = await db.prepare(`
      SELECT p.id, u.first_name, u.last_name
      FROM patients p JOIN users u ON p.user_id = u.id
      WHERE p.user_id = ?
    `).get(req.user.id);
    if (!patient) return res.status(404).json({ error: 'No patient record found for this user' });

    const alertMsg = message || 'Patient requesting caregiver contact';
    const result = await db.prepare(`
      INSERT INTO patient_alerts (patient_id, message, is_urgent)
      VALUES (?, ?, ?)
    `).run(patient.id, alertMsg, isUrgent ? 1 : 0);

    // Fan-out: write in-app notification to every caregiver
    const caregivers = await db.prepare(`SELECT id FROM users WHERE role = 'caregiver'`).all();
    const patientName = `${patient.first_name} ${patient.last_name}`;
    const notifTitle = isUrgent ? `🚨 Urgent — ${patientName}` : `📞 ${patientName} is calling`;
    const notifBody = alertMsg;
    const insertNotif = db.prepare(
      `INSERT INTO notifications (user_id, title, body, type) VALUES (?, ?, ?, ?)`
    );
    for (const cg of caregivers) {
      const notifResult = await insertNotif.run(cg.id, notifTitle, notifBody, isUrgent ? 'urgent' : 'alert');
      const notification = await db.prepare('SELECT * FROM notifications WHERE id = ?').get(notifResult.lastInsertRowid);
      // Deliver instantly to any caregiver device with an open WebSocket connection
      sendToUser(cg.id, { type: 'notification', notification });
    }

    const alert = await db.prepare(`
      SELECT pa.*, u.first_name || ' ' || u.last_name AS patient_name, p.wellness_score
      FROM patient_alerts pa
      JOIN patients p ON pa.patient_id = p.id
      JOIN users u ON p.user_id = u.id
      WHERE pa.id = ?
    `).get(result.lastInsertRowid);

    res.status(201).json({ alert });
  } catch (error) {
    logger.error('Create alert error:', error);
    res.status(500).json({ error: 'Failed to send alert' });
  }
});

// GET /api/alerts — caregivers get all alerts (unacknowledged first)
router.get('/', async (req, res) => {
  try {
    if (!['caregiver', 'organization'].includes(req.user.role)) {
      return res.status(403).json({ error: 'Access denied' });
    }
    const db = getDb();
    const alerts = await db.prepare(`
      SELECT pa.*, u.first_name || ' ' || u.last_name AS patient_name, p.wellness_score
      FROM patient_alerts pa
      JOIN patients p ON pa.patient_id = p.id
      JOIN users u ON p.user_id = u.id
      ORDER BY pa.is_acknowledged ASC, pa.is_urgent DESC, pa.created_at DESC
      LIMIT 50
    `).all();
    res.json({ alerts });
  } catch (error) {
    logger.error('Get alerts error:', error);
    res.status(500).json({ error: 'Failed to get alerts' });
  }
});

// PUT /api/alerts/:id/acknowledge — mark alert handled
router.put('/:id/acknowledge', async (req, res) => {
  try {
    if (!['caregiver', 'organization'].includes(req.user.role)) {
      return res.status(403).json({ error: 'Access denied' });
    }
    const db = getDb();
    await db.prepare(`
      UPDATE patient_alerts SET is_acknowledged = 1, acknowledged_by = ? WHERE id = ?
    `).run(req.user.id, req.params.id);
    res.json({ success: true });
  } catch (error) {
    logger.error('Acknowledge alert error:', error);
    res.status(500).json({ error: 'Failed to acknowledge alert' });
  }
});

// GET /api/alerts/notifications — current user's in-app notifications
router.get('/notifications', async (req, res) => {
  try {
    const db = getDb();
    const notifications = await db.prepare(`
      SELECT * FROM notifications WHERE user_id = ?
      ORDER BY created_at DESC LIMIT 50
    `).all(req.user.id);
    const unreadCount = notifications.filter(n => !n.is_read).length;
    res.json({ notifications, unreadCount });
  } catch (error) {
    logger.error('Get notifications error:', error);
    res.status(500).json({ error: 'Failed to get notifications' });
  }
});

// PUT /api/alerts/notifications/:id/read — mark notification as read
router.put('/notifications/:id/read', async (req, res) => {
  try {
    const db = getDb();
    await db.prepare(`UPDATE notifications SET is_read = 1 WHERE id = ? AND user_id = ?`)
      .run(req.params.id, req.user.id);
    res.json({ success: true });
  } catch (error) {
    logger.error('Mark notification read error:', error);
    res.status(500).json({ error: 'Failed to mark notification read' });
  }
});

export default router;
