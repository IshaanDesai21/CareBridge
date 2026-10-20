# Plan C — Family Messages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A private, live, text-only group conversation per patient between the patient and all linked family members, with a Messages tab and unread badge on the patient and family sides. Caregivers and organizations can't read it through any API.

**Architecture:** Two new tables, one router guarded by a strict patient-or-family access check, and a WebSocket push via the existing `sendToUser()`. On iOS, a `MessagesStore` (ObservableObject) holds conversations and unread counts and is fed by `LiveNotificationsManager`.

**Tech Stack:** Express + pg wrapper + vitest + `ws`; SwiftUI iOS 17.

**Spec:** `docs/superpowers/specs/2026-10-19-pill-check-calendar-messages-design.md` (§ Messages).

**Depends on:** Plan A Task 1 (test helpers). Independent of Plan B, except that both edit the tab wiring in `TabView.swift`.

## Global Constraints

- Participants = the patient (`patients.user_id`) + every `family_patient_links.family_user_id` for that patient. **Everyone else gets 403**, including caregiver, organization, and family linked to a different patient.
- Text only; trim whitespace; 1–2000 characters.
- Tab orders, exactly:
  - patient: Home · Calendar · Medications · **Messages** · Profile
  - family: Overview · Calendar · **Messages** · Profile
  - No Messages tab for caregiver/organization.
- WebSocket event, exactly: `{ "type": "family_message", "patientId": <int>, "message": <Message> }`, sent to every participant except the sender.
- Every new `APIService` method has a demo branch.
- iOS verification = the build command from Plan A + a demo-mode run.

## Review Focus

1. **A family member is unlinked after messages exist.** They lose access immediately (403), and they stop receiving pushes. Test in Task 2.
2. **A caregiver who also has a patient record of their own** (role caregiver). Access is decided by the role-independent participant rule, so the caregiver role alone never grants access. Test in Task 1.
3. **A whitespace-only or 2001-character message.** Expect 400, nothing stored. Test in Task 2.
4. **The family app is open on two devices.** Both get the push, and reading on one clears the badge on the other at its next refresh (read state is per user, not per device). Covered by `sendToUser` fan-out and the Task 2 read test.
5. **Paging back past the first page** (`before`). Returns older messages in ascending order without duplicating the boundary message. Test in Task 2.

---

## File Structure

- `backend/src/database/db.js`: `family_messages`, `family_message_reads`.
- `backend/src/utils/patientAccess.js`: add `isConversationParticipant`, `conversationParticipantIds`.
- `backend/src/routes/messages.js` *(new)*, mounted at `/api/messages`.
- `backend/src/routes/family.js`: add `GET /patients`.
- `ios/CareBridge/Models/Models.swift`: `FamilyMessage`, `UnreadCount`.
- `ios/CareBridge/Services/APIService.swift`: message methods + `getLinkedPatients`.
- `ios/CareBridge/Managers/MessagesStore.swift` *(new)*.
- `ios/CareBridge/Managers/LiveNotificationsManager.swift`: route `family_message`.
- `ios/CareBridge/Views/Messages/MessagesView.swift`, `ConversationView.swift` *(new)*.
- `ios/CareBridge/Views/Main/TabView.swift`: tabs + badge.

---

### Task 1: Storage + participant check

**Files:** modify `backend/src/database/db.js`, `backend/src/utils/patientAccess.js`; Test `backend/tests/messageAccess.test.js`.

**Interfaces:**
- Produces:
  - Tables:
    - `family_messages`: `id SERIAL PK, patient_id INT FK patients CASCADE, sender_user_id INT FK users SET NULL, content TEXT NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP`, with an index on `(patient_id, id)`.
    - `family_message_reads`: `user_id INT FK users CASCADE, patient_id INT FK patients CASCADE, last_read_message_id INT NOT NULL DEFAULT 0, PRIMARY KEY (user_id, patient_id)`.
  - `isConversationParticipant(db, userId: number, patientId: number) → Promise<boolean>`: true iff `patients.user_id = userId` **or** a link row exists. Ignores role entirely.
  - `conversationParticipantIds(db, patientId) → Promise<number[]>`: patient user id + linked family user ids.

- [ ] **Step 1: Write failing tests:**
  - patient owner → true
  - linked family → true
  - family linked to another patient → false
  - caregiver user with no patient record or link → false *(RF 2)*
  - `conversationParticipantIds` returns patient + 2 family ids
- [ ] **Step 2:** `cd backend && npx vitest run tests/messageAccess.test.js`. Expected: FAIL.
- [ ] **Step 3:** Implement the DDL and both functions.
- [ ] **Step 4:** Re-run. Expected: PASS.
- [ ] **Step 5:** Commit: `feat(messages): storage and participant check`.

---

### Task 2: Messages routes + live push

**Files:** create `backend/src/routes/messages.js`; modify `backend/src/server.js` (`app.use('/api/messages', messageRoutes)`), `backend/src/routes/family.js`; Test `backend/tests/messages.test.js` (mock `../src/utils/ws.js` → `sendToUser: vi.fn()`).

**Interfaces:**
- Consumes: Task 1 functions; `sendToUser(userId, payload)` from `utils/ws.js`.
- Produces:
  - `Message` JSON: `{ id, patientId, senderUserId, senderName, senderRole, content, createdAt }`, where `senderName` = `first_name last_name` and `senderRole` comes from `users.role`.
  - `GET /api/messages/unread` → `{ unread: [{ patientId, count }] }` for each conversation the caller participates in (patient: own; family: linked). Count = messages with `id > last_read_message_id AND sender_user_id <> me`. **Declare this route before `/:patientId`.**
  - `GET /api/messages/:patientId?before=<id>&limit=<n≤100, default 50>` → `{ messages: Message[] }`. Newest page by default; with `before`, only `id < before`. Always returned ascending by id.
  - `POST /api/messages/:patientId` `{ content }` → `201 { message }`. Pushes the WS event to `conversationParticipantIds` minus the sender.
  - `POST /api/messages/:patientId/read` `{ lastReadMessageId }` → `{ ok: true }`. Upserts with `GREATEST(existing, new)`.
  - Any non-participant → `403 {error:'Access denied'}`.
  - `GET /api/family/patients` → `{ patients }`: every linked patient, same columns as `/family/patient`.

- [ ] **Step 1: Write failing tests:**
  - caregiver GET → 403
  - unlinked family (participant check false) GET → 403 *(RF 1)*
  - POST `"   "` → 400; POST 2001 chars → 400 *(RF 3)*
  - POST valid → 201, and `sendToUser` is called once for each other participant with `type:'family_message'`, never for the sender
  - GET with `before=10` → SQL params include 10; result ascending *(RF 5)*
  - read upsert params
  - unread counts exclude own messages
  - `/family/patients` returns all links
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement and mount.
- [ ] **Step 4:** `npx vitest run`. Expected: PASS.
- [ ] **Step 5:** Commit: `feat(messages): private patient-family conversation API with live push`.

---

### Task 3: iOS messages data layer

**Files:** modify `Models/Models.swift`, `Services/APIService.swift`, `Managers/LiveNotificationsManager.swift`; create `Managers/MessagesStore.swift`.

**Interfaces:**
- Produces:
  - `struct FamilyMessage: Codable, Identifiable, Hashable { id: Int; patientId: Int; senderUserId: Int?; senderName: String; senderRole: String; content: String; createdAt: String }`
  - `APIService`:
    - `getMessages(patientId:before:token:) -> [FamilyMessage]`
    - `sendMessage(patientId:content:token:) -> FamilyMessage`
    - `markMessagesRead(patientId:lastReadMessageId:token:)`
    - `getUnreadCounts(token:) -> [Int: Int]`
    - `getLinkedPatients(token:) -> [Patient]`
    - Demo: a 6-message conversation between "Dad" (patient) and two family members; send appends; unread = 2.
  - `@MainActor final class MessagesStore: ObservableObject`:
    - `static let shared`
    - `@Published var messages: [Int: [FamilyMessage]]`, `@Published var unread: [Int: Int]`
    - `var totalUnread: Int`
    - `func load(patientId:token:)`, `func loadOlder(patientId:token:)`, `func send(patientId:content:token:)`, `func markRead(patientId:token:)`, `func refreshUnread(token:)`
    - `func receive(_ message: FamilyMessage)`: appends if not already present by id; increments `unread` unless that conversation is currently open (`var openPatientId: Int?`).
  - `LiveNotificationsManager.handle`: new `case "family_message"`. Decode `message` via `JSONSerialization` → `Data` → `FamilyMessage`, then call `MessagesStore.shared.receive`. No local system notification.

- [ ] **Step 1:** Implement.
- [ ] **Step 2:** iOS build. Expected: SUCCEEDED.
- [ ] **Step 3:** Commit: `feat(ios): messages store, API client and live delivery`.

---

### Task 4: iOS Messages UI + tabs

**Files:** create `Views/Messages/MessagesView.swift`, `Views/Messages/ConversationView.swift`; modify `Views/Main/TabView.swift`.

**Interfaces:**
- Consumes: Task 3.
- Produces:
  - `MessagesView(role: String)`:
    - patient → resolves its patient id (`getMyPatient`) → `ConversationView`.
    - family → `getLinkedPatients`. One patient goes straight to the conversation; several shows a list with the patient's name and an unread count, pushing `ConversationView`.
  - `ConversationView(patientId: Int)`:
    - Bubbles: own messages right-aligned in `Color.cbPrimary`, others left-aligned with sender name above.
    - Pull or scroll to the top loads older messages.
    - Text field + send button, disabled when the trimmed text is empty.
    - On appear, sets `openPatientId` and marks read (last id); clears on disappear.
    - Header subtitle, exact: `"Only you and family can see these messages."`
  - Tabs:
    - patient: insert `MessagesView(role:"patient")` after Medications. Label `"Messages"`, image `"bubble.left.and.bubble.right.fill"`, `.badge(store.totalUnread)`.
    - family: insert after Calendar, same label, image and badge.
    - Call `MessagesStore.shared.refreshUnread` on tab-view appear.

- [ ] **Step 1:** Implement.
- [ ] **Step 2:** iOS build. Expected: SUCCEEDED.
- [ ] **Step 3:** Demo run:
  - patient: tabs read Home · Calendar · Medications · Messages · Profile with badge 2; open → badge clears; send → appears.
  - family: tabs read Overview · Calendar · Messages · Profile.
  - caregiver: no Messages tab.
- [ ] **Step 4:** Commit: `feat(ios): Messages tab for patient and family`.

---

## Self-review notes

- Spec coverage:

  | Spec item | Task |
  |---|---|
  | Group conversation | 2 |
  | Strict access | 1, 2 |
  | Live + badge | 2, 3, 4 |
  | Multi-patient family | 2, 4 |
  | Tabs | 4 |
  | Text only | 2 |
  | Demo | 3 |

- No push notifications when the app is closed (non-goal).
