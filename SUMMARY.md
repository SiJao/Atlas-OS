# Atlas OS — Rangkuman

**Per:** 2026-11-24 · **Rinci:** [DESIGN.md](DESIGN.md) (v0.9) · **Atlas sendiri:** repo private `SiJao/atlas` (SPEC.md)

---

## 1. Apa itu Atlas OS

Laptop kedua yang saat dinyalakan **langsung masuk ke Atlas**, layar penuh, tanpa desktop.
- Atlas menjadi satu-satunya "kulit" laptop itu. Pengguna hanya bisa membuka aplikasi yang diizinkan.
- Laptop pertama (Windows) tetap menjadi tempat pengembangan. Versi baru Atlas sampai ke laptop 2 lewat pembaruan yang selalu minta izin.

| | |
|---|---|
| Laptop target | Zyrex Sky 232 Mini: Celeron N4020, RAM 4 GB (disolder), SSD 256 GB, 11,6" FHD |
| Dasar sistem | Debian 13 minimal + X11 + Openbox (tanpa desktop) |
| Tampilan | Google Chrome layar penuh (kiosk) yang menampilkan layar utama Atlas |
| Otak | tetap di awan: Gemini (depan) + Claude Code (belakang); data tetap di laptop |
| Status | **Tahap 0–5 selesai** + perbaikan dari uji coba Hong Khai, teruji di VirtualBox. Berikutnya: **tampilan desktop baru** dari gambar Hong Khai (§22 DESIGN), lalu **Tahap 6** di laptop Zyrex |

## 2. Rancangan sistem

```
┌──────────────────────────── Laptop 2 (Atlas OS) ─────────────────────────────┐
│ Debian 13 minimal → login otomatis tty1 akun "atlas" (tanpa sudo)            │
│   └ startx → Openbox terkunci (tanpa menu/panel; Ctrl+Alt+Spasi, Alt+Tab)     │
│       └ atlas-kiosk → Chrome --kiosk /?kiosk=1 (dibuka lagi bila tertutup)    │
│             │ HTTP + SSE (127.0.0.1:4950)                                      │
│ systemd --user:                                                               │
│   atlas.service ── server Node Atlas ──┬─► Gemini API                         │
│     ├ inti bersama (sama dgn Windows)  └─► Claude Code                        │
│     └ lapisan OS: server/os/linux.js + linux-helper.js + linux-atspi.py        │
│   gagal 3× → atlas-recovery.service (halaman pemulihan :4951)                 │
│   atlas-update-check.timer (menyala + tiap 6 jam) → atlas-update-install/…    │
│ Aplikasi izin: Chrome, LibreOffice, mpv, Evince, PCManFM, VS Code             │
│ Ctrl+Alt+F2 → terminal teks akun admin Hong Khai                               │
└───────────────────────────────────────────────────────────────────────────────┘
          ▲ cek & tarik versi baru (deploy key hanya-baca, host GitHub di-pin)
GitHub SiJao/atlas ◄── push ── Laptop 1 (Windows, pengembangan, server/os/windows.js)
```

### 2.1 Inti bersama vs lapisan OS

Kode Atlas dibagi dua (Tahap 1–2):
- **Inti bersama**, sama persis di kedua OS: percakapan, otak, memori, pengingat, Claude, pengaman, dan seterusnya.
- **Lapisan OS** `server/os/`, satu adaptor per OS dengan antarmuka sama. Inti hanya bicara ke `platform`. Tes `os-boundary` menjaga agar kode khusus Windows tidak masuk lagi ke inti.

| Fungsi lapisan OS | Windows | Linux (Atlas OS) |
|---|---|---|
| Menjalankan perintah | PowerShell | bash |
| Info CPU/baterai/disk/jaringan | `Get-CimInstance` | `/proc`, `/sys`, `df` |
| Daftar & tutup proses | `Get-Process` / `Stop-Process` | `ps` / sinyal |
| Volume, kecerahan, kunci layar | API Windows | `wpctl`, `brightnessctl`, `xdg-screensaver` |
| Daya (mati/mulai ulang/tidur) | `shutdown.exe` | `systemctl` (tanpa root), jeda 60 dtk diatur Atlas |
| Buka aplikasi/file/folder/web | Start Menu, `explorer.exe` | daftar aplikasi izin, `xdg-open` |
| Tempat sampah + undo | Recycle Bin (`$I`) | Trash freedesktop (`gio trash`, `.trashinfo`) |
| Kunci rahasia | DPAPI | `systemd-creds --user` |
| Jendela, hotkey, jendela aktif, waktu diam | `pembantu.exe` + WebView2 | `linux-helper.js`: `xdotool`, `xprintidle`, FIFO hotkey |
| Mouse/keyboard + tombol darurat | SendInput + hook | `xdotool` + `xinput` (input Atlas sendiri diabaikan) |
| Isi aplikasi (tekan/isi kontrol) | UI Automation | AT-SPI (`linux-atspi.py`) |
| Wi-Fi | menu Windows | panel Wi-Fi Atlas (NetworkManager) |
| Pengaman Claude | blok RunAs/gsudo | blok sudo/su/pkexec/doas, pola bahaya bash |

## 3. Layar utama (Tahap 3, tata letak A "Pusat" pilihan Hong Khai)

- Kiri atas: **jam & tanggal**. Kiri: kartu **"Hari ini"** (pengingat hari ini).
- Tengah: **orb** Atlas dan status ("Ucapkan "Atlas"…", Mendengarkan, Berpikir, Berbicara, Claude bekerja).
- Kanan: **percakapan + kolom ketik**. Kartu izin juga muncul di sini.
- Kanan atas: Online, baterai, RAM, tombol **Versi baru · pasang** (bila ada), **Wi-Fi**, **Daya**.
- Bawah: **dok 8 aplikasi**: Browser, Dokumen, Lembar kerja, Presentasi, Kode, Video, PDF, Berkas. Dok dibuka lewat router lokal, tanpa Gemini.

## 4. Fungsi (yang dibawa Atlas ke Atlas OS)

| Kelompok | Fungsi |
|---|---|
| Bicara & dengar | panggil "Atlas" atau Ctrl+Alt+Spasi, jawab dengan suara (Gemini TTS Algenib), ketik juga bisa |
| Laptop | info laptop, buka/tutup aplikasi, volume, kecerahan, kunci layar, matikan/mulai ulang/tidur (**langsung**; lewat ucapan dengan kartu izin), panel **Jaringan** (kabel/LAN + Wi-Fi), **Mode admin** |
| File | cari, baca (teks & Office), salin, pindah, ganti nama, hapus ke tempat sampah, **undo** |
| Pengingat & jadwal | pengingat berbunyi, ringkasan pagi, kalender & Gmail (setelah akun Google pulih) |
| Memori | ingatan jangka panjang + memori graf (orang, proyek, janji) |
| Tugas berat | diserahkan ke Claude Code: kode, analisis file, riset mendalam |
| Otomatis | alur berpemicu (file baru / jadwal / email), rencana bertahap + pemeriksa |
| Kendali | tekan/isi kontrol LibreOffice (AT-SPI), kendali mouse/keyboard, browser Atlas sendiri |
| Kabar ke HP | Telegram dua arah, email |
| Kesehatan | "periksa atlas", log audit, mode daya normal/hemat/kritis/offline, penjaga RAM |
| **Pembaruan** | "cek pembaruan", "pasang pembaruan", "kembali ke versi sebelumnya" |

## 5. Pengamanan & batas akses

- Akun **`atlas` tanpa sudo**, sandi terkunci (hanya login otomatis di layar). Akun admin terpisah untuk perawatan (`Ctrl+Alt+F2`).
- **Aplikasi hanya dari daftar izin.** Openbox tanpa menu klik-kanan dan tanpa panel.
- **Pagar Claude menyala:** Claude hanya menulis di folder kerja, tidak bisa naik hak; pola sudo/su/pkexec ditolak otomatis.
- **Kartu izin menyala** untuk aksi yang mengubah sesuatu (termasuk pembaruan dan daya lewat ucapan). Menu daya di layar langsung dijalankan, karena memilihnya sudah merupakan konfirmasi.
- **Tombol layar** (dok, daya, pembaruan) tidak menulis di obrolan. Berhasil tanpa tanda; gagal atau aplikasi crash → **popup**.
- **Mode admin:** sandi diketik di kotak bertitik (●●●), diperiksa sistem, lalu terminal admin terbuka. Sandi tidak disimpan dan tidak dicatat; 3× salah → jeda 1 menit. Chrome tidak ditawari menyimpan sandi.
- **polkit:** aturan khusus akun `atlas` hanya untuk daya dan jaringan, karena Atlas berjalan sebagai layanan latar.
- **Usulan perbaikan diri mati** di laptop 2. Kode hanya datang dari laptop 1 lewat GitHub.
- **Wi-Fi:** sandi tidak disimpan Atlas, tidak dicatat, dan tidak dikirim ke Gemini. Nama jaringan ditampilkan sebagai teks, bukan HTML.
- **Kunci rahasia** dienkripsi `systemd-creds`, diisi di layar laptop 2, **tidak pernah disalin** dari laptop 1.
- **Pemulihan:** Atlas mati → dinyalakan ulang. Gagal 3× dalam 2 menit → **halaman pemulihan** dengan tombol: mulai ulang Atlas / kembali ke versi sebelumnya / mulai ulang laptop.
- **zram** 50 % RAM + penjaga RAM Atlas.

## 6. Alur pembaruan (Tahap 5)

1. Laptop 1 commit dan push ke `SiJao/atlas`.
2. Laptop 2 mengecek **saat menyala dan tiap 6 jam** (deploy key hanya-baca). Bila ada versi baru, Atlas mengabari dan tombol **"Versi baru · pasang"** muncul.
3. Tombol atau ucapan "pasang pembaruan" memunculkan **kartu izin** berisi daftar perubahan. Update ditunda bila Claude sedang bekerja atau ada kartu lain terbuka.
4. **Uji jalan:** versi baru dinyalakan di port cadangan dengan salinan data, tanpa layanan latar. Gagal → berhenti, versi lama tetap jalan.
5. **Data dicadangkan** (3 cadangan terakhir), lalu Atlas pindah ke versi baru dan menyala ulang.
6. **Kesehatan dicek 60 detik.** Gagal → **otomatis kembali** ke versi lama; versi itu ditandai buruk dan tidak ditawarkan lagi.
7. Atlas mengabari hasilnya. "Kembali ke versi sebelumnya" lewat ucapan, kartu izin, atau halaman pemulihan.

`atlas-data` tidak pernah diubah oleh update. Tiga rilis terakhir disimpan.

## 7. Memasang Atlas OS

1. Pasang **Debian 13 netinst** tanpa desktop (pilih hanya "standard system utilities"; nama akun admin bebas, kecuali `admin` yang dicadangkan Debian).
2. Salin folder `stage4/` dan kunci deploy ke laptop, lalu jalankan:
   ```
   sudo ./install-atlas-os.sh --deploy-key /path/atlas_deploy_key
   ```
   Durasinya ± 7 menit (unduhan ± 1 GB). Aman dijalankan ulang, dan tidak mengganti versi Atlas yang sudah terpasang.
3. Mulai ulang laptop. Layar langsung masuk ke Atlas.
4. Sekali saja: isi kunci Gemini di layar Atlas, dan login Claude Code (`sudo -u atlas -i ~/.local/bin/claude`).

## 8. Keputusan Hong Khai

| Pertanyaan | Jawaban |
|---|---|
| Level "OS" | Linux minimal + Atlas kiosk. Ditolak: tanpa OS (bare-metal), dan mengganti explorer.exe di laptop 1 |
| Laptop | Zyrex 4 GB (saran laptop N100 8 GB tidak dipilih) |
| OS dasar | Debian 13 + X11/Openbox + Chrome kiosk |
| Aplikasi diizinkan | Chrome, LibreOffice, media & PDF, VS Code |
| Pagar Claude laptop 2 | Menyala |
| Mode update | Tanya dulu |
| Tahap 1 | Cara A (fasad); catatan hanya di folder atlas-os; commit per langkah, push di akhir |
| Tahap 2 | Kunci rahasia `systemd-creds`; kontrol aplikasi AT-SPI dikerjakan langsung; VM berdisk |
| Tahap 3 | Tata letak **A · Pusat**; mode kiosk di halaman Atlas yang ada; kolom ketik di bawah percakapan |
| Tahap 4 | Panel Wi-Fi di layar Atlas; deploy key hanya-baca (dipasang lewat API); uji di VM baru bersih |
| Tahap 5 | Gerbang = uji jalan; cek saat menyala + tiap 6 jam; cadangan data 3 terakhir |
| Penamaan | Nama file & isi kode baru dalam bahasa Inggris |
| Repo Atlas OS | `SiJao/Atlas-OS`, **publik** (kode Atlas tetap di repo private) |

## 9. Tahapan

| Tahap | Isi | Status |
|---|---|---|
| 0 | Uji kelayakan: suara id-ID di Chrome Linux, RAM | ✅ **Lulus** di VirtualBox |
| 1 | Pisah inti & lapisan OS di repo Atlas | ✅ **Selesai**: 6 commit |
| 2 | Adaptor Linux + pengganti pembantu.exe + AT-SPI | ✅ **Selesai**: uji VM dengan program Linux sungguhan 18/18 |
| 3 | Layar utama layar penuh | ✅ **Selesai**: tata letak A, mode kiosk `/?kiosk=1`, diuji dengan Chrome `--kiosk` |
| 4 | Skrip pemasang Debian → Atlas OS, ukur RAM | ✅ **Selesai**: VM bersih menyala sendiri ke Atlas; RAM 715 MB diam |
| 5 | Alur update + rollback | ✅ **Selesai**: update sungguhan dari GitHub, versi rusak, kembali otomatis, alur dari layar |
| 6 | Uji di laptop asli & pakai harian | ⏳ menunggu laptop Zyrex |

### Hasil penting

- **Suara (Tahap 0):** Google Chrome di Linux mengenali "atlas buka peringatan hari ini" dalam 2,1 dtk. "Pengingat" salah dengar jadi "peringatan", hal yang biasa di Web Speech.
- **RAM sistem terpasang (Tahap 4, VM 3 GB tanpa GPU):**

  | Keadaan | Total terpakai | Chrome kiosk | Atlas | Xorg+Openbox | LibreOffice |
  |---|---|---|---|---|---|
  | Layar utama, diam | **715 MB** | 569 | 73 | 50 | – |
  | Mikrofon menyala | **782 MB** | 604 | 55 | 55 | – |
  | LibreOffice Calc terbuka | **784 MB** | 407 | 73 | 109 | 204 |

  Dengan RAM 4 GB di Zyrex, sisa ± 3 GB saat diam. Angka ± 2 GB di Tahap 0 ternyata akibat sistem live.
- **Pemasang (Tahap 4):** ± 7 menit pertama kali, 21 dtk saat diulang. Dari Debian polos (245 MB, 329 paket) sampai layar Atlas tanpa disentuh.
- **Pembaruan (Tahap 5):** update dari GitHub 68 dtk; versi rusak dihentikan uji jalan; versi yang mati setelah 25 dtk dikembalikan otomatis dalam ± 35 dtk.
- **Tes Atlas di Windows:** 292/292 lulus. Tampilan notch Windows tidak berubah.
- **Bug yang ditemukan uji VM dan sudah diperbaiki:** ± 25. Contohnya:
  - AT-SPI macet di lembar Calc;
  - pembaca hotkey tertinggal setelah Atlas mati;
  - kabar "Ada versi baru" palsu setelah update;
  - "kembali" sempat memilih rilis rusak;
  - daftar aplikasi kendali masih memakai nama Windows;
  - template VirtualBox ikut memasang GNOME.

## 10. Risiko & yang masih terbuka

1. **Belum teruji di perangkat asli (Tahap 6):** Wi-Fi sungguhan, kecerahan, speaker, tombol darurat dengan mouse/keyboard fisik, firmware Wi-Fi Zyrex, suara + mikrofon bersama layar utama.
2. **Chrome kiosk ± 400–600 MB** di VM tanpa GPU (bagian terbesar RAM). Di Intel UHD 600 asli diharapkan lebih kecil.
3. **Membaca isi aplikasi** lewat AT-SPI lebih lemah daripada UI Automation di Windows. Teruji di LibreOffice Calc; aplikasi lain belum.
4. **Dua OS** harus dirawat dan diuji terus. Tes Windows berjalan di laptop 1, uji Linux di VM.
5. **Riwayat Atlas:** commit `d297c60` tidak bisa dijalankan sendirian (memanggil file dari commit berikutnya). Tidak berdampak, karena laptop 2 selalu memakai ujung `main`.
6. **Kalender Google** belum tampil di "Hari ini", karena menunggu akun Google pulih.

## 11. Lokasi file

| Apa | Di mana |
|---|---|
| Repo proyek ini | `SiJao/Atlas-OS` (publik) |
| Desain lengkap | `DESIGN.md` (v0.9) |
| Rangkuman ini | `SUMMARY.md` |
| Uji kelayakan (Tahap 0) | `stage0/` (STEPS.md, test.sh, voice-test.html, test-server.mjs, stage0-result.txt) |
| Uji adaptor Linux (Tahap 2) | `stage2/` (provision-vm.sh, smoke-test.sh, real-check.mjs, atspi-diag.sh) |
| Prototipe & uji layar utama (Tahap 3) | `stage3/` (home-prototype.html, kiosk-check.sh, shots/) |
| **Pemasang Atlas OS** (Tahap 4–5) | `stage4/install-atlas-os.sh` + `stage4/files/` (atlas-kiosk, recovery-server.mjs, atlas-update.mjs) |
| Uji pemasang & pembaruan | `stage4/post-install-check.sh`, `stage4/update-failure-test.sh`, `stage4/debian-preseed-minimal.cfg`, tangkapan layar `stage4/*.png` |
| Kode Atlas (lapisan OS, layar utama, pembaruan) | repo private `SiJao/atlas`: `server/os/`, `server/update.js`, `web/` |
| Lokal saja (tidak ikut repo) | `stage0/downloads/` (ISO, installer), `vm/` (kunci SSH VM, **kunci deploy**, sandi VM) |
| Mesin virtual uji | VirtualBox: **AtlasOS-Test** (live, Tahap 0) dan **AtlasOS-Install** (Atlas OS terpasang, Tahap 4–5) |
