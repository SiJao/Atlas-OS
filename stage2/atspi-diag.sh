#!/bin/bash
# Diagnose AT-SPI on LibreOffice Calc in the test VM: timings and the names it exposes.
set -u
pkill -f 'Xvfb :98' 2>/dev/null; sleep 1
Xvfb :98 -screen 0 1280x800x24 -nolisten tcp >/dev/null 2>&1 & X=$!
export DISPLAY=:98 GTK_MODULES=gail:atk-bridge SAL_USE_VCLPLUGIN=gtk3
eval "$(dbus-launch --sh-syntax)"
openbox >/dev/null 2>&1 & sleep 2
libreoffice --calc --norestore >/dev/null 2>&1 & sleep 25
PID=$(xdotool getactivewindow getwindowpid)
echo "front pid=$PID comm=$(cat /proc/$PID/comm) title=$(xdotool getactivewindow getwindowname)"
python3 - "$PID" <<'EOF'
import sys, time, json, importlib.util
spec = importlib.util.spec_from_file_location('a', '/home/atlas/atlas/server/os/linux-atspi.py')
a = importlib.util.module_from_spec(spec); spec.loader.exec_module(a)
a.Atspi.set_timeout(2000, 8000)
pid = int(sys.argv[1])
for cmd in ('depan', 'daftar'):
    t = time.time()
    try:
        r = a.handle({'perintah': cmd, 'pid': pid, 'pids': [pid]})
        items = r if isinstance(r, list) else r['kontrol']
        print(cmd, 'OK', round(time.time() - t, 1), 's', len(items), 'items')
        print('  names:', [i['nama'] for i in items if i.get('nama')][:60])
        print('  boxes:', [(i['nama'], i['jenis']) for i in items if 'box' in i['jenis'] or 'entry' in i['jenis'] or 'text' in i['jenis']][:20])
    except Exception as e:
        print(cmd, 'ERROR', round(time.time() - t, 1), 's', repr(e))
EOF
pkill -x soffice.bin; kill $X "$DBUS_SESSION_BUS_PID" 2>/dev/null
