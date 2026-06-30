import pkg from 'pg';
const { Pool } = pkg;
import logger from '../utils/logger.js';

let pool;

export async function connectDatabase() {
  pool = new Pool({
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 5432,
    database: process.env.DB_NAME || 'carebridge',
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || 'postgres',
  });

  // Test connection
  try {
    const client = await pool.connect();
    logger.info('PostgreSQL connected successfully');
    client.release();
    
    // Create tables if they don't exist
    await initializeTables();
  } catch (error) {
    logger.error('Database connection error:', error);
    throw error;
  }

  return pool;
}

async function initializeTables() {
  const client = await pool.connect();
  
  try {
    await client.query('BEGIN');
    
    // Users table
    await client.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        role VARCHAR(50) NOT NULL CHECK (role IN ('patient', 'caregiver', 'family', 'organization')),
        first_name VARCHAR(100),
        last_name VARCHAR(100),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Patients table
    await client.query(`
      CREATE TABLE IF NOT EXISTS patients (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        date_of_birth DATE,
        phone VARCHAR(20),
        emergency_contact_name VARCHAR(255),
        emergency_contact_phone VARCHAR(20),
        medical_history TEXT,
        diagnoses TEXT[],
        allergies TEXT[],
        accessibility_preferences JSONB,
        wellness_score INTEGER DEFAULT 75,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Wellness check-ins table
    await client.query(`
      CREATE TABLE IF NOT EXISTS wellness_checkins (
        id SERIAL PRIMARY KEY,
        patient_id INTEGER REFERENCES patients(id) ON DELETE CASCADE,
        date DATE NOT NULL,
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
        weight DECIMAL(5,2),
        notes TEXT,
        voice_recording_url TEXT,
        photo_urls TEXT[],
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Medications table
    await client.query(`
      CREATE TABLE IF NOT EXISTS medications (
        id SERIAL PRIMARY KEY,
        patient_id INTEGER REFERENCES patients(id) ON DELETE CASCADE,
        name VARCHAR(255) NOT NULL,
        dosage VARCHAR(100),
        frequency VARCHAR(100),
        instructions TEXT,
        start_date DATE,
        end_date DATE,
        pharmacy_name VARCHAR(255),
        pharmacy_phone VARCHAR(20),
        refill_reminder_days INTEGER DEFAULT 7,
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Medication logs (tracking when meds are taken)
    await client.query(`
      CREATE TABLE IF NOT EXISTS medication_logs (
        id SERIAL PRIMARY KEY,
        medication_id INTEGER REFERENCES medications(id) ON DELETE CASCADE,
        scheduled_time TIMESTAMP NOT NULL,
        taken_time TIMESTAMP,
        status VARCHAR(20) CHECK (status IN ('pending', 'taken', 'missed', 'skipped')),
        notes TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Appointments table
    await client.query(`
      CREATE TABLE IF NOT EXISTS appointments (
        id SERIAL PRIMARY KEY,
        patient_id INTEGER REFERENCES patients(id) ON DELETE CASCADE,
        title VARCHAR(255) NOT NULL,
        type VARCHAR(50) CHECK (type IN ('doctor', 'therapy', 'equipment', 'telehealth')),
        provider_name VARCHAR(255),
        location TEXT,
        appointment_date TIMESTAMP NOT NULL,
        duration_minutes INTEGER DEFAULT 30,
        notes TEXT,
        questions TEXT[],
        follow_up_tasks TEXT[],
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Journal entries table
    await client.query(`
      CREATE TABLE IF NOT EXISTS journal_entries (
        id SERIAL PRIMARY KEY,
        patient_id INTEGER REFERENCES patients(id) ON DELETE CASCADE,
        title VARCHAR(255),
        content TEXT,
        voice_note_url TEXT,
        photo_urls TEXT[],
        mood VARCHAR(50),
        is_shared BOOLEAN DEFAULT false,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Care notes table
    await client.query(`
      CREATE TABLE IF NOT EXISTS care_notes (
        id SERIAL PRIMARY KEY,
        patient_id INTEGER REFERENCES patients(id) ON DELETE CASCADE,
        caregiver_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
        note_type VARCHAR(50) CHECK (note_type IN ('observation', 'behavior', 'equipment', 'nutrition', 'communication', 'question')),
        content TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Tasks/checklist table
    await client.query(`
      CREATE TABLE IF NOT EXISTS care_tasks (
        id SERIAL PRIMARY KEY,
        patient_id INTEGER REFERENCES patients(id) ON DELETE CASCADE,
        assigned_to INTEGER REFERENCES users(id) ON DELETE SET NULL,
        title VARCHAR(255) NOT NULL,
        description TEXT,
        task_type VARCHAR(50),
        scheduled_time TIMESTAMP,
        completed_at TIMESTAMP,
        status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'skipped')),
        recurrence VARCHAR(50),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Documents table
    await client.query(`
      CREATE TABLE IF NOT EXISTS documents (
        id SERIAL PRIMARY KEY,
        patient_id INTEGER REFERENCES patients(id) ON DELETE CASCADE,
        uploaded_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
        file_name VARCHAR(255) NOT NULL,
        file_type VARCHAR(50),
        file_url TEXT NOT NULL,
        file_size INTEGER,
        category VARCHAR(50) CHECK (category IN ('insurance', 'medical_record', 'lab_result', 'equipment', 'directive', 'other')),
        extracted_data JSONB,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // AI insights table
    await client.query(`
      CREATE TABLE IF NOT EXISTS ai_insights (
        id SERIAL PRIMARY KEY,
        patient_id INTEGER REFERENCES patients(id) ON DELETE CASCADE,
        insight_type VARCHAR(50) CHECK (insight_type IN ('trend', 'alert', 'recommendation', 'summary')),
        title VARCHAR(255),
        description TEXT,
        severity VARCHAR(20) CHECK (severity IN ('low', 'medium', 'high')),
        data_points JSONB,
        is_read BOOLEAN DEFAULT false,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    await client.query('COMMIT');
    logger.info('Database tables initialized successfully');
  } catch (error) {
    await client.query('ROLLBACK');
    logger.error('Error initializing tables:', error);
    throw error;
  } finally {
    client.release();
  }
}

export function getPool() {
  if (!pool) {
    throw new Error('Database not connected. Call connectDatabase() first.');
  }
  return pool;
}

export async function query(text, params) {
  return pool.query(text, params);
}
