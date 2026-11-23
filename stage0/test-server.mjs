// Server kecil untuk uji Tahap 0 di VirtualBox (jalan di Windows).
// Hanya mendengar di 127.0.0.1; dari dalam VM (NAT) alamatnya http://10.0.2.2:4952.
//   GET /test.sh, GET /voice-test.html  -> perlengkapan uji
//   PUT /hasil                        -> simpan hasil ke stage0/stage0-result.txt
import { createServer } from 'node:http';
import { readFile, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const DIR = dirname(fileURLToPath(import.meta.url));
const BERKAS = { '/test.sh': 'text/x-shellscript', '/voice-test.html': 'text/html; charset=utf-8' };
const BATAS = 1024 * 1024;

createServer(async (req, res) => {
  try {
    if (req.method === 'GET' && BERKAS[req.url]) {
      res.writeHead(200, { 'content-type': BERKAS[req.url] });
      return res.end(await readFile(join(DIR, req.url.slice(1))));
    }
    if (req.method === 'PUT' && req.url === '/hasil') {
      const potong = []; let n = 0;
      for await (const c of req) { n += c.length; if (n > BATAS) { res.writeHead(413); return res.end(); } potong.push(c); }
      await writeFile(join(DIR, 'stage0-result.txt'), Buffer.concat(potong));
      console.log(new Date().toLocaleTimeString(), 'hasil diterima,', n, 'byte');
      res.writeHead(200); return res.end('tersimpan\n');
    }
    res.writeHead(404); res.end();
  } catch (e) { res.writeHead(500); res.end(String(e)); }
}).listen(4952, '127.0.0.1', () => console.log('Server uji Tahap 0 di 127.0.0.1:4952 (dari VM: http://10.0.2.2:4952)'));
