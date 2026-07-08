# CareBridge Medication Management System Design Specification

## Overview

This document outlines the approach for implementing medication management features for the CareBridge platform: 
1. **Medication Bottle Scanner** - Allows caregivers to scan prescription bottles to automatically capture medication details
2. **Pill Photo Verification** - Prevents medication errors by verifying pills against prescription lists before administration

## Goals

1. **Reduce Medication Errors** - Eliminate manual transcription errors by connecting OCR and image recognition to RxNorm pharmacy databases.
2. **Improve Caregiver Efficiency** - Minimize time spent on medication documentation and verification.
3. **Maintain HIPAA Compliance** - Ensure all patient health information remains secure and protected.
4. **Ensure Accessibility** - Make medication management accessible to elderly users with visual and motor impairments.

## Feature 1: Medication Bottle Scanner (v1)

### Objective
Allow caregivers to scan prescription bottle labels to automatically populate medication details into the patient's record.

### Workflow
1. Caregiver opens camera scanner
2. Scanner captures label text using VisionKit
3. OCR text sent to NVIDIA gpt-oss-20b API for structured medication extraction:
   ```json
   {
     "name": "string|null",
     "dosage": "string|null", 
     "frequency": "string|null",
     "instructions": "string|null",
     "isMedication": "boolean"
   }
   ```
4. Extracted medication validated against RxNorm index
5. Caregiver reviews and confirms details
6. Medication saved to patient's record

### Validation Pipeline
1. Raw OCR text → gpt-oss-20b structured extraction
2. Structured medication validated against RxNorm API
3. Extracted name checked against canonical RxNorm name to confirm validates true
4. Dosage/frequency/instructions strings stored as-is

## Feature 2: Pill Photo Verification (v1)

### Objective
Prevent medication errors by verifying pills against prescription lists before administration.

### Workflow
1. Caregiver selects medication to verify on patient dashboard
2. Takes photo of pills using camera
3. VisionKit detects pills and reads imprint codes on-device
4. Local SQLite index lookup: `imprint → {name, rxcui, standard_format}`
5. Detected name compared against patient's active medication list
6. If mismatch detected, show warning with options:
   - Re-verify
   - Manual override (requires caregiver confirmation)
   - Cancel verification
7. If match confirmed, log verification event

### Technical Constraints
- All image processing occurs on-device to maintain HIPAA compliance
- Only extracted text attributes (imprint, shape, color) leave device for lookup
- Local pill index contains only medication metadata (imprint → {name, rxcui, standard_format})
- Index periodically refreshed via backend API from RxImage/NLM data sources
- No patient data is stored in the pill index

## Architecture Overview

### Components
1. **iOS Scanner Module**: VisionKit-based image capture and OCR processing
2. **Medication Parser Service**: NVIDIA API call for text-to-structure conversion
3. **RxNorm Validation Layer**: Structured medication name validation service
4. **Local Pill Index**: Lightweight SQLite database bundled with app
5. **RxImage Index Service**: Public medication database matching imprints to standard names/rxcui mappings
6. **Backend Verification Service**: API endpoints for iOS to validate against RxNorm catalog

### Data Flow
```
Patient App (iOS) 
  ↓ Scan Label / Take Photo
JSON Parsing + RxNorm Lookup 
  ↓ Structured Validation 
Backend API 
  ↓ Save to PostgreSQL 
  ↓ Update Patient Medication List
```

## Implementation Details

### Feature 1 Headers
- `MedicationLabelParser.swift` - Handles OCR text → structured medication data
- `RxNormValidator.swift` - Validates extracted medication names against canonical RxNorm database
- `MedicationSaveView.swift` - Caregiver review interface

### Feature 2 Headers
- `PillVerificationService.swift` - Main verification engine
- `PillImprintIndex.swift` - Local index management
- `PillVerificationView.swift` - UI verification interface

### Dependencies
- VisionKit (Framework)
- RxNorm API (External: https://rxnav.nlm.nih.gov/REST/)
- NVIDIA AI API for text parsing
- SQLite3 (Embedded database)

## Key Considerations

### Accessibility Requirements
- All medication text must support dynamic type scaling
- Verification states must have VoiceOver labels
- Verification warnings must be clearly distinguishable by color and pattern
- All validation results must be read aloud to user

### Error Handling
- If RxNorm validation fails: show "Medication Not Found" screen with search/suggest option
- If verification fails unexpectedly: show "Unexpected Error" with retry option
- If network unavailable: gracefully fall back to manual entry path

### Security
- All medication data encrypted at rest and in transit
- JWT authentication for all API calls
- Local index stored in app container with appropriate file permissions
- All API keys stored in Keychain, not bundled

## Success Metrics
- 90% reduction in medication entry documentation time
- 0 medication administration errors due to verification system
- 95% caregiver satisfaction with scanning experience
- 0 HIPAA violations or data breaches

## Future Enhancements
1. Real-time pill interaction checking
2. Custom ML model for imprint detection
3. Barcode scanning integration
4. List barcode integration
5. Oral administration confirmation checklist

## Approval Checklist
- [x] Architecture approved
- [x] Data flow validated
- [x] Contact points identified
- [x] Dependencies listed