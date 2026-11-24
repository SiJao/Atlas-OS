// Atlas OS updater (DESIGN §20, approved 2026-11-24). Runs as the "atlas" user via systemd --user services,
// separate from Atlas's server (installing restarts the server). No root, no npm packages.
//
//   node atlas-update.mjs cek       is there a newer commit on SiJao/atlas main?   -> update.json "tersedia"/"terbaru"
//   node atlas-update.mjs pasang    clone -> trial run -> back up data -> switch -> health check -> (rollback)
//   node atlas-update.mjs kembali   switch back to the previous release
//   node atlas-update.mjs status
//
// State for Atlas: <ATLAS_DATA>/update.json. Releases: /opt/atlas/releases/<sha12>, active one = /opt/atlas/current.
import { execFile, spawn } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const HOME = os.homedir();
const REPO = process.env.ATLAS_UPDATE_REPO || 'git@github.com:SiJao/atlas.git';
const REF = process.env.ATLAS_UPDATE_REF || 'main';
const ROOT = process.env.ATLAS_ROOT || '/opt/atlas';
const RELEASES = path.join(ROOT, 'releases');
const CURRENT = path.join(ROOT, 'current');
const DATA = process.env.ATLAS_DATA || path.join(HOME, 'atlas-data');
const STATE = path.join(DATA, 'update.json');
const BACKUPS = path.join(HOME, 'atlas-cadangan');
// Commit history only (for the list of changes), one cache per repository address.
const MIRROR = path.join(HOME, '.cache', `atlas-repo-${createHash('sha1').update(REPO).digest('hex').slice(0, 8)}.git`);
const LOCK = path.join(os.tmpdir(), `atlas-update-${process.getuid?.() ?? 'x'}.lock`);
const PORT = Number(process.env.ATLAS_PORT || 4950);
const TRIAL_PORT = 4960;
const KEEP_RELEASES = 3;
const KEEP_BACKUPS = 3;
const HEALTH_SECONDS = Number(process.env.ATLAS_UPDATE_HEALTH_SECONDS || 60);

const log = (...a) => console.log('[atlas-update]', ...a);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function run(cmd, args, { cwd, timeoutMs = 180000, env } = {}) {
  return new Promise((resolve, reject) => {
    execFile(cmd, args, { cwd, timeout: timeoutMs, maxBuffer: 16 * 1024 * 1024, env: env || process.env }, (e, out, err) => {
      if (e) reject(new Error(String(err || e.message).trim().split('\n').slice(-3).join(' ').slice(0, 300)));
      else resolve(String(out).trim());
    });
  });
}
const git = (args, o) => run('git', args, o);

// ---------- state ----------
function readState() { try { return JSON.parse(fs.readFileSync(STATE, 'utf8')); } catch { return {}; } }
function writeState(next) {
  const prev = readState();
  // buruk (failed versions), riwayat and sebelumnya (the release to go back to) survive every later state.
  const s = { buruk: prev.buruk || [], riwayat: prev.riwayat || [], ...(prev.sebelumnya ? { sebelumnya: prev.sebelumnya } : {}), ...next, waktu: new Date().toISOString() };
  if (next.status && next.status !== prev.status) s.riwayat = [{ status: next.status, sha: next.sha || null, waktu: s.waktu }, ...s.riwayat].slice(0, 10);
  fs.mkdirSync(DATA, { recursive: true });
  const tmp = `${STATE}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(s, null, 2));
  fs.renameSync(tmp, STATE);
  return s;
}
const markBad = (sha) => { const s = readState(); return [...new Set([...(s.buruk || []), sha])].slice(-20); };

const currentSha = () => { try { return path.basename(fs.realpathSync(CURRENT)); } catch { return null; } };
async function fullShaOf(dir) { try { return await git(['-C', dir, 'rev-parse', 'HEAD']); } catch { return null; } }

/** Point /opt/atlas/current at a release atomically (new link + rename). */
function switchTo(sha) {
  const tmp = `${CURRENT}.new`;
  try { fs.rmSync(tmp, { force: true }); } catch { /* none */ }
  fs.symlinkSync(path.join(RELEASES, sha), tmp);
  fs.renameSync(tmp, CURRENT);
}

const systemctl = (...a) => run('systemctl', ['--user', ...a], { timeoutMs: 60000 });

async function httpOk(port, p = '/') {
  try {
    const r = await fetch(`http://127.0.0.1:${port}${p}`, { signal: AbortSignal.timeout(4000) });
    return r.ok ? await r.text() : null;
  } catch { return null; }
}

// ---------- cek ----------
async function mirror() {
  if (!fs.existsSync(MIRROR)) {
    fs.mkdirSync(path.dirname(MIRROR), { recursive: true });
    await git(['clone', '-q', '--bare', '--filter=blob:none', REPO, MIRROR]);
  } else {
    await git(['--git-dir', MIRROR, 'fetch', '-q', '--prune', 'origin', `+refs/heads/${REF}:refs/heads/${REF}`]);
  }
  return git(['--git-dir', MIRROR, 'rev-parse', REF]);
}

async function cek() {
  const sekarang = currentSha();
  try {
    const full = await mirror();
    const sha = full.slice(0, 12);
    if (sha === sekarang) return writeState({ status: 'terbaru', sekarang, sha: null, perubahan: [], dicek: new Date().toISOString() });
    if ((readState().buruk || []).includes(sha)) return writeState({ status: 'dilewati', sekarang, sha, alasan: 'versi ini pernah gagal', dicek: new Date().toISOString() });
    let perubahan = [];
    const curFull = sekarang && await fullShaOf(path.join(RELEASES, sekarang));
    try { perubahan = (await git(['--git-dir', MIRROR, 'log', '--format=%s', `${curFull}..${full}`])).split('\n').filter(Boolean).slice(0, 20); } catch { /* history unknown */ }
    log(`versi baru ${sha} (${perubahan.length} perubahan), sekarang ${sekarang}`);
    return writeState({ status: 'tersedia', sekarang, sha, full, perubahan, dicek: new Date().toISOString() });
  } catch (e) {
    log('cek gagal:', e.message);
    const prev = readState();
    // Keep an offer that is still valid; only record that this check failed.
    return writeState({ ...(prev.status === 'tersedia' ? {} : { status: 'galat-cek' }), sekarang, galatCek: e.message, dicek: new Date().toISOString() });
  }
}

// ---------- pasang ----------
async function trialRun(dir) {
  const data = fs.mkdtempSync(path.join(os.tmpdir(), 'atlas-uji-'));
  fs.cpSync(DATA, data, { recursive: true, filter: (src) => !/server\.pid$/.test(src) });
  const env = { ...process.env, ATLAS_DATA: data, ATLAS_PORT: String(TRIAL_PORT), ATLAS_UJI_JALAN: '1' };
  delete env.ATLAS_KIOSK;
  const child = spawn(process.execPath, ['server/index.js'], { cwd: dir, env, stdio: ['ignore', 'pipe', 'pipe'] });
  let out = '';
  child.stdout.on('data', (d) => { out += d; });
  child.stderr.on('data', (d) => { out += d; });
  try {
    for (let i = 0; i < 30; i++) {
      await sleep(1000);
      if (child.exitCode !== null) {
        const lines = out.trim().split('\n');
        const why = lines.find((l) => /\b\w*Error\b/.test(l)) || lines.at(-1) || '';
        throw new Error(`server versi baru berhenti (kode ${child.exitCode}): ${why.trim().slice(0, 200)}`);
      }
      const page = await httpOk(TRIAL_PORT, '/?kiosk=1');
      if (!page) continue;
      if (!page.includes('id="kiosk"')) throw new Error('halaman layar utama tidak lengkap');
      const k = await httpOk(TRIAL_PORT, '/api/keadaan');
      if (!k) throw new Error('/api/keadaan tidak menjawab');
      JSON.parse(k);
      return true;
    }
    throw new Error('server versi baru tidak menjawab dalam 30 detik');
  } finally {
    child.kill('SIGTERM');
    await sleep(500);
    if (child.exitCode === null) child.kill('SIGKILL');
    fs.rmSync(data, { recursive: true, force: true });
  }
}

function backupData(label) {
  fs.mkdirSync(BACKUPS, { recursive: true });
  const f = path.join(BACKUPS, `${new Date().toISOString().replace(/[:.]/g, '-')}-${label}.tar.gz`);
  return run('tar', ['-czf', f, '-C', path.dirname(DATA), path.basename(DATA)]).then(() => {
    const all = fs.readdirSync(BACKUPS).filter((n) => n.endsWith('.tar.gz')).sort();
    for (const old of all.slice(0, Math.max(0, all.length - KEEP_BACKUPS))) fs.rmSync(path.join(BACKUPS, old), { force: true });
    return f;
  });
}

/** Atlas must come up within 20 s and then stay up until HEALTH_SECONDS. */
async function healthy() {
  let up = false;
  for (let t = 0; t < HEALTH_SECONDS; t += 5) {
    await sleep(5000);
    const ok = !!(await httpOk(PORT, '/')) && !!(await httpOk(PORT, '/api/keadaan'));
    let active = false;
    try { active = (await systemctl('is-active', 'atlas.service')) === 'active'; } catch { active = false; }
    if (ok && active) up = true;
    else if (up || t >= 20) return false;
  }
  return up;
}

async function restartAtlas() {
  await systemctl('reset-failed', 'atlas.service').catch(() => {});
  await systemctl('restart', 'atlas.service');
}

function pruneReleases(keep) {
  const cur = currentSha();
  const all = fs.readdirSync(RELEASES).filter((n) => !n.endsWith('.tmp'))
    .map((n) => ({ n, t: fs.statSync(path.join(RELEASES, n)).mtimeMs })).sort((a, b) => b.t - a.t);
  const stay = new Set([cur, ...keep, ...all.slice(0, KEEP_RELEASES).map((x) => x.n)]);
  for (const { n } of all) if (!stay.has(n)) fs.rmSync(path.join(RELEASES, n), { recursive: true, force: true });
}

async function pasang() {
  // Always check again first: main may have moved on since the offer was shown (install the newest).
  const s = await cek();
  if (s.status !== 'tersedia') { log('tidak ada versi baru'); return s; }
  const lama = currentSha();
  let sha = s.sha;
  const dir = path.join(RELEASES, sha);
  // 1. clone (read-only deploy key) — the exact commit that was offered
  if (!fs.existsSync(dir)) {
    const tmp = `${dir}.tmp`;
    fs.rmSync(tmp, { recursive: true, force: true });
    await git(['clone', '-q', '--depth', '20', '--branch', REF, REPO, tmp]);
    if (s.full) await git(['-C', tmp, 'checkout', '-q', s.full]).catch(() => { throw new Error(`commit ${sha} tidak ditemukan di ${REF}`); });
    fs.renameSync(tmp, dir);
  }
  // 2. trial run on a spare port with a COPY of the data
  try {
    log(`uji jalan ${sha} di port ${TRIAL_PORT}…`);
    await trialRun(dir);
  } catch (e) {
    log('uji jalan gagal:', e.message);
    fs.rmSync(dir, { recursive: true, force: true });
    return writeState({ status: 'gagal', tahap: 'uji', sha, sekarang: lama, alasan: e.message, buruk: markBad(sha) });
  }
  // 3. back up the data, 4. switch, 5. health check
  const cadangan = await backupData(lama || 'awal');
  log('data dicadangkan:', cadangan);
  // A silent in-between state: the Atlas that starts after the switch must not re-announce "a new version is available".
  writeState({ status: 'memasang', sha, sekarang: lama, perubahan: s.perubahan || [] });
  switchTo(sha);
  await restartAtlas();
  if (await healthy()) {
    fs.utimesSync(dir, new Date(), new Date());
    pruneReleases([lama]);
    log(`terpasang: ${lama} -> ${sha}`);
    return writeState({ status: 'terpasang', sha, sekarang: sha, sebelumnya: lama, cadangan, perubahan: s.perubahan || [] });
  }
  // 6. rollback
  log(`versi ${sha} tidak sehat; kembali ke ${lama}`);
  switchTo(lama);
  await restartAtlas();
  fs.rmSync(dir, { recursive: true, force: true }); // a failed release must never be picked by "kembali"
  return writeState({ status: 'gagal', tahap: 'jalan', sha, sekarang: lama, alasan: 'Atlas tidak berjalan stabil setelah diganti', buruk: markBad(sha) });
}

// ---------- kembali ----------
async function kembali() {
  const cur = currentSha();
  const s = readState();
  const buruk = new Set(s.buruk || []);
  const others = fs.readdirSync(RELEASES).filter((n) => n !== cur && !n.endsWith('.tmp') && !buruk.has(n))
    .map((n) => ({ n, t: fs.statSync(path.join(RELEASES, n)).mtimeMs })).sort((a, b) => b.t - a.t).map((x) => x.n);
  const target = s.sebelumnya && others.includes(s.sebelumnya) ? s.sebelumnya : others[0];
  if (!target) throw new Error('Tidak ada versi sebelumnya yang tersimpan.');
  writeState({ status: 'mengembalikan', sha: target, sekarang: cur });
  switchTo(target);
  await restartAtlas();
  const ok = await healthy();
  log(`kembali: ${cur} -> ${target} (${ok ? 'sehat' : 'TIDAK sehat'})`);
  return writeState({ status: 'kembali', sha: target, sekarang: target, dari: cur, sehat: ok, buruk: cur ? markBad(cur) : s.buruk });
}

// ---------- main ----------
const cmd = process.argv[2] || 'status';
let lockFd = null;
try {
  if (cmd !== 'status') {
    try { lockFd = fs.openSync(LOCK, 'wx'); } catch { log('pembaruan lain sedang berjalan'); process.exit(0); }
  }
  const fn = { cek, pasang, kembali, status: async () => readState() }[cmd];
  if (!fn) { console.error('pakai: cek | pasang | kembali | status'); process.exitCode = 2; }
  else console.log(JSON.stringify(await fn(), null, 2));
} catch (e) {
  log('galat:', e.message);
  if (cmd !== 'status') writeState({ status: cmd === 'kembali' ? 'gagal-kembali' : 'gagal', tahap: cmd, alasan: e.message, sekarang: currentSha() });
  process.exitCode = 1;
} finally {
  if (lockFd !== null) { fs.closeSync(lockFd); fs.rmSync(LOCK, { force: true }); }
}
