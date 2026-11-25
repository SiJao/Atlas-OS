#!/usr/bin/python3
"""Atlas OS Live: send waiting log snapshots to Hong Khai's PC (DESIGN §26.6, review §26.7).

    atlas-live-send.py <folder-with-belum-terkirim-and-terkirim> [budget-seconds]

The secret code never leaves this machine and never appears on a command line:
  1. find the PC: last good address, the addresses baked into the image, then a UDP broadcast;
     a PC only counts when it proves it knows the code: reply = HMAC(code, "udp:" + our nonce) / "hai:" + our nonce;
  2. each upload is signed: HMAC(code, "log:" + single-use server nonce + ":" + name + ":" + sha256(file)).
"""
import hashlib
import hmac
import json
import os
import secrets
import shutil
import socket
import sys
import time
import urllib.parse
import urllib.request

# Paths can be overridden only for the tests (atlas tests/atlas-os-live.test.mjs); the image uses the defaults.
CONF = os.environ.get("ATLAS_LIVE_CONF", "/etc/atlas-os/live-log.conf")
TOKEN_FILE = os.environ.get("ATLAS_LIVE_TOKEN", "/etc/atlas-os/live-log.token")
LAST = os.environ.get("ATLAS_LIVE_LAST", "/run/atlas-live/target")


def conf():
    c = {"TARGETS": "", "PORT": "4960"}
    try:
        for line in open(CONF, encoding="utf-8"):
            k, _, v = line.strip().partition("=")
            if k in c:
                c[k] = v.strip().strip('"')
    except OSError:
        pass
    return c["TARGETS"].split(), int(c["PORT"] or 4960)


def mac(key, msg):
    return hmac.new(key, msg.encode(), hashlib.sha256).hexdigest()


def hai(host, port, key, timeout=3):
    """True when the receiver at host proves it knows the code."""
    c = secrets.token_hex(16)
    try:
        with urllib.request.urlopen(f"http://{host}:{port}/hai?c={c}", timeout=timeout) as r:
            j = json.loads(r.read(4096))
        return hmac.compare_digest(str(j.get("p", "")), mac(key, "hai:" + c))
    except Exception:
        return False


def broadcast(port, key):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    s.settimeout(1.5)
    try:
        for _ in range(2):
            c = secrets.token_hex(16)
            want = "ATLAS-LOG!" + mac(key, "udp:" + c)
            s.sendto(("ATLAS-LOG?" + c).encode(), ("255.255.255.255", port))
            end = time.time() + 1.5
            while time.time() < end:
                try:
                    data, addr = s.recvfrom(128)
                except socket.timeout:
                    break
                if hmac.compare_digest(data.decode(errors="replace"), want):
                    return addr[0]
    except OSError:
        pass
    finally:
        s.close()
    return None


def find(targets, port, key):
    tried = []
    try:
        tried.append(open(LAST, encoding="utf-8").read().strip())
    except OSError:
        pass
    for t in tried + targets:
        if t and hai(t, port, key):
            return t
    t = broadcast(port, key)
    return t if t and hai(t, port, key) else None


def upload(host, port, key, path):
    name = os.path.basename(path)
    body = open(path, "rb").read()
    with urllib.request.urlopen(f"http://{host}:{port}/nonce", timeout=5) as r:
        s = json.loads(r.read(4096)).get("s", "")
    sig = mac(key, f"log:{s}:{name}:{hashlib.sha256(body).hexdigest()}")
    q = urllib.parse.urlencode({"name": name, "s": s, "sig": sig})
    req = urllib.request.Request(f"http://{host}:{port}/log?{q}", data=body, method="POST",
                                 headers={"Content-Type": "application/gzip"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.status == 200


def main():
    folder = sys.argv[1]
    budget = float(sys.argv[2]) if len(sys.argv) > 2 else 600
    deadline = time.time() + budget
    try:
        key = open(TOKEN_FILE, encoding="utf-8").read().strip().encode()
    except OSError:
        return 0
    waiting = sorted(os.path.join(folder, "belum-terkirim", f) for f in os.listdir(os.path.join(folder, "belum-terkirim"))
                     if f.endswith(".tar.gz"))
    if not waiting:
        return 0
    targets, port = conf()
    host = find(targets, port, key)
    if not host:
        return 0
    with open(LAST, "w", encoding="utf-8") as f:
        f.write(host)
    for p in waiting:
        if time.time() > deadline:
            break
        try:
            if not upload(host, port, key, p):
                break
        except Exception:
            break
        shutil.move(p, os.path.join(folder, "terkirim", os.path.basename(p)))
    getattr(os, "sync", lambda: None)()  # flush the stick (Linux); absent on Windows (tests)
    return 0


if __name__ == "__main__":
    sys.exit(main())
