# 🚀 Quick Start Guide

Get CareBridge running in 5 minutes!

## Prerequisites Check

Before starting, make sure you have:

- ✅ **macOS** (for iOS development)
- ✅ **Node.js 18+** ([Download](https://nodejs.org))
- ✅ **PostgreSQL 14+** ([Download](https://www.postgresql.org))
- ✅ **Xcode 15+** ([Mac App Store](https://apps.apple.com/app/xcode/id497799835))

## Step 1: Clone and Setup

```bash
# Run the setup script
chmod +x setup.sh
./setup.sh
```

Or manually:

```bash
# Setup backend
cd backend
npm install
cp .env.example .env

# Create database
createdb carebridge
```

## Step 2: Configure Database

Edit `backend/.env`:

```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=carebridge
DB_USER=postgres
DB_PASSWORD=your_password_here
```

## Step 3: Start Backend

```bash
cd backend
npm run dev
```

You should see:
```
🚀 CareBridge API running on port 3000
Environment: development
Database connected successfully
```

## Step 4: Open iOS App

In a new terminal:

```bash
cd iOS
open CareBridge.xcodeproj
```

## Step 5: Run in Simulator

In Xcode:
1. Select **iPhone 15 Pro** from the device menu
2. Press **Cmd + R** (or click the Play button)
3. Wait for the app to build and launch

## Step 6: Create Account

In the simulator:
1. Tap **"Don't have an account? Sign Up"**
2. Fill in your details:
   - First Name: Test
   - Last Name: User
   - Email: test@example.com
   - Password: password123
3. Tap **"Create Account"**

## Step 7: Explore!

You're now logged in! Try:

- ✨ Complete a **daily wellness check-in**
- 📊 View your **wellness score**
- 📔 Create a **journal entry**
- 👤 Explore your **profile**

## Common Issues

### "Cannot connect to server"

Make sure the backend is running at http://localhost:3000

```bash
# Check if backend is running
curl http://localhost:3000/health
```

Expected response:
```json
{"status":"ok","timestamp":"...","version":"1.0.0"}
```

### "Database connection error"

1. Make sure PostgreSQL is running:
   ```bash
   psql -l
   ```

2. Verify database exists:
   ```bash
   psql -l | grep carebridge
   ```

3. Check credentials in `backend/.env`

### "Build failed" in Xcode

1. Clean build folder: **Cmd + Shift + K**
2. Rebuild: **Cmd + R**

### Testing on Physical Device

If you want to test on your iPhone:

1. Update `baseURL` in `iOS/CareBridge/Services/APIService.swift`:
   ```swift
   private let baseURL = "http://YOUR_MAC_IP:3000/api"
   ```

2. Find your Mac's IP:
   ```bash
   ifconfig | grep "inet " | grep -v 127.0.0.1
   ```

## API Testing

Test the API directly:

```bash
# Health check
curl http://localhost:3000/health

# Register user
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "api@example.com",
    "password": "password123",
    "role": "patient",
    "firstName": "API",
    "lastName": "Test"
  }'

# Login
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "api@example.com",
    "password": "password123"
  }'
```

## Next Steps

- 📖 Read the full [README.md](README.md)
- 🔍 Explore the [Product Specification](ProductSpecification.md)
- 💻 Check out the [Backend API docs](backend/README.md)
- 📱 Learn about the [iOS app](iOS/README.md)

## Need Help?

- Check the main [README.md](README.md) for detailed documentation
- Review the [Product Specification](ProductSpecification.md) for feature details
- Inspect the code - it's well-commented!

---

**Happy building! 🎉**
