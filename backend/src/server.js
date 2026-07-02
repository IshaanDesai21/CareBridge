import 'dotenv/config';
import os from 'os';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { createServer } from 'http';
import { WebSocketServer } from 'ws';
import logger from './utils/logger.js';
import { connectDatabase } from './database/db.js';
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

const app = express();
const server = createServer(app);
const wss = new WebSocketServer({ server });

// Middleware
app.use(helmet());
app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  credentials: true
}));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Request logging
app.use((req, res, next) => {
  logger.info(`${req.method} ${req.path}`);
  next();
});

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
    database: 'SQLite'
  });
});

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/patients', patientRoutes);
app.use('/api/wellness', wellnessRoutes);
app.use('/api/medications', medicationRoutes);
app.use('/api/appointments', appointmentRoutes);
app.use('/api/journal', journalRoutes);
app.use('/api/care-notes', careNotesRoutes);
app.use('/api/ai', aiRoutes);
app.use('/api/family', familyRoutes);
app.use('/api/alerts', alertRoutes);

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

function startServer() {
  try {
    connectDatabase();
    seedDemoData();
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
      logger.info(`Database: SQLite (carebridge.db)`);
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
