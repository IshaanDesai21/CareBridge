/**
 * Invoke an Express router's route handlers directly (no HTTP server).
 * Runs only the matched route's handler stack, skipping router.use() layers
 * such as authenticateToken; the caller supplies req.user.
 */
export function invokeRoute(router, method, routePath, { body = {}, params = {}, query = {}, user } = {}) {
  return new Promise((resolve, reject) => {
    const m = method.toLowerCase();
    const layer = router.stack.find((l) => l.route?.path === routePath && l.route?.methods?.[m]);
    if (!layer) {
      reject(new Error(`${method.toUpperCase()} ${routePath} route not found in router stack`));
      return;
    }

    const req = { method: m.toUpperCase(), url: routePath, path: routePath, body, params, query, user, headers: {} };
    let statusCode = 200;
    const res = {
      status(code) {
        statusCode = code;
        return res;
      },
      json(payload) {
        resolve({ status: statusCode, body: payload });
        return res;
      },
      send(payload) {
        resolve({ status: statusCode, body: payload });
        return res;
      },
      sendStatus(code) {
        resolve({ status: code, body: undefined });
        return res;
      },
    };

    const handlers = layer.route.stack.map((h) => h.handle);
    let idx = 0;
    const fail = (e) => resolve({ status: 500, body: { error: String(e) } });
    const next = (err) => {
      if (err) return fail(err);
      const fn = handlers[idx++];
      if (!fn) return;
      try {
        const out = fn(req, res, next);
        if (out && typeof out.catch === 'function') out.catch(fail);
      } catch (e) {
        fail(e);
      }
    };
    next();
  });
}
