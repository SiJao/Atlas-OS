# Atlas OS — panduan penyelamatan (DESIGN §24 P3-9)

Urutan dari yang paling ringan. Coba nomor 1 dulu.

## 1. Atlas bermasalah, laptop masih menyala

- Layar **pemulihan** muncul sendiri bila Atlas gagal 3 kali. Di sana ada tombol **Mulai ulang Atlas**, **Kembali ke versi sebelumnya**, dan **Mulai ulang laptop**.
- Pengaturan aneh (layar terlalu besar/kecil, papan ketik salah, layar cepat mati): **Pengaturan › Sistem › Kembalikan pengaturan Atlas OS**. Dokumen dan aplikasi tidak disentuh.

## 2. Lupa PIN kunci layar

1. Tekan **Ctrl + Alt + F2**, masuk dengan akun **admin**.
2. Ketik:
   ```
   sudo rm /home/atlas/.config/atlas-os/pin.hash
   sudo pkill -x xsecurelock
   ```
3. Tekan **Ctrl + Alt + F1** untuk kembali ke layar Atlas. Atur PIN baru di Pengaturan › Keamanan.

## 3. Layar Atlas tidak muncul sama sekali

1. **Ctrl + Alt + F2**, masuk sebagai admin.
2. Lihat penyebabnya: `sudo -u atlas XDG_RUNTIME_DIR=/run/user/$(id -u atlas) journalctl --user -u atlas -n 50`
3. Jalankan pemasang lagi dari folder `stage4` (aman diulang; data dan versi Atlas yang terpasang tetap):
   ```
   sudo ./install-atlas-os.sh
   ```

## 4. Sistem rusak, perlu dipasang ulang: selamatkan dokumen dulu

Memasang ulang Debian **menghapus seluruh isi SSD**. Sebelum itu:

1. Bila ada **Cadangan dokumen** (Pengaturan › Penyimpanan), file ada di flashdisk, folder `Cadangan Atlas OS`.
2. Bila belum ada cadangan: boot dari **USB Debian live** (sama dengan uji Tahap 0), buka pengelola berkas, buka SSD laptop, salin folder `home/atlas/Documents`, `Downloads`, `Desktop`, dan `Gambar` ke flashdisk lain.
3. Pasang ulang: USB Debian netinst → Debian minimal → `sudo ./install-atlas-os.sh --deploy-key …` (DESIGN §19). Kunci Gemini, PIN, Wi-Fi, dan login Claude diisi lagi; dokumen disalin kembali dari flashdisk.
