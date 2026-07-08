/**
 * Unit tests for the medication verification endpoint.
 *
 * We mock getDb and authenticateToken so no running database or real tokens
 * are needed. The route handler is invoked directly without starting an HTTP
 * server, following the same pattern as parse-med-validation.test.js.
 */

import { describe, test, expect, vi, beforeEach, afterEach } from 'vitest';

// ── Module mocks ──────────────────────────────────────────────────────────────

// authenticateToken: bypass auth, inject a fake user
vi.mock('../src/utils/auth.js', () => ({
  authenticateToken: (req, _res, next) => {
    req.user = { id: 42 };
    next();
  },
}));

vi.mock('../src/utils/logger.js', () => ({
  default: { error: vi.fn(), info: vi.fn(), warn: vi.fn() },
}));

// getDb is set per-test via the `mockGetDb` variable below
let mockGetDb;
vi.mock('../src/database/db.js', () => ({
  get getDb() {
    return mockGetDb;
  },
}));

// ── Import router AFTER mocks ─────────────────────────────────────────────────

import router from '../src/routes/medicationVerification.js';

// ── Helpers ───────────────────────────────────────────────────────────────────

/**
 * Invoke POST /verify/:medicationId directly against the router stack.
 * Returns { status, body }.
 */
function callVerify(medicationId, body) {
  return new Promise((resolve) => {
    const req = {
      method: 'POST',
      url: `/verify/${medicationId}`,
      path: `/verify/${medicationId}`,
      params: { medicationId: String(medicationId) },
      body,
      user: { id: 42 },
    };

    let statusCode = 200;
    const res = {
      status(code) {
        statusCode = code;
        return res;
      },
      json(payload) {
        resolve({ status: statusCode, body: payload });
      },
    };

    // Find the POST /verify/:medicationId layer in the router stack
    const layer = router.stack.find(
      (l) => l.route?.path === '/verify/:medicationId' && l.route?.methods?.post
    );
    if (!layer) throw new Error('POST /verify/:medicationId route not found in router stack');

    const handlers = layer.route.stack.map((h) => h.handle);
    let idx = 0;
    const next = (err) => {
      if (err) return resolve({ status: 500, body: { error: String(err) } });
      const fn = handlers[idx++];
      if (fn) fn(req, res, next);
    };
    next();
  });
}

// ── Tests ─────────────────────────────────────────────────────────────────────

describe('Medication Verification endpoint', () => {
  afterEach(() => {
    vi.clearAllMocks();
  });

  test('returns status "match" when pill names match the medication name', async () => {
    mockGetDb = () => ({
      prepare: (sql) => ({
        get: vi.fn().mockResolvedValue({ id: 1, name: 'Metformin' }),
        run: vi.fn().mockResolvedValue({ lastInsertRowid: 10, changes: 1 }),
      }),
    });

    const { status, body } = await callVerify(1, {
      pills: [{ name: 'Metformin', imprint: 'M523' }],
    });

    expect(status).toBe(200);
    expect(body.verification).toBeDefined();
    expect(body.verification.status).toBe('match');
    expect(body.verification.expected).toBe('Metformin');
    expect(body.verification.medicationId).toBe('1');
  });

  test('returns status "mismatch" when pill names do not match the medication name', async () => {
    mockGetDb = () => ({
      prepare: (sql) => ({
        get: vi.fn().mockResolvedValue({ id: 1, name: 'Metformin' }),
        run: vi.fn().mockResolvedValue({ lastInsertRowid: 11, changes: 1 }),
      }),
    });

    const { status, body } = await callVerify(1, {
      pills: [{ name: 'Lisinopril', imprint: 'LIS10' }],
    });

    expect(status).toBe(200);
    expect(body.verification).toBeDefined();
    expect(body.verification.status).toBe('mismatch');
    expect(body.verification.expected).toBe('Metformin');
  });

  test('returns 404 when medication is not found', async () => {
    mockGetDb = () => ({
      prepare: (sql) => ({
        get: vi.fn().mockResolvedValue(undefined),
        run: vi.fn(),
      }),
    });

    const { status, body } = await callVerify(999, {
      pills: [{ name: 'Metformin', imprint: 'M523' }],
    });

    expect(status).toBe(404);
    expect(body.error).toMatch(/not found/i);
  });

  test('returns 400 when pills body is missing', async () => {
    // getDb should not be called at all for this case
    mockGetDb = () => ({
      prepare: () => ({ get: vi.fn(), run: vi.fn() }),
    });

    const { status, body } = await callVerify(1, {});

    expect(status).toBe(400);
    expect(body.error).toBeDefined();
  });

  test('returns 400 when pills array is empty', async () => {
    mockGetDb = () => ({
      prepare: () => ({ get: vi.fn(), run: vi.fn() }),
    });

    const { status, body } = await callVerify(1, { pills: [] });

    expect(status).toBe(400);
    expect(body.error).toBeDefined();
  });
});
