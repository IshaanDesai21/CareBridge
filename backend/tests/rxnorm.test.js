import { getMedicationInfo } from '../src/services/rxnorm.js';

describe('RxNorm Service', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  test('returns medication info for valid drug name', async () => {
    vi.stubGlobal('fetch', vi
      .fn()
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({ idGroup: { rxnormId: ['29046'] } }),
      })
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          propertiesGroup: {
            properties: [{ name: 'Lisinopril 10 MG Oral Tablet' }],
          },
        }),
      }));

    const result = await getMedicationInfo('Lisinopril');
    expect(result).toHaveProperty('rxcui');
    expect(result).toHaveProperty('name');
    expect(result.name.toLowerCase()).toContain('lisinopril');
    expect(typeof result.rxcui).toBe('number');
    expect(Array.isArray(result.ingredients)).toBe(true);
  });

  test('returns null for invalid drug name', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValueOnce({
      ok: true,
      json: async () => ({ idGroup: { rxnormId: [] } }),
    }));

    const result = await getMedicationInfo('NotARealMedication12345');
    expect(result).toBeNull();
  });
});
