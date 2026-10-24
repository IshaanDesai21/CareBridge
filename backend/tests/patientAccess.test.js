import { describe, test, expect } from 'vitest';
import { fakeDb } from './helpers/fakeDb.js';
import { canAccessPatient } from '../src/utils/patientAccess.js';

const patientRow = (userId) => [/FROM patients WHERE id = \?/, { get: async () => ({ id: 1, user_id: userId }) }];

describe('canAccessPatient', () => {
  test('patient can access own record', async () => {
    const db = fakeDb([patientRow(5)]);
    expect(await canAccessPatient(db, { id: 5, role: 'patient' }, 1)).toBe(true);
  });

  test('patient cannot access another patient', async () => {
    const db = fakeDb([patientRow(9)]);
    expect(await canAccessPatient(db, { id: 5, role: 'patient' }, 1)).toBe(false);
  });

  test('family linked -> true', async () => {
    const db = fakeDb([[/FROM family_patient_links/, { get: async () => ({ id: 1 }) }]]);
    expect(await canAccessPatient(db, { id: 7, role: 'family' }, 1)).toBe(true);
  });

  test('family unlinked -> false', async () => {
    const db = fakeDb([[/FROM family_patient_links/, { get: async () => undefined }]]);
    expect(await canAccessPatient(db, { id: 7, role: 'family' }, 1)).toBe(false);
  });

  test('caregiver without org -> true', async () => {
    const db = fakeDb([[/SELECT organization_id FROM users/, { get: async () => ({ organization_id: null }) }]]);
    expect(await canAccessPatient(db, { id: 2, role: 'caregiver' }, 1)).toBe(true);
  });

  test('caregiver in org 3, patient user in org 3 -> true', async () => {
    const db = fakeDb([
      [/SELECT organization_id FROM users/, { get: async () => ({ organization_id: 3 }) }],
      [/JOIN users u/, { get: async (_id, org) => (org === 3 ? { id: 1 } : undefined) }],
    ]);
    expect(await canAccessPatient(db, { id: 2, role: 'caregiver' }, 1)).toBe(true);
  });

  test('caregiver in org 3, patient user in org 4 -> false', async () => {
    const db = fakeDb([
      [/SELECT organization_id FROM users/, { get: async () => ({ organization_id: 3 }) }],
      [/JOIN users u/, { get: async (_id, org) => (org === 4 ? { id: 1 } : undefined) }],
    ]);
    expect(await canAccessPatient(db, { id: 2, role: 'organization' }, 1)).toBe(false);
  });

  test('unknown role -> false', async () => {
    const db = fakeDb([]);
    expect(await canAccessPatient(db, { id: 2, role: 'stranger' }, 1)).toBe(false);
    expect(db.calls).toHaveLength(0);
  });
});
