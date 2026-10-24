// Field-level encryption for sensitive data at rest.
//
// Health information (diagnoses, medications, journal entries, notes, messages,
// AI chat, ...) is encrypted with AES-256-GCM before it is written to Postgres
// and decrypted when it is read back, so the database itself only ever holds
// ciphertext for these columns. The database layer (database/db.js) applies this
// automatically using ENCRYPTED_COLUMNS below, so route code doesn't change.
//
// Stored format: "enc:v1:" + base64(iv[12] | authTag[16] | ciphertext).
// Values without the prefix are treated as legacy plaintext and returned as-is,
// which lets existing rows be read until the boot-time migration encrypts them.
import crypto from 'crypto';

const PREFIX = 'enc:v1:';
const IV_BYTES = 12;
const TAG_BYTES = 16;

// table -> columns holding personal or health information. Login identifiers
// (users.email, first/last name) stay searchable in plaintext so sign-in,
// lookups and name sorting keep working; everything clinical is encrypted.
export const ENCRYPTED_COLUMNS = {
  users: ['phone'],
  patients: [
    'date_of_birth', 'phone', 'emergency_contact_name', 'emergency_contact_phone',
    'medical_history', 'diagnoses', 'allergies', 'accessibility_preferences',
    'hearing_notes', 'vision_score', 'emergency_contacts', 'care_team'
  ],
  wellness_checkins: ['notes'],
  medications: ['name', 'dosage', 'frequency', 'instructions', 'pharmacy_name', 'pharmacy_phone', 'strength'],
  medication_logs: ['notes'],
  verification_logs: ['expected_name', 'detected_pills'],
  appointments: ['title', 'provider_name', 'location', 'notes', 'questions', 'follow_up_tasks'],
  journal_entries: ['title', 'content', 'mood'],
  care_notes: ['content'],
  care_tasks: ['title', 'description'],
  ai_insights: ['title', 'description', 'data_points'],
  patient_alerts: ['message'],
  patient_notes: ['content'],
  meals: ['description'],
  family_messages: ['content'],
  notifications: ['title', 'body'],
  chat_messages: ['content'],
  pill_checks: ['problems', 'detections']
};

let key = null;

/** Loads the key from DATA_ENCRYPTION_KEY. Returns true if encryption is on. */
export function initFieldCrypto(secret = process.env.DATA_ENCRYPTION_KEY) {
  key = secret ? crypto.createHash('sha256').update(String(secret)).digest() : null;
  return key !== null;
}

export function isEncryptionEnabled() {
  return key !== null;
}

export function isEncrypted(value) {
  return typeof value === 'string' && value.startsWith(PREFIX);
}

export function encryptValue(value) {
  if (!key || value === null || value === undefined || isEncrypted(value)) return value;
  if (typeof value === 'object') return value; // not a text value; leave untouched
  const iv = crypto.randomBytes(IV_BYTES);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const ciphertext = Buffer.concat([cipher.update(String(value), 'utf8'), cipher.final()]);
  return PREFIX + Buffer.concat([iv, cipher.getAuthTag(), ciphertext]).toString('base64');
}

export function decryptValue(value) {
  if (!isEncrypted(value)) return value;
  if (!key) {
    throw new Error('Encrypted data found but DATA_ENCRYPTION_KEY is not set.');
  }
  const raw = Buffer.from(value.slice(PREFIX.length), 'base64');
  const iv = raw.subarray(0, IV_BYTES);
  const tag = raw.subarray(IV_BYTES, IV_BYTES + TAG_BYTES);
  const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(raw.subarray(IV_BYTES + TAG_BYTES)), decipher.final()]).toString('utf8');
}

/** Decrypts every encrypted string field of a result row, in place. */
export function decryptRow(row) {
  if (!row || typeof row !== 'object') return row;
  for (const k of Object.keys(row)) {
    if (isEncrypted(row[k])) row[k] = decryptValue(row[k]);
  }
  return row;
}

// ── Mapping statement placeholders to encrypted columns ──────────────────────

// Splits on commas that aren't inside parentheses or quotes.
function splitTopLevel(text) {
  const parts = [];
  let depth = 0, quote = null, start = 0;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (quote) { if (ch === quote) quote = null; continue; }
    if (ch === "'" || ch === '"') quote = ch;
    else if (ch === '(') depth++;
    else if (ch === ')') depth--;
    else if (ch === ',' && depth === 0) { parts.push(text.slice(start, i)); start = i + 1; }
  }
  parts.push(text.slice(start));
  return parts.map((p) => p.trim());
}

function countPlaceholders(text) {
  let n = 0, quote = null;
  for (const ch of text) {
    if (quote) { if (ch === quote) quote = null; continue; }
    if (ch === "'" || ch === '"') quote = ch;
    else if (ch === '?') n++;
  }
  return n;
}

/**
 * For an INSERT or UPDATE on a table with encrypted columns, returns the
 * zero-based indexes of the `?` parameters whose values land in an encrypted
 * column. Returns [] for any other statement.
 */
export function encryptedParamIndexes(sql) {
  const flat = sql.replace(/\s+/g, ' ').trim();

  const ins = flat.match(/^insert\s+(?:or\s+ignore\s+)?into\s+(\w+)\s*\(([^)]*)\)\s*values\s*\((.*)$/i);
  if (ins) {
    const cols = ENCRYPTED_COLUMNS[ins[1].toLowerCase()];
    if (!cols) return [];
    const columns = ins[2].split(',').map((c) => c.trim().toLowerCase());
    // VALUES ( ... ) — cut at the matching close paren.
    let depth = 1, end = 0;
    for (; end < ins[3].length && depth > 0; end++) {
      if (ins[3][end] === '(') depth++;
      else if (ins[3][end] === ')') depth--;
    }
    const values = splitTopLevel(ins[3].slice(0, end - 1));
    const out = [];
    let idx = 0;
    values.forEach((v, i) => {
      if (v === '?' && cols.includes(columns[i])) out.push(idx);
      idx += countPlaceholders(v);
    });
    return out;
  }

  const upd = flat.match(/^update\s+(\w+)\s+set\s+(.*?)(\s+where\s+.*)?$/i);
  if (upd) {
    const cols = ENCRYPTED_COLUMNS[upd[1].toLowerCase()];
    if (!cols) return [];
    const out = [];
    let idx = 0;
    for (const assignment of splitTopLevel(upd[2])) {
      const m = assignment.match(/^(\w+)\s*=\s*(.*)$/s);
      const n = countPlaceholders(assignment);
      // `col = ?` or `col = COALESCE(?, col)`: exactly one value going into col.
      if (m && n === 1 && cols.includes(m[1].toLowerCase())) out.push(idx);
      idx += n;
    }
    return out;
  }

  return [];
}
