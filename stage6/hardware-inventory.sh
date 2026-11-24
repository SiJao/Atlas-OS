#!/bin/bash
# Atlas OS hardware inventory (DESIGN §25). READ-ONLY: installs nothing, changes nothing, scans no Wi-Fi.
# Run it on the target laptop from a Debian live USB (before Windows is removed) or on an installed Atlas OS:
#   bash hardware-inventory.sh            # without root: most sections
#   sudo bash hardware-inventory.sh       # with root: also kernel log, disk health, DMI details
# Output: atlas-hardware-<host>-<date>.txt in the current folder (or $HOME if not writable).
# MAC addresses and serial numbers are masked, so the file can be shared for review.
set -u
export LC_ALL=C

STAMP=$(date +%Y%m%d-%H%M)
OUT="atlas-hardware-$(hostname 2>/dev/null || echo pc)-$STAMP.txt"
touch "$OUT" 2>/dev/null || OUT="$HOME/$OUT"
ROOT=no; [ "$(id -u)" -eq 0 ] && ROOT=yes

have() { command -v "$1" >/dev/null 2>&1; }
# Masks MAC addresses (aa:bb:cc:dd:ee:ff -> aa:bb:cc:xx:xx:xx) and obvious serial numbers.
mask() { sed -E 's/(([0-9a-fA-F]{2}:){3})([0-9a-fA-F]{2}:){2}[0-9a-fA-F]{2}/\1xx:xx:xx/g; s/(([Ss]erial|SerialNumber|serial_number|Serial Number)[^:=]*[:=][[:space:]]*).*/\1<disamarkan>/'; }
# section "Title" command args...   (skipped with a note when the command is missing; 15 s limit each)
section() {
  local title=$1; shift
  echo; echo "===== $title"
  if ! have "$1"; then echo "(tidak tersedia: $1)"; return; fi
  timeout 15 "$@" 2>&1 | mask | head -n 200
}
show() { # show "Title" file...
  local title=$1; shift
  echo; echo "===== $title"
  for f in "$@"; do [ -r "$f" ] && printf '%s: %s\n' "$f" "$(tr -d '\0' < "$f" 2>/dev/null | head -c 300 | mask)"; done
}
yesno() { if "$@" >/dev/null 2>&1; then echo ya; else echo TIDAK; fi; }

{
echo "Atlas OS — inventaris perangkat keras (baca-saja), $(date '+%Y-%m-%d %H:%M')"
echo "root: $ROOT  (tanpa root, log kernel & kesehatan disk mungkin tidak terbaca)"

# ---------- quick verdicts (what Atlas OS needs) ----------
echo; echo "===== RINGKASAN"
BL=$(ls /sys/class/backlight 2>/dev/null | tr '\n' ' ')
BAT=""; for p in /sys/class/power_supply/*; do [ -r "$p/type" ] || continue
  [ "$(cat "$p/type")" = Battery ] && [ "$(cat "$p/scope" 2>/dev/null)" != Device ] && BAT="$BAT$(basename "$p") "; done
WIFI=""; for n in /sys/class/net/*; do [ -d "$n/wireless" ] && WIFI="$WIFI$(basename "$n") "; done
CARDS=$(grep -c '^ *[0-9]* \[' /proc/asound/cards 2>/dev/null || echo 0)
echo "Model          : $(cat /sys/class/dmi/id/sys_vendor 2>/dev/null) $(cat /sys/class/dmi/id/product_name 2>/dev/null)"
echo "Prosesor       : $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ //')"
echo "RAM            : $(awk '/MemTotal/ {printf "%.1f GB", $2/1048576}' /proc/meminfo)"
echo "Boot UEFI      : $(yesno test -d /sys/firmware/efi)"
echo "Wi-Fi          : ${WIFI:-TIDAK ADA antarmuka Wi-Fi (driver/firmware belum termuat?)}"
echo "Kartu suara    : $CARDS"
echo "Lampu latar    : ${BL:-TIDAK ADA (kecerahan tidak bisa diatur)}"
echo "Baterai laptop : ${BAT:-TIDAK ADA}"
BT=$(ls /sys/class/bluetooth 2>/dev/null | tr '\n' ' '); CAM=$(ls /dev/video* 2>/dev/null | tr '\n' ' ')
echo "Bluetooth      : ${BT:-tidak ada}"
echo "Kamera         : ${CAM:-tidak ada}"
echo "Layar (fisik)  : $(for c in /sys/class/drm/card*-*; do [ "$(cat "$c/status" 2>/dev/null)" = connected ] && echo -n "$(basename "$c") "; done)"

# ---------- devices and drivers ----------
section "PCI: perangkat, ID, driver yang dipakai (lspci -nnk)" lspci -nnk
section "USB (lsusb)" lsusb
show "DMI (model, BIOS)" /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name /sys/class/dmi/id/product_version /sys/class/dmi/id/board_name /sys/class/dmi/id/bios_version /sys/class/dmi/id/bios_date
section "CPU" lscpu
section "Memori" free -m

# ---------- network ----------
section "Antarmuka jaringan (ip -br link)" ip -br link
section "rfkill (Wi-Fi/Bluetooth diblokir?)" rfkill list
section "NetworkManager: perangkat" nmcli -t -f DEVICE,TYPE,STATE device
echo; echo "===== Driver per antarmuka"
for n in /sys/class/net/*; do [ -e "$n/device/driver" ] && echo "$(basename "$n"): $(basename "$(readlink -f "$n/device/driver")")"; done

# ---------- sound ----------
show "Kartu suara (/proc/asound/cards)" /proc/asound/cards
section "Perangkat putar (aplay -l)" aplay -l
section "Perangkat rekam (arecord -l)" arecord -l
section "PipeWire (wpctl status)" wpctl status
echo; echo "===== Codec"
for c in /proc/asound/card*/codec#*; do [ -r "$c" ] && head -n 3 "$c"; done 2>/dev/null

# ---------- screen ----------
echo; echo "===== Lampu latar"
for b in /sys/class/backlight/*; do [ -d "$b" ] && echo "$(basename "$b"): $(cat "$b/brightness" 2>/dev/null)/$(cat "$b/max_brightness" 2>/dev/null) type=$(cat "$b/type" 2>/dev/null)"; done
echo; echo "===== Layar tersambung (DRM)"
for c in /sys/class/drm/card*-*; do [ -r "$c/status" ] && echo "$(basename "$c"): $(cat "$c/status") $(head -n1 "$c/modes" 2>/dev/null)"; done
[ -n "${DISPLAY:-}" ] && section "xrandr (ukuran fisik mm untuk skala)" xrandr --query

# ---------- power ----------
echo; echo "===== Daya (/sys/class/power_supply)"
for p in /sys/class/power_supply/*; do [ -d "$p" ] || continue
  echo "$(basename "$p"): type=$(cat "$p/type" 2>/dev/null) scope=$(cat "$p/scope" 2>/dev/null) status=$(cat "$p/status" 2>/dev/null) capacity=$(cat "$p/capacity" 2>/dev/null) online=$(cat "$p/online" 2>/dev/null)"
  for f in energy_full energy_full_design charge_full charge_full_design cycle_count; do [ -r "$p/$f" ] && echo "   $f=$(cat "$p/$f")"; done
done
show "Mode tidur yang didukung" /sys/power/state /sys/power/mem_sleep
echo; echo "===== Suhu (thermal_zone)"
for z in /sys/class/thermal/thermal_zone*; do [ -r "$z/temp" ] && echo "$(basename "$z"): $(cat "$z/type") $(( $(cat "$z/temp") / 1000 )) °C"; done

# ---------- storage ----------
section "Disk (lsblk)" lsblk -o NAME,SIZE,TYPE,TRAN,ROTA,MODEL,FSTYPE,MOUNTPOINT
if [ "$ROOT" = yes ] && have smartctl; then
  for d in $(lsblk -dno NAME,TYPE | awk '$2=="disk"{print $1}'); do section "Kesehatan /dev/$d (smartctl)" smartctl -i -H "/dev/$d"; done
fi

# ---------- input, camera ----------
echo; echo "===== Masukan (touchpad, keyboard, tombol)"
grep -E '^N: Name=' /proc/bus/input/devices 2>/dev/null | sed 's/^N: Name=//'
[ -n "${DISPLAY:-}" ] && section "xinput" xinput list --short

# ---------- firmware & driver problems ----------
echo; echo "===== Kernel: firmware / galat perangkat"
if [ "$ROOT" = yes ] || [ "$(cat /proc/sys/kernel/dmesg_restrict 2>/dev/null)" = 0 ]; then
  { journalctl -k -b --no-pager 2>/dev/null || dmesg 2>/dev/null; } | grep -iE 'firmware|fw |direct firmware load|failed|error|sof|snd_|iwlwifi|rtw|ath1|i915|backlight|acpi.*(error|warn)' | mask | tail -n 120
else
  echo "(butuh root: jalankan dengan sudo untuk bagian ini)"
fi
section "Modul kernel terkait" sh -c "lsmod | grep -iE 'snd|sof|iwl|rtw|ath|btusb|uvc|i915|hid|i2c' | awk '{print \$1}' | sort | tr '\n' ' '"
section "Versi kernel & Debian" sh -c "uname -r; cat /etc/os-release | grep PRETTY"
echo; echo "===== Selesai. Tidak ada yang diubah di laptop ini."
} > "$OUT" 2>&1

echo "Inventaris tersimpan di: $(readlink -f "$OUT")"
echo "Isinya tanpa alamat MAC dan nomor seri. Kirim file ini untuk diperiksa."
