// Postgres-backed database layer. Exposes a better-sqlite3-shaped API
// (db.prepare(sql).get/all/run with `?` placeholders) so route code written
// against that shape only needed `async`/`await` added, not rewritten.
import pg from 'pg';
import logger from '../utils/logger.js';

const { Pool } = pg;

let pool;

function convertPlaceholders(sql) {
  let i = 0;
  return sql.replace(/\?/g, () => `$${++i}`);
}

function toPgSql(sql) {
  return convertPlaceholders(sql);
}

class Statement {
  constructor(rawSql) {
    this.rawSql = rawSql;
    this.sql = toPgSql(rawSql);
  }

  async all(...params) {
    const { rows } = await pool.query(this.sql, params);
    return rows;
  }

  async get(...params) {
    const { rows } = await pool.query(this.sql, params);
    return rows[0];
  }

  async run(...params) {
    let sql = this.sql;
    const isInsertOrIgnore = /insert\s+or\s+ignore\s+into/i.test(this.rawSql);
    if (isInsertOrIgnore) {
      sql = sql.replace(/insert\s+or\s+ignore\s+into/i, 'INSERT INTO');
    }
    const isInsert = /^\s*insert/i.test(this.rawSql);
    if (isInsert) {
      if (isInsertOrIgnore) sql += ' ON CONFLICT DO NOTHING';
      if (!/returning/i.test(sql)) sql += ' RETURNING id';
    }
    const result = await pool.query(sql, params);
    return {
      lastInsertRowid: result.rows[0]?.id,
      changes: result.rowCount
    };
  }
}

export function getDb() {
  if (!pool) {
    throw new Error('Database not initialized. Call connectDatabase() first.');
  }
  return { prepare: (sql) => new Statement(sql) };
}

export async function connectDatabase() {
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) {
    throw new Error('DATABASE_URL is not set. Point it at your Postgres instance (e.g. a Neon connection string).');
  }

  pool = new Pool({
    connectionString,
    ssl: connectionString.includes('sslmode=require') || process.env.NODE_ENV === 'production'
      ? { rejectUnauthorized: false }
      : false
  });

  await initializeTables();
  logger.info('✅ Postgres database ready');
  return pool;
}

async function initializeTables() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT,
      google_id TEXT UNIQUE,
      role TEXT NOT NULL DEFAULT 'patient' CHECK (role IN ('patient', 'caregiver', 'family', 'organization')),
      first_name TEXT,
      last_name TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS patients (
      id SERIAL PRIMARY KEY,
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
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS wellness_checkins (
      id SERIAL PRIMARY KEY,
      patient_id INTEGER REFERENCES patients(id) ON DELETE CASCADE,
      date TEXT DEFAULT (CURRENT_DATE::text),
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
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS medications (
      id SERIAL PRIMARY KEY,
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
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS medication_logs (
      id SERIAL PRIMARY KEY,
      medication_id INTEGER REFERENCES medications(id) ON DELETE CASCADE,
      scheduled_time TEXT NOT NULL,
      taken_time TEXT,
      status TEXT CHECK (status IN ('pending', 'taken', 'missed', 'skipped')),
      notes TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS verification_logs (
      id SERIAL PRIMARY KEY,
      medication_id INTEGER REFERENCES medications(id) ON DELETE CASCADE,
      status TEXT CHECK (status IN ('match', 'mismatch')),
      expected_name TEXT NOT NULL,
      detected_pills TEXT NOT NULL,
      verified_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS appointments (
      id SERIAL PRIMARY KEY,
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
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS journal_entries (
      id SERIAL PRIMARY KEY,
      patient_id INTEGER REFERENCES patients(id) ON DELETE CASCADE,
      title TEXT,
      content TEXT,
      mood TEXT,
      is_shared INTEGER DEFAULT 0,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS care_notes (
      id SERIAL PRIMARY KEY,
      patient_id INTEGER REFERENCES patients(id) ON DELETE CASCADE,
      caregiver_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
      note_type TEXT CHECK (note_type IN ('observation', 'behavior', 'equipment', 'nutrition', 'communication', 'question')),
      content TEXT NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS care_tasks (
      id SERIAL PRIMARY KEY,
      patient_id INTEGER REFERENCES patients(id) ON DELETE CASCADE,
      assigned_to INTEGER REFERENCES users(id) ON DELETE SET NULL,
      title TEXT NOT NULL,
      description TEXT,
      task_type TEXT,
      scheduled_time TEXT,
      completed_at TEXT,
      status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'skipped')),
      recurrence TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS ai_insights (
      id SERIAL PRIMARY KEY,
      patient_id INTEGER REFERENCES patients(id) ON DELETE CASCADE,
      insight_type TEXT CHECK (insight_type IN ('trend', 'alert', 'recommendation', 'summary')),
      title TEXT,
      description TEXT,
      severity TEXT CHECK (severity IN ('low', 'medium', 'high')),
      data_points TEXT,
      is_read INTEGER DEFAULT 0,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS join_codes (
      id SERIAL PRIMARY KEY,
      code TEXT UNIQUE NOT NULL,
      patient_id INTEGER REFERENCES patients(id) ON DELETE CASCADE,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS family_patient_links (
      id SERIAL PRIMARY KEY,
      family_user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
      patient_id INTEGER REFERENCES patients(id) ON DELETE CASCADE,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(family_user_id, patient_id)
    );

    CREATE TABLE IF NOT EXISTS patient_alerts (
      id SERIAL PRIMARY KEY,
      patient_id INTEGER REFERENCES patients(id) ON DELETE CASCADE,
      message TEXT NOT NULL,
      is_urgent INTEGER DEFAULT 0,
      is_acknowledged INTEGER DEFAULT 0,
      acknowledged_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  `);

  // Migrations for columns added after the initial schema. Postgres supports
  // IF NOT EXISTS directly, so these are idempotent without a try/catch.
  await pool.query(`
    ALTER TABLE users ALTER COLUMN password_hash DROP NOT NULL;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS google_id TEXT UNIQUE;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS phone TEXT;
    ALTER TABLE patients ADD COLUMN IF NOT EXISTS gender TEXT;
    ALTER TABLE patients ADD COLUMN IF NOT EXISTS height_cm REAL;
    ALTER TABLE patients ADD COLUMN IF NOT EXISTS weight_kg REAL;
    ALTER TABLE patients ADD COLUMN IF NOT EXISTS hearing_notes TEXT;
    ALTER TABLE patients ADD COLUMN IF NOT EXISTS vision_score TEXT;
    ALTER TABLE patients ADD COLUMN IF NOT EXISTS emergency_contacts TEXT;
    ALTER TABLE patients ADD COLUMN IF NOT EXISTS care_team TEXT;
    ALTER TABLE patients ADD COLUMN IF NOT EXISTS ai_companion_name TEXT;
    ALTER TABLE patients ADD COLUMN IF NOT EXISTS ai_companion_gender TEXT;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS organization_id INTEGER;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS apple_id TEXT UNIQUE;
  `);

  // Organizations: an owner creates + names an org and gets a single join code.
  // Caregivers and patients both join with that code (users.organization_id).
  await pool.query(`
    CREATE TABLE IF NOT EXISTS organizations (
      id SERIAL PRIMARY KEY,
      name TEXT NOT NULL,
      join_code TEXT UNIQUE NOT NULL,
      owner_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS notifications (
      id SERIAL PRIMARY KEY,
      user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
      title TEXT NOT NULL,
      body TEXT NOT NULL,
      type TEXT DEFAULT 'alert',
      is_read INTEGER DEFAULT 0,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS chat_messages (
      id SERIAL PRIMARY KEY,
      user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
      role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
      content TEXT NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  `);

  logger.info('Database tables initialized');
}
