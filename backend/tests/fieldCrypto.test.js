import { describe, it, expect, beforeAll } from 'vitest';
import fs from 'fs';
import path from 'path';
import {
  initFieldCrypto, encryptValue, decryptValue, decryptRow, isEncrypted,
  encryptedParamIndexes, ENCRYPTED_COLUMNS
} from '../src/utils/fieldCrypto.js';

describe('fieldCrypto', () => {
  beforeAll(() => initFieldCrypto('test-key-0123456789abcdefghijklmnopqrstuvwxyz'));

  it('round-trips text, including unicode', () => {
    const plain = 'Takes metformin 500mg — feeling dizzy 😟';
    const enc = encryptValue(plain);
    expect(isEncrypted(enc)).toBe(true);
    expect(enc).not.toContain('metformin');
    expect(decryptValue(enc)).toBe(plain);
  });

  it('uses a fresh IV so equal inputs give different ciphertext', () => {
    expect(encryptValue('same')).not.toBe(encryptValue('same'));
  });

  it('leaves null, undefined and already-encrypted values alone', () => {
    expect(encryptValue(null)).toBeNull();
    expect(encryptValue(undefined)).toBeUndefined();
    const enc = encryptValue('x');
    expect(encryptValue(enc)).toBe(enc);
  });

  it('passes legacy plaintext through on read', () => {
    expect(decryptValue('plain old note')).toBe('plain old note');
    expect(decryptRow({ id: 1, content: 'plain', n: 5 })).toEqual({ id: 1, content: 'plain', n: 5 });
  });

  it('rejects tampered ciphertext', () => {
    const enc = encryptValue('secret');
    const bytes = Buffer.from(enc.slice(7), 'base64');
    bytes[bytes.length - 1] ^= 1;
    expect(() => decryptValue('enc:v1:' + bytes.toString('base64'))).toThrow();
  });

  it('rejects ciphertext made with a different key', () => {
    const enc = encryptValue('secret');
    initFieldCrypto('a-completely-different-key-0123456789abcdef');
    expect(() => decryptValue(enc)).toThrow();
    initFieldCrypto('test-key-0123456789abcdefghijklmnopqrstuvwxyz');
  });
});

describe('encryptedParamIndexes', () => {
  it('maps INSERT values to encrypted columns, skipping literals', () => {
    expect(encryptedParamIndexes(
      "INSERT INTO chat_messages (user_id, role, content) VALUES (?, 'user', ?)"
    )).toEqual([1]);
  });

  it('maps UPDATE assignments, including COALESCE, and ignores WHERE params', () => {
    expect(encryptedParamIndexes(
      'UPDATE journal_entries SET title = COALESCE(?, title), is_shared = COALESCE(?, is_shared), content = ? WHERE id = ? AND content = ?'
    )).toEqual([0, 2]);
  });

  it('ignores tables with nothing encrypted and SELECTs', () => {
    expect(encryptedParamIndexes('INSERT INTO join_codes (code, patient_id) VALUES (?, ?)')).toEqual([]);
    expect(encryptedParamIndexes('SELECT * FROM journal_entries WHERE content = ?')).toEqual([]);
  });

  // Guards against a new route writing a sensitive column in a shape the mapper
  // doesn't understand, which would silently store plaintext.
  it('covers every encrypted column written anywhere in the backend', () => {
    const dirs = ['src/routes', 'src/services', 'src/database'];
    const files = dirs.flatMap((d) => fs.readdirSync(d).filter((f) => f.endsWith('.js')).map((f) => path.join(d, f)));
    for (const f of files) {
      const src = fs.readFileSync(f, 'utf8');
      for (const m of src.matchAll(/prepare\(\s*(`[\s\S]*?`|"[^"]*"|'[^']*')/g)) {
        const sql = m[1].slice(1, -1).replace(/\$\{[^}]*\}/g, '?').replace(/\s+/g, ' ').trim();
        const table = (sql.match(/^(?:insert\s+(?:or\s+ignore\s+)?into|update)\s+(\w+)/i) || [])[1];
        const cols = table && ENCRYPTED_COLUMNS[table];
        if (!cols) continue;
        let expected = 0;
        if (/^insert/i.test(sql)) {
          const names = sql.match(/\(([^)]*)\)/)[1].split(',').map((c) => c.trim());
          const values = sql.slice(sql.toLowerCase().indexOf('values')).match(/\((.*)\)/)[1].split(',').map((v) => v.trim());
          names.forEach((n, i) => { if (cols.includes(n) && values[i] === '?') expected++; });
        } else {
          const set = sql.split(/ where /i)[0];
          expected = cols.filter((c) => new RegExp(`\\b${c}\\s*=`).test(set)).length;
        }
        expect(encryptedParamIndexes(sql).length, `${f}: ${sql}`).toBe(expected);
      }
    }
  });
});
