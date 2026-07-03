import express from 'express';
import { getDb } from '../database/db.js';
import { authenticateToken } from '../utils/auth.js';
import logger from '../utils/logger.js';

const router = express.Router();
router.use(authenticateToken);

// Get all patients (for caregivers/org) or linked patients (for family)
router.get('/', async (req, res) => {
  try {
    const db = getDb();
    let patients;
    if (req.user.role === 'family') {
      patients = await db.prepare(`
        SELECT p.*, u.email, u.first_name, u.last_name
        FROM family_patient_links fpl
        JOIN patients p ON fpl.patient_id = p.id
        JOIN users u ON p.user_id = u.id
        WHERE fpl.family_user_id = ?
      `).all(req.user.id);
    } else {
      // Caregiver / organization: scope to their organization if they belong to
      // one; otherwise (legacy / no org) fall back to all patients.
      const me = await db.prepare('SELECT organization_id FROM users WHERE id = ?').get(req.user.id);
      if (me?.organization_id) {
        patients = await db.prepare(`
          SELECT p.*, u.email, u.first_name, u.last_name
          FROM patients p
          JOIN users u ON p.user_id = u.id
          WHERE u.organization_id = ?
          ORDER BY p.wellness_score ASC, u.last_name ASC
        `).all(me.organization_id);
      } else {
        patients = await db.prepare(`
          SELECT p.*, u.email, u.first_name, u.last_name
          FROM patients p
          JOIN users u ON p.user_id = u.id
          ORDER BY p.wellness_score ASC, u.last_name ASC
        `).all();
      }
    }
    res.json({ patients });
  } catch (error) {
    logger.error('Get patients error:', error);
    res.status(500).json({ error: 'Failed to retrieve patients' });
  }
});

// Get current user's own patient record (patient role only)
router.get('/me', async (req, res) => {
  try {
    const db = getDb();
    const patient = await db.prepare(`
      SELECT p.*, u.email, u.first_name, u.last_name
      FROM patients p JOIN users u ON p.user_id = u.id
      WHERE p.user_id = ?
    `).get(req.user.id);
    if (!patient) return res.status(404).json({ error: 'No patient record found' });
    res.json({ patient });
  } catch (error) {
    logger.error('Get my patient error:', error);
    res.status(500).json({ error: 'Failed to retrieve patient record' });
  }
});

// Get join code for a patient (caregivers/org only)
router.get('/:patientId/join-code', async (req, res) => {
  try {
    if (!['caregiver', 'organization'].includes(req.user.role)) {
      return res.status(403).json({ error: 'Access denied' });
    }
    const db = getDb();
    const record = await db.prepare('SELECT code FROM join_codes WHERE patient_id = ?').get(req.params.patientId);
    if (!record) return res.status(404).json({ error: 'No join code found for this patient' });
    res.json({ code: record.code });
  } catch (error) {
    logger.error('Get join code error:', error);
    res.status(500).json({ error: 'Failed to get join code' });
  }
});

// Get patient profile
router.get('/:patientId', async (req, res) => {
  try {
    const db = getDb();
    const patient = await db.prepare(`
      SELECT p.*, u.email, u.first_name, u.last_name
      FROM patients p
      JOIN users u ON p.user_id = u.id
      WHERE p.id = ?
    `).get(req.params.patientId);

    if (!patient) {
      return res.status(404).json({ error: 'Patient not found' });
    }
    res.json({ patient });
  } catch (error) {
    logger.error('Get patient error:', error);
    res.status(500).json({ error: 'Failed to retrieve patient' });
  }
});

// Get physical + extended details for a patient (caregiver/org only)
router.get('/:patientId/details', async (req, res) => {
  try {
    const db = getDb();
    const patient = await db.prepare(`
      SELECT p.id, p.gender, p.height_cm, p.weight_kg, p.hearing_notes, p.vision_score,
             p.emergency_contacts, p.care_team, p.medical_history, p.diagnoses, p.allergies,
             p.ai_companion_name, p.ai_companion_gender, p.date_of_birth, p.wellness_score,
             u.first_name, u.last_name, u.email
      FROM patients p JOIN users u ON p.user_id = u.id
      WHERE p.id = ?
    `).get(req.params.patientId);
    if (!patient) return res.status(404).json({ error: 'Patient not found' });

    // Parse JSON fields
    const parse = (field) => { try { return JSON.parse(field || '[]'); } catch { return []; } };
    patient.diagnoses = parse(patient.diagnoses);
    patient.allergies = parse(patient.allergies);
    patient.emergency_contacts = parse(patient.emergency_contacts);
    patient.care_team = parse(patient.care_team);

    res.json({ details: patient });
  } catch (error) {
    logger.error('Get patient details error:', error);
    res.status(500).json({ error: 'Failed to retrieve patient details' });
  }
});

// Update patient physical + extended details (caregiver/patient)
router.patch('/:patientId/details', async (req, res) => {
  try {
    const {
      gender, heightCm, weightKg, hearingNotes, visionScore,
      medicalHistory, diagnoses, allergies, emergencyContacts, careTeam,
      aiCompanionName, aiCompanionGender
    } = req.body;

    const db = getDb();
    await db.prepare(`
      UPDATE patients SET
        gender = COALESCE(?, gender),
        height_cm = COALESCE(?, height_cm),
        weight_kg = COALESCE(?, weight_kg),
        hearing_notes = COALESCE(?, hearing_notes),
        vision_score = COALESCE(?, vision_score),
        medical_history = COALESCE(?, medical_history),
        diagnoses = COALESCE(?, diagnoses),
        allergies = COALESCE(?, allergies),
        emergency_contacts = COALESCE(?, emergency_contacts),
        care_team = COALESCE(?, care_team),
        ai_companion_name = COALESCE(?, ai_companion_name),
        ai_companion_gender = COALESCE(?, ai_companion_gender),
        updated_at = CURRENT_TIMESTAMP
      WHERE id = ?
    `).run(
      gender ?? null,
      heightCm ?? null,
      weightKg ?? null,
      hearingNotes ?? null,
      visionScore ?? null,
      medicalHistory ?? null,
      diagnoses !== undefined ? JSON.stringify(diagnoses) : null,
      allergies !== undefined ? JSON.stringify(allergies) : null,
      emergencyContacts !== undefined ? JSON.stringify(emergencyContacts) : null,
      careTeam !== undefined ? JSON.stringify(careTeam) : null,
      aiCompanionName ?? null,
      aiCompanionGender ?? null,
      req.params.patientId
    );

    res.json({ success: true });
  } catch (error) {
    logger.error('Update patient details error:', error);
    res.status(500).json({ error: 'Failed to update patient details' });
  }
});

// Update patient profile
router.put('/:patientId', async (req, res) => {
  try {
    const {
      dateOfBirth, phone, emergencyContactName, emergencyContactPhone,
      medicalHistory, diagnoses, allergies, accessibilityPreferences
    } = req.body;

    const db = getDb();
    await db.prepare(`
      UPDATE patients SET
        date_of_birth = COALESCE(?, date_of_birth),
        phone = COALESCE(?, phone),
        emergency_contact_name = COALESCE(?, emergency_contact_name),
        emergency_contact_phone = COALESCE(?, emergency_contact_phone),
        medical_history = COALESCE(?, medical_history),
        diagnoses = COALESCE(?, diagnoses),
        allergies = COALESCE(?, allergies),
        accessibility_preferences = COALESCE(?, accessibility_preferences),
        updated_at = CURRENT_TIMESTAMP
      WHERE id = ?
    `).run(
      dateOfBirth ?? null, phone ?? null, emergencyContactName ?? null,
      emergencyContactPhone ?? null, medicalHistory ?? null,
      diagnoses ? JSON.stringify(diagnoses) : null,
      allergies ? JSON.stringify(allergies) : null,
      accessibilityPreferences ? JSON.stringify(accessibilityPreferences) : null,
      req.params.patientId
    );

    const patient = await db.prepare('SELECT * FROM patients WHERE id = ?').get(req.params.patientId);
    if (!patient) return res.status(404).json({ error: 'Patient not found' });
    res.json({ patient });
  } catch (error) {
    logger.error('Update patient error:', error);
    res.status(500).json({ error: 'Failed to update patient' });
  }
});

export default router;
