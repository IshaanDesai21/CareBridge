// Pure dose rule engine for the caregiver pill check. No DB, no Express.

export const TARGET_CLASSES = ['benzonatate', 'phenazopyridine', 'atorvastatin', 'lisinopril'];
export const CLASS_FORM = {
  benzonatate: 'capsule',
  phenazopyridine: 'tablet',
  atorvastatin: 'tablet',
  lisinopril: 'tablet',
};
export const CONFIDENCE_THRESHOLD = Number(process.env.PILL_CONFIDENCE_THRESHOLD ?? 0.6);
export const CORRECTION_WINDOW_MS = 30 * 60 * 1000;

export function normalizeStrength(s) {
  if (typeof s !== 'string') return null;
  const m = s.toLowerCase().match(/(\d+(?:\.\d+)?)\s*(mcg|mg|g)\b/);
  return m ? `${m[1]} ${m[2]}` : null;
}

export function drugClassFor(medicationName) {
  if (typeof medicationName !== 'string') return null;
  const lower = medicationName.toLowerCase();
  return TARGET_CLASSES.find((c) => new RegExp(`\\b${c}\\b`).test(lower)) ?? null;
}

const titleCase = (s) => s.charAt(0).toUpperCase() + s.slice(1);
const normImprint = (s) => String(s ?? '').toLowerCase().replace(/[\s;]/g, '');
const isPosInt = (n) => Number.isInteger(n) && n > 0;

function dosingComplete(med) {
  return (
    !!med.form &&
    isPosInt(med.pills_per_dose_min) &&
    isPosInt(med.pills_per_dose_max) &&
    isPosInt(med.doses_per_day) &&
    med.pills_per_dose_min <= med.pills_per_dose_max
  );
}

const setupProblem = (med) => ({
  code: 'setup_incomplete',
  medicationId: med.id,
  message: `Finish setting up ${med.name}: pills per dose and times per day are needed.`,
});

function countProblems(med, count, todayTotal) {
  const problems = [];
  const min = med.pills_per_dose_min;
  const max = med.pills_per_dose_max;
  if (count < min || count > max) {
    const range = min === max ? `${min}` : `${min}–${max}`;
    problems.push({
      code: 'count_mismatch',
      medicationId: med.id,
      expected: min === max ? min : `${min}–${max}`,
      counted: count,
      message: `Expected ${range} ${med.name}, counted ${count}.`,
    });
  }
  const total = (todayTotal ?? 0) + count;
  const dailyMax = max * med.doses_per_day;
  if (total > dailyMax) {
    problems.push({
      code: 'over_daily_max',
      medicationId: med.id,
      message: `This would be ${total} ${med.name} today — more than the daily maximum of ${dailyMax}.`,
    });
  }
  return problems;
}

export function evaluatePillCheck({ detections, medications, todayTotals, catalog, threshold }) {
  const limit = threshold ?? CONFIDENCE_THRESHOLD;
  const dets = detections ?? [];
  const meds = medications ?? [];
  const totals = todayTotals ?? {};
  const cat = catalog ?? [];
  const problems = [];
  const doses = [];

  if (dets.length === 0) {
    problems.push({
      code: 'no_pills',
      message: 'No pills found in the photo. Spread the pills out on a flat surface and try again.',
    });
  }

  let unrecognized = 0;
  const groups = new Map();
  for (const d of dets) {
    if (d.confidence < limit || d.label === 'other' || !TARGET_CLASSES.includes(d.label)) {
      unrecognized += 1;
      continue;
    }
    if (!groups.has(d.label)) groups.set(d.label, []);
    groups.get(d.label).push(d);
  }

  const labelProblems = [];
  for (const [label, group] of groups) {
    const display = titleCase(label);
    const matches = meds.filter((m) => drugClassFor(m.name) === label);
    if (matches.length === 0) {
      labelProblems.push({ code: 'not_on_list', label: display, message: `${display} isn't on this patient's medication list.` });
      continue;
    }
    if (matches.length > 1) {
      labelProblems.push({ code: 'duplicate_medication', label: display, message: `${display} is listed more than once. Remove the old entry before checking.` });
      continue;
    }
    const med = matches[0];
    if (!dosingComplete(med)) {
      labelProblems.push(setupProblem(med));
      continue;
    }
    const before = labelProblems.length;
    if (med.form !== CLASS_FORM[label]) {
      labelProblems.push({
        code: 'wrong_form',
        medicationId: med.id,
        message: `${med.name} should be a ${med.form}, but a ${CLASS_FORM[label]} was found.`,
      });
    }
    let allMatched = true;
    const wrongStrengths = new Set();
    for (const d of group) {
      const key = normImprint(d.imprint);
      const entry = key ? cat.find((c) => normImprint(c.imprint) === key) : null;
      if (!entry) {
        allMatched = false;
        continue;
      }
      if (entry.drug !== label) {
        unrecognized += 1;
        allMatched = false;
        continue;
      }
      if (normalizeStrength(entry.strength) !== normalizeStrength(med.strength)) {
        allMatched = false;
        if (!wrongStrengths.has(entry.strength)) {
          wrongStrengths.add(entry.strength);
          labelProblems.push({
            code: 'wrong_strength',
            medicationId: med.id,
            message: `${med.name} should be ${med.strength}, but this pill looks like ${entry.strength}.`,
          });
        }
      }
    }
    labelProblems.push(...countProblems(med, group.length, totals[med.id]));
    if (labelProblems.length === before) {
      doses.push({ medicationId: med.id, pillCount: group.length, strengthVerified: allMatched });
    }
  }

  if (unrecognized > 0) {
    problems.push({
      code: 'unrecognized',
      counted: unrecognized,
      message: `Couldn't recognize ${unrecognized} pill(s). Check them by hand before giving.`,
    });
  }
  problems.push(...labelProblems);

  if (problems.length > 0) return { status: 'fail', problems, doses: [] };
  return { status: 'pass', problems: [], doses };
}

export function evaluateManualDose({ medication, pillCount, todayTotal }) {
  if (!dosingComplete(medication)) {
    return { status: 'fail', problems: [setupProblem(medication)] };
  }
  const problems = countProblems(medication, pillCount, todayTotal);
  return { status: problems.length ? 'fail' : 'pass', problems };
}

export function resolvableFailureIds({ failures, passedMedicationIds, now }) {
  const nowMs = now instanceof Date ? now.getTime() : Number(now);
  const passed = new Set(passedMedicationIds ?? []);
  return (failures ?? [])
    .filter((f) => {
      const age = nowMs - new Date(f.created_at).getTime();
      if (!(age < CORRECTION_WINDOW_MS)) return false;
      return (f.problems ?? []).every((p) => p.medicationId == null || passed.has(p.medicationId));
    })
    .map((f) => f.id);
}
