#!/bin/bash
# Uji kelayakan Atlas OS — Tahap 0 (DESIGN.md §12).
# Dijalankan di sesi Debian live (USB). TIDAK memasang apa pun ke disk laptop:
# semua yang dipasang hanya hidup di RAM dan hilang saat laptop dimatikan.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
HASIL="$HOME/stage0-result.txt"
PORT=4951
UJI="/tmp/atlas-test"

catat() { echo "$*" | tee -a "$HASIL"; }
ram()   { free -m | awk '/^Mem:/ {print "terpakai " $3 " MB, tersedia " $7 " MB dari " $2 " MB"}'; }
# Proses $1 beserta semua turunannya.
turunan() { echo "$1"; local c; for c in $(pgrep -P "$1"); do turunan "$c"; done; }
# Jumlah PSS (bagian RAM yang benar-benar dipakai) satu pohon proses.
pss() { local tot=0 p v; for p in $(turunan "$1"); do v=$(sudo awk '/^Pss:/ {print $2}' /proc/$p/smaps_rollup 2>/dev/null); tot=$((tot + ${v:-0})); done; echo "$((tot / 1024)) MB"; }

: > "$HASIL"
catat "=== Uji Tahap 0 Atlas OS — $(date '+%F %T') ==="
catat "Kernel: $(uname -r)"
catat "CPU: $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2-)"
catat "RAM dasar (desktop LXDE/Openbox, sebelum Chrome): $(ram)"
PERLU=""
for a in curl python3 arecord; do command -v $a >/dev/null || PERLU="$PERLU $a"; done
if [ -n "$PERLU" ]; then
  catat "Memasang alat yang kurang (hanya di RAM):$PERLU"
  PERLU=${PERLU/arecord/alsa-utils}
  sudo apt-get update -qq && sudo apt-get install -y -qq $PERLU >/dev/null || catat "GAGAL memasang:$PERLU"
fi
catat "Kartu suara (rekam):"; arecord -l 2>&1 | grep -E '^card' | tee -a "$HASIL" || catat "  (tidak ada)"

catat ""; catat "--- Internet ---"
if curl -sS -m 10 -o /dev/null https://www.google.com; then catat "OK"; else catat "GAGAL: tidak ada internet. Sambungkan Wi-Fi dulu (ikon jaringan di pojok), lalu jalankan ulang."; exit 1; fi

catat ""; catat "--- Memasang Google Chrome (hanya di RAM) ---"
if ! command -v google-chrome >/dev/null; then
  curl -fL -o /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb || { catat "GAGAL unduh Chrome"; exit 1; }
  sudo apt-get update -qq && sudo apt-get install -y -qq /tmp/chrome.deb >/dev/null || { catat "GAGAL pasang Chrome"; exit 1; }
fi
catat "$(google-chrome --version)"

catat ""; catat "--- Halaman uji ---"
cd "$DIR" && python3 -m http.server $PORT --bind 127.0.0.1 >/dev/null 2>&1 &
SERVER=$!
sleep 1
rm -rf "$UJI"; mkdir -p "$UJI"
google-chrome --user-data-dir="$UJI" --no-first-run --no-default-browser-check \
  --app="http://127.0.0.1:$PORT/voice-test.html" >/dev/null 2>&1 &
CHROME=$!
sleep 8
catat "RAM Chrome (halaman uji terbuka): $(pss $CHROME)"
catat "RAM total sekarang: $(ram)"

echo
echo ">>> Kerjakan langkah 1-4 di jendela Chrome (bunyi, mikrofon, dengar, simpan)."
echo ">>> Setelah menekan 'Simpan hasil', kembali ke sini dan tekan Enter."
read -r _

catat "RAM Chrome (setelah pengenalan suara): $(pss $CHROME)"
catat "RAM total setelah uji: $(ram)"
catat ""; catat "--- Hasil halaman uji ---"
J=$(ls -t "$HOME"/Downloads/voice-result*.json 2>/dev/null | head -1)
if [ -n "$J" ]; then cat "$J" | tee -a "$HASIL"; else catat "(voice-result.json tidak ditemukan; tombol Simpan belum ditekan?)"; fi

kill $SERVER 2>/dev/null

# Kirim salinan kembali ke Windows: lewat server uji (VirtualBox) atau flashdisk.
MED=/run/live/medium
if curl -fsS -m 10 -T "$HASIL" http://10.0.2.2:4952/hasil >/dev/null 2>&1; then
  echo; echo "Hasil terkirim ke Windows (stage0/stage0-result.txt)."
elif sudo mount -o remount,rw "$MED" 2>/dev/null && sudo cp "$HASIL" "$MED/stage0-result.txt"; then
  sync; echo; echo "Hasil tersimpan di flashdisk: stage0-result.txt"
else
  echo; echo "Tidak bisa menulis ke flashdisk. FOTO layar ini, atau salin $HASIL."
fi
echo "Selesai. Laptop boleh dimatikan; cabut flashdisk saat layar gelap, lalu nyalakan lagi ke Windows."
