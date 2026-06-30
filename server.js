import express from 'express';
import cors from 'cors';
import Database from 'better-sqlite3';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// SQLite Database
const db = new Database('carebridge.db');

// Create tables
db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    first_name TEXT,
    last_name TEXT,
    role TEXT DEFAULT 'patient',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );
  
  CREATE TABLE IF NOT EXISTS patients (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    wellness_score INTEGER DEFAULT 75,
    FOREIGN KEY (user_id) REFERENCES users(id)
  );

  CREATE TABLE IF NOT EXISTS wellness_checkins (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_id INTEGER,
    date TEXT DEFAULT (date('now')),
    energy INTEGER,
    mood INTEGER,
    pain INTEGER,
    notes TEXT,
    FOREIGN KEY (patient_id) REFERENCES patients(id)
  );
`);

console.log('✅ Database ready');

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static('public')); // Serve static files from public folder

// Routes
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    database: 'SQLite'
  });
});

// Register
app.post('/api/auth/register', async (req, res) => {
  try {
    const { email, password, firstName, lastName } = req.body;
    const hash = await bcrypt.hash(password, 10);
    
    const stmt = db.prepare('INSERT INTO users (email, password_hash, first_name, last_name) VALUES (?, ?, ?, ?)');
    const result = stmt.run(email, hash, firstName, lastName);
    
    db.prepare('INSERT INTO patients (user_id) VALUES (?)').run(result.lastInsertRowid);
    
    const user = db.prepare('SELECT id, email, first_name, last_name FROM users WHERE id = ?').get(result.lastInsertRowid);
    const token = jwt.sign({ id: user.id }, 'secret-key', { expiresIn: '7d' });
    
    res.json({ user, token });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Login
app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    
    const user = db.prepare('SELECT * FROM users WHERE email = ?').get(email);
    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    
    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    
    const token = jwt.sign({ id: user.id }, 'secret-key', { expiresIn: '7d' });
    
    res.json({
      user: { id: user.id, email: user.email, firstName: user.first_name, lastName: user.last_name },
      token
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Get patients
app.get('/api/patients', (req, res) => {
  try {
    const patients = db.prepare(`
      SELECT p.id, p.wellness_score, u.email, u.first_name, u.last_name
      FROM patients p
      JOIN users u ON p.user_id = u.id
      ORDER BY p.wellness_score ASC
    `).all();
    
    res.json({ patients });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Submit wellness check-in
app.post('/api/wellness', (req, res) => {
  try {
    const { patientId, energy, mood, pain, notes } = req.body;
    
    const stmt = db.prepare('INSERT INTO wellness_checkins (patient_id, energy, mood, pain, notes) VALUES (?, ?, ?, ?, ?)');
    const result = stmt.run(patientId, energy, mood, pain, notes);
    
    const score = Math.round(((energy + mood + (11 - pain)) / 3) * 10);
    db.prepare('UPDATE patients SET wellness_score = ? WHERE id = ?').run(score, patientId);
    
    const checkin = db.prepare('SELECT * FROM wellness_checkins WHERE id = ?').get(result.lastInsertRowid);
    
    res.json({ checkin, wellnessScore: score });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Get wellness history
app.get('/api/wellness/:patientId', (req, res) => {
  try {
    const checkins = db.prepare('SELECT * FROM wellness_checkins WHERE patient_id = ? ORDER BY date DESC LIMIT 30').all(req.params.patientId);
    res.json({ checkins });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

app.listen(PORT, () => {
  console.log(`\n🚀 CareBridge API running on http://localhost:${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
  console.log(`🌐 Open website: http://localhost:${PORT}\n`);
});
