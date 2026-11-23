#!/bin/bash
# Stage 2 smoke test inside the test VM (Atlas OS DESIGN §17.3).
# Expects ~/atlas.tar.gz (Atlas working tree WITHOUT data/) and ~/stage2/real-check.mjs.
# Uses a throw-away data folder with no real keys.
set -u
command -v Xvfb >/dev/null || sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq xvfb >/dev/null

rm -rf ~/atlas && mkdir -p ~/atlas && tar -xzf ~/atlas.tar.gz -C ~/atlas
cd ~/atlas
export ATLAS_DATA; ATLAS_DATA=$(mktemp -d)
echo '{"bukaJendela": false}' > "$ATLAS_DATA/pengaturan.json"

# Headless X like the real session: Xvfb + D-Bus + accessibility + Openbox.
pkill -f 'Xvfb :99' 2>/dev/null; sleep 1
Xvfb :99 -screen 0 1280x800x24 -nolisten tcp >/dev/null 2>&1 &
XVFB=$!
export DISPLAY=:99 GTK_MODULES=gail:atk-bridge QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1 SAL_USE_VCLPLUGIN=gtk3 NO_AT_BRIDGE=0
eval "$(dbus-launch --sh-syntax)"
sleep 2
openbox >/dev/null 2>&1 &
sleep 2

echo "===== 1. unit tests on Linux"
node --test --test-concurrency=1 tests/linux.test.mjs tests/os-boundary.test.mjs 2>&1 | grep -E '^(ℹ (tests|pass|fail))|^✖|Error' | head -20

echo "===== 2. real programs"
node ~/stage2/real-check.mjs 2>&1

echo "===== 3. Atlas server starts on Linux"
ATLAS_PORT=4999 timeout 40 node server/index.js > /tmp/atlas-server.log 2>&1 &
for i in $(seq 1 30); do sleep 1; curl -fsS -o /dev/null http://127.0.0.1:4999/ 2>/dev/null && break; done
curl -fsS http://127.0.0.1:4999/ -o /dev/null && echo "GET / OK" || echo "GET / FAIL"
curl -fsS http://127.0.0.1:4999/api/keadaan | head -c 300; echo
grep -iE 'error|galat|gagal|warn' /tmp/atlas-server.log | head -15
echo "RAM: $(free -m | awk '/^Mem:/ {print "used " $3 " MB, available " $7 " MB"}')"

kill "$XVFB" 2>/dev/null; kill "$DBUS_SESSION_BUS_PID" 2>/dev/null
rm -rf "$ATLAS_DATA"
echo "===== done"
