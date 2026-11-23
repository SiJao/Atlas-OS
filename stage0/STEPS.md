# Tahap 0 — Uji kelayakan Atlas OS

Tujuan: memastikan **pengenalan suara Bahasa Indonesia jalan di Linux** dan mengukur RAM, **sebelum** laptop kedua dibeli. Lihat [../DESIGN.md](../DESIGN.md) §6 dan §12.

**Windows dan isi disk laptop TIDAK diubah.** Linux berjalan dari flashdisk dan hanya memakai RAM.
Satu-satunya yang terhapus: **seluruh isi flashdisk** yang dipakai.

## Isi folder

| File | Guna |
|---|---|
| `downloads/debian-live-13.8.0-amd64-lxde.iso` | Debian 13 live, desktop LXDE (memakai Openbox, sama dengan rancangan) |
| `downloads/rufus-4.16p.exe` | Pembuat flashdisk bootable (portabel, tanpa pasang) |
| `test.sh` | Skrip uji yang dijalankan di Linux |
| `voice-test.html` | Halaman uji: pengeras suara, mikrofon, pengenalan suara id-ID |

## Cara 1 — VirtualBox (tanpa flashdisk, dipakai sekarang)

Sudah disiapkan 2026-11-23: VirtualBox 7.2.22 terpasang, mesin virtual **AtlasOS-Test** (Debian live LXDE, RAM 3 GB, 2 CPU, mikrofon & suara aktif, tanpa hard disk virtual).

1. **Tutup aplikasi berat** (Chrome dengan banyak tab, Kantor Pixel). VM memakai 3 GB RAM.
2. Pastikan **server uji** berjalan di Windows:
   ```
   node C:\HISADA\atlas-os\stage0\test-server.mjs
   ```
   Server ini hanya mendengar di 127.0.0.1. Dari dalam VM alamatnya `http://10.0.2.2:4952`.
3. Buka VirtualBox → pilih **AtlasOS-Test** → **Start**.
4. Di menu Debian pilih **"Live system (amd64)"**, tunggu desktop LXDE muncul.
5. Buka **LXTerminal** (menu → System Tools), lalu ketik:
   ```
   sudo apt-get update && sudo apt-get install -y wget curl python3
   mkdir ~/stage0 && cd ~/stage0
   wget http://10.0.2.2:4952/test.sh http://10.0.2.2:4952/voice-test.html
   bash test.sh
   ```
6. Kerjakan halaman uji nomor 1 → 4 (lihat bagian C langkah 5), lalu tekan Enter di terminal.
7. Hasil otomatis terkirim ke Windows sebagai `stage0\stage0-result.txt`.
8. Matikan VM: menu VirtualBox **Machine → ACPI Shutdown**, atau tutup jendela → *Power off*.

Catatan:
- Bila mikrofon di VM tidak menangkap suara, cek di jendela VM: **Devices → Audio → Audio Input** harus tercentang.
- Angka RAM di VM tetap berguna untuk Linux + Chrome, tetapi angka pasti harus diukur ulang di laptop asli.

## Cara 2 — Flashdisk (nanti, di laptop asli)

## A. Buat flashdisk (di Windows, ± 10 menit)

1. Colokkan flashdisk **≥ 8 GB yang isinya boleh dihapus**.
2. Jalankan `downloads\rufus-4.16p.exe` (Windows akan meminta izin admin, klik **Ya**).
3. **Device:** pilih flashdisk. **Periksa ukurannya**, jangan sampai salah pilih.
4. **Boot selection:** pilih file ISO Debian di atas.
5. Biarkan pilihan lain bawaan (Partition scheme **GPT**, target **UEFI**), klik **START**.
6. Bila Rufus bertanya mode tulis, pilih **"Write in ISO Image mode (Recommended)"**. Dengan mode ini hasil uji bisa disimpan kembali ke flashdisk.
7. Setelah selesai, **salin `test.sh` dan `voice-test.html` ke flashdisk** (langsung di akar, bukan di folder).

## B. Boot ke Linux

1. Matikan laptop (Shut down, bukan Restart).
2. Nyalakan sambil menekan **F12** berulang kali (Lenovo: menu boot). Bila tidak muncul, coba **Fn+F12**, atau tombol kecil **Novo** (lubang kecil di samping laptop) → *Boot Menu*.
3. Pilih flashdisk (biasanya bertuliskan `EFI USB Device`).
4. Di menu Debian, pilih **"Live system (amd64)"** (yang paling atas).
5. Tunggu desktop LXDE muncul (± 1–2 menit).

Bila muncul pesan Secure Boot/galat: foto layarnya, matikan laptop, cabut flashdisk, nyalakan lagi ke Windows, dan kabari saya.

## C. Jalankan uji (± 10 menit)

1. Sambungkan **Wi-Fi** lewat ikon jaringan di pojok kanan bawah.
2. Buka **Terminal** (menu → System Tools → LXTerminal).
3. Ketik:
   ```
   bash /run/live/medium/test.sh
   ```
4. Skrip memasang Google Chrome (hanya di RAM) dan membuka halaman uji.
5. Di halaman uji, kerjakan nomor **1 → 4**:
   - Bunyikan, lalu jawab terdengar atau tidak.
   - Mulai mikrofon (izinkan bila ditanya), bicara, lihat batang bergerak.
   - Mulai dengar, ucapkan **"Atlas, buka pengingat hari ini"**.
   - Tekan **Simpan hasil**.
6. Kembali ke terminal dan tekan **Enter**.
7. Hasil tersimpan di flashdisk sebagai `stage0-result.txt`. Bila skrip bilang gagal menyimpan, **foto layar terminal**.

## D. Kembali ke Windows

1. Matikan laptop dari menu LXDE (Logout → Shutdown).
2. Cabut flashdisk saat layar gelap, lalu nyalakan laptop seperti biasa.
3. Colokkan flashdisk lagi di Windows dan beri tahu saya. Saya baca `stage0-result.txt` dan menulis kesimpulannya di DESIGN.md.

## Arti hasil

| Hasil pengenalan suara | Langkah berikutnya |
|---|---|
| **OK**, teks Bahasa Indonesia muncul | Rancangan Atlas OS jalan terus → Tahap 1 |
| **GAGAL: network / not-allowed / tidak ada API** | Rancangan harus diputuskan ulang **sebelum membeli laptop** |
