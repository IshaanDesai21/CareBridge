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

import calendar from '../src/routes/calendar.js';

const caregiver = { id: 2, role: 'caregiver' };
const family = { id: 3, role: 'family' };

function makeDb({ linked = true, patient = { id: 1 }, dates = {}, rows = {} } = {}) {
  return fakeDb([
    [/SELECT organization_id FROM users/, { get: () => ({ organization_id: null }) }],
    [/FROM family_patient_links/, { get: () => (linked ? { linked: 1 } : undefined) }],
    [/SELECT id FROM patients WHERE id = \?/, { get: () => patient }],
    [/FROM wellness_checkins WHERE patient_id = \? AND date LIKE/, { all: () => (dates.checkin ?? []).map((d) => ({ d })) }],
    [/FROM dose_logs WHERE patient_id = \? AND local_date LIKE/, { all: () => (dates.dose ?? []).map((d) => ({ d })) }],
    [/FROM pill_checks\s+WHERE patient_id = \? AND status = 'fail' AND resolved_by_check_id IS NULL AND local_date LIKE/, { all: () => (dates.flag ?? []).map((d) => ({ d })) }],
    [/FROM patient_notes WHERE patient_id = \? AND local_date LIKE/, { all: () => (dates.pnote ?? []).map((d) => ({ d })) }],
    [/FROM care_notes\s+WHERE patient_id = \? AND COALESCE/, { all: () => (dates.cnote ?? []).map((d) => ({ d })) }],
    [/FROM meals WHERE patient_id = \? AND local_date LIKE/, { all: () => (dates.meal ?? []).map((d) => ({ d })) }],
    [/FROM wellness_checkins WHERE/, { all: () => rows.checkins ?? [] }],
    [/FROM medications WHERE/, { all: () => rows.medications ?? [] }],
    [/FROM dose_logs dl/, { all: () => rows.doseLogs ?? [] }],
    [/FROM pill_checks/, { all: () => rows.failedChecks ?? [] }],
    [/FROM meals ml/, { all: () => rows.meals ?? [] }],
    [/FROM care_notes cn/, { all: () => rows.careNotes ?? [] }],
    [/FROM patient_notes pn/, { all: () => rows.patientNotes ?? [] }],
  ]);
}
const month = (m, user = family, patientId = '1') =>
  invokeRoute(calendar, 'get', '/:patientId', { params: { patientId }, query: { month: m }, user });
const day = (date, user = family, patientId = '1') =>
  invokeRoute(calendar, 'get', '/:patientId/day/:date', { params: { patientId, date }, user });

describe('calendar month', () => {
  test('200 with month shape and day flags', async () => {
    mockDb = makeDb({ dates: { dose: ['2026-10-03'], flag: ['2026-10-04'], cnote: ['2026-10-05'], meal: ['2026-10-06'], checkin: ['2026-10-01'] } });
    const r = await month('2026-10');
    expect(r.status).toBe(200);
    expect(r.body.month).toBe('2026-10');
    expect(r.body.days).toHaveLength(31);
    expect(r.body.days[0]).toMatchObject({ date: '2026-10-01', hasCheckin: true });
    expect(r.body.days[2].hasDoses).toBe(true);
    expect(r.body.days[3].hasFlag).toBe(true);
    expect(r.body.days[4].hasEntries).toBe(true);
    expect(r.body.days[5].hasEntries).toBe(true);
  });

  test('month query uses LIKE prefix and unresolved-fail flags', async () => {
    mockDb = makeDb();
    await month('2026-10');
    const flag = mockDb.calls.find((c) => /FROM pill_checks/.test(c.sql));
    expect(flag.sql).toMatch(/status = 'fail' AND resolved_by_check_id IS NULL/);
    expect(flag.params).toEqual(['1', '2026-10-%']);
  });

  test('legacy care notes (NULL local_date) count by created_at', async () => {
    mockDb = makeDb();
    await month('2026-10');
    const cn = mockDb.calls.find((c) => /FROM care_notes/.test(c.sql));
    expect(cn.sql).toMatch(/COALESCE\(local_date, to_char\(created_at, 'YYYY-MM-DD'\)\)/);
  });

  test.each(['2026-13', '2026-1', 'banana', undefined, '2026-00'])('bad month %s -> 400', async (m) => {
    mockDb = makeDb();
    const r = await month(m);
    expect(r.status).toBe(400);
    expect(r.body.error).toBe('Invalid month');
  });

  test('no access -> 403', async () => {
    mockDb = makeDb({ linked: false });
    const r = await month('2026-10');
    expect(r.status).toBe(403);
    expect(r.body.error).toBe('Access denied');
  });

  test('nonexistent patient -> 404', async () => {
    mockDb = makeDb({ patient: null });
    const r = await month('2026-10', caregiver, '99');
    expect(r.status).toBe(404);
    expect(r.body.error).toBe('Patient not found');
  });
});

describe('calendar day', () => {
  test('200 passes rows through to day payload', async () => {
    mockDb = makeDb({
      rows: {
        medications: [{ id: 10, name: 'Lisinopril', strength: '10 mg', doses_per_day: 2, as_needed: 0, is_active: 1 }],
        doseLogs: [{ id: 1, medication_id: 10, name: 'Lisinopril', strength: '10 mg', pill_count: 1, source: 'photo', strength_verified: 1, given_at: '2026-10-19T08:00:00Z' }],
        careNotes: [{ id: 5, caregiver_id: 2, content: 'Calm day', author_first_name: 'Ann', author_last_name: 'Lee', created_at: '2026-10-19T09:00:00Z' }],
        patientNotes: [{ id: 6, author_user_id: 9, content: 'Felt ok', author_first_name: 'Pat', author_last_name: null, created_at: '2026-10-19T10:00:00Z' }],
      },
    });
    const r = await day('2026-10-19');
    expect(r.status).toBe(200);
    expect(r.body.day.date).toBe('2026-10-19');
    expect(JSON.stringify(r.body.day)).toContain('Calm day');
    expect(JSON.stringify(r.body.day)).toContain('Ann Lee');
    expect(JSON.stringify(r.body.day)).toContain('Felt ok');
    expect(JSON.stringify(r.body.day)).toContain('Lisinopril');
  });

  test('care notes fall back to created_at date when local_date is NULL; meds not filtered by active', async () => {
    mockDb = makeDb();
    await day('2026-10-19');
    const cn = mockDb.calls.find((c) => /FROM care_notes cn/.test(c.sql));
    expect(cn.sql).toMatch(/cn\.local_date IS NULL AND to_char\(cn\.created_at, 'YYYY-MM-DD'\) = \?/);
    expect(cn.params).toEqual(['1', '2026-10-19', '2026-10-19']);
    const med = mockDb.calls.find((c) => /FROM medications WHERE/.test(c.sql));
    expect(med.sql).not.toMatch(/is_active = 1/);
  });

  test.each(['banana', '2026-02-30', '2026-13-01'])('bad date %s -> 400', async (d) => {
    mockDb = makeDb();
    const r = await day(d);
    expect(r.status).toBe(400);
    expect(r.body.error).toBe('Invalid date');
  });

  test('no access -> 403', async () => {
    mockDb = makeDb({ linked: false });
    expect((await day('2026-10-19')).status).toBe(403);
  });

  test('nonexistent patient -> 404', async () => {
    mockDb = makeDb({ patient: null });
    expect((await day('2026-10-19', caregiver, '99')).status).toBe(404);
  });
});
