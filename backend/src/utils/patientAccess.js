/**
 * Whether `user` may access the patient with id `patientId`.
 * - patient: owns the record (patients.user_id = user.id)
 * - family: linked via family_patient_links
 * - caregiver/organization: no organization_id on the caller, or the patient's
 *   user shares it (mirrors routes/patients.js GET /)
 * - anything else: false
 */
export async function canAccessPatient(db, user, patientId) {
  switch (user.role) {
    case 'patient': {
      const patient = await db.prepare('SELECT id, user_id FROM patients WHERE id = ?').get(patientId);
      return !!patient && String(patient.user_id) === String(user.id);
    }
    case 'family': {
      const link = await db
        .prepare('SELECT 1 AS linked FROM family_patient_links WHERE family_user_id = ? AND patient_id = ?')
        .get(user.id, patientId);
      return !!link;
    }
    case 'caregiver':
    case 'organization': {
      const me = await db.prepare('SELECT organization_id FROM users WHERE id = ?').get(user.id);
      if (!me?.organization_id) return true;
      const row = await db
        .prepare(
          `SELECT p.id FROM patients p
           JOIN users u ON p.user_id = u.id
           WHERE p.id = ? AND u.organization_id = ?`
        )
        .get(patientId, me.organization_id);
      return !!row;
    }
    default:
      return false;
  }
}
