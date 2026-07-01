// Uses the built-in node:sqlite module (Node 22.5+, stable in Node 24)
// Zero native compilation required — no better-sqlite3 needed.
import { DatabaseSync } from 'node:sqlite';
import { fileURLToPath } from 'url';
import path from 'path';
import logger from '../utils/logger.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DB_PATH = path.join(__dirname, '..', '..', 'carebridge.db');

let db;

export function getDb() {
  if (!db) {
    throw new Error('Database not initialized. Call connectDatabase() first.');
  }
  return db;
}

export function connectDatabase() {
  db = new DatabaseSync(DB_PATH);

  // Enable WAL mode and foreign keys
  db.exec('PRAGMA journal_mode = WAL');
  db.exec('PRAGMA foreign_keys = ON');

  initializeTables();
  logger.info(`✅ SQLite database ready at ${DB_PATH}`);
  return db;
}

function initializeTables() {
  db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      role TEXT NOT NULL DEFAULT 'patient' CHECK (role IN ('patient', 'caregiver', 'family', 'organization')),
      first_name TEXT,
      last_name TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS patients (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
      date_of_birth TEXT,
      phone TEXT,
      emergency_contact_name TEXT,
      emergency_contact_phone TEXT,
      medical_history TEXT,
      diagnoses TEXT,
      allergies TEXT,
      accessibility_preferences TEXT,
      wellness_score INTEGER DEFAULT 75,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS wellness_checkins (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      patient_id INTEGER REFERENCES patients(id) ON DELETE CASCADE,
      date TEXT DEFAULT (date('now')),
      energy INTEGER CHECK (energy BETWEEN 1 AND 10),
      fatigue INTEGER CHECK (fatigue BETWEEN 1 AND 10),
      pain INTEGER CHECK (pain BETWEEN 1 AND 10),
      mood INTEGER CHECK (mood BETWEEN 1 AND 10),
      sleep_quality INTEGER CHECK (sleep_quality BETWEEN 1 AND 10),
      breathing INTEGER CHECK (breathing BETWEEN 1 AND 10),
      mobility INTEGER CHECK (mobility BETWEEN 1 AND 10),
      balance INTEGER CHECK (balance BETWEEN 1 AND 10),
      speech_clarity INTEGER CHECK (speech_clarity BETWEEN 1 AND 10),
      appetite INTEGER CHECK (appetite BETWEEN 1 AND 10),
      hydration INTEGER CHECK (hydration BETWEEN 1 AND 10),
      swallowing_difficulty INTEGER CHECK (swallowing_difficulty BETWEEN 1 AND 10),
      weight REAL,
      notes TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS medications (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      patient_id INTEGER REFERENCES patients(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      dosage TEXT,
      frequency TEXT,
      instructions TEXT,
      start_date TEXT,
      end_date TEXT,
      pharmacy_name TEXT,
      pharmacy_phone TEXT,
      refill_reminder_days INTEGER DEFAULT 7,
      is_active INTEGER DEFAULT 1,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS medication_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      medication_id INTEGER REFERENCES medications(id) ON DELETE CASCADE,
      scheduled_time TEXT NOT NULL,
      taken_time TEXT,
      status TEXT CHECK (status IN ('pending', 'taken', 'missed', 'skipped')),
      notes TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS appointments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      patient_id INTEGER REFERENCES patients(id) ON DELETE CASCADE,
      title TEXT NOT NULL,
      type TEXT CHECK (type IN ('doctor', 'therapy', 'equipment', 'telehealth')),
      provider_name TEXT,
      location TEXT,
      appointment_date TEXT NOT NULL,
      duration_minutes INTEGER DEFAULT 30,
      notes TEXT,
      questions TEXT,
      follow_up_tasks TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS journal_entries (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      patient_id INTEGER REFERENCES patients(id) ON DELETE CASCADE,
      title TEXT,
      content TEXT,
      mood TEXT,
      is_shared INTEGER DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS care_notes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      patient_id INTEGER REFERENCES patients(id) ON DELETE CASCADE,
      caregiver_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
      note_type TEXT CHECK (note_type IN ('observation', 'behavior', 'equipment', 'nutrition', 'communication', 'question')),
      content TEXT NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS care_tasks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      patient_id INTEGER REFERENCES patients(id) ON DELETE CASCADE,
      assigned_to INTEGER REFERENCES users(id) ON DELETE SET NULL,
      title TEXT NOT NULL,
      description TEXT,
      task_type TEXT,
      scheduled_time TEXT,
      completed_at TEXT,
      status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'skipped')),
      recurrence TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS ai_insights (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      patient_id INTEGER REFERENCES patients(id) ON DELETE CASCADE,
      insight_type TEXT CHECK (insight_type IN ('trend', 'alert', 'recommendation', 'summary')),
      title TEXT,
      description TEXT,
      severity TEXT CHECK (severity IN ('low', 'medium', 'high')),
      data_points TEXT,
      is_read INTEGER DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
  `);

  logger.info('Database tables initialized');
}
