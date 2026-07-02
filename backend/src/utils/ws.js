import jwt from 'jsonwebtoken';
import logger from './logger.js';

// Maps userId -> Set of live WebSocket connections for that user (supports multiple devices/tabs)
const clientsByUser = new Map();

export function registerConnection(userId, ws) {
  if (!clientsByUser.has(userId)) clientsByUser.set(userId, new Set());
  clientsByUser.get(userId).add(ws);
}

export function removeConnection(userId, ws) {
  const set = clientsByUser.get(userId);
  if (!set) return;
  set.delete(ws);
  if (set.size === 0) clientsByUser.delete(userId);
}

export function sendToUser(userId, payload) {
  const set = clientsByUser.get(userId);
  if (!set || set.size === 0) return false;
  const data = JSON.stringify(payload);
  let delivered = false;
  for (const ws of set) {
    if (ws.readyState === ws.OPEN) {
      ws.send(data);
      delivered = true;
    }
  }
  return delivered;
}

// Verifies the auth token sent by the client as the first WS message and
// wires up connection tracking + cleanup. Returns the decoded user or null.
export function authenticateSocket(ws, token) {
  try {
    const user = jwt.verify(token, process.env.JWT_SECRET || 'carebridge-dev-secret');
    registerConnection(user.id, ws);
    ws.on('close', () => removeConnection(user.id, ws));
    return user;
  } catch (error) {
    logger.error('WebSocket auth failed:', error.message);
    return null;
  }
}
