// PolyTrack Leaderboard – liefert nur die Webseite aus, die Daten liegen in Supabase.
// Läuft nur mit Node.js (keine Pakete nötig)
// Start: node server.js  →  http://localhost:3815
const http = require('http');
const fs = require('fs');
const path = require('path');
const os = require('os');
const PORT = Number(process.env.PORT) || 3815;
const PUBLIC_DIR = path.join(__dirname, 'public');

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
};

function send(res, code, text = '') {
  res.writeHead(code, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end(text);
}

const server = http.createServer((req, res) => {
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    res.setHeader('Allow', 'GET, HEAD');
    return send(res, 405);
  }

  let p;
  try {
    p = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
  } catch {
    return send(res, 400, 'Bad request');
  }
  if (p.includes('\0')) return send(res, 400, 'Bad request');
  if (p.endsWith('/')) p += 'index.html';

  const full = path.join(PUBLIC_DIR, p);
  // Nur Dateien innerhalb von public/ ausliefern (auch nicht "public2/…")
  if (!full.startsWith(PUBLIC_DIR + path.sep)) return send(res, 403);

  fs.readFile(full, (err, buf) => {
    if (err) return send(res, 404, 'Not found');
    res.writeHead(200, {
      'Content-Type': MIME[path.extname(full).toLowerCase()] || 'application/octet-stream',
      'Cache-Control': 'no-cache',
      'X-Content-Type-Options': 'nosniff',
    });
    res.end(req.method === 'HEAD' ? undefined : buf);
  });
});   // <- hier endet createServer

server.on('error', (e) => {
  if (e.code === 'EADDRINUSE') console.error(`Port ${PORT} ist schon belegt – läuft der Server schon? Sonst: PORT=4000 node server.js`);
  else console.error(e);
  process.exit(1);
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`\nPolyTrack Leaderboard läuft:`);
  console.log(`  Lokal:     http://localhost:${PORT}`);
  for (const addrs of Object.values(os.networkInterfaces()))
    for (const a of addrs || [])
      if (a.family === 'IPv4' && !a.internal)
        console.log(`  Im WLAN:   http://${a.address}:${PORT}  (für deine Freunde im selben Netzwerk)`);
  console.log('');
});
