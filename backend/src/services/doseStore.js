// Persistence for pill checks and dose logs. No Express here.
// NOTE: the db wrapper has no transaction support, so multi-statement writes are sequential awaits.
import { resolvableFailureIds } from './doseRules.js';
import { canAccessPatient } from '../utils/patientAccess.js';

export async function todayTotals(db, patientId, localDate) {
  const rows = await db.prepare(`
    SELECT medication_id, SUM(pill_count) AS total
    FROM dose_logs WHERE patient_id = ? AND local_date = ?
    GROUP BY medication_id
  `).all(patientId, localDate);
  const totals = {};
  for (const r of rows) totals[r.medication_id] = Number(r.total);
  return totals;
}

export async function recentUnresolvedFailures(db, patientId, nowMs = Date.now()) {
  const rows = await db.prepare(`
    SELECT id, problems, EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - created_at)) * 1000 AS age_ms
    FROM pill_checks
    WHERE patient_id = ? AND status = 'fail' AND resolved_by_check_id IS NULL
      AND created_at > CURRENT_TIMESTAMP - INTERVAL '30 minutes'
    ORDER BY created_at DESC
  `).all(patientId);
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
  await db.prepare(`UPDATE pill_checks SET resolved_by_check_id = ? WHERE id IN (${placeholders})`).run(byId, ...ids);
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
    const failures = await recentUnresolvedFailures(db, patientId, nowMs);
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

const isPosInt = (n) => Number.isInteger(n) && n > 0;

/** Role and shape checks shared by both routes. Returns {status, error} or null. */
export async function guardDoseRequest(db, user, { patientId, localDate }) {
  if (user?.role !== 'caregiver') return { status: 403, error: 'Only caregivers can log doses' };
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
