#!/bin/bash
# Atlas OS Live (DESIGN §26.6): after the ISO was written to a stick (or an image file), turn the free space behind it
# into a FAT32 partition "ATLAS-LOG" for the automatic log. Readable on Windows.
#
#   ./add-log-partition.sh /dev/sdX              # the stick (check with lsblk first!)
#   ./add-log-partition.sh test.img              # an image file (attached through a loop device)
set -euo pipefail
T=${1:?"perangkat atau berkas image"}
[ "$(id -u)" -eq 0 ] || { echo "Jalankan sebagai root."; exit 1; }
LOOP=""
if [ -f "$T" ]; then LOOP=$(losetup -fP --show "$T"); DEV=$LOOP; else DEV=$T; fi
[ -b "$DEV" ] || { echo "$DEV bukan perangkat blok."; exit 1; }
for p in $(lsblk -nlo PATH "$DEV"); do umount "$p" 2>/dev/null || true; done
if lsblk -nlo LABEL "$DEV" | grep -qx ATLAS-LOG; then echo "ATLAS-LOG sudah ada."; else
  echo ',,c' | sfdisk --append --no-reread --wipe never "$DEV" >/dev/null
  partprobe "$DEV" 2>/dev/null || blockdev --rereadpt "$DEV" 2>/dev/null || true
  [ -n "$LOOP" ] && { losetup -d "$LOOP"; LOOP=$(losetup -fP --show "$T"); DEV=$LOOP; }
  udevadm settle 2>/dev/null || true
  P=$(lsblk -nlo PATH,TYPE "$DEV" | awk '$2=="part"{p=$1} END{print p}')
  [ -n "$P" ] && [ "$P" != "$DEV" ] || { echo "Partisi baru tidak terlihat."; exit 1; }
  mkfs.vfat -F 32 -n ATLAS-LOG "$P" >/dev/null
  echo "ATLAS-LOG dibuat: $P"
fi
lsblk -o PATH,SIZE,FSTYPE,LABEL "$DEV"
[ -n "$LOOP" ] && losetup -d "$LOOP"
true
