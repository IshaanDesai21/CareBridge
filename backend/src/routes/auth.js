import express from 'express';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { randomBytes } from 'crypto';
import { OAuth2Client } from 'google-auth-library';
import { getDb } from '../database/db.js';
import logger from '../utils/logger.js';

const router = express.Router();
const JWT_SECRET = process.env.JWT_SECRET || 'carebridge-dev-secret';

// Both the web and iOS Google OAuth clients are accepted as valid
// audiences, since Google issues a separate client ID per platform.
const GOOGLE_CLIENT_IDS = [process.env.GOOGLE_WEB_CLIENT_ID, process.env.GOOGLE_IOS_CLIENT_ID].filter(Boolean);
const googleClient = GOOGLE_CLIENT_IDS.length ? new OAuth2Client() : null;

function generateJoinCode() {
  return randomBytes(3).toString('hex').toUpperCase();
}

function signToken(user) {
  return jwt.sign({ id: user.id, email: user.email, role: user.role }, JWT_SECRET, { expiresIn: '7d' });
}

async function createPatientRecord(db, userId) {
  const patientResult = await db.prepare('INSERT INTO patients (user_id, wellness_score) VALUES (?, ?)').run(userId, 75);
  const patientId = patientResult.lastInsertRowid;
  let code;
  do { code = generateJoinCode(); } while (await db.prepare('SELECT id FROM join_codes WHERE code = ?').get(code));
  await db.prepare('INSERT INTO join_codes (code, patient_id) VALUES (?, ?)').run(code, patientId);
  return code;
}

// Register new user
router.post('/register', async (req, res) => {
  try {
    const { email, password, role = 'patient', firstName, lastName, joinCode, phone } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }

    const db = getDb();

    const existing = await db.prepare('SELECT id FROM users WHERE email = ?').get(email);
    if (existing) {
      return res.status(400).json({ error: 'User already exists' });
    }

    // Validate join code for family registration if provided
    let familyPatientId = null;
    if (role === 'family' && joinCode) {
      const codeRecord = await db.prepare('SELECT * FROM join_codes WHERE code = ?').get(joinCode.toUpperCase().trim());
      if (!codeRecord) return res.status(400).json({ error: 'Invalid join code' });
      familyPatientId = codeRecord.patient_id;
    }

    const passwordHash = await bcrypt.hash(password, 10);

    const insertUser = db.prepare(
      'INSERT INTO users (email, password_hash, role, first_name, last_name, phone) VALUES (?, ?, ?, ?, ?, ?)'
    );
    const userResult = await insertUser.run(email, passwordHash, role, firstName ?? null, lastName ?? null, phone ?? null);
    const userId = userResult.lastInsertRowid;

    let patientJoinCode = null;
    if (role === 'patient') {
      patientJoinCode = await createPatientRecord(db, userId);
    }

    if (familyPatientId) {
      await db.prepare('INSERT OR IGNORE INTO family_patient_links (family_user_id, patient_id) VALUES (?, ?)').run(userId, familyPatientId);
    }

    const user = await db.prepare(
      'SELECT id, email, role, first_name, last_name, created_at FROM users WHERE id = ?'
    ).get(userId);

    res.status(201).json({
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
        first_name: user.first_name,
        last_name: user.last_name,
        ...(patientJoinCode ? { join_code: patientJoinCode } : {})
      },
      token: signToken(user)
    });
  } catch (error) {
    logger.error('Registration error:', error);
    res.status(500).json({ error: 'Registration failed' });
  }
});

// Login
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }

    const db = getDb();
    const user = await db.prepare(
      'SELECT id, email, password_hash, role, first_name, last_name FROM users WHERE email = ?'
    ).get(email);

    if (!user || !user.password_hash) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const isValid = await bcrypt.compare(password, user.password_hash);
    if (!isValid) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    res.json({
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
        first_name: user.first_name,
        last_name: user.last_name
      },
      token: signToken(user)
    });
  } catch (error) {
    logger.error('Login error:', error);
    res.status(500).json({ error: 'Login failed' });
  }
});

// Sign in / register with a Google ID token (Google Identity Services on
// web, GoogleSignIn SDK on iOS both hand back an ID token for the client
// to forward here; we verify it server-side rather than trusting the client).
router.post('/google', async (req, res) => {
  try {
    if (!googleClient) {
      return res.status(501).json({ error: 'Google sign-in is not configured on this server' });
    }

    const { idToken, role, joinCode } = req.body;
    if (!idToken) {
      return res.status(400).json({ error: 'idToken is required' });
    }

    let payload;
    try {
      const ticket = await googleClient.verifyIdToken({ idToken, audience: GOOGLE_CLIENT_IDS });
      payload = ticket.getPayload();
    } catch (verifyError) {
      logger.error('Google token verification failed:', verifyError.message);
      return res.status(401).json({ error: 'Invalid Google token' });
    }

    const { sub: googleId, email, given_name: firstName, family_name: lastName } = payload;
    if (!email) {
      return res.status(400).json({ error: 'Google account has no email' });
    }

    const db = getDb();
    let user = await db.prepare('SELECT * FROM users WHERE google_id = ? OR email = ?').get(googleId, email);

    let patientJoinCode = null;
    if (!user) {
      const chosenRole = ['patient', 'caregiver', 'family', 'organization'].includes(role) ? role : 'patient';

      let familyPatientId = null;
      if (chosenRole === 'family' && joinCode) {
        const codeRecord = await db.prepare('SELECT * FROM join_codes WHERE code = ?').get(joinCode.toUpperCase().trim());
        if (codeRecord) familyPatientId = codeRecord.patient_id;
      }

      const inserted = await db.prepare(
        'INSERT INTO users (email, google_id, role, first_name, last_name) VALUES (?, ?, ?, ?, ?)'
      ).run(email, googleId, chosenRole, firstName ?? null, lastName ?? null);
      const userId = inserted.lastInsertRowid;

      if (chosenRole === 'patient') {
        patientJoinCode = await createPatientRecord(db, userId);
      }
      if (familyPatientId) {
        await db.prepare('INSERT OR IGNORE INTO family_patient_links (family_user_id, patient_id) VALUES (?, ?)').run(userId, familyPatientId);
      }

      user = await db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    } else if (!user.google_id) {
      // Existing password-based account signing in with Google for the first time — link it.
      await db.prepare('UPDATE users SET google_id = ? WHERE id = ?').run(googleId, user.id);
    }

    res.json({
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
        first_name: user.first_name,
        last_name: user.last_name,
        ...(patientJoinCode ? { join_code: patientJoinCode } : {})
      },
      token: signToken(user)
    });
  } catch (error) {
    logger.error('Google sign-in error:', error);
    res.status(500).json({ error: 'Google sign-in failed' });
  }
});

// Get current user
router.get('/me', async (req, res) => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
      return res.status(401).json({ error: 'Access token required' });
    }

    const decoded = jwt.verify(token, JWT_SECRET);
    const db = getDb();
    const user = await db.prepare(
      'SELECT id, email, role, first_name, last_name, created_at FROM users WHERE id = ?'
    ).get(decoded.id);

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({ user });
  } catch (error) {
    logger.error('Get user error:', error);
    res.status(401).json({ error: 'Invalid token' });
  }
});

export default router;
