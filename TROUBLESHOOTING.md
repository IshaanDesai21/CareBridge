# 🔧 Troubleshooting Guide

Common issues and their solutions when running CareBridge.

## Backend Issues

### ❌ "Cannot connect to database"

**Symptoms:**
```
Error: connect ECONNREFUSED 127.0.0.1:5432
```

**Solutions:**

1. **Check if PostgreSQL is running:**
   ```bash
   # macOS (Homebrew)
   brew services list | grep postgresql
   
   # Start if not running
   brew services start postgresql@14
   ```

2. **Verify database exists:**
   ```bash
   psql -l | grep carebridge
   
   # Create if missing
   createdb carebridge
   ```

3. **Check credentials in .env:**
   ```bash
   cd backend
   cat .env
   
   # Make sure DB_USER and DB_PASSWORD are correct
   ```

4. **Test connection manually:**
   ```bash
   psql -h localhost -U postgres carebridge
   # If this fails, check your PostgreSQL installation
   ```

---

### ❌ "Port 3000 already in use"

**Symptoms:**
```
Error: listen EADDRINUSE: address already in use :::3000
```

**Solutions:**

1. **Find and kill the process:**
   ```bash
   # macOS/Linux
   lsof -ti:3000 | xargs kill -9
   
   # Or change the port in backend/.env
   PORT=3001
   ```

2. **Check what's using the port:**
   ```bash
   lsof -i :3000
   ```

---

### ❌ "Module not found" errors

**Symptoms:**
```
Error: Cannot find module 'express'
```

**Solutions:**

1. **Install dependencies:**
   ```bash
   cd backend
   rm -rf node_modules
   npm install
   ```

2. **Check Node.js version:**
   ```bash
   node --version
   # Should be 18+
   ```

---

### ❌ Database tables not created

**Symptoms:**
```
Error: relation "users" does not exist
```

**Solutions:**

1. **The tables should auto-create on first run. Try:**
   ```bash
   cd backend
   npm run db:migrate
   ```

2. **Or manually recreate the database:**
   ```bash
   dropdb carebridge
   createdb carebridge
   npm run dev
   # Tables will be created automatically
   ```

---

## iOS App Issues

### ❌ "Cannot connect to server" in simulator

**Symptoms:**
- Login fails
- "Network error" messages
- Empty data screens

**Solutions:**

1. **Verify backend is running:**
   ```bash
   curl http://localhost:3000/health
   # Should return: {"status":"ok",...}
   ```

2. **Check API URL in code:**
   Open `iOS/CareBridge/Services/APIService.swift`
   ```swift
   private let baseURL = "http://localhost:3000/api"
   ```

3. **Simulator network issues:**
   - Restart the simulator
   - Reset network settings: Hardware → Erase All Content and Settings
   - Try a different simulator (iPhone 15 Pro recommended)

---

### ❌ Build errors in Xcode

**Symptoms:**
- "Command PhaseScriptExecution failed"
- "Module not found"
- Various build failures

**Solutions:**

1. **Clean build:**
   ```
   Cmd + Shift + K  (Clean Build Folder)
   Cmd + R          (Build and Run)
   ```

2. **Derived Data issues:**
   - Xcode → Preferences → Locations
   - Click arrow next to Derived Data path
   - Delete the folder for CareBridge
   - Rebuild

3. **Check deployment target:**
   - Click on project in navigator
   - Check "iOS Deployment Target" is 17.0 or later

---

### ❌ "Cannot find 'MainTabView' in scope"

**Symptoms:**
Compiler errors about missing views or types

**Solutions:**

1. **Files not in target:**
   - Select the file in Project Navigator
   - Check "Target Membership" in File Inspector (right panel)
   - Ensure "CareBridge" is checked

2. **Restart Xcode:**
   - Sometimes Xcode needs a restart to index properly
   - Quit and reopen

---

### ❌ Physical device testing issues

**Symptoms:**
- "Cannot connect to localhost"
- Network timeouts

**Solutions:**

1. **Update API URL to use Mac's IP:**
   
   Find your Mac's IP:
   ```bash
   ifconfig | grep "inet " | grep -v 127.0.0.1
   # Look for something like: inet 192.168.1.100
   ```

   Update `APIService.swift`:
   ```swift
   private let baseURL = "http://192.168.1.100:3000/api"
   ```

2. **Ensure iPhone and Mac are on same WiFi network**

3. **Check firewall settings:**
   - System Preferences → Security & Privacy → Firewall
   - Allow Node.js to accept incoming connections

---

## Database Issues

### ❌ Authentication fails after database recreation

**Symptoms:**
- Login works once, then fails
- "Invalid credentials" for valid accounts

**Solution:**

Users were deleted when database was recreated. Either:

1. **Register a new account** in the app
2. **Or seed the database:**
   ```bash
   cd backend
   npm run db:seed
   # Then use: patient@example.com / password123
   ```

---

### ❌ "Too many connections" to PostgreSQL

**Symptoms:**
```
Error: sorry, too many clients already
```

**Solutions:**

1. **Close unnecessary connections:**
   ```bash
   psql carebridge
   SELECT pg_terminate_backend(pid) 
   FROM pg_stat_activity 
   WHERE datname = 'carebridge' 
   AND pid <> pg_backend_pid();
   ```

2. **Increase max connections (if needed):**
   Edit PostgreSQL config file

---

## Common Development Issues

### ❌ Token expired

**Symptoms:**
- Suddenly logged out
- "Invalid or expired token" errors

**Solution:**

JWT tokens expire after 7 days. Just log in again.

To extend token life, edit `backend/.env`:
```
JWT_EXPIRES_IN=30d
```

---

### ❌ CORS errors in browser (if testing API directly)

**Symptoms:**
```
Access to fetch blocked by CORS policy
```

**Solution:**

Update `backend/.env`:
```
CORS_ORIGIN=http://localhost:3000,http://localhost:5173
```

Or in `backend/src/server.js`, update CORS config.

---

### ❌ Seed data not appearing in iOS app

**Symptoms:**
- Ran `npm run db:seed`
- But no data shows in app

**Solution:**

The seeded patient has `id: 1`, but the app might be using a different patient ID.

Option 1: **Log in as seeded patient:**
```
Email: patient@example.com
Password: password123
```

Option 2: **Update hardcoded patient ID in iOS code**
(Search for `patientId = 1` and update as needed)

---

## Performance Issues

### ❌ App is slow or laggy

**Solutions:**

1. **Backend logging:**
   - Reduce log level in production
   - Edit `backend/src/utils/logger.js`

2. **Database indexes:**
   - Already included in schema for common queries
   - Monitor slow queries with PostgreSQL logs

3. **iOS performance:**
   - Test on Release build, not Debug
   - Product → Scheme → Edit Scheme → Run → Build Configuration → Release

---

## Security Warnings

### ⚠️ "NSAppTransportSecurity" warning

This is expected for local development. The Info.plist allows localhost connections.

For production, remove this and use HTTPS only.

---

### ⚠️ JWT_SECRET in .env

**Warning:** Change `JWT_SECRET` before deploying to production!

Generate a secure random secret:
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

---

## Testing Issues

### ❌ Cannot create test accounts

**Solutions:**

1. **Email already exists:**
   - Use a different email
   - Or reset the database

2. **Password too short:**
   - Minimum 6 characters required

3. **Form validation fails:**
   - Check all required fields are filled
   - Passwords must match

---

## Data Issues

### ❌ Wellness score not updating

**Symptoms:**
- Completed check-in
- Score still shows old value

**Solutions:**

1. **Check backend logs:**
   - Look for calculation errors
   - Verify UPDATE query ran

2. **Refresh the app:**
   - Pull down to refresh on Home screen
   - Or restart the app

3. **Check database:**
   ```sql
   SELECT wellness_score FROM patients WHERE id = 1;
   ```

---

### ❌ Check-in submitted but not showing in history

**Solutions:**

1. **Check API response:**
   - Look at Xcode console for errors
   - Verify 201 Created response

2. **Check database:**
   ```sql
   SELECT * FROM wellness_checkins 
   ORDER BY created_at DESC 
   LIMIT 5;
   ```

3. **Patient ID mismatch:**
   - Verify you're querying the correct patient ID

---

## Environment Issues

### ❌ "command not found: createdb"

**Solution:**

PostgreSQL command-line tools not in PATH.

```bash
# macOS with Homebrew
echo 'export PATH="/usr/local/opt/postgresql@14/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Or use absolute path
/usr/local/opt/postgresql@14/bin/createdb carebridge
```

---

### ❌ "command not found: npm"

**Solution:**

Node.js not installed or not in PATH.

1. Download from https://nodejs.org
2. Or install with Homebrew:
   ```bash
   brew install node
   ```

---

### ❌ Xcode not found

**Solution:**

```bash
# Install Xcode Command Line Tools
xcode-select --install

# Install full Xcode from Mac App Store
```

---

## Getting More Help

### Enable Debug Logging

**Backend:**
Edit `backend/.env`:
```
LOG_LEVEL=debug
```

**iOS:**
Add print statements in `APIService.swift`:
```swift
print("API Request: \(request)")
print("API Response: \(String(data: data, encoding: .utf8) ?? "")")
```

### Check System Status

```bash
# Node.js version
node --version

# npm version
npm --version

# PostgreSQL version
psql --version

# Database status
brew services list | grep postgresql

# Port availability
lsof -i :3000

# Backend health
curl http://localhost:3000/health
```

### Database Inspection

```bash
# Connect to database
psql carebridge

# List all tables
\dt

# Check users
SELECT id, email, role FROM users;

# Check patients
SELECT id, user_id, wellness_score FROM patients;

# Check recent check-ins
SELECT patient_id, date, energy, mood 
FROM wellness_checkins 
ORDER BY date DESC 
LIMIT 5;

# Exit psql
\q
```

### Reset Everything

If all else fails, complete reset:

```bash
# Stop backend (Ctrl+C)

# Reset database
dropdb carebridge
createdb carebridge

# Reset backend
cd backend
rm -rf node_modules
npm install

# Start backend
npm run dev

# Seed data (optional)
npm run db:seed

# iOS app: Delete app from simulator
# Then rebuild in Xcode (Cmd+R)
```

---

## Still Having Issues?

1. Check the logs carefully - they usually contain the answer
2. Review the relevant README files
3. Compare your code with the original files
4. Try the "Reset Everything" steps above
5. Check that all prerequisites are properly installed

---

**Most issues are related to:**
1. Backend not running (check with `curl http://localhost:3000/health`)
2. Database not created (run `createdb carebridge`)
3. Dependencies not installed (run `npm install`)
4. Wrong API URL in iOS app (check `APIService.swift`)
5. Stale build in Xcode (clean with Cmd+Shift+K)

Happy debugging! 🐛
