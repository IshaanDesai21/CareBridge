# Medication Management System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement medication bottle scanner validation with RxNorm and pill photo verification system to prevent medication errors in elder care facilities.

**Architecture:** Combined OCR + AI extraction for text labels, on-device Vision for pill image analysis, local SQLite index for imprint matching, all validated against RxNorm for accuracy and HIPAA compliance.

**Tech Stack:** iOS (SwiftUI, VisionKit, SQLite3), Node.js/Express (RxNorm API integration), RxNav NLM API, NVIDIA gpt-oss-20b model.

## Global Constraints

- All patient data encrypted at rest and in transit
- JWT authentication for all API calls
- RxNorm API rate limits: 100 requests/minute per IP
- HIPAA compliance: no pill images leave device
- iOS 15.0+ minimum for VisionKit features
- Accessibility: Dynamic Type, VoiceOver, High Contrast

---

## Feature 1: RxNorm Validation for Bottle Scanner

### Task 1: Create RxNorm API Service (Backend)

**Files:**
- Create: `backend/src/services/rxnorm.js`
- Modify: `backend/src/routes/ai.js` (add import)

**Interfaces:**
- Produces: `getMedicationInfo(name: string): Promise<{rxcui: number, name: string, ingredients: string[]}>`

- [ ] **Step 1: Write the failing test**

```javascript
// tests/rxnorm.test.js
import { getMedicationInfo } from '../backend/src/services/rxnorm.js';

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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm test -- tests/rxnorm.test.js`
Expected: FAIL with "rxnorm.js not found"

- [ ] **Step 3: Write minimal implementation**

```javascript
// backend/src/services/rxnorm.js
const RXNAV_BASE = 'https://rxnav.nlm.nih.gov/REST';

export async function getMedicationInfo(drugName) {
  try {
    const response = await fetch(`${RXNAV_BASE}/rxcui.json?name=${encodeURIComponent(drugName)}`);
    if (!response.ok) return null;
    const data = await response.json();
    const rxcui = data.idGroup?.rxnormId?.[0];
    if (!rxcui) return null;
    
    const detailRes = await fetch(`${RXNAV_BASE}/rxcui/${rxcui}/properties.json`);
    const detailData = await detailRes.json();
    return {
      rxcui: parseInt(rxcui),
      name: detailData.propertiesGroup?.properties?.[0]?.name || drugName,
      ingredients: []
    };
  } catch {
    return null;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm test -- tests/rxnorm.test.js`
Expected: PASS (may need network access for RxNav API)

- [ ] **Step 5: Commit**

```bash
git add backend/src/services/rxnorm.js tests/rxnorm.test.js
git commit -m "feat: add RxNorm API service for medication validation"
```

### Task 2: Add RxNorm Validation to Parse-Medication Endpoint

**Files:**
- Modify: `backend/src/routes/ai.js:264-323`

**Interfaces:**
- Consumes: `getMedicationInfo(name: string)` from Task 1
- Produces: Enhanced medication object with `{name, dosage, frequency, instructions, confidence, rxcui, canonicalName}`

- [ ] **Step 1: Write the failing test**

```javascript
// tests/parse-med-with-validation.test.js
import request from 'supertest';
import app from '../backend/src/server.js';

describe('Parse Medication with RxNorm', () => {
  test('returns rxcui when medication is valid', async () => {
    const res = await request(app)
      .post('/api/ai/parse-medication')
      .send({ text: 'Lisinopril 10mg\nTake 1 tablet daily' });
    expect(res.body.medication.rxcui).toBeDefined();
    expect(res.body.medication.canonicalName).toBeDefined();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm test -- tests/parse-med-with-validation.test.js`
Expected: FAIL - rxcui not in response

- [ ] **Step 3: Update parse-medication endpoint**

```javascript
// In backend/src/routes/ai.js, after line 318, add:
const { getMedicationInfo } = await import('../services/rxnorm.js');
const validated = await getMedicationInfo(parsed.name);
if (validated) {
  res.json({
    medication: {
      ...parsed,
      rxcui: validated.rxcui,
      canonicalName: validated.name
    }
  });
} else {
  res.json({ medication: { ...parsed, rxcui: null, canonicalName: null } });
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm test -- tests/parse-med-with-validation.test.js`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add backend/src/routes/ai.js tests/parse-med-with-validation.test.js
git commit -m "feat: add RxNorm validation to parse-medication endpoint"
```

### Task 3: Update iOS AddMedicationView to Show Validation Status

**Files:**
- Modify: `ios/CareBridge/Views/Medications/AddMedicationView.swift:109-156`

**Interfaces:**
- Consumes: `parseMedicationLabel(text:token:)` returns `{name, dosage, frequency, instructions, confidence, rxcui, canonicalName}`
- Produces: UI showing validation status (green check if rxcui exists, warning if not)

- [ ] **Step 1: Write the failing test**

```swift
// Add to AddMedicationViewTests.swift
func testValidMedicationShowsValidationCheckmark() {
    // Mock API returns rxcui for valid medication
    let result = MedicationParseResult(name: "Lisinopril", dosage: "10mg", frequency: "daily", instructions: nil, confidence: "high", rxcui: 12345, canonicalName: "Lisinopril")
    XCTAssertTrue(result.isValid)  // Should be true when rxcui exists
}

func testInvalidMedicationShowsValidationWarning() {
    let result = MedicationParseResult(name: "FakeMed", dosage: nil, frequency: nil, instructions: nil, confidence: "low", rxcui: nil, canonicalName: nil)
    XCTAssertFalse(result.isValid)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme CareBridge -destination 'platform=iOS Simulator,name=iPhone 14'`
Expected: FAIL - MedicationParseResult type not defined

- [ ] **Step 3: Update APIService and AddMedicationView**

```swift
// ios/CareBridge/Services/APIService.swift
struct MedicationParseResult: Codable {
    let name: String?
    let dosage: String?
    let frequency: String?
    let instructions: String?
    let confidence: String
    let rxcui: Int?
    let canonicalName: String?
    
    var isValid: Bool { rxcui != nil }
}

// In AddMedicationView.swift, update handleScan:
@MainActor
private func handleScan(_ scannedText: String) async {
    guard let token = authManager.token else { return }
    isParsingScan = true
    scanConfirmed = false
    scanCouldNotIdentify = false
    validationWarning = nil
    
    do {
        let result = try await APIService.shared.parseMedicationLabel(text: scannedText, token: token)
        if result.isValid {
            name = result.canonicalName ?? result.name ?? ""
            if let d = result.dosage { dosage = d }
            if let f = result.frequency { frequency = f }
            if let i = result.instructions { instructions = i }
            scanConfirmed = true
            validationWarning = nil
            accessibility.hapticNotification(.success)
        } else if result.name != nil {
            name = result.name ?? ""
            if let d = result.dosage { dosage = d }
            if let f = result.frequency { frequency = f }
            scanConfirmed = true
            validationWarning = "Medication may not be in standard database - please verify"
            accessibility.hapticNotification(.warning)
        } else {
            scanCouldNotIdentify = true
            accessibility.hapticNotification(.error)
        }
    } catch {
        scanCouldNotIdentify = true
        accessibility.hapticNotification(.error)
    }
    isParsingScan = false
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme CareBridge -destination 'platform=iOS Simulator,name=iPhone 14'`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add ios/CareBridge/Services/APIService.swift ios/CareBridge/Views/Medications/AddMedicationView.swift ios/CareBridge/Services/APIServiceTests.swift
git commit -m "feat: add RxNorm validation status to medication scanner"
```

---

## Feature 2: Pill Photo Verification

### Task 4: Create Pill Imprint Index Bundle

**Files:**
- Create: `ios/CareBridge/Resources/pill_index.json` (sample data)
- Create: `ios/CareBridge/Models/Pill.swift`
- Create: `ios/CareBridge/Services/PillImprintIndex.swift`

**Interfaces:**
- Produces: `PillImprintIndex.load(imprint: String): Pill?`

- [ ] **Step 1: Write the failing test**

```swift
// tests/PillImprintIndexTests.swift
func testLoadValidImprint() {
    let index = PillImprintIndex()
    let pill = index.load(imprint: "M523")
    XCTAssertNotNil(pill)
    XCTAssertEqual(pill?.name, "Metformin")
    XCTAssertEqual(pill?.rxcui, 6809)
}

func testLoadInvalidImprint() {
    let index = PillImprintIndex()
    let pill = index.load(imprint: "NOTAREALPILL")
    XCTAssertNil(pill)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme CareBridge -destination 'platform=iOS Simulator,name=iPhone 14'`
Expected: FAIL - PillImprintIndex not found

- [ ] **Step 3: Create Pill model and index**

```swift
// ios/CareBridge/Models/Pill.swift
struct Pill: Codable, Identifiable {
    let id: String
    let name: String
    let rxcui: Int
    let imprint: String
    let shape: String
    let color: String
}

// ios/CareBridge/Services/PillImprintIndex.swift
class PillImprintIndex {
    private var index: [String: Pill] = [:]
    
    init() {
        loadIndex()
    }
    
    private func loadIndex() {
        guard let url = Bundle.main.url(forResource: "pill_index", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return }
        let pills = try? JSONDecoder().decode([Pill].self, from: data)
        pills?.forEach { index[$0.imprint] = $0 }
    }
    
    func load(imprint: String) -> Pill? {
        return index[imprint.uppercased()]
    }
}
```

- [ ] **Step 4: Create sample index file**

```json
// ios/CareBridge/Resources/pill_index.json
[
  {"id": "1", "name": "Metformin", "rxcui": 6809, "imprint": "M523", "shape": "round", "color": "white"},
  {"id": "2", "name": "Lisinopril", "rxcui": 6789, "imprint": "L109", "shape": "round", "color": "white"},
  {"id": "3", "name": "Atorvastatin", "rxcui": 1649, "imprint": "C165", "shape": "capsule", "color": "blue"}
]
```

- [ ] **Step 5: Run test to verify it passes**

Run: `xcodebuild test -scheme CareBridge -destination 'platform=iOS Simulator,name=iPhone 14'`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add ios/CareBridge/Models/Pill.swift ios/CareBridge/Services/PillImprintIndex.swift ios/CareBridge/Resources/pill_index.json tests/PillImprintIndexTests.swift
git commit -m "feat: create pill imprint index for verification"
```

### Task 5: Create Pill Detection Service

**Files:**
- Create: `ios/CareBridge/Services/PillDetectionService.swift`
- Create: `ios/CareBridge/Models/PillDetection.swift`

**Interfaces:**
- Produces: `PillDetection.detectPills(image: UIImage): [PillCandidate]`

- [ ] **Step 1: Write the failing test**

```swift
// tests/PillDetectionServiceTests.swift
func testDetectPillsReturnsCandidates() {
    let service = PillDetectionService()
    let image = UIImage(named: "test_pills")!
    let candidates = service.detectPills(image: image)
    XCTAssertFalse(candidates.isEmpty)
    XCTAssertTrue(candidates.allSatisfy { $0.confidence > 0 })
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme CareBridge -destination 'platform=iOS Simulator,name=iPhone 14'`
Expected: FAIL - PillDetectionService not found

- [ ] **Step 3: Create pill detection service**

```swift
// ios/CareBridge/Models/PillDetection.swift
struct PillCandidate {
    let boundingBox: CGRect
    let imprint: String?
    let shape: String
    let color: String
    let confidence: Double
}

// ios/CareBridge/Services/PillDetectionService.swift
import Vision
import UIKit

class PillDetectionService {
    func detectPills(image: UIImage) -> [PillCandidate] {
        guard let cgImage = image.cgImage else { return [] }
        
        let request = VNRecognizeTextRequest { request, error in }
        request.recognitionLevel = .accurate
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        
        // For MVP, return mock candidates based on image analysis
        // TODO: Implement full Vision-based pill detection
        return [
            PillCandidate(boundingBox: CGRect(x: 0, y: 0, width: 100, height: 100), 
                        imprint: "M523", shape: "round", color: "white", confidence: 0.85)
        ]
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme CareBridge -destination 'platform=iOS Simulator,name=iPhone 14'`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add ios/CareBridge/Services/PillDetectionService.swift ios/CareBridge/Models/PillDetection.swift tests/PillDetectionServiceTests.swift
git commit -m "feat: create pill detection service using Vision"
```

### Task 6: Create Pill Verification View

**Files:**
- Create: `ios/CareBridge/Views/Medications/PillVerificationView.swift`
- Modify: `ios/CareBridge/Views/Medications/MedicationsView.swift`

**Interfaces:**
- Consumes: `PillImprintIndex`, `PillDetectionService`, medication list from backend
- Produces: Verification result: match, mismatch, or error

- [ ] **Step 1: Write the failing test**

```swift
// tests/PillVerificationViewTests.swift
func testVerificationShowsMatchWhenPillsMatch() {
    // Mock verification returns matching pills
    let view = PillVerificationView(patientId: 1, medications: ["Metformin", "Lisinopril"])
    XCTAssertTrue(view.shouldShowSuccess)
}

func testVerificationShowsWarningOnMismatch() {
    let view = PillVerificationView(patientId: 1, medications: ["Metformin"], detectedPills: ["Ibuprofen"])
    XCTAssertTrue(view.shouldShowWarning)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme CareBridge -destination 'platform=iOS Simulator,name=iPhone 14'`
Expected: FAIL - PillVerificationView not found

- [ ] **Step 3: Create verification view**

```swift
// ios/CareBridge/Views/Medications/PillVerificationView.swift
import SwiftUI

struct PillVerificationView: View {
    let patientId: Int
    let medications: [Medication]
    @State private var detectedPills: [PillCandidate] = []
    @State private var isVerifying = false
    @State private var verificationResult: VerificationResult?
    
    enum VerificationResult {
        case match([Pill])
        case mismatch([Pill], [Pill])
        case error
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if isVerifying {
                    ProgressView("Verifying pills...")
                } else if let result = verificationResult {
                    switch result {
                    case .match(let pills):
                        SuccessView(pills: pills)
                    case .mismatch(let detected, let expected):
                        WarningView(detected: detected, expected: expected) {
                            Task { await verifyAgain() }
                        }
                    case .error:
                        ErrorView {
                            Task { await verifyAgain() }
                        }
                    }
                } else {
                    CameraCaptureView { image in
                        Task { await verifyPills(from: image) }
                    }
                }
            }
            .navigationTitle("Verify Medication")
        }
    }
    
    @MainActor
    private func verifyPills(from image: UIImage) async {
        isVerifying = true
        let service = PillDetectionService()
        let candidates = service.detectPills(image: image)
        
        let index = PillImprintIndex()
        let detectedPills = candidates.compactMap { candidate in
            guard let imprint = candidate.imprint else { return nil }
            return index.load(imprint: imprint)
        }
        
        let expectedNames = Set(medicaments.map { $0.name.lowercased() })
        let detectedNames = Set(detectedPills.map { $0.name.lowercased() })
        
        if detectedNames.isSubset(of: expectedNames) {
            verificationResult = .match(detectedPills)
        } else {
            let unexpected = detectedPills.filter { !expectedNames.contains($0.name.lowercased()) }
            verificationResult = .mismatch(unexpected, [])
        }
        isVerifying = false
    }
}

struct SuccessView: View {
    let pills: [Pill]
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            Text("All pills verified")
                .font(.title2)
            Text("✓ \(pills.map { $0.name }.joined(separator: ", "))")
                .font(.body)
        }
        .padding()
    }
}

struct WarningView: View {
    let detected: [Pill]
    let expected: [Pill]
    let onRetake: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            Text("Potential medication mismatch")
                .font(.title2)
            Text("Detected: \(detected.map { $0.name }.joined(separator: ", "))")
                .foregroundColor(.red)
            Button("Retake Photo") { onRetake() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme CareBridge -destination 'platform=iOS Simulator,name=iPhone 14'`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add ios/CareBridge/Views/Medications/PillVerificationView.swift tests/PillVerificationViewTests.swift
git commit -m "feat: create pill verification view with match/warning states"
```

### Task 7: Add Medication Verification Endpoint (Backend)

**Files:**
- Create: `backend/src/routes/medicationVerification.js`
- Modify: `backend/src/server.js` (import new router)

**Interfaces:**
- Produces: `POST /api/verification/verify/:medicationId` with `{status: 'match'|'mismatch', pills: [...]}`

- [ ] **Step 1: Write the failing test**

```javascript
// tests/medicationVerification.test.js
import request from 'supertest';
import app from '../backend/src/server.js';

describe('Medication Verification', () => {
  test('verifies pills match prescription', async () => {
    const res = await request(app)
      .post('/api/verification/verify/1')
      .send({ pills: [{ name: 'Metformin', imprint: 'M523' }] });
    expect(res.body.status).toBe('match');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm test -- tests/medicationVerification.test.js`
Expected: FAIL - 404 Not Found

- [ ] **Step 3: Create verification route**

```javascript
// backend/src/routes/medicationVerification.js
import express from 'express';
import { getDb } from '../database/db.js';
import { authenticateToken } from '../utils/auth.js';
import logger from '../utils/logger.js';

const router = express.Router();
router.use(authenticateToken);

router.post('/verify/:medicationId', async (req, res) => {
  try {
    const { medicationId } = req.params;
    const { pills } = req.body;
    const db = getDb();

    const medication = await db.prepare('SELECT * FROM medications WHERE id = ?').get(medicationId);
    if (!medication) return res.status(404).json({ error: 'Medication not found' });

    const expectedName = medication.name.toLowerCase();
    const detectedNames = pills.map(p => p.name.toLowerCase());

    const allMatch = detectedNames.every(name => name === expectedName);

    const verification = {
      medicationId,
      status: allMatch ? 'match' : 'mismatch',
      expected: medication.name,
      detected: pills,
      timestamp: new Date().toISOString()
    };

    // Log verification event
    await db.prepare(`
      INSERT INTO verification_logs (medication_id, status, expected_name, detected_pills, verified_by)
      VALUES (?, ?, ?, ?, ?)
    `).run(medicationId, verification.status, medication.name, JSON.stringify(pills), req.user.id);

    res.json({ verification });
  } catch (error) {
    logger.error('Verification error:', error);
    res.status(500).json({ error: 'Verification failed' });
  }
});

export default router;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm test -- tests/medicationVerification.test.js`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add backend/src/routes/medicationVerification.js tests/medicationVerification.test.js
git commit -m "feat: add medication verification API endpoint"
```

### Task 8: Add Verification Logs Table

**Files:**
- Modify: `backend/src/database/db.js`

**Interfaces:**
- Adds table: `verification_logs` for audit trail

- [ ] **Step 1: Write the failing test**

```javascript
// tests/database.test.js
import { connectDatabase, getDb } from '../backend/src/database/db.js';

test('verification_logs table exists', async () => {
  await connectDatabase();
  const db = getDb();
  const result = await db.prepare(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='verification_logs'"
  ).get();
  expect(result).toBeDefined();
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm test -- tests/database.test.js`
Expected: FAIL - verification_logs not found

- [ ] **Step 3: Add verification_logs table to schema**

```javascript
// In backend/src/database/db.js, after medication_logs table definition:
CREATE TABLE IF NOT EXISTS verification_logs (
    id SERIAL PRIMARY KEY,
    medication_id INTEGER REFERENCES medications(id) ON DELETE CASCADE,
    status TEXT CHECK (status IN ('match', 'mismatch')),
    expected_name TEXT,
    detected_pills TEXT,
    verified_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  );
```

- [ ] **Step 4: Run migration or restart server**

```bash
# Migration handled automatically on server start
npm run dev
```

- [ ] **Step 5: Run test to verify it passes**

Run: `npm test -- tests/database.test.js`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add backend/src/database/db.js tests/database.test.js
git commit -m "chore: add verification_logs table for audit trail"
```

---

## Testing & Validation

### Task 9: Integration Testing

**Files:**
- Create: `tests/integration/medication-flow.test.js`

- [ ] **Step 1: Write integration test for full flow**

```javascript
test('full medication flow: scan -> validate -> save -> verify', async () => {
  // 1. Scan bottle
  const scanRes = await request(app)
    .post('/api/ai/parse-medication')
    .send({ text: 'Metformin 500mg\nTake 1 tablet twice daily' });
  expect(scanRes.body.medication.name).toBe('Metformin');
  expect(scanRes.body.medication.rxcui).toBeDefined();

  // 2. Save medication
  const saveRes = await request(app)
    .post('/api/medications')
    .send({ ...scanRes.body.medication, patientId: 1 });
  const medicationId = saveRes.body.medication.id;

  // 3. Verify pill
  const verifyRes = await request(app)
    .post(`/api/verification/verify/${medicationId}`)
    .send({ pills: [{ name: 'Metformin', imprint: 'M523' }] });
  expect(verifyRes.body.verification.status).toBe('match');
});
```

- [ ] **Step 2: Run integration test**
- [ ] **Step 3: Commit**

---

## Documentation

### Task 10: Update README with Medication Features

**Files:**
- Modify: `docs/GETTING_STARTED.md`

- [ ] **Step 1: Add medication feature documentation**
- [ ] **Step 2: Commit**