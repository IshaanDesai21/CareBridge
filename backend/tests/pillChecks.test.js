import { describe, test, expect, vi } from 'vitest';
import { invokeRoute } from './helpers/invokeRoute.js';
import { fakeDb } from './helpers/fakeDb.js';

vi.mock('../src/utils/auth.js', () => ({
  authenticateToken: (_req, _res, next) => next(),
}));
vi.mock('../src/utils/logger.js', () => ({
  default: { error: vi.fn(), info: vi.fn(), warn: vi.fn() },
}));
let mockDb;
vi.mock('../src/database/db.js', () => ({
  get getDb() {
    return () => mockDb;
  },
}));

import pillChecks from '../src/routes/pillChecks.js';
import doseLogs from '../src/routes/doseLogs.js';

const caregiver = { id: 2, role: 'caregiver' };
const med = {
  id: 10, patient_id: 1, name: 'Lisinopril', strength: '10 mg', form: 'tablet',
  pills_per_dose_min: 1, pills_per_dose_max: 2, doses_per_day: 2, as_needed: 0, is_active: 1,
};
const lisin = [{ label: 'lisinopril', confidence: 0.9, imprint: 'X', box: [1, 2, 3, 4] }];

function makeDb({ meds = [med], failures = [], doseRows = [], patient = { id: 1 } } = {}) {
  return fakeDb([
    [/FROM dose_logs d JOIN medications m/, { all: () => doseRows }],
    [/SELECT organization_id FROM users/, { get: () => ({ organization_id: null }) }],
    [/SELECT id FROM patients WHERE id = \?/, { get: () => patient }],
    [/FROM medications/, {
      all: () => meds.filter((m) => m.is_active === 1),
      get: (id) => meds.find((m) => m.id === id && m.is_active === 1),
    }],
    [/FROM pill_checks/, { all: (_pid, src) => failures.filter((f) => !f.source || f.source === src) }],
    [/INSERT INTO pill_checks/, { run: () => ({ lastInsertRowid: 55 }) }],
    [/INSERT INTO dose_logs/, { run: () => ({ lastInsertRowid: 1 }) }],
    [/UPDATE pill_checks/, { run: () => ({ changes: 1 }) }],
  ]);
}
const post = (body, user = caregiver) => invokeRoute(pillChecks, 'post', '/', { body, user });
const manual = (body, user = caregiver) => invokeRoute(doseLogs, 'post', '/manual', { body, user });
const callsMatching = (db, re) => db.calls.filter((c) => re.test(c.sql));

describe('pill checks', () => {
  test('family role -> 403', async () => {
    mockDb = makeDb();
    const r = await post({ patientId: 1, localDate: '2026-10-19', detections: [] }, { id: 3, role: 'family' });
    expect(r.status).toBe(403);
    expect(r.body.error).toBe('Only caregivers can log doses');
  });

  test('bad localDate / detections / patientId -> 400', async () => {
    mockDb = makeDb();
    expect((await post({ patientId: 1, localDate: '10/19/2026', detections: [] })).status).toBe(400);
    expect((await post({ patientId: 1, localDate: '2026-10-19', detections: 'x' })).status).toBe(400);
    expect((await post({ patientId: 1, localDate: '2026-10-19', detections: [1] })).status).toBe(400);
    expect((await post({ patientId: 'abc', localDate: '2026-10-19', detections: [] })).status).toBe(400);
    expect((await post({ patientId: 0, localDate: '2026-10-19', detections: [] })).status).toBe(400);
  });

  test('missing patient -> 404', async () => {
    mockDb = makeDb({ patient: null });
    const r = await post({ patientId: 1, localDate: '2026-10-19', detections: lisin });
    expect(r.status).toBe(404);
    expect(r.body.error).toBe('Patient not found');
  });

  test('pass inserts check + one dose per dose and resolves eligible failures', async () => {
    const failures = [
      { id: 40, problems: JSON.stringify([{ code: 'count_mismatch', medicationId: 10 }]), age_ms: '60000' },
      { id: 41, problems: JSON.stringify([{ code: 'count_mismatch', medicationId: 99 }]), age_ms: '60000' },
    ];
    mockDb = makeDb({ failures });
    const r = await post({ patientId: 1, localDate: '2026-10-19', detections: lisin });
    expect(r.status).toBe(201);
    expect(r.body.check).toMatchObject({
      id: 55, status: 'pass', problems: [],
      doses: [{ medicationId: 10, name: 'Lisinopril', strength: '10 mg', pillCount: 1 }],
    });
    const chk = callsMatching(mockDb, /INSERT INTO pill_checks/)[0];
    expect(chk.params).toContain('pass');
    expect(chk.params).toContain(JSON.stringify([{ label: 'lisinopril', confidence: 0.9, imprint: 'X' }]));
    expect(callsMatching(mockDb, /INSERT INTO dose_logs/)).toHaveLength(1);
    const upd = callsMatching(mockDb, /UPDATE pill_checks/);
    expect(upd).toHaveLength(1);
    expect(upd[0].params).toEqual([55, 40]);
  });

  test('fail inserts fail check with problems JSON and no dose_logs', async () => {
    mockDb = makeDb();
    const r = await post({ patientId: 1, localDate: '2026-10-19', detections: [] });
    expect(r.status).toBe(201);
    expect(r.body.check.status).toBe('fail');
    expect(r.body.check.doses).toEqual([]);
    const chk = callsMatching(mockDb, /INSERT INTO pill_checks/)[0];
    expect(chk.params).toContain('fail');
    const problemsJson = chk.params.find((p) => typeof p === 'string' && p.includes('no_pills'));
    expect(JSON.parse(problemsJson)[0].code).toBe('no_pills');
    expect(callsMatching(mockDb, /INSERT INTO dose_logs/)).toHaveLength(0);
    expect(callsMatching(mockDb, /UPDATE pill_checks/)).toHaveLength(0);
  });

  test('photo check loads only active medications for the patient', async () => {
    mockDb = makeDb();
    await post({ patientId: 1, localDate: '2026-10-19', detections: lisin });
    const q = callsMatching(mockDb, /FROM medications/)[0];
    expect(q.sql).toMatch(/is_active = 1/);
    expect(q.params).toEqual([1]);
  });

  test('correction window is computed in SQL; age_ms drives eligibility', async () => {
    const failures = [
      { id: 40, problems: JSON.stringify([{ code: 'x', medicationId: 10 }]), age_ms: 29 * 60 * 1000 },
      { id: 41, problems: JSON.stringify([{ code: 'x', medicationId: 10 }]), age_ms: 31 * 60 * 1000 },
    ];
    mockDb = makeDb({ failures });
    await post({ patientId: 1, localDate: '2026-10-19', detections: lisin });
    const q = callsMatching(mockDb, /FROM pill_checks/)[0];
    expect(q.sql).toMatch(/EXTRACT\(EPOCH FROM \(CURRENT_TIMESTAMP - created_at\)\) \* 1000 AS age_ms/);
    expect(q.sql).toMatch(/created_at > CURRENT_TIMESTAMP - INTERVAL '30 minutes'/);
    // 31-minute row is excluded by the engine's strict window even if SQL returned it
    expect(callsMatching(mockDb, /UPDATE pill_checks/)[0].params).toEqual([55, 40]);
  });
});

describe('manual dose', () => {
  const ok = { patientId: 1, medicationId: 10, pillCount: 1, localDate: '2026-10-19' };

  test('manual pass inserts dose_logs source manual', async () => {
    mockDb = makeDb();
    const r = await manual(ok);
    expect(r.status).toBe(201);
    expect(r.body.check).toMatchObject({
      status: 'pass', doses: [{ medicationId: 10, name: 'Lisinopril', strength: '10 mg', pillCount: 1 }],
    });
    expect(callsMatching(mockDb, /INSERT INTO pill_checks/)[0].params).toContain('manual');
    expect(callsMatching(mockDb, /INSERT INTO dose_logs/)[0].params).toContain('manual');
  });

  test('manual over max inserts fail check source manual', async () => {
    mockDb = makeDb();
    const r = await manual({ ...ok, pillCount: 5 });
    expect(r.status).toBe(201);
    expect(r.body.check.status).toBe('fail');
    expect(callsMatching(mockDb, /INSERT INTO pill_checks/)[0].params).toEqual(expect.arrayContaining(['manual', 'fail']));
    expect(callsMatching(mockDb, /INSERT INTO dose_logs/)).toHaveLength(0);
  });

  test('inactive / foreign / missing medication -> 404', async () => {
    mockDb = makeDb({ meds: [] });
    const r = await manual(ok);
    expect(r.status).toBe(404);
    expect(r.body.error).toBe('Medication not found');
    const sql = callsMatching(mockDb, /FROM medications/)[0].sql;
    expect(sql).toMatch(/patient_id = \?/);
    expect(sql).toMatch(/is_active = 1/);
  });

  test('missing patient -> 404; family -> 403; validation -> 400', async () => {
    mockDb = makeDb({ patient: null });
    expect((await manual(ok)).body.error).toBe('Patient not found');
    mockDb = makeDb();
    expect((await manual(ok, { id: 3, role: 'family' })).status).toBe(403);
    expect((await manual({ ...ok, pillCount: 0 })).status).toBe(400);
    expect((await manual({ ...ok, pillCount: 1.5 })).status).toBe(400);
    expect((await manual({ ...ok, medicationId: 'x' })).status).toBe(400);
    expect((await manual({ ...ok, localDate: 'nope' })).status).toBe(400);
  });
});

describe('fix round 1', () => {
  const okDate = '2026-10-19';
  const failRow = (id, source) => ({
    id, source, problems: JSON.stringify([{ code: 'x', medicationId: 10 }]), age_ms: 60000,
  });

  test('organization role may log (201)', async () => {
    mockDb = makeDb();
    const r = await post({ patientId: 1, localDate: okDate, detections: lisin }, { id: 9, role: 'organization' });
    expect(r.status).toBe(201);
    mockDb = makeDb();
    const m = await manual({ patientId: 1, medicationId: 10, pillCount: 1, localDate: okDate }, { id: 9, role: 'organization' });
    expect(m.status).toBe(201);
  });

  test('manual pass does not resolve a photo failure', async () => {
    mockDb = makeDb({ failures: [failRow(40, 'photo')] });
    await manual({ patientId: 1, medicationId: 10, pillCount: 1, localDate: okDate });
    expect(callsMatching(mockDb, /FROM pill_checks/)[0].params).toEqual([1, 'manual']);
    expect(callsMatching(mockDb, /UPDATE pill_checks/)).toHaveLength(0);
  });

  test('photo pass does not resolve a manual failure', async () => {
    mockDb = makeDb({ failures: [failRow(41, 'manual')] });
    await post({ patientId: 1, localDate: okDate, detections: lisin });
    expect(callsMatching(mockDb, /FROM pill_checks/)[0].params).toEqual([1, 'photo']);
    expect(callsMatching(mockDb, /UPDATE pill_checks/)).toHaveLength(0);
  });

  test('same-source pass resolves; UPDATE only touches unresolved rows', async () => {
    mockDb = makeDb({ failures: [failRow(42, 'manual')] });
    await manual({ patientId: 1, medicationId: 10, pillCount: 1, localDate: okDate });
    const upd = callsMatching(mockDb, /UPDATE pill_checks/);
    expect(upd[0].params).toEqual([55, 42]);
    expect(upd[0].sql).toMatch(/resolved_by_check_id IS NULL/);
  });

  test('failed photo check issues no resolve UPDATE', async () => {
    mockDb = makeDb({ failures: [failRow(40, 'photo')] });
    const r = await post({ patientId: 1, localDate: okDate, detections: [] });
    expect(r.body.check.status).toBe('fail');
    expect(callsMatching(mockDb, /UPDATE pill_checks/)).toHaveLength(0);
  });

  test('detections validation -> 400', async () => {
    mockDb = makeDb();
    const bad = [
      Array.from({ length: 51 }, () => ({ label: 'lisinopril' })),
      [{ label: 5 }],
      [{ label: 'x'.repeat(33) }],
      [{ label: 'a', imprint: 'y'.repeat(65) }],
      [{ label: 'a', imprint: 5 }],
      [{ label: 'a', confidence: '0.9' }],
    ];
    for (const detections of bad) {
      expect((await post({ patientId: 1, localDate: okDate, detections })).status).toBe(400);
    }
    const good = await post({ patientId: 1, localDate: okDate, detections: [{ label: 'a', imprint: null, confidence: 0.5 }] });
    expect(good.status).toBe(201);
  });
});

describe('daily maximum by drug across medication rows', () => {
  const okDate = '2026-10-19';
  // Refill: old row (now inactive) already has 2 pills logged today; new active row allows 1 x 2/day = 2.
  const oldRow = { ...med, id: 9, name: 'Lisinopril 10 mg', is_active: 0 };
  const newRow = { ...med, id: 10, pills_per_dose_min: 1, pills_per_dose_max: 1, doses_per_day: 2 };
  const doseRows = [{ name: 'Lisinopril 10 mg', pill_count: 1 }, { name: 'Lisinopril 10 mg', pill_count: 1 }];

  test('totals query joins medications and is not grouped by medication_id', async () => {
    mockDb = makeDb({ meds: [oldRow, newRow], doseRows });
    await manual({ patientId: 1, medicationId: 10, pillCount: 1, localDate: okDate });
    const q = callsMatching(mockDb, /FROM dose_logs/)[0];
    expect(q.sql).not.toMatch(/GROUP BY medication_id/);
    expect(q.params).toEqual([1, okDate]);
  });

  test('manual: refill row inherits the old row\'s pills -> over_daily_max', async () => {
    mockDb = makeDb({ meds: [oldRow, newRow], doseRows });
    const r = await manual({ patientId: 1, medicationId: 10, pillCount: 1, localDate: okDate });
    expect(r.body.check.status).toBe('fail');
    expect(r.body.check.problems.map((p) => p.code)).toEqual(['over_daily_max']);
    expect(callsMatching(mockDb, /INSERT INTO dose_logs/)).toHaveLength(0);
  });

  test('photo: refill row inherits the old row\'s pills -> over_daily_max', async () => {
    mockDb = makeDb({ meds: [oldRow, newRow], doseRows });
    const r = await post({ patientId: 1, localDate: okDate, detections: lisin });
    expect(r.body.check.status).toBe('fail');
    expect(r.body.check.problems.map((p) => p.code)).toEqual(['over_daily_max']);
  });

  test('photo: pills logged under a differently-named row of the same drug count', async () => {
    mockDb = makeDb({ meds: [newRow], doseRows: [{ name: 'LISINOPRIL tabs', pill_count: 2 }] });
    const r = await post({ patientId: 1, localDate: okDate, detections: lisin });
    expect(r.body.check.problems.map((p) => p.code)).toEqual(['over_daily_max']);
    mockDb = makeDb({ meds: [newRow], doseRows: [{ name: 'Atorvastatin', pill_count: 2 }] });
    expect((await post({ patientId: 1, localDate: okDate, detections: lisin })).body.check.status).toBe('pass');
  });

  test('manual: two active rows for the same drug -> duplicate_medication fail check', async () => {
    const dup = { ...med, id: 11, name: 'lisinopril 20 mg', strength: '20 mg' };
    mockDb = makeDb({ meds: [med, dup] });
    const r = await manual({ patientId: 1, medicationId: 10, pillCount: 1, localDate: okDate });
    expect(r.status).toBe(201);
    expect(r.body.check.status).toBe('fail');
    expect(r.body.check.problems).toEqual([{
      code: 'duplicate_medication', label: 'Lisinopril',
      message: 'Lisinopril is listed more than once. Remove the old entry before checking.',
    }]);
    expect(callsMatching(mockDb, /INSERT INTO pill_checks/)[0].params).toEqual(expect.arrayContaining(['manual', 'fail']));
    expect(callsMatching(mockDb, /INSERT INTO dose_logs/)).toHaveLength(0);
  });

  test('manual: non-target duplicate by normalized name also fails', async () => {
    const a = { ...med, id: 10, name: 'Metformin 500 mg' };
    const b = { ...med, id: 12, name: 'metformin  1000mg' };
    mockDb = makeDb({ meds: [a, b] });
    const r = await manual({ patientId: 1, medicationId: 10, pillCount: 1, localDate: okDate });
    expect(r.body.check.problems[0]).toMatchObject({ code: 'duplicate_medication', label: 'Metformin' });
  });
});
