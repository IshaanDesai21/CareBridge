import { describe, test, expect } from 'vitest';
import { localDateError } from '../src/services/entryGuards.js';

const range = { status: 400, error: 'localDate out of range' };
const format = { status: 400, error: 'localDate must be YYYY-MM-DD' };

describe('localDateError (injected clock)', () => {
  const noon = Date.UTC(2026, 9, 21, 12);
  test('today and +/-1 day accepted', () => {
    for (const d of ['2026-10-20', '2026-10-21', '2026-10-22']) expect(localDateError(d, noon)).toBeNull();
  });
  test('+/-2 days rejected', () => {
    expect(localDateError('2026-10-19', noon)).toEqual(range);
    expect(localDateError('2026-10-23', noon)).toEqual(range);
  });
  test('bounds follow the UTC date, not the hour', () => {
    const lateUtc = Date.UTC(2026, 9, 21, 23, 59);
    const earlyUtc = Date.UTC(2026, 9, 21, 0, 1);
    expect(localDateError('2026-10-22', lateUtc)).toBeNull();
    expect(localDateError('2026-10-20', earlyUtc)).toBeNull();
    expect(localDateError('2026-10-23', lateUtc)).toEqual(range);
  });
  test('month/year boundaries', () => {
    expect(localDateError('2026-12-31', Date.UTC(2027, 0, 1, 3))).toBeNull();
    expect(localDateError('2026-12-30', Date.UTC(2027, 0, 1, 3))).toEqual(range);
  });
  test('bad format', () => {
    for (const d of ['10/21/2026', '2026-02-30', null, undefined, 20261021]) expect(localDateError(d, noon)).toEqual(format);
  });
});
