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

function makeDb() {
  return fakeDb([
    [/SELECT organization_id FROM users/, { get: () => ({ organization_id: null }) }],
    [/INSERT INTO medications/, { run: () => ({ lastInsertRowid: 7 }) }],
    [/UPDATE medications/, { run: () => ({ changes: 1 }) }],
    [/SELECT \* FROM medications/, { get: () => ({ id: 7, patient_id: 1 }) }],
  ]);
}

function hasSequence(params, seq) {
  for (let i = 0; i + seq.length <= params.length; i++) {
    if (seq.every((v, j) => params[i + j] === v)) return true;
  }
  return false;
}

describe('structured medication fields', () => {
  test('POST stores form, strength, pills/dose range, doses/day, asNeeded', async () => {
    mockDb = makeDb();
    const { status } = await invokeRoute(router, 'post', '/', {
      user: { id: 1, role: 'caregiver' },
      body: { patientId: 1, name: 'Benzonatate', dosage: '100 mg', form: 'capsule',
        pillsPerDoseMin: 1, pillsPerDoseMax: 2, dosesPerDay: 3, asNeeded: true },
    });
    expect(status).toBe(201);
    const ins = mockDb.calls.find((c) => /INSERT INTO medications/.test(c.sql));
    expect(hasSequence(ins.params, ['capsule', '100 mg', 1, 2, 3, 1])).toBe(true);
  });

  test('POST with only max sets min and max to it', async () => {
    mockDb = makeDb();
    await invokeRoute(router, 'post', '/', {
      user: { id: 1, role: 'caregiver' },
      body: { patientId: 1, name: 'X', dosage: '5 mg', pillsPerDoseMax: 2 },
    });
    const ins = mockDb.calls.find((c) => /INSERT INTO medications/.test(c.sql));
    expect(hasSequence(ins.params, ['5 mg', 2, 2])).toBe(true);
  });

  test('PUT with dosesPerDay only passes null for the other new fields', async () => {
    mockDb = makeDb();
    await invokeRoute(router, 'put', '/:medicationId', {
      user: { id: 1, role: 'caregiver' }, params: { medicationId: '7' }, body: { dosesPerDay: 2 },
    });
    const upd = mockDb.calls.find((c) => /UPDATE medications/.test(c.sql));
    expect(upd.sql).toMatch(/doses_per_day = COALESCE/);
    // tail: form, strength, min, max, doses, as_needed, id
    expect(upd.params.slice(-7)).toEqual([null, null, null, null, 2, null, 7]);
  });
});
