import { describe, test, expect } from 'vitest';
import {
  evaluatePillCheck, evaluateManualDose, resolvableFailureIds, normalizeStrength,
  drugClassFor, CORRECTION_WINDOW_MS, CONFIDENCE_THRESHOLD, TARGET_CLASSES, CLASS_FORM,
} from '../src/services/doseRules.js';

const L = { id: 1, name: 'Lisinopril', strength: '10 mg', form: 'tablet', pills_per_dose_min: 1, pills_per_dose_max: 1, doses_per_day: 1 };
const B = { id: 2, name: 'Benzonatate', strength: '100 mg', form: 'capsule', pills_per_dose_min: 1, pills_per_dose_max: 2, doses_per_day: 3 };
const det = (label, confidence = 0.9, imprint = null) => ({ label, confidence, imprint });
const run = (o) => evaluatePillCheck({ detections: [], medications: [L, B], todayTotals: {}, catalog: [], ...o });
const codes = (r) => r.problems.map((p) => p.code);

describe('constants', () => {
  test('exports', () => {
    expect(TARGET_CLASSES).toEqual(['benzonatate', 'phenazopyridine', 'atorvastatin', 'lisinopril']);
    expect(CLASS_FORM.benzonatate).toBe('capsule');
    expect(CORRECTION_WINDOW_MS).toBe(1800000);
    expect(CONFIDENCE_THRESHOLD).toBe(0.6);
  });
});

describe('helpers', () => {
  test('normalizeStrength', () => {
    expect(normalizeStrength('10mg')).toBe('10 mg');
    expect(normalizeStrength('10 MG')).toBe('10 mg');
    expect(normalizeStrength('10 MG tablet')).toBe('10 mg');
    expect(normalizeStrength('500 mcg')).toBe('500 mcg');
    expect(normalizeStrength('1 g')).toBe('1 g');
    expect(normalizeStrength(null)).toBeNull();
    expect(normalizeStrength('tablet')).toBeNull();
  });
  test('drugClassFor', () => {
    expect(drugClassFor('Lisinopril 10 mg')).toBe('lisinopril');
    expect(drugClassFor('Tylenol')).toBeNull();
    expect(drugClassFor(null)).toBeNull();
  });
});

describe('evaluatePillCheck', () => {
  test('passes one lisinopril + one benzonatate', () => {
    const r = run({ detections: [det('lisinopril'), det('benzonatate')] });
    expect(r.status).toBe('pass');
    expect(r.problems).toEqual([]);
    expect(r.doses).toEqual([
      { medicationId: 1, pillCount: 1, strengthVerified: false },
      { medicationId: 2, pillCount: 1, strengthVerified: false },
    ]);
  });
  test('no detections -> no_pills', () => {
    const r = run({});
    expect(r.status).toBe('fail');
    expect(r.doses).toEqual([]);
    expect(r.problems).toEqual([{ code: 'no_pills', message: 'No pills found in the photo. Spread the pills out on a flat surface and try again.' }]);
  });
  test('low confidence -> unrecognized counted 1', () => {
    const r = run({ detections: [det('lisinopril'), det('benzonatate', 0.3)] });
    expect(r.status).toBe('fail');
    const p = r.problems.find((x) => x.code === 'unrecognized');
    expect(p.counted).toBe(1);
    expect(p.message).toBe("Couldn't recognize 1 pill(s). Check them by hand before giving.");
    expect(p.medicationId).toBeUndefined();
  });
  test('label other / unknown label -> unrecognized', () => {
    const r = run({ detections: [det('other'), det('aspirin'), det('lisinopril')] });
    expect(r.problems.find((x) => x.code === 'unrecognized').counted).toBe(2);
    expect(codes(r)).toEqual(['unrecognized']);
  });
  test('phenazopyridine not on list', () => {
    const r = run({ detections: [det('phenazopyridine')] });
    expect(r.problems).toEqual([{ code: 'not_on_list', label: 'Phenazopyridine', message: "Phenazopyridine isn't on this patient's medication list." }]);
  });
  test('no medications -> every label not_on_list', () => {
    const r = run({ medications: [], detections: [det('lisinopril'), det('benzonatate')] });
    expect(codes(r)).toEqual(['not_on_list', 'not_on_list']);
  });
  test('two lisinopril meds -> duplicate_medication', () => {
    const r = run({ medications: [L, { ...L, id: 9, name: 'Lisinopril 20' }], detections: [det('lisinopril')] });
    expect(r.problems).toEqual([{ code: 'duplicate_medication', label: 'Lisinopril', message: 'Lisinopril is listed more than once. Remove the old entry before checking.' }]);
  });
  test('benzonatate listed as tablet -> wrong_form', () => {
    const r = run({ medications: [{ ...B, form: 'tablet' }], detections: [det('benzonatate')] });
    expect(r.problems).toEqual([{ code: 'wrong_form', medicationId: 2, message: 'Benzonatate should be a tablet, but a capsule was found.' }]);
  });
  test('2 lisinopril when max 1 -> count_mismatch', () => {
    const r = run({ detections: [det('lisinopril'), det('lisinopril')] });
    // rules are independent: 2 pills also exceeds the daily max of 1
    expect(r.problems).toEqual([
      { code: 'count_mismatch', medicationId: 1, expected: 1, counted: 2, message: 'Expected 1 Lisinopril, counted 2.' },
      { code: 'over_daily_max', medicationId: 1, message: 'This would be 2 Lisinopril today — more than the daily maximum of 1.' },
    ]);
  });
  test('range message uses en dash', () => {
    const r = run({ detections: [det('benzonatate'), det('benzonatate'), det('benzonatate')] });
    expect(r.problems[0].message).toBe('Expected 1–2 Benzonatate, counted 3.');
  });
  test('benzonatate 2 within 1-2 -> pass', () => {
    const r = run({ detections: [det('benzonatate'), det('benzonatate')] });
    expect(r.status).toBe('pass');
    expect(r.doses[0].pillCount).toBe(2);
  });
  test('over_daily_max', () => {
    const r = run({ todayTotals: { 2: 5 }, detections: [det('benzonatate'), det('benzonatate')] });
    expect(r.problems).toEqual([{ code: 'over_daily_max', medicationId: 2, message: 'This would be 7 Benzonatate today — more than the daily maximum of 6.' }]);
  });
  test('exactly at daily max passes', () => {
    const r = run({ todayTotals: { 2: 4 }, detections: [det('benzonatate'), det('benzonatate')] });
    expect(r.status).toBe('pass');
  });
  test('missing doses_per_day -> setup_incomplete', () => {
    const r = run({ medications: [{ ...B, doses_per_day: null }], detections: [det('benzonatate')] });
    expect(r.problems).toEqual([{ code: 'setup_incomplete', medicationId: 2, message: 'Finish setting up Benzonatate: pills per dose and times per day are needed.' }]);
  });
  test('missing form -> setup_incomplete', () => {
    const r = run({ medications: [{ ...B, form: null }], detections: [det('benzonatate')] });
    expect(codes(r)).toEqual(['setup_incomplete']);
  });
  test('min > max -> setup_incomplete', () => {
    const r = run({ medications: [{ ...B, pills_per_dose_min: 3, pills_per_dose_max: 1 }], detections: [det('benzonatate')] });
    expect(codes(r)).toEqual(['setup_incomplete']);
  });
  test('doses_per_day 0 -> setup_incomplete', () => {
    const r = run({ medications: [{ ...B, doses_per_day: 0 }], detections: [det('benzonatate')] });
    expect(codes(r)).toEqual(['setup_incomplete']);
  });
  test('non-integer / zero / negative dosing -> setup_incomplete', () => {
    for (const patch of [{ pills_per_dose_min: 0 }, { pills_per_dose_max: -1 }, { pills_per_dose_min: 1.5 }, { doses_per_day: '3' }]) {
      const r = run({ medications: [{ ...B, ...patch }], detections: [det('benzonatate')] });
      expect(codes(r)).toEqual(['setup_incomplete']);
    }
  });
  test('incomplete med absent from photo -> no failure', () => {
    const r = run({ medications: [L, { ...B, doses_per_day: null }], detections: [det('lisinopril')] });
    expect(r.status).toBe('pass');
  });
  test('imprint matches catalog 20 mg while med is 10 mg -> wrong_strength', () => {
    const catalog = [{ imprint: 'AB 20', drug: 'lisinopril', strength: '20 mg', form: 'tablet' }];
    const r = run({ catalog, detections: [det('lisinopril', 0.9, 'ab;20')] });
    expect(r.status).toBe('fail');
    expect(r.problems).toEqual([{ code: 'wrong_strength', medicationId: 1, message: 'Lisinopril should be 10 mg, but this pill looks like 20 mg.' }]);
  });
  test('imprint of different drug -> unrecognized', () => {
    const catalog = [{ imprint: 'XY1', drug: 'atorvastatin', strength: '10 mg', form: 'tablet' }];
    const r = run({ catalog, detections: [det('lisinopril', 0.9, 'xy1')] });
    expect(codes(r)).toEqual(['unrecognized']);
    expect(r.problems[0].counted).toBe(1);
  });
  test('matching imprint -> strengthVerified true', () => {
    const catalog = [{ imprint: 'AB 10', drug: 'lisinopril', strength: '10mg', form: 'tablet' }];
    const r = run({ catalog, detections: [det('lisinopril', 0.9, 'AB 10')] });
    expect(r.status).toBe('pass');
    expect(r.doses).toEqual([{ medicationId: 1, pillCount: 1, strengthVerified: true }]);
  });
  test('strengthVerified requires every detection matched', () => {
    const catalog = [{ imprint: 'AB 10', drug: 'benzonatate', strength: '100 mg', form: 'capsule' }];
    const r = run({ catalog, detections: [det('benzonatate', 0.9, 'AB10'), det('benzonatate')] });
    expect(r.doses[0].strengthVerified).toBe(false);
  });
  test('imprint unreadable -> pass, strengthVerified false', () => {
    const r = run({ detections: [det('lisinopril', 0.9, 'zzz')] });
    expect(r.status).toBe('pass');
    expect(r.doses[0].strengthVerified).toBe(false);
  });
  test('collects all problems', () => {
    const r = run({ detections: [det('other'), det('phenazopyridine'), det('lisinopril'), det('lisinopril')] });
    expect(codes(r)).toEqual(['unrecognized', 'not_on_list', 'count_mismatch', 'over_daily_max']);
    expect(r.doses).toEqual([]);
  });
  test('custom threshold', () => {
    const r = run({ threshold: 0.95, detections: [det('lisinopril', 0.9)] });
    expect(codes(r)).toEqual(['unrecognized']);
  });
});

describe('evaluateManualDose', () => {
  test('over max -> over_daily_max', () => {
    const r = evaluateManualDose({ medication: B, pillCount: 2, todayTotal: 5 });
    expect(r.status).toBe('fail');
    expect(r.problems.map((p) => p.code)).toEqual(['over_daily_max']);
    expect(r.problems[0].medicationId).toBe(2);
  });
  test('in range -> pass', () => {
    expect(evaluateManualDose({ medication: B, pillCount: 2, todayTotal: 0 })).toEqual({ status: 'pass', problems: [] });
  });
  test('outside range -> count_mismatch', () => {
    const r = evaluateManualDose({ medication: B, pillCount: 3, todayTotal: 0 });
    expect(r.problems.map((p) => p.code)).toEqual(['count_mismatch']);
  });
  test('setup incomplete', () => {
    const r = evaluateManualDose({ medication: { ...B, doses_per_day: 0 }, pillCount: 1, todayTotal: 0 });
    expect(r.status).toBe('fail');
    expect(r.problems.map((p) => p.code)).toEqual(['setup_incomplete']);
  });
});

describe('resolvableFailureIds', () => {
  const now = new Date('2026-10-19T12:00:00Z');
  const ago = (min) => new Date(now.getTime() - min * 60000);
  const prob = (code, medicationId) => ({ code, message: 'x', ...(medicationId ? { medicationId } : {}) });
  test('names med 2, pass includes 2', () => {
    expect(resolvableFailureIds({ failures: [{ id: 5, created_at: ago(10), problems: [prob('count_mismatch', 2)] }], passedMedicationIds: [2], now })).toEqual([5]);
  });
  test('pass excludes med 2', () => {
    expect(resolvableFailureIds({ failures: [{ id: 5, created_at: ago(10), problems: [prob('count_mismatch', 2)] }], passedMedicationIds: [1], now })).toEqual([]);
  });
  test('every named med must be passed', () => {
    const f = [{ id: 5, created_at: ago(10), problems: [prob('count_mismatch', 2), prob('wrong_form', 1)] }];
    expect(resolvableFailureIds({ failures: f, passedMedicationIds: [2], now })).toEqual([]);
    expect(resolvableFailureIds({ failures: f, passedMedicationIds: [1, 2], now })).toEqual([5]);
  });
  test('only unrecognized -> resolvable', () => {
    expect(resolvableFailureIds({ failures: [{ id: 6, created_at: ago(10), problems: [prob('unrecognized')] }], passedMedicationIds: [], now })).toEqual([6]);
  });
  test('exactly 30 min ago -> not resolvable', () => {
    expect(resolvableFailureIds({ failures: [{ id: 7, created_at: ago(30), problems: [prob('unrecognized')] }], passedMedicationIds: [], now })).toEqual([]);
  });
  test('just under 30 min, ISO string and numeric now', () => {
    const f = [{ id: 8, created_at: ago(29.9).toISOString(), problems: [prob('no_pills')] }];
    expect(resolvableFailureIds({ failures: f, passedMedicationIds: [], now: now.getTime() })).toEqual([8]);
  });
  test('older failures excluded', () => {
    expect(resolvableFailureIds({ failures: [{ id: 9, created_at: ago(60), problems: [] }], passedMedicationIds: [], now })).toEqual([]);
  });
});

describe('fail-closed regressions', () => {
  test('missing / NaN confidence -> unrecognized', () => {
    for (const d of [{ label: 'lisinopril' }, { label: 'lisinopril', confidence: NaN }, { label: 'lisinopril', confidence: '0.9' }]) {
      expect(codes(run({ detections: [d] }))).toEqual(['unrecognized']);
    }
  });
  test('invalid threshold falls back to 0.6', () => {
    for (const threshold of [NaN, 0, -1, 2, '0.1', Infinity]) {
      expect(codes(run({ threshold, detections: [det('lisinopril', 0.3)] }))).toEqual(['unrecognized']);
    }
    expect(codes(run({ threshold: 0.2, detections: [det('lisinopril', 0.3)] }))).toEqual([]);
  });
  test('invalid env threshold falls back to 0.6', async () => {
    const { vi } = await import('vitest');
    for (const v of ['abc', '', '0', '5']) {
      vi.resetModules();
      process.env.PILL_CONFIDENCE_THRESHOLD = v;
      const m = await import('../src/services/doseRules.js');
      expect(m.CONFIDENCE_THRESHOLD).toBe(0.6);
    }
    vi.resetModules();
    process.env.PILL_CONFIDENCE_THRESHOLD = '0.8';
    expect((await import('../src/services/doseRules.js')).CONFIDENCE_THRESHOLD).toBe(0.8);
    delete process.env.PILL_CONFIDENCE_THRESHOLD;
  });
  test('manual dose bad pillCount -> count_mismatch', () => {
    for (const pillCount of [undefined, NaN, 1.5, 0, -1, '1']) {
      const r = evaluateManualDose({ medication: B, pillCount, todayTotal: 0 });
      expect(r.status).toBe('fail');
      expect(r.problems[0].code).toBe('count_mismatch');
      expect(r.problems[0].medicationId).toBe(2);
      expect(r.problems[0].message).toBe(`Expected 1–2 Benzonatate, counted ${pillCount}.`);
    }
  });
  test('bad todayTotal fails closed; string total coerced', () => {
    for (const todayTotal of [NaN, -1, 'abc', Infinity]) {
      const r = evaluateManualDose({ medication: B, pillCount: 1, todayTotal });
      expect(r.status).toBe('fail');
      expect(codes(r)).toEqual(['over_daily_max']);
      expect(codes(run({ todayTotals: { 2: todayTotal }, detections: [det('benzonatate')] }))).toEqual(['over_daily_max']);
    }
    expect(evaluateManualDose({ medication: B, pillCount: 2, todayTotal: '5' }).problems[0].message)
      .toBe('This would be 7 Benzonatate today — more than the daily maximum of 6.');
    expect(evaluateManualDose({ medication: B, pillCount: 1, todayTotal: undefined }).status).toBe('pass');
    expect(evaluateManualDose({ medication: B, pillCount: 1, todayTotal: '4' }).status).toBe('pass');
    expect(codes(run({ todayTotals: { 2: '5' }, detections: [det('benzonatate'), det('benzonatate')] }))).toEqual(['over_daily_max']);
  });
  test('decimal strengths', () => {
    expect(normalizeStrength('.5 mg')).toBe('0.5 mg');
    expect(normalizeStrength('.5 mg')).toBe(normalizeStrength('0.5 mg'));
    expect(normalizeStrength('0.50 mg')).toBe(normalizeStrength('.5 mg'));
    expect(normalizeStrength('.5 mg')).not.toBe(normalizeStrength('5 mg'));
    expect(normalizeStrength('2.5 mg')).not.toBe(normalizeStrength('5 mg'));
    expect(normalizeStrength('2,5 mg')).toBe('2.5 mg');
    expect(normalizeStrength('0,5 mg')).toBe('0.5 mg');
    expect(normalizeStrength('1,000 mg')).toBe('1000 mg');
    expect(normalizeStrength('10 mg')).toBe('10 mg');
  });
  test('0.5 mg catalog vs 5 mg med -> wrong_strength', () => {
    const catalog = [{ imprint: 'Q1', drug: 'lisinopril', strength: '.5 mg', form: 'tablet' }];
    const r = run({ catalog, medications: [{ ...L, strength: '5 mg' }, B], detections: [det('lisinopril', 0.9, 'q1')] });
    expect(codes(r)).toEqual(['wrong_strength']);
  });
  test('null strengths are unverified, no wrong_strength', () => {
    const catalog = [{ imprint: 'Q1', drug: 'lisinopril', strength: null, form: 'tablet' }];
    let r = run({ catalog, medications: [{ ...L, strength: null }, B], detections: [det('lisinopril', 0.9, 'q1')] });
    expect(r.status).toBe('pass');
    expect(r.doses[0].strengthVerified).toBe(false);
    r = run({ catalog, detections: [det('lisinopril', 0.9, 'q1')] });
    expect(r.status).toBe('pass');
    expect(r.doses[0].strengthVerified).toBe(false);
    const cat2 = [{ imprint: 'Q1', drug: 'lisinopril', strength: '10 mg', form: 'tablet' }];
    r = run({ catalog: cat2, medications: [{ ...L, strength: null }, B], detections: [det('lisinopril', 0.9, 'q1')] });
    expect(r.status).toBe('pass');
    expect(r.doses[0].strengthVerified).toBe(false);
  });
});
