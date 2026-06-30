# Database Schema

## Overview
CareBridge uses PostgreSQL as the primary relational database with Prisma ORM for type-safe database access.

## Entity Relationship Diagram

```
┌─────────────┐       ┌─────────────┐       ┌─────────────┐
│    User     │───────│   Patient   │───────│  Caregiver  │
└─────────────┘       └─────────────┘       └─────────────┘
      │                      │                      │
      │                      │                      │
      ▼                      ▼                      ▼
┌─────────────┐       ┌─────────────┐       ┌─────────────┐
│Organization │       │   Record    │       │   Message   │
└─────────────┘       └─────────────┘       └─────────────┘
```

## Core Tables

### users
Primary authentication and user table.

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(50),
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL, -- 'patient', 'caregiver', 'admin'
    avatar_url TEXT,
    bio TEXT,
    preferences JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    last_login TIMESTAMP,
    is_verified BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);
```

### patients
Patient profiles and information.

```sql
CREATE TABLE patients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    date_of_birth DATE,
    gender VARCHAR(50),
    address TEXT,
    emergency_contact JSONB,
    medical_history JSONB,
    medications JSONB,
    allergies JSONB,
    primary_diagnosis TEXT,
    care_level VARCHAR(50),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_patients_user_id ON patients(user_id);
```

### caregivers
Caregiver profiles and credentials.

```sql
CREATE TABLE caregivers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    organization_id UUID REFERENCES organizations(id),
    license_number VARCHAR(100),
    certifications JSONB,
    specializations TEXT[],
    experience_years INTEGER,
    availability JSONB,
    rate_per_hour DECIMAL(10, 2),
    rating DECIMAL(3, 2),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_caregivers_user_id ON caregivers(user_id);
CREATE INDEX idx_caregivers_org_id ON caregivers(organization_id);
```

### organizations
Care organizations and agencies.

```sql
CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    type VARCHAR(50), -- 'agency', 'hospital', 'clinic'
    address TEXT,
    phone VARCHAR(50),
    email VARCHAR(255),
    website TEXT,
    license_number VARCHAR(100),
    settings JSONB DEFAULT '{}',
    subscription_tier VARCHAR(50),
    subscription_expires_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_organizations_name ON organizations(name);
```

### care_relationships
Connections between patients and caregivers.

```sql
CREATE TABLE care_relationships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID REFERENCES patients(id) ON DELETE CASCADE,
    caregiver_id UUID REFERENCES caregivers(id) ON DELETE CASCADE,
    relationship_type VARCHAR(50), -- 'family', 'professional', 'friend'
    role VARCHAR(100), -- 'primary', 'secondary', 'emergency'
    permissions JSONB, -- What they can view/edit
    status VARCHAR(50) DEFAULT 'active', -- 'active', 'inactive', 'pending'
    started_at TIMESTAMP DEFAULT NOW(),
    ended_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_care_rel_patient ON care_relationships(patient_id);
CREATE INDEX idx_care_rel_caregiver ON care_relationships(caregiver_id);
CREATE UNIQUE INDEX idx_care_rel_unique ON care_relationships(patient_id, caregiver_id) 
    WHERE ended_at IS NULL;
```

### records
Health records, updates, and observations.

```sql
CREATE TABLE records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID REFERENCES patients(id) ON DELETE CASCADE,
    created_by_id UUID REFERENCES users(id),
    type VARCHAR(50) NOT NULL, -- 'voice', 'text', 'vital', 'medication', 'observation'
    title VARCHAR(255),
    content TEXT,
    audio_url TEXT,
    transcription TEXT,
    metadata JSONB, -- Vitals, tags, location, etc.
    ai_analysis JSONB, -- AI-generated insights
    sentiment_score DECIMAL(3, 2),
    is_flagged BOOLEAN DEFAULT FALSE,
    flag_reason TEXT,
    recorded_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_records_patient_id ON records(patient_id);
CREATE INDEX idx_records_type ON records(type);
CREATE INDEX idx_records_created_by ON records(created_by_id);
CREATE INDEX idx_records_recorded_at ON records(recorded_at DESC);
```

### medications
Medication tracking and reminders.

```sql
CREATE TABLE medications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID REFERENCES patients(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    dosage VARCHAR(100),
    frequency VARCHAR(100),
    instructions TEXT,
    prescribing_doctor VARCHAR(255),
    start_date DATE,
    end_date DATE,
    reminder_times TIME[],
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_medications_patient_id ON medications(patient_id);
CREATE INDEX idx_medications_active ON medications(is_active);
```

### medication_logs
Medication administration tracking.

```sql
CREATE TABLE medication_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    medication_id UUID REFERENCES medications(id) ON DELETE CASCADE,
    logged_by_id UUID REFERENCES users(id),
    scheduled_time TIMESTAMP NOT NULL,
    taken_time TIMESTAMP,
    status VARCHAR(50), -- 'taken', 'missed', 'skipped'
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_med_logs_med_id ON medication_logs(medication_id);
CREATE INDEX idx_med_logs_scheduled ON medication_logs(scheduled_time DESC);
```

### appointments
Medical appointments and scheduling.

```sql
CREATE TABLE appointments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID REFERENCES patients(id) ON DELETE CASCADE,
    caregiver_id UUID REFERENCES caregivers(id),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    location TEXT,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP NOT NULL,
    type VARCHAR(50), -- 'checkup', 'specialist', 'therapy', 'test'
    provider_name VARCHAR(255),
    status VARCHAR(50) DEFAULT 'scheduled', -- 'scheduled', 'completed', 'cancelled'
    reminder_sent BOOLEAN DEFAULT FALSE,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_appointments_patient_id ON appointments(patient_id);
CREATE INDEX idx_appointments_start_time ON appointments(start_time);
CREATE INDEX idx_appointments_status ON appointments(status);
```

### messages
In-app messaging between users.

```sql
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL,
    sender_id UUID REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    message_type VARCHAR(50) DEFAULT 'text', -- 'text', 'image', 'audio', 'system'
    media_url TEXT,
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_messages_conversation ON messages(conversation_id);
CREATE INDEX idx_messages_sender ON messages(sender_id);
CREATE INDEX idx_messages_created_at ON messages(created_at DESC);
```

### notifications
Push and in-app notifications.

```sql
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    data JSONB,
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP,
    action_url TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_is_read ON notifications(is_read);
CREATE INDEX idx_notifications_created_at ON notifications(created_at DESC);
```

### ai_conversations
AI assistant conversation history and context.

```sql
CREATE TABLE ai_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    patient_id UUID REFERENCES patients(id),
    context JSONB, -- Conversation memory
    summary TEXT,
    message_count INTEGER DEFAULT 0,
    last_message_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_ai_conv_user_id ON ai_conversations(user_id);
CREATE INDEX idx_ai_conv_patient_id ON ai_conversations(patient_id);
```

### audit_logs
Security and compliance audit trail.

```sql
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(50),
    resource_id UUID,
    changes JSONB,
    ip_address VARCHAR(50),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_audit_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_action ON audit_logs(action);
CREATE INDEX idx_audit_created_at ON audit_logs(created_at DESC);
```

## Data Relationships

### One-to-One
- `users` ↔ `patients`
- `users` ↔ `caregivers`

### One-to-Many
- `patients` → `records`
- `patients` → `medications`
- `patients` → `appointments`
- `users` → `messages`
- `organizations` → `caregivers`

### Many-to-Many
- `patients` ↔ `caregivers` (via `care_relationships`)

## Data Migration Strategy

See `backend/prisma/migrations/` for version-controlled schema changes.

## Backup and Recovery

- **Automated Backups**: Daily full backups
- **Point-in-Time Recovery**: 30-day retention
- **Backup Encryption**: AES-256
- **Recovery Time Objective (RTO)**: < 1 hour
- **Recovery Point Objective (RPO)**: < 15 minutes

## Performance Optimization

### Indexing Strategy
- Primary keys: Clustered indexes
- Foreign keys: Non-clustered indexes
- Frequently queried columns: Composite indexes
- Full-text search: GIN indexes on text columns

### Query Optimization
- Use connection pooling
- Implement query result caching (Redis)
- Optimize N+1 queries with eager loading
- Use database views for complex queries

### Partitioning
- `records`: Partition by `recorded_at` (monthly)
- `audit_logs`: Partition by `created_at` (monthly)
- Archive old data to cold storage

## Security

### Encryption
- Passwords: bcrypt with salt
- Sensitive fields: AES-256 at application level
- Connection: SSL/TLS required

### Access Control
- Row-level security policies
- Role-based permissions
- Audit logging for all data access

### Data Retention
- Active data: Unlimited
- Inactive users: 2 years
- Audit logs: 7 years (compliance)
- Soft deletes for user data
