import express from 'express';
import { getDb } from '../database/db.js';
import { authenticateToken } from '../utils/auth.js';
import logger from '../utils/logger.js';

const router = express.Router();
router.use(authenticateToken);

// Get all patients (for caregivers)
router.get('/', (req, res) => {
  try {
    const db = getDb();
    const patients = db.prepare(`
      SELECT p.*, u.email, u.first_name, u.last_name
      FROM patients p
      JOIN users u ON p.user_id = u.id
      ORDER BY p.wellness_score ASC, u.last_name ASC
    `).all();
    res.json({ patients });
  } catch (error) {
    logger.error('Get patients error:', error);
    res.status(500).json({ error: 'Failed to retrieve patients' });
  }
});

// Get patient profile
router.get('/:patientId', (req, res) => {
  try {
    const db = getDb();
    const patient = db.prepare(`
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

// Update patient profile
router.put('/:patientId', (req, res) => {
  try {
    const {
      dateOfBirth, phone, emergencyContactName, emergencyContactPhone,
      medicalHistory, diagnoses, allergies, accessibilityPreferences
    } = req.body;

    const db = getDb();
    db.prepare(`
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

    const patient = db.prepare('SELECT * FROM patients WHERE id = ?').get(req.params.patientId);
    if (!patient) return res.status(404).json({ error: 'Patient not found' });
    res.json({ patient });
  } catch (error) {
    logger.error('Update patient error:', error);
    res.status(500).json({ error: 'Failed to update patient' });
  }
});

export default router;
