#!/bin/bash
# Atlas OS Live builder (DESIGN §26). Run as root on Debian 13 with live-build (the test VM), from an atlas-os checkout:
#
#   ./build-atlas-os-live.sh --atlas atlas-<commit>.tar --log-targets "192.168.1.50 NAMA-PC.local" \
#                            --log-token-file live-log.token [--out /var/tmp/atlas-os-live]
#
#   --atlas           `git archive --prefix=<commit>/ HEAD` of SiJao/atlas (no .git, no data, no keys)
#   --log-targets     where the PC log receiver may be (tried in order; then a UDP broadcast)
#   --log-token-file  64 hex characters; the same code is in the PC's receiver.json. Never commit it.
#
# Result: <out>/atlas-os-live-amd64.iso (+ .sha256). Nothing secret beyond the log code goes into the image (§26.2).
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/.." && pwd)
ATLAS_TAR=""; TARGETS=""; TOKEN_FILE=""; OUT=/var/tmp/atlas-os-live
while [ $# -gt 0 ]; do
  case "$1" in
    --atlas) ATLAS_TAR=$(readlink -f "$2"); shift 2 ;;
    --log-targets) TARGETS="$2"; shift 2 ;;
    --log-token-file) TOKEN_FILE=$(readlink -f "$2"); shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *) echo "Argumen tidak dikenal: $1"; exit 2 ;;
  esac
done
langkah() { echo; echo "==== $*"; }
[ "$(id -u)" -eq 0 ] || { echo "Jalankan sebagai root."; exit 1; }
command -v lb >/dev/null || { echo "Butuh paket live-build."; exit 1; }
[ -f "$ATLAS_TAR" ] || { echo "Butuh --atlas <tar>."; exit 1; }
TOKEN=$(tr -d ' \r\n' < "$TOKEN_FILE" 2>/dev/null || true)
[[ "$TOKEN" =~ ^[0-9a-f]{64}$ ]] || { echo "Kode log harus 64 karakter hex (--log-token-file)."; exit 1; }
[[ "$TARGETS" =~ ^[A-Za-z0-9.:\ -]*$ ]] || { echo "--log-targets: hanya nama/IP dipisah spasi."; exit 1; }
SHA=$(tar -tf "$ATLAS_TAR" | head -1 | cut -d/ -f1)
[[ "$SHA" =~ ^[0-9a-f]{7,40}$ ]] || { echo "Tar Atlas harus dibuat dengan git archive --prefix=<komit>/."; exit 1; }
# Secrets must never be inside the Atlas tree (DESIGN §26.2).
# (server/rahasia.js is the code that keeps secrets, not a secret: only data files and keys are refused.)
if tar -tf "$ATLAS_TAR" | grep -Eiq '(^|/)(data|atlas-data)/|rahasia\.json$|(^|/)\.env$|deploy_key|(^|/)id_(ed25519|rsa|ecdsa)|\.(pem|key)$'; then
  echo "Tar Atlas berisi berkas yang tampak rahasia; batal."; exit 1
fi

W="$OUT/build"
langkah "1. Konfigurasi live-build di $W"
mkdir -p "$W"
cd "$W"
lb clean >/dev/null 2>&1 || true   # keeps cache/ (bootstrap + packages): a rebuild is much faster
rm -rf config
lb config \
  --distribution trixie \
  --archive-areas "main contrib non-free-firmware" \
  --binary-images iso-hybrid \
  --bootloaders "grub-efi,syslinux" \
  --debian-installer none \
  --apt-recommends false \
  --memtest none \
  --security true --updates true \
  --iso-volume ATLAS_OS_LIVE \
  --iso-application "Atlas OS Live" \
  --iso-publisher "Atlas OS" \
  --bootappend-live "boot=live quiet" >/dev/null

# Firmware for laptops other than the Zyrex (Wi-Fi, audio, graphics, CPU microcode). The installer adds its own set too.
cat > config/package-lists/atlas-os-live.list.chroot <<'EOF'
firmware-iwlwifi
firmware-realtek
firmware-atheros
firmware-brcm80211
firmware-mediatek
firmware-libertas
firmware-misc-nonfree
firmware-amd-graphics
firmware-intel-sound
firmware-sof-signed
intel-microcode
amd64-microcode
EOF

langkah "2. Berkas yang masuk image: stage4, inventaris Tahap 6, log live, kode Atlas $SHA"
I=config/includes.chroot_after_packages
install -d "$I/root/atlas-os/stage6" "$I/root/atlas-os/live" "$I/opt/atlas/releases" "$I/etc/atlas-os"
cp -a "$REPO/stage4" "$I/root/atlas-os/"
rm -f "$I/root/atlas-os/stage4/"*.png
install -m 755 "$REPO/stage6/hardware-inventory.sh" "$I/root/atlas-os/stage6/"
cp -a "$HERE/files" "$I/root/atlas-os/live/"
tar -xf "$ATLAS_TAR" -C "$I/opt/atlas/releases"
ln -sfn "/opt/atlas/releases/$SHA" "$I/opt/atlas/current"
printf 'TARGETS="%s"\nPORT=4960\n' "$TARGETS" > "$I/etc/atlas-os/live-log.conf"
( umask 077; printf '%s\n' "$TOKEN" > "$I/etc/atlas-os/live-log.token" )
echo atlas-live > "$I/etc/hostname"
printf '127.0.0.1\tlocalhost\n127.0.1.1\tatlas-live\n::1\tlocalhost ip6-localhost ip6-loopback\n' > "$I/etc/hosts"

mkdir -p config/hooks/live
cat > config/hooks/live/9000-atlas-os.hook.chroot <<'EOF'
#!/bin/bash
# Atlas OS Live (DESIGN §26.3): the normal installer, inside the image's chroot.
set -euo pipefail
export ATLAS_OS_LIVE=1 DEBIAN_FRONTEND=noninteractive
ln -sf /usr/share/zoneinfo/Asia/Jakarta /etc/localtime && echo Asia/Jakarta > /etc/timezone
cd /root/atlas-os/stage4 && bash ./install-atlas-os.sh
chown -R atlas:atlas /opt/atlas
# Automatic log (§26.6)
F=/root/atlas-os/live/files
install -m 755 /root/atlas-os/stage6/hardware-inventory.sh /opt/atlas-os/hardware-inventory.sh
install -m 755 "$F/atlas-live-log" /opt/atlas-os/atlas-live-log
install -m 755 "$F/atlas-live-send.py" /opt/atlas-os/atlas-live-send.py
install -m 644 "$F"/atlas-live-*.service "$F"/atlas-live-*.timer /etc/systemd/system/
install -d /etc/NetworkManager/dispatcher.d && install -m 755 "$F/90-atlas-live-log" /etc/NetworkManager/dispatcher.d/
systemctl enable atlas-live-log.timer atlas-live-ram.timer atlas-live-log-akhir.service
chown root:root /etc/atlas-os/live-log.token /etc/atlas-os/live-log.conf
chmod 600 /etc/atlas-os/live-log.token; chmod 644 /etc/atlas-os/live-log.conf
# No updates on a live stick (everything is lost at shutdown anyway, §26.2)
systemctl disable apt-daily.timer apt-daily-upgrade.timer >/dev/null 2>&1 || true
printf 'APT::Periodic::Update-Package-Lists "0";\nAPT::Periodic::Unattended-Upgrade "0";\n' > /etc/apt/apt.conf.d/20auto-upgrades
rm -f /home/atlas/.config/systemd/user/timers.target.wants/atlas-update-check.timer
# live-config would add a "user" account with admin rights; the installer already made "atlas" (no admin rights).
apt-get purge -y -qq live-config live-config-systemd >/dev/null 2>&1 || true
: > /opt/atlas-os/admin-user
rm -rf /root/atlas-os /home/atlas/.ssh/atlas_deploy_key
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
EOF
chmod 755 config/hooks/live/9000-atlas-os.hook.chroot

langkah "3. Membangun (lama: unduh paket, pasang Atlas OS, squashfs)"
lb build 2>&1 | tee "$OUT/build.log" | grep -E '^(P:|E:|W:)|==== ' || true
ISO=$(ls -1 "$W"/*.hybrid.iso 2>/dev/null | head -1 || true)
[ -n "$ISO" ] || { echo "Build gagal; lihat $OUT/build.log"; exit 1; }
mv "$ISO" "$OUT/atlas-os-live-amd64.iso"
(cd "$OUT" && sha256sum atlas-os-live-amd64.iso > atlas-os-live-amd64.iso.sha256)

langkah "4. Pemeriksaan isi image"
M=$(mktemp -d); mount -o loop,ro "$OUT/atlas-os-live-amd64.iso" "$M"
S=$(mktemp -d); mount -o loop,ro "$M/live/filesystem.squashfs" "$S"
cek() { if eval "$2"; then echo "  ok   $1"; else echo "  GAGAL $1"; GAGAL=1; fi; }
GAGAL=0
# /opt/atlas/current is an absolute link: check the release itself (review §26.7 no. 10)
cek "Atlas $SHA terpasang"            "[ -f '$S/opt/atlas/releases/$SHA/server/index.js' ] && [ \"\$(readlink '$S/opt/atlas/current')\" = /opt/atlas/releases/$SHA ]"
cek "Wi-Fi: wpasupplicant, rfkill, iw" "[ -x '$S/usr/sbin/wpa_supplicant' ] && [ -x '$S/usr/sbin/rfkill' ] && [ -x '$S/usr/sbin/iw' ]"
cek "pengirim log (python)"           "[ -x '$S/opt/atlas-os/atlas-live-send.py' ]"
cek "akun atlas tanpa grup sudo"      "! grep -qE '^sudo:.*\batlas\b' '$S/etc/group'"
cek "tidak ada akun 'user' live"      "! grep -q '^user:' '$S/etc/passwd'"
cek "live-config dibuang"             "[ ! -e '$S/lib/live/config' ] && [ ! -e '$S/usr/lib/live/config' ]"
cek "tanpa deploy key / data Atlas"   "[ ! -e '$S/home/atlas/.ssh/atlas_deploy_key' ] && [ ! -e '$S/home/atlas/atlas-data/rahasia.json' ]"
cek "tanpa Claude Code"               "[ ! -e '$S/home/atlas/.local/bin/claude' ]"
cek "kode log hanya root"             "[ \"\$(stat -c %a:%U '$S/etc/atlas-os/live-log.token')\" = 600:root ]"
cek "log otomatis aktif"              "[ -L '$S/etc/systemd/system/timers.target.wants/atlas-live-log.timer' ]"
cek "tema jendela AtlasOS"            "[ -f '$S/usr/share/themes/AtlasOS/openbox-3/themerc' ]"
umount "$S" "$M"; rmdir "$S" "$M"
du -h "$OUT/atlas-os-live-amd64.iso"
[ "$GAGAL" = 0 ] || { echo "Ada pemeriksaan yang gagal."; exit 1; }
echo "Selesai: $OUT/atlas-os-live-amd64.iso"
