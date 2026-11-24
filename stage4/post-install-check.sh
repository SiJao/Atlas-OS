#!/bin/bash
# Stage 4 checks on an installed Atlas OS (DESIGN §19.5). Run by the admin account with sudo.
#   bash post-install-check.sh ram|wifi|dock|recovery-break|recovery-restart|status
set -u
AU=atlas
AUID=$(id -u $AU)
U() { sudo -u $AU XDG_RUNTIME_DIR=/run/user/$AUID DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$AUID/bus "$@"; }
URL=http://127.0.0.1:4950
post() { curl -sS -X POST -H 'Content-Type: application/json' -H "Origin: $URL" -d "$2" "$URL$1"; echo; }

# PSS (real share of RAM) of all processes whose command line matches a pattern.
pss() { local t=0 p v; for p in $(pgrep -f "$1"); do v=$(sudo awk '/^Pss:/ {print $2}' /proc/$p/smaps_rollup 2>/dev/null); t=$((t + ${v:-0})); done; echo $((t / 1024)); }
ram() {
  echo "-- RAM ($1)"
  free -m | awk '/^Mem:/ {print "   total terpakai " $3 " MB, tersedia " $7 " MB dari " $2 " MB"} /^Swap:/ {print "   zram/swap terpakai " $3 " MB dari " $2 " MB"}'
  echo "   Chrome kiosk  $(pss 'chrome-atlas') MB"
  echo "   Atlas (node)  $(pss 'server/index.js') MB"
  echo "   Xorg+Openbox  $(( $(pss '/usr/lib/xorg/Xorg') + $(pss 'openbox') )) MB"
  echo "   PipeWire      $(( $(pss 'pipewire') + $(pss 'wireplumber') )) MB"
  echo "   LibreOffice   $(pss 'soffice') MB"
}

case "${1:-status}" in
  status)
    U systemctl --user --no-pager --plain list-units 'atlas*' | head -5
    echo "autologin: $(loginctl list-sessions --no-legend | awk '{print $3, $5, $6}')"
    echo "rilis: $(readlink /opt/atlas/current)"
    echo "zram: $(/usr/sbin/swapon --show=NAME,SIZE --noheadings | tr '\n' ' ')"
    echo "sudo untuk atlas: $(sudo -l -U $AU 2>&1 | tail -1)"
    ;;
  ram) ram "layar utama, diam" ;;
  wifi)
    echo "GET /api/wifi: $(curl -sS $URL/api/wifi)"
    echo "POST /api/wifi (jaringan khayalan): $(post /api/wifi '{"ssid":"Uji-Atlas-OS","sandi":"sandi-uji-12345"}')"
    echo "sandi di audit? $(sudo grep -rl 'sandi-uji-12345' /home/$AU/atlas-data 2>/dev/null | wc -l) file (harus 0)"
    ;;
  dock)
    post /api/pesan '{"teks":"buka lembar kerja"}'
    for i in $(seq 1 30); do sleep 1; pgrep -x soffice.bin >/dev/null && break; done
    sleep 12
    ram "LibreOffice Calc terbuka"
    sudo pkill -u $AU -x soffice.bin; sleep 2
    ;;
  recovery-break)
    # Make the server crash 3 times within 2 minutes (like a broken release) -> atlas-recovery.service.
    for i in 1 2 3 4; do
      P=$(pgrep -u $AU -f 'server/index.js' | head -1)
      [ -n "$P" ] && sudo kill -9 "$P" && echo "server $P dimatikan paksa ($i)"
      sleep 8
    done
    sleep 5
    echo "atlas.service: $(U systemctl --user is-active atlas.service) / pemulihan: $(U systemctl --user is-active atlas-recovery.service)"
    curl -sS -o /dev/null -w "halaman pemulihan HTTP %{http_code}\n" http://127.0.0.1:4951/
    ;;
  recovery-restart)
    curl -sS -o /dev/null -w "tombol 'Mulai ulang Atlas' HTTP %{http_code}\n" -X POST -H 'Origin: http://127.0.0.1:4951' -H 'Host: 127.0.0.1:4951' http://127.0.0.1:4951/mulai-ulang-atlas
    for i in $(seq 1 30); do sleep 1; curl -fsS -o /dev/null $URL/ 2>/dev/null && break; done
    echo "atlas.service: $(U systemctl --user is-active atlas.service)"
    ;;
esac
