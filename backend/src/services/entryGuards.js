// Shared validation/guards for calendar write routes (patient notes, meals, care notes). No Express here.
import { canAccessPatient } from '../utils/patientAccess.js';

export const MAX_TEXT = 2000;
export const MEAL_TYPES = ['breakfast', 'lunch', 'dinner', 'snack'];
export const NOTE_TYPES = ['observation', 'behavior', 'equipment', 'nutrition', 'communication', 'question'];

export const isPosInt = (n) => Number.isInteger(n) && n > 0;
const idStr = (s) => (/^\d{1,9}$/.test(String(s)) && Number(s) > 0 ? Number(s) : null);
export const parseId = idStr;

export function validDate(s) {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(typeof s === 'string' ? s : '');
  if (!m) return false;
  const [y, mo, d] = [Number(m[1]), Number(m[2]), Number(m[3])];
  const dt = new Date(Date.UTC(y, mo - 1, d));
  return dt.getUTCFullYear() === y && dt.getUTCMonth() === mo - 1 && dt.getUTCDate() === d;
}

/** Returns an error string or null. */
export function textError(value, field) {
  if (typeof value !== 'string' || value.trim() === '') return `${field} is required`;
  if (value.length > MAX_TEXT) return `${field} must be at most ${MAX_TEXT} characters`;
  return null;
}

export const roleGuard = (user, roles, msg) => (roles.includes(user?.role) ? null : { status: 403, error: msg });

/** Access (403) then existence (404). */
export async function guardPatient(db, user, patientId) {
  if (!(await canAccessPatient(db, user, patientId))) return { status: 403, error: 'Access denied' };
  const patient = await db.prepare('SELECT id FROM patients WHERE id = ?').get(patientId);
  if (!patient) return { status: 404, error: 'Patient not found' };
  return null;
}

/** Existence (404), authorship (403), then current access to the row's patient (403). Returns { err, row }. */
export async function loadOwned(db, table, authorCol, id, user, label) {
  const row = await db.prepare(`SELECT * FROM ${table} WHERE id = ?`).get(id);
  if (!row) return { err: { status: 404, error: `${label} not found` } };
  if (String(row[authorCol]) !== String(user.id)) return { err: { status: 403, error: 'Only the author can change this' } };
  const accessErr = await guardPatient(db, user, row.patient_id);
  if (accessErr) return { err: accessErr };
  return { row };
}
