#!/bin/bash
# Stage 5 failure tests in the TEST VM (DESIGN §20). Run by the admin account (sudo). Uses a LOCAL test
# repository inside the VM, so broken commits never reach SiJao/atlas (laptop 1 uses it too).
#   1. a version that cannot start        -> stopped by the trial run, current version untouched
#   2. a version that dies after 25 s     -> passes the trial, fails the 60 s health check -> automatic rollback
#   3. "kembali" (manual rollback)        -> previous release
set -u
AUID=$(id -u atlas)
A() { sudo -u atlas -H env XDG_RUNTIME_DIR=/run/user/$AUID ATLAS_DATA=/home/atlas/atlas-data "$@"; }
UPD() { A env ATLAS_UPDATE_REPO=file:///tmp/atlas-test.git node /opt/atlas-os/atlas-update.mjs "$@" 2>&1 | grep -E '^\[atlas-update\]'; }
state() { A node -e 'const s=require("/home/atlas/atlas-data/update.json");console.log("   status:",s.status,"| sha:",s.sha,"| sekarang:",s.sekarang,"| tahap:",s.tahap||"-","| alasan:",s.alasan||"-")'; }
now() { echo "   current: $(basename "$(readlink -f /opt/atlas/current)") | atlas.service: $(A systemctl --user is-active atlas.service) | GET /: $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:4950/)"; }

echo "== persiapan repo uji lokal (/tmp/atlas-test.git) dari rilis sekarang"
A bash -c 'rm -rf /tmp/atlas-work /tmp/atlas-test.git && cp -a /opt/atlas/current/. /tmp/atlas-work && cd /tmp/atlas-work && rm -rf .git && git init -q -b main && git add -A && git -c user.name=uji -c user.email=uji@localhost commit -qm "dasar uji" && git clone -q --bare /tmp/atlas-work /tmp/atlas-test.git'
BASE=$(A git -C /tmp/atlas-work rev-parse HEAD)
now

echo; echo "== 1. versi yang tidak bisa menyala (galat sintaks)"
A bash -c 'cd /tmp/atlas-work && echo "this is not javascript (" >> server/index.js && git -c user.name=uji -c user.email=uji@localhost commit -qam "rusak: galat sintaks" && git push -q /tmp/atlas-test.git main'
UPD pasang; state; now

echo; echo "== 2. versi yang mati 25 detik setelah menyala"
A bash -c "cd /tmp/atlas-work && git reset -q --hard $BASE && echo 'setTimeout(() => process.exit(3), 25000);' >> server/index.js && git -c user.name=uji -c user.email=uji@localhost commit -qam 'rusak: mati setelah 25 detik' && git push -q -f /tmp/atlas-test.git main"
S=$(date +%s); UPD pasang; echo "   ($(( $(date +%s) - S )) dtk)"; state; now

echo; echo "== 3. kembali ke versi sebelumnya (manual)"
BEFORE=$(basename "$(readlink -f /opt/atlas/current)")
A node /opt/atlas-os/atlas-update.mjs kembali 2>&1 | grep -E '^\[atlas-update\]'; state; now
echo "   (sebelumnya $BEFORE)"
echo; echo "== rilis tersimpan: $(ls /opt/atlas/releases | tr '\n' ' ')"
