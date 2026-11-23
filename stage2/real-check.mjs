// Stage 2 smoke test with REAL Linux programs (Atlas OS DESIGN §17.3). Run inside the test VM from ~/atlas:
//   node ~/stage2/real-check.mjs        (DISPLAY, D-Bus session and Openbox must already run: see smoke-test.sh)
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const { platform } = await import(pathToFileURL(path.join(process.cwd(), 'server/os/index.js')).href);
const results = [];
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function check(name, fn) {
  const t = Date.now();
  try {
    const info = await fn();
    results.push({ name, ok: true, info });
    console.log(`PASS ${name} (${Date.now() - t} ms)${info !== undefined ? ` -> ${JSON.stringify(info).slice(0, 300)}` : ''}`);
  } catch (e) {
    results.push({ name, ok: false, info: e.message });
    console.log(`FAIL ${name} (${Date.now() - t} ms) -> ${e.message}`);
  }
}
const must = (cond, msg) => { if (!cond) throw new Error(msg); };

await check('adapter is linux', () => { must(platform.name === 'linux', platform.name); return platform.label; });
await check('systemInfo (cpu, baterai, disk, proses, jaringan)', () => platform.systemInfo(() => true));
await check('topProcesses', async () => { const t = await platform.topProcesses(); must(t.length > 0, 'empty'); return t.slice(0, 3); });
await check('volume lihat / atur 30 / bisu / bunyikan', async () => {
  const before = await platform.volume('lihat');
  const v = await platform.volume('atur', 30);
  must(v.volume === 30, `volume ${v.volume}`);
  must((await platform.volume('bisu')).bisu === true, 'not muted');
  await platform.volume('bunyikan');
  await platform.volume('atur', before.volume);
  return { before, set: v };
});
await check('brightness (VM has no backlight: a clear error is the expected answer)', async () => {
  try { return { kecerahan: await platform.brightness() }; } catch (e) { must(/kecerahan/.test(e.message), e.message); return `error ok: ${e.message}`; }
});
await check('trash: moveToTrash + findInTrash + restore', async () => {
  const f = path.join(os.homedir(), 'Downloads', `atlas-uji-${process.pid}.txt`);
  fs.writeFileSync(f, 'uji tempat sampah');
  await platform.moveToTrash(f, false);
  must(!fs.existsSync(f), 'still there');
  const [x] = platform.findInTrash(f);
  must(x, 'not found in trash');
  fs.renameSync(x.isi, f);
  fs.rmSync(x.info);
  must(fs.readFileSync(f, 'utf8') === 'uji tempat sampah', 'content changed');
  fs.rmSync(f);
  return { trashName: platform.trashName };
});
await check('secretProtector (systemd-creds --user) round trip', async () => {
  const s = await platform.secretProtector.protect('kunci-uji-123');
  must(!s.includes('kunci-uji-123'), 'plain text');
  must(await platform.secretProtector.unprotect(s) === 'kunci-uji-123', 'round trip');
  return { storedLength: s.length };
});
await check('Claude guard: sudo blocked, rm risky', () => {
  must(platform.adminPattern.test('sudo apt install x'), 'sudo');
  must(platform.riskyCommands.some((r) => r.pola.test('rm -rf x')), 'rm');
  return platform.claudeExecutable;
});

// ----- window helper -----
const h = new platform.WindowHelper();
const events = { jendela: [], diam: [], daya: [], hotkey: 0 };
h.on('jendela', (j) => events.jendela.push(j));
h.on('diam', (d) => events.diam.push(d));
h.on('daya', (d) => events.daya.push(d));
h.on('hotkey', () => { events.hotkey += 1; });
h.mulai();

await check('openApp("excel") -> LibreOffice Calc', async () => {
  const r = platform.openApp('excel');
  for (let i = 0; i < 40; i++) {
    await sleep(1000);
    if ((await platform.listProcesses()).some((p) => p.nama === 'soffice.bin')) return r;
  }
  throw new Error('soffice.bin did not start');
});
await sleep(8000); // let Calc draw its window

await check('helper events: jendela, diam, daya', async () => {
  await sleep(3000);
  must(events.jendela.length > 0, 'no jendela event');
  must(events.diam.length > 0, 'no diam event');
  return { jendela: events.jendela.at(-1), diam: events.diam.at(-1), daya: h.daya, detikDiam: h.detikDiam() };
});
await check('hotkey FIFO (what Openbox does on Ctrl+Alt+Space)', async () => {
  fs.writeFileSync(h.fifo, 'HOTKEY\n');
  await sleep(500);
  must(events.hotkey === 1, `hotkey events: ${events.hotkey}`);
  return h.fifo;
});
await check('uia depan (xdotool + AT-SPI elements)', async () => {
  const d = await h.uia('depan');
  must(d.proses && d.proses !== '?', 'no front process');
  return { proses: d.proses, judul: d.judul, elemen: d.elemen.length, contoh: d.elemen.slice(0, 5).map((e) => e.nama) };
});
await check('uia daftar soffice.bin (AT-SPI)', async () => {
  const r = await h.uia('daftar', ['soffice.bin']);
  must(r.kontrol.length > 0, 'no controls');
  return { jendela: r.jendela, kontrol: r.kontrol.length, contoh: r.kontrol.filter((k) => k.nama).slice(0, 8).map((k) => `${k.nama} (${k.jenis})`) };
});
await check('uia tekan "OK" on the Tip of the Day dialog (AT-SPI)', async () => {
  const d = await h.uia('daftar', ['soffice.bin']);
  if (!/tip of the day/i.test(d.jendela)) return `no dialog (${d.jendela})`;
  const r = await h.uia('tekan', ['soffice.bin', 'OK']);
  await sleep(2000);
  return r;
});
await check('uia isi: a text field in Find & Replace (AT-SPI)', async () => {
  await h.uia('kendali-mulai');
  await h.uia('tombol', ['ctrl+h']);
  await h.uia('kendali-selesai');
  await sleep(4000);
  const daftar = await h.uia('daftar', ['soffice.bin']);
  const kolom = daftar.kontrol.find((k) => k.nama && k.aktif && /text|entry|combo/i.test(k.jenis));
  must(kolom, `no named text field in "${daftar.jendela}": ${daftar.kontrol.map((k) => `${k.nama}/${k.jenis}`).slice(0, 25).join(', ')}`);
  const r = await h.uia('isi', ['soffice.bin', kolom.nama, 'Atlas OS']);
  await h.uia('tekan', ['soffice.bin', 'Close']).catch(() => {});
  return { jendela: daftar.jendela, kolom, r };
});
await check('uia layar (screenshot)', async () => {
  const f = path.join(os.tmpdir(), 'atlas-layar.jpg');
  const r = await h.uia('layar', [f, '1280']);
  must(fs.statSync(f).size > 1000, 'empty screenshot');
  fs.rmSync(f);
  return r;
});
await check('uia control session: klik, tombol, ketik, gulir', async () => {
  await h.uia('kendali-mulai');
  const out = [];
  out.push(await h.uia('klik', ['640', '400', 'kiri', '1']));
  out.push(await h.uia('tombol', ['ctrl+home']));
  out.push(await h.uia('ketik', [Buffer.from('Atlas OS').toString('base64')]));
  out.push(await h.uia('tombol', ['enter']));
  out.push(await h.uia('gulir', ['bawah', '3', '', '']));
  out.push(await h.uia('kendali-selesai'));
  must(out.at(-1).dibatalkan === false, 'own input triggered the emergency stop');
  return out;
});
await check('closeProcesses soffice.bin (forced)', async () => {
  const ids = (await platform.listProcesses()).filter((p) => p.nama === 'soffice.bin').map((p) => p.id);
  return { sisa: await platform.closeProcesses(ids, true) };
});

h.berhenti();
const failed = results.filter((r) => !r.ok);
console.log(`\n${results.length - failed.length}/${results.length} PASS`);
fs.writeFileSync(path.join(os.homedir(), 'stage2-real-check.json'), JSON.stringify(results, null, 2));
process.exit(failed.length ? 1 : 0);
