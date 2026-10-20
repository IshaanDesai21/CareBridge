import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const catalog = JSON.parse(
  fs.readFileSync(path.join(__dirname, '../src/data/pillCatalog.json'), 'utf-8')
);
const norm = (s) => s.replace(/[\s;]/g, '').toUpperCase();

describe('pillCatalog.json', () => {
  test('is non-empty', () => {
    expect(catalog.length).toBeGreaterThan(0);
  });

  test('every normalized imprint is unique across rows', () => {
    const keys = catalog.map((r) => norm(r.imprint));
    expect(new Set(keys).size).toBe(keys.length);
  });

  test('every row has a valid drug, strength and form', () => {
    for (const r of catalog) {
      expect(['benzonatate', 'phenazopyridine', 'atorvastatin', 'lisinopril']).toContain(r.drug);
      expect(r.strength).toMatch(/^\d+(\.\d+)? (mg|mcg|g)$/);
      expect(['tablet', 'capsule']).toContain(r.form);
      expect(norm(r.imprint)).not.toBe('');
    }
  });
});
