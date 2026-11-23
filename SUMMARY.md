# Atlas OS — Rangkuman

**Per:** 2026-11-23 · **Rinci:** [DESIGN.md](DESIGN.md) (v0.4) · **Atlas sendiri:** [../atlas/SPEC.md](../atlas/SPEC.md)

---

## 1. Apa itu Atlas OS

Laptop kedua yang saat dinyalakan **langsung masuk ke Atlas**, layar penuh. Tidak ada desktop Windows.
- Atlas menjadi satu-satunya "kulit" laptop itu.
- Pengguna hanya bisa membuka aplikasi yang diizinkan.
- Laptop pertama (Windows) tetap menjadi tempat pengembangan.

| | |
|---|---|
| Laptop target | Zyrex Sky 232 Mini: Celeron N4020, RAM 4 GB (disolder), SSD 256 GB, 11,6" FHD |
| Dasar sistem | Debian 13 minimal + X11 + Openbox |
| Tampilan | Google Chrome layar penuh (kiosk) yang menampilkan Atlas |
| Otak | tetap di awan: Gemini (depan) + Claude Code (belakang); data tetap di laptop |
| Status | Tahap 0 lulus, Tahap 1 selesai; Tahap 2–6 belum |

## 2. Rancangan sistem

```
┌──────────────────────── Laptop 2 (Atlas OS) ──────────────────────────┐
│  Debian 13 minimal ── login otomatis akun "atlas" (tanpa sudo)        │
│    └ X11 + Openbox (hotkey, jendela)                                   │
│        └ Google Chrome --kiosk ── tampilan Atlas + pengenalan suara    │
│              │ HTTP + SSE (127.0.0.1)                                  │
│        Server Node Atlas (systemd) ──┬─► Gemini API (jawab cepat)      │
│          ├ inti bersama (sama dgn Windows)  └─► Claude Code (tugas berat)│
│          └ lapisan OS: server/os/linux.js                              │
│        Aplikasi izin: Chrome, LibreOffice, media & PDF, VS Code        │
│  Skrip root tetap: update · matikan · mulai ulang                      │
│  Pemulihan: layar pemulihan · Ctrl+Alt+F2 (akun admin Hong Khai)        │
└────────────────────────────────────────────────────────────────────────┘
         ▲ tarik update (deploy key hanya-baca)
GitHub SiJao/atlas ◄── push ── Laptop 1 (Windows, pengembangan, server/os/windows.js)
```

### 2.1 Inti bersama vs lapisan OS

Kode Atlas dibagi dua:
- **Inti bersama** — sama persis di Windows dan Linux: percakapan, otak, memori, pengingat, Claude, pengaman, dan seterusnya.
- **Lapisan OS** — satu adaptor per OS dengan antarmuka yang sama (`server/os/`). Inti hanya bicara ke `platform`.

| Fungsi lapisan OS | Windows (sudah ada) | Linux (Tahap 2) |
|---|---|---|
| Menjalankan perintah | PowerShell | bash |
| Info CPU/baterai/disk/jaringan | `Get-CimInstance` | `/proc`, `/sys` |
| Daftar & tutup proses | `Get-Process` / `Stop-Process` | `ps` / `kill` |
| Volume, kecerahan, kunci layar, daya | API Windows, `shutdown.exe` | `wpctl`, `brightnessctl`, skrip root tetap |
| Buka aplikasi/file/folder/web | Start Menu, `explorer.exe` | daftar aplikasi izin, `xdg-open` |
| Tempat sampah + undo | Recycle Bin (`$I`) | Trash freedesktop (`gio trash`) |
| Kunci rahasia | DPAPI | `systemd-creds` / file terenkripsi |
| Jendela, hotkey, jendela aktif | `pembantu.exe` + WebView2 | Openbox + Chrome kiosk, `xdotool` |
| Mouse/keyboard, isi aplikasi | SendInput, UI Automation | `xdotool`, AT-SPI |
| Pengaman Claude | blok RunAs/gsudo, `taskkill` | blok sudo/su/pkexec, `kill` |

## 3. Fungsi (yang dibawa Atlas ke Atlas OS)

| Kelompok | Fungsi |
|---|---|
| Bicara & dengar | panggil "Atlas", jawab dengan suara (Gemini TTS Algenib), ketik juga bisa |
| Laptop | info laptop, buka/tutup aplikasi, buka file/folder/web, volume, kecerahan, kunci layar, matikan/mulai ulang |
| File | cari, baca (teks & Office), salin, pindah, ganti nama, hapus ke tempat sampah, **undo** |
| Pengingat & jadwal | pengingat berbunyi, ringkasan pagi, kalender & Gmail (setelah akun Google pulih) |
| Memori | ingatan jangka panjang + memori graf (orang, proyek, janji) |
| Tugas berat | diserahkan ke Claude Code: kode, analisis file, riset mendalam |
| Otomatis | alur berpemicu (file baru / jadwal / email), rencana bertahap + pemeriksa |
| Kendali | tekan/isi kontrol aplikasi, kendali mouse/keyboard, browser Atlas sendiri |
| Kabar ke HP | Telegram dua arah, email |
| Kesehatan | "periksa atlas", log audit, mode daya normal/hemat/kritis/offline, penjaga RAM |

## 4. Pengamanan & batas akses

- Akun **`atlas` tanpa sudo**. Aplikasi hanya dari **daftar izin**: Chrome, LibreOffice, media & PDF, VS Code.
- **Pagar Claude menyala:** Claude hanya boleh menulis di folder kerja, tidak bisa menjadi admin, dan pola naik-hak ditolak otomatis.
- Pekerjaan sistem hanya lewat **satu skrip root dengan perintah tetap**: update, matikan, mulai ulang.
- **Usulan perbaikan diri dimatikan** di laptop 2. Perubahan kode hanya datang dari laptop 1.
- **Penjaga RAM** (wajib bila Chrome tetap ± 500 MB): peringatan saat sisa RAM < 600 MB, tugas Claude menunggu, zram menyala.
- **Pemulihan:** systemd menyalakan ulang Atlas bila mati. Bila gagal 3× dalam 2 menit, muncul layar pemulihan (kembali ke versi lama / mulai ulang). `Ctrl+Alt+F2` membuka terminal untuk akun admin Hong Khai.

## 5. Alur update

Alurnya:
1. Laptop 1 commit dan push ke `SiJao/atlas`.
2. Laptop 2 melihat ada versi baru dan **bertanya dulu** (mode `tanya`).
3. Bila disetujui, laptop 2 menyalin versi baru ke folder rilis baru lalu menjalankan tes.
4. Bila tes lulus, Atlas pindah ke versi baru dan menyala ulang.
5. Kesehatan dicek selama 60 detik. Bila gagal, otomatis kembali ke versi lama.

`data/` tidak pernah disentuh update. Tiga rilis terakhir disimpan.

## 6. Keputusan Hong Khai (2026-11-23)

| Pertanyaan | Jawaban |
|---|---|
| Level "OS" | Linux minimal + Atlas kiosk. Ditolak: tanpa OS (bare-metal), dan mengganti explorer.exe di laptop 1 |
| Laptop | Zyrex 4 GB (saran laptop N100 8 GB tidak dipilih) |
| OS dasar | Debian 13 + X11/Openbox + Chrome kiosk |
| Aplikasi diizinkan | Chrome, LibreOffice, media & PDF, VS Code |
| Pagar Claude laptop 2 | Menyala |
| Mode update | Tanya dulu |
| Tahap 1 | Cara A (fasad); catatan hanya di folder atlas-os; commit per langkah, push di akhir |
| Penamaan | Nama file & isi kode baru dalam bahasa Inggris |
| Repo Atlas OS | `SiJao/Atlas-OS`, **publik** |

## 7. Tahapan

| Tahap | Isi | Status |
|---|---|---|
| 0 | Uji kelayakan: suara id-ID di Chrome Linux, RAM | ✅ **Lulus** di VirtualBox |
| 1 | Pisah inti & lapisan OS di repo Atlas | ✅ **Selesai**: 6 commit, di-push |
| 2 | Adaptor Linux `server/os/linux.js` | belum |
| 3 | Tampilan layar penuh (prototipe Chrome → dipilih) | belum |
| 4 | Skrip pemasang Debian → Atlas OS, ukur RAM asli | belum |
| 5 | Alur update + rollback | belum |
| 6 | Pengamanan & uji pakai harian | belum |

### Hasil penting sejauh ini

- **Suara:** Google Chrome 158 di Linux mengenali "atlas buka peringatan hari ini" dalam 2,1 detik. "Pengingat" salah dengar jadi "peringatan", hal yang biasa di Web Speech.
- **RAM (VM 3 GB):** desktop live 656 MB, Chrome 141 → **520 MB** setelah mendengar, total ± 2 GB. Lebih tinggi dari perkiraan, sebagian karena keadaan uji (sistem live, tanpa GPU). Angka pasti diukur di Tahap 4.
- **Tahap 1:** 262 tes, 261 lulus. Yang gagal hanya `tutup_aplikasi`: kena batas 30 detik karena PowerShell lambat. Ini sudah terjadi sebelum ada perubahan, dan tes itu lulus dengan batas lebih longgar. Tes pagar `os-boundary` menjaga agar kode Windows tidak masuk lagi ke inti.

## 8. Risiko & yang masih terbuka

1. **RAM 4 GB** dengan LibreOffice/VS Code/Chrome/Claude bersamaan. Pengaman §5.1 kemungkinan wajib.
2. **Membaca isi aplikasi** di Linux (AT-SPI) lebih lemah daripada UI Automation di Windows.
3. **Dua OS** harus dirawat dan diuji terus.
4. **Belum terpasang:** jendela native (`pembantu.exe`) belum punya padanan Linux. Ini pekerjaan terbesar Tahap 2.
5. **Tampilan layar penuh** belum dirancang (§8 DESIGN).

## 9. Lokasi file

| Apa | Di mana |
|---|---|
| Repo proyek ini | `SiJao/Atlas-OS` (publik) |
| Desain lengkap | `C:\HISADA\atlas-os\DESIGN.md` |
| Rangkuman ini | `C:\HISADA\atlas-os\SUMMARY.md` |
| Perlengkapan & hasil Tahap 0 | `C:\HISADA\atlas-os\stage0\` (STEPS.md, test.sh, voice-test.html, test-server.mjs, stage0-result.txt) |
| Unduhan (ISO Debian, Rufus, pemasang VirtualBox) | `C:\HISADA\atlas-os\stage0\downloads\` (lokal saja, tidak ikut repo) |
| Mesin virtual uji | VirtualBox → **AtlasOS-Test** |
| Lapisan OS (kode) | `C:\HISADA\atlas\server\os\` (repo `SiJao/atlas`) |
| Tes pagar | `C:\HISADA\atlas\tests\os-boundary.test.mjs` |
