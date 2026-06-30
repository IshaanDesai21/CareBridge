import { query } from './connection.js';
import bcrypt from 'bcrypt';
import logger from '../utils/logger.js';

async function seed() {
  try {
    logger.info('Starting database seed...');

    // Create sample patient user
    const patientPassword = await bcrypt.hash('password123', 10);
    const patientResult = await query(
      `INSERT INTO users (email, password_hash, role, first_name, last_name) 
       VALUES ($1, $2, $3, $4, $5) 
       ON CONFLICT (email) DO NOTHING
       RETURNING id`,
      ['patient@example.com', patientPassword, 'patient', 'John', 'Doe']
    );

    if (patientResult.rows.length > 0) {
      const patientUserId = patientResult.rows[0].id;
      logger.info(`Created patient user with ID: ${patientUserId}`);

      // Create patient profile
      const patientProfileResult = await query(
        `INSERT INTO patients (user_id, date_of_birth, phone, emergency_contact_name, emergency_contact_phone, wellness_score)
         VALUES ($1, $2, $3, $4, $5, $6)
         RETURNING id`,
        [patientUserId, '1975-05-15', '555-0123', 'Jane Doe', '555-0124', 75]
      );

      const patientId = patientProfileResult.rows[0].id;
      logger.info(`Created patient profile with ID: ${patientId}`);

      // Create sample medications
      await query(
        `INSERT INTO medications (patient_id, name, dosage, frequency, instructions)
         VALUES 
         ($1, 'Lisinopril', '10mg', 'Once daily', 'Take in the morning with water'),
         ($1, 'Metformin', '500mg', 'Twice daily', 'Take with meals'),
         ($1, 'Vitamin D', '2000 IU', 'Once daily', 'Take with food')`,
        [patientId]
      );
      logger.info('Created sample medications');

      // Create sample appointments
      await query(
        `INSERT INTO appointments (patient_id, title, type, provider_name, location, appointment_date, duration_minutes)
         VALUES 
         ($1, 'Annual Physical', 'doctor', 'Dr. Smith', '123 Medical Plaza', NOW() + INTERVAL '7 days', 60),
         ($1, 'Physical Therapy', 'therapy', 'Jane PT', '456 Wellness Center', NOW() + INTERVAL '3 days', 45)`,
        [patientId]
      );
      logger.info('Created sample appointments');

      // Create sample wellness check-ins
      const today = new Date();
      for (let i = 0; i < 7; i++) {
        const date = new Date(today);
        date.setDate(date.getDate() - i);
        
        await query(
          `INSERT INTO wellness_checkins (
            patient_id, date, energy, fatigue, pain, mood, sleep_quality,
            breathing, mobility, balance, speech_clarity, appetite, 
            hydration, swallowing_difficulty, notes
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)`,
          [
            patientId,
            date.toISOString().split('T')[0],
            Math.floor(Math.random() * 3) + 6, // 6-8
            Math.floor(Math.random() * 3) + 3, // 3-5
            Math.floor(Math.random() * 3) + 2, // 2-4
            Math.floor(Math.random() * 3) + 7, // 7-9
            Math.floor(Math.random() * 3) + 6, // 6-8
            Math.floor(Math.random() * 2) + 8, // 8-9
            Math.floor(Math.random() * 2) + 7, // 7-8
            Math.floor(Math.random() * 2) + 7, // 7-8
            Math.floor(Math.random() * 2) + 8, // 8-9
            Math.floor(Math.random() * 3) + 6, // 6-8
            Math.floor(Math.random() * 3) + 6, // 6-8
            Math.floor(Math.random() * 2) + 2, // 2-3
            i === 0 ? 'Feeling good today!' : null
          ]
        );
      }
      logger.info('Created sample wellness check-ins');

      // Create sample journal entries
      await query(
        `INSERT INTO journal_entries (patient_id, title, content, mood)
         VALUES 
         ($1, 'Good Day', 'Had a wonderful day today. Went for a walk in the park.', 'happy'),
         ($1, 'Doctor Visit', 'Doctor says my numbers are looking good. Feeling encouraged.', 'calm')`,
        [patientId]
      );
      logger.info('Created sample journal entries');
    }

    // Create sample caregiver user
    const caregiverPassword = await bcrypt.hash('password123', 10);
    const caregiverResult = await query(
      `INSERT INTO users (email, password_hash, role, first_name, last_name) 
       VALUES ($1, $2, $3, $4, $5) 
       ON CONFLICT (email) DO NOTHING
       RETURNING id`,
      ['caregiver@example.com', caregiverPassword, 'caregiver', 'Sarah', 'Smith']
    );

    if (caregiverResult.rows.length > 0) {
      logger.info(`Created caregiver user with ID: ${caregiverResult.rows[0].id}`);
    }

    logger.info('✅ Database seeding completed successfully!');
    logger.info('');
    logger.info('Sample accounts created:');
    logger.info('  Patient:');
    logger.info('    Email: patient@example.com');
    logger.info('    Password: password123');
    logger.info('');
    logger.info('  Caregiver:');
    logger.info('    Email: caregiver@example.com');
    logger.info('    Password: password123');

    process.exit(0);
  } catch (error) {
    logger.error('Error seeding database:', error);
    process.exit(1);
  }
}

// Run if called directly
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

if (process.argv[1] === __filename) {
  // Connect to database first
  import('./connection.js').then(({ connectDatabase }) => {
    connectDatabase().then(() => {
      seed();
    });
  });
}

export default seed;
