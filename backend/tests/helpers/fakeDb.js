/**
 * Minimal fake of the getDb() interface for route/unit tests.
 * rules: Array<[RegExp, { get?, all?, run? }]> — the first regex matching the SQL wins.
 * Every call is recorded in db.calls: Array<{ sql, method, params }>.
 */
export function fakeDb(rules) {
  const calls = [];
  return {
    calls,
    prepare(sql) {
      const call = (method) => async (...params) => {
        calls.push({ sql, method, params });
        const rule = rules.find(([re]) => re.test(sql));
        if (!rule) throw new Error('fakeDb: unmatched SQL: ' + sql);
        const handler = rule[1][method];
        if (!handler) throw new Error(`fakeDb: no ${method} handler for SQL: ${sql}`);
        return handler(...params);
      };
      return { get: call('get'), all: call('all'), run: call('run') };
    },
  };
}
