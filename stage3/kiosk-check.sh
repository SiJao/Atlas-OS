#!/bin/bash
# Stage 3 check in the test VM: Atlas server on Linux + the kiosk home screen (atlas-os DESIGN §18).
# Expects ~/atlas.tar.gz (no data/). Uses a throw-away data folder: no real keys, Gemini not configured.
set -u
rm -rf ~/atlas && mkdir -p ~/atlas && tar -xzf ~/atlas.tar.gz -C ~/atlas
cd ~/atlas
export ATLAS_DATA; ATLAS_DATA=$(mktemp -d)
echo '{"bukaJendela": false}' > "$ATLAS_DATA/pengaturan.json"
PORT=4999; URL="http://127.0.0.1:$PORT"
pkill -f "[s]erver/index.js" 2>/dev/null; sleep 1 # test VM only: stop servers left by earlier runs

pkill -f 'Xvfb :99' 2>/dev/null; sleep 1
Xvfb :99 -screen 0 1920x1080x24 -nolisten tcp >/dev/null 2>&1 & XVFB=$!
export DISPLAY=:99 GTK_MODULES=gail:atk-bridge SAL_USE_VCLPLUGIN=gtk3
eval "$(dbus-launch --sh-syntax)"
openbox >/dev/null 2>&1 & sleep 2

ATLAS_PORT=$PORT node server/index.js > /tmp/atlas-server.log 2>&1 & SERVER=$!
for i in $(seq 1 30); do sleep 1; curl -fsS -o /dev/null "$URL/" 2>/dev/null && break; done

post() { curl -fsS -X POST -H 'Content-Type: application/json' -H "Origin: $URL" -d "$2" "$URL$1"; echo; }
T1=$(date -d "+5 min" +%Y-%m-%dT%H:%M); T2=$(date -d "+15 min" +%Y-%m-%dT%H:%M)
echo "== reminders for today"
post /api/pengingat "{\"aksi\":\"buat\",\"waktu\":\"${T1}\",\"pesan\":\"Cek proyek Atlas OS\",\"ulang\":\"tidak\"}"
post /api/pengingat "{\"aksi\":\"buat\",\"waktu\":\"${T2}\",\"pesan\":\"Matikan laptop\",\"ulang\":\"tidak\"}"

echo "== dock: 'buka lembar kerja' through the local router"
post /api/pesan '{"teks":"buka lembar kerja"}'
for i in $(seq 1 25); do sleep 1; pgrep -x soffice.bin >/dev/null && break; done
pgrep -x soffice.bin >/dev/null && echo "LibreOffice Calc started: OK" || echo "LibreOffice Calc started: FAIL"
curl -fsS "$URL/api/keadaan" | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{const k=JSON.parse(s);console.log('last messages:', (k.riwayat||k.percakapan||[]).slice(-2).map(p=>p.peran+': '+p.teks))})" 2>/dev/null
pkill -x soffice.bin

# Headless --screenshot never finishes here (Atlas keeps an SSE connection open), so run the real kiosk
# Chrome on the X screen with the same flags as openChromeApp (ATLAS_KIOSK=1) and photograph the screen.
echo "== real Chrome --kiosk on the X screen, then a screenshot"
rm -rf /tmp/kiosk-profile /tmp/kiosk.png
google-chrome --user-data-dir=/tmp/kiosk-profile --kiosk --use-fake-ui-for-media-stream --autoplay-policy=no-user-gesture-required \
  --no-first-run --no-default-browser-check --disable-features=Translate --noerrdialogs --password-store=basic "--app=$URL/?kiosk=1" >/dev/null 2>&1 &
CHROME=$!
sleep 15
import -silent -window root /tmp/kiosk.png && ls -la /tmp/kiosk.png
PSS=0; for p in $(pgrep -f '[k]iosk-profile'); do v=$(awk '/^Pss:/ {print $2}' /proc/$p/smaps_rollup 2>/dev/null); PSS=$((PSS + ${v:-0})); done
echo "kiosk Chrome RAM (PSS, all its processes): $((PSS / 1024)) MB"
echo "/api/laptop: $(curl -fsS "$URL/api/laptop")"
kill $CHROME 2>/dev/null; sleep 1; pkill -f '[k]iosk-profile' 2>/dev/null

grep -iE 'error|galat|gagal' /tmp/atlas-server.log | head -10
echo "RAM: $(free -m | awk '/^Mem:/ {print "used " $3 " MB, available " $7 " MB"}')"
kill $SERVER $XVFB "$DBUS_SESSION_BUS_PID" 2>/dev/null
rm -rf "$ATLAS_DATA"
echo "== done"
