// Harness QA: monta el handler de Vercel (api/[...slug].js) en HTTP local
// para probar el flujo REAL del chat IA con Groq y Supabase reales.
const http = require('node:http');
const path = require('node:path');
const handler = require(path.join(__dirname, '..', '..', 'api', '[...slug].js'));

// Carga .env.prod en process.env
require('node:fs')
  .readFileSync(path.join(__dirname, '..', '..', '.env.prod'), 'utf8')
  .split(/\r?\n/)
  .forEach((l) => {
    const m = l.match(/^([A-Z_0-9]+)=(.*)$/);
    if (m) process.env[m[1]] = m[2].replace(/^"|"$/g, '');
  });

const server = http.createServer((req, res) => {
  // shim mínimo de express: res.status(code).json(obj)
  if (!res.status) {
    res.status = (code) => {
      res.statusCode = code;
      res.json = (obj) => {
        res.setHeader('Content-Type', 'application/json');
        res.end(JSON.stringify(obj));
        return res;
      };
      return res;
    };
  }
  const url = new URL(req.url, 'http://localhost');
  // Simula el catch-all de Vercel: req.query.slug = segmentos tras /api
  const slug = url.pathname.replace(/^\/api\//, '').split('/').filter(Boolean);
  req.query = { ...Object.fromEntries(url.searchParams), slug };
  req.url = url.pathname + url.search;
  const chunks = [];
  req.on('data', (c) => chunks.push(c));
  req.on('end', () => {
    // parseBody del login usa req.body como Buffer/string.
    req.body = Buffer.concat(chunks).toString('utf-8');
    Promise.resolve(handler(req, res)).catch((e) => {
      console.error('[harness] error:', e);
      if (!res.headersSent) res.status(500).json({ error: String(e) });
    });
  });
});

server.listen(8791, () => console.log('LISTEN 8791'));
