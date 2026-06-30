# 🎨 CareBridge Visual Guide

## Application Flow

### User Journey: First Time User

```
┌─────────────────┐
│   App Launch    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Login Screen  │◄──────┐
└────────┬────────┘       │
         │                │
         │ Tap "Sign Up"  │
         ▼                │
┌─────────────────┐       │
│ Registration    │       │
│     Form        │       │
└────────┬────────┘       │
         │                │
         │ Create Account │
         ▼                │
┌─────────────────┐       │
│  Home Dashboard │       │
│  (Logged In)    │       │
└────────┬────────┘       │
         │                │
         │ Complete       │
         │ Check-in       │
         ▼                │
┌─────────────────┐       │
│ Wellness Check  │       │
│  (3 Pages)      │       │
└────────┬────────┘       │
         │                │
         │ Submit         │
         ▼                │
┌─────────────────┐       │
│   Wellness      │       │
│   Updated       │       │
└────────┬────────┘       │
         │                │
         │ Continue       │
         │ Exploring      │
         ▼                │
┌─────────────────┐       │
│  Tab Bar Nav    │       │
│ Home|Wellness   │       │
│ Meds|Journal    │       │
│    Profile      │       │
└─────────────────┘       │
         │                │
         │ Logout         │
         └────────────────┘
```

## Screen Hierarchy

```
CareBridge App
│
├── 🔐 Authentication (Not Logged In)
│   ├── Login View
│   └── Registration View
│
└── 🏠 Main App (Logged In)
    │
    ├── Tab 1: Home
    │   ├── Welcome Header
    │   ├── Wellness Score Card
    │   ├── Check-in Status
    │   ├── Quick Actions
    │   └── Upcoming Appointments
    │
    ├── Tab 2: Wellness
    │   ├── Daily Check-in Button
    │   ├── Wellness History
    │   └── → Wellness Check-in Flow
    │       ├── Page 1: Energy & Pain
    │       ├── Page 2: Physical Function
    │       └── Page 3: Nutrition & Notes
    │
    ├── Tab 3: Medications
    │   ├── Medications List
    │   └── Add Medication (+)
    │
    ├── Tab 4: Journal
    │   ├── Journal Entries List
    │   └── → New Entry Form
    │       ├── Title
    │       ├── Content
    │       └── Mood Picker
    │
    └── Tab 5: Profile
        ├── User Info
        ├── Health Information
        ├── Settings
        └── Sign Out
```

## API Endpoint Map

```
Backend API (http://localhost:3000/api)
│
├── /auth
│   ├── POST /register     → Create new account
│   ├── POST /login        → Get JWT token
│   └── GET  /me           → Get current user
│
├── /patients
│   ├── GET  /             → List all patients
│   ├── GET  /:id          → Get patient profile
│   └── PUT  /:id          → Update patient
│
├── /wellness
│   ├── POST /             → Submit check-in
│   ├── GET  /:patientId   → Get history
│   └── GET  /:id/today    → Today's check-in
│
├── /medications
│   ├── GET  /:patientId   → List medications
│   ├── POST /             → Add medication
│   ├── PUT  /:id          → Update medication
│   └── POST /:id/log      → Log dose taken
│
├── /appointments
│   ├── GET    /:patientId → List appointments
│   ├── POST   /           → Create appointment
│   ├── PUT    /:id        → Update appointment
│   └── DELETE /:id        → Cancel appointment
│
├── /journal
│   ├── GET    /:patientId → List entries
│   ├── POST   /           → Create entry
│   ├── PUT    /:id        → Update entry
│   └── DELETE /:id        → Delete entry
│
├── /care-notes
│   ├── GET  /:patientId   → List notes
│   ├── POST /             → Create note
│   └── PUT  /:id          → Update note
│
└── /ai
    ├── POST /chat         → Chat with AI
    ├── GET  /insights/:id → Get AI insights
    └── GET  /summary/:id  → Wellness summary
```

## Database Schema

```
┌──────────────┐
│    users     │
├──────────────┤
│ id (PK)      │
│ email        │◄────┐
│ password_hash│     │
│ role         │     │
│ first_name   │     │
│ last_name    │     │
│ created_at   │     │
└──────────────┘     │
                     │
                     │
┌──────────────┐     │
│   patients   │     │
├──────────────┤     │
│ id (PK)      │     │
│ user_id (FK) │─────┘
│ date_of_birth│
│ phone        │
│ emergency_*  │
│ wellness_score│◄────────────┐
└──────┬───────┘              │
       │                      │
       │ One-to-Many          │
       │                      │
       ├────────────────────────────┐
       │                            │
       ▼                            ▼
┌──────────────┐          ┌──────────────┐
│wellness_     │          │ medications  │
│checkins      │          ├──────────────┤
├──────────────┤          │ id (PK)      │
│ id (PK)      │          │ patient_id   │
│ patient_id   │          │ name         │
│ date         │          │ dosage       │
│ energy       │          │ frequency    │
│ fatigue      │          │ is_active    │
│ pain         │          └──────┬───────┘
│ mood         │                 │
│ sleep_quality│                 │
│ ...          │                 ▼
└──────────────┘          ┌──────────────┐
       │                  │medication_   │
       │                  │logs          │
       │                  ├──────────────┤
       ▼                  │ id (PK)      │
┌──────────────┐          │ medication_id│
│appointments  │          │ taken_time   │
├──────────────┤          │ status       │
│ id (PK)      │          └──────────────┘
│ patient_id   │
│ title        │          ┌──────────────┐
│ type         │          │journal_      │
│ provider_name│          │entries       │
│ appt_date    │          ├──────────────┤
└──────────────┘          │ id (PK)      │
       │                  │ patient_id   │
       │                  │ title        │
       ▼                  │ content      │
┌──────────────┐          │ mood         │
│ care_notes   │          │ is_shared    │
├──────────────┤          └──────────────┘
│ id (PK)      │
│ patient_id   │          ┌──────────────┐
│ caregiver_id │          │ care_tasks   │
│ note_type    │          ├──────────────┤
│ content      │          │ id (PK)      │
└──────────────┘          │ patient_id   │
       │                  │ title        │
       │                  │ status       │
       ▼                  │ scheduled_time│
┌──────────────┐          └──────────────┘
│ documents    │
├──────────────┤          ┌──────────────┐
│ id (PK)      │          │ ai_insights  │
│ patient_id   │          ├──────────────┤
│ file_name    │          │ id (PK)      │
│ file_url     │          │ patient_id   │
│ category     │          │ insight_type │
└──────────────┘          │ title        │
                          │ severity     │
                          └──────────────┘
```

## Color Scheme

### Wellness Metrics
```
🟢 Green (80-100)  → Excellent/Good
🟠 Orange (60-79)  → Fair/Moderate  
🔴 Red (0-59)      → Poor/Concerning
```

### UI Elements
```
🔵 Blue     → Primary actions, headers
🟣 Purple   → AI features, special features
🟢 Green    → Success, positive metrics
🟠 Orange   → Warnings, pending items
🔴 Red      → Errors, critical alerts
⚫ Gray     → Secondary, disabled items
```

### Feature Icons
```
❤️  Wellness & Health
💊 Medications
📅 Appointments
📔 Journal
👤 Profile
🤖 AI Companion
📊 Analytics
🔔 Notifications
```

## Data Flow Example: Daily Check-in

```
┌─────────────────────────────────────────────────┐
│             iOS App (User)                      │
│  User fills out wellness check-in form          │
│  - Energy: 7                                    │
│  - Fatigue: 3                                   │
│  - Pain: 2                                      │
│  - ... (12 metrics total)                       │
└────────────────┬────────────────────────────────┘
                 │
                 │ HTTP POST /api/wellness
                 │ { patientId: 1, energy: 7, ... }
                 │ Authorization: Bearer <JWT>
                 ▼
┌─────────────────────────────────────────────────┐
│         Backend API (Node.js)                   │
│  1. Verify JWT token                            │
│  2. Validate data (1-10 range)                  │
│  3. Insert into wellness_checkins table         │
│  4. Calculate wellness score                    │
│     avg = (energy + (11-fatigue) + ...) / 12    │
│     score = avg * 10                            │
│  5. Update patients.wellness_score              │
│  6. Return { checkin, wellnessScore }           │
└────────────────┬────────────────────────────────┘
                 │
                 │ PostgreSQL Queries:
                 │ INSERT INTO wellness_checkins...
                 │ UPDATE patients SET wellness_score...
                 ▼
┌─────────────────────────────────────────────────┐
│         PostgreSQL Database                     │
│  - New row in wellness_checkins                 │
│  - Updated wellness_score in patients           │
│  - Timestamps recorded                          │
└────────────────┬────────────────────────────────┘
                 │
                 │ Response: 201 Created
                 │ { checkin: {...}, wellnessScore: 75 }
                 ▼
┌─────────────────────────────────────────────────┐
│             iOS App (Update UI)                 │
│  - Show success message                         │
│  - Update wellness score display                │
│  - Mark check-in as complete                    │
│  - Navigate back to home                        │
└─────────────────────────────────────────────────┘
```

## Authentication Flow

```
┌──────────────┐
│ User enters  │
│ credentials  │
└──────┬───────┘
       │
       │ POST /api/auth/login
       │ { email, password }
       ▼
┌──────────────┐
│   Backend    │
│ 1. Find user │
│ 2. Compare   │
│    password  │
│    with bcrypt│
│ 3. Generate  │
│    JWT token │
└──────┬───────┘
       │
       │ { user: {...}, token: "eyJ..." }
       ▼
┌──────────────┐
│  iOS App     │
│ 1. Save token│
│ 2. Save user │
│ 3. Navigate  │
│    to home   │
└──────┬───────┘
       │
       │ Future requests include:
       │ Authorization: Bearer eyJ...
       ▼
┌──────────────┐
│   Backend    │
│ Middleware   │
│ verifies JWT │
│ before each  │
│ request      │
└──────────────┘
```

## Wellness Score Calculation

```
Input: 12 metrics (1-10 scale each)
├── Energy (higher is better)
├── Fatigue (lower is better) → inverted
├── Pain (lower is better) → inverted
├── Mood (higher is better)
├── Sleep Quality (higher is better)
├── Breathing (higher is better)
├── Mobility (higher is better)
├── Balance (higher is better)
├── Speech Clarity (higher is better)
├── Appetite (higher is better)
├── Hydration (higher is better)
└── Swallowing Difficulty (lower is better) → inverted

Formula:
  score = (
    energy + 
    (11 - fatigue) + 
    (11 - pain) + 
    mood + 
    sleep_quality + 
    breathing + 
    mobility + 
    balance + 
    speech_clarity + 
    appetite + 
    hydration + 
    (11 - swallowing_difficulty)
  ) / 12 * 10

Output: Wellness Score (0-100)
├── 80-100: 🟢 Excellent
├── 60-79:  🟠 Good
└── 0-59:   🔴 Needs Attention
```

## File Organization Pattern

```
Backend:
routes/        → API endpoint handlers
services/      → Business logic (to be added)
models/        → Data models (to be added)
utils/         → Helper functions
database/      → DB connection and migrations

iOS:
Views/         → SwiftUI views
Managers/      → State management
Services/      → API communication
Models/        → Data structures
Components/    → Reusable UI elements
```

This visual guide helps understand how everything connects! 🎨
