# Atlas OS — Dokumen Desain

**Versi:** 1.0
**Tanggal:** 2026-11-24
**Status:**
- **Tahap 0 LULUS** di VirtualBox (§15): pengenalan suara Bahasa Indonesia jalan di Google Chrome Linux.
- **Tahap 1 SELESAI** (§16): lapisan OS `server/os/` di repo Atlas, 6 commit, sudah di-push.
- **Tahap 2 SELESAI** (§17): adaptor Linux + pengganti pembantu.exe; 276 tes Windows lulus, uji asap VM 18/18.
- **Tahap 3 SELESAI** (§18): layar utama tata letak A (dipilih Hong Khai) sebagai mode kiosk `/?kiosk=1`; 281 tes Windows lulus, diuji dengan Chrome `--kiosk` di VM.
- **Tahap 4 SELESAI** (§19): `stage4/install-atlas-os.sh` — dari Debian polos ke layar utama Atlas; diuji di VM bersih (menyala sendiri, hotkey, pemulihan, Wi-Fi API); RAM terpasang 715 MB diam, ± 780 MB saat mendengar / dengan LibreOffice.
- **Tahap 5 SELESAI** (§20): pembaruan dari GitHub dengan izin (tombol + kartu), uji jalan, cadangan data, cek kesehatan, kembali otomatis; diuji di VM termasuk versi rusak; 292 tes Windows lulus.
- **Perbaikan uji coba Hong Khai SELESAI** (§21): tombol tanpa obrolan + popup gagal, daya langsung, panel Jaringan (kabel), Mode admin.
- **Desktop baru + Pengaturan SELESAI** (§22): bar menu Atlas, notch ringkas, dok, jendela Atlas mengambang, Pengaturan 11 kategori; diuji di VM; 310 tes Windows lulus.
- **Temuan pemeriksa plugin SELESAI** (§23): 8 bug + 5 perbaikan keamanan (akun sambungan, profil Chrome dikunci, mikrofon, polkit NetworkManager, audit); diuji di VM; 319 tes.
- Berikutnya: Tahap 6 (laptop asli).
**Folder:** `C:\HISADA\atlas-os`. Proyek TERPISAH dari `C:\HISADA\atlas` dan tidak ikut repo `SiJao/atlas`.
**Repo:** `SiJao/Atlas-OS` (**publik**, keputusan Hong Khai 2026-11-23). Unduhan besar di `stage0/downloads/` tidak ikut repo.
**Hubungan:** Atlas yang sekarang dijelaskan di [../atlas/DESIGN.md](../atlas/DESIGN.md) dan [../atlas/SPEC.md](../atlas/SPEC.md). Dokumen ini hanya membahas cara Atlas berjalan sebagai "sistem operasi" di laptop kedua.

---

## 1. Tujuan

Laptop kedua dinyalakan, lalu yang muncul **langsung Atlas**, layar penuh. Tidak ada desktop Windows, tidak ada menu Start.

- Atlas menjadi satu-satunya "kulit" (shell) laptop itu.
- Akses pengguna dibatasi: yang bisa dibuka hanya yang diizinkan Atlas.
- Laptop pertama (laptop sekarang) tetap memakai Windows dan tetap menjadi tempat pengembangan Atlas.

## 2. Yang sudah diputuskan (diskusi 2026-11-23)

| Pilihan | Keputusan | Alasan |
|---|---|---|
| Atlas tanpa OS sama sekali (bare-metal) | **Ditolak** | Mustahil. Atlas butuh driver Wi-Fi, layar, suara, Node.js, dan browser. Semua itu datang dari OS. |
| Mengganti `explorer.exe` dengan Atlas di laptop sekarang | **Ditolak** | Berisiko. Laptop ini dipakai bersama, dan salah langkah bisa membuat Windows tidak bisa dipakai. |
| **Linux minimal + Atlas sebagai satu-satunya layar penuh (kiosk)** | **Disarankan** | Paling ringan, paling bisa dikunci, dan gratis. |

## 3. Perangkat target

Rencana: **Zyrex Sky 232 Mini**.

| Komponen | Nilai | Akibat |
|---|---|---|
| CPU | Celeron N4020 (sama dengan laptop sekarang) | Tetap tanpa AI lokal. Otak tetap Gemini + Claude di awan. |
| RAM | **4 GB, disolder (tidak bisa ditambah)** | Batas utama. Lihat anggaran di §5. |
| Disk | SSD M.2 256 GB | Cukup. Jauh lebih cepat dari eMMC. |
| Layar | 11,6" FHD | Tampilan Atlas harus dirancang ulang untuk layar penuh kecil (§8). |

**Diputuskan 2026-11-23: tetap Zyrex 4 GB.** Saran laptop N100/N200 8 GB tidak dipilih. Akibatnya RAM harus dijaga ketat (lihat §5.1).

## 4. Pilihan OS dasar

| Pilihan | Plus | Minus |
|---|---|---|
| **Debian 13 minimal (tanpa desktop)** — disarankan | Stabil, ringan (± 150 MB saat diam), paket lengkap, Google Chrome & Node resmi tersedia | Perlu dipasang dan diatur sendiri (akan dibuat skrip pemasang) |
| Ubuntu Server 24.04 | Dokumentasi paling banyak | Lebih berat (snap), ada hal yang tidak perlu |
| Alpine Linux | Paling kecil | Memakai musl: Google Chrome dan Claude Code bisa bermasalah |

**Diputuskan 2026-11-23: Debian 13 minimal + X11/Openbox + Google Chrome layar penuh.**

### 4.1 Lapisan tampilan (diputuskan: X11 + Openbox)

| Pilihan | Plus | Minus |
|---|---|---|
| **X11 + Openbox** — disarankan untuk tahap awal | Alat otomasi matang: `xdotool` (mouse/keyboard), `wmctrl`/`xprop` (jendela aktif). Mirip cara kerja Atlas di Windows sekarang. | Keamanan antar-aplikasi lebih lemah (aplikasi bisa membaca jendela lain). Untuk satu pengguna ini masih wajar. |
| Wayland + `cage` (kiosk satu aplikasi) | Paling terkunci, paling sederhana | Hanya bisa satu aplikasi. Aplikasi lain (browser, file) tidak bisa dibuka di atasnya. |
| Wayland + `labwc` | Modern, aman, bisa banyak jendela | Kendali mouse/keyboard dan membaca jendela aktif jauh lebih sulit (`ydotool`, dukungan terbatas) |

## 5. Anggaran RAM (perkiraan, WAJIB diukur di Tahap 0)

| Bagian | Diam | Bekerja |
|---|---|---|
| Linux dasar + X11 + Openbox | ± 200 MB | sama |
| Google Chrome kiosk (tampilan Atlas + suara) | ± 200 MB | ± 300 MB |
| Server Node Atlas | ± 50 MB | ± 70 MB |
| Claude Code | 0 | ± 255 MB per tugas |
| Chrome "browser Atlas" (CDP) | 0 | sesuai halaman |
| **Total** | **± 450 MB** | **± 900 MB – 1,2 GB** |

Dengan RAM 4 GB, sisa sekitar 2,5 GB. Ini **lebih lega** daripada Windows di laptop sekarang.

### 5.1 Aplikasi berat dengan RAM 4 GB

Laptop 2 juga akan menjalankan LibreOffice (± 250–400 MB), VS Code (± 300–500 MB), dan Chrome dengan banyak tab. Bila semuanya terbuka bersama Claude, RAM 4 GB bisa habis.

Usulan pengaman (dirinci saat Tahap 6):
- **Penjaga RAM Atlas** (sudah ada di Atlas Windows) tetap aktif dan memperingatkan saat RAM tersedia < 600 MB.
- Saat RAM menipis, tugas Claude baru **menunggu** sampai aplikasi berat ditutup (bukan menutup aplikasi sendiri).
- **zram** (swap terkompresi di RAM) dinyalakan. Ini standar di Linux ringan dan murah untuk CPU.
- Angka di atas harus diukur ulang di laptop asli.

**Penyederhanaan penting:** di Windows, Atlas butuh Chrome pendengar tersembunyi (± 105 MB) karena WebView2 tidak punya pengenalan suara. Di Linux, tampilan Atlas langsung berjalan di Google Chrome. Jadi pengenalan suara bisa dilakukan di halaman yang sama, dan Chrome pendengar tidak diperlukan lagi.

## 6. Risiko utama

1. **Pengenalan suara (Web Speech) di Linux — LULUS di Tahap 0 (2026-11-23, lihat §15).** Catatan asli sebelum uji:
   - Chromium (versi open source) di Linux **tidak** punya kunci layanan suara Google. Suara pasti gagal di sana.
   - Google Chrome resmi untuk Linux kemungkinan bisa, tetapi **belum diuji**.
   - Bila gagal, tidak ada cadangan yang layak: Whisper lokal sudah diukur terlalu lambat di N4020 (DESIGN §18).
   - Karena itu, ini diuji **pertama** di Tahap 0, sebelum laptop dibeli.
2. **Banyak bagian Atlas khusus Windows** (§7). Port-nya pekerjaan besar, bukan sekadar menyalin folder.
3. **Pemulihan saat rusak.** Bila Atlas gagal menyala, layar bisa kosong. Harus ada jalan keluar (§10).

## 7. Pemisahan: inti bersama vs lapisan OS

Atlas dibagi menjadi dua bagian:

- **Inti bersama** — kode yang sama persis di Windows dan Linux.
- **Lapisan OS** — satu adaptor per OS, di `server/os/windows.js` dan `server/os/linux.js`, dengan antarmuka yang sama.

Inti tidak boleh lagi memanggil `powershell.exe`, `pembantu.exe`, atau path `C:\` secara langsung. Semua lewat adaptor.

### 7.1 Inti bersama (tidak berubah)

`percakapan`, `otak`, `router` (polanya), `registri`, `pengaman`, `kebijakan`, `sensitif`, `audit`, `memori`, `graf`, `pengingat`, `pemicu`, `alur`, `rencana`, `pemeriksa`, `notifikasi`, `kabar`, `sumberdaya`, `google`, `kontak`, `kebiasaan`, `dokumen`, `riset`, `suara`, `penyimpanan`, `pengaturan`, serta seluruh `web/`.

### 7.2 Lapisan OS (perlu versi Linux)

| Fungsi | Windows sekarang | Linux (usulan) |
|---|---|---|
| Jendela & tampilan | `pembantu.exe` + WebView2, notch, orb | Google Chrome `--kiosk` layar penuh, dijalankan oleh Openbox (*sejak §22.3: desktop + jendela Atlas, tanpa `--kiosk`*) |
| Hotkey global | `pembantu.exe` (Ctrl+Alt+Space) | Keybind Openbox → `curl` ke server lokal |
| Jendela aktif, waktu diam | `pembantu.exe` (JENDELA, DIAM) | `xdotool getactivewindow` / `xprintidle` |
| Daya baterai | `pembantu.exe` (DAYA) | `/sys/class/power_supply/` |
| Mouse/keyboard | `SendInput` (`input.cs`) | `xdotool` |
| Membaca isi aplikasi (UIA) | UI Automation | AT-SPI (lebih terbatas). Bila tidak cukup: tangkapan layar + Gemini, dengan penjaga yang sama. |
| Perintah sistem | PowerShell | `bash` |
| Volume / kecerahan / kunci layar | PowerShell + API Windows | `wpctl` / `brightnessctl` / pengunci X11 |
| Buka & tutup aplikasi | `Start-Process`, `Stop-Process` | Daftar aplikasi yang diizinkan (§9), `pkill` |
| Kunci rahasia | DPAPI (`rahasia.dpapi`) | `systemd-creds` (pakai TPM bila ada) atau file terenkripsi yang hanya bisa dibaca pengguna `atlas` |
| Undo hapus file | Recycle Bin (`$I`) | Tempat Sampah standar freedesktop (`gio trash`) |
| Larangan admin untuk Claude | Blok `RunAs`, `gsudo`, `psexec` | Blok `sudo`, `su`, `pkexec`, `doas` |
| Proses terlindung | `explorer`, `dwm`, `svchost`, ... | `Xorg`, `openbox`, `systemd`, `chrome` kiosk, `node` |
| Autostart | `Atlas.lnk` + `baki.exe` | Layanan `systemd` + login otomatis ke sesi Atlas |
| Folder proyek | `C:\HISADA` | `/home/atlas/proyek` |
| Skrip `.cmd` | `mulai.cmd`, `berhenti.cmd` | `systemctl --user start/stop atlas` |

### 7.3 Tes

- Tes yang menyentuh lapisan OS diberi penanda platform. Tes Windows hanya berjalan di Windows, dan tes Linux hanya berjalan di Linux.
- Inti bersama diuji di kedua OS.
- Syarat Tahap 1: semua 259 tes di Windows tetap lulus tanpa perubahan perilaku.

## 8. Tampilan layar penuh [TANYA]

Notch dan orb dibuat untuk "menumpang" di atas Windows. Di Atlas OS, Atlas adalah layarnya sendiri, jadi tampilannya perlu dirancang baru:

- layar utama: orb besar di tengah, jam, cuaca, pengingat hari ini, status;
- panel percakapan;
- peluncur untuk aplikasi yang diizinkan (§9);
- tombol daya (matikan, mulai ulang).

Akan dibuat **prototipe di Chrome dulu**, lalu dipilih Hong Khai sebelum dipasang (seperti §19 dan §22).

## 9. Batasan akses

Daftar aplikasi dan pagar diputuskan 2026-11-23. Poin lain masih usulan:

1. Laptop masuk otomatis ke akun **`atlas`** yang **tidak punya `sudo`**.
2. Aplikasi yang bisa dibuka hanya yang ada di **daftar izin** (diatur di `data/pengaturan.json`). Daftar awal yang dipilih:
   - **Browser:** Google Chrome.
   - **Dokumen:** LibreOffice (Writer, Calc, Impress), pengganti Microsoft Office.
   - **Media & PDF:** pemutar video/musik (mpv), penampil PDF dan gambar.
   - **Kode:** VS Code.
   - Pengelola berkas (untuk membuka/menyimpan file) ikut dibutuhkan oleh aplikasi di atas.
3. Aplikasi yang dibuka muncul di atas Atlas. Saat ditutup, layar kembali ke Atlas.
4. Pekerjaan sistem (update, matikan, mulai ulang) dilakukan oleh **satu skrip pembantu kecil milik root dengan perintah tetap**. Claude tidak bisa menjalankan perintah root bebas.
5. **Pagar Claude MENYALA di laptop 2** (diputuskan 2026-11-23). Claude hanya boleh menulis di folder kerja dan tidak bisa menjadi admin. Ini berbeda dengan laptop 1, yang pagarnya dimatikan, karena laptop 2 tidak dipantau setiap saat.
6. **Usulan perbaikan diri (§14 V) dimatikan** di laptop 2. Perubahan kode hanya datang dari laptop 1.

## 10. Pemulihan dan jalan keluar

- `systemd` menyalakan ulang Atlas bila mati. Bila gagal 3 kali dalam 2 menit, muncul **layar pemulihan** sederhana: pesan galat, tombol "kembali ke versi sebelumnya", dan tombol "mulai ulang".
- **Pintu perawatan:** `Ctrl+Alt+F2` membuka terminal teks. Login memakai akun admin terpisah dengan sandi yang hanya dipegang Hong Khai.
- Tidak ada desktop cadangan yang bisa dibuka tanpa sandi.

## 11. Alur update (laptop 1 → laptop 2)

```
Laptop 1 (Windows, pengembangan)
   │ commit + tes lulus + push
   ▼
GitHub SiJao/atlas (private)
   │ laptop 2 menarik dengan deploy key HANYA-BACA
   ▼
Laptop 2 (Atlas OS)
   1. git fetch → periksa ada commit baru
   2. salin ke folder rilis baru: /opt/atlas/rilis/<commit>
   3. jalankan tes di folder baru
   4. bila lulus: tautan "sekarang" dipindah ke rilis baru, layanan dinyalakan ulang
   5. periksa kesehatan 60 detik ("periksa atlas")
   6. bila gagal: tautan dikembalikan ke rilis lama (rollback otomatis)
```

- **`data/` tidak pernah disentuh update.** Data berada di luar folder rilis, di `/home/atlas/atlas-data`.
- Disimpan 3 rilis terakhir untuk rollback.
- **Mode update: `tanya`** (diputuskan 2026-11-23). Atlas memberi tahu "ada versi baru" dan menunggu jawaban ya. Mode `otomatis` dan `manual` tetap tersedia lewat pengaturan.
- Deploy key hanya-baca berarti laptop 2 tidak bisa mengubah repo, walaupun dibobol.

## 12. Tahapan rencana

| Tahap | Isi | Butuh laptop 2? |
|---|---|---|
| **0. Uji kelayakan** | Boot Debian live USB di laptop SEKARANG, tanpa memasang apa pun ke disk. Uji: Google Chrome + Web Speech Bahasa Indonesia, Gemini TTS, ukur RAM. **Bila suara gagal, berhenti dan putuskan ulang.** | Tidak |
| **1. Pisah inti & lapisan OS** | Buat `server/os/windows.js`. Pindahkan semua panggilan Windows ke sana. Perilaku tidak berubah, 259 tes tetap lulus. | Tidak |
| **2. Adaptor Linux** | Buat `server/os/linux.js` beserta tesnya | Tidak (diuji di USB live atau WSL) |
| **3. Tampilan layar penuh** | Prototipe Chrome → dipilih → dipasang | Tidak |
| **4. Skrip pemasang** | Satu skrip: dari Debian minimal sampai Atlas OS siap (akun, Openbox, Chrome, Node, Claude Code, systemd, pemulihan) | Ya, atau USB/VM |
| **5. Alur update** | Deploy key, rilis, tes, rollback, mode update | Ya |
| **6. Pengamanan & uji coba** | Daftar izin aplikasi, skrip root tetap, pintu perawatan, uji pakai harian | Ya |

Setiap tahap: rancang → disetujui → kerjakan → tes → commit, sesuai aturan kerja biasa.

## 13. Plus dan minus Atlas OS secara keseluruhan

**Plus**
- Laptop 2 terasa "milik Atlas": menyala langsung ke asisten.
- Lebih ringan dari Windows: sekitar 2,5 GB RAM bebas dari total 4 GB.
- Bisa dikunci jauh lebih rapat daripada Windows.
- Pemisahan inti/OS juga membuat kode Atlas di Windows lebih rapi.

**Minus**
- Pekerjaan port besar (§7.2). Beberapa fitur akan lebih lemah di Linux, terutama membaca isi aplikasi (AT-SPI lebih terbatas daripada UIA).
- Dua OS harus dirawat dan diuji terus.
- Aplikasi khusus Windows (misalnya Microsoft Office) tidak bisa dipakai di laptop 2. Dokumen Office hanya bisa dibaca Atlas atau dibuka dengan LibreOffice.
- Risiko terbesar (suara) belum pasti sampai Tahap 0 selesai.

## 14. Keputusan Hong Khai (2026-11-23)

| No | Pertanyaan | Jawaban |
|---|---|---|
| 1 | Laptop kedua (§3) | **Zyrex Sky 232 Mini, 4 GB** |
| 2 | OS dasar (§4) | **Debian 13 minimal + X11/Openbox + Google Chrome layar penuh** |
| 3 | Aplikasi yang diizinkan (§9) | **Chrome, LibreOffice, media & PDF, VS Code** |
| 4 | Pagar Claude di laptop 2 (§9) | **Menyala** |
| 5 | Mode update (§11) | **Tanya dulu** |
| 6 | Mulai Tahap 0 (§12) | **Ya**, tetapi menunggu flashdisk ≥ 8 GB. Perlengkapan siap di `stage0/` (lihat `stage0/STEPS.md`). |

Masih terbuka: tampilan layar penuh (§8). Akan dibuat sebagai prototipe Chrome untuk dipilih.

## 15. Hasil Tahap 0 (2026-11-23)

Diuji di **VirtualBox 7.2.22** di laptop sekarang (belum ada flashdisk). VM: Debian 13.8 live LXDE, kernel 6.12, RAM 3 GB, 2 core Celeron N4020. Google Chrome 158 dipasang hanya di RAM. Data lengkap: `stage0/stage0-result.txt`.

| Uji | Hasil |
|---|---|
| Pengeras suara | **OK** |
| Mikrofon | **OK** (level penuh) |
| Web Speech `id-ID` di Google Chrome Linux | **OK**: tidak ada galat. Teks pertama muncul 2,1 detik setelah mulai mendengar. |
| Transkrip | "atlas buka **peringatan** hari ini" (diucapkan: "pengingat"). Kata panggil "Atlas" dikenali. Satu kata keliru, sama seperti kebiasaan Web Speech di Windows. |

**Kesimpulan: risiko terbesar (§6 no. 1) gugur. Rancangan Atlas OS boleh lanjut.**

### 15.1 RAM — lebih besar dari perkiraan, perlu diukur ulang

| Saat | RAM terpakai (dari 3 GB) | Chrome |
|---|---|---|
| Desktop LXDE saja | 656 MB | — |
| Halaman uji terbuka | 1442 MB | 141 MB |
| Setelah mikrofon + pengenalan suara | 2008 MB | **520 MB** |

Angka ini **lebih tinggi** dari perkiraan §5 (± 200 MB untuk dasar dan ± 300 MB untuk Chrome). Sebagian kemungkinan karena keadaan uji, bukan sifat Atlas OS:
- Sistem live menyimpan semua yang dipasang (termasuk Chrome ± 400 MB) di RAM. Di sistem terpasang, semua itu ada di SSD.
- Desktop LXDE live menjalankan panel, pengelola jaringan, dan layanan lain yang tidak dipakai Atlas OS (Openbox saja).
- Di VM tidak ada GPU, jadi Chrome menggambar dengan perangkat lunak (SwiftShader). Cara ini memakan RAM lebih banyak daripada Intel UHD 600 asli.

Tindakan:
- Perkiraan §5 dianggap **belum pasti**. Angka yang benar diukur di **Tahap 4** (Debian terpasang, Openbox saja, di laptop asli atau VM berdisk).
- Bila Chrome tetap ± 500 MB saat mendengar, pengaman §5.1 menjadi **wajib**, bukan sekadar usulan.

## 16. Desain Tahap 1 — memisahkan inti & lapisan OS

**Disetujui 2026-11-23:**
- cara **A** (fasad);
- catatan **hanya** di dokumen ini (Atlas DESIGN.md tidak disentuh);
- **commit per langkah, push di akhir**.

**Tempat kerja:** repo Atlas (`C:\HISADA\atlas`, `SiJao/atlas`), karena kodenya ada di sana.
**Syarat lulus:** perilaku Atlas di Windows **tidak berubah sama sekali**, semua tes lama lulus, dan ada satu tes baru "pagar arsitektur" (§16.4).
**Linux belum disentuh** di tahap ini. `server/os/linux.js` baru dibuat di Tahap 2.

### 16.1 Hasil pendataan (2026-11-23)

Hal khusus Windows tersebar di **17 file server**:

| Kelompok | Tempat sekarang | Isi khusus Windows |
|---|---|---|
| Menjalankan skrip | `alat.js`, `alat-sistem.js`, `rahasia.js` | tiga salinan pemanggil `powershell.exe` |
| Info sistem | `alat.js` | CPU/baterai/disk lewat `Get-CimInstance` |
| Proses | `alat-sistem.js`, `kebiasaan.js`, `aktivitas.js` | daftar proses (`Get-Process`), tutup proses, daftar proses terlindung Windows |
| Volume, kecerahan, kunci layar | `alat-sistem.js` | PowerShell + WMI |
| Buka aplikasi/file/folder | `alat.js`, `router.js` | `explorer.exe`, path `Program Files`, Start Menu, nama aplikasi Windows |
| Tempat sampah | `alat.js`, `urungkan.js` | Recycle Bin (`VisualBasic.FileIO`, file `$I`) |
| Kunci rahasia | `rahasia.js`, `periksa.js` | DPAPI |
| Jendela, hotkey, UIA, mouse/keyboard | `jendela.js`, `kendali.js`, `komputer.js`, `index.js`, `periksa.js` | `pembantu.exe`, WebView2, path `chrome.exe` |
| Claude | `claude.js` | pola perintah berisiko PowerShell/registry, larangan `RunAs`, `taskkill`, `claude.exe`, folder sistem Windows |
| Path tetap | `alat.js`, `pengaman.js`, `pengaturan.js`, `proyek.js`, `index.js` | `C:\HISADA`, `Documents\Atlas`, `SystemRoot`/`ProgramFiles` |
| Teks prompt | `otak.js`, `percakapan.js` | kata "Windows", "PowerShell", contoh path `C:\...` |

### 16.2 Bentuk adaptor

```
server/os/index.js     → memilih adaptor menurut process.platform (sekarang hanya Windows)
server/os/windows.js   → semua yang khusus Windows, satu antarmuka
server/os/linux.js     → (Tahap 2)
```

Antarmuka (objek `platform` dari `os/index.js`). Nama-namanya dalam bahasa Inggris sesuai keputusan 2026-11-23. Inilah yang dibuat; usulan awal di draf memakai nama Indonesia.

| Bagian | Isi (Windows) |
|---|---|
| `name`, `label`, `shellName`, `helperName`, `startCommand` | `'windows'`, `'Windows'`, `'PowerShell'`, `'pembantu.exe'`, `'mulai.cmd'` (untuk teks prompt dan pesan) |
| `run`, `runDetached`, `runScript`, `quote` | satu-satunya pemanggil `powershell.exe` dan program lain |
| `projectRoots`, `workFolder`, `appDataFolder`, `systemFolders()`, `pathHintForAI` | `C:\HISADA`, `Documents\Atlas`, `AppData`, folder sistem, petunjuk jalur untuk Gemini |
| `systemInfo(want)` | cpu, baterai, disk, proses, jaringan |
| `topProcesses()`, `listProcesses()`, `closeProcesses(ids, force)`, `protectedProcesses`, `processAliases`, `shellProcesses` | |
| `volume(aksi, persen)`, `brightness(persen)`, `lockScreen()`, `power(aksi)` | |
| `openApp(nama)`, `openDefault(target)`, `openFolder(p)`, `executableExtensions` | |
| `trashName`, `moveToTrash(p, isDir)`, `findInTrash(asal)` | Recycle Bin |
| `secretProtector` | `{ protect, unprotect }` (DPAPI) |
| `riskyCommands`, `adminPattern`, `claudeAdminHint`, `claudeExecutable`, `killTree(child)` | bagian Claude |
| `WindowHelper`, `openChromeApp`, `openListener`, `findChrome` | membungkus `jendela.js` (pembantu.exe, Chrome) |

### 16.3 Cara memindahkan (disarankan: cara A)

| Cara | Plus | Minus |
|---|---|---|
| **A. Fasad dulu** — kode khusus Windows dipindah ke `os/windows.js`, sedangkan `jendela.js` dan `pembantu/` tetap di tempatnya dan hanya dibungkus | Perubahan kecil dan mudah ditinjau. Risiko merusak Atlas yang sudah jalan paling kecil. | `jendela.js` masih berupa file khusus Windows di luar folder `os/` (diberi tanda jelas). |
| B. Pindah total — `jendela.js`, `kendali`, `komputer` ikut masuk `os/windows/` | Struktur paling rapi | Perubahan besar, banyak tes harus ikut diubah, risiko lebih tinggi |

Urutan kerja cara A, dengan tes dijalankan setelah setiap langkah:
1. `os/windows.js` + `os/index.js`: pindahkan pemanggil PowerShell, lalu `alat.js`, `alat-sistem.js`, dan `rahasia.js` memakainya.
2. Info sistem, proses, volume/kecerahan/kunci layar.
3. Buka aplikasi/jalur dan tempat sampah (`alat.js`, `urungkan.js`).
4. Bagian Claude (`claude.js`).
5. Path tetap dan teks prompt.
6. `index.js` mengambil pembantu dan Chrome lewat adaptor.
7. Tes pagar arsitektur, lalu pembaruan SPEC.md Atlas.

### 16.4 Tes pagar arsitektur

Tes baru `tests/os-boundary.test.mjs` membaca semua file inti (komentar diabaikan). Tes ini **gagal** bila ada file di luar `server/os/` dan `jendela.js` yang memuat salah satu dari:
- `powershell.exe`, `pembantu.exe`, `explorer.exe`, `rundll32`, `taskkill`, `shutdown.exe`;
- `ProtectedData`, `$Recycle.Bin`, `Get-CimInstance`, `Get-Process`, `Stop-Process`;
- `C:\\HISADA`, `'Documents', 'Atlas'`, `process.platform === 'win32'`.

Tes ini juga memastikan dua hal lain: inti tidak meng-import `os/windows.js` secara langsung, dan adaptor Windows punya semua fungsi antarmuka.

Tujuannya: kode Windows baru tidak bisa diam-diam masuk lagi ke inti. Saat pertama dijalankan, tes ini langsung menemukan 3 sisa (pesan galat dengan `pembantu.exe` di `kendali.js`, `komputer.js`, `periksa.js`), dan ketiganya sudah dipindah.

### 16.5 Hasil (selesai 2026-11-23)

- **6 commit** di `SiJao/atlas` (`9e73511` → `129e511`), sudah di-push dan dicek lewat GitHub API. Urutan aslinya sedikit dirapatkan dari rencana 7 langkah:
  1. adaptor + `alat`/`alat-sistem`/`rahasia`;
  2. `urungkan` + `kebiasaan`;
  3. `claude`;
  4. path & teks;
  5. `index` + `peramban`;
  6. tes pagar.
- **Tes:** 262 (259 lama + 3 pagar). 261 lulus. `tutup_aplikasi` tetap kena batas 30 detik karena PowerShell lambat menyala di Celeron. Kegagalan ini sama persis dengan patokan sebelum ada perubahan, dan tes itu lulus dengan batas 180 detik (40 detik).
- Teks yang dikirim ke Gemini/Claude di Windows **sama persis** dengan sebelumnya, karena dirakit dari `platform.label`, `shellName`, dan seterusnya.
- **SPEC.md dan DESIGN.md Atlas tidak disentuh**, sesuai keputusan "catatan hanya di atlas-os".
- Atlas yang sedang berjalan baru memakai kode ini setelah `berhenti.cmd` + `mulai.cmd`.

**Masih khusus Windows untuk Tahap 2:**
- `jendela.js` + `pembantu/` (jendela, hotkey, UIA, mouse/keyboard), lewat `WindowHelper`;
- baris perangkat keras di prompt Claude ("Celeron 2 core, RAM 7,8 GB");
- deskripsi `kunci_layar` ("Windows+L");
- kata "UI Automation Windows" di `kendali.js`;
- `aktivitas.js` yang mengenali jendela Atlas dari nama proses `chrome|pembantu`.

### 16.6 Plus / minus Tahap 1

- **Plus:** kode Atlas lebih rapi. Sebagian besar hal yang khusus Windows ada di satu tempat, jadi port Linux tinggal mengisi satu file adaptor. Ada tiga salinan pemanggil PowerShell yang menjadi satu.
- **Minus:** sekitar 17 file berubah sekaligus, padahal belum ada fitur baru yang terlihat. Atlas yang sedang berjalan baru memakai kode ini setelah `berhenti.cmd` + `mulai.cmd`.

## 17. Desain Tahap 2 — adaptor Linux

**Disetujui 2026-11-23:**
- kunci rahasia: **systemd-creds** (17.4 no. 1a);
- kontrol aplikasi: **AT-SPI dikerjakan sekarang** (17.4 no. 2b);
- uji di **VM berdisk baru**;
- **commit per langkah, push di akhir**.

**Tempat kerja:** repo Atlas, file baru `server/os/linux.js` (+ `server/os/linux-helper.js`). Antarmuka sama persis dengan `windows.js` (§16.2). `os/index.js` memilihnya bila `process.platform === 'linux'`.
**Syarat lulus:**
- perilaku Atlas di Windows **tidak berubah**;
- tes lama lulus;
- tes baru untuk `linux.js` lulus di Windows, dengan perintah Linux dipalsukan;
- uji asap di VM Debian: server Atlas menyala dan alat-alat dasar jalan.

### 17.1 Pemetaan fungsi

| Antarmuka | Linux (usulan) |
|---|---|
| `run`, `runDetached`, `runScript` | `execFile`; skrip lewat `bash -c` |
| `systemInfo` | CPU dari `/proc/stat`, baterai dari `/sys/class/power_supply`, disk dari `df`, proses dari `ps`, jaringan dari `/sys/class/net` |
| `topProcesses`, `listProcesses`, `closeProcesses` | `ps -eo pid,comm,rss`; tutup = `SIGTERM`, paksa = `SIGKILL` |
| `protectedProcesses`, `shellProcesses` | `systemd`, `Xorg`, `openbox`, `dbus-daemon`, `pipewire`, `node`, `claude`, Chrome kiosk Atlas, … |
| `volume` | `wpctl` (PipeWire) |
| `brightness` | `brightnessctl` (akun `atlas` masuk grup `video`) |
| `lockScreen` | `xset s activate` / pengunci layar ringan (dipilih di Tahap 4) |
| `power` | `systemctl poweroff/reboot/suspend` (logind mengizinkan pengguna lokal yang aktif tanpa sudo). Jeda 60 detik dan "batal" diatur oleh timer Atlas sendiri. |
| `openApp` | hanya dari **daftar aplikasi izin** (`pengaturan.aplikasiOS`): nama → perintah (`google-chrome`, `libreoffice --writer`, `mpv`, `code`, …) |
| `openDefault`, `openFolder` | `xdg-open` |
| `moveToTrash`, `findInTrash` | `gio trash`; cari di `~/.local/share/Trash/info/*.trashinfo` |
| `secretProtector` | `systemd-creds --user encrypt/decrypt` (disetujui) |
| `riskyCommands`, `adminPattern` | pola bash: `rm`, `systemctl`, `apt`, `chmod/chown`, `crontab`, `iptables/nmcli`, `curl \| sh`, `git push`, …; naik hak: `sudo`, `su`, `pkexec`, `doas` |
| `claudeExecutable`, `killTree` | `~/.local/bin/claude`; bunuh grup proses (`process.kill(-pid)`) |
| `projectRoots`, `workFolder` | `~/proyek`, `~/Documents/Atlas` |
| `WindowHelper` | `linux-helper.js` (§17.2) |
| `openChromeApp`, `findChrome` | `google-chrome --kiosk` (Atlas OS) atau `--app` (desktop biasa) (*sejak §22.3: `--app=…/?window=1` tanpa `--kiosk`*) |

### 17.2 Pengganti pembantu.exe

`pembantu.exe` (C#) tidak bisa jalan di Linux. Penggantinya adalah kelas Node `linux-helper.js`. Kelas ini memancarkan **event yang sama** sehingga `index.js` tidak perlu tahu bedanya:

| Event / fungsi | Cara di Linux |
|---|---|
| `jendela` (jendela aktif berganti) | `xdotool getactivewindow getwindowname` + `/proc/<pid>/comm`, dicek tiap 2 detik |
| `diam` (detik tanpa sentuhan) | `xprintidle`, tiap 15 detik |
| `daya` (charger, persen) | `/sys/class/power_supply`, tiap 60 detik |
| `hotkey` (Ctrl+Alt+Space) | Keybind Openbox menulis `HOTKEY` ke FIFO `$XDG_RUNTIME_DIR/atlas-hotkey`. Helper membaca FIFO itu, jadi tidak ada pintu HTTP baru. |
| `native` | selalu `false`: tampilan = Chrome, pengenalan suara langsung di halaman (sudah didukung `app.js`), tanpa Chrome pendengar |
| `atur(popup/max)` | tidak ada (kiosk selalu layar penuh) |
| `bunyi()` | `paplay` / `pw-play` suara sistem |
| `uia`: `depan`, `klik`, `ketik`, `tombol`, `gulir`, `layar`, `kendali-mulai/selesai` | `xdotool` + tangkapan layar (`import` dari ImageMagick atau `scrot`). Tombol darurat: gerakan mouse fisik dideteksi dari perubahan posisi `xdotool getmouselocation`. |
| `uia`: `daftar`, `tekan`, `isi` (kontrol aplikasi) | AT-SPI lewat skrip Python `server/os/linux-atspi.py` (disetujui) |

### 17.3 Cara menguji

1. **Di Windows (setiap commit):** tes `linux.test.mjs` memanggil `linux.js` dengan `run` palsu (keluaran `ps`, `wpctl`, `.trashinfo` contoh). Logika parsing teruji tanpa Linux.
2. **Di VM AtlasOS-Test (akhir tahap):** Debian live + Node 24 + salinan Atlas dari server uji. Yang diuji: server menyala, `info_pc`, volume, buka/tutup aplikasi, tempat sampah + undo, kunci rahasia, hotkey FIFO.
   - Kunci asli tidak pernah dikirim ke VM: `data/` diisi kunci palsu.
   - **[TANYA 3]**: VM live hilang saat dimatikan. Untuk Tahap 2–4 lebih praktis memakai VM **berdisk** (Debian terpasang, ± 10 GB file di disk laptop).

### 17.4 Pertanyaan

1. **Kunci rahasia di Linux:**
   - (a) `systemd-creds --user`: kunci dipegang sistem dan hanya akun itu yang bisa membuka; padanan terdekat DPAPI. Disarankan, diuji dulu di VM.
   - (b) file terenkripsi + kunci di `~/.config/atlas` (izin 600): sederhana, tetapi siapa pun yang login sebagai `atlas` bisa membacanya.
2. **Kontrol aplikasi** (`aplikasi_tekan` / `aplikasi_isi`):
   - (a) belum tersedia di Linux pada Tahap 2: Atlas menjawab "belum didukung" dan menyarankan kendali mouse/keyboard. Disarankan; AT-SPI dikerjakan di Tahap 6.
   - (b) dikerjakan sekarang lewat AT-SPI (skrip Python): lebih lama, hasilnya kurang andal di LibreOffice dan Chrome.
3. **VM untuk uji:** tetap live, atau buat VM berdisk baru?
4. **Commit & push:** sama seperti Tahap 1 (per langkah, push di akhir)?

### 17.5 Hasil (selesai 2026-11-23)

- **3 commit** di `SiJao/atlas` (`6a4d8a8` → `53e1c49`), sudah di-push dan dicek lewat GitHub API:
  1. `linux-helper.js` + `linux-atspi.py` (pengganti pembantu.exe);
  2. `linux.js` + `os/index.js` (memuat adaptor sesuai OS, hanya satu yang dimuat);
  3. daftar aplikasi kendali & nama tempat sampah dari adaptor.
- **Tes Windows:** 276/276 lulus (termasuk 17 tes baru `linux.test.mjs`).
- **VM uji `AtlasOS-Disk`:** Debian 13.8 terpasang otomatis lewat `VBoxManage unattended install`, dikendalikan lewat SSH (kunci di `vm/`, tidak ikut repo). Disiapkan dengan `stage2/provision-vm.sh`.
- **Uji asap dengan program Linux sungguhan** (`stage2/smoke-test.sh` + `stage2/real-check.mjs`, data palsu tanpa kunci asli): **18/18 lulus**, dan server Atlas menyala di Linux (`GET /` OK, RAM VM ± 620 MB terpakai).
  - Lulus: info laptop, proses, volume (wpctl), kecerahan (VM tanpa backlight → pesan jelas), tempat sampah + pemulihan, **systemd-creds --user**, pengaman Claude, buka "excel" → LibreOffice Calc, jendela aktif/diam/daya, **hotkey FIFO**, AT-SPI depan (88 elemen) / daftar (94 kontrol) / isi (kolom "Find" di Find & Replace), tangkapan layar, klik/tombol/ketik/gulir, tutup proses.
  - Tidak ada proses yang tertinggal setelah uji.

**Masalah yang ditemukan uji VM dan sudah diperbaiki:**
1. Penelusuran AT-SPI macet di lembar Calc (± 17 miliar sel). Wadah dengan > 300 anak atau `MANAGES_DESCENDANTS` kini dilewati.
2. `xdotool mousemove --sync` gagal di sebagian server X. Diganti jeda 40 ms.
3. Pembaca FIFO hotkey berupa `sh`/`cat` bisa tertinggal saat Atlas mati, lalu "mencuri" hotkey. Kini FIFO dibaca langsung oleh Node (`O_RDWR|O_NONBLOCK` + `net.Socket`).
4. AT-SPI yang macet menahan proses Python. Kini Python dimatikan saat batas waktu habis dan dinyalakan ulang.
5. Aplikasi yang baru dibuka terlambat mendaftar ke AT-SPI. Kini dicoba ulang 3× tiap 1 detik.
6. Kolom tanpa nama (LibreOffice) kini memakai nama labelnya (`LABELLED_BY`). Combo box diisi lewat kolom teks di dalamnya.

**Catatan untuk Tahap 4 (pemasang):**
- Akun `atlas` harus masuk grup `audio` (dan `video` untuk kecerahan). PipeWire memakai kartu suara hanya dalam sesi seat aktif. Login otomatis di layar memenuhi syarat ini; SSH tidak.
- Pemasangan otomatis VirtualBox ikut memasang GNOME (± 500 MB RAM). gdm sudah dimatikan di VM uji. Atlas OS asli **tidak** memasang desktop apa pun.
- Variabel aksesibilitas untuk sesi X: `GTK_MODULES=gail:atk-bridge`, `SAL_USE_VCLPLUGIN=gtk3`, `QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1`. Chrome pengguna membutuhkan `--force-renderer-accessibility` (belum ditambahkan ke daftar aplikasi; dikerjakan di Tahap 4).

**Belum teruji (butuh laptop asli, Tahap 6):**
- tombol darurat dengan mouse/keyboard *fisik* (Xvfb tidak punya perangkat fisik; logika pemilahan XTEST sudah teruji di tes unit);
- kecerahan sungguhan;
- suara keluar ke speaker asli.

## 18. Tahap 3 — layar utama layar penuh

### 18.1 Prototipe & pilihan (2026-11-23)

Prototipe: `stage3/home-prototype.html`. Tiga tata letak dengan orb asli Atlas (`web/orb.js`), dirancang untuk layar 1920×1080. Tangkapan layarnya ada di `stage3/shots/`.

| Tata letak | Isi |
|---|---|
| **A · Pusat — DIPILIH Hong Khai** | Orb besar di tengah; jam + tanggal kiri atas; status (online, baterai, RAM) + tombol daya kanan atas; kartu "Hari ini" (pengingat/acara) di kiri; percakapan di kanan; dok 8 aplikasi izin di bawah |
| B · Panel | kolom info di kiri; orb, percakapan, dan kolom ketik di kanan |
| C · Tenang | hanya orb, jam, satu baris status; aplikasi di laci bawah |

Keadaan orb yang sudah ada dipakai apa adanya:
- diam;
- mendengar (cincin mengikuti suara);
- berpikir (emas cepat);
- Claude bekerja (ungu);
- berbicara;
- kendali (merah).

### 18.2 Rencana pemasangan (disetujui 2026-11-23: mode kiosk di halaman lama + kolom ketik di bawah percakapan)

- **Mode kiosk di halaman Atlas yang sudah ada** (`web/index.html` + `app.js` + `gaya.css`), bukan halaman baru. Aktif bila alamatnya `/?kiosk=1`; `openChromeApp` di Linux memakai alamat itu saat `ATLAS_KIOSK=1`. Semua logika lama (mikrofon, suara, kartu izin, SSE, percakapan, orb) dipakai ulang. **Tampilan Windows (notch) tidak berubah.**
- Isi layar diambil dari API yang sudah ada:
  - jam: lokal;
  - "Hari ini": `/api/pengingat` + `/api/acara`;
  - status: `/api/laptop` + SSE `sumberdaya`;
  - percakapan: SSE `pesan`.
- **Dok aplikasi:** satu klik mengirim "buka <aplikasi>" lewat router lokal (tanpa Gemini, tanpa kuota). Daftar dok = daftar aplikasi izin Linux (§9).
- **Menu daya:** tidurkan / mulai ulang / matikan (60 dtk, bisa dibatalkan) / batal, lewat alat `daya_pc` yang sudah ada.
- **Kolom ketik:** di bagian bawah kartu percakapan kanan (disetujui), karena keyboard adalah jalan masuk kedua selain suara.
- **Tes:** tes baru memastikan `?kiosk=1` memuat tata letak A dan halaman biasa tidak berubah. Uji di VM AtlasOS-Disk dengan Chrome `--kiosk` sungguhan, ditambah tangkapan layar.

### 18.3 Hasil (selesai 2026-11-24)

- **3 commit** di `SiJao/atlas` (`3070c20` → `3995c4b`), sudah di-push dan dicek lewat GitHub API:
  1. router lokal untuk dok & menu daya, `/api/laptop` membawa data baterai;
  2. mode kiosk `/?kiosk=1` dengan tata letak A di `web/` (index.html, gaya.css, app.js);
  3. Chrome kiosk Linux membuka `/?kiosk=1`, boleh bersuara tanpa klik, tanpa pop-up Translate.
- **Tes Windows:** 281/281 lulus (5 tes baru `kiosk.test.mjs`). Tanpa `?kiosk=1`, tampilan notch Windows tidak berubah.
- **Uji di VM** (`stage3/kiosk-check.sh`: server Atlas + Chrome `--kiosk` sungguhan di layar X, tangkapan layar `stage3/shots/vm-kiosk.png`):
  - jam, tanggal, "Hari ini" (2 pengingat yang dibuat lewat API), Online, baterai ⚡ 100 %, RAM, orb, status, percakapan, kolom ketik, dok 8 aplikasi: **semua tampil**;
  - tombol dok "Lembar kerja" → router lokal → LibreOffice Calc terbuka, Atlas menjawab "Lembar kerja dibuka." **tanpa Gemini**;
  - Chrome kiosk ± **587 MB** (PSS, VM tanpa GPU), sesuai temuan Tahap 0. RAM VM total terpakai ± 860 MB–1,2 GB.
- **Diperbaiki dari uji:** pop-up Google Translate (kini `--disable-features=Translate` + meta `notranslate`), teks peringatan kunci yang menyebut path Windows, label dok terpotong (font Linux lebih lebar).

**Belum (Tahap 4 ke atas):**
- menu daya baru teruji lewat router, belum diklik sungguhan di laptop asli;
- kalender Google belum muncul di "Hari ini" (menunggu akun Google pulih);
- suara keluar dan mikrofon di kiosk baru teruji di Tahap 0, belum bersama layar ini.

## 19. Tahap 4 — skrip pemasang Atlas OS (SELESAI)

**Disetujui 2026-11-24:**
- Wi-Fi lewat **panel Wi-Fi di layar Atlas** (19.6 no. 1a);
- kode lewat **deploy key hanya-baca** yang dipasang lewat API (no. 2a);
- uji di **VM baru bersih** AtlasOS-Install (no. 3a).

**Tujuan:** dari **Debian 13 netinst polos** (tanpa desktop) sampai laptop menyala langsung ke layar utama Atlas, dengan **satu skrip** `install-atlas-os.sh` yang dijalankan sekali sebagai root. Sekaligus **mengukur RAM sistem terpasang** (angka §5 yang masih perkiraan).

### 19.1 Akun

| Akun | Guna | Hak |
|---|---|---|
| **`atlas`** | login otomatis di layar, menjalankan Atlas & aplikasi | **tanpa sudo**; grup `audio`, `video`, `input` |
| **admin** (dibuat saat memasang Debian, nama bebas) | perawatan lewat `Ctrl+Alt+F2` (terminal teks) | sudo, sandi hanya dipegang Hong Khai |

Mematikan, mulai ulang, dan tidur tidak butuh root: logind mengizinkan pengguna lokal yang sedang aktif. Mengatur Wi-Fi juga tidak butuh root, karena polkit NetworkManager mengizinkan pengguna lokal yang aktif. Karena itu skrip root khusus (§9 no. 4) **belum dibutuhkan** di tahap ini.

### 19.2 Yang dipasang

| Kelompok | Paket |
|---|---|
| Layar | `xserver-xorg-core` + driver Intel/modesetting, `xinit`, `openbox`, `x11-xserver-utils`, `xinput` |
| Alat atlas-helper | `xdotool`, `xprintidle`, `imagemagick`, `python3-gi`, `gir1.2-atspi-2.0`, `at-spi2-core` |
| Suara | `pipewire`, `pipewire-pulse`, `wireplumber`, `sound-theme-freedesktop` |
| Sistem | `network-manager`, `brightnessctl`, `libglib2.0-bin` (gio trash), `xdg-utils`, `zram-tools`, `firmware-*` (Wi-Fi Zyrex) |
| Aplikasi izin (§9) | Google Chrome, LibreOffice (Writer/Calc/Impress + gtk3), `mpv`, `evince`, `pcmanfm`, VS Code (repo Microsoft) |
| Atlas | Node 24 (`/opt/node`, versi sama dengan laptop 1), Claude Code CLI (untuk akun `atlas`), kode Atlas di `/opt/atlas` |

Yang **tidak** dipasang: desktop apa pun (GNOME/XFCE/LXDE), display manager, layanan yang tidak dipakai.

### 19.3 Urutan menyala

```
BIOS → Debian → getty tty1 login otomatis "atlas"
  → ~/.bash_profile: startx (hanya di tty1)
    → Openbox (tanpa menu klik-kanan, tanpa panel; hanya hotkey Atlas + Alt+Tab)
      → autostart: tunggu server Atlas → Chrome --kiosk /?kiosk=1 (diulang bila Chrome tertutup)
        [sejak §22.3: Chrome tanpa --kiosk → desktop http://localhost:4950/desktop + jendela Atlas /?window=1]
  → systemd --user: atlas.service (server Node, ATLAS_DATA=~/atlas-data, ATLAS_KIOSK=1, Restart=on-failure)
      → gagal 3× dalam 2 menit → atlas-pemulihan.service: halaman pemulihan sederhana
         (galat terakhir + tombol "mulai ulang Atlas" / "mulai ulang laptop")
Ctrl+Alt+F2 → terminal teks untuk akun admin
```

### 19.4 Pengaturan bawaan Atlas di laptop 2

- `pagar: true` (keputusan §9). Kartu izin menyala (bawaan kode). Usulan perbaikan diri mati.
- Daftar aplikasi izin = §9. Proyek di `~/proyek`, folder kerja Claude `~/Documents/Atlas`.
- zram 50 % RAM (pengaman §5.1). Penjaga RAM Atlas tetap aktif.
- Kunci rahasia: diisi Hong Khai di layar Atlas setelah terpasang, dienkripsi systemd-creds. **Tidak pernah disalin dari laptop 1.**

### 19.5 Cara menguji

1. VM uji: §19.6 [TANYA 3].
2. Pasang Debian netinst otomatis (tanpa desktop), lalu jalankan `install-atlas-os.sh` lewat SSH.
3. Mulai ulang. VM harus **menyala sendiri ke layar utama Atlas** tanpa disentuh; dibuktikan dengan tangkapan layar VirtualBox.
4. Ukur RAM: diam (layar utama), sambil mendengar, dengan LibreOffice terbuka, dan dengan tugas Claude.
5. Uji pemulihan: matikan paksa server 3× → halaman pemulihan muncul → tombol "mulai ulang Atlas" bekerja.
6. Skrip dijalankan **dua kali**: hasilnya harus sama (aman diulang).

### 19.6 Pertanyaan

1. **Wi-Fi di layar kiosk** (tidak ada desktop untuk memilih jaringan):
   - (a) panel Wi-Fi kecil di layar utama Atlas, lokal: daftar jaringan, pilih, ketik sandi; sandi tidak pernah dikirim ke Gemini. Disarankan.
   - (b) lewat terminal admin (`nmtui`) saja.
2. **Asal kode Atlas** di laptop 2:
   - (a) `git clone` dari `SiJao/atlas` dengan **deploy key hanya-baca**. Ini juga dipakai alur update Tahap 5. Saya buat kuncinya dan memasangnya di GitHub lewat API **atas izinmu**. Disarankan.
   - (b) disalin dari laptop 1 dulu; deploy key menyusul di Tahap 5.
3. **VM uji:**
   - (a) VM baru yang bersih `AtlasOS-Install` (± 8 GB disk), supaya terbukti jalan dari Debian polos; `AtlasOS-Disk` boleh dihapus setelahnya. Disarankan.
   - (b) pakai `AtlasOS-Disk` yang sudah ada (sudah tercampur GNOME, jadi kurang mewakili).
4. **Login Claude Code di laptop 2:** Claude perlu login akun (sekali, di layar laptop 2). Cara yang disarankan: lewat terminal admin setelah terpasang. Ini catatan saja, bukan pilihan.

### 19.7 Hasil (selesai 2026-11-24)

**Uji dari nol di VM bersih `AtlasOS-Install`.** Debian 13.8 netinst dipasang otomatis dengan preseed sendiri (`stage4/debian-preseed-minimal.cfg`, tanpa tugas desktop). Debian polos memakai 245 MB RAM, 1,1 GB disk, 329 paket.

| Uji | Hasil |
|---|---|
| `install-atlas-os.sh` pertama | ✅ 416 dtk + 65 dtk setelah satu perbaikan (lihat bawah), exit 0 |
| Dijalankan **lagi** (aman diulang?) | ✅ 21 dtk, exit 0, tetap satu rilis |
| Kode dari GitHub lewat deploy key hanya-baca + host key GitHub yang di-*pin* | ✅ rilis `b452861f6897` |
| Mulai ulang → **langsung layar utama Atlas** tanpa disentuh | ✅ (`stage4/boot-1.png`) |
| Hotkey Ctrl+Alt+Spasi sungguhan (keyboard VM) → Openbox → FIFO → mikrofon menyala | ✅ (`stage4/hotkey.png`) |
| Dok "Lembar kerja" → LibreOffice Calc (router lokal) | ✅ |
| Panel Wi-Fi: `/api/wifi` menjawab; sambung ke jaringan khayalan → "Perangkat Wi-Fi tidak ditemukan" (VM tanpa kartu Wi-Fi); **sandi tidak ada di file mana pun** | ✅ |
| Server dimatikan paksa 3× → **halaman pemulihan** muncul sendiri | ✅ (`stage4/recovery-1.png`) |
| Tombol "Mulai ulang Atlas" → layar utama kembali, riwayat utuh | ✅ (`stage4/recovery-2.png`) |
| Akun `atlas` tanpa sudo, sandi terkunci; Claude Code 2.1.331 terpasang (belum login) | ✅ |
| zram 1,5 GB aktif | ✅ |

**RAM sistem terpasang** (VM 3 GB, tanpa GPU; PSS per bagian):

| Keadaan | Total terpakai | Chrome kiosk | Atlas (node) | Xorg+Openbox | PipeWire | LibreOffice |
|---|---|---|---|---|---|---|
| Layar utama, diam | **715 MB** | 569 | 73 | 50 | 23 | – |
| Mikrofon menyala | **782 MB** | 604 | 55 | 55 | 38 | – |
| LibreOffice Calc terbuka | **784 MB** | 407 | 73 | 109 | 23 | 204 |

Kesimpulan: perkiraan §5 (± 450 MB diam) terlalu optimis untuk Chrome, tetapi totalnya masih **jauh di bawah 4 GB**. Kekhawatiran Tahap 0 (± 2 GB) ternyata akibat sistem live. Dengan RAM 4 GB, sisa ± 3 GB saat diam. Pengaman §5.1 tetap ada, tetapi tidak mendesak.

**Masalah yang ditemukan dan diperbaiki:**
1. Pemasang otomatis VirtualBox memasang GNOME karena templatenya tidak menentukan `tasksel`. Kini memakai preseed sendiri.
2. Nama `admin` dicadangkan Debian. Akun admin di VM uji: `atlasadmin`.
3. `runuser` membawa HOME dan folder kerja root/admin, sehingga `git` gagal membaca folder admin. Kini `as_atlas` pindah ke rumah `atlas` dan menetapkan HOME.
4. Atlas: `kendali.aplikasi` bawaan masih nama proses Windows, dan saklar usulan belum ada. Keduanya diperbaiki di repo Atlas (`fa6da19`).

**Belum (butuh laptop asli / Tahap 5–6):**
- Wi-Fi sungguhan;
- kecerahan;
- tombol darurat fisik;
- suara keluar ke speaker;
- login Claude Code;
- isi kunci Gemini;
- rollback otomatis saat update (Tahap 5).

## 20. Tahap 5 — alur update + rollback (SELESAI)

**Disetujui 2026-11-24:**
- gerbang = **uji jalan** (20.4 no. 1a);
- cek **saat menyala + tiap 6 jam**;
- **cadangan data, simpan 3 terakhir**.

**Tujuan:** laptop 2 menerima versi Atlas baru dari `SiJao/atlas` dengan aman. Ada tiga aturan:
- tidak ada update tanpa izin (mode **tanya**, §11);
- versi baru diuji dulu sebelum dipakai;
- bila gagal, otomatis kembali ke versi lama.

`atlas-data` tidak pernah diubah oleh update. Sebelum berganti versi, datanya dicadangkan.

### 20.1 Bagian-bagiannya

| Bagian | Tugas |
|---|---|
| **`atlas-update`** (skrip di `/opt/atlas-os/`, dijalankan akun `atlas`, tanpa root) | `cek`: `git ls-remote` → ada commit baru? Ringkasan perubahannya ditulis ke `~/atlas-data/update.json`. `pasang`: ambil, uji, ganti, periksa, atau rollback. `kembali`: pakai rilis sebelumnya. |
| **Pengatur waktu** `atlas-update-cek.timer` (systemd --user) | menjalankan `cek` saat menyala dan setiap N jam [TANYA 2] |
| **Atlas (server + layar utama)** | membaca `update.json` → kartu "Ada versi baru Atlas (3 perubahan) — Pasang sekarang / Nanti". "Pasang" → `systemctl --user start atlas-update.service`. Juga lewat suara: "Atlas, cek pembaruan" / "Atlas, pasang pembaruan" (router lokal). |
| **Halaman pemulihan** (Tahap 4) | tombol baru **"Kembali ke versi sebelumnya"** |

Hanya aktif di Atlas OS (Linux, `ATLAS_KIOSK=1`). Atlas di laptop 1 (Windows) tidak berubah.

### 20.2 Langkah `pasang`

```
1. git clone --depth 1 (deploy key hanya-baca) → /opt/atlas/releases/<sha>.tmp
2. GERBANG UJI [TANYA 1] → gagal: hapus .tmp, catat, berhenti (versi lama tetap jalan)
3. cadangkan ~/atlas-data → ~/atlas-cadangan/<waktu>.tar.gz (simpan 3)
4. ganti tautan /opt/atlas/current → rilis baru; systemctl --user restart atlas
5. periksa 60 dtk: GET / dan /api/keadaan harus OK terus
6. gagal → tautan kembali ke rilis lama, restart, versi baru ditandai "buruk" (tidak ditawarkan lagi)
7. simpan 3 rilis terakhir, hapus yang lebih lama
8. hasil → update.json → Atlas mengabari: "Atlas diperbarui ke <sha>" / "Update gagal, kembali ke versi lama"
```

### 20.3 Pengaman

- Hanya cabang `main` dari `SiJao/atlas`, lewat deploy key hanya-baca. Host GitHub di-pin.
- Update hanya dipasang saat **tidak ada tugas Claude berjalan** dan **tidak ada kartu izin terbuka**. Bila ada, ditunda.
- `atlas-update` tidak bisa menyentuh sistem (tanpa root). Yang diganti hanya isi `/opt/atlas`.
- Semua langkah tercatat di audit Atlas (`update_pasang`, `update_kembali`).

### 20.4 Pertanyaan

1. **Gerbang uji sebelum ganti versi:**
   - (a) **uji jalan**: versi baru dinyalakan di port cadangan dengan salinan data, lalu halaman dan API-nya diperiksa (± 20–30 dtk). Disarankan.
   - (b) (a) **ditambah tes unit yang aman di Linux** (± 3–5 menit di Celeron; sebagian tes Atlas khusus Windows, jadi daftarnya disaring dulu).
2. **Seberapa sering mengecek versi baru:** saat menyala + tiap 6 jam (disarankan) / saat menyala saja / tiap jam.
3. **Cadangan data sebelum update:** ya, simpan 3 cadangan terakhir (disarankan) / tidak.

### 20.5 Hasil (selesai 2026-11-24)

**Kode:**
- Atlas: `d297c60` (mode `ATLAS_UJI_JALAN=1`), `104a980` (modul `server/update.js`, alat `update_cek/pasang/kembali`, frasa router, tombol "Versi baru"), `5d617fe` (cek dijawab sekali).
- Atlas OS: `stage4/files/atlas-update.mjs` (pengupdate), layanan + timer di pemasang, tombol "Kembali ke versi sebelumnya" di halaman pemulihan.
- Tes Windows: **292/292** lulus.

**Uji di VM `AtlasOS-Install`:**

| Uji | Hasil |
|---|---|
| Timer cek saat menyala | ✅ menemukan versi baru **sungguhan** di GitHub (`104a980`, 2 perubahan) |
| Pasang dari GitHub | ✅ 68 dtk: clone → uji jalan → cadangan data → ganti → sehat 60 dtk → `b452861 → 104a980` |
| Versi rusak (galat sintaks) | ✅ dihentikan oleh uji jalan ("SyntaxError: Unexpected identifier"); versi aktif tidak tersentuh |
| Versi yang mati 25 dtk setelah menyala | ✅ lolos uji jalan, gagal cek kesehatan → **otomatis kembali** ke versi lama (± 35 dtk); rilis rusak dihapus & ditandai buruk |
| "Kembali ke versi sebelumnya" | ✅ ke rilis sehat sebelumnya, melewati rilis buruk |
| **Alur dari layar** | ✅ "cek pembaruan" → tombol **Versi baru · pasang** → diklik mouse → **kartu izin** "Pasang versi baru Atlas? 104a980 → 26e1247" → **Ya, izinkan** → "Atlas sudah diperbarui ke versi 26e12476e3ab" (dibacakan) |

Repo uji lokal di VM dipakai untuk versi rusak, jadi tidak ada commit rusak yang pernah menyentuh `SiJao/atlas`. VM dibersihkan kembali ke `104a980`.

**Bug yang ditemukan uji dan sudah diperbaiki:**
1. Atlas yang menyala setelah update mengumumkan lagi "Ada versi baru". Kini pengupdate menulis status antara `memasang` / `mengembalikan` yang tidak diumumkan.
2. Kabar setelah restart tidak muncul. Kini kunci kabar terakhir disimpan di `data/update-kabar.json`.
3. "Kembali" sempat memilih rilis yang rusak. Kini rilis gagal dihapus, rilis buruk dilewati, dan `sebelumnya` tidak hilang tertimpa.
4. Pesan galat uji jalan kurang jelas. Kini baris `…Error` yang ditampilkan.
5. Cache riwayat commit kini per alamat repo, sehingga repo uji tidak mencampuri cache GitHub.
6. Menjalankan ulang pemasang dulu ikut mengganti versi diam-diam. Kini versi yang sudah terpasang dibiarkan; mengganti versi hanya lewat pengupdate.
7. "Cek pembaruan" dijawab dua kali. Kini sekali.

**Catatan jujur:** commit Atlas `d297c60` sudah meng-import `./update.js` yang baru masuk di `104a980`, jadi `d297c60` sendirian tidak bisa dijalankan. Laptop 2 selalu memakai ujung `main` sehingga tidak berdampak. Riwayat tidak ditulis ulang, karena itu butuh force push.

## 21. Perbaikan dari uji coba Hong Khai di VirtualBox (2026-11-24)

**Keputusan Hong Khai:**
1. Tombol **"Mode admin"** di Atlas: kolom sandi bertitik, lalu terminal admin terbuka.
2. Menu daya: **langsung** tanpa kartu. Ucapan: tetap kartu, tetapi setelah "Ya" **langsung mati** (tanpa 60 dtk).
3. Tombol: **tanpa tanda bila berhasil**. Bila **gagal atau crash**: **popup** "<aplikasi> gagal dijalankan: <alasan>".
4. Panel **Jaringan** dengan LAN/kabel (disetujui tanpa pertanyaan).

| No | Masukan | Penyebab | Usulan |
|---|---|---|---|
| 1 | **Login admin membingungkan**: tidak terlihat apakah nama pengguna benar atau sedang mengisi sandi | Terminal teks Linux (`Ctrl+Alt+F2`) memang tidak menampilkan apa pun saat sandi diketik; pesannya bahasa Inggris dan hurufnya kecil | [TANYA 1] |
| 2 | **Jaringan**: tampilkan juga LAN/kabel atau jaringan virtual, bukan hanya Wi-Fi | Panel hanya membaca daftar Wi-Fi | Panel **"Jaringan"**: bagian *Kabel / LAN* (nama perangkat, tersambung atau tidak, alamat IP) di atas daftar Wi-Fi. Bar status menunjukkan jenis sambungan ("Kabel" / nama Wi-Fi / "Offline"). |
| 3 | **Matikan / mulai ulang langsung**, tanpa menunggu 60 detik | Jeda 60 dtk ditiru dari Windows (`shutdown /t 60`) | Di Atlas OS: langsung. [TANYA 2] |
| 4 | **Tombol & aksi tidak perlu masuk ke gelembung obrolan**, kecuali bila Hong Khai sendiri meminta (mengucapkan/mengetik) | Tombol dok, daya, dan pembaruan mengirim kalimat ("buka lembar kerja") lewat obrolan | Jalur baru **`/api/aksi`**: tombol menjalankan alat langsung, tetap lewat kartu izin bila perlu dan tetap tercatat di audit, tetapi **tidak** menulis pesan di obrolan. Hasilnya tampil sebentar sebagai baris kecil di bawah orb. Ucapan/ketikan tetap masuk obrolan seperti biasa. [TANYA 3] |

Pertanyaan:
1. **Login admin:**
   - (a) layar login diberi petunjuk Bahasa Indonesia yang jelas, misalnya "ketik nama akun, Enter; ketik sandi — **hurufnya memang tidak tampil**, lalu Enter", plus huruf terminal lebih besar. Disarankan; perubahannya kecil.
   - (b) tombol **"Mode admin"** di menu daya Atlas, dengan kolom sandi bertitik (●●●) di layar grafis.
2. **Matikan/mulai ulang:**
   - (a) dari **menu daya**: langsung tanpa kartu izin (memilih di menu sudah berupa konfirmasi); lewat **ucapan** "matikan laptop": tetap dengan kartu (untuk berjaga dari salah dengar). Disarankan.
   - (b) keduanya langsung tanpa kartu.
   - Atlas di Windows (laptop 1) tetap 60 detik.
3. **Hasil tombol:**
   - (a) baris kecil di bawah orb selama ± 4 dtk, misalnya "Lembar kerja dibuka" atau "Gagal: …". Disarankan.
   - (b) tanpa tanda apa pun.

### 21.1 Hasil (2026-11-24)

Atlas: `5caee18` (empat perbaikan), `bba071b` (kolom sandi & kabel unmanaged), `f230d80` (kegagalan daya jadi popup). Tes Windows 298/298 (kecuali `tutup_aplikasi` yang lambat saat VM berjalan; bagian itu tidak diubah).

Diuji di VM dengan klik mouse sungguhan:

| Uji | Hasil |
|---|---|
| Klik dok "Lembar kerja" | ✅ Calc terbuka; **tidak ada pesan baru di obrolan** |
| Popup gagal | ✅ penampil PDF disembunyikan → klik dok PDF → popup "PDF gagal dijalankan — pdf belum terpasang" |
| Panel Jaringan | ✅ bagian **Kabel / LAN** (`enp0s3`) di atas Wi-Fi; bar status "· Kabel" |
| Mode admin | ✅ sandi tampil ●●●; salah → "Sandi salah."; benar → **terminal admin `atlasadmin`** (huruf besar); file sandi sekali-pakai terhapus; audit hanya mencatat berhasil/gagal |
| Menu daya "Mulai ulang" | ✅ VM mati **6 dtk** setelah klik (tanpa 60 dtk, tanpa kartu), layar Atlas kembali sendiri |

**Masalah yang ditemukan uji dan sudah diperbaiki:**
1. **Chrome menawarkan menyimpan sandi admin.** Kolom sandi admin & Wi-Fi kini teks yang digambar sebagai titik (bukan `type=password`).
2. **Kabel tampil "Tidak tersambung"**, karena kabel dari pemasang Debian dikelola `ifupdown`. Kini IP-nya dibaca dari kernel, dan pemasang membuat NetworkManager ikut mengelola kabel.
3. **Mulai ulang/matikan tidak terjadi dan senyap.** `polkitd` tidak terpasang (`--no-install-recommends`), sehingga logind & NetworkManager menolak layanan Atlas. Kini pemasang memasang `polkitd` + aturan **khusus akun atlas, hanya daya & NetworkManager**; penolakan apa pun menjadi popup. (Bug ini juga mengenai panel Wi-Fi di laptop asli; kini ikut beres.)
4. **Pengupdate memasang tawaran lama**, bukan versi terbaru. Kini selalu mengecek ulang sebelum memasang.

Juga ditambahkan: petunjuk Bahasa Indonesia di layar login terminal (`/etc/issue`) sebagai cadangan Mode admin.

## 22. Tampilan desktop baru dari gambar Hong Khai (2026-11-24, setelah §21)

Rujukan: gambar buatan Gemini milik Hong Khai (`ui-reference/gemini-desktop.jpg`, lokal saja). Isinya: bar menu atas, wallpaper ombak dengan pusaran Debian, jendela "Tentang OS Ini", jendela Atlas mengambang (orb + obrolan + kolom ketik), dan dok ikon berwarna di bawah.

**Keputusan Hong Khai:**
1. Dikerjakan **setelah** 4 perbaikan §21.
2. Bar atas & dok **selalu terlihat**. Aplikasi dibuka di ruang di antaranya (margin Openbox; layar Atlas di lapisan paling bawah).
3. Atlas berupa **jendela sendiri** yang bisa dipanggil di atas aplikasi (Ctrl+Alt+Spasi / ikon Atlas di dok).
5. **Notch Atlas** (seperti di Atlas Windows, §22 DESIGN Atlas) ikut dipakai, tetapi **lebih ringkas** supaya tidak memenuhi layar: pil kecil di tengah bar atas; saat dipanggil/mendengar/berbicara hanya turun sedikit (orb kecil + status + teks singkat), lalu naik lagi. (Permintaan Hong Khai 2026-11-24.)
4. Bar menu: **menu Atlas saja + status**. Menu Atlas berisi Tentang OS Ini, Jaringan, Mode admin, Tidurkan, Mulai ulang, Matikan. Bagian kanan: Online, baterai, RAM, Versi baru, Wi-Fi, volume, tanggal & jam.

**Penyesuaian dari gambar:**
- logo Apple diganti logo Atlas;
- ikon aplikasi digambar sendiri (bukan logo merek lain);
- data "Tentang OS Ini" dibaca dari sistem (gambar menulis 3 GB/eMMC; Zyrex 4 GB/SSD).

Alurnya sama seperti sebelumnya: prototipe Chrome → dipilih → dipasang.

### 22.1 Prototipe (2026-11-24)

`desktop-ui/desktop-prototype.html` (dibuka di Chrome; tombol tinjau di bawah layar memperlihatkan semua keadaan). Isinya:
- **bar atas:** logo Atlas + menu (Tentang OS Ini, Pengaturan…, Jaringan…, Mode admin…, Tidurkan, Mulai ulang, Matikan); kanan: Online · Kabel, baterai, RAM, Versi baru, Wi-Fi, volume, tanggal & jam;
- **notch ringkas:** pil 150×30 di tengah bar. Turun menjadi 380×64 hanya bila Atlas sedang mendengar/berpikir/berbicara **dan** jendelanya tersembunyi;
- **wallpaper:** ombak biru-ungu + pusaran (digambar sendiri, bukan logo Debian);
- **dok:** ikon sendiri (Browser, Dokumen, Lembar kerja, Presentasi, Kode, Video, PDF, Berkas, **Pengaturan** | Atlas, Sampah); titik di bawah ikon = aplikasi sedang terbuka;
- **jendela Atlas** mengambang (orb + obrolan + kolom ketik);
- **Pengaturan**.

### 22.2 Pengaturan (permintaan Hong Khai 2026-11-24, "seperti Windows dan OS lain")

Jendela sendiri: daftar kategori di kiri (dengan kotak cari), isi di kanan. Isinya dibaca dari sistem dan diubah lewat alat Linux biasa, **tanpa sudo**. Yang butuh root hanya ditampilkan dengan keterangan "lewat Mode admin".

| Kategori | Isi | Alat Linux |
|---|---|---|
| Sistem | nama perangkat, OS, versi Atlas, prosesor, memori, grafis, disk, suhu, lama menyala | `/etc/os-release`, `/proc/cpuinfo`, `os`, `lspci`, `df`, `/sys/class/thermal` |
| Layar | kecerahan (geser), lampu malam, resolusi (dibaca), matikan layar setelah … | `brightnessctl`, `xrandr --gamma`, `xrandr`, `xset dpms` |
| Suara | volume & bisu, perangkat keluaran, mikrofon & volumenya | `wpctl` |
| Jaringan & Internet | kabel/LAN, Wi-Fi nyala/mati, daftar Wi-Fi + sambung | `nmcli` (sudah ada, §19/§21) |
| Baterai & Daya | persen, status, kesehatan, tidur otomatis setelah … menit (pakai baterai / dicas) | `/sys/class/power_supply`, waktu diam dari `xprintidle`, `systemctl suspend` |
| Penyimpanan | pemakaian disk, Tempat Sampah (kosongkan) | `df`, `du`, `gio trash --empty` |
| Tanggal & Waktu | waktu otomatis (NTP), zona waktu (WIB/WITA/WIT + semua) | `timedatectl` (aturan polkit baru: **hanya** zona waktu & NTP) |
| Aplikasi | daftar aplikasi yang diizinkan & perintahnya (dibaca) | daftar izin Atlas |
| Atlas | versi, pintasan, suara jawaban, kartu izin, pagar (dibaca) | pengaturan Atlas |
| Pembaruan | versi terpasang, cek sekarang, kembali ke versi sebelumnya | §20 (tetap lewat kartu izin) |
| Keamanan | kunci layar sekarang, Mode admin | §21 |

Pilihan yang disimpan (lampu malam, matikan layar, tidur otomatis) ditaruh di `data/system-settings.json` dan dipasang ulang setiap Atlas menyala.

Tidak dimasukkan (butuh root atau berisiko mengunci layar): ganti nama perangkat, ubah resolusi, aksi tutup laptop, Bluetooth (belum terpasang). Semua bisa lewat Mode admin.

### 22.3 Susunan jendela (hasil uji VM 2026-11-24)

Dua temuan dari uji di VM:
1. Chrome yang dibuka dengan `--kiosk` membuat **semua** jendelanya layar penuh. Karena itu Chrome kini dibuka **tanpa** `--kiosk`.
2. Saat Openbox memasang aturan jendela, judul halaman belum ada (masih `127.0.0.1_/`). Yang bisa dibedakan hanya `WM_CLASS`, yang dibuat Chrome dari **host + jalur** (`localhost__desktop`, `127.0.0.1__settings`, `127.0.0.1` untuk `/?window=1`).

Susunannya (satu Chrome, profil yang sama):

| Jendela | Alamat | Diatur oleh |
|---|---|---|
| Desktop (wallpaper + bar + notch + dok) | `http://localhost:4950/desktop` | aturan Openbox `name="localhost__desktop"`: tanpa bingkai, lapisan **bawah**, tidak di Alt+Tab; ukurannya disamakan dengan layar oleh `atlas-kiosk` |
| Jendela Atlas | `http://127.0.0.1:4950/?window=1` | Atlas sendiri (`wmctrl`): ± 440 px di kanan, di antara bar dan dok; disembunyikan = diminimalkan |
| Pengaturan | `http://127.0.0.1:4950/settings` | aturan biasa: dimaksimalkan di antara bar dan dok |
| Aplikasi lain | — | dimaksimalkan di antara bar & dok |

- **Margin Openbox:** atas 34 px (bar), bawah 84 px (dok). Ukuran ini cocok untuk layar Zyrex 1366×768.
- **Memanggil Atlas:** Ctrl+Alt+Spasi atau ikon Atlas di dok → jendela Atlas muncul di depan dan mikrofon menyala. Kartu izin yang datang saat jendela tersembunyi juga memunculkannya.
- **Menu & popup desktop** (menu Atlas, popup "gagal dijalankan"): selama terbuka, jendela desktop **naik sementara** ke depan; setelah ditutup turun lagi. Ikon Wi-Fi/volume/baterai di bar membuka halaman Pengaturan yang sesuai, jadi tidak perlu popup.
- **Notch:** Atlas mengirim keadaan jendelanya (terlihat/tersembunyi, mendengar) ke desktop lewat server (SSE).
- Bila jendela Atlas atau desktop tertutup (Alt+F4), `atlas-kiosk` membukanya lagi.
- Halaman pemulihan (§19.3) tetap layar penuh seperti sebelumnya.
- Atlas di Windows (laptop 1) tidak berubah; semua ini hanya aktif bila `ATLAS_KIOSK=1` di Linux.

### 22.4 Plus / minus

- ➕ Aplikasi tidak menutupi bar & dok; Atlas tetap dipanggil dengan satu tombol; Pengaturan tanpa terminal.
- ➖ Satu jendela Chrome tambahan (± 60–80 MB RAM). Saat menu desktop terbuka, aplikasi tertutup sementara.

### 22.5 Hasil (2026-11-24)

Atlas `7afd7dd`. Tes Windows 310/310 (termasuk 12 tes baru `tests/settings.test.mjs`). Diuji di VM `AtlasOS-Install` (1280×800) dengan klik mouse sungguhan; tangkapan layar ada di `desktop-ui/vm-screens/`.

| Uji | Hasil |
|---|---|
| Menyala | ✅ desktop (bawah, tanpa bingkai, selebar layar) + jendela Atlas mengambang di kanan, di antara bar & dok |
| Ikon Pengaturan di dok | ✅ jendela Pengaturan, dimaksimalkan di antara bar & dok; data asli VM (Celeron N4020, 2,9 GB, VMware SVGA, Debian 13) |
| Ubah lewat Pengaturan | ✅ zona waktu WITA → WIB (polkit), volume 55 %, lampu malam, matikan layar 10 menit (`xset`); kecerahan ditolak dengan pesan (VM tanpa lampu latar); kunci asing ditolak |
| Menu Atlas di bar | ✅ desktop naik sementara, menu tampil; klik di luar → turun lagi |
| Dok "Lembar kerja" | ✅ Calc dimaksimalkan di antara bar & dok; titik di bawah ikon |
| Ctrl+Alt+Spasi | ✅ jendela Atlas ke depan (di atas Calc), "Mendengarkan…" |
| Notch | ✅ Atlas sibuk + jendela tersembunyi → pil melebar di dalam bar ("Sedang berpikir… membaca pengingat & kalender") |
| Atlas dimulai ulang | ✅ berhenti 1 dtk; Calc tetap terbuka |
| RAM | 0,6–0,8 GB terpakai (desktop + jendela Atlas + Pengaturan [+ Calc]) |

**Masalah yang ditemukan uji dan sudah diperbaiki:**
1. **Nama jendela Chrome** = host + jalur (`localhost__desktop`, `127.0.0.1__settings`), bukan host saja. Aturan Openbox dan pencarian jendela disesuaikan.
2. **Bar peringatan Chrome** ("unsupported command-line flag") muncul setelah `--kiosk` dibuang. Flag mikrofon diganti kebijakan Chrome `/etc/opt/chrome/policies/managed/atlas-os.json`: mikrofon & suara otomatis **hanya** untuk alamat Atlas.
3. **Gelembung Google Translate** di desktop. Halaman Atlas kini ditandai `notranslate`.
4. **`atlas-kiosk` macet** karena Chrome dibuka di depan sebelum siap. Kini semua peluncuran di latar, dan jendela Atlas baru dibuka setelah desktop ada.
5. **Aplikasi ikut mati saat Atlas dimulai ulang** (cgroup layanan): Calc yang belum disimpan hilang. Kini setiap aplikasi dijalankan di scope systemd sendiri (`systemd-run --user --scope`). Bug ini sudah ada sejak Tahap 2 dan juga mengenai pembaruan Atlas.
6. **Stop Atlas macet 90 dtk** karena sambungan SSE desktop/Pengaturan & keep-alive tidak ditutup. Kini ditutup semua, dengan jaring pengaman keluar setelah 5 dtk.
7. **Kecerahan membaca LED Scroll Lock** saat tidak ada lampu latar. Kini hanya kelas `backlight`. Bug lama ini juga mengenai "Atlas, terangkan layar".
8. **Titik dok**: LibreOffice menaruh jenis aplikasinya di kelas (`libreoffice.libreoffice-calc`), dan jendela Atlas sendiri juga Chrome. Pencocokan diperbaiki.
9. **Bingkai jendela Atlas menimpa bar**: `wmctrl` menaruh isi jendela, sedangkan bar judul Openbox ada di atasnya. Posisi kini memperhitungkan bar judul.

**Belum diuji di VM:** suara mikrofon sungguhan & notch saat benar-benar berbicara (butuh kunci Gemini), suspend otomatis, kunci Wi-Fi asli. Semuanya untuk Tahap 6 (laptop asli).

## 23. Temuan pemeriksa plugin `atlas-os-engineering` (2026-11-24)

Hong Khai memasang plugin `atlas-os-engineering` (zip buatannya sendiri) dan meminta plugin itu dipakai. Dua pemeriksa independen dari plugin (`security-auditor`, `qa-test-engineer`) memeriksa Atlas `7afd7dd` + Atlas-OS `2f1553e` dengan membaca kode dan menjalankan tes (310/310). Tidak ada temuan keamanan tingkat tinggi. **Keputusan Hong Khai: kerjakan semuanya.**

### 23.1 Bug

| No | Bug | Perbaikan |
|---|---|---|
| 1 | Tidur otomatis berulang: setelah tidur > 10 menit dan dibangunkan tanpa sentuhan mouse/keyboard, waktu diam masih besar, jadi laptop langsung tidur lagi | Tidur hanya bila masa diam **dimulai setelah** tidur terakhir |
| 2 | Ikon Atlas di dok tidak pernah menyembunyikan jendela: saat diklik, yang aktif adalah jendela desktop | Ditentukan dari urutan tumpukan jendela (`_NET_CLIENT_LIST_STACKING`): Atlas paling atas dan tidak diminimalkan → sembunyikan; selain itu → tampilkan |
| 3 | Baterai mouse/keyboard nirkabel (`scope=Device`) terbaca sebagai baterai laptop | Abaikan baterai perangkat; `capacity` kosong = tidak terbaca (bukan 0 %) |
| 4 | Input aneh: `NaN` sampai ke `brightnessctl`/`wpctl`; kunci `constructor` menimbulkan galat 500; angka negatif di `system-settings.json` diterima | Angka diperiksa; tabel memakai `Object.hasOwn`; nilai tersimpan hanya dari daftar pilihan |
| 5 | `atlas-kiosk` bisa `kill` nomor proses lama | Hanya `pkill` per profil |
| 6 | Pengaturan simpanan gagal dipasang bila X belum siap saat Atlas mulai | Dicoba ulang beberapa kali |
| 7 | Jendela Atlas ganda bila judul halaman lambat muncul | Jendela Atlas dikenali dari kelasnya saja (`127.0.0.1` persis), bukan judul |
| 8 | Pengaturan memuat ulang halaman setelah Atlas tersambung lagi, sehingga sandi yang sedang diketik hilang | Tidak dimuat ulang bila ada kolom yang sedang diisi |

### 23.2 Keamanan

- **A. Hanya akun atlas (dan root) yang boleh memakai server Atlas.** Rancangan awal (token di halaman) tidak menghentikan program lokal, karena program itu bisa membuka halaman yang sama dan membaca tokennya. Yang benar-benar menjaga: di Linux, pemilik (UID) setiap sambungan ke `127.0.0.1:4950` dibaca dari `/proc/net/tcp`; sambungan dari akun lain ditolak (403). Program yang berjalan sebagai `atlas` memang sudah dipercaya penuh (mereka bisa mengubah data Atlas langsung). Windows tidak berubah.
- **B. Profil Chrome Atlas dikunci.** Kebijakan Chrome berlaku untuk seluruh mesin, termasuk Browser di dok, jadi pemblokiran URL tidak dipakai. Sebagai gantinya, `atlas-kiosk` menutup setiap jendela browser biasa (Ctrl+N / Ctrl+T) dan DevTools yang muncul di profil Chrome Atlas. Ini hanya penghalang, bukan sandbox.
- **C. Mikrofon** otomatis hanya untuk `http://127.0.0.1:4950` (jendela Atlas). `localhost` dihapus, karena desktop tidak butuh mikrofon.
- **D. Polkit NetworkManager dipersempit.** Yang tetap diizinkan: `network-control`, `enable-disable-wifi`, `wifi.scan`, `settings.modify.system` (menyimpan Wi-Fi baru), `settings.modify.own`. Yang tidak lagi diizinkan: mematikan seluruh jaringan, nama host, DNS global, hotspot, dan lainnya.
- **E. Audit Pengaturan.** Semua kunci dicatat, berhasil maupun gagal, beserta nilai yang bukan rahasia.
- Dicatat saja: indikator notch "mendengar" bukan indikator privasi (bisa dipalsukan program lokal).

### 23.3 Dokumen

Empat tempat di SUMMARY/DESIGN yang masih menulis `Chrome --kiosk /?kiosk=1` diperbarui atau ditandai "diganti §22.3".

### 23.4 Hasil (2026-11-24)

Atlas `0733cf0`. Tes Windows 319/319, termasuk 9 tes baru di `tests/settings.test.mjs`. Diuji di VM `AtlasOS-Install` setelah pemasang dijalankan ulang:

| Uji | Hasil |
|---|---|
| A — akun lain (`atlasadmin`) memanggil API, termasuk POST dengan Origin palsu | ✅ 403 "Akun ditolak"; akun `atlas` dan root 200; Chrome & `atlas-kiosk` tetap jalan |
| B — jendela browser biasa dibuka di profil Chrome Atlas | ✅ tertutup sendiri dalam ± 1 dtk |
| C — kebijakan Chrome | ✅ mikrofon/suara otomatis hanya `http://127.0.0.1:4950` |
| D — `nmcli networking off` / ganti nama host sebagai atlas | ✅ ditolak; Wi-Fi nyala/mati tetap bisa |
| No. 4 — `volume=abc`, `?bagian=constructor` | ✅ 400 dengan pesan jelas |
| E — audit | ✅ perubahan gagal tercatat beserta nilainya |
| No. 2 — ikon Atlas di dok | ✅ klik 1 menyembunyikan, klik 2 menampilkan; saat Calc di atas, klik membawa Atlas ke depan |
| Menyala ulang | ✅ desktop + jendela Atlas, satu jendela masing-masing |

Belum bisa diuji di VM: tidur otomatis setelah bangun (no. 1) dan baterai mouse nirkabel (no. 3). Keduanya hanya diuji lewat tes unit; uji perangkat keras di Tahap 6.

## 24. Daftar kekurangan Atlas OS (2026-11-24; dikerjakan mulai 2026-11-24)

Hong Khai: "sistem ini sangat banyak kurangnya, fungsi, dll". Ia memilih keempat kelompok (dasar sehari-hari, pengaturan, aplikasi, desktop & Atlas) dan meminta **daftar lengkap dulu**. Sumber daftar: pemeriksaan saya, laporan `os-architect` dari plugin (baca kode + daftar paket pemasang), dan dua klaim yang saya cek ulang sendiri. Ukuran kerja: **K** = kecil (± setengah hari), **S** = sedang, **B** = besar. "Root" = butuh paket/izin baru dari pemasang.

### 24.1 Kesalahan yang ditemukan sambil menyusun daftar

- **Ukuran layar salah.** §2 mencatat Zyrex **11,6" FHD (1920×1080)**, tetapi desktop §22 saya rancang untuk 1366×768 (margin 34/84 px, huruf 13–14 px). Di layar asli tulisan akan sangat kecil. Perlu **skala tampilan** (lihat P1-4).
- **Pesan kunci Gemini** di halaman Atlas masih menyebut jalur Windows (`C:\HISADA\atlas\data\rahasia.json` + Notepad).

### 24.2 Prioritas 1 — tanpa ini Atlas OS terasa belum bisa dipakai

| No | Kekurangan | Sekarang | Usulan | Ukuran |
|---|---|---|---|---|
| P1-1 | **Kunci Gemini dari layar** | hanya lewat terminal admin + `rahasia.json` | kolom bertitik di Pengaturan › Atlas; disimpan terenkripsi `systemd-creds`; tidak pernah dicatat/dikirim | K |
| P1-2 | **Flashdisk / kartu SD** | tidak ada `udisks2`/`gvfs`: tidak terbuka otomatis | pasang `udisks2 gvfs ntfs-3g exfatprogs` + aturan polkit (hanya mount/lepas untuk atlas); ikon/popup "Flashdisk" di bar + tombol **Lepas dengan aman** | S, root |
| P1-3 | **Proyektor / monitor kedua** | hanya membaca layar pertama | Pengaturan › Layar: **Duplikat / Perluas / Hanya proyektor** (`xrandr`), deteksi saat dicolok | S |
| P1-4 | **Skala tampilan** | tidak ada; desktop dirancang untuk 1366×768 | skala 100/125/150 % untuk desktop, jendela Atlas, Pengaturan (CSS) dan aplikasi (`Xft.dpi`), margin Openbox ikut skala; bawaan 150 % di FHD 11,6" | S |
| P1-5 | **Kunci layar** | tombol ada tetapi tidak berbuat apa-apa (tidak ada pengunci terpasang) | perlu keputusan: buka dengan **PIN** sendiri (disimpan terenkripsi) atau sandi admin; kunci otomatis saat tidur/tutup layar | S, root |
| P1-6 | **Baterai lemah** | hanya mode hemat diam-diam | popup peringatan 20 % dan 10 %, tidur otomatis di 5 % (simpan pekerjaan dulu) | K |
| P1-7 | **Pembaruan keamanan Debian + Chrome + VS Code** | tidak ada; hanya Atlas yang diperbarui | `unattended-upgrades` (keamanan saja, otomatis) + tampil di Pengaturan › Pembaruan | K, root |
| P1-8 | **Bahasa & papan ketik** | locale & keyboard bawaan pemasang (en, US); tidak ada Arab | Bahasa Indonesia untuk sistem/LibreOffice (`libreoffice-l10n-id`, kamus `hunspell-id`); papan ketik **Arab** dengan tombol pindah (mis. Alt+Shift) + penanda di bar; font Arab (Amiri / Scheherazade) | S, root |

### 24.3 Prioritas 2 — kebutuhan sehari-hari

| No | Kekurangan | Usulan | Ukuran |
|---|---|---|---|
| P2-1 | **Kartu "Hari ini" + jam besar** hilang dari desktop baru | widget pengingat hari ini + jam di wallpaper (kiri atas) | K |
| P2-2 | **Printer** tidak ada (`cups`) | `cups` + driver umum; Pengaturan › Printer (tambah printer jaringan/USB, cetak halaman uji) | S, root |
| P2-3 | **Zip/RAR** tidak bisa dibuka | `xarchiver` + `unzip p7zip`; klik ganda di Berkas membuka arsip | K, root |
| P2-4 | **Penampil foto** tidak ada | `ristretto` (ringan) + ikon dok opsional | K, root |
| P2-5 | **Tangkapan layar** | tombol PrintScreen → simpan ke `Gambar/Tangkapan layar` + notifikasi | K |
| P2-6 | **Tombol Fn** volume/kecerahan/bisu | ikatan tombol `XF86*` di Openbox + tampilan kecil (OSD) di desktop | K |
| P2-7 | **Notifikasi** aplikasi (Chrome, LibreOffice) | penerima notifikasi kecil → tampil di desktop (pojok kanan atas, di bawah bar) | S |
| P2-8 | **Daftar jendela terbuka** | menu di bar atau tombol di dok: semua jendela terbuka, pulihkan yang diminimalkan, "tampilkan desktop" | S |
| P2-9 | **Aplikasi bawaan per jenis file** | `mimeapps.list`: PDF→Evince, docx→Writer, xlsx→Calc, gambar→penampil foto, video→mpv | K |
| P2-10 | **Bluetooth** (mouse, speaker, earphone) | `bluez` + Pengaturan › Bluetooth (cari, pasangkan, lepas) | S, root |
| P2-11 | **Kalkulator, catatan cepat, penyunting teks ringan** | `galculator`, `mousepad` (VS Code terlalu berat untuk catatan) | K, root |

### 24.4 Prioritas 3 — perawatan & lanjutan

| No | Kekurangan | Usulan | Ukuran |
|---|---|---|---|
| P3-1 | **Cadangan dokumen** | salin otomatis Dokumen/Unduhan ke flashdisk pilihan (setelah P1-2), dengan pengingat | S |
| P3-2 | **Memasang aplikasi lain** | daftar aplikasi pilihan (katalog kecil) yang bisa dipasang lewat Mode admin + otomatis masuk daftar izin Atlas | B, root |
| P3-3 | **Penyiapan pertama** | saat pertama menyala: Wi-Fi → zona waktu → kunci Gemini → login Google, satu per satu | S |
| P3-4 | **Login Claude Code dari layar** | tombol di Pengaturan › Atlas membuka terminal login (sebagai atlas) | K |
| P3-5 | **Log untuk pengguna** | Pengaturan › Keamanan: log aktivitas sudah ada; tambah "masalah terakhir" (gagal buka aplikasi, pembaruan gagal) | K |
| P3-6 | **Kamera** | izin kamera untuk Meet/Zoom di Chrome sudah normal; aplikasi kamera kecil opsional | K |
| P3-7 | **Atlas mengendalikan aplikasi lain** | kendali AT-SPI baru teruji di LibreOffice; tambahkan Chrome/Evince/Berkas | B |
| P3-8 | **Tombol daya & tutup laptop** | Pengaturan › Baterai & Daya: aksi tutup layar & tombol daya (butuh aturan logind) | K, root |
| P3-9 | **Pemulihan/reset** | "Kembalikan pengaturan Atlas OS" dan USB penyelamat | B |
| P3-10 | VPN, hotspot, pemindai, layar sentuh/aksesibilitas | dicatat, belum diusulkan | — |

### 24.5 Catatan

- Paket baru menambah ruang disk sedikit, tetapi RAM hanya saat aplikasinya dibuka (`udisks2`, `cups`, `bluez` masing-masing ± 5–15 MB bila aktif).
- Semua yang "root" masuk lewat **pemasang** (dijalankan ulang oleh admin), bukan oleh Atlas atau Claude.
- Perangkat keras nyata (Wi-Fi, suara, kecerahan, kamera, tombol Fn, lampu latar) tetap harus dicek di Tahap 6.

### 24.6 Keputusan Hong Khai (2026-11-24)

- Daftar ini **disimpan dulu**; belum ada yang dikerjakan. Urutan pengerjaan dipilih nanti.
- **Kunci layar (P1-5): PIN sendiri** (4–8 angka, diatur di Pengaturan › Keamanan, disimpan terenkripsi). Sandi admin tetap terpisah.
- **Pembaruan 2026-11-24 (pesan berikutnya):** "sekalian kerjakan DESIGN §24" → semua dikerjakan berurutan P1 → P2 → P3, diuji di VM dan di-push per kelompok. P3-10 tetap hanya dicatat.

### 24.7 Cara pengerjaan (keputusan teknis, dipilih sendiri karena Hong Khai meminta langsung dikerjakan)

Prinsip: yang butuh root masuk lewat **pemasang**; saat berjalan, Atlas tetap tanpa sudo. Pilihan berisiko kecil saja yang diambil sendiri; semuanya bisa diubah.

| No | Cara |
|---|---|
| P1-1 | Pengaturan › Atlas: kolom kunci bertitik → `POST /api/settings/kunci` → ditulis lewat gudang rahasia (terenkripsi `systemd-creds`), tidak pernah dicatat nilainya. Pesan "kunci belum diisi" tidak lagi menyebut jalur Windows di Atlas OS. |
| P1-2 | Pemasang: `udisks2 ntfs-3g exfatprogs dosfstools` + polkit **hanya** mount/lepas/eject untuk atlas. Atlas memantau `lsblk` tiap 3 dtk, me-mount flashdisk baru (`udisksctl`), menampilkan ikon **Flashdisk** di bar (Buka / Lepas dengan aman). |
| P1-3 | Pengaturan › Layar: daftar layar tersambung + **Duplikat / Perluas / Hanya layar luar / Hanya laptop** (`xrandr`). Saat proyektor dicolok, notch menawarkan pilihan. `atlas-kiosk` menyesuaikan ukuran desktop bila ukuran layar berubah. |
| P1-4 | **Ukuran tampilan** 100/125/150/175/200 % lewat `Xft.dpi` (Chrome, LibreOffice, GTK ikut) + margin Openbox ikut dikali. Bawaan dihitung dari ukuran fisik layar (11,6" FHD → 150 %). Berlaku setelah jendela Atlas dibuka ulang otomatis. |
| P1-5 | Kunci layar `xsecurelock` + `xss-lock`; PIN 4–8 angka (pilihan Hong Khai), hash `sha512-crypt` di file milik atlas, diperiksa `pam_pwdfile` lewat layanan PAM khusus `atlas-lock`. Terkunci saat: tombol, tidur, layar mati. **Selama terkunci Atlas tidak menjalankan perintah suara.** Tanpa PIN: tombol menjelaskan "atur PIN dulu". |
| P1-6 | Baterai ≤ 20 % dan ≤ 10 %: peringatan (notch + bunyi); ≤ 5 % tanpa charger: peringatan 60 dtk lalu tidur. |
| P1-7 | Pemasang: `unattended-upgrades` untuk keamanan Debian + Google Chrome + VS Code (tanpa restart otomatis). Pengaturan › Pembaruan menampilkan kapan terakhir berjalan. |
| P1-8 | Pemasang: `locales` (id_ID.UTF-8), `libreoffice-l10n-id`, kamus & font Arab (paket opsional, dilewati bila tidak ada). Bahasa Indonesia untuk sesi & aplikasi yang dibuka Atlas; **server Atlas tetap memakai bahasa bawaan** supaya keluaran alat sistem yang dibacanya tidak berubah. Papan ketik: Pengaturan › Bahasa & Papan ketik (Inggris, Arab, …), pindah dengan **Win+Spasi**, penanda (EN/AR) di bar. |
| P2-1 | Jam besar + kartu **Hari ini** (pengingat hari ini) di kiri atas desktop. |
| P2-2 | `cups cups-browsed ipp-usb printer-driver-cups-pdf` (+ gutenprint opsional); atlas masuk grup `lpadmin`; Pengaturan › Printer: daftar, tambah (printer jaringan/USB tanpa driver = "everywhere"), jadikan utama, halaman uji, hapus. |
| P2-3/4/11 | `xarchiver unzip 7zip`, `ristretto`, `galculator`, `mousepad`; masuk daftar izin Atlas ("buka kalkulator", "buka catatan"). |
| P2-5 | PrintScreen (layar penuh) dan Alt+PrintScreen (jendela aktif) → `Gambar/Tangkapan layar/…png`, kabar di notch. |
| P2-6 | Tombol Fn volume/bisu/kecerahan (`XF86*`) → Atlas → tampil sebentar di notch (OSD). Notch dipakai karena bar selalu terlihat, sedangkan desktop berada di bawah aplikasi. |
| P2-7 | Penerima notifikasi `org.freedesktop.Notifications` (Python + Gio, seperti jembatan AT-SPI) → notch + daftar notifikasi di bar. |
| P2-8 | Tombol **Jendela** di bar: daftar jendela terbuka, klik = ke depan, "Tampilkan desktop". |
| P2-9 | `~/.config/mimeapps.list`: PDF→Evince, dokumen/lembar/presentasi→LibreOffice, gambar→Ristretto, video/audio→mpv, arsip→Xarchiver, teks→Mousepad, web→Chrome. |
| P2-10 | `bluez libspa-0.2-bluetooth`; atlas grup `bluetooth`; Pengaturan › Bluetooth (nyala/mati, cari, pasangkan, sambung, lupakan) lewat `bluetoothctl`. |
| P3-1 | Pengaturan › Penyimpanan › Cadangan: pilih flashdisk, salin Dokumen/Unduhan/Gambar (`rsync`), otomatis saat flashdisk itu dicolok bila cadangan terakhir > 7 hari. |
| P3-2 | Katalog kecil (VLC, Audacity, Pinta, Thunderbird, GIMP, Inkscape, kamera) dipasang lewat **sandi admin** (helper admin yang sama dengan Mode admin, hanya nama paket dari katalog), lalu otomatis masuk daftar izin. |
| P3-3 | Penyiapan pertama: Wi-Fi → zona waktu → kunci Gemini → selesai (sekali, bisa dilewati). |
| P3-4 | Tombol "Login Claude Code" membuka terminal sebagai atlas. |
| P3-5 | Keamanan: "Masalah terakhir" (aksi gagal). |
| P3-6 | Kamera lewat katalog (P3-2). |
| P3-7 | Kendali AT-SPI ditambah Evince, Berkas, Mousepad, dan Browser (Chrome dengan `--force-renderer-accessibility`). |
| P3-8 | Pemasang: tombol daya fisik membuka **menu daya Atlas** (bukan langsung mati); tutup laptop = tidur + kunci. Pengaturan menampilkannya. |
| P3-9 | "Kembalikan pengaturan Atlas OS" (layar, skala, papan ketik, tidur) + panduan USB penyelamat (pasang ulang tanpa menghapus data). |

## 25. Tahap 6 — perangkat keras Zyrex (persiapan, 2026-11-24)

Zyrex **belum ada** di tangan Hong Khai. Semua uji sejauh ini di VirtualBox (tanpa lampu latar, Wi-Fi, baterai, kartu suara asli), jadi **belum ada satu pun bukti perangkat keras asli**. Skill `linux-hardware-integration` dari plugin: penemuan baca-saja dulu, jangan menebak chip dari nama model.

**Yang dikerjakan sekarang (pilihan Hong Khai):**
1. `stage6/hardware-inventory.sh`: skrip **baca-saja** yang mengumpulkan semua bukti ke satu file teks (chip Wi-Fi/suara/grafis + driver & firmware, `rfkill`, kartu suara, lampu latar, baterai, layar, disk, suhu, UEFI, touchpad, kamera, Bluetooth, galat firmware di log kernel). Tidak memasang dan tidak mengubah apa pun; alamat MAC dan nomor seri disamarkan. Bisa dijalankan dari **Debian live USB sebelum Windows dihapus**. Diuji di VM.
2. `stage6/windows-hardware-id.md`: cara mencatat Hardware ID Wi-Fi & Audio dari Device Manager Windows bawaan Zyrex (tanpa flashdisk).
3. Perbaikan: alat Atlas `info_pc` mencari baterai dengan aturan yang sama seperti Pengaturan (jenis Battery, bukan nama `BAT*`; baterai mouse diabaikan).

**Yang harus dibuktikan di Zyrex (daftar uji Tahap 6):** chip & driver Wi-Fi; codec suara + mikrofon internal (laptop N4020 kadang perlu `firmware-sof-signed`, belum ada di pemasang); lampu latar `intel_backlight`; nama baterai; resolusi & ukuran fisik layar (untuk skala, §24 P1-4); tidur/bangun (Wi-Fi & suara pulih); tombol Fn mengirim `XF86*`; touchpad; kamera; SSD & kesehatannya.

### 24.8 Pemeriksaan independen sebelum uji VM (2026-11-24)

Plugin `atlas-os-engineering`, mode ultracode: 4 pemeriksa (keamanan, adaptor Linux, inti + tampilan, pemasang) + 1 pemeriksa skeptis per temuan. **30 temuan: 17 terbukti, 13 terbantah. Tidak ada yang berat.** Semua yang terbukti diperbaiki:

| No | Temuan (tingkat) | Perbaikan |
|---|---|---|
| 1/4 | Cadangan gagal dicoba ulang tiap 3 dtk, popup tiap kali (sedang) | gagal = tidak dicoba otomatis lagi sampai flashdisk dicolok ulang; tombol manual tetap bisa |
| 2 | Setelah "Duplikat", mode Perluas/Hanya layar luar tetap ter-skala & buram (sedang) | setiap layar diberi `--scale 1x1` kecuali yang dicerminkan |
| 3/8 | Dua printer merek sama dapat nama antrean sama; yang kedua menimpa (sedang/ringan) | nama dari host + jalur lengkap; nama yang sudah dipakai diberi `-2`, `-3`; antrean lama tidak pernah ditimpa |
| 5 | Batas 3 salah sandi admin bisa dilewati dengan permintaan paralel (ringan) | percobaan dihitung **sebelum** sandi diperiksa (Mode admin & katalog) |
| 6 | `lpadmin` setara akses admin CUPS; `cups-browsed` membuat antrean dari jaringan pondok (ringan) | `cups-browsed` dibuang (pencarian printer lewat `avahi-daemon`); `lpadmin` **diterima sebagai risiko** demi panel Printer |
| 7 | Cadangan otomatis berjalan saat layar terkunci; folder tujuan bisa berupa tautan (ringan) | tidak saat terkunci; tujuan berupa tautan ditolak |
| 9 | Partisi LUKS/LVM/RAID ditawarkan sebagai flashdisk (ringan) | dilewati |
| 11/13/14 | Skala tampilan: tersimpan 100 % bila layar belum terbaca; reset tidak mengembalikan skala; skala disimpan sebelum berhasil dipasang (ringan) | dicoba ulang; dipasang dulu baru disimpan; reset memasang ulang |
| 12 | Pemantau flashdisk bisa berjalan ganda → popup "gagal dibuka" palsu (ringan) | satu putaran sekaligus |
| 15 | Mencolok charger menutup popup lain yang sedang terbuka (ringan) | hanya popup baterai |
| 16 | Tombol pintas yang ditekan sebelum Atlas siap membuat file biasa di jalur FIFO → semua pintasan mati sampai restart (ringan) | `/opt/atlas-os/atlas-key` hanya menulis ke FIFO yang ada & tidak pernah menunggu; Atlas mengganti file non-FIFO |
| 17 | Tombol daya diabaikan → tidak ada jalan mematikan bila Atlas/layar kunci macet (ringan) | tahan tombol daya ± 2 dtk = mati paksa (`HandlePowerKeyLongPress`) |

Catatan: no. 10 (hard disk USB terdaftar tetapi gagal di-mount karena aturan polkit `drive.removable`) **belum diubah**: udisks menganggap drive USB "removable" walau medianya tetap; dicek di uji perangkat keras (VM tidak punya USB).

### 24.9 Uji VM bersih: pemasang & flashdisk (2026-11-25)

VM `AtlasOS-Install` dipasang ulang dari nol (Debian 13 netinst + `install-atlas-os.sh`), lalu kode Atlas §24 ditimpakan dan diuji di layar VM (klik sungguhan lewat `xdotool`, tangkapan layar VirtualBox). Flashdisk uji: SanDisk Cruzer Switch 8 GB, diformat FAT32 `ATLAS-UJI` atas izin Hong Khai (isi lamanya dicadangkan dulu ke PC dan dicek hash per file), disambungkan ke VM lewat pengendali USB 3 + filter USB.

| Yang diuji | Hasil |
|---|---|
| Flashdisk dicolok → terpasang otomatis di `/media/atlas/ATLAS-UJI`, notch "Flashdisk tersambung" | lulus (± 1 dtk) |
| Menu flashdisk di bar: Buka (pengelola berkas berbahasa Indonesia di folder flashdisk), Lepas dengan aman (flashdisk dimatikan, ikon hilang) | lulus |
| Pengaturan › Penyimpanan: "Jadikan … tempat cadangan" → cadangan pertama langsung berjalan; "Cadangkan sekarang" menyalin berkas baru | lulus (`Cadangan Atlas OS/Documents/…` di flashdisk) |
| Dicolok ulang dalam 7 hari → tidak dicadangkan lagi | lulus |

Ditemukan & diperbaiki:

| No | Temuan | Perbaikan |
|---|---|---|
| 1 | Pada lebar 1280 px CSS (VM, dan laptop 11,6" FHD pada skala 1,5) kelompok kanan bar masuk ke bawah notch: ikon flashdisk & indikator EN/AR **tertutup** | `rapikanBar()`: bila menabrak notch, sembunyikan dulu angka RAM (ada di Pengaturan › Sistem), lalu tulisan "Online · Kabel" (titiknya tetap); dicek ulang saat flashdisk/papan ketik/tombol versi baru berubah dan saat ukuran jendela berubah |
| 2 | Pengaturan › Penyimpanan tetap "belum pernah" setelah cadangan otomatis selesai | acara SSE `cadangan` (mulai/selesai, juga saat gagal) + `drive`: halaman Penyimpanan membaca ulang dirinya (tidak saat ada isian yang sedang diketik) |
| 3 | Tepat setelah Atlas mulai ulang, Penyimpanan menulis "Tidak ada flashdisk tersambung" padahal flashdisk terpasang (pemantau 3 dtk belum jalan) | `daftarDrive()` memindai sekali bila pemantau belum pernah jalan; halaman Pengaturan hanya menggambar jawaban terbaru (jawaban lama yang lambat tidak menimpa) |
| 4 | Cadangan dari tombol tercatat "dari otomatis" di daftar aktivitas | sumber dicatat sesuai asal (`tombol` / `otomatis`) |
| 5 | Pemasang: Claude Code gagal terpasang sekali (unduhan), pesan galat dibuang | dicoba 3 kali, 3 baris terakhir galat ditampilkan bila tetap gagal |
| 6 | Layar tty1 penuh pesan merah `systemd-ssh-generator: Failed to query local AF_VSOCK CID` setiap paket dipasang | generator itu dimatikan (`/etc/systemd/system-generators/…` → `/dev/null`; Atlas OS tidak memakai ssh lewat vsock) + `kernel.printk = 3 4 1 3` (konsol hanya pesan kritis) |

Catatan:
- Perintah pasca-pasang VirtualBox (`--post-install-command`) tidak memasang kunci ssh VM; kunci dipasang sekali lewat sandi VM. Hanya urusan VM uji, bukan pemasang Atlas OS.
- Daftar aktivitas Keamanan memakai nama kunci mentah (`pengaturan: jadikanCadangan`, `bukaDrive`); belum diubah (kecil).
- Daftar penyiapan pertama muncul lagi setiap Atlas dimulai ulang sampai "Selesai" ditekan (sesuai rancangan: "Nanti" = tanya lagi).
- Masih harus diuji di VM: kunci layar PIN, skala tampilan, proyektor/mode layar, papan ketik Arab, notifikasi, peluncur, printer (cups-pdf), Bluetooth (VM tanpa Bluetooth), katalog aplikasi, tombol Fn/PrintScreen.

### 24.10 Jendela: minimize, maximize, ubah ukuran (uji VM 2026-11-25)

**Masalah (dilaporkan Hong Khai, terbukti di VM):** tombol Minimize dan Maximize di judul jendela tidak berbuat apa-apa, dan jendela tidak bisa diubah ukurannya. Penyebab: bagian `<mouse>` di `rc.xml` **menggantikan semua** bawaan Openbox, padahal isinya hanya Pindah, Tutup, dan klik-untuk-fokus. Judul jendela Clearlooks juga hanya ± 16 px dengan tombol ± 10 px, terlalu kecil untuk layar 11,6".

**Perbaikan:**

| Bagian | Isi |
|---|---|
| Tombol judul | Minimize = `Iconify`, Maximize = `ToggleMaximize`, Tutup; klik ganda judul = maximize/kembali |
| Ubah ukuran | tarik tepi/sudut/pegangan bawah (`Top … BRCorner` → `Resize`); Alt + tarik kiri = pindah, Alt + tarik kanan = ubah ukuran |
| Tombol keyboard | Win+↑ = maximize/kembali, Win+↓ = minimize (seperti Windows) |
| Aturan aplikasi | hanya jendela `type="normal"` dibuka maximized (dialog Simpan/Buka tidak); "kembali" = 80 % layar, di tengah |
| Tema `AtlasOS` | gelap, warna Atlas; huruf judul 11 pt (ikut `Xft.dpi`, jadi ikut skala tampilan) → judul ± 30 px di 100 %; tombol 10×10; pegangan bawah 6 px dengan sudut biru; dipasang di `/usr/share/themes/AtlasOS` (tidak bisa diubah akun atlas) |
| Mengembalikan jendela | ikon dok, daftar "Jendela" (kini "Berkas — judul"), Alt+Tab |
| Lain-lain | ikon Berkas di dok membuka folder rumah (dulu folder rilis Atlas); menu bar diberi `backdrop-filter: blur` |

Pemeriksaan independen (2 pemeriksa + verifikasi skeptis per temuan): **8 temuan, 4 terbukti, 4 terbantah.** Yang terbukti diperbaiki:

| No | Temuan | Perbaikan |
|---|---|---|
| 1 | Win+↓/↑, Alt+F4, Alt+tarik bisa mengenai jendela desktop Atlas sendiri → wallpaper, dok, bar hilang tanpa jalan kembali (sedang) | aksi itu dibungkus `<If><query><name>localhost__desktop</name></query>` (tidak berlaku untuk desktop); lapis kedua: `atlas-kiosk` mengembalikan desktop yang tersembunyi/ter-maximize dalam 2 dtk |
| 2 | Ukuran 80 % dari aturan `class="*"` ikut mengenai desktop (ringan) | aturan desktop diberi `<size>100 %</size>` |
| 3 | Pesan galat "Cadangkan" bisa tertimpa "Mencadangkan…" yang basi (sedang) | pesan dibaca setelah data halaman selesai dibaca |
| 4 | `rapikanBar` mengukur notch yang sedang beranimasi (ringan) | diukur terhadap notch kecil tetap (120 px, `NOTCH_KECIL`) |

Diuji di VM: minimize (tombol & Win+↓), kembali lewat dok / daftar Jendela, maximize ↔ kembali (jendela baru → 1024×545 di tengah), ubah ukuran dari sudut (640×480 → 953×591), Pengaturan minimize → ikon dok, Win+↓/↑ saat desktop aktif tidak berbuat apa-apa.

Catatan VM saja: Guest Additions 7.2.22 dipasang di VM uji (salin-tempel Windows → VM untuk mengisi kunci Gemini); tidak termasuk Atlas OS.

## 26. Atlas OS Live — flashdisk untuk mencoba di laptop lain (2026-11-25)

**Permintaan Hong Khai:** "format flashdisk, lalu pasang file live boot ke flashdisk, saya akan mencoba ke laptop lain". Pilihannya (2026-11-25): **Atlas OS Live** (bukan Debian Live biasa, bukan flashdisk pemasang), ditulis ke **SanDisk 8 GB ATLAS-UJI**.

### 26.1 Bentuk

- Satu berkas ISO hibrida (`atlas-os-live-amd64.iso`, ± 3 GB) yang boot dari flashdisk di laptop **UEFI maupun BIOS lama**. Atlas OS langsung jalan dari flashdisk; **disk laptop tidak disentuh**.
- Tanpa persistensi: semua perubahan (berkas, setelan, kunci Gemini yang diisi) **hilang saat dimatikan**. Ini memang untuk mencoba.
- Isi = hasil `install-atlas-os.sh` yang sama (satu sumber kebenaran), termasuk firmware Wi-Fi (Intel, Realtek, Atheros, lain-lain) supaya Wi-Fi laptop lain terbaca.
- Kode Atlas = `git archive` dari komit Atlas yang sedang dipakai (tanpa `.git`).

### 26.2 Yang sengaja TIDAK ada di ISO

| Tidak ada | Alasan |
|---|---|
| Kunci Gemini, berkas rahasia, data Atlas Hong Khai | ISO bisa terbawa/hilang; kunci diisi di Pengaturan › Atlas saat mencoba (salin-tempel dari browser Atlas OS) |
| Deploy key SiJao/atlas, kunci/sandi VM (`vm/`) | rahasia; pembaruan Atlas tidak diperlukan di live (perubahan hilang saat mati) |
| Claude Code | butuh login (rahasia di RAM); ukuran ± 200 MB |
| Akun admin | live tanpa sandi admin = Mode admin mati; `atlas` tetap tanpa hak admin |
| `live-config` (pembuat akun "user" berhak admin) | dibuang; akun `atlas` dibuat oleh pemasang seperti biasa |
| Pembaruan otomatis (apt, cek versi Atlas) | dimatikan: menulis ke RAM untuk sesuatu yang hilang saat mati |

Catatan: ISO berisi kode Atlas dari repo **privat** SiJao/atlas. Flashdisk ini milik Hong Khai; jangan dibagikan ke orang lain.

### 26.3 Cara membuat (`live/build-atlas-os-live.sh`, dijalankan di VM uji sebagai root)

1. `live-build` (Debian 13): `--distribution trixie --archive-areas "main contrib non-free-firmware" --binary-images iso-hybrid --bootloaders "grub-efi,syslinux" --debian-installer none`, nama volume `ATLAS_OS_LIVE`, zona waktu Asia/Jakarta, nama mesin `atlas-live`.
2. `includes.chroot`: `stage4/` sementara di `/root/atlas-os-stage4`, kode Atlas di `/opt/atlas/releases/<komit>` + `current`.
3. Hook chroot: `ATLAS_OS_LIVE=1 ./install-atlas-os.sh` → buang `live-config`, matikan timer pembaruan, hapus `stage4/` dan cache apt.
4. Penyesuaian pemasang untuk chroot (tetap sama untuk laptop biasa): `enable-linger` lewat berkas bila `loginctl` tidak bisa; `daemon-reload` terakhir boleh gagal; langkah Claude dilewati bila `ATLAS_OS_LIVE=1`.

### 26.4 Uji sebelum dipakai

1. ISO di-boot di VM VirtualBox baru (EFI) → harus sampai ke desktop Atlas tanpa campur tangan.
2. Baru ditulis ke flashdisk dari dalam VM uji (`dd`) **setelah** memastikan `/dev/sdX` adalah SanDisk bernomor seri `4C530001250512110243`; dibaca ulang dan dibandingkan checksum.

### 26.5 Risiko yang diketahui

- **Secure Boot:** bila laptop menolak boot, matikan Secure Boot di BIOS (bootloader bertanda tangan belum dijamin pada build ini).
- RAM laptop < 4 GB: live memakai RAM untuk semua perubahan; bisa lambat.
- Driver grafis/Wi-Fi yang tidak ada di Debian 13 tetap tidak jalan (justru ini gunanya mencoba).
- Mode admin & Ctrl+Alt+F2 tidak bisa dipakai (tidak ada akun admin di live).

### 26.6 Log otomatis ke PC Hong Khai + uji Wi-Fi (keputusan Hong Khai 2026-11-25)

Permintaan: "pasang auto log yang langsung mengirim ke laptop ini saat ada jaringan, namun jika tidak ada jaringan, simpan di flashdisk. cek fungsi wifi juga". Pilihan: **langsung lewat LAN/Wi-Fi** ke PC Windows (DESKTOP-ATLAS); isi log: **perangkat keras + uji Wi-Fi, galat sistem, pemakaian**.

**Di flashdisk:** setelah ISO ditulis, sisa ruang menjadi partisi FAT32 **`ATLAS-LOG`**. Isinya: `atlas-live-log/belum-terkirim/` dan `atlas-live-log/terkirim/`. Flashdisk ini bisa dibaca langsung di Windows.

**Di Atlas OS Live (root, `/opt/atlas-os/atlas-live-log`):**

| Kapan | Apa |
|---|---|
| 3 menit setelah menyala, lalu tiap 10 menit | ambil potret log → simpan di `belum-terkirim/` → coba kirim semua yang belum terkirim |
| jaringan tersambung (NetworkManager dispatcher) | langsung coba kirim |
| tiap menit | catat pemakaian RAM |
| saat dimatikan | potret terakhir (kalau jaringan sudah putus: tetap di flashdisk, dikirim saat menyala berikutnya) |

PC dicari berurutan: alamat yang terakhir berhasil, alamat yang dimasukkan saat membuat ISO (IP LAN PC + `DESKTOP-ATLAS.local`), lalu siaran UDP di jaringan lokal (port 4960) yang dijawab penerima. Setiap kiriman membawa **kode rahasia flashdisk** (32 byte acak, dibuat saat build). Kode itu **tidak** masuk repo publik: ada di ISO (`/etc/atlas-os/live-log.token`, root 0600) dan di PC (`C:\HISADA\atlas-live-logs\receiver.json`). Pengiriman memakai HTTP biasa di LAN. Isi log bukan rahasia; kode itu hanya membuka izin menaruh log.

**Isi satu potret (`.tar.gz`, nama `<merk-model>-<boot>-<jam>`):**
- `info.txt`: waktu, merk/model laptop, versi Atlas, kernel, lama menyala.
- `hardware.txt`: `hardware-inventory.sh` Tahap 6 (baca-saja; MAC & nomor seri disamarkan).
- `wifi.txt`:
  - kartu Wi-Fi & driver (`lspci -k`), `rfkill`, status NetworkManager;
  - daftar jaringan terlihat (nama + sinyal), tersambung/tidak, cek internet;
  - pesan firmware dari log kernel.
- `galat.txt`: peringatan/galat journal sejak menyala, layanan yang gagal.
- `xorg.txt`: baris galat/peringatan Xorg.
- `atlas.txt`: galat server Atlas.
- `pemakaian.txt`: daftar aksi Atlas (alat, label ≤ 80 huruf, status, waktu; **tanpa isi percakapan**), waktu boot (`systemd-analyze`), RAM per menit.

**Tidak pernah dikirim:** kunci Gemini, sandi Wi-Fi, isi percakapan/suara, isi berkas.

**Di PC (DESKTOP-ATLAS)** — protokol diperbarui di §26.7 (kode tidak pernah dikirim; log tidak dibuka otomatis):
- `live/log-receiver.mjs` (Node) mendengar di port 4960 (TCP untuk log, UDP untuk pencarian).
- Hanya menerima kiriman yang membawa kode yang benar; ukuran maksimal 20 MB.
- Log disimpan di `C:\HISADA\atlas-live-logs\<model>\` dan langsung dibuka (`tar`).
- Dijalankan otomatis saat login (folder Startup, tanpa jendela).
- Aturan Windows Firewall masuk TCP+UDP 4960, **hanya dari subnet lokal**. Jaringan pondok berprofil *Public*, jadi aturan berlaku untuk Public+Private. Pembuatannya perlu persetujuan UAC Hong Khai.

**Pengaman tambahan (ditemukan saat merancang):** di live, flashdisk boot sendiri tergolong "removable". Atlas akan menampilkannya di menu flashdisk, dan "Lepas dengan aman" mematikan sistem yang sedang berjalan. Maka Atlas **tidak pernah menampilkan disk yang menampung `/`, `/boot`, `/boot/efi` atau `/run/live/medium`** (berlaku juga untuk laptop biasa).

**Uji Wi-Fi:** VM tidak punya kartu Wi-Fi. Fungsi Wi-Fi diuji di laptop sungguhan lewat `wifi.txt` (kartu terdeteksi? firmware termuat? jaringan terlihat? tersambung? internet?) dan panel Jaringan Atlas.

### 26.7 Pemeriksaan independen Atlas OS Live (2026-11-25)

3 pemeriksa (keamanan & privasi, keandalan, live-build) + pemeriksa skeptis per temuan: **16 temuan, 11 terbukti, 5 terbantah.** Build pertama dihentikan (cache disimpan) dan dibangun ulang dengan perbaikan.

| No | Temuan (tingkat) | Perbaikan |
|---|---|---|
| 1 | Penerima menjalankan `tar` dengan folder kerja berisi isi arsip kiriman → `tar.exe` palsu bisa dijalankan di PC (berat) | penerima **tidak membuka apa pun**: log disimpan apa adanya (`.tar.gz`, dibuka lewat Explorer) |
| 2 | Kode terbaca akun atlas lewat baris perintah `curl` milik root (berat) | `curl` dibuang; pengirim Python membaca kode dari berkas root 0600, kode tidak pernah ada di baris perintah |
| 3 | Kode dikirim ke perangkat mana pun yang menjawab siaran UDP, lewat HTTP polos (berat → sedang) | **kode tidak pernah dikirim**: PC harus membuktikan tahu kode (HMAC atas nonce acak, UDP & `/hai`); tiap unggahan ditandatangani HMAC atas nonce sekali-pakai + nama + sha256 isi |
| 4 | Root membaca berkas milik atlas (Xorg log, audit) → symlink/FIFO bisa membuat root membaca berkas lain atau macet (sedang) | dibaca **sebagai atlas** (`runuser`) dengan batas waktu 10 dtk; baris audit bukan objek diabaikan |
| 5/9 | Penerima mati oleh permintaan aneh (`GET //`), nama perangkat Windows (`CON-…`), atau galat simpan (sedang) | semua jalur dibungkus, `clientError` ditangani, nama CON/NUL/AUX/COMx/LPTx & titik di akhir ditolak, berkas yang sudah ada tidak ditimpa |
| 6 | Log akhir saat dimatikan bisa terpotong (inventaris 180 dtk + antre 120 dtk > batas 90 dtk) (berat) | mode akhir: tanpa inventaris baru, tanpa pindai ulang Wi-Fi, antre 15 dtk, kirim 40 dtk; batas unit 150 dtk |
| 7 | Log akhir tidak dikirim bila internet tidak "full", padahal PC ada di LAN (sedang) | syarat internet dibuang; cukup cari PC |
| 8 | Flashdisk dicabut/galat I/O → potret hilang, folder sementara menumpuk (sedang) | uji tulis; mount basi dilepas → simpan di RAM; folder sementara selalu dihapus (`trap`) |
| 10 | Pemeriksaan "Atlas terpasang" selalu gagal (symlink mutlak di squashfs) (sedang) | cek folder rilis + isi `readlink` |
| 11 | Pesan "Build gagal" tidak pernah muncul (`pipefail`) (ringan) | `\|\| true` |

Tambahan dari pemeriksaan (ditolak sebagai "tidak terbukti dari kode", tetapi dicek langsung): pemasang memakai `--no-install-recommends`, sehingga `wpasupplicant` (hanya *Recommends* dari NetworkManager) bisa tidak ikut; tanpa itu **Wi-Fi tidak bisa tersambung sama sekali**. Di VM kebetulan ada, `rfkill` tidak ada. Pemasang kini memasang `wpasupplicant rfkill iw usbutils wireless-regdb` secara eksplisit (laptop biasa juga), dan build memeriksanya.

Uji otomatis (`atlas/tests/atlas-os-live.test.mjs`): kode salah ditolak, nonce sekali pakai, tidak ada yang dibuka, permintaan aneh tidak mematikan penerima, balasan UDP berupa HMAC, dan pengirim Python sungguhan ↔ penerima Node sungguhan (penerima palsu yang tidak tahu kode tidak mendapat apa-apa).

### 26.8 Kunci Gemini format baru ditolak (uji VM 2026-11-25)

**Masalah:** Pengaturan › Atlas menolak setiap kunci dengan "Bentuk kunci tidak dikenali". Kunci Gemini sekarang berbentuk **`AQ.…`** (ada titik, lebih dari 39 karakter), padahal pemeriksaan hanya mengizinkan huruf, angka, `-` dan `_` (bentuk lama `AIza…`). Salin-tempel ke VM baru bisa setelah Guest Additions dipasang.

**Perbaikan (`atlas/server/gemini-key.js`):**
- kedua bentuk diterima;
- yang sering ikut tersalin dibuang otomatis: spasi/baris baru, tanda kutip, `GEMINI_API_KEY=`, karakter tak terlihat;
- bila masih salah, Atlas menjelaskan sebabnya **tanpa memperlihatkan kunci** (terlalu pendek N karakter, berisi titik dua, alamat web, dll.);
- **sebelum disimpan, kunci dicek ke Google** (daftar model, kunci lewat header). Ditolak = tidak disimpan. Layanan belum aktif = diberi tahu. Offline = tetap disimpan dengan catatan "belum bisa dicek".

Image live dibangun ulang dengan perbaikan ini.

### 26.9 Uji boot & status (2026-11-25, dihentikan sementara)

- **Lulus:** ISO di-boot di VM uji UEFI (`AtlasOS-Live-Test`, disk dengan tata letak flashdisk). Desktop Atlas tampil < 100 dtk dengan jam benar dan jaringan tersambung. Flashdisk sistem tidak ditawarkan di menu. Partisi ATLAS-LOG dibuat dan terbaca di Windows. SanDisk ditulis dan checksum hasil baca ulang cocok.
- **Belum terbukti:** log otomatis sampai ke PC. Di VM uji tidak ada log masuk. Penyebab yang ditemukan ada di **pengaturan VM uji**, bukan di image: VM baru VirtualBox 7 punya `localhostReachable=0`, sedangkan penerima hanya mendengar di 127.0.0.1. Lanjutan: `--nat-localhostreachable1 on` di VM uji (atau penerima di 0.0.0.0 setelah aturan firewall disetujui), lalu ulangi.
- **Perbaikan berikutnya:** menu GRUB live belum boot otomatis (tunggu Enter) → beri batas waktu 5 dtk; kompresi squashfs `zstd` supaya build lebih cepat; penerima punya `ATLAS_LOG_VERBOSE=1` untuk mencatat setiap permintaan.
- Aturan Windows Firewall belum dibuat (menunggu UAC Hong Khai).
- **Pembaruan (malam yang sama): log ke PC TERBUKTI.** Aturan Windows Firewall dibuat (UAC disetujui Hong Khai, hanya subnet lokal) dan penerima mendengar di 0.0.0.0. VM uji mengirim 6 log lewat alamat LAN PC: 5 log yang menumpuk di ATLAS-LOG terkirim begitu penerima terjangkau, 1 log baru dikirim oleh dispatcher NetworkManager saat jaringan tersambung. Semua tanda tangan sah, isi lengkap.
