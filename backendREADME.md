# CareBridge Backend API

Healthcare coordination platform backend built with Node.js, Express, and PostgreSQL.

## Setup

### Prerequisites

- Node.js 18+ 
- PostgreSQL 14+
- npm or yarn

### Installation

1. Install dependencies:
```bash
cd backend
npm install
```

2. Create PostgreSQL database:
```bash
createdb carebridge
```

3. Configure environment:
```bash
cp .env.example .env
# Edit .env with your database credentials
```

4. Start the development server:
```bash
npm run dev
```

The API will be available at `http://localhost:3000`

## API Endpoints

### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login
- `GET /api/auth/me` - Get current user

### Patients
- `GET /api/patients` - Get all patients
- `GET /api/patients/:patientId` - Get patient profile
- `PUT /api/patients/:patientId` - Update patient profile

### Wellness
- `POST /api/wellness` - Create wellness check-in
- `GET /api/wellness/:patientId` - Get wellness history
- `GET /api/wellness/:patientId/today` - Get today's check-in

### Medications
- `GET /api/medications/:patientId` - Get medications
- `POST /api/medications` - Create medication
- `PUT /api/medications/:medicationId` - Update medication
- `POST /api/medications/:medicationId/log` - Log medication taken

### Appointments
- `GET /api/appointments/:patientId` - Get appointments
- `POST /api/appointments` - Create appointment
- `PUT /api/appointments/:appointmentId` - Update appointment
- `DELETE /api/appointments/:appointmentId` - Delete appointment

### Journal
- `GET /api/journal/:patientId` - Get journal entries
- `POST /api/journal` - Create journal entry
- `PUT /api/journal/:entryId` - Update journal entry
- `DELETE /api/journal/:entryId` - Delete journal entry

### Care Notes
- `GET /api/care-notes/:patientId` - Get care notes
- `POST /api/care-notes` - Create care note
- `PUT /api/care-notes/:noteId` - Update care note

### AI
- `GET /api/ai/insights/:patientId` - Get AI insights
- `POST /api/ai/chat` - Chat with AI companion
- `GET /api/ai/summary/:patientId` - Get wellness summary

## Testing with curl

Register a patient:
```bash
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "patient@example.com",
    "password": "password123",
    "role": "patient",
    "firstName": "John",
    "lastName": "Doe"
  }'
```

Login:
```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "patient@example.com",
    "password": "password123"
  }'
```
