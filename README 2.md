# 🏥 CareBridge Backend API

Healthcare coordination platform backend.

## 🚀 Quick Start

### Prerequisites
- Node.js 18+
- PostgreSQL 14+

### Setup

1. **Install dependencies:**
```bash
npm install
```

2. **Create database:**
```bash
createdb carebridge
```

3. **Configure environment:**
```bash
cp .env.example .env
# Edit .env with your database credentials
```

4. **Start server:**
```bash
npm run dev
```

Server runs at `http://localhost:3000`

## 📡 API Endpoints

### Health Check
```bash
GET /health
```

### Authentication
```bash
POST /api/auth/register
POST /api/auth/login
```

### Patients
```bash
GET /api/patients
```

### Wellness
```bash
POST /api/wellness
GET /api/wellness/:patientId
```

## 🧪 Test the API

### Register:
```bash
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123",
    "firstName": "Test",
    "lastName": "User"
  }'
```

### Login:
```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'
```

## 📁 Project Structure

```
carebridge/
├── package.json
├── .env.example
├── src/
│   ├── server.js      # Main server
│   ├── db.js          # Database connection
│   └── routes/
│       ├── auth.js
│       ├── patients.js
│       └── wellness.js
```

## 🗄️ Database Tables

- **users** - User accounts
- **patients** - Patient profiles
- **wellness_checkins** - Daily check-ins

Tables are created automatically on first run.

## ⚙️ Environment Variables

Required in `.env`:

```env
NODE_ENV=development
PORT=3000
DB_HOST=localhost
DB_PORT=5432
DB_NAME=carebridge
DB_USER=postgres
DB_PASSWORD=your_password
JWT_SECRET=your-secret-key
```

## 🐛 Troubleshooting

### Database connection error
```bash
# Check PostgreSQL is running
brew services list | grep postgresql

# Start if needed
brew services start postgresql@14
```

### Port already in use
```bash
# Kill process on port 3000
lsof -ti:3000 | xargs kill -9
```

### Module not found
```bash
rm -rf node_modules
npm install
```

## 📦 Dependencies

- **express** - Web framework
- **pg** - PostgreSQL client  
- **bcrypt** - Password hashing
- **jsonwebtoken** - JWT auth
- **cors** - CORS support
- **helmet** - Security headers
- **dotenv** - Environment variables
- **winston** - Logging

## 🔐 Security

- Passwords hashed with bcrypt
- JWT token authentication
- SQL injection prevention
- CORS configured
- Security headers via Helmet

## 📝 License

ISC
