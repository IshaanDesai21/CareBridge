# Pill Check, Calendar & Family Messages — Design

Date: 2026-10-19
Scope: iOS app (`ios/`) + backend (`backend/`). The SvelteKit dashboard is out of scope.

## Why

CareBridge's caregiver measures out a patient's pills, then hands them over. Two mistakes matter at that moment: the wrong pill, or the wrong number of pills. This work adds a one-photo check right before the handoff. If the check passes, the dose is logged with no extra taps. If it fails, the failure is visible to the family unless the caregiver fixes it.

The family's and patient's main question is "what happened today?" A per-day calendar answers it in one place: check-in scores, medications given, meals, and notes. The family and patient also get a private Messages channel that the caregiver can't see.

This is a **proof of concept**. The pill model only knows four drugs, picked because they look different from each other.

## Goals

1. **Bottle scan → structured medication.** Scanning a prescription label saves the name, dosage (strength), form, pills per dose and doses per day to the patient's medication list.
2. **Pill check.** One photo of a dose's pills, spread out flat, is enough. An on-device model trained with Create ML detects, classifies and counts every pill. The result is checked against the patient's medication list and the day's history. On a pass, each medication and count is logged with the time. On a failure, a clear error is shown and a flagged attempt goes on the calendar.
3. **Calendar** for patient, caregiver and family. Each one shows check-ins, medications given, flagged attempts, meals and notes per day.
4. **Messages** between a patient and their linked family members, as one group conversation per patient. Caregivers can't read it.

## Non-goals (this round)

- **Set dose times** (8 AM / 8 PM schedules, reminders, early/late windows). This is the **planned next step**. Nothing here should block adding it: dose times would sit on top of the same medication list and dose logs.
- Recognizing any pill beyond the four trained drugs, or other forms of those drugs (for example, chewables).
- Photos or attachments in Messages.
- Push notifications for messages when the app is closed.
- Family writing in the calendar. Family reads only and talks to the patient through Messages.
- Dashboard (web) versions of any of this.
- Fixing authorization on existing routes (see "Authorization" for what's required on *new* routes).

## Anti-goals (failure even if it "works")

- **Logging a wrong dose as correct.** When unsure, fail. An "unrecognized pill" error is the safe outcome; a confident wrong label isn't.
- **A caregiver (or organization) able to read family messages** through any API. Hiding it in the UI isn't enough.
- **Flags that never clear** after the caregiver fixes the mistake. Those train the family to ignore flags.
- **A pill check that needs more than one tap after a pass.** It should log right away.

## Decisions made with the user

### Medications and the daily maximum
- The bottle scan saves **pills per dose** and **doses per day** as numbers, plus strength (for example "10 mg") and **form** (`tablet` or `capsule`).
- **Daily maximum** = pills per dose × doses per day. Going over it is flagged.
- *(My call)* **Ranges** like "take 1 to 2 capsules" are stored as `pills_per_dose_min` / `pills_per_dose_max`. Any count in that range passes, and the daily maximum uses the max. A single number sets min = max.
- *(My call)* **As-needed** prescriptions ("…as needed for cough") get an `as_needed` flag. The daily maximum still applies. On the calendar they show "2 doses given (max 3)" instead of "2 of 3 doses", so a skipped as-needed dose doesn't read like a missed one.

### The four trained drugs

| Class label | Drug | Typical look |
|---|---|---|
| `benzonatate` | Benzonatate | yellow gel capsule, glossy |
| `phenazopyridine` | Phenazopyridine | red-brown/maroon round tablet |
| `atorvastatin` | Atorvastatin | white oval film-coated tablet |
| `lisinopril` | Lisinopril | small round tablet, pink/peach/yellow/white by strength and manufacturer |

Combination products are excluded from training: lisinopril/HCTZ, amlodipine/atorvastatin.

### Photo conditions
Pills are spread out on a flat surface (palm, table, countertop), with nothing stacked or overlapping. The capture screen tells the caregiver this.

### Pass/fail rules for one photo
A check **fails** if any of the following is true:
1. A detected pill's type isn't on the patient's **active** medication list.
2. A detected pill's form doesn't match the listed form. For example, the list says capsule but the model saw a tablet.
3. A pill's strength can be read from its imprint and doesn't match the listed strength. (See "Strength check" for what happens when it can't be read.)
4. The model isn't confident about a pill ("unrecognized pill").
5. For a medication in the photo, the count is outside its pills-per-dose range.
6. Adding this dose would push the day's total for that medication over its daily maximum.
7. No pills are detected at all.

A medication **missing** from the photo isn't an error. The caregiver may give different medications at different times. Instead, the calendar shows progress per medication ("Benzonatate 2 of 3 doses").

There are **no fixed dose times**. Doses are counted per calendar day.

### Pass behavior
Log one dose entry per medication in the photo: medication, pill count and time. No confirmation tap. The result screen shows the photo with a labeled box around each pill so the caregiver can see what was counted.

### Fail behavior
Show an error that explains each problem in plain words. For example: "Expected 1 Benzonatate, counted 2", "This pill isn't on Dad's medication list", or "Couldn't recognize 1 pill". Record a **flagged attempt** on the calendar, visible to caregiver, patient and family.

### Corrections
If the **next passing check for the same patient arrives within 30 minutes** of a failed check, that failure is marked *resolved by* the passing check. It's no longer shown as a flag, and only the successful dose appears. If no passing check comes within 30 minutes, the flag stays.

*(My call: what counts as a correction.)* A passing check clears a failure only if it **contains every medication named in that failure**. Failures that name no specific medication ("unrecognized pill", "no pills detected", "pill not on the list") are cleared by any passing check in the window. Example: "Expected 1 Benzonatate, counted 2", then a pass containing only atorvastatin → the benzonatate flag **stays**. Store each failure's problems as structured entries (`{ code, medicationId?, expected?, counted? }`) so this can be checked. Display text is generated from them.

### Medications the model can't check: manual "Mark as given"
Patients usually take more than the four trained drugs. Any medication on the list can also be logged by hand. The caregiver picks the medication and enters the pill count, and it's logged with the time. These entries are labeled **"logged manually"** on the calendar, so the family can tell they weren't photo-checked.
- The **daily maximum still applies**. A manual entry that goes over it is refused with the same over-maximum message, and the attempt is recorded as a flagged entry like a failed photo check (same 30-minute correction rule).
- The count must be within the pills-per-dose range, or it's flagged the same way.
- Manual logging is available for **every** medication, including the four trained ones (camera unavailable, poor lighting). The photo check stays the default path for trained drugs.
- The pill photo itself still fails on any untrained pill. The caregiver photographs the trained drugs and marks the rest by hand.
- Only caregivers/organizations can log doses, manually or by photo.

### Tabs

| Role | Tabs (in order) |
|---|---|
| Patient | Home · **Calendar** (replaces Wellness) · Medications · **Messages** · Profile |
| Caregiver / organization | Patients · Scan Med · **Calendar** · Profile |
| Family | Overview · **Calendar** · **Messages** · Profile |

The daily check-in stays where it is, on Home.

### Calendar layout ("A" from the mockups)
A month grid. Each day has small colored dots: green = medications logged, red = unresolved flag, blue = notes or meals. Tapping a day shows that day's cards below the grid:
- **Check-in**: the day's scores. Show a few headline scores (mood, energy, pain, sleep) with "+N more" to expand all 12.
- **Medications**: each dose given (time, name + strength, count, and "logged manually" when applicable), plus per-medication progress for the day ("2 of 3 doses") for every active medication.
- **Flagged**: unresolved failed checks, with the time and plain-words reasons.
- **Meals**: what the patient ate.
- **Notes**: caregiver notes and patient notes, each labeled with the author's name and time.

### Who can write what on the calendar

| | Patient notes | Caregiver notes | Meals | Read everything |
|---|---|---|---|---|
| Patient | write | — | write | ✓ |
| Caregiver | — | write | write | ✓ |
| Family | — | — | — | ✓ |

### Messages
- One shared group conversation per patient: the patient plus all their linked family members.
- Text only. Arrives live while the app is open (reuse the existing WebSocket in `backend/src/utils/ws.js`). The Messages tab shows an unread badge.
- A family member linked to more than one patient picks which patient's conversation to open.
- **The backend refuses** message reads and writes from anyone who isn't the patient or a linked family member, including caregivers and organizations.

## Current state (what exists, what's wrong)

- **Bottle scan** works end to end: `MedicationScannerView.swift` (Live Text) → `POST /api/ai/parse-medication` (`backend/src/routes/ai.js`, LLM → JSON) → `ScanConfirmSheet` in `AddMedicationView.swift`. But `frequency` is free text. `pills_per_dose`, `doses_per_day` and `form` don't exist in the `medications` table, the parser output, the `Medication` Swift model or the form.
- **Scan Med tab** (`ScanMedicationView` in `ios/CareBridge/Views/Main/TabView.swift` ~L970) is a patient picker that opens `AddMedicationView(autoOpenScanner: true)`. It has no pill check.
- **Pill verification** (`PillVerificationView.swift`, used from the *patient's* `MedicationsView.swift`) uses OCR only. `PillDetectionService` reads imprint text with Vision and counts pills by clustering text boxes, so face-down or imprint-less pills are invisible. Shape and color are hard-coded `"unknown"`.
- **`ios/CareBridge/Resources/pill_index.json`** has made-up or wrong entries (for example, atorvastatin as a "blue capsule") and doesn't include benzonatate or phenazopyridine.
- **`backend/src/services/rximage.js`** (uncommitted) calls the NLM RxImage API, which was retired in 2021, so it always returns null. The `GET /api/medications/pill-lookup` route and `PillImprintIndex.lookupRemote()` depend on it.
- **`verification_logs`** and `POST /api/verification/verify/:medicationId` check one medication at a time by name and have no count logic.
- **No** calendar, patient-authored notes, meals, or person-to-person messaging. `care_notes` exists (caregiver-authored, already shown to family in `FamilyPortalView`). `journal_entries` exists, but `JournalView` isn't reachable from any tab. `chat_messages` is the AI companion and unrelated.
- **Authorization gap:** existing routes like `GET /api/care-notes/:patientId` don't check that the caller may see that patient. New routes must (see below).
- **`GET /api/family/patient`** returns only one linked patient (`LIMIT 1`).
- **Working tree has uncommitted edits** in the medication/verification area (see `git status`). The builder should review them first. Anything touching the RxImage path or the OCR-cluster counting is superseded by this design.
- The Xcode project uses synchronized folders (`PBXFileSystemSynchronizedRootGroup`), so new Swift files and a `.mlmodel` dropped into `ios/CareBridge/` are picked up without editing `project.pbxproj`.

## Design

### 1. Structured medications

**Schema** (`initializeTables()` in `backend/src/database/db.js`, using `ALTER TABLE medications ADD COLUMN IF NOT EXISTS`):
- `form TEXT` (`'tablet' | 'capsule'`, nullable)
- `strength TEXT` (normalized, for example `"10 mg"`). Keep `dosage` for backward compatibility and fill both.
- `pills_per_dose_min INTEGER`, `pills_per_dose_max INTEGER`
- `doses_per_day INTEGER`
- `as_needed INTEGER DEFAULT 0`

**Parser.** Extend the `/parse-medication` prompt and response to return `form`, `pillsPerDose` and `dosesPerDay`. For example, "Take 2 capsules by mouth 3 times daily" → `capsule`, `2`, `3`, and "once daily" → `1`, "every 12 hours" → `2`. Keep `frequency` as human-readable text. The non-AI fallback leaves the new fields null.

**iOS.** `Medication`, `ScannedMedication`, `ScanConfirmSheet` and the manual form gain these fields, editable before saving. `POST`/`PUT /api/medications` accept them.

**Check-ability.** A medication can be pill-checked only if it has `pills_per_dose`, `doses_per_day` and `form`. If one is missing, the pill check fails with "Finish setting up <med>: pills per dose / times per day missing". It doesn't guess.

### 2. Pill model (Create ML object detector)

**Data source:** C3PI archive at `https://data.lhncbc.nlm.nih.gov/public/Pills/`. The index `directory_of_images.txt` (pipe-separated: NDC | part | path | image class | name) lists each image. Relevant image classes:
- `MC_C3PI_REFERENCE_SEG_V1.6`: segmented PNG cut-outs on a plain background. These are the **training source**.
- `C3PI_Test`: consumer-quality photos of single pills. These are the **real-world evaluation source**.

Approximate counts after excluding combo products: lisinopril ~460 cut-outs / ~630 real photos, atorvastatin ~250 / ~150, phenazopyridine ~90 / ~30, benzonatate ~70 / ~45. Product metadata (imprint, color, shape, strength) is in the archive's XML.

**Synthetic mixed-pill images.** C3PI shows one pill per image. To train a detector, generate composites: 1–8 pills per image (mixed classes), randomly rotated, scaled, lit and placed **without overlap** on background images (palms, countertops, tables, paper towels). Bounding boxes are known from placement, so annotations are generated automatically in Create ML's JSON format. Hold out by product (NDC), not by image, so evaluation reflects unseen manufacturers.

**Pipeline lives in the repo** under `ml/pill-detector/`: download → filter → composite → train (Create ML, `createml` CLI or a Swift script using `CreateML.MLObjectDetector`) → evaluate. It's scripted so it can be re-run when classes change. The raw C3PI download and generated images are git-ignored. Only the scripts, a small manifest, and the trained `PillDetector.mlmodel` are committed.

**Distractor pills** *(my call)*. The anti-goal is "confident wrong label", and many unrelated pills are small white rounds. So composites also include pills from **other C3PI drugs**, especially look-alikes (white/pink/yellow round and oval tablets, yellow and two-tone capsules), labeled as a fifth class `other`. At check time, an `other` detection is an "unrecognized pill" failure. The evaluation adds a metric: held-out non-target pills must be labeled `other` or fall below threshold at least 90% of the time.

**On device.** `PillDetector.mlmodel` goes in `ios/CareBridge/Resources/`. A rewritten `PillDetectionService` runs it through Vision (`VNCoreMLRequest`) and returns detections (box, class, confidence). Any detection below the confidence threshold counts as an **unrecognized pill**, not as the top class.

**Acceptance bar** (my call; adjust if training can't reach it):
- Held-out synthetic composites: correct count of each class in ≥ 95% of images.
- Real `C3PI_Test` single-pill photos: ≥ 90% top-1 class accuracy, and below-threshold rather than wrong at least as often as wrong.
- Held-out non-target (distractor) pills: rejected (`other` or below threshold) ≥ 90%.
- Inference under 1 s on a recent iPhone.

If the bar isn't met, report the actual numbers rather than shipping silently.

**Strength check (my call).** The model identifies the drug. Strength comes from the imprint. After detection, run Vision text recognition inside each pill's box. Map the imprint to strength using a small **appearance catalog** built from C3PI metadata for the four drugs (imprint → drug, strength, form, color, shape). It replaces `pill_index.json`.
- Readable imprint, wrong strength or drug → **fail**.
- Unreadable imprint → **don't fail on strength**. Record "strength not verified" on the dose log.
- Rationale: most imprints won't be readable from a casual palm photo. Failing on every unreadable imprint would make the check unusable, and the drug, form and count checks still protect against the main errors.

### 3. Pill check flow and storage

**Flow (iOS, Scan Med tab).** Pick a patient (existing list), then choose **Scan Bottle** (existing flow, now structured), **Check Pills**, or **Mark as Given** (pick a medication and enter the count). Check Pills opens the camera with the "spread pills flat, nothing stacked" hint, takes one photo, runs detection on-device, and sends detections to the backend. It then shows the result: the photo with labeled boxes, plus either "Logged ✓ <med ×n>…" or the list of problems with a **Retake** button.

**Rules run on the backend** (my call). The backend owns the medication list and the day's totals, so it's the one source of truth for pass/fail and the 30-minute correction window. The rules are easy to unit-test in vitest. Implement them as a pure function (detections + medications + today's dose totals + recent failed checks → result) called by the route. Setup-incomplete medications ("pills per dose missing") fail only if that medication actually appears in the photo.

`POST /api/pill-checks` with `{ patientId, localDate, detections: [{ label, confidence, imprint?, box }] }` → `{ check: { id, status: 'pass'|'fail', problems: [...], doses: [...] } }`.

**Tables:**
- `pill_checks`: id, patient_id, performed_by (user), status (`pass`/`fail`), problems (JSON text), detections (JSON text), local_date (TEXT `YYYY-MM-DD`), created_at, resolved_by_check_id (nullable FK to `pill_checks`).
- `dose_logs`: id, patient_id, medication_id, pill_check_id (nullable), source (`photo`/`manual`), pill_count, strength_verified (0/1), logged_by, local_date, given_at.
- Manual entries go through `POST /api/dose-logs/manual` `{ patientId, medicationId, pillCount, localDate }`. It runs the same count and daily-maximum rules (shared with the photo rule function). On failure it writes a `fail` `pill_checks` row with no detections, so flags and corrections work identically.

Photos are **not** uploaded or stored (my call: privacy, and nothing needs them later).

**Correction.** When a check passes, mark any unresolved `fail` checks for the same patient created within the previous 30 minutes as `resolved_by_check_id = <this check>`.

**Retire:** `rximage.js`, `GET /api/medications/pill-lookup`, `PillImprintIndex.lookupRemote()`, `pill_index.json`, the OCR-cluster counter, `POST /api/verification/verify/...` and its iOS caller. Leave the `verification_logs` table in place; dropping tables isn't needed. Remove the pill check from the **patient's** `MedicationsView` (my call: it's a caregiver feature now, and two verifiers would drift apart).

### 4. Calendar

**Day boundaries.** New tables store a client-sent `local_date` (`YYYY-MM-DD`, device time zone), so "today" means the patient's or caregiver's day, not UTC. Existing `wellness_checkins.date` is used as-is (it's server `CURRENT_DATE`). This mismatch is known and out of scope.

**Storage:**
- Caregiver notes: reuse `care_notes`, so they also keep appearing in the existing caregiver and family Notes tabs. Add `local_date TEXT`, and fill it on new inserts.
- Patient notes: new `patient_notes` (id, patient_id, author_user_id, content, local_date, created_at, updated_at).
- Meals: new `meals` (id, patient_id, author_user_id, meal_type `breakfast|lunch|dinner|snack`, description, local_date, created_at, updated_at).
- Authors can edit and delete their own notes and meals (my call).

**API:**
- `GET /api/calendar/:patientId?month=YYYY-MM` → per-day summary for the dots: has doses, has unresolved flag, has notes or meals, has check-in.
- `GET /api/calendar/:patientId/day/:date` → check-in, dose logs, per-medication progress (`given / doses_per_day` for active medications), unresolved flagged checks, meals, and notes from both sources with author names.
- CRUD: `/api/patient-notes`, `/api/meals`. Caregiver notes keep using `/api/care-notes`, extended to accept `localDate`.

**iOS.** One shared `CalendarView` (layout A) that takes a patient id and the viewer's role and shows the right "add" buttons. Caregivers pick a patient first, from the same list as Scan Med. Family members with more than one linked patient pick one. Patients go straight in. `WellnessView` is removed from the patient tabs; the check-in history now lives in the calendar.

### 5. Messages

**Storage:**
- `family_messages`: id, patient_id, sender_user_id, content, created_at.
- `family_message_reads`: user_id, patient_id, last_read_message_id (unique user_id + patient_id).

**API:**
- `GET /api/messages/:patientId?before=<id>` (paged)
- `POST /api/messages/:patientId`
- `POST /api/messages/:patientId/read`
- `GET /api/messages/unread` (counts per patient)

On send, push `{ type: 'family_message', patientId, message }` through `sendToUser()` to every participant except the sender.

**Access rule (strict):** the caller is the patient (`patients.user_id = caller`) or has a `family_patient_links` row for that patient. Anyone else gets **403**, whatever their role.

**Family with several patients:** add `GET /api/family/patients` (all linked patients). The existing `/family/patient` stays for current callers.

**iOS.** A `MessagesView` chat screen for patient and family, with the unread badge on the tab. A WebSocket listener updates the open conversation and the badge.

### Authorization (new routes)

Add one shared helper, for example `canAccessPatient(user, patientId)` in `backend/src/utils/`:
- patient → their own patient record
- family → linked patients
- caregiver/organization → the same scope as `GET /api/patients` (org-scoped, else all)

Every new calendar, notes, meals and pill-check route uses it. Messages use the stricter patient-or-family rule above. Write rules apply on top: only patients write patient notes, only caregivers write caregiver notes, only patient or caregiver write meals, only caregiver or organization run pill checks.

### Demo mode

Every new `APIService` method gets an `isDemoMode` branch with canned data (`demo*`), following the existing pattern. Demo data should include a month of calendar days, one resolved and one unresolved flag, meals, notes from both authors, and a short family conversation, so App Review and offline demos show the features.

### Testing

- **Backend (vitest, existing mock pattern):** the pill-check rule function, covering every fail condition, the daily maximum across several checks, the 30-minute correction (inside and outside the window), and missing setup fields. Also access control on calendar and message routes, including caregiver → 403 on messages, and the calendar day aggregation.
- **iOS (XCTest):** parsing of the new medication fields, the detection → request mapping (threshold → unrecognized), and calendar day model decoding.
- **Model:** the evaluation script prints the acceptance-bar numbers.

## Left to the builder

- Exact visual styling within layout A, and the chat UI look. Follow the app's existing `Color.cb*` palette and components.
- Background images for compositing (must be license-clear), the composite count, and training hyperparameters.
- Exact request/response field names beyond those sketched, and pagination size.
- Confidence threshold value (tune on the held-out set).
- Order of work. Suggested: structured medications → pill-check backend rules → model pipeline → iOS pill check → calendar → messages.

## Planned next step

Set dose times per medication, with reminders, on-time/late status on the calendar, and missed-dose alerts.
