// Atlas OS Live log receiver for Hong Khai's PC (DESIGN §26.6, review §26.7). No dependencies (Node 24).
//   node log-receiver.mjs [folder] [host]     default folder: C:\HISADA\atlas-live-logs (Windows) or ~/atlas-live-logs
//                                             host 127.0.0.1 = only this PC and its VirtualBox VMs (NAT 10.0.2.2)
// The folder holds receiver.json { "token": "<64 hex>", "port": 4960 }; made on first run. The same code goes into the
// live image (--log-token-file). Never commit receiver.json. The code itself is never sent over the network:
//   UDP  "ATLAS-LOG?<c>"            -> "ATLAS-LOG!" + HMAC(code, "udp:" + c)       (the stick finds this PC)
//   GET  /hai?c=<c>                 -> {"p": HMAC(code, "hai:" + c)}              (this PC proves it knows the code)
//   GET  /nonce                     -> {"s": <single-use nonce, 5 min>}
//   POST /log?name=&s=&sig=         sig = HMAC(code, "log:" + s + ":" + name + ":" + sha256(body))
// Logs are stored as received (.tar.gz, Windows Explorer opens them); nothing is unpacked or run here.
import http from 'node:http';
import dgram from 'node:dgram';
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const MAX_BYTES = 20 * 1024 * 1024;
export const NAME_RE = /^[A-Za-z0-9][A-Za-z0-9._-]{0,120}\.tar\.gz$/;
const WIN_RESERVED = /^(con|prn|aux|nul|com[0-9]|lpt[0-9])$/i;
const NONCE_RE = /^[0-9a-f]{32}$/;

export function loadConfig(dir) {
  fs.mkdirSync(dir, { recursive: true });
  const f = path.join(dir, 'receiver.json');
  let c = {};
  try { c = JSON.parse(fs.readFileSync(f, 'utf8')); } catch { /* first run */ }
  if (!/^[0-9a-f]{64}$/.test(c.token || '')) {
    c = { token: crypto.randomBytes(32).toString('hex'), port: c.port || 4960 };
    fs.writeFileSync(f, `${JSON.stringify(c, null, 2)}\n`, { mode: 0o600 });
  }
  return { token: c.token, port: Number(c.port) || 4960 };
}

export const hmacHex = (token, msg) => crypto.createHmac('sha256', token).update(msg).digest('hex');
const same = (a, b) => {
  const x = Buffer.from(String(a || '')), y = Buffer.from(String(b || ''));
  return x.length === y.length && crypto.timingSafeEqual(x, y);
};
/** Folder for a log: the laptop model at the front of the name, safe on Windows. */
export function modelOf(name) {
  const m = name.split('-').slice(0, -3).join('-').replace(/[^A-Za-z0-9._-]/g, '').replace(/[. ]+$/, '').slice(0, 60);
  return !m || WIN_RESERVED.test(m.split('.')[0]) ? 'laptop' : m;
}

/** Starts both listeners; resolves to { http, udp, port, close() }. log(msg) receives one line per stored log. */
export function startReceiver({ dir, token, port = 4960, host = '0.0.0.0', log = () => {} }) {
  const nonces = new Map();              // nonce -> expiry
  const perIp = new Map();               // ip -> timestamps of requests (rate limit)
  const limited = (ip, max) => {
    const now = Date.now(), l = (perIp.get(ip) || []).filter((t) => now - t < 60000);
    l.push(now); perIp.set(ip, l);
    if (perIp.size > 1000) perIp.clear();
    return l.length > max;
  };
  const srv = http.createServer((req, res) => {
    const end = (code, body, type = 'text/plain; charset=utf-8') => {
      if (res.headersSent) return;
      res.writeHead(code, { 'Content-Type': type }); res.end(body);
    };
    try {
      const ip = req.socket.remoteAddress || '?';
      if (limited(ip, 120)) { req.resume(); return end(429, 'terlalu sering'); }
      let url;
      try { url = new URL(req.url || '/', 'http://x'); } catch { req.resume(); return end(400, 'alamat tidak sah'); }
      if (req.method === 'GET' && url.pathname === '/hai') {
        const c = url.searchParams.get('c') || '';
        if (!NONCE_RE.test(c)) return end(400, 'tidak sah');
        return end(200, JSON.stringify({ p: hmacHex(token, `hai:${c}`) }), 'application/json');
      }
      if (req.method === 'GET' && url.pathname === '/nonce') {
        const now = Date.now();
        for (const [k, t] of nonces) if (t < now) nonces.delete(k);
        if (nonces.size > 500) return end(429, 'terlalu banyak');
        const s = crypto.randomBytes(16).toString('hex');
        nonces.set(s, now + 5 * 60000);
        return end(200, JSON.stringify({ s }), 'application/json');
      }
      if (req.method !== 'POST' || url.pathname !== '/log') { req.resume(); return end(404, 'tidak ada'); }
      const name = url.searchParams.get('name') || '', s = url.searchParams.get('s') || '', sig = url.searchParams.get('sig') || '';
      const exp = nonces.get(s);
      if (!NAME_RE.test(name) || !NONCE_RE.test(s)) { req.resume(); return end(400, 'nama/nonce tidak sah'); }
      if (!exp || exp < Date.now()) { req.resume(); return end(403, 'nonce kedaluwarsa'); }
      nonces.delete(s); // single use, whatever happens next
      const folder = path.join(dir, modelOf(name));
      fs.mkdirSync(folder, { recursive: true });
      const target = path.join(folder, name);
      const tmp = path.join(dir, `.masuk-${crypto.randomBytes(6).toString('hex')}`);
      const hash = crypto.createHash('sha256');
      let size = 0, stop = false;
      const out = fs.createWriteStream(tmp);
      const cleanup = () => { try { fs.rmSync(tmp, { force: true }); } catch { /* ignore */ } };
      req.on('data', (c) => {
        if (stop) return;
        size += c.length;
        if (size > MAX_BYTES) { stop = true; out.destroy(); cleanup(); end(413, 'terlalu besar'); req.destroy(); return; }
        hash.update(c); out.write(c);
      });
      req.on('error', () => { stop = true; out.destroy(); cleanup(); });
      req.on('end', () => { if (!stop) out.end(); });
      out.on('error', () => { stop = true; cleanup(); end(500, 'gagal menyimpan'); });
      out.on('finish', () => {
        if (stop) return;
        try {
          if (!same(sig, hmacHex(token, `log:${s}:${name}:${hash.digest('hex')}`))) { cleanup(); return end(403, 'tanda tangan salah'); }
          if (fs.existsSync(target)) { cleanup(); return end(200, 'sudah ada'); } // re-sent after a lost reply: keep the first
          fs.renameSync(tmp, target);
          log(`${new Date().toISOString()} ${ip} ${path.basename(folder)}/${name} ${size} byte`);
          end(200, 'tersimpan');
        } catch { cleanup(); end(500, 'gagal menyimpan'); }
      });
    } catch { end(500, 'galat'); }
  });
  srv.on('clientError', (_e, socket) => { try { socket.end('HTTP/1.1 400 Bad Request\r\n\r\n'); } catch { /* ignore */ } });
  const udp = dgram.createSocket({ type: 'udp4', reuseAddr: true });
  udp.on('message', (m, r) => {
    const t = m.toString();
    const c = t.startsWith('ATLAS-LOG?') ? t.slice(10) : '';
    if (!NONCE_RE.test(c) || limited(`udp:${r.address}`, 20)) return;
    udp.send(`ATLAS-LOG!${hmacHex(token, `udp:${c}`)}`, r.port, r.address);
  });
  udp.on('error', () => {});
  return new Promise((resolve, reject) => {
    srv.once('error', reject);
    srv.listen(port, host, () => {
      udp.bind(srv.address().port, host, () => resolve({
        http: srv, udp, port: srv.address().port,
        close: () => new Promise((r) => { udp.close(); srv.close(() => r()); }),
      }));
    });
  });
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const dir = process.argv[2] || (process.platform === 'win32' ? 'C:\\HISADA\\atlas-live-logs' : path.join(os.homedir(), 'atlas-live-logs'));
  const host = process.argv[3] || '0.0.0.0';
  const { token, port } = loadConfig(dir);
  const logFile = path.join(dir, 'penerima.log');
  const log = (l) => { try { fs.appendFileSync(logFile, `${l}\n`); } catch { /* ignore */ } console.log(l); };
  process.on('uncaughtException', (e) => log(`${new Date().toISOString()} galat (penerima tetap jalan): ${e.message}`));
  startReceiver({ dir, token, port, host, log }).then(() => log(`${new Date().toISOString()} penerima log Atlas OS Live siap di ${host}:${port} (${dir})`))
    .catch((e) => { log(`${new Date().toISOString()} gagal mulai: ${e.message}`); process.exit(1); });
}
