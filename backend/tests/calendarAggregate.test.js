import { buildMonth, buildDay } from '../src/services/calendarAggregate.js';

const empty = { checkins: [], medications: [], doseLogs: [], failedChecks: [], meals: [], careNotes: [], patientNotes: [] };
const day = (over) => buildDay({ date: '2026-10-05', ...empty, ...over });

describe('buildMonth', () => {
  const none = { checkinDates: [], doseDates: [], flagDates: [], noteDates: [], mealDates: [] };

  test('has one entry per calendar day', () => {
    expect(buildMonth({ month: '2026-02', ...none }).days).toHaveLength(28);
    expect(buildMonth({ month: '2026-10', ...none }).days).toHaveLength(31);
    expect(buildMonth({ month: '2024-02', ...none }).days).toHaveLength(29);
  });

  test('a flag date sets hasFlag only on that day', () => {
    const m = buildMonth({ month: '2026-10', ...none, flagDates: ['2026-10-03'] });
    expect(m.month).toBe('2026-10');
    expect(m.days.filter((d) => d.hasFlag).map((d) => d.date)).toEqual(['2026-10-03']);
    expect(m.days[0]).toEqual({ date: '2026-10-01', hasCheckin: false, hasDoses: false, hasFlag: false, hasEntries: false });
  });

  test('notes and meals set hasEntries; checkins and doses their own flags', () => {
    const m = buildMonth({ month: '2026-10', checkinDates: ['2026-10-01'], doseDates: ['2026-10-02'], flagDates: [], noteDates: ['2026-10-03'], mealDates: ['2026-10-04'] });
    expect(m.days[0].hasCheckin).toBe(true);
    expect(m.days[1].hasDoses).toBe(true);
    expect(m.days[2].hasEntries).toBe(true);
    expect(m.days[3].hasEntries).toBe(true);
    expect(m.days[4].hasEntries).toBe(false);
  });
});

describe('buildDay', () => {
  test('empty day', () => {
    expect(day({})).toEqual({ date: '2026-10-05', checkin: null, doses: [], progress: [], flags: [], meals: [], notes: [] });
  });

  test('two check-ins: picks the later created_at, camelCased', () => {
    const d = day({ checkins: [
      { id: 1, energy: 2, sleep_quality: 3, created_at: '2026-10-05T08:00:00Z' },
      { id: 2, energy: 5, sleep_quality: 4, speech_clarity: 1, swallowing_difficulty: 2, created_at: '2026-10-05T20:00:00Z' },
    ] });
    expect(d.checkin.energy).toBe(5);
    expect(d.checkin.sleepQuality).toBe(4);
    expect(d.checkin.speechClarity).toBe(1);
    expect(d.checkin.swallowingDifficulty).toBe(2);
    expect(d.checkin.createdAt).toBe('2026-10-05T20:00:00Z');
  });

  const meds = [
    { id: 1, name: 'Zed', strength: '5 mg', doses_per_day: 3, as_needed: 0, is_active: 1 },
    { id: 2, name: 'Alpha', strength: '10 mg', doses_per_day: 3, as_needed: 1, is_active: 1 },
    { id: 3, name: 'Old', strength: '1 mg', doses_per_day: 2, as_needed: 0, is_active: 0 },
    { id: 4, name: 'NoSched', strength: '1 mg', doses_per_day: null, as_needed: 0, is_active: 1 },
  ];
  const log = (id, medication_id, given_at, extra = {}) => ({ id, medication_id, name: 'x', strength: 's', pill_count: 1, source: 'manual', strength_verified: 0, given_at, ...extra });

  test('inactive med: dose shown, no progress row; progress only for active scheduled meds, by name', () => {
    const d = day({ medications: meds, doseLogs: [
      log(10, 3, '2026-10-05T09:00:00Z', { name: 'Old', strength: '1 mg' }),
      log(11, 1, '2026-10-05T08:00:00Z', { name: 'Zed', strength: '5 mg', strength_verified: 1, source: 'photo' }),
    ] });
    expect(d.doses.map((x) => x.id)).toEqual([11, 10]);
    expect(d.doses[0]).toEqual({ id: 11, medicationId: 1, name: 'Zed', strength: '5 mg', pillCount: 1, source: 'photo', strengthVerified: true, givenAt: '2026-10-05T08:00:00Z' });
    expect(d.progress.map((p) => p.medicationId)).toEqual([2, 1]);
  });

  test('progress labels', () => {
    const d = day({ medications: meds, doseLogs: [
      log(1, 1, 'a'), log(2, 1, 'b'), log(3, 2, 'c'), log(4, 2, 'd'),
    ] });
    const zed = d.progress.find((p) => p.medicationId === 1);
    const alpha = d.progress.find((p) => p.medicationId === 2);
    expect(zed).toEqual({ medicationId: 1, name: 'Zed', strength: '5 mg', given: 2, dosesPerDay: 3, asNeeded: false, label: '2 of 3 doses' });
    expect(alpha.asNeeded).toBe(true);
    expect(alpha.label).toBe('2 doses given (max 3)');
  });

  test('flags: unresolved fail checks only, messages from problems (string or array)', () => {
    const d = day({ failedChecks: [
      { id: 1, created_at: '2026-10-05T10:00:00Z', source: 'photo', resolved_by_check_id: null, problems: JSON.stringify([{ code: 'a', message: 'Wrong pill' }, { code: 'b', message: 'Too many' }]) },
      { id: 2, created_at: '2026-10-05T11:00:00Z', source: 'photo', resolved_by_check_id: 9, problems: '[{"message":"gone"}]' },
      { id: 3, created_at: '2026-10-05T12:00:00Z', source: 'manual', resolved_by_check_id: null, problems: [{ message: 'Array form' }] },
      { id: 4, created_at: '2026-10-05T13:00:00Z', source: 'manual', resolved_by_check_id: null, problems: '{not json' },
    ] });
    expect(d.flags).toEqual([
      { id: 1, createdAt: '2026-10-05T10:00:00Z', source: 'photo', messages: ['Wrong pill', 'Too many'] },
      { id: 3, createdAt: '2026-10-05T12:00:00Z', source: 'manual', messages: ['Array form'] },
      { id: 4, createdAt: '2026-10-05T13:00:00Z', source: 'manual', messages: [] },
    ]);
  });

  test('meals and merged notes with kinds and author names', () => {
    const d = day({
      meals: [{ id: 1, meal_type: 'lunch', description: 'Soup', author_user_id: 7, author_first_name: 'Ann', author_last_name: 'Lee', created_at: '2026-10-05T12:00:00Z' }],
      careNotes: [{ id: 5, caregiver_id: 3, content: 'c', author_first_name: 'Bo', author_last_name: null, created_at: '2026-10-05T15:00:00Z' }],
      patientNotes: [{ id: 6, author_user_id: 7, content: 'p', author_first_name: 'Ann', author_last_name: 'Lee', created_at: '2026-10-05T09:00:00Z' }],
    });
    expect(d.meals[0]).toEqual({ id: 1, mealType: 'lunch', description: 'Soup', authorUserId: 7, authorName: 'Ann Lee', createdAt: '2026-10-05T12:00:00Z' });
    expect(d.notes).toEqual([
      { id: 6, kind: 'patient', content: 'p', authorUserId: 7, authorName: 'Ann Lee', createdAt: '2026-10-05T09:00:00Z' },
      { id: 5, kind: 'caregiver', content: 'c', authorUserId: 3, authorName: 'Bo', createdAt: '2026-10-05T15:00:00Z' },
    ]);
  });
});
