#!/bin/bash
# Atlas OS installer (DESIGN §19, approved 2026-11-24).
# From a plain Debian 13 netinst (no desktop) to a laptop that boots straight into Atlas's home screen.
#
#   sudo ./install-atlas-os.sh --deploy-key /path/to/atlas_deploy_key
#
# Run it from this folder (it copies files/ next to it). Safe to run again: every step checks or overwrites.
# The account that runs it (via sudo) stays the ADMIN account; Atlas runs as the separate user "atlas" without sudo.
set -euo pipefail

ATLAS_USER="${ATLAS_USER:-atlas}"
ATLAS_REPO="${ATLAS_REPO:-git@github.com:SiJao/atlas.git}"
ATLAS_REF="${ATLAS_REF:-main}"
NODE_VERSION="${NODE_VERSION:-v24.19.0}"   # same as laptop 1
DEPLOY_KEY=""
HERE="$(cd "$(dirname "$0")" && pwd)"

while [ $# -gt 0 ]; do
  case "$1" in
    --deploy-key) DEPLOY_KEY="$2"; shift 2 ;;
    *) echo "Argumen tidak dikenal: $1"; exit 2 ;;
  esac
done

langkah() { echo; echo "==== $*"; }
[ "$(id -u)" -eq 0 ] || { echo "Jalankan dengan sudo/root."; exit 1; }
grep -q 'VERSION_CODENAME=trixie' /etc/os-release || { echo "Butuh Debian 13 (trixie)."; exit 1; }
[ -n "$DEPLOY_KEY" ] && [ -f "$DEPLOY_KEY" ] || [ -d "/opt/atlas/current" ] || { echo "Butuh --deploy-key (kunci hanya-baca ke SiJao/atlas)."; exit 1; }
export DEBIAN_FRONTEND=noninteractive
APT=(apt-get install -y -qq --no-install-recommends)

# ---------------------------------------------------------------------------------------------
langkah "1. Sumber paket: main + contrib + non-free-firmware (firmware Wi-Fi)"
if [ -f /etc/apt/sources.list.d/debian.sources ]; then
  sed -i '/^Components:/{/non-free-firmware/!s/$/ non-free-firmware/}' /etc/apt/sources.list.d/debian.sources
fi
if [ -f /etc/apt/sources.list ]; then
  sed -i -E '/^deb(-src)? .*debian/{/non-free-firmware/!s/ main( |$)/ main non-free-firmware\1/}' /etc/apt/sources.list
fi
apt-get update -qq
"${APT[@]}" ca-certificates curl gnupg git xz-utils >/dev/null

langkah "2. Repo Google Chrome & VS Code"
install -d -m 755 /usr/share/keyrings
curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor --yes -o /usr/share/keyrings/google-chrome.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor --yes -o /usr/share/keyrings/microsoft.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
echo "code code/add-microsoft-repo boolean false" | debconf-set-selections
apt-get update -qq

langkah "3. Paket (tanpa desktop apa pun)"
VIDEO=(xserver-xorg-video-fbdev)
[ "$(systemd-detect-virt 2>/dev/null || true)" = "oracle" ] && VIDEO+=(xserver-xorg-video-vmware) # VirtualBox test VM
"${APT[@]}" \
  xserver-xorg-core xserver-xorg-input-libinput "${VIDEO[@]}" xinit x11-xserver-utils xinput openbox \
  xdotool wmctrl x11-utils pciutils xprintidle imagemagick python3 python3-gi gir1.2-atspi-2.0 at-spi2-core dbus-user-session \
  pipewire pipewire-pulse pipewire-bin wireplumber pulseaudio-utils sound-theme-freedesktop \
  network-manager polkitd brightnessctl libglib2.0-bin xdg-utils zram-tools \
  firmware-iwlwifi firmware-realtek firmware-atheros firmware-misc-nonfree \
  fonts-dejavu-core fonts-noto-core fonts-noto-color-emoji \
  google-chrome-stable libreoffice-writer libreoffice-calc libreoffice-impress libreoffice-gtk3 \
  mpv evince pcmanfm code xterm >/dev/null
echo "terpasang: $(google-chrome --version), LibreOffice $(dpkg-query -W -f='${Version}' libreoffice-core 2>/dev/null), VS Code $(dpkg-query -W -f='${Version}' code)"

langkah "4. Node.js $NODE_VERSION di /opt/node (checksum diperiksa)"
if ! /opt/node/bin/node --version 2>/dev/null | grep -qx "$NODE_VERSION"; then
  TMP=$(mktemp -d)
  F="node-${NODE_VERSION}-linux-x64.tar.xz"
  curl -fsSL -o "$TMP/$F" "https://nodejs.org/dist/${NODE_VERSION}/$F"
  curl -fsSL -o "$TMP/SHASUMS256.txt" "https://nodejs.org/dist/${NODE_VERSION}/SHASUMS256.txt"
  (cd "$TMP" && grep " $F\$" SHASUMS256.txt | sha256sum -c --quiet)
  rm -rf /opt/node && install -d /opt/node && tar -xJf "$TMP/$F" -C /opt/node --strip-components=1
  rm -rf "$TMP"
fi
ln -sf /opt/node/bin/node /usr/local/bin/node
ln -sf /opt/node/bin/npm /usr/local/bin/npm
node --version

langkah "5. Akun $ATLAS_USER (tanpa sudo; audio, video, input) + login otomatis di tty1"
id "$ATLAS_USER" >/dev/null 2>&1 || useradd -m -s /bin/bash "$ATLAS_USER"
usermod -aG audio,video,input "$ATLAS_USER"
passwd -l "$ATLAS_USER" >/dev/null    # no password login anywhere; only the tty1 autologin
gpasswd -d "$ATLAS_USER" sudo >/dev/null 2>&1 || true
H=$(getent passwd "$ATLAS_USER" | cut -d: -f6)
install -d /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $ATLAS_USER --noclear %I \$TERM
EOF
loginctl enable-linger "$ATLAS_USER"   # user services keep running between sessions

langkah "6. Sesi layar: startx -> Openbox -> Atlas"
# runuser keeps root's HOME and working folder otherwise (the admin's folder, which atlas may not read).
as_atlas() { (cd "$H" && runuser -u "$ATLAS_USER" -- env HOME="$H" USER="$ATLAS_USER" LOGNAME="$ATLAS_USER" "$@"); }
as_atlas install -d "$H/.config/openbox" "$H/.config/systemd/user" "$H/.local/bin" "$H/.local/share/atlas" \
  "$H/proyek" "$H/Documents/Atlas" "$H/Downloads" "$H/Desktop" "$H/atlas-data"
cat > "$H/.bash_profile" <<'EOF'
# Atlas OS: tty1 starts the display; other ttys stay plain text.
[ -f ~/.bashrc ] && . ~/.bashrc
if [ -z "${DISPLAY:-}" ] && [ "$(tty)" = /dev/tty1 ]; then exec startx -- -nolisten tcp -quiet vt1 >/dev/null 2>&1; fi
EOF
cat > "$H/.xinitrc" <<'EOF'
# Atlas OS X session (DESIGN §19.3). Accessibility on, so Atlas can read/press controls (AT-SPI).
export GTK_MODULES=gail:atk-bridge QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1 SAL_USE_VCLPLUGIN=gtk3 NO_AT_BRIDGE=0
export ATLAS_DATA="$HOME/atlas-data" ATLAS_KIOSK=1
systemctl --user import-environment DISPLAY XAUTHORITY GTK_MODULES QT_LINUX_ACCESSIBILITY_ALWAYS_ON SAL_USE_VCLPLUGIN
dbus-update-activation-environment --systemd DISPLAY XAUTHORITY GTK_MODULES QT_LINUX_ACCESSIBILITY_ALWAYS_ON SAL_USE_VCLPLUGIN
systemctl --user reset-failed atlas.service 2>/dev/null
systemctl --user restart atlas.service
exec openbox-session
EOF
cat > "$H/.config/openbox/autostart" <<'EOF'
xset s off; xset s noblank; xset dpms 0 0 900    # no screensaver; screen off after 15 min idle
"$HOME/.local/bin/atlas-kiosk" &
EOF
# Openbox: no desktop menu, no panel; only Atlas's hotkey, Alt+Tab between open apps, and Alt+F4.
# Desktop (DESIGN §22.3): margins keep the Atlas top bar (34 px) and dock (84 px) visible; maximized apps fit
# between them. The desktop window (Chrome app on http://localhost:4950/desktop, WM_CLASS "localhost__desktop") stays undecorated
# in the bottom layer. Keep the margins in sync with web/desktop.css in Atlas.
cat > "$H/.config/openbox/rc.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <focus><focusNew>yes</focusNew><followMouse>no</followMouse></focus>
  <placement><policy>Smart</policy><center>yes</center></placement>
  <theme><name>Clearlooks</name><titleLayout>LIMC</titleLayout></theme>
  <desktops><number>1</number></desktops>
  <margins><top>34</top><bottom>84</bottom><left>0</left><right>0</right></margins>
  <keyboard>
    <keybind key="C-A-space"><action name="Execute"><command>sh -c 'echo HOTKEY &gt; "$XDG_RUNTIME_DIR/atlas-hotkey"'</command></action></keybind>
    <keybind key="A-Tab"><action name="NextWindow"/></keybind>
    <keybind key="A-F4"><action name="Close"/></keybind>
  </keyboard>
  <mouse>
    <dragThreshold>8</dragThreshold>
    <context name="Frame"><mousebind button="A-Left" action="Drag"><action name="Move"/></mousebind></context>
    <context name="Titlebar"><mousebind button="Left" action="Drag"><action name="Move"/></mousebind>
      <mousebind button="Left" action="DoubleClick"><action name="ToggleMaximize"/></mousebind></context>
    <context name="Client"><mousebind button="Left" action="Press"><action name="Focus"/><action name="Raise"/></mousebind></context>
    <context name="Close"><mousebind button="Left" action="Click"><action name="Close"/></mousebind></context>
    <context name="Root"></context>
  </mouse>
  <applications>
    <application class="*"><maximized>yes</maximized></application>
    <application name="localhost__desktop"><maximized>no</maximized><decor>no</decor><layer>below</layer><focus>no</focus>
      <skip_taskbar>yes</skip_taskbar><skip_pager>yes</skip_pager><position force="yes"><x>0</x><y>0</y></position></application>
  </applications>
</openbox_config>
EOF
install -m 755 "$HERE/files/atlas-kiosk" "$H/.local/bin/atlas-kiosk"
install -d /opt/atlas-os && install -m 644 "$HERE/files/recovery-server.mjs" /opt/atlas-os/recovery-server.mjs
install -m 644 "$HERE/files/atlas-update.mjs" /opt/atlas-os/atlas-update.mjs   # DESIGN §20
# Mode admin (DESIGN §21): the admin = the account that ran this installer with sudo.
install -m 755 "$HERE/files/admin-terminal.py" /opt/atlas-os/admin-terminal.py
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "$ATLAS_USER" ] && [ "$SUDO_USER" != root ]; then
  echo "$SUDO_USER" > /opt/atlas-os/admin-user
elif [ ! -s /opt/atlas-os/admin-user ]; then
  echo "PERINGATAN: akun admin tidak diketahui (jalankan pemasang lewat sudo dari akun admin); Mode admin belum aktif."
fi
chmod 644 /opt/atlas-os/admin-user 2>/dev/null || true
# Text-console fallback (Ctrl+Alt+F2): clear Indonesian instructions on the login screen.
cat > /etc/issue <<'EOF'

  Atlas OS — terminal perawatan (Ctrl+Alt+F1 = kembali ke layar Atlas)
  1. Ketik NAMA AKUN admin, tekan Enter.
  2. Ketik SANDI, tekan Enter. Huruf sandi memang TIDAK tampil sama sekali di sini; itu normal.
  Lebih mudah: menu Daya di layar Atlas -> "Mode admin" (sandi tampil sebagai titik).

EOF

langkah "7. Layanan Atlas (systemd --user) + halaman pemulihan"
cat > "$H/.config/systemd/user/atlas.service" <<'EOF'
[Unit]
Description=Atlas (asisten) — server
StartLimitIntervalSec=120
StartLimitBurst=3
OnFailure=atlas-recovery.service

[Service]
Environment=ATLAS_DATA=%h/atlas-data ATLAS_KIOSK=1
WorkingDirectory=/opt/atlas/current
ExecStart=/opt/node/bin/node server/index.js
Restart=on-failure
RestartSec=5
EOF
cat > "$H/.config/systemd/user/atlas-recovery.service" <<'EOF'
[Unit]
Description=Atlas — halaman pemulihan (127.0.0.1:4951)

[Service]
ExecStart=/opt/node/bin/node /opt/atlas-os/recovery-server.mjs
Restart=on-failure
EOF

# Updates (DESIGN §20): check at boot + every 6 h; install/rollback only when Hong Khai says yes (via Atlas).
for x in check:cek install:pasang rollback:kembali; do
  unit=${x%%:*}; perintah=${x##*:}
  cat > "$H/.config/systemd/user/atlas-update-$unit.service" <<EOF
[Unit]
Description=Atlas — pembaruan ($perintah)

[Service]
Type=oneshot
Environment=ATLAS_DATA=%h/atlas-data
ExecStart=/opt/node/bin/node /opt/atlas-os/atlas-update.mjs $perintah
TimeoutStartSec=15min
EOF
done
cat > "$H/.config/systemd/user/atlas-update-check.timer" <<'EOF'
[Unit]
Description=Atlas — cek pembaruan saat menyala dan tiap 6 jam

[Timer]
OnBootSec=3min
OnUnitActiveSec=6h

[Install]
WantedBy=timers.target
EOF
install -d "$H/.config/systemd/user/timers.target.wants"
ln -sfn ../atlas-update-check.timer "$H/.config/systemd/user/timers.target.wants/atlas-update-check.timer"

langkah "8. Kode Atlas dari $ATLAS_REPO ($ATLAS_REF) dengan deploy key hanya-baca"
install -d -o "$ATLAS_USER" -g "$ATLAS_USER" -m 700 "$H/.ssh"
if [ -n "$DEPLOY_KEY" ]; then install -o "$ATLAS_USER" -g "$ATLAS_USER" -m 600 "$DEPLOY_KEY" "$H/.ssh/atlas_deploy_key"; fi
# GitHub's published SSH host key (pinned: no trust-on-first-use).
echo "github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl" > "$H/.ssh/known_hosts"
cat > "$H/.ssh/config" <<'EOF'
Host github.com
  IdentityFile ~/.ssh/atlas_deploy_key
  IdentitiesOnly yes
  StrictHostKeyChecking yes
EOF
chown "$ATLAS_USER:$ATLAS_USER" "$H/.ssh/known_hosts" "$H/.ssh/config"; chmod 600 "$H/.ssh/config"
install -d -o "$ATLAS_USER" -g "$ATLAS_USER" /opt/atlas /opt/atlas/releases
if [ -e /opt/atlas/current ]; then
  # Already installed: changing versions is the updater's job (with Hong Khai's yes, test run, rollback).
  echo "rilis tetap: $(basename "$(readlink -f /opt/atlas/current)") (versi baru dipasang lewat atlas-update)"
else
  SHA=$(as_atlas git ls-remote "$ATLAS_REPO" "$ATLAS_REF" | cut -c1-12)
  [ -n "$SHA" ] || { echo "Tidak bisa membaca repo Atlas (deploy key?)."; exit 1; }
  if [ ! -d "/opt/atlas/releases/$SHA" ]; then
    as_atlas git clone -q --depth 20 --branch "$ATLAS_REF" "$ATLAS_REPO" "/opt/atlas/releases/$SHA.tmp"
    as_atlas mv "/opt/atlas/releases/$SHA.tmp" "/opt/atlas/releases/$SHA"
  fi
  as_atlas ln -sfn "/opt/atlas/releases/$SHA" /opt/atlas/current
  echo "rilis: $SHA"
fi

langkah "9. Pengaturan bawaan Atlas OS (pagar menyala, usulan mati, Chrome dibuka oleh atlas-kiosk)"
if [ ! -f "$H/atlas-data/pengaturan.json" ]; then
  cat > "$H/atlas-data/pengaturan.json" <<'EOF'
{
  "bukaJendela": false,
  "izin": { "kartu": true, "pagar": true, "sensitif": true },
  "usulan": { "aktif": false }
}
EOF
  chown "$ATLAS_USER:$ATLAS_USER" "$H/atlas-data/pengaturan.json"
fi

langkah "10. Claude Code CLI untuk $ATLAS_USER (login dilakukan Hong Khai nanti)"
if [ ! -x "$H/.local/bin/claude" ]; then as_atlas bash -c 'cd ~ && curl -fsSL https://claude.ai/install.sh | bash' >/dev/null 2>&1 || echo "PERINGATAN: Claude Code belum terpasang (coba lagi nanti)."; fi
[ -x "$H/.local/bin/claude" ] && echo "claude: $(as_atlas "$H/.local/bin/claude" --version 2>/dev/null | head -1)"

langkah "11. Sistem: zram 50 %, boot cepat"
printf 'ALGO=zstd\nPERCENT=50\n' > /etc/default/zramswap
systemctl enable --now zramswap >/dev/null 2>&1 || true
if grep -q '^GRUB_TIMEOUT=' /etc/default/grub; then sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub && update-grub >/dev/null 2>&1 || true; fi
systemctl enable NetworkManager >/dev/null 2>&1 || true
# Debian's installer sets up the cable with ifupdown, so NetworkManager would leave it "unmanaged" and Atlas's
# network panel could not manage it. Let NetworkManager manage those interfaces too (takes effect after reboot).
# Atlas runs as a background (systemd --user) service, which polkit does not count as an "active local session":
# allow exactly power and NetworkManager actions for the atlas user (found in the VM test 2026-11-24).
install -d /etc/polkit-1/rules.d
cat > /etc/polkit-1/rules.d/50-atlas-os.rules <<EOF
// Atlas OS (DESIGN §21, §22.2): power, NetworkManager, time zone/NTP for the "$ATLAS_USER" user only, nothing else.
polkit.addRule(function (action, subject) {
  if (subject.user !== "$ATLAS_USER") return polkit.Result.NOT_HANDLED;
  var power = ["org.freedesktop.login1.power-off", "org.freedesktop.login1.power-off-multiple-sessions",
               "org.freedesktop.login1.reboot", "org.freedesktop.login1.reboot-multiple-sessions",
               "org.freedesktop.login1.suspend", "org.freedesktop.login1.suspend-multiple-sessions"];
  if (power.indexOf(action.id) >= 0) return polkit.Result.YES;
  // NetworkManager (DESIGN §23 D): only what the Wi-Fi/network panel needs: connect/disconnect, Wi-Fi on/off, scan,
  // save a new Wi-Fi network. Not: all networking off, hostname, global DNS, hotspot, reload, checkpoints.
  var nm = ["org.freedesktop.NetworkManager.network-control", "org.freedesktop.NetworkManager.enable-disable-wifi",
            "org.freedesktop.NetworkManager.wifi.scan", "org.freedesktop.NetworkManager.settings.modify.system",
            "org.freedesktop.NetworkManager.settings.modify.own"];
  if (nm.indexOf(action.id) >= 0) return polkit.Result.YES;
  // Settings window (DESIGN §22.2): time zone and automatic time only (not setting the clock by hand).
  if (action.id === "org.freedesktop.timedate1.set-timezone" || action.id === "org.freedesktop.timedate1.set-ntp") return polkit.Result.YES;
  return polkit.Result.NOT_HANDLED;
});
EOF
systemctl restart polkit >/dev/null 2>&1 || true
# Chrome policy (DESIGN §22.3, §23 C): microphone allowed without asking for the Atlas window only
# (http://127.0.0.1:4950; the desktop on localhost needs no microphone). Replaces the
# --use-fake-ui-for-media-stream flag, which shows a warning bar now that Chrome no longer runs in --kiosk.
install -d /etc/opt/chrome/policies/managed
cat > /etc/opt/chrome/policies/managed/atlas-os.json <<'EOF'
{
  "AudioCaptureAllowedUrls": ["http://127.0.0.1:4950"],
  "AutoplayAllowlist": ["http://127.0.0.1:4950"]
}
EOF
install -d /etc/NetworkManager/conf.d
printf '[ifupdown]\nmanaged=true\n' > /etc/NetworkManager/conf.d/10-atlas-os-manage-all.conf
chown -R "$ATLAS_USER:$ATLAS_USER" "$H/.config" "$H/.local" "$H/.bash_profile" "$H/.xinitrc" "$H/atlas-data"
systemctl daemon-reload

langkah "Selesai"
echo "Mulai ulang laptop: layar langsung masuk ke Atlas (akun $ATLAS_USER)."
echo "Perawatan: Ctrl+Alt+F2, login akun admin."
echo "Langkah sekali saja oleh Hong Khai: isi kunci Gemini (layar Atlas), login Claude Code (sudo -u $ATLAS_USER -i ~/.local/bin/claude)."
