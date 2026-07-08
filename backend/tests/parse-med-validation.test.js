/**
 * Tests for the RxNorm wiring in the parse-medication endpoint.
 *
 * We test the wiring by controlling fetch at the global level:
 *   - The first fetch call (from callAI → NVIDIA) returns our fake LLM JSON.
 *   - Subsequent fetch calls (from getMedicationInfo → RxNav) return either
 *     a valid RxNav response or a "not found" response depending on the test.
 *
 * This avoids the ESM live-binding problem with vi.mock on named exports and
 * doesn't need a running database or real API keys.
 */

import { describe, test, expect, vi, beforeEach, afterEach } from 'vitest';

// ── Module mocks ──────────────────────────────────────────────────────────────

vi.mock('../src/utils/auth.js', () => ({
  authenticateToken: (_req, _res, next) => next(),
}));

vi.mock('../src/database/db.js', () => ({
  getDb: () => ({
    prepare: () => ({ get: vi.fn(), all: vi.fn(), run: vi.fn() }),
  }),
}));

vi.mock('../src/utils/logger.js', () => ({
  default: { error: vi.fn(), info: vi.fn(), warn: vi.fn() },
}));

// ── Import router after mocks ─────────────────────────────────────────────────

import router from '../src/routes/ai.js';

// ── Helpers ───────────────────────────────────────────────────────────────────

/**
 * Build a mock fetch that:
 *   call #1  → NVIDIA LLM response (returns the fake OCR-parsed JSON)
 *   call #2  → RxNav rxcui lookup  (rxnormId or empty)
 *   call #3  → RxNav properties    (only reached when #2 returns an rxcui)
 */
function buildFetchMock({ rxnavRxcui, rxnavName }) {
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
              instructions: 'Take with water',
              isMedication: true,
            }),
            reasoning_content: null,
          },
        },
      ],
    }),
  };

  if (rxnavRxcui) {
    const RXNAV_RXCUI_RESPONSE = {
      ok: true,
      json: async () => ({ idGroup: { rxnormId: [String(rxnavRxcui)] } }),
    };
    const RXNAV_PROPERTIES_RESPONSE = {
      ok: true,
      json: async () => ({
        propertiesGroup: {
          properties: [{ name: rxnavName }],
        },
      }),
    };
    return vi
      .fn()
      .mockResolvedValueOnce(NVIDIA_RESPONSE)
      .mockResolvedValueOnce(RXNAV_RXCUI_RESPONSE)
      .mockResolvedValueOnce(RXNAV_PROPERTIES_RESPONSE);
  } else {
    // Drug not found: RxNav returns empty rxnormId array
    const RXNAV_NOT_FOUND = {
      ok: true,
      json: async () => ({ idGroup: { rxnormId: [] } }),
    };
    return vi
      .fn()
      .mockResolvedValueOnce(NVIDIA_RESPONSE)
      .mockResolvedValueOnce(RXNAV_NOT_FOUND);
  }
}

/** Invoke the parse-medication route handler directly (no HTTP server needed). */
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

    const layer = router.stack.find(
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

// ── Tests ─────────────────────────────────────────────────────────────────────

describe('parse-medication RxNorm wiring', () => {
  beforeEach(() => {
    process.env.NVIDIA_API_KEY = 'test-key';
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    vi.clearAllMocks();
    delete process.env.NVIDIA_API_KEY;
  });

  test('merges rxcui and canonicalName when getMedicationInfo resolves with data', async () => {
    vi.stubGlobal('fetch', buildFetchMock({
      rxnavRxcui: 29046,
      rxnavName: 'Lisinopril 10 MG Oral Tablet',
    }));

    const { status, body } = await callParseMedication({
      text: 'Lisinopril 10mg\nTake 1 tablet daily',
    });

    expect(status).toBe(200);
    expect(body.medication).toBeDefined();
    expect(body.medication.rxcui).toBe(29046);
    expect(body.medication.canonicalName).toBe('Lisinopril 10 MG Oral Tablet');
    expect(body.medication.confidence).toBe('high');
    expect(body.medication.name).toBe('Lisinopril');
  });

  test('sets rxcui and canonicalName to null when getMedicationInfo returns null (drug not found)', async () => {
    vi.stubGlobal('fetch', buildFetchMock({ rxnavRxcui: null, rxnavName: null }));

    const { status, body } = await callParseMedication({
      text: 'Unknowndrugxyz 5mg\nTake once',
    });

    expect(status).toBe(200);
    expect(body.medication).toBeDefined();
    expect(body.medication.rxcui).toBeNull();
    expect(body.medication.canonicalName).toBeNull();
    // Medication was still extracted from OCR — should not reject the request
    expect(body.medication.name).toBe('Lisinopril'); // from mocked LLM response
    expect(body.medication.confidence).toBe('high');
  });
});
