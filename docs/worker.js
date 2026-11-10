// 007 Clean Temp usage counter - Cloudflare Worker + D1.
//   POST /ping   {"id":"<guid>","v":"2.2.0","m":"gui"|"auto"}   counts one user per day
//   GET  /stats  totals for the stats page (no IDs are ever returned)

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};
const ID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const VER_RE = /^[0-9]{1,3}(\.[0-9]{1,3}){0,3}$/;

const day = (offset = 0) => new Date(Date.now() - offset * 86400000).toISOString().slice(0, 10);
const json = (data, extra = {}) =>
  new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json', ...CORS, ...extra } });

async function ping(request, env) {
  let b;
  try { b = await request.json(); } catch { return new Response('bad json', { status: 400, headers: CORS }); }
  const id = String(b.id || '').toLowerCase();
  const v = String(b.v || '');
  const m = b.m === 'auto' ? 'auto' : 'gui';
  if (!ID_RE.test(id) || !VER_RE.test(v)) return new Response('bad data', { status: 400, headers: CORS });

  const today = day();
  await env.DB.batch([
    env.DB.prepare('INSERT OR IGNORE INTO pings (id, day, version, mode) VALUES (?1, ?2, ?3, ?4)').bind(id, today, v, m),
    env.DB.prepare(
      `INSERT INTO installs (id, first_seen, last_seen, version) VALUES (?1, ?2, ?2, ?3)
       ON CONFLICT(id) DO UPDATE SET last_seen = excluded.last_seen, version = excluded.version`
    ).bind(id, today, v),
  ]);
  return new Response(null, { status: 204, headers: CORS });
}

async function stats(env) {
  const one = (sql, ...args) => env.DB.prepare(sql).bind(...args).first('n');
  const [total, today, week, month, newWeek] = await Promise.all([
    one('SELECT COUNT(*) AS n FROM installs'),
    one('SELECT COUNT(*) AS n FROM pings WHERE day = ?1', day()),
    one('SELECT COUNT(DISTINCT id) AS n FROM pings WHERE day >= ?1', day(6)),
    one('SELECT COUNT(DISTINCT id) AS n FROM pings WHERE day >= ?1', day(29)),
    one('SELECT COUNT(*) AS n FROM installs WHERE first_seen >= ?1', day(6)),
  ]);
  const daily = await env.DB.prepare(
    'SELECT day, COUNT(*) AS users FROM pings WHERE day >= ?1 GROUP BY day ORDER BY day'
  ).bind(day(29)).all();
  const versions = await env.DB.prepare(
    'SELECT version, COUNT(*) AS users FROM installs WHERE last_seen >= ?1 GROUP BY version ORDER BY users DESC'
  ).bind(day(29)).all();

  return json(
    { total, today, week, month, newWeek, daily: daily.results, versions: versions.results, updated: new Date().toISOString() },
    { 'Cache-Control': 'public, max-age=60' }
  );
}

export default {
  async fetch(request, env) {
    const { pathname } = new URL(request.url);
    if (request.method === 'OPTIONS') return new Response(null, { headers: CORS });
    if (pathname === '/ping' && request.method === 'POST') return ping(request, env);
    if (pathname === '/stats' && request.method === 'GET') return stats(env);
    return new Response('007 Clean Temp stats', { headers: CORS });
  },
};
