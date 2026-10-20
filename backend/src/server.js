import 'dotenv/config';
import os from 'os';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { createServer } from 'http';
import { WebSocketServer } from 'ws';
import logger from './utils/logger.js';
import { connectDatabase, getDb } from './database/db.js';
import { seedDemoData } from './database/seed.js';
import { authenticateSocket } from './utils/ws.js';

// Routes
import authRoutes from './routes/auth.js';
import patientRoutes from './routes/patients.js';
import wellnessRoutes from './routes/wellness.js';
import medicationRoutes from './routes/medications.js';
import appointmentRoutes from './routes/appointments.js';
import journalRoutes from './routes/journal.js';
import careNotesRoutes from './routes/careNotes.js';
import aiRoutes from './routes/ai.js';
import familyRoutes from './routes/family.js';
import alertRoutes from './routes/alerts.js';
import organizationRoutes from './routes/organizations.js';
import pillCheckRoutes from './routes/pillChecks.js';
import doseLogRoutes from './routes/doseLogs.js';

const isProduction = process.env.NODE_ENV === 'production';

// ── Required-config check ─────────────────────────────────────────────────────
// In production we refuse to boot with missing/weak secrets rather than silently
// falling back to insecure defaults. In development we only warn.
function validateEnv() {
  const problems = [];
  const weakJwt = !process.env.JWT_SECRET
    || process.env.JWT_SECRET.length < 32
    || /change-in-production|dev-secret|super-secret-key/i.test(process.env.JWT_SECRET);

  if (weakJwt) problems.push('JWT_SECRET is missing or weak (need a long random value, 32+ chars).');
  if (!process.env.DATABASE_URL) problems.push('DATABASE_URL is not set (Postgres connection string).');
  if (/user:password@host\/dbname/.test(process.env.DATABASE_URL || '')) {
    problems.push('DATABASE_URL is still the placeholder value.');
  }
  // AI features (companion chat, handoff overview) need this — warn loudly but
  // don't block boot, since the rest of the API works without it.
  if (!process.env.NVIDIA_API_KEY) {
    logger.warn('⚠️  NVIDIA_API_KEY is not set — AI chat will use canned fallback replies and AI overview/summary will be unavailable.');
  }

  if (problems.length) {
    if (isProduction) {
      logger.error('Refusing to start — fix these environment problems:');
      problems.forEach((p) => logger.error(`  • ${p}`));
      process.exit(1);
    } else {
      problems.forEach((p) => logger.warn(`⚠️  ${p}`));
    }
  }
}
validateEnv();

const app = express();
const server = createServer(app);
const wss = new WebSocketServer({ server });

// Behind Render/Heroku/any reverse proxy: trust the first proxy so rate limiting
// and secure-cookie logic see the real client IP, not the proxy's.
app.set('trust proxy', 1);

// Middleware
app.use(helmet());
// CORS_ORIGIN accepts a comma-separated list so both the production
// dashboard domain and local dev servers can be allowed at once.
const corsOrigins = (process.env.CORS_ORIGIN || '*').split(',').map((o) => o.trim());
app.use(cors({
  origin: corsOrigins.includes('*') ? '*' : corsOrigins,
  credentials: true
}));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Request logging
app.use((req, res, next) => {
  logger.info(`${req.method} ${req.path}`);
  next();
});

// ── Rate limiting ─────────────────────────────────────────────────────────────
// A broad limiter across the API, plus a much stricter one on auth endpoints to
// slow credential-stuffing / brute-force attempts.
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 min
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests, please slow down and try again shortly.' }
});
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20, // login/register/google attempts per IP per window
  standardHeaders: true,
  legacyHeaders: false,
  skipSuccessfulRequests: true,
  message: { error: 'Too many attempts. Please wait a few minutes and try again.' }
});
app.use('/api/', apiLimiter);

// Health check — reports the real DB engine and pings it so uptime monitors
// (and Render's healthCheckPath) fail if the database is unreachable.
app.get('/health', async (req, res) => {
  try {
    await getDb().prepare('SELECT 1').get();
    res.json({
      status: 'ok',
      timestamp: new Date().toISOString(),
      version: '1.0.0',
      database: 'postgres',
      db: 'connected'
    });
  } catch (error) {
    res.status(503).json({
      status: 'degraded',
      timestamp: new Date().toISOString(),
      version: '1.0.0',
      database: 'postgres',
      db: 'unreachable'
    });
  }
});

// API Routes
app.use('/api/auth', authLimiter, authRoutes);
app.use('/api/patients', patientRoutes);
app.use('/api/wellness', wellnessRoutes);
app.use('/api/medications', medicationRoutes);
app.use('/api/appointments', appointmentRoutes);
app.use('/api/journal', journalRoutes);
app.use('/api/care-notes', careNotesRoutes);
app.use('/api/ai', aiRoutes);
app.use('/api/family', familyRoutes);
app.use('/api/alerts', alertRoutes);
app.use('/api/organizations', organizationRoutes);
app.use('/api/pill-checks', pillCheckRoutes);
app.use('/api/dose-logs', doseLogRoutes);

// WebSocket
wss.on('error', (error) => {
  logger.error('WebSocket server error:', error);
});

wss.on('connection', (ws) => {
  logger.info('WebSocket client connected');
  let authenticated = false;

  ws.on('error', (error) => logger.error('WebSocket client error:', error));

  ws.on('message', (message) => {
    if (authenticated) return; // only the initial auth message is handled
    try {
      const parsed = JSON.parse(message.toString());
      if (parsed.type === 'auth' && parsed.token) {
        const user = authenticateSocket(ws, parsed.token);
        if (user) {
          authenticated = true;
          ws.send(JSON.stringify({ type: 'auth_ok' }));
        } else {
          ws.send(JSON.stringify({ type: 'auth_failed' }));
        }
      }
    } catch (error) {
      logger.error('WS message parse error:', error.message);
    }
  });

  ws.on('close', () => logger.info('WebSocket client disconnected'));
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: { message: 'Route not found', status: 404 } });
});

// Error handler
app.use((err, req, res, next) => {
  logger.error(err.stack);
  res.status(err.status || 500).json({
    error: { message: err.message || 'Internal server error', status: err.status || 500 }
  });
});

// Start
const PORT = process.env.PORT || 3000;

process.on('uncaughtException', (error) => {
  logger.error('Uncaught exception:', error);
  process.exit(1);
});

process.on('unhandledRejection', (reason) => {
  logger.error('Unhandled promise rejection:', reason);
});

async function startServer() {
  try {
    await connectDatabase();
    await seedDemoData();
    server.on('error', (error) => {
      if (error.code === 'EADDRINUSE') {
        logger.error(`Port ${PORT} is already in use. Stop the existing server and retry.`);
      } else {
        logger.error('Server error:', error);
      }
      process.exit(1);
    });
    server.listen(PORT, '0.0.0.0', () => {
      logger.info(`CareBridge API running on http://0.0.0.0:${PORT}`);
      logger.info(`Health check: http://localhost:${PORT}/health`);
      logger.info(`Database: Postgres`);
      logger.info(`Environment: ${process.env.NODE_ENV || 'development'}`);
      const nets = os.networkInterfaces();
      for (const name of Object.keys(nets)) {
        for (const net of nets[name]) {
          if (net.family === 'IPv4' && !net.internal) {
            logger.info(`Local network URL (set in iOS app): http://${net.address}:${PORT}`);
          }
        }
      }
    });
  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
}

startServer();

export { wss };
