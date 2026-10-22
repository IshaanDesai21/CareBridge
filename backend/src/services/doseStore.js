// Persistence for pill checks and dose logs. No Express here.
// NOTE: the db wrapper has no transaction support, so multi-statement writes are sequential awaits.
import { resolvableFailureIds, drugKeyFor } from './doseRules.js';
import { canAccessPatient } from '../utils/patientAccess.js';

/**
 * Pills already logged on localDate, summed by drug key across ALL of the patient's medication rows
 * (active and inactive), so a refill row, duplicate row or deleted row never resets the daily maximum.
 * Returns { [drugKey]: total }.
 */
export async function todayTotalsByDrug(db, patientId, localDate) {
  const rows = await db.prepare(`
    SELECT m.name AS name, d.pill_count AS pill_count
    FROM dose_logs d JOIN medications m ON m.id = d.medication_id
    WHERE d.patient_id = ? AND d.local_date = ?
  `).all(patientId, localDate);
  const totals = {};
  for (const r of rows) {
    const key = drugKeyFor(r.name);
    totals[key] = (totals[key] ?? 0) + Number(r.pill_count);
  }
  return totals;
}

/** Per-medication-id view of todayTotalsByDrug for the given medications: { [medicationId]: total }. */
export async function todayTotals(db, patientId, localDate, medications) {
  const byDrug = await todayTotalsByDrug(db, patientId, localDate);
  const totals = {};
  for (const m of medications ?? []) totals[m.id] = byDrug[drugKeyFor(m.name)] ?? 0;
  return totals;
}

export async function recentUnresolvedFailures(db, patientId, source, nowMs = Date.now()) {
  const rows = await db.prepare(`
    SELECT id, problems, EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - created_at)) * 1000 AS age_ms
    FROM pill_checks
    WHERE patient_id = ? AND source = ? AND status = 'fail' AND resolved_by_check_id IS NULL
      AND created_at > CURRENT_TIMESTAMP - INTERVAL '30 minutes'
    ORDER BY created_at DESC
  `).all(patientId, source);
  return rows.map((r) => {
    let problems;
    try {
      problems = JSON.parse(r.problems);
    } catch {
      problems = [];
    }
    return {
      id: r.id,
      problems: Array.isArray(problems) ? problems : [],
      created_at: new Date(nowMs - Number(r.age_ms)),
    };
  });
}

export async function recordCheck(db, { patientId, performedBy, source, status, problems, detections, localDate }) {
  const result = await db.prepare(`
    INSERT INTO pill_checks (patient_id, performed_by, source, status, problems, detections, local_date)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  `).run(
    patientId, performedBy, source, status,
    JSON.stringify(problems ?? []), JSON.stringify(detections ?? []), localDate,
  );
  return result.lastInsertRowid;
}

export async function recordDoses(db, { patientId, checkId, source, loggedBy, localDate, doses }) {
  for (const d of doses) {
    await db.prepare(`
      INSERT INTO dose_logs (patient_id, medication_id, pill_check_id, source, pill_count, strength_verified, logged_by, local_date)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `).run(patientId, d.medicationId, checkId, source, d.pillCount, d.strengthVerified ? 1 : 0, loggedBy, localDate);
  }
}

export async function markResolved(db, ids, byId) {
  if (!ids.length) return;
  const placeholders = ids.map(() => '?').join(', ');
  await db.prepare(`UPDATE pill_checks SET resolved_by_check_id = ? WHERE resolved_by_check_id IS NULL AND id IN (${placeholders})`).run(byId, ...ids);
}

/**
 * Persist an evaluated check. On pass: insert check, insert doses, resolve eligible earlier failures.
 * On fail: insert the check only. Returns the response `check` object.
 */
export async function persistEvaluation(db, { patientId, user, source, evaluation, detections, localDate, medsById }) {
  const checkId = await recordCheck(db, {
    patientId, performedBy: user.id, source, status: evaluation.status,
    problems: evaluation.problems, detections, localDate,
  });
  let doses = [];
  if (evaluation.status === 'pass') {
    doses = evaluation.doses;
    await recordDoses(db, { patientId, checkId, source, loggedBy: user.id, localDate, doses });
    const nowMs = Date.now();
    const failures = await recentUnresolvedFailures(db, patientId, source, nowMs);
    const ids = resolvableFailureIds({
      failures,
      passedMedicationIds: doses.map((d) => d.medicationId),
      now: nowMs,
    });
    await markResolved(db, ids, checkId);
  }
  return {
    id: checkId,
    status: evaluation.status,
    problems: evaluation.problems,
    doses: doses.map((d) => ({
      medicationId: d.medicationId,
      name: medsById.get(d.medicationId)?.name ?? null,
      strength: medsById.get(d.medicationId)?.strength ?? null,
      pillCount: d.pillCount,
      strengthVerified: d.strengthVerified,
    })),
  };
}

export const stripBoxes = (detections) =>
  detections.map((d) => ({ label: d.label, confidence: d.confidence, imprint: d.imprint }));

/** Returns an error string or null. */
export function validateDetections(detections) {
  if (!Array.isArray(detections) || detections.length > 50) {
    return 'detections must be an array of at most 50 objects';
  }
  for (const d of detections) {
    if (d === null || typeof d !== 'object' || Array.isArray(d)) return 'detections must be an array of objects';
    if (typeof d.label !== 'string' || d.label.length > 32) return 'detection label must be a string of at most 32 characters';
    if (d.imprint != null && (typeof d.imprint !== 'string' || d.imprint.length > 64)) {
      return 'detection imprint must be a string of at most 64 characters';
    }
    if (d.confidence !== undefined && (typeof d.confidence !== 'number' || !Number.isFinite(d.confidence))) {
      return 'detection confidence must be a number';
    }
  }
  return null;
}

const isPosInt =(n) => Number.isInteger(n) && n > 0;

/** Role and shape checks shared by both routes. Returns {status, error} or null. */
export async function guardDoseRequest(db, user, { patientId, localDate }) {
  if (!['caregiver', 'organization'].includes(user?.role)) return { status: 403, error: 'Only caregivers can log doses' };
  if (!isPosInt(patientId)) return { status: 400, error: 'patientId must be a positive integer' };
  if (typeof localDate !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(localDate)) {
    return { status: 400, error: 'localDate must be YYYY-MM-DD' };
  }
  return null;
}

/** After shape validation: access (403) then existence (404). */
export async function guardPatient(db, user, patientId) {
  if (!(await canAccessPatient(db, user, patientId))) return { status: 403, error: 'Access denied' };
  const patient = await db.prepare('SELECT id FROM patients WHERE id = ?').get(patientId);
  if (!patient) return { status: 404, error: 'Patient not found' };
  return null;
}
