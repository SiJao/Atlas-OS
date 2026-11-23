# Atlas OS — Dokumen Desain

**Versi:** 0.6
**Tanggal:** 2026-11-24
**Status:**
- **Tahap 0 LULUS** di VirtualBox (§15): pengenalan suara Bahasa Indonesia jalan di Google Chrome Linux.
- **Tahap 1 SELESAI** (§16): lapisan OS `server/os/` di repo Atlas, 6 commit, sudah di-push.
- **Tahap 2 SELESAI** (§17): adaptor Linux + pengganti pembantu.exe; 276 tes Windows lulus, uji asap VM 18/18.
- **Tahap 3 SELESAI** (§18): layar utama tata letak A (dipilih Hong Khai) sebagai mode kiosk `/?kiosk=1`; 281 tes Windows lulus, diuji dengan Chrome `--kiosk` di VM.
- Berikutnya: Tahap 4 (skrip pemasang Debian → Atlas OS, ukur RAM asli).
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
| Jendela & tampilan | `pembantu.exe` + WebView2, notch, orb | Google Chrome `--kiosk` layar penuh, dijalankan oleh Openbox |
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
| `openChromeApp`, `findChrome` | `google-chrome --kiosk` (Atlas OS) atau `--app` (desktop biasa) |

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
