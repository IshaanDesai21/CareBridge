/**
 * Pure calendar aggregation (no DB access). Input rows are snake_case, as
 * returned by pg. Output is camelCase JSON.
 *
 * buildDay input row contract (what the route must pass):
 *   checkins:     wellness_checkins rows for the day
 *                 (id, energy, fatigue, pain, mood, sleep_quality, breathing,
 *                  mobility, balance, speech_clarity, appetite, hydration,
 *                  swallowing_difficulty, notes, created_at)
 *   medications:  medications rows for the patient (id, name, strength,
 *                 doses_per_day, as_needed 0/1, is_active 0/1)
 *   doseLogs:     dose_logs rows for the day JOINED with medications, adding
 *                 `name` and `strength` (id, medication_id, name, strength,
 *                 pill_count, source, strength_verified 0/1, given_at)
 *   failedChecks: pill_checks rows with status='fail' for the day
 *                 (id, created_at, source, problems, resolved_by_check_id).
 *                 `problems` may be a JSON string or an array of
 *                 {code, message}; malformed JSON yields no messages.
 *                 Rows with resolved_by_check_id set are ignored here.
 *   meals:        meals rows JOINED with users for the author:
 *                 (id, meal_type, description, author_user_id,
 *                  author_first_name, author_last_name, created_at)
 *   careNotes:    care_notes rows JOINED with users on caregiver_id:
 *                 (id, caregiver_id, content, author_first_name,
 *                  author_last_name, created_at)
 *   patientNotes: patient_notes rows JOINED with users on author_user_id:
 *                 (id, author_user_id, content, author_first_name,
 *                  author_last_name, created_at)
 *
 * Author names are always `author_first_name` / `author_last_name` (either may
 * be null); they are joined with a space into `authorName`.
 * Timestamps (created_at, given_at) may be Date objects or ISO strings and are
 * passed through unchanged to the output.
 */

const CHECKIN_FIELDS = [
  'energy', 'fatigue', 'pain', 'mood', 'sleepQuality', 'breathing', 'mobility',
  'balance', 'speechClarity', 'appetite', 'hydration', 'swallowingDifficulty', 'notes',
];

const snake = (s) => s.replace(/[A-Z]/g, (c) => `_${c.toLowerCase()}`);

const toMs = (v) => {
  const ms = v instanceof Date ? v.getTime() : Date.parse(v);
  return Number.isNaN(ms) ? 0 : ms;
};

const byTimeThenId = (key) => (a, b) => toMs(a[key]) - toMs(b[key]) || (a.id ?? 0) - (b.id ?? 0);

const authorName = (row) =>
  [row.author_first_name, row.author_last_name].filter(Boolean).join(' ') || null;

const truthy = (v) => v === true || Number(v) === 1;

export function buildMonth({ month, checkinDates = [], doseDates = [], flagDates = [], noteDates = [], mealDates = [] }) {
  const [y, m] = month.split('-').map(Number);
  const count = new Date(Date.UTC(y, m, 0)).getUTCDate();
  const checkin = new Set(checkinDates);
  const doses = new Set(doseDates);
  const flags = new Set(flagDates);
  const entries = new Set([...noteDates, ...mealDates]);
  const days = [];
  for (let d = 1; d <= count; d++) {
    const date = `${month}-${String(d).padStart(2, '0')}`;
    days.push({
      date,
      hasCheckin: checkin.has(date),
      hasDoses: doses.has(date),
      hasFlag: flags.has(date),
      hasEntries: entries.has(date),
    });
  }
  return { month, days };
}

function parseMessages(problems) {
  let list = problems;
  if (typeof problems === 'string') {
    try {
      list = JSON.parse(problems);
    } catch {
      return [];
    }
  }
  if (!Array.isArray(list)) return [];
  return list.map((p) => p && p.message).filter((m) => typeof m === 'string' && m);
}

export function buildDay({
  date,
  checkins = [],
  medications = [],
  doseLogs = [],
  failedChecks = [],
  meals = [],
  careNotes = [],
  patientNotes = [],
}) {
  let checkin = null;
  if (checkins.length) {
    const latest = [...checkins].sort(byTimeThenId('created_at')).at(-1);
    checkin = {};
    for (const f of CHECKIN_FIELDS) checkin[f] = latest[snake(f)] ?? null;
    checkin.createdAt = latest.created_at;
  }

  const sortedLogs = [...doseLogs].sort(byTimeThenId('given_at'));
  const doses = sortedLogs.map((l) => ({
    id: l.id,
    medicationId: l.medication_id,
    name: l.name ?? null,
    strength: l.strength ?? null,
    pillCount: l.pill_count,
    source: l.source,
    strengthVerified: truthy(l.strength_verified),
    givenAt: l.given_at,
  }));

  const progress = medications
    .filter((m) => truthy(m.is_active) && Number.isInteger(m.doses_per_day) && m.doses_per_day > 0)
    .sort((a, b) => String(a.name).localeCompare(String(b.name)))
    .map((m) => {
      const given = doseLogs.filter((l) => l.medication_id === m.id).length;
      const asNeeded = truthy(m.as_needed);
      return {
        medicationId: m.id,
        name: m.name,
        strength: m.strength ?? null,
        given,
        dosesPerDay: m.doses_per_day,
        asNeeded,
        label: asNeeded ? `${given} doses given (max ${m.doses_per_day})` : `${given} of ${m.doses_per_day} doses`,
      };
    });

  const flags = failedChecks
    .filter((c) => c.resolved_by_check_id == null)
    .sort(byTimeThenId('created_at'))
    .map((c) => ({ id: c.id, createdAt: c.created_at, source: c.source, messages: parseMessages(c.problems) }));

  const mealList = [...meals].sort(byTimeThenId('created_at')).map((m) => ({
    id: m.id,
    mealType: m.meal_type,
    description: m.description,
    authorUserId: m.author_user_id ?? null,
    authorName: authorName(m),
    createdAt: m.created_at,
  }));

  const notes = [
    ...careNotes.map((n) => ({
      id: n.id, kind: 'caregiver', content: n.content,
      authorUserId: n.caregiver_id ?? null, authorName: authorName(n), createdAt: n.created_at,
    })),
    ...patientNotes.map((n) => ({
      id: n.id, kind: 'patient', content: n.content,
      authorUserId: n.author_user_id ?? null, authorName: authorName(n), createdAt: n.created_at,
    })),
  ].sort((a, b) => toMs(a.createdAt) - toMs(b.createdAt) || a.kind.localeCompare(b.kind) || a.id - b.id);

  return { date, checkin, doses, progress, flags, meals: mealList, notes };
}
