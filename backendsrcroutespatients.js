import express from 'express';
import { query } from '../database/connection.js';
import { authenticateToken } from '../utils/auth.js';
import logger from '../utils/logger.js';

const router = express.Router();

// All routes require authentication
router.use(authenticateToken);

// Get patient profile
router.get('/:patientId', async (req, res) => {
  try {
    const { patientId } = req.params;

    const result = await query(
      `SELECT p.*, u.email, u.first_name, u.last_name 
       FROM patients p
       JOIN users u ON p.user_id = u.id
       WHERE p.id = $1`,
      [patientId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Patient not found' });
    }

    res.json({ patient: result.rows[0] });
  } catch (error) {
    logger.error('Get patient error:', error);
    res.status(500).json({ error: 'Failed to retrieve patient' });
  }
});

// Update patient profile
router.put('/:patientId', async (req, res) => {
  try {
    const { patientId } = req.params;
    const {
      dateOfBirth,
      phone,
      emergencyContactName,
      emergencyContactPhone,
      medicalHistory,
      diagnoses,
      allergies,
      accessibilityPreferences
    } = req.body;

    const result = await query(
      `UPDATE patients 
       SET date_of_birth = COALESCE($1, date_of_birth),
           phone = COALESCE($2, phone),
           emergency_contact_name = COALESCE($3, emergency_contact_name),
           emergency_contact_phone = COALESCE($4, emergency_contact_phone),
           medical_history = COALESCE($5, medical_history),
           diagnoses = COALESCE($6, diagnoses),
           allergies = COALESCE($7, allergies),
           accessibility_preferences = COALESCE($8, accessibility_preferences),
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $9
       RETURNING *`,
      [
        dateOfBirth,
        phone,
        emergencyContactName,
        emergencyContactPhone,
        medicalHistory,
        diagnoses,
        allergies,
        JSON.stringify(accessibilityPreferences),
        patientId
      ]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Patient not found' });
    }

    res.json({ patient: result.rows[0] });
  } catch (error) {
    logger.error('Update patient error:', error);
    res.status(500).json({ error: 'Failed to update patient' });
  }
});

// Get all patients (for caregivers)
router.get('/', async (req, res) => {
  try {
    const result = await query(
      `SELECT p.*, u.email, u.first_name, u.last_name 
       FROM patients p
       JOIN users u ON p.user_id = u.id
       ORDER BY p.wellness_score ASC, u.last_name ASC`
    );

    res.json({ patients: result.rows });
  } catch (error) {
    logger.error('Get patients error:', error);
    res.status(500).json({ error: 'Failed to retrieve patients' });
  }
});

export default router;
