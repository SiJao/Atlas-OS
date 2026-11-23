#!/bin/bash
# Prepare the test VM "AtlasOS-Disk" for stage 2 (Atlas OS DESIGN §17.3).
# A first draft of the stage 4 installer: Debian 13 minimal -> X11 + Openbox + the tools atlas-helper needs.
# Run as the test user (passwordless sudo in the TEST VM only; the real Atlas OS user has no sudo).
set -euo pipefail
NODE_VERSION="${NODE_VERSION:-v24.19.0}" # same version as laptop 1

echo "== packages"
sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
  xserver-xorg-core xserver-xorg-video-vmware xserver-xorg-input-libinput xinit x11-xserver-utils xinput openbox \
  xdotool xprintidle imagemagick dbus-x11 \
  python3 python3-gi gir1.2-atspi-2.0 at-spi2-core \
  pipewire pipewire-pulse wireplumber pipewire-bin pulseaudio-utils sound-theme-freedesktop \
  brightnessctl libglib2.0-bin xdg-utils git curl ca-certificates xz-utils fonts-dejavu-core \
  libreoffice-writer libreoffice-calc libreoffice-gtk3 >/dev/null

echo "== node $NODE_VERSION"
if ! /opt/node/bin/node --version 2>/dev/null | grep -q "^${NODE_VERSION}$"; then
  curl -fsSL "https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-linux-x64.tar.xz" -o /tmp/node.tar.xz
  sudo rm -rf /opt/node && sudo mkdir -p /opt/node && sudo tar -xJf /tmp/node.tar.xz -C /opt/node --strip-components=1
  sudo ln -sf /opt/node/bin/node /usr/local/bin/node && sudo ln -sf /opt/node/bin/npm /usr/local/bin/npm
fi
node --version

echo "== google chrome"
if ! command -v google-chrome >/dev/null; then
  curl -fsSL -o /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq /tmp/chrome.deb >/dev/null
fi
google-chrome --version

echo "== X session (startx on tty1 -> openbox) + hotkey"
mkdir -p ~/.config/openbox
cat > ~/.xinitrc <<'EOF'
export GTK_MODULES=gail:atk-bridge
export QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1
export SAL_USE_VCLPLUGIN=gtk3
exec dbus-launch --exit-with-session openbox-session
EOF
cp /etc/xdg/openbox/rc.xml ~/.config/openbox/rc.xml
# Ctrl+Alt+Space -> atlas-helper FIFO (DESIGN §17.2)
python3 - <<'EOF'
import os, re
p = os.path.expanduser('~/.config/openbox/rc.xml')
s = open(p).read()
kb = '<keybind key="C-A-space"><action name="Execute"><command>sh -c \'echo HOTKEY &gt; "$XDG_RUNTIME_DIR/atlas-hotkey"\'</command></action></keybind>'
if 'atlas-hotkey' not in s:
    s = s.replace('<keyboard>', '<keyboard>\n    ' + kb, 1)
open(p, 'w').write(s)
EOF
sudo usermod -aG video,input "$USER"
mkdir -p ~/proyek ~/Documents/Atlas ~/Downloads ~/Desktop

echo "== systemd-creds"
systemctl --version | head -1
echo "ok" | systemd-creds --user --name=atlas-test encrypt - - | systemd-creds --user --name=atlas-test decrypt - - && echo "systemd-creds --user: OK"

echo "== done"
