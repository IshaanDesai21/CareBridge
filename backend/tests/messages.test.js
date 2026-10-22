import { describe, test, expect, vi, beforeEach } from 'vitest';
import { invokeRoute } from './helpers/invokeRoute.js';
import { fakeDb } from './helpers/fakeDb.js';

vi.mock('../src/utils/auth.js', () => ({
  authenticateToken: (_req, _res, next) => next(),
}));
vi.mock('../src/utils/logger.js', () => ({
  default: { error: vi.fn(), info: vi.fn(), warn: vi.fn() },
}));
vi.mock('../src/utils/ws.js', () => ({ sendToUser: vi.fn() }));
let mockDb;
vi.mock('../src/database/db.js', () => ({
  get getDb() {
    return () => mockDb;
  },
}));

import messages from '../src/routes/messages.js';
import family from '../src/routes/family.js';
import { sendToUser } from '../src/utils/ws.js';

const patientUser = { id: 7, role: 'patient' };
const familyUser = { id: 3, role: 'family' };
const caregiver = { id: 2, role: 'caregiver' };

const row = (id, over = {}) => ({
  id, patient_id: 1, sender_user_id: 7, content: `m${id}`, created_at: '2026-10-19T10:00:00Z',
  first_name: 'Pat', last_name: 'Ient', role: 'patient', ...over,
});

// participants: users 7 (patient owner) and 3 (family) of patient 1; family 5 also linked.
function makeDb({ rows = [], unread = [] } = {}) {
  return fakeDb([
    [/FROM patients WHERE id = \? AND user_id = \?/, { get: (pid, uid) => (pid === 1 && uid === 7 ? { id: 1 } : undefined) }],
    [/FROM family_patient_links WHERE family_user_id = \? AND patient_id = \?/, {
      get: (uid, pid) => (pid === 1 && (uid === 3 || uid === 5) ? { linked: 1 } : undefined),
    }],
    [/SELECT user_id FROM patients WHERE id = \?/, { get: () => ({ user_id: 7 }) }],
    [/SELECT family_user_id FROM family_patient_links WHERE patient_id = \?/, {
      all: () => [{ family_user_id: 3 }, { family_user_id: 5 }],
    }],
    [/INSERT INTO family_messages/, { run: () => ({ lastInsertRowid: 42 }) }],
    [/INSERT INTO family_message_reads/, { run: () => ({ changes: 1 }) }],
    [/WHERE m\.id = \?/, { get: () => row(42, { sender_user_id: 3, first_name: 'Fam', last_name: 'Ily', role: 'family' }) }],
    [/FROM family_messages m/, { all: () => rows }],
    [/FROM \(\s*SELECT id AS patient_id/, { all: () => unread }],
    [/FROM family_patient_links fpl/, { all: () => [{ id: 1, email: 'a@b.c' }, { id: 2, email: 'd@e.f' }] }],
  ]);
}
const call = (router, method, path, o) => invokeRoute(router, method, path, o);
const sqlCalls = (re) => mockDb.calls.filter((c) => re.test(c.sql));

beforeEach(() => {
  sendToUser.mockClear();
});

describe('access (private conversation)', () => {
  test('caregiver GET -> 403 and no message query', async () => {
    mockDb = makeDb();
    const r = await call(messages, 'get', '/:patientId', { user: caregiver, params: { patientId: '1' } });
    expect(r.status).toBe(403);
    expect(r.body).toEqual({ error: 'Access denied' });
    expect(sqlCalls(/FROM family_messages/)).toHaveLength(0);
  });

  test('unlinked family GET/POST/read -> 403', async () => {
    mockDb = makeDb();
    const u = { id: 4, role: 'family' };
    expect((await call(messages, 'get', '/:patientId', { user: u, params: { patientId: '1' } })).status).toBe(403);
    expect((await call(messages, 'post', '/:patientId', { user: u, params: { patientId: '1' }, body: { content: 'hi' } })).status).toBe(403);
    expect((await call(messages, 'post', '/:patientId/read', { user: u, params: { patientId: '1' }, body: { lastReadMessageId: 1 } })).status).toBe(403);
    expect(sqlCalls(/INSERT/)).toHaveLength(0);
  });

  test('invalid patientId -> 400 before any DB access', async () => {
    mockDb = makeDb();
    for (const id of ['abc', '0', '-1', '1.5']) {
      expect((await call(messages, 'get', '/:patientId', { user: patientUser, params: { patientId: id } })).status).toBe(400);
      expect((await call(messages, 'post', '/:patientId', { user: patientUser, params: { patientId: id }, body: { content: 'x' } })).status).toBe(400);
      expect((await call(messages, 'post', '/:patientId/read', { user: patientUser, params: { patientId: id }, body: { lastReadMessageId: 1 } })).status).toBe(400);
    }
    expect(mockDb.calls).toHaveLength(0);
  });
});

describe('POST /:patientId', () => {
  const post = (body, user = familyUser) => call(messages, 'post', '/:patientId', { user, params: { patientId: '1' }, body });

  test('blank and 2001-char content -> 400', async () => {
    mockDb = makeDb();
    expect((await post({ content: '   ' })).status).toBe(400);
    expect((await post({ content: 'x'.repeat(2001) })).status).toBe(400);
    expect((await post({})).status).toBe(400);
    expect(sqlCalls(/INSERT/)).toHaveLength(0);
  });

  test('2000 chars accepted; content stored trimmed', async () => {
    mockDb = makeDb();
    expect((await post({ content: '  hello  ' })).status).toBe(201);
    expect(sqlCalls(/INSERT INTO family_messages/)[0].params).toEqual([1, 3, 'hello']);
    expect((await post({ content: 'x'.repeat(2000) })).status).toBe(201);
  });

  test('valid -> 201, same Message in response and push to each other participant, never the sender', async () => {
    mockDb = makeDb();
    const r = await post({ content: 'hello' });
    expect(r.status).toBe(201);
    expect(r.body.message).toEqual({
      id: 42, patientId: 1, senderUserId: 3, senderName: 'Fam Ily', senderRole: 'family',
      content: 'm42', createdAt: '2026-10-19T10:00:00Z',
    });
    expect(sendToUser).toHaveBeenCalledTimes(2);
    expect(sendToUser).toHaveBeenCalledWith(7, { type: 'family_message', message: r.body.message });
    expect(sendToUser).toHaveBeenCalledWith(5, { type: 'family_message', message: r.body.message });
    expect(sendToUser.mock.calls.map((c) => c[0])).not.toContain(3);
  });
});

describe('GET /:patientId', () => {
  const get = (query, user = patientUser) => call(messages, 'get', '/:patientId', { user, params: { patientId: '1' }, query });

  test('default limit 50, newest page returned ascending', async () => {
    mockDb = makeDb({ rows: [row(9), row(8), row(7)] });
    const r = await get({});
    expect(r.status).toBe(200);
    expect(r.body.messages.map((m) => m.id)).toEqual([7, 8, 9]);
    expect(sqlCalls(/FROM family_messages/)[0].params).toEqual([1, 50]);
  });

  test('before=10 binds 10 and limit param', async () => {
    mockDb = makeDb({ rows: [row(9), row(8)] });
    const r = await get({ before: '10', limit: '20' });
    expect(r.body.messages.map((m) => m.id)).toEqual([8, 9]);
    const q = sqlCalls(/FROM family_messages/)[0];
    expect(q.sql).toMatch(/m\.id < \?/);
    expect(q.params).toEqual([1, 10, 20]);
  });

  test('invalid limit/before -> 400', async () => {
    mockDb = makeDb();
    for (const q of [{ limit: '0' }, { limit: '101' }, { limit: 'x' }, { limit: '1.5' }, { before: '0' }, { before: 'abc' }]) {
      expect((await get(q)).status).toBe(400);
    }
  });
});

describe('POST /:patientId/read', () => {
  const read = (body) => call(messages, 'post', '/:patientId/read', { user: familyUser, params: { patientId: '1' }, body });

  test('upserts with GREATEST and params', async () => {
    mockDb = makeDb();
    const r = await read({ lastReadMessageId: 17 });
    expect(r.body).toEqual({ ok: true });
    const c = sqlCalls(/INSERT INTO family_message_reads/)[0];
    expect(c.sql).toMatch(/ON CONFLICT \(user_id, patient_id\) DO UPDATE SET/);
    expect(c.sql).toMatch(/GREATEST\(family_message_reads\.last_read_message_id, EXCLUDED\.last_read_message_id\)/);
    expect(c.params).toEqual([3, 1, 17]);
  });

  test('invalid lastReadMessageId -> 400', async () => {
    mockDb = makeDb();
    for (const v of [0, -1, 1.5, '5', null, undefined]) {
      expect((await read({ lastReadMessageId: v })).status).toBe(400);
    }
  });
});

describe('GET /unread', () => {
  test('returns counts incl. zero entries; excludes own messages; scoped to caller', async () => {
    mockDb = makeDb({ unread: [{ patient_id: 1, unread_count: '3' }, { patient_id: 2, unread_count: '0' }] });
    const r = await call(messages, 'get', '/unread', { user: familyUser });
    expect(r.body).toEqual({ unread: [{ patientId: 1, count: 3 }, { patientId: 2, count: 0 }] });
    const c = mockDb.calls[0];
    expect(c.sql).toMatch(/sender_user_id IS DISTINCT FROM/);
    expect(c.sql).toMatch(/last_read_message_id/);
    expect(c.params).toEqual([3, 3, 3, 3]);
  });

  test('is declared before /:patientId', () => {
    const paths = messages.stack.filter((l) => l.route?.methods?.get).map((l) => l.route.path);
    expect(paths.indexOf('/unread')).toBeLessThan(paths.indexOf('/:patientId'));
  });
});

describe('GET /family/patients', () => {
  test('returns all linked patients', async () => {
    mockDb = makeDb();
    const r = await call(family, 'get', '/patients', { user: familyUser });
    expect(r.body.patients).toHaveLength(2);
    expect(mockDb.calls[0].params).toEqual([3]);
  });
});
