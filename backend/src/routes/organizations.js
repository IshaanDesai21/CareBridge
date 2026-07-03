import express from 'express';
import { randomBytes } from 'crypto';
import { getDb } from '../database/db.js';
import { authenticateToken } from '../utils/auth.js';
import logger from '../utils/logger.js';

const router = express.Router();
router.use(authenticateToken);

// 6-character uppercase hex code, e.g. "A3F9C1"
function generateOrgCode() {
  return randomBytes(3).toString('hex').toUpperCase();
}

// GET /api/organizations/me — the current user's organization (+ basic stats)
router.get('/me', async (req, res) => {
  try {
    const db = getDb();
    const me = await db.prepare('SELECT organization_id FROM users WHERE id = ?').get(req.user.id);
    if (!me?.organization_id) return res.json({ organization: null });

    const org = await db.prepare('SELECT * FROM organizations WHERE id = ?').get(me.organization_id);
    if (!org) return res.json({ organization: null });

    const members = await db.prepare('SELECT COUNT(*) AS c FROM users WHERE organization_id = ?').get(org.id);
    const patients = await db.prepare("SELECT COUNT(*) AS c FROM users WHERE organization_id = ? AND role = 'patient'").get(org.id);

    res.json({
      organization: {
        id: org.id,
        name: org.name,
        join_code: org.join_code,
        is_owner: org.owner_id === req.user.id,
        member_count: Number(members.c),
        patient_count: Number(patients.c)
      }
    });
  } catch (error) {
    logger.error('Get organization error:', error);
    res.status(500).json({ error: 'Failed to get organization' });
  }
});

// POST /api/organizations — create and name an organization; returns its join code
router.post('/', async (req, res) => {
  try {
    const { name } = req.body;
    if (!name || !name.trim()) return res.status(400).json({ error: 'Organization name is required' });
    if (!['caregiver', 'organization'].includes(req.user.role)) {
      return res.status(403).json({ error: 'Only caregiver or organization accounts can create an organization' });
    }

    const db = getDb();
    const me = await db.prepare('SELECT organization_id FROM users WHERE id = ?').get(req.user.id);
    if (me?.organization_id) return res.status(400).json({ error: 'You already belong to an organization' });

    let code;
    do { code = generateOrgCode(); } while (await db.prepare('SELECT id FROM organizations WHERE join_code = ?').get(code));

    const result = await db.prepare('INSERT INTO organizations (name, join_code, owner_id) VALUES (?, ?, ?)')
      .run(name.trim(), code, req.user.id);
    const orgId = result.lastInsertRowid;
    await db.prepare('UPDATE users SET organization_id = ? WHERE id = ?').run(orgId, req.user.id);

    res.status(201).json({
      organization: { id: orgId, name: name.trim(), join_code: code, is_owner: true, member_count: 1, patient_count: 0 }
    });
  } catch (error) {
    logger.error('Create organization error:', error);
    res.status(500).json({ error: 'Failed to create organization' });
  }
});

// POST /api/organizations/join — join an existing org with its code (any role)
router.post('/join', async (req, res) => {
  try {
    const { code } = req.body;
    if (!code || !code.trim()) return res.status(400).json({ error: 'Join code is required' });

    const db = getDb();
    const org = await db.prepare('SELECT * FROM organizations WHERE join_code = ?').get(code.trim().toUpperCase());
    if (!org) return res.status(404).json({ error: 'Invalid organization code' });

    await db.prepare('UPDATE users SET organization_id = ? WHERE id = ?').run(org.id, req.user.id);
    res.json({ organization: { id: org.id, name: org.name } });
  } catch (error) {
    logger.error('Join organization error:', error);
    res.status(500).json({ error: 'Failed to join organization' });
  }
});

export default router;
