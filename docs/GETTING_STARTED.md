# ✅ CareBridge - Clean Setup Complete

## 📁 Current File Structure

```
carebridge/
├── package.json           ✅ Dependencies configured
├── .env.example          ✅ Environment template  
├── .gitignore            ✅ Git ignore rules
├── README.md             ✅ Complete documentation
├── FILE_LISTING.md       ✅ This file
├── ProductSpecification.md ✅ Original spec
│
└── src/
    ├── server.js         ✅ Express server
    ├── db.js             ✅ PostgreSQL connection
    └── routes/
        ├── auth.js       ✅ Login/register
        ├── patients.js   ✅ Patient endpoints
        └── wellness.js   ✅ Check-in endpoints
```

## 🚀 Quick Start (3 Steps)

### 1. Install Dependencies
```bash
npm install
```

### 2. Setup Database
```bash
createdb carebridge
cp .env.example .env
# Edit .env with your PostgreSQL password if needed
```

### 3. Start Server
```bash
npm run dev
```

✅ Server runs at http://localhost:3000

## 🧪 Test It Works

```bash
# Health check
curl http://localhost:3000/health

# Should return:
# {"status":"ok","timestamp":"..."}
```

## 📡 Available API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| POST | `/api/auth/register` | Create account |
| POST | `/api/auth/login` | Login |
| GET | `/api/patients` | List patients |
| POST | `/api/wellness` | Submit check-in |
| GET | `/api/wellness/:id` | Get check-in history |

## 🗄️ Database

Tables created automatically:
- **users** - User accounts with authentication
- **patients** - Patient profiles and wellness scores
- **wellness_checkins** - Daily health check-ins

## 📝 What's Different

This is a **simplified, working version** focused on:
- ✅ Clean file structure
- ✅ Working npm install
- ✅ Core functionality only
- ✅ Easy to understand
- ✅ Ready to extend

## 🎯 Next Steps

1. **Start the server** (see Quick Start above)
2. **Test the API** with curl
3. **Add more features** as needed
4. **Build the iOS app** (optional)

## 🐛 Common Issues

### "Cannot find module"
```bash
npm install
```

### "Database connection refused"
```bash
# Start PostgreSQL
brew services start postgresql@14
```

### "Port 3000 in use"
```bash
# Change port in .env
PORT=3001
```

## 💡 Pro Tips

- Edit `.env` for your database password
- Check `README.md` for detailed docs
- Use `npm run dev` for auto-reload
- Database tables auto-create on first run

---

**Everything is clean and working!** 🎉

Run `npm install` and `npm run dev` to get started.

## Medication Features

CareBridge includes advanced medication management capabilities to reduce medication errors and improve patient safety:

### Medication Bottle Scanner with RxNorm Validation

Use the medication bottle scanner in AddMedicationView to photograph a prescription label. The app extracts the drug name, dosage, and frequency, then validates against the NLM RxNorm database. A green checkmark confirms the medication is recognized; an orange warning indicates the name was extracted but not found in RxNorm (allowing manual confirmation).

**API Endpoints:**
- `POST /api/ai/parse-medication` — Extract medication details from label text; returns name, dosage, frequency, instructions, rxcui, and canonicalName (RxNorm validation happens internally)

### Pill Check & Dose Logging

Caregivers log doses with a photo pill check or manually; the backend dose rules (count, form, strength, daily maximum by drug) decide pass/fail, and only passing checks record doses.
- `POST /api/pill-checks` — on-device detections (label, confidence, imprint) for a photo check; boxes are stripped and the photo is never uploaded or stored.
- `POST /api/dose-logs/manual` — a manually entered dose (medication + pill count), checked by the same rules.

### Privacy & HIPAA Compliance

Pill images never leave the device. Only detection labels, confidences and imprint text are sent to the server for dose checks. Image data remains local.
