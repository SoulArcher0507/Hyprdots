#!/usr/bin/env bash
set -euo pipefail

SWAPFILE="/swapfile"

RAM_GIB=$(awk '/MemTotal/ {printf "%d\n", ($2 + 1048575) / 1048576}' /proc/meminfo)

echo "[INFO] Detected RAM: ${RAM_GIB} GiB"

swapoff "$SWAPFILE" 2>/dev/null || true
rm -f "$SWAPFILE"

mkswap --file --size "${RAM_GIB}G" "$SWAPFILE"

sed -i '\|^/swapfile[[:space:]]|d' /etc/fstab
echo "/swapfile none swap defaults 0 0" >> /etc/fstab

swapon "$SWAPFILE"

echo "[OK] Swapfile created and enabled: $SWAPFILE (${RAM_GIB} GiB)"
swapon --show

