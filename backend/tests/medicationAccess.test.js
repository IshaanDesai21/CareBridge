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

import router from '../src/routes/medications.js';

const caregiver = { id: 2, role: 'caregiver' };
const ownerPatient = { id: 7, role: 'patient' };
const otherPatient = { id: 8, role: 'patient' };
const family = { id: 3, role: 'family' };
const existing = { id: 5, patient_id: 1, name: 'Lisinopril', pills_per_dose_min: 1, pills_per_dose_max: 2, is_active: 1 };

function makeDb({ med = existing, linked = true, orgMismatch = false } = {}) {
  return fakeDb([
    [/SELECT id, user_id FROM patients/, { get: () => ({ id: 1, user_id: 7 }) }],
    [/FROM family_patient_links/, { get: () => (linked ? { linked: 1 } : undefined) }],
    [/SELECT organization_id FROM users/, { get: () => ({ organization_id: orgMismatch ? 9 : null }) }],
    [/SELECT p\.id FROM patients p/, { get: () => undefined }],
    [/SELECT \* FROM medications WHERE patient_id/, { all: () => [existing] }],
    [/SELECT \* FROM medications WHERE id/, { get: () => med }],
    [/INSERT INTO medications/, { run: () => ({ lastInsertRowid: 5 }) }],
    [/INSERT INTO medication_logs/, { run: () => ({ lastInsertRowid: 3 }) }],
    [/SELECT \* FROM medication_logs/, { get: () => ({ id: 3 }) }],
    [/UPDATE medications/, { run: () => ({ changes: 1 }) }],
    [/DELETE FROM medications/, { run: () => ({ changes: 1 }) }],
  ]);
}
const writes = () => mockDb.calls.filter((c) => /INSERT|UPDATE|DELETE/.test(c.sql));
const get = (patientId, user) => invokeRoute(router, 'get', '/:patientId', { params: { patientId }, user });
const create = (body, user = caregiver) =>
  invokeRoute(router, 'post', '/', { body: { patientId: 1, name: 'X', ...body }, user });
const update = (body, user = caregiver, medicationId = '5') =>
  invokeRoute(router, 'put', '/:medicationId', { params: { medicationId }, body, user });
const remove = (user = caregiver, medicationId = '5') =>
  invokeRoute(router, 'delete', '/:medicationId', { params: { medicationId }, user });
const log = (user = caregiver, medicationId = '5') =>
  invokeRoute(router, 'post', '/:medicationId/log', { params: { medicationId }, body: { scheduledTime: 'x' }, user });

describe('GET /:patientId', () => {
  test('bad id -> 400', async () => {
    mockDb = makeDb();
    expect((await get('abc', caregiver)).status).toBe(400);
  });
  test('no access -> 403 (unlinked family, other patient, other org)', async () => {
    mockDb = makeDb({ linked: false });
    expect((await get('1', family)).status).toBe(403);
    expect((await get('1', otherPatient)).status).toBe(403);
    mockDb = makeDb({ orgMismatch: true });
    expect((await get('1', caregiver)).status).toBe(403);
  });
  test('linked family / owner / caregiver -> 200 with numeric patient id', async () => {
    mockDb = makeDb();
    for (const u of [family, ownerPatient, caregiver]) {
      const r = await get('1', u);
      expect(r.status).toBe(200);
      expect(r.body.medications).toHaveLength(1);
    }
    expect(mockDb.calls.find((c) => /WHERE patient_id/.test(c.sql)).params).toEqual([1]);
  });
});

describe('POST /', () => {
  test('family -> 403; other patient -> 403; owner patient + caregiver -> 201', async () => {
    mockDb = makeDb();
    expect((await create({}, family)).status).toBe(403);
    expect((await create({}, otherPatient)).status).toBe(403);
    expect(writes()).toHaveLength(0);
    expect((await create({}, ownerPatient)).status).toBe(201);
    expect((await create({}, caregiver)).status).toBe(201);
  });
  test('bad patientId -> 400', async () => {
    mockDb = makeDb();
    expect((await create({ patientId: 'x' })).status).toBe(400);
  });
  test('dosing validation -> 400', async () => {
    mockDb = makeDb();
    const bad = [
      { pillsPerDoseMin: 0 }, { pillsPerDoseMax: 21 }, { dosesPerDay: 1.5 }, { dosesPerDay: '2' },
      { form: 'liquid' }, { pillsPerDoseMin: 3, pillsPerDoseMax: 2 },
    ];
    for (const b of bad) expect((await create(b)).status, JSON.stringify(b)).toBe(400);
    expect(writes()).toHaveLength(0);
    expect((await create({ pillsPerDoseMin: 1, pillsPerDoseMax: 20, dosesPerDay: 20, form: 'capsule' })).status).toBe(201);
  });
});

describe('PUT /:medicationId', () => {
  test('missing -> 404; family -> 403; other patient -> 403', async () => {
    mockDb = makeDb({ med: null });
    expect((await update({ name: 'Y' })).status).toBe(404);
    mockDb = makeDb();
    expect((await update({ name: 'Y' }, family)).status).toBe(403);
    expect((await update({ name: 'Y' }, otherPatient)).status).toBe(403);
    expect(writes()).toHaveLength(0);
    expect((await update({ name: 'Y' }, ownerPatient)).status).toBe(200);
  });
  test('validation incl. merged min <= max -> 400', async () => {
    mockDb = makeDb();
    expect((await update({ pillsPerDoseMin: 3 })).status).toBe(400); // existing max 2
    expect((await update({ pillsPerDoseMax: 0 })).status).toBe(400);
    expect((await update({ form: 'gel' })).status).toBe(400);
    expect((await update({ dosesPerDay: 21 })).status).toBe(400);
    expect(writes()).toHaveLength(0);
    expect((await update({ pillsPerDoseMin: 2 })).status).toBe(200);
  });
});

describe('DELETE /:medicationId', () => {
  test('soft delete', async () => {
    mockDb = makeDb();
    const r = await remove();
    expect(r).toEqual({ status: 200, body: { success: true } });
    const w = writes();
    expect(w).toHaveLength(1);
    expect(w[0].sql).toMatch(/UPDATE medications SET is_active = 0, updated_at = CURRENT_TIMESTAMP WHERE id = \?/);
    expect(w[0].params).toEqual([5]);
  });
  test('missing -> 404; family -> 403; other patient -> 403', async () => {
    mockDb = makeDb({ med: null });
    expect((await remove()).status).toBe(404);
    mockDb = makeDb();
    expect((await remove(family)).status).toBe(403);
    expect((await remove(otherPatient)).status).toBe(403);
    expect(writes()).toHaveLength(0);
  });
});

describe('POST /:medicationId/log (legacy)', () => {
  test('guarded like other writes', async () => {
    mockDb = makeDb({ med: null });
    expect((await log()).status).toBe(404);
    mockDb = makeDb();
    expect((await log(family)).status).toBe(403);
    expect((await log(otherPatient)).status).toBe(403);
    expect(writes()).toHaveLength(0);
    expect((await log(ownerPatient)).status).toBe(201);
  });
});
