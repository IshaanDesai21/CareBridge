# CareBridge API

## Quick Start

```bash
# 1. Install
npm install

# 2. Create database
createdb carebridge

# 3. Run
npm run dev
```

Server: http://localhost:3000

## Test

```bash
curl http://localhost:3000/health
```

## Endpoints

- `GET /health` - Health check
- `POST /api/auth/register` - Register
- `POST /api/auth/login` - Login  
- `GET /api/patients` - List patients
- `POST /api/wellness` - Submit check-in
- `GET /api/wellness/:id` - Get history

## Database

Edit `.env` if needed:
```
PORT=3000
DB_PASSWORD=postgres
```
