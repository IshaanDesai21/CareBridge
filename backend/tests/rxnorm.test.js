import { getMedicationInfo } from '../src/services/rxnorm.js';

describe('RxNorm Service', () => {
  test('returns medication info for valid drug name', async () => {
    const result = await getMedicationInfo('Lisinopril');
    expect(result).toHaveProperty('rxcui');
    expect(result).toHaveProperty('name');
    expect(result.name.toLowerCase()).toContain('lisinopril');
  });

  test('returns null for invalid drug name', async () => {
    const result = await getMedicationInfo('NotARealMedication12345');
    expect(result).toBeNull();
  });
});
