import express from 'express';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { randomBytes } from 'crypto';
import { getDb } from '../database/db.js';
import logger from '../utils/logger.js';

const router = express.Router();
const JWT_SECRET = process.env.JWT_SECRET || 'carebridge-dev-secret';

function generateJoinCode() {
  return randomBytes(3).toString('hex').toUpperCase();
}

// Register new user
router.post('/register', async (req, res) => {
  try {
    const { email, password, role = 'patient', firstName, lastName, joinCode, phone } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }

    const db = getDb();

    const existing = db.prepare('SELECT id FROM users WHERE email = ?').get(email);
    if (existing) {
      return res.status(400).json({ error: 'User already exists' });
    }

    // Validate join code for family registration if provided
    let familyPatientId = null;
    if (role === 'family' && joinCode) {
      const codeRecord = db.prepare('SELECT * FROM join_codes WHERE code = ?').get(joinCode.toUpperCase().trim());
      if (!codeRecord) return res.status(400).json({ error: 'Invalid join code' });
      familyPatientId = codeRecord.patient_id;
    }

    const passwordHash = await bcrypt.hash(password, 10);

    const insertUser = db.prepare(
      'INSERT INTO users (email, password_hash, role, first_name, last_name, phone) VALUES (?, ?, ?, ?, ?, ?)'
    );
    const userResult = insertUser.run(email, passwordHash, role, firstName ?? null, lastName ?? null, phone ?? null);
    const userId = userResult.lastInsertRowid;

    let patientJoinCode = null;
    if (role === 'patient') {
      const patientResult = db.prepare('INSERT INTO patients (user_id, wellness_score) VALUES (?, ?)').run(userId, 75);
      const patientId = patientResult.lastInsertRowid;
      // Generate unique join code
      let code;
      do { code = generateJoinCode(); } while (db.prepare('SELECT id FROM join_codes WHERE code = ?').get(code));
      db.prepare('INSERT INTO join_codes (code, patient_id) VALUES (?, ?)').run(code, patientId);
      patientJoinCode = code;
    }

    if (familyPatientId) {
      db.prepare('INSERT OR IGNORE INTO family_patient_links (family_user_id, patient_id) VALUES (?, ?)').run(userId, familyPatientId);
    }

    const user = db.prepare(
      'SELECT id, email, role, first_name, last_name, created_at FROM users WHERE id = ?'
    ).get(userId);

    const token = jwt.sign(
      { id: user.id, email: user.email, role: user.role },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.status(201).json({
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
        first_name: user.first_name,
        last_name: user.last_name,
        ...(patientJoinCode ? { join_code: patientJoinCode } : {})
      },
      token
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
    const user = db.prepare(
      'SELECT id, email, password_hash, role, first_name, last_name FROM users WHERE email = ?'
    ).get(email);

    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const isValid = await bcrypt.compare(password, user.password_hash);
    if (!isValid) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const token = jwt.sign(
      { id: user.id, email: user.email, role: user.role },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.json({
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
        first_name: user.first_name,
        last_name: user.last_name
      },
      token
    });
  } catch (error) {
    logger.error('Login error:', error);
    res.status(500).json({ error: 'Login failed' });
  }
});

// Get current user
router.get('/me', (req, res) => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
      return res.status(401).json({ error: 'Access token required' });
    }

    const decoded = jwt.verify(token, JWT_SECRET);
    const db = getDb();
    const user = db.prepare(
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
