# Deploying CareBridge to production

This covers the manual, one-time setup needed to get `carebridge.ftcblueprint.com`
live with a persistent database, working Google Sign-In, and auto-deploy on
every push to `main`. Everything on the code side is already done — this is
account/credential setup only you can do.

## 0. What changed in the code

- The backend now requires a **Postgres** database (`DATABASE_URL`) instead of
  the local SQLite file — SQLite doesn't survive restarts/redeploys on free
  hosting, so data would vanish constantly.
- Added `POST /api/auth/google` — verifies a Google ID token server-side and
  logs in / creates a user. Both the dashboard and iOS app use it.
- The dashboard now builds with `@sveltejs/adapter-node` (a real Node server)
  instead of `adapter-auto`, which can't target Render on its own.
- `render.yaml` defines both services as a Render "Blueprint".
- `.github/workflows/deploy.yml` triggers Render deploy hooks on push to `main`.

## 1. Create a free Postgres database (Neon)

1. Go to neon.tech and sign up (free tier is plenty for this app).
2. Create a project, e.g. "carebridge".
3. Copy the connection string it gives you (looks like
   `postgresql://user:pass@ep-xxxx.neon.tech/dbname?sslmode=require`).
4. Keep it handy — you'll paste it into Render as `DATABASE_URL` in step 2.

You don't need to create any tables — the backend creates/migrates them
automatically on startup (see `backend/src/database/db.js`).

## 2. Deploy the backend + dashboard on Render

1. Sign up at render.com and connect your GitHub account.
2. Click **New > Blueprint**, pick this repo. Render will read `render.yaml`
   at the root and propose two services: `carebridge-api` and
   `carebridge-dashboard`.
3. Before/after creating them, fill in the env vars marked `sync: false` in
   `render.yaml` (Render will prompt for these, or you can set them under each
   service's **Environment** tab):
   - `carebridge-api`:
     - `DATABASE_URL` → the Neon connection string from step 1
     - `GOOGLE_WEB_CLIENT_ID`, `GOOGLE_IOS_CLIENT_ID` → from step 3 below
     - `NVIDIA_API_KEY` → your existing key from `backend/.env` (don't reuse
       the dev key in a public repo — copy it directly into Render's env var
       UI, never commit it)
   - `carebridge-dashboard`:
     - `VITE_GOOGLE_CLIENT_ID` → the **web** client ID from step 3
4. Deploy. Both services get a temporary URL like
   `carebridge-api.onrender.com` / `carebridge-dashboard.onrender.com` — note
   these, you'll point DNS at them in step 4.
5. Free-tier services spin down after ~15 min of inactivity and take 30-60s to
   wake back up on the next request. That's the tradeoff of "free" — normal
   and expected, not a bug. A `.github/workflows/keep-alive.yml` workflow
   pings both services every 10 minutes to prevent this.
6. Render already auto-deploys on every push to `main` on its own
   (`autoDeploy: true` in `render.yaml`) — nothing further to configure.

## 3. Google Cloud OAuth setup (walkthrough)

1. Go to console.cloud.google.com, create a new project (e.g. "CareBridge").
2. **APIs & Services → OAuth consent screen**: choose External, fill in app
   name/support email, add your email as a test user (or publish it later).
3. **APIs & Services → Credentials → Create Credentials → OAuth client ID**:
   - **Web application** client:
     - Authorized JavaScript origins: `https://carebridge.ftcblueprint.com`
       (and `http://localhost:5173` for local dev)
     - No redirect URI needed — the dashboard uses Google Identity Services'
       token flow, not a redirect.
     - Copy the resulting **Client ID** → this is `GOOGLE_WEB_CLIENT_ID` /
       `VITE_GOOGLE_CLIENT_ID`.
   - **iOS** client:
     - Bundle ID: `com.ishaandesai.CareBridge`
     - Copy the **Client ID** → this is `GOOGLE_IOS_CLIENT_ID`.
     - Google also shows a "reversed client ID" (starts with
       `com.googleusercontent.apps.…`) — you need that for step 5.
4. Put `GOOGLE_WEB_CLIENT_ID` and `GOOGLE_IOS_CLIENT_ID` into the Render
   backend env vars (step 2), and `VITE_GOOGLE_CLIENT_ID` (the web client ID)
   into the Render dashboard env vars.

## 4. Point carebridge.ftcblueprint.com at Render

In Render, open each service → **Settings → Custom Domains**:
- `carebridge-dashboard` → add `carebridge.ftcblueprint.com`
- `carebridge-api` → add `api.carebridge.ftcblueprint.com`

Render will show you the exact CNAME target for each (usually
`<service>.onrender.com`). In your DNS provider for `ftcblueprint.com`, add:

| Type  | Name                        | Value                              |
|-------|-----------------------------|-------------------------------------|
| CNAME | carebridge                  | carebridge-dashboard.onrender.com  |
| CNAME | api.carebridge              | carebridge-api.onrender.com        |

DNS can take a few minutes to an hour to propagate. Render auto-issues a free
TLS cert once it verifies the CNAME.

## 5. Finish the iOS app

The Swift code assumes the `GoogleSignIn` SDK is already added — add it via
Xcode (raw project-file edits for SPM packages are too easy to corrupt):

1. Open `ios/CareBridge.xcodeproj` in Xcode.
2. **File → Add Package Dependencies…** → paste
   `https://github.com/google/GoogleSignIn-iOS` → Add Package → add
   `GoogleSignIn` to the CareBridge target.
3. In `ios/CareBridge/Info.plist`, replace the two placeholders with your real
   values from step 3:
   - `GIDClientID` → your iOS client ID
   - `CFBundleURLSchemes` entry → the reversed client ID
4. `APIService.defaultServerURL` now defaults to
   `https://api.carebridge.ftcblueprint.com` — update it if you used a
   different subdomain.
5. Build and run — the "Sign in with Google" button on the login screen will
   now work.

## 6. Verify

- Push to `main` → GitHub Actions should show the workflow running, and
  Render should show a new deploy.
- Visit `https://carebridge.ftcblueprint.com`, register a real account, sign
  out, sign back in — data should persist (it's in Neon now, not a local
  file).
- Try "Sign in with Google" on both the dashboard and the iOS app.
