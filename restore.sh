#!/usr/bin/env bash
set -euo pipefail
f="${1:-}"; [[ -f "$f" ]] || { echo "use: ./restore.sh ops/snap/<file.tar.gz|tar.zst>"; exit 2; }
case "$f" in
  *.zst) tar --zstd -xf "$f" ;;
  *.gz)  tar -xzf "$f" ;;
  *)     tar -xf "$f" ;;
esac
echo "[RESTORE] done"
