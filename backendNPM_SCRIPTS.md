# 📜 NPM Scripts Reference

Quick reference for all available backend commands.

## Backend Commands

All commands should be run from the `backend/` directory:

```bash
cd backend
```

### Development

#### `npm run dev`
Start the development server with auto-reload.

```bash
npm run dev
```

- Runs on port 3000 (or PORT from .env)
- Auto-restarts on file changes
- Development logging enabled
- Creates database tables automatically on first run

**When to use:** Daily development

---

#### `npm start`
Start the production server.

```bash
npm start
```

- Runs in production mode
- No auto-reload
- Optimized logging

**When to use:** Production deployment

---

### Database Management

#### `npm run db:migrate`
Create database tables.

```bash
npm run db:migrate
```

- Creates all 10 tables
- Sets up foreign keys
- Adds constraints
- Idempotent (safe to run multiple times)

**When to use:** 
- Initial setup
- After database reset
- Schema changes (future)

---

#### `npm run db:seed`
Populate database with sample data.

```bash
npm run db:seed
```

Creates:
- 2 user accounts (patient and caregiver)
- 1 patient profile
- 3 medications
- 2 appointments
- 7 days of wellness check-ins
- 2 journal entries

**Sample accounts created:**
```
Patient:
  Email: patient@example.com
  Password: password123

Caregiver:
  Email: caregiver@example.com
  Password: password123
```

**When to use:**
- Initial setup
- Testing
- Development
- After database reset

---

#### `npm run db:setup`
One-command database setup (migrate + seed).

```bash
npm run db:setup
```

Equivalent to:
```bash
npm run db:migrate && npm run db:seed
```

**When to use:** First-time setup

---

## Installation

#### `npm install`
Install all dependencies.

```bash
npm install
```

Installs:
- express
- pg (PostgreSQL)
- bcrypt
- jsonwebtoken
- cors
- helmet
- winston
- dotenv
- ws (WebSocket)
- and more...

**When to use:**
- Initial setup
- After pulling updates
- After package.json changes

---

#### `npm ci`
Clean install (production).

```bash
npm ci
```

- Faster than `npm install`
- Uses exact versions from package-lock.json
- Removes node_modules first

**When to use:** CI/CD pipelines, production

---

## Quick Workflows

### First Time Setup

```bash
cd backend
npm install
cp .env.example .env
# Edit .env with your database credentials
npm run db:setup
npm run dev
```

### Daily Development

```bash
cd backend
npm run dev
```

### After Database Reset

```bash
# Terminal 1: Database
dropdb carebridge
createdb carebridge

# Terminal 2: Backend
cd backend
npm run db:setup
npm run dev
```

### Fresh Start

```bash
cd backend
rm -rf node_modules
npm install
dropdb carebridge
createdb carebridge
npm run db:setup
npm run dev
```

---

## Environment Variables

Required in `backend/.env`:

```env
# Server
NODE_ENV=development
PORT=3000

# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=carebridge
DB_USER=postgres
DB_PASSWORD=your_password

# JWT
JWT_SECRET=your-secret-key
JWT_EXPIRES_IN=7d

# CORS
CORS_ORIGIN=http://localhost:5173

# Optional: AI
OPENAI_API_KEY=your-key
```

---

## Available Scripts Summary

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `npm run dev` | Development server with auto-reload | Daily development |
| `npm start` | Production server | Production deployment |
| `npm install` | Install dependencies | Setup, after updates |
| `npm run db:migrate` | Create tables | Initial setup, schema changes |
| `npm run db:seed` | Add sample data | Testing, development |
| `npm run db:setup` | Migrate + seed | First-time setup |

---

## Dependencies

### Production Dependencies

- **express** - Web framework
- **pg** - PostgreSQL client
- **bcrypt** - Password hashing
- **jsonwebtoken** - JWT auth
- **cors** - Cross-origin support
- **helmet** - Security headers
- **dotenv** - Environment variables
- **winston** - Logging
- **multer** - File uploads
- **express-validator** - Input validation
- **ws** - WebSocket support

### Development Dependencies

- **nodemon** - Auto-reload on file changes

---

## Port Configuration

Default port: **3000**

Change in `.env`:
```env
PORT=3001
```

Or override on command line:
```bash
PORT=3001 npm run dev
```

---

## Logging

Logs are written to console using Winston.

Log levels:
- **error** - Errors only
- **warn** - Warnings and errors
- **info** - General information (default)
- **debug** - Detailed debugging

Set in `.env`:
```env
LOG_LEVEL=debug
```

---

## Testing the API

### Health Check
```bash
curl http://localhost:3000/health
```

### Register User
```bash
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123",
    "role": "patient",
    "firstName": "Test",
    "lastName": "User"
  }'
```

### Login
```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'
```

Save the token and use it:
```bash
TOKEN="your-token-here"

curl http://localhost:3000/api/patients \
  -H "Authorization: Bearer $TOKEN"
```

---

## Common Issues

### Port already in use
```bash
lsof -ti:3000 | xargs kill -9
```

### Database connection error
```bash
# Check PostgreSQL is running
brew services list | grep postgresql

# Start if needed
brew services start postgresql@14
```

### Module not found
```bash
rm -rf node_modules
npm install
```

---

## Advanced Usage

### Run with different environment
```bash
NODE_ENV=production npm start
```

### Custom database
```bash
DB_NAME=carebridge_test npm run dev
```

### Debug mode
```bash
LOG_LEVEL=debug npm run dev
```

---

This reference covers all NPM commands for the CareBridge backend! 📜
