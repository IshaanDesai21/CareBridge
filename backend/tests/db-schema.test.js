import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

describe('Database Schema', () => {
  test('verification_logs table is defined in db.js', () => {
    const dbFilePath = path.join(__dirname, '../src/database/db.js');
    const dbSource = fs.readFileSync(dbFilePath, 'utf-8');
    expect(dbSource).toContain('verification_logs');
    expect(dbSource).toContain('medication_id INTEGER REFERENCES medications(id)');
    expect(dbSource).toContain("status TEXT CHECK (status IN ('match', 'mismatch'))");
    expect(dbSource).toContain('expected_name TEXT NOT NULL');
    expect(dbSource).toContain('detected_pills TEXT NOT NULL');
    expect(dbSource).toContain('verified_by INTEGER REFERENCES users(id)');
  });

  test('db.js exports connectDatabase and getDb functions', async () => {
    const dbModule = await import('../src/database/db.js');
    expect(typeof dbModule.connectDatabase).toBe('function');
    expect(typeof dbModule.getDb).toBe('function');
  });
});
