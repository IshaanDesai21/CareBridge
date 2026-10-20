# Plan B — Calendar, Notes & Meals Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A month-grid Calendar tab for patient, caregiver and family showing per-day check-in scores, doses given with per-medication progress, unresolved flags, meals, and patient and caregiver notes. Patients and caregivers can write notes and meals; family reads only.

**Architecture:**
- Backend: two read endpoints aggregate the existing `wellness_checkins`, `care_notes`, the Plan A `dose_logs`/`pill_checks`, and new `patient_notes`/`meals` tables. Aggregation is a pure module so it's unit-tested without a DB.
- iOS: one `CalendarView` parameterized by patient id and viewer role.

**Tech Stack:** Express + pg wrapper + vitest; SwiftUI iOS 17.

**Spec:** `docs/superpowers/specs/2026-10-19-pill-check-calendar-messages-design.md` (§ Calendar, layout "A").

**Depends on:** Plan A Tasks 1 (`canAccessPatient`, test helpers), 2 (medication dosing columns), 4 (`dose_logs`, `pill_checks`), 9 (`Date.localDateString`).

## Global Constraints

- Layout A: month grid with per-day dots (green = doses logged, red = unresolved flag, blue = notes or meals). Tapping a day shows cards in this order: Check-in, Medications, Flagged, Meals, Notes.
- Tab orders, exactly:
  - patient: Home · Calendar · Medications · Messages · Profile (Messages is added in Plan C; Plan B inserts Calendar where Wellness was)
  - caregiver/organization: Patients · Scan Med · Calendar · Profile
  - family: Overview · Calendar · Messages · Profile
- Write rules:
  - patient notes: patient only
  - caregiver notes: caregiver/organization only
  - meals: patient or caregiver/organization
  - family: no writes
  - edit/delete: author only
- Meal types: `breakfast | lunch | dinner | snack`.
- Progress per active medication = **number of dose events** (`dose_logs` rows) that day vs `doses_per_day`. As-needed meds read `"<n> doses given (max <doses_per_day>)"`; others read `"<n> of <doses_per_day> doses"`. Show "logged manually" on manual doses.
- New tables store client `local_date`. `wellness_checkins.date` is used as-is.
- All reads and writes check `canAccessPatient` (Plan A Task 1).
- Every new `APIService` method has a demo branch.
- iOS verification = the build command from Plan A + a demo-mode run.

## Review Focus

1. **Several check-ins on one day.** Show the latest (by `created_at`), not the first or a merge. Test in Task 2.
2. **A medication deactivated mid-month.** Its past doses still appear on those days, but no progress row for inactive meds. Test in Task 2.
3. **A flag resolved later the same day.** The day must not show a red dot or the Flagged card. Test in Task 2.
4. **An invalid `month` / `date` parameter** (`2026-13`, `banana`). Expect 400, not a 500 or an empty 200. Test in Task 3.
5. **A family member tries to POST a note or meal.** Expect 403 even though they can read. Test in Task 4.

---

## File Structure

- `backend/src/database/db.js`: `patient_notes`, `meals` tables; `care_notes.local_date`.
- `backend/src/services/calendarAggregate.js` *(new, pure)*: build month dots and day payload.
- `backend/src/routes/calendar.js` *(new)*: `GET /api/calendar/:patientId` (month), `GET /api/calendar/:patientId/day/:date`.
- `backend/src/routes/patientNotes.js`, `backend/src/routes/meals.js` *(new)*: CRUD.
- `backend/src/routes/careNotes.js`: accept `localDate`, role and access checks on POST.
- `ios/CareBridge/Models/CalendarModels.swift` *(new)*: `CalendarMonth`, `CalendarDay`, `MedicationProgress`, `DayDose`, `DayFlag`, `Meal`, `DayNote`.
- `ios/CareBridge/Views/Calendar/CalendarView.swift`, `CalendarMonthGrid.swift`, `CalendarDayCards.swift`, `NoteEditorSheet.swift`, `MealEditorSheet.swift`, `CalendarPatientPicker.swift` *(new)*.
- `ios/CareBridge/Views/Main/TabView.swift`: tab wiring.
- Delete `ios/CareBridge/Views/Wellness/WellnessView.swift` (`WellnessHistoryCard` and `MetricBadge` are used only there).

---

### Task 1: Notes & meals storage

**Files:** Modify `backend/src/database/db.js`.

**Interfaces:**
- Produces:
  - `patient_notes`: `id SERIAL PK, patient_id INT FK patients CASCADE, author_user_id INT FK users SET NULL, content TEXT NOT NULL, local_date TEXT NOT NULL, created_at, updated_at`
  - `meals`: `id SERIAL PK, patient_id INT FK CASCADE, author_user_id INT FK users SET NULL, meal_type TEXT CHECK (meal_type IN ('breakfast','lunch','dinner','snack')), description TEXT NOT NULL, local_date TEXT NOT NULL, created_at, updated_at`
  - `ALTER TABLE care_notes ADD COLUMN IF NOT EXISTS local_date TEXT`
  - Indexes on `(patient_id, local_date)` for both new tables.

- [ ] **Step 1:** Add the DDL. In `backend/tests/db-schema.test.js`, following its existing pattern, add assertions that the init SQL contains `CREATE TABLE IF NOT EXISTS patient_notes`, `CREATE TABLE IF NOT EXISTS meals`, and `care_notes ADD COLUMN IF NOT EXISTS local_date`.
- [ ] **Step 2:** `cd backend && npx vitest run tests/db-schema.test.js`. Expected: PASS after adding the DDL (FAIL before).
- [ ] **Step 3:** Commit: `feat(calendar): patient_notes and meals tables`.

---

### Task 2: Calendar aggregation (pure)

**Files:** Create `backend/src/services/calendarAggregate.js`; Test `backend/tests/calendarAggregate.test.js`.

**Interfaces:**
- Produces:
  - `buildMonth({ month: 'YYYY-MM', checkinDates: string[], doseDates: string[], flagDates: string[], noteDates: string[], mealDates: string[] }) → { month, days: Array<{ date, hasCheckin, hasDoses, hasFlag, hasEntries }> }`
    - One entry per calendar day of the month. `hasEntries` = notes or meals.
  - `buildDay({ date, checkins, medications, doseLogs, failedChecks, meals, careNotes, patientNotes }) → DayPayload`
  - `DayPayload` (camelCase JSON):
    ```
    { date,
      checkin: null | { energy, fatigue, pain, mood, sleepQuality, breathing, mobility, balance, speechClarity, appetite, hydration, swallowingDifficulty, notes, createdAt },
      doses: [{ id, medicationId, name, strength, pillCount, source, strengthVerified, givenAt }],      // ordered by givenAt
      progress: [{ medicationId, name, strength, given, dosesPerDay, asNeeded, label }],                 // active meds with doses_per_day set, ordered by name
      flags: [{ id, createdAt, source, messages: string[] }],                                            // unresolved fail checks only
      meals: [{ id, mealType, description, authorUserId, authorName, createdAt }],
      notes: [{ id, kind: 'caregiver'|'patient', content, authorUserId, authorName, createdAt }] }      // both kinds merged, ordered by createdAt
    ```
  - `progress.label` exact copy: `"<given> of <dosesPerDay> doses"`, or `"<given> doses given (max <dosesPerDay>)"` when `asNeeded`.

- [ ] **Step 1: Write failing tests:**
  - `buildMonth("2026-02")` has 28 days; `"2026-10"` has 31
  - a flag date sets `hasFlag` only on that day
  - `buildDay` with two check-ins picks the later `created_at` *(RF 1)*
  - inactive med: its dose is in `doses`, no `progress` row *(RF 2)*
  - a resolved failed check (`resolved_by_check_id` set) is excluded from `flags` *(RF 3)*
  - progress label for a normal med with 2 doses of 3: `"2 of 3 doses"`; as-needed: `"2 doses given (max 3)"`
  - notes from both sources are merged and sorted, with the right `kind`
  - `flags[].messages` comes from the stored problems' `message` fields
- [ ] **Step 2:** `npx vitest run tests/calendarAggregate.test.js`. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Re-run. Expected: PASS.
- [ ] **Step 5:** Commit: `feat(calendar): pure month and day aggregation`.

---

### Task 3: Calendar read routes

**Files:** Create `backend/src/routes/calendar.js`; modify `backend/src/server.js` (`app.use('/api/calendar', calendarRoutes)`); Test `backend/tests/calendarRoutes.test.js`.

**Interfaces:**
- Consumes: `buildMonth`, `buildDay` (Task 2), `canAccessPatient`.
- Produces:
  - `GET /api/calendar/:patientId?month=YYYY-MM` → `200 { month, days }`. `400 {error:'Invalid month'}` unless `/^\d{4}-(0[1-9]|1[0-2])$/`.
  - `GET /api/calendar/:patientId/day/:date` → `200 { day: DayPayload }`. `400 {error:'Invalid date'}` unless it's a valid `YYYY-MM-DD`.
  - Both → `403 {error:'Access denied'}` when `!canAccessPatient`.
  - Query sources:
    - month: `DISTINCT date`/`local_date` per table filtered by `LIKE 'YYYY-MM-%'`; flags = `pill_checks` with `status='fail' AND resolved_by_check_id IS NULL`
    - day: rows for that date; `care_notes` match `local_date = ?` **or** (`local_date IS NULL AND created_at::date = ?`) so legacy notes still show; author names via `users` join

- [ ] **Step 1: Write failing tests** (`invokeRoute` + `fakeDb`): month 200 shape; `month=2026-13` → 400 *(RF 4)*; `date=banana` → 400 *(RF 4)*; no access → 403; day 200 passes rows through to `day`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement and mount.
- [ ] **Step 4:** `npx vitest run`. Expected: PASS.
- [ ] **Step 5:** Commit: `feat(calendar): month and day endpoints`.

---

### Task 4: Notes & meals write routes

**Files:** Create `backend/src/routes/patientNotes.js`, `backend/src/routes/meals.js`; modify `backend/src/routes/careNotes.js` (POST/PUT), `backend/src/server.js` (`/api/patient-notes`, `/api/meals`); Test `backend/tests/notesMeals.test.js`.

**Interfaces:**
- Produces:
  - `POST /api/patient-notes` `{ patientId, content, localDate }` → `201 { note }`. Role must be `patient` **and** own the patient (`canAccessPatient`).
  - `PUT /api/patient-notes/:id` `{ content }` and `DELETE /api/patient-notes/:id`: author only, else 403.
  - `POST /api/meals` `{ patientId, mealType, description, localDate }` → `201 { meal }`. Roles `patient|caregiver|organization` + access.
  - `PUT /api/meals/:id` and `DELETE /api/meals/:id`: author only.
  - `POST /api/care-notes`: now requires role `caregiver|organization` + access; stores `localDate` → `local_date`. `PUT`: author only. GET unchanged.
  - Validation: empty content/description → 400; bad `mealType` → 400; bad `localDate` → 400.

- [ ] **Step 1: Write failing tests:**
  - family POST meal → 403 *(RF 5)*; family POST patient note → 403
  - caregiver POST patient note → 403
  - patient POST meal → 201 (INSERT params include `local_date`)
  - non-author PUT meal → 403; author DELETE meal → 200
  - caregiver POST care note stores `local_date`
  - `mealType:'brunch'` → 400
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement and mount.
- [ ] **Step 4:** `npx vitest run`. Expected: PASS.
- [ ] **Step 5:** Commit: `feat(calendar): patient notes, meals, and scoped caregiver notes`.

---

### Task 5: iOS calendar models & API

**Files:** Create `ios/CareBridge/Models/CalendarModels.swift`; modify `ios/CareBridge/Services/APIService.swift`.

**Interfaces:**
- Produces:
  - Swift `Codable` mirrors of `buildMonth`/`DayPayload`: `CalendarMonth { month, days: [CalendarDaySummary] }`, `CalendarDaySummary { date, hasCheckin, hasDoses, hasFlag, hasEntries }`, `CalendarDay` (fields as in `DayPayload`; nested `DayCheckin`, `DayDose`, `MedicationProgress`, `DayFlag`, `Meal`, `DayNote`). Keys are camelCase, matching the server.
  - `APIService`:
    - `getCalendarMonth(patientId: Int, month: String, token: String) async throws -> CalendarMonth`
    - `getCalendarDay(patientId: Int, date: String, token: String) async throws -> CalendarDay`
    - `addPatientNote(patientId:content:localDate:token:) -> DayNote`; `addCareNote(patientId:content:localDate:token:) -> DayNote`
    - `updateNote(kind:id:content:token:)`; `deleteNote(kind:id:token:)` (kind routes to `patient-notes` or `care-notes`; care-notes has no DELETE today, so skip delete for caregiver notes and hide that button)
    - `addMeal(patientId:mealType:description:localDate:token:) -> Meal`; `updateMeal(id:mealType:description:token:)`; `deleteMeal(id:token:)`
  - Demo data:
    - `demoCalendarMonth(for month:)`: dots on ~70% of past days; one red (unresolved flag) day, three days ago
    - `demoCalendarDay(date:)`: today has a full payload (check-in, 3 doses including one manual, progress rows including one as-needed, meals, both note kinds); the flag day has one flag; other days are lighter
    - writes return the posted object

- [ ] **Step 1:** Implement.
- [ ] **Step 2:** iOS build. Expected: SUCCEEDED.
- [ ] **Step 3:** Commit: `feat(ios): calendar models and API client`.

---

### Task 6: iOS Calendar UI + tab wiring

**Files:** Create `ios/CareBridge/Views/Calendar/{CalendarView,CalendarMonthGrid,CalendarDayCards,NoteEditorSheet,MealEditorSheet,CalendarPatientPicker}.swift`; modify `ios/CareBridge/Views/Main/TabView.swift`; delete `ios/CareBridge/Views/Wellness/WellnessView.swift`.

**Interfaces:**
- Consumes: Task 5 API and models; `Date.localDateString` (Plan A).
- Produces:
  - `CalendarView(patientId: Int, viewerRole: String)`:
    - Month header with ‹ › arrows.
    - `CalendarMonthGrid` with dots: green `hasDoses`, red `hasFlag`, `Color.cbPrimary`-blue `hasEntries`.
    - Selected day defaults to today.
    - `CalendarDayCards` below the grid, in the order Check-in, Medications (progress rows, then dose rows with time; `"logged manually"` caption for manual; `"strength not verified"` caption when false), Flagged (red card per flag: time + messages), Meals, Notes (author name + kind badge + time).
    - Check-in shows mood, energy, pain and sleep, plus a "+8 more" disclosure revealing the rest.
    - Empty states per card: `"No check-in"`, `"No doses logged"`, `"No meals logged"`, `"No notes"`. Flagged is hidden when empty.
    - Toolbar `+` menu: "Add note" (patient → patient note; caregiver/org → caregiver note) and "Add meal" (patient, caregiver/org). Hidden for family.
    - Swipe actions edit/delete on own entries.
    - Refreshes the day + month after a write.
  - `CalendarPatientPicker(content: (Patient) -> some View)`: loads `getPatients`. Exactly one patient → shows `content` directly; several → a list that pushes `content`.
  - Tabs:
    - patient: replace `WellnessView()` with `CalendarView(patientId:viewerRole:"patient")`, resolving the id via `getMyPatient`. Label `"Calendar"`, system image `"calendar"`.
    - caregiver: insert `CalendarPatientPicker { CalendarView(patientId: $0.id, viewerRole: role) }` between Scan Med and Profile.
    - family: insert the same picker after Overview.

- [ ] **Step 1:** Implement the views and wiring; delete `WellnessView.swift`.
- [ ] **Step 2:** iOS build. Expected: SUCCEEDED.
- [ ] **Step 3:** Demo run for each role (`loginAsDemo(role:)`):
  - patient: Calendar is tab 2; add a meal and a note; they appear.
  - caregiver: Calendar is tab 3; picker → patient → red-dot day shows the Flagged card.
  - family: Calendar is tab 2 with no `+` button.
- [ ] **Step 4:** Commit: `feat(ios): calendar tab for patient, caregiver and family`.

---

## Self-review notes

- Spec coverage:

  | Spec item | Task |
  |---|---|
  | Calendar contents | 2, 6 |
  | Write matrix | 4, 6 |
  | Layout A | 6 |
  | Tabs | 6 (Messages tab in Plan C) |
  | `local_date` | 1, 4 |
  | Legacy care notes | 3 |
  | Authorization | 3, 4 |
  | Demo | 5 |
