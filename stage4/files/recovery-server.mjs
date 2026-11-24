// Atlas OS recovery page (DESIGN §10 / §19.3). Started by atlas-recovery.service when atlas.service has
// failed 3 times in 2 minutes. Only on 127.0.0.1:4951; POSTs only from this page (Origin check).
// Shows the last log lines and offers: restart Atlas, go back to the previous version (§20), restart the laptop.
import { createServer } from 'node:http';
import { execFile } from 'node:child_process';

const PORT = 4951;
const ASAL = `http://127.0.0.1:${PORT}`;
const jalankan = (cmd, args) => new Promise((r) => execFile(cmd, args, { timeout: 20000 }, (e, out, err) => r({ ok: !e, teks: String(out || err || (e && e.message) || '') })));
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

async function halaman(pesan = '') {
  const log = await jalankan('journalctl', ['--user', '-u', 'atlas.service', '-n', '40', '--no-pager', '-o', 'short-iso']);
  return `<!doctype html><html lang="id"><head><meta charset="utf-8"><meta name="google" content="notranslate"><title>Atlas — Pemulihan</title>
<style>
  body { margin: 0; min-height: 100vh; background: #0B1220; color: #E6EDF7; font: 22px "Segoe UI", "DejaVu Sans", system-ui, sans-serif; display: grid; place-items: center; }
  main { width: min(1400px, 92vw); }
  h1 { font-weight: 400; font-size: 44px; margin: 0 0 8px; } p { color: #9AA8BF; margin: 0 0 26px; }
  .tombol { display: flex; gap: 18px; margin-bottom: 26px; }
  button { font: inherit; padding: 20px 34px; border-radius: 16px; border: 1px solid #22314D; background: #111A2B; color: #E6EDF7; cursor: pointer; }
  button.utama { background: #38BDF8; color: #0B1220; border-color: #38BDF8; font-weight: 600; }
  pre { background: #070B14; border: 1px solid #22314D; border-radius: 14px; padding: 18px; font-size: 15px; max-height: 50vh; overflow: auto; white-space: pre-wrap; color: #C9D3E1; }
  .pesan { color: #FBBF24; min-height: 30px; }
</style></head><body><main>
<h1>Atlas berhenti berjalan</h1>
<p>Atlas gagal menyala tiga kali berturut-turut. Coba mulai ulang Atlas; bila masih gagal, mulai ulang laptop atau panggil Hong Khai.</p>
<div class="pesan">${esc(pesan)}</div>
<div class="tombol">
  <form method="post" action="/mulai-ulang-atlas"><button class="utama">Mulai ulang Atlas</button></form>
  <form method="post" action="/kembali-versi"><button>Kembali ke versi sebelumnya</button></form>
  <form method="post" action="/mulai-ulang-laptop"><button>Mulai ulang laptop</button></form>
</div>
<pre>${esc(log.teks || 'Catatan tidak terbaca.')}</pre>
</main></body></html>`;
}

createServer(async (req, res) => {
  const kirim = (kode, html) => { res.writeHead(kode, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' }); res.end(html); };
  if (req.headers.host !== `127.0.0.1:${PORT}`) return kirim(403, 'Host ditolak');
  if (req.method === 'GET' && req.url === '/') return kirim(200, await halaman());
  if (req.method === 'POST' && req.headers.origin === ASAL) {
    if (req.url === '/mulai-ulang-atlas') {
      await jalankan('systemctl', ['--user', 'reset-failed', 'atlas.service']);
      const r = await jalankan('systemctl', ['--user', 'start', 'atlas.service']);
      return kirim(200, await halaman(r.ok ? 'Atlas sedang dinyalakan… layar utama muncul sebentar lagi.' : `Gagal: ${r.teks}`));
    }
    if (req.url === '/kembali-versi') { // DESIGN §20: the previous release from /opt/atlas/releases
      const r = await jalankan('systemctl', ['--user', 'start', '--no-block', 'atlas-update-rollback.service']);
      return kirim(200, await halaman(r.ok ? 'Atlas sedang dikembalikan ke versi sebelumnya… layar utama muncul ± 1 menit lagi.' : `Gagal: ${r.teks}`));
    }
    if (req.url === '/mulai-ulang-laptop') {
      setTimeout(() => jalankan('systemctl', ['reboot']), 1000);
      return kirim(200, await halaman('Laptop dimulai ulang…'));
    }
  }
  kirim(404, 'Tidak ada');
}).listen(PORT, '127.0.0.1', () => console.log(`Halaman pemulihan Atlas di ${ASAL}`));
