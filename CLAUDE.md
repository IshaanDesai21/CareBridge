# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

CareBridge is a healthcare coordination platform with three apps in one repo:

- `backend/` — Express REST + WebSocket API (Node, ESM, Postgres)
- `dashboard/` — SvelteKit web app for caregivers/family/organizations
- `ios/` — SwiftUI iOS app for patients (plus a widget extension)

All clients talk to the same backend API under `/api/*`.

## Commands

### Root (runs backend + dashboard together)
```bash
npm run install:all   # installs root, backend, and dashboard deps
npm run dev           # runs backend + dashboard concurrently (colored prefixes)
npm run dev:backend
npm run dev:dashboard
npm run build         # builds the dashboard only
```

### Backend (`backend/`)
```bash
npm run dev           # nodemon src/server.js
npm start              # node src/server.js
npm test               # vitest run (all tests)
npx vitest run tests/medicationVerification.test.js   # single file
npx vitest run -t "test name"                          # single test by name
```
Requires `backend/.env` (see `.env.example` at repo root) — notably `DATABASE_URL` (Postgres) and `JWT_SECRET`. Without `NVIDIA_API_KEY`, AI chat/overview endpoints fall back to canned responses or a 503 rather than failing the whole server.

Tests mock `getDb`/`authenticateToken`/`logger` and invoke route handlers directly (no live DB, no real HTTP server) — see `backend/tests/integration/medication-flow.test.js` for the pattern. `backend/tests/setup.js` sets `NVIDIA_API_KEY` globally before any module loads.

### Dashboard (`dashboard/`)
```bash
npm run dev      # vite dev --port 5173
npm run build    # vite build (adapter-node — produces a real Node server, not static)
npm run check    # svelte-kit sync && svelte-check
```
`dashboard/.env` sets `VITE_API_URL` (defaults to same-origin if unset).

### iOS (`ios/`)
Open `ios/CareBridge.xcodeproj` in Xcode (15+, iOS 17+ deployment target) and run with Cmd+R. `ios/project.yml` exists for XcodeGen but the checked-in `.xcodeproj` is the source of truth — prefer editing it directly via Xcode rather than regenerating. Tests under `ios/CareBridge/Tests/` are XCTest and run via Xcode's test runner (Cmd+U) or `xcodebuild test`.

## Architecture

### Backend: SQLite-shaped API over Postgres
`backend/src/database/db.js` is the key file to read before touching any route — it implements a `better-sqlite3`-shaped wrapper (`db.prepare(sql).get/all/run(...)` with `?` placeholders) on top of a real `pg` Pool. Placeholders get rewritten to `$1, $2, ...`, and `INSERT OR IGNORE` is rewritten to `ON CONFLICT DO NOTHING`. This means route code looks synchronous-sqlite-ish but every call must be `await`ed. All tables are created/migrated idempotently at boot (`initializeTables()`), not via a migrations tool — new columns are added with `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` directly in that function.

### Auth model
JWT-based (`backend/src/utils/auth.js`), one token per session, 7-day expiry. Three sign-in paths converge on the same user table and `signToken()` in `backend/src/routes/auth.js`: password (`/register`, `/login`), Google ID token verification (`/google`, via `google-auth-library`, shared between dashboard and iOS), and Sign in with Apple (`/apple`, manual JWKS verification against Apple's public keys). All three auto-provision a `patients` row + join code when the chosen role is `patient`.

Four roles: `patient`, `caregiver`, `family`, `organization`. Role gates data visibility rather than routes:
- `patient` — owns their own record, used by the iOS app.
- `family` — linked to one or more patients via `family_patient_links`, joined using a per-patient `join_codes` code generated at patient creation.
- `caregiver` / `organization` — see patients scoped to their `organization_id` if they belong to one (`organizations` table, its own join code), otherwise see all patients (legacy/no-org fallback — see `patients.js` `GET /`).

WebSocket connections (`backend/src/utils/ws.js`) authenticate via a first `{type: 'auth', token}` message (not a header), then get tracked per-user-id in an in-memory map for `sendToUser()` push delivery.

### AI integration
A single NVIDIA-hosted model (`openai/gpt-oss-20b`) handles three distinct features in `backend/src/routes/ai.js`: the patient-facing companion chat (`/chat`, persona driven by `ai_companion_name`/`ai_companion_gender` on the patient record, with server-side chat history as source of truth over client-sent history), clinical handoff overviews for caregivers (`/overview/:patientId`), and OCR-to-structured-data parsing for the medication bottle scanner (`/parse-medication`). The model returns hidden reasoning in a separate field and sometimes leaks `<think>` tags into content — `stripThinkTags()` cleans this up. Every AI feature has a non-AI fallback path (canned chat replies, raw-text fallback parse) so a missing/failed `NVIDIA_API_KEY` degrades rather than breaks the feature.

### Medication identification pipeline
Two independent lookup paths feed the same `Pill`/medication shape, both backed by free NIH NLM APIs (no key required):
- `backend/src/services/rxnorm.js` — resolves a drug **name** (e.g. from OCR label text) to an RxNorm `rxcui`.
- `backend/src/services/rximage.js` + `ios/CareBridge/Services/PillImprintIndex.swift` — resolves a pill **imprint code** (text stamped on the pill itself) to drug identity. The iOS app does on-device OCR first (`PillDetectionService.swift`, using Vision's `VNRecognizeTextRequest`, clustering nearby text observations into distinct pills), checks a bundled local JSON index (`pill_index.json`) for instant offline results, then falls back to the live rximage API via `PillImprintIndex.lookupRemote()`.
- `backend/src/routes/medicationVerification.js` compares detected pills against a patient's prescribed medication name and logs the match/mismatch to `verification_logs` for audit.

### iOS demo mode
`APIService` (`ios/CareBridge/Services/APIService.swift`) has a global `isDemoMode` flag. When set, *every* method short-circuits to return canned `demo*` data (`demoUser`, `demoMedications`, etc.) instead of hitting the network — used for App Store review / offline demos via `AuthenticationManager.loginAsDemo(role:)`. When adding a new `APIService` method, check whether a demo-mode branch is expected to match this pattern before the real network call.

### Widget / Live Activity data flow
`ios/CareBridgeWidget/` is a separate extension target sharing data with the main app via an App Group container (`group.com.carebridge.app`, declared in both targets' `.entitlements`). The main app writes wellness data into shared `UserDefaults(suiteName:)` via `WidgetDataStore.update(...)` and calls `WidgetCenter.shared.reloadAllTimelines()`; the widget extension reads from the same suite. There's no other communication channel between the two targets.

### Deployment
Render Blueprint (`render.yaml`) defines two free-tier services — `carebridge-api` and `carebridge-dashboard` — both auto-deploying on push to `main`. The dashboard builds with `@sveltejs/adapter-node` (real server, not static/adapter-auto) because Render needs a long-running process. `.github/workflows/deploy.yml` builds both and then pings Render's deploy hooks, mainly so deploys are visible in the Actions tab and there's a place to add build/test gates. Full first-time setup (Neon Postgres, Google/Apple OAuth credentials, DNS) is documented in `DEPLOYMENT.md` — read it before changing anything auth- or deploy-related.
