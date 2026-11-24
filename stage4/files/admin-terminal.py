#!/usr/bin/env python3
# Atlas OS "Mode admin" (DESIGN §21, Hong Khai 2026-11-24). Runs as the "atlas" user.
# The admin password is typed in Atlas's own dialog (masked ●●●), never in a terminal that shows nothing.
#   admin-terminal.py --cek <user>          password on stdin -> exit 0 if correct (via `su <user> -c true`)
#   admin-terminal.py --buka <user> <file>  run INSIDE xterm: read the password from a one-time 0600 file
#                                           (deleted right away), start `su -l <user>` and type it for you
import os
import pty
import select
import sys
import time

ENV = {**os.environ, 'LC_ALL': 'C', 'LANG': 'C'}  # English "Password:" prompt, whatever the locale
PROMPT = b'assword:'


def run_su(argv, password, interactive):
    pid, fd = pty.fork()
    if pid == 0:
        os.execvpe(argv[0], argv, ENV)
    sent = False
    buf = b''
    deadline = time.time() + 15
    while not sent and time.time() < deadline:
        r, _, _ = select.select([fd], [], [], 0.5)
        if fd in r:
            try:
                data = os.read(fd, 1024)
            except OSError:
                break
            if not data:
                break
            buf += data
            if PROMPT in buf:
                os.write(fd, password.encode() + b'\n')
                sent = True
    password = None  # forget it as soon as it is typed
    if not interactive:
        out = b''
        while True:
            try:
                data = os.read(fd, 1024)
            except OSError:
                break
            if not data:
                break
            out += data
        _, status = os.waitpid(pid, 0)
        return os.waitstatus_to_exitcode(status) if sent else 1
    # Relay between this terminal (xterm) and su's pseudo-terminal until the admin shell ends.
    import termios
    import tty
    old = termios.tcgetattr(0)
    tty.setraw(0)
    try:
        while True:
            r, _, _ = select.select([0, fd], [], [])
            if fd in r:
                try:
                    data = os.read(fd, 4096)
                except OSError:
                    break
                if not data:
                    break
                os.write(1, data)
            if 0 in r:
                data = os.read(0, 4096)
                if not data:
                    break
                os.write(fd, data)
    finally:
        termios.tcsetattr(0, termios.TCSADRAIN, old)
    _, status = os.waitpid(pid, 0)
    return os.waitstatus_to_exitcode(status)


def main():
    mode, user = sys.argv[1], sys.argv[2]
    if mode == '--cek':
        password = sys.stdin.readline().rstrip('\n')
        sys.exit(0 if run_su(['su', user, '-c', 'true'], password, False) == 0 else 1)
    if mode == '--buka':
        path = sys.argv[3]
        with open(path) as f:
            password = f.read()
        os.unlink(path)
        print(f'Terminal admin ({user}). Ketik "exit" atau tekan Alt+F4 untuk menutup.\r')
        sys.exit(run_su(['su', '-l', user], password, True))
    sys.exit(2)


if __name__ == '__main__':
    main()
