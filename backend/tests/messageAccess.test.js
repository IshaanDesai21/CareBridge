import { describe, test, expect } from 'vitest';
import { fakeDb } from './helpers/fakeDb.js';
import { isConversationParticipant, conversationParticipantIds } from '../src/utils/patientAccess.js';

// patient 1 owned by user 7; family 3 and 5 linked to patient 1; family 4 linked elsewhere
function makeDb() {
  return fakeDb([
    [/FROM patients WHERE id = \? AND user_id = \?/, { get: (pid, uid) => (pid === 1 && uid === 7 ? { id: 1 } : undefined) }],
    [/FROM family_patient_links WHERE family_user_id = \? AND patient_id = \?/, {
      get: (uid, pid) => (pid === 1 && (uid === 3 || uid === 5) ? { linked: 1 } : undefined),
    }],
    [/SELECT user_id FROM patients WHERE id = \?/, { get: () => ({ user_id: 7 }) }],
    [/SELECT family_user_id FROM family_patient_links WHERE patient_id = \?/, {
      all: () => [{ family_user_id: 3 }, { family_user_id: 5 }],
    }],
  ]);
}

describe('isConversationParticipant', () => {
  test('patient owner -> true', async () => {
    expect(await isConversationParticipant(makeDb(), 7, 1)).toBe(true);
  });
  test('linked family -> true', async () => {
    expect(await isConversationParticipant(makeDb(), 3, 1)).toBe(true);
  });
  test('family linked to another patient -> false', async () => {
    expect(await isConversationParticipant(makeDb(), 4, 1)).toBe(false);
  });
  test('caregiver with no record or link -> false', async () => {
    expect(await isConversationParticipant(makeDb(), 2, 1)).toBe(false);
  });
});

describe('conversationParticipantIds', () => {
  test('patient + family ids', async () => {
    expect(await conversationParticipantIds(makeDb(), 1)).toEqual([7, 3, 5]);
  });
});
