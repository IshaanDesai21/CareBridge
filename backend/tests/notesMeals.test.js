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

import patientNotes from '../src/routes/patientNotes.js';
import meals from '../src/routes/meals.js';
import careNotes from '../src/routes/careNotes.js';

const patientUser = { id: 7, role: 'patient' };
const caregiver = { id: 2, role: 'caregiver' };
const family = { id: 3, role: 'family' };
const D = '2026-10-19';

// rows: map of table -> existing row (or null)
function makeDb({ owns = true, linked = true, patient = { id: 1 }, rows = {} } = {}) {
  return fakeDb([
    [/SELECT id, user_id FROM patients/, { get: () => (owns ? { id: 1, user_id: 7 } : { id: 1, user_id: 99 }) }],
    [/SELECT organization_id FROM users/, { get: () => ({ organization_id: null }) }],
    [/FROM family_patient_links/, { get: () => (linked ? { linked: 1 } : undefined) }],
    [/SELECT id FROM patients WHERE id = \?/, { get: () => patient }],
    [/INSERT INTO patient_notes/, { run: () => ({ lastInsertRowid: 11 }) }],
    [/INSERT INTO meals/, { run: () => ({ lastInsertRowid: 12 }) }],
    [/INSERT INTO care_notes/, { run: () => ({ lastInsertRowid: 13 }) }],
    [/SELECT \* FROM patient_notes/, { get: () => rows.patient_notes ?? null }],
    [/SELECT \* FROM meals/, { get: () => rows.meals ?? null }],
    [/SELECT \* FROM care_notes/, { get: () => rows.care_notes ?? null }],
    [/^\s*UPDATE |^\s*DELETE /, { run: () => ({ changes: 1 }) }],
  ]);
}
const call = (router, method, path, body, user, params = {}) =>
  invokeRoute(router, method, path, { body, user, params });
const writes = (re) => mockDb.calls.filter((c) => re.test(c.sql));

describe('patient notes', () => {
  const body = { patientId: 1, content: 'Felt ok', localDate: D };

  test('family -> 403, caregiver -> 403', async () => {
    mockDb = makeDb();
    expect((await call(patientNotes, 'post', '/', body, family)).status).toBe(403);
    expect((await call(patientNotes, 'post', '/', body, caregiver)).status).toBe(403);
    expect(writes(/INSERT/)).toHaveLength(0);
  });

  test('patient who does not own the record -> 403', async () => {
    mockDb = makeDb({ owns: false });
    expect((await call(patientNotes, 'post', '/', body, patientUser)).status).toBe(403);
  });

  test('patient creates note -> 201 with local_date param', async () => {
    mockDb = makeDb({ rows: { patient_notes: { id: 11, content: 'Felt ok' } } });
    const r = await call(patientNotes, 'post', '/', body, patientUser);
    expect(r.status).toBe(201);
    expect(r.body.note.id).toBe(11);
    expect(writes(/INSERT INTO patient_notes/)[0].params).toEqual([1, 7, 'Felt ok', D]);
  });

  test('validation 400s: empty, too long, bad/missing date', async () => {
    mockDb = makeDb();
    expect((await call(patientNotes, 'post', '/', { ...body, content: '  ' }, patientUser)).status).toBe(400);
    expect((await call(patientNotes, 'post', '/', { ...body, content: 'x'.repeat(2001) }, patientUser)).status).toBe(400);
    expect((await call(patientNotes, 'post', '/', { ...body, content: 'x'.repeat(2000) }, patientUser)).status).toBe(201);
    expect((await call(patientNotes, 'post', '/', { ...body, localDate: '10/19/2026' }, patientUser)).status).toBe(400);
    expect((await call(patientNotes, 'post', '/', { ...body, localDate: undefined }, patientUser)).status).toBe(400);
  });

  test('missing patient -> 404', async () => {
    mockDb = makeDb({ patient: null });
    expect((await call(patientNotes, 'post', '/', body, patientUser)).status).toBe(404);
  });

  test('PUT: missing -> 404, non-author -> 403, author -> 200', async () => {
    mockDb = makeDb();
    expect((await call(patientNotes, 'put', '/:id', { content: 'new' }, patientUser, { id: '11' })).status).toBe(404);
    mockDb = makeDb({ rows: { patient_notes: { id: 11, author_user_id: 99 } } });
    expect((await call(patientNotes, 'put', '/:id', { content: 'new' }, patientUser, { id: '11' })).status).toBe(403);
    mockDb = makeDb({ rows: { patient_notes: { id: 11, author_user_id: 7 } } });
    expect((await call(patientNotes, 'put', '/:id', { content: 'new' }, patientUser, { id: '11' })).status).toBe(200);
    expect((await call(patientNotes, 'put', '/:id', { content: '' }, patientUser, { id: '11' })).status).toBe(400);
  });

  test('family can never edit or delete', async () => {
    mockDb = makeDb({ rows: { patient_notes: { id: 11, author_user_id: 3 } } });
    expect((await call(patientNotes, 'put', '/:id', { content: 'x' }, family, { id: '11' })).status).toBe(403);
    expect((await call(patientNotes, 'delete', '/:id', {}, family, { id: '11' })).status).toBe(403);
    expect(writes(/UPDATE|DELETE/)).toHaveLength(0);
  });

  test('DELETE: non-author 403, author 200', async () => {
    mockDb = makeDb({ rows: { patient_notes: { id: 11, author_user_id: 99 } } });
    expect((await call(patientNotes, 'delete', '/:id', {}, patientUser, { id: '11' })).status).toBe(403);
    mockDb = makeDb({ rows: { patient_notes: { id: 11, author_user_id: 7 } } });
    expect((await call(patientNotes, 'delete', '/:id', {}, patientUser, { id: '11' })).status).toBe(200);
    expect(writes(/DELETE FROM patient_notes/)).toHaveLength(1);
  });
});

describe('meals', () => {
  const body = { patientId: 1, mealType: 'lunch', description: 'Soup', localDate: D };

  test('family -> 403', async () => {
    mockDb = makeDb();
    expect((await call(meals, 'post', '/', body, family)).status).toBe(403);
    expect(writes(/INSERT/)).toHaveLength(0);
  });

  test('patient POST -> 201 and INSERT params include local_date', async () => {
    mockDb = makeDb({ rows: { meals: { id: 12 } } });
    const r = await call(meals, 'post', '/', body, patientUser);
    expect(r.status).toBe(201);
    expect(r.body.meal.id).toBe(12);
    expect(writes(/INSERT INTO meals/)[0].sql).toMatch(/local_date/);
    expect(writes(/INSERT INTO meals/)[0].params).toEqual([1, 7, 'lunch', 'Soup', D]);
  });

  test('caregiver POST -> 201', async () => {
    mockDb = makeDb({ rows: { meals: { id: 12 } } });
    expect((await call(meals, 'post', '/', body, caregiver)).status).toBe(201);
  });

  test('mealType brunch -> 400; empty/long description -> 400; bad date -> 400', async () => {
    mockDb = makeDb();
    expect((await call(meals, 'post', '/', { ...body, mealType: 'brunch' }, patientUser)).status).toBe(400);
    expect((await call(meals, 'post', '/', { ...body, description: '' }, patientUser)).status).toBe(400);
    expect((await call(meals, 'post', '/', { ...body, description: 'x'.repeat(2001) }, patientUser)).status).toBe(400);
    expect((await call(meals, 'post', '/', { ...body, localDate: 'nope' }, patientUser)).status).toBe(400);
  });

  test('PUT non-author -> 403; missing -> 404', async () => {
    mockDb = makeDb({ rows: { meals: { id: 12, author_user_id: 99 } } });
    expect((await call(meals, 'put', '/:id', { description: 'Stew' }, patientUser, { id: '12' })).status).toBe(403);
    mockDb = makeDb();
    expect((await call(meals, 'put', '/:id', { description: 'Stew' }, patientUser, { id: '12' })).status).toBe(404);
  });

  test('PUT author -> 200; bad mealType -> 400', async () => {
    mockDb = makeDb({ rows: { meals: { id: 12, author_user_id: 7 } } });
    expect((await call(meals, 'put', '/:id', { description: 'Stew' }, patientUser, { id: '12' })).status).toBe(200);
    expect((await call(meals, 'put', '/:id', { mealType: 'brunch' }, patientUser, { id: '12' })).status).toBe(400);
  });

  test('DELETE author -> 200; non-author -> 403; family -> 403', async () => {
    mockDb = makeDb({ rows: { meals: { id: 12, author_user_id: 7 } } });
    expect((await call(meals, 'delete', '/:id', {}, patientUser, { id: '12' })).status).toBe(200);
    expect(writes(/DELETE FROM meals/)).toHaveLength(1);
    expect((await call(meals, 'delete', '/:id', {}, family, { id: '12' })).status).toBe(403);
    mockDb = makeDb({ rows: { meals: { id: 12, author_user_id: 99 } } });
    expect((await call(meals, 'delete', '/:id', {}, caregiver, { id: '12' })).status).toBe(403);
  });
});

describe('care notes', () => {
  const body = { patientId: 1, content: 'Calm', localDate: D };

  test('family and patient POST -> 403', async () => {
    mockDb = makeDb();
    expect((await call(careNotes, 'post', '/', body, family)).status).toBe(403);
    expect((await call(careNotes, 'post', '/', body, patientUser)).status).toBe(403);
  });

  test('caregiver POST stores local_date and NULL note_type', async () => {
    mockDb = makeDb({ rows: { care_notes: { id: 13 } } });
    const r = await call(careNotes, 'post', '/', body, caregiver);
    expect(r.status).toBe(201);
    const ins = writes(/INSERT INTO care_notes/)[0];
    expect(ins.sql).toMatch(/local_date/);
    expect(ins.params).toEqual([1, 2, null, 'Calm', D]);
  });

  test('localDate optional -> stored NULL; with noteType kept', async () => {
    mockDb = makeDb({ rows: { care_notes: { id: 13 } } });
    const r = await call(careNotes, 'post', '/', { patientId: 1, content: 'Hi', noteType: 'observation' }, caregiver);
    expect(r.status).toBe(201);
    expect(writes(/INSERT INTO care_notes/)[0].params).toEqual([1, 2, 'observation', 'Hi', null]);
  });

  test('bad localDate / noteType / content -> 400', async () => {
    mockDb = makeDb();
    expect((await call(careNotes, 'post', '/', { ...body, localDate: 'x' }, caregiver)).status).toBe(400);
    expect((await call(careNotes, 'post', '/', { ...body, noteType: 'bogus' }, caregiver)).status).toBe(400);
    expect((await call(careNotes, 'post', '/', { ...body, content: '' }, caregiver)).status).toBe(400);
    expect((await call(careNotes, 'post', '/', { ...body, content: 'x'.repeat(2001) }, caregiver)).status).toBe(400);
  });

  test('missing patient -> 404', async () => {
    mockDb = makeDb({ patient: null });
    expect((await call(careNotes, 'post', '/', body, caregiver)).status).toBe(404);
  });

  test('PUT: missing 404, non-author 403, author 200, family 403', async () => {
    mockDb = makeDb();
    expect((await call(careNotes, 'put', '/:noteId', { content: 'x' }, caregiver, { noteId: '13' })).status).toBe(404);
    mockDb = makeDb({ rows: { care_notes: { id: 13, caregiver_id: 99 } } });
    expect((await call(careNotes, 'put', '/:noteId', { content: 'x' }, caregiver, { noteId: '13' })).status).toBe(403);
    expect((await call(careNotes, 'put', '/:noteId', { content: 'x' }, family, { noteId: '13' })).status).toBe(403);
    mockDb = makeDb({ rows: { care_notes: { id: 13, caregiver_id: 2 } } });
    expect((await call(careNotes, 'put', '/:noteId', { content: 'x' }, caregiver, { noteId: '13' })).status).toBe(200);
  });
});
