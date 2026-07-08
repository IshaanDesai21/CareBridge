/**
 * Integration tests for the full medication flow.
 *
 * Covers three scenarios using the same direct route-handler invocation
 * pattern as the unit tests — no HTTP server, no live database, no real API keys.
 *
 *  Test 1: parse-medication returns rxcui for a valid drug
 *  Test 2: verification endpoint returns "match" for a matching pill
 *  Test 3: verification endpoint returns "mismatch" for a wrong pill
 */

import { describe, test, expect, vi, beforeEach, afterEach } from 'vitest';

// ── Module mocks ──────────────────────────────────────────────────────────────

vi.mock('../../src/utils/auth.js', () => ({
  authenticateToken: (req, _res, next) => {
    req.user = { id: 1 };
    next();
  },
}));

vi.mock('../../src/utils/logger.js', () => ({
  default: { error: vi.fn(), info: vi.fn(), warn: vi.fn() },
}));

// getDb is swapped per-test via the `mockGetDb` variable below.
let mockGetDb;
vi.mock('../../src/database/db.js', () => ({
  get getDb() {
    return mockGetDb;
  },
}));

// ── Import routers AFTER mocks ─────────────────────────────────────────────────

import aiRouter from '../../src/routes/ai.js';
import verificationRouter from '../../src/routes/medicationVerification.js';

// ── Route-invocation helpers ──────────────────────────────────────────────────

/**
 * Invoke POST /parse-medication against the ai router stack directly.
 * Returns { status, body }.
 */
function callParseMedication(body) {
  return new Promise((resolve) => {
    const req = {
      method: 'POST',
      url: '/parse-medication',
      path: '/parse-medication',
      body,
      user: { id: 1 },
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

    const layer = aiRouter.stack.find(
      (l) => l.route?.path === '/parse-medication' && l.route?.methods?.post
    );
    if (!layer) throw new Error('POST /parse-medication route not found in router stack');

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

/**
 * Invoke POST /verify/:medicationId against the verification router stack directly.
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
      user: { id: 1 },
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

    const layer = verificationRouter.stack.find(
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

describe('Medication flow integration', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
    vi.clearAllMocks();
  });

  // ── Test 1: parse-medication returns rxcui for a valid drug ──────────────────

  test('parse-medication returns rxcui and canonicalName for a valid drug', async () => {
    // call #1 — NVIDIA LLM returns structured medication JSON
    const NVIDIA_RESPONSE = {
      ok: true,
      json: async () => ({
        choices: [
          {
            message: {
              content: JSON.stringify({
                name: 'Lisinopril',
                dosage: '10mg',
                frequency: 'Once daily',
                instructions: null,
                isMedication: true,
              }),
              reasoning_content: null,
            },
          },
        ],
      }),
    };

    // call #2 — RxNav rxcui lookup returns 29046
    const RXNAV_RXCUI_RESPONSE = {
      ok: true,
      json: async () => ({ idGroup: { rxnormId: ['29046'] } }),
    };

    // call #3 — RxNav properties returns canonical name
    const RXNAV_PROPERTIES_RESPONSE = {
      ok: true,
      json: async () => ({
        propertiesGroup: {
          properties: [{ name: 'Lisinopril' }],
        },
      }),
    };

    vi.stubGlobal(
      'fetch',
      vi.fn()
        .mockResolvedValueOnce(NVIDIA_RESPONSE)
        .mockResolvedValueOnce(RXNAV_RXCUI_RESPONSE)
        .mockResolvedValueOnce(RXNAV_PROPERTIES_RESPONSE)
    );

    const { status, body } = await callParseMedication({
      text: 'Lisinopril 10mg Take 1 tablet daily',
    });

    expect(status).toBe(200);
    expect(body.medication).toBeDefined();
    expect(body.medication.name).toBe('Lisinopril');
    expect(body.medication.rxcui).toBe(29046);
    expect(typeof body.medication.canonicalName).toBe('string');
  });

  // ── Test 2: verification returns "match" for a matching pill ─────────────────

  test('verification endpoint returns "match" when pill name matches medication', async () => {
    mockGetDb = () => ({
      prepare: () => ({
        get: vi.fn().mockResolvedValue({ id: 1, name: 'Metformin', patient_id: 1 }),
        run: vi.fn().mockResolvedValue({ lastInsertRowid: 42, changes: 1 }),
      }),
    });

    const { status, body } = await callVerify(1, {
      pills: [{ name: 'Metformin', imprint: 'M523' }],
    });

    expect(status).toBe(200);
    expect(body.verification).toBeDefined();
    expect(body.verification.status).toBe('match');
  });

  // ── Test 3: verification returns "mismatch" for a wrong pill ─────────────────

  test('verification endpoint returns "mismatch" when pill name does not match medication', async () => {
    mockGetDb = () => ({
      prepare: () => ({
        get: vi.fn().mockResolvedValue({ id: 1, name: 'Metformin', patient_id: 1 }),
        run: vi.fn().mockResolvedValue({ lastInsertRowid: 43, changes: 1 }),
      }),
    });

    const { status, body } = await callVerify(1, {
      pills: [{ name: 'Ibuprofen', imprint: 'IBU200' }],
    });

    expect(status).toBe(200);
    expect(body.verification).toBeDefined();
    expect(body.verification.status).toBe('mismatch');
  });
});
