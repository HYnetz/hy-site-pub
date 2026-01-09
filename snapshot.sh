#!/usr/bin/env bash
set -euo pipefail
mkdir -p ops/snap
ts="$(date +%F_%H%M%S)"
out="ops/snap/hy_snap_${ts}.tar.zst"
if tar --version 2>/dev/null | grep -qi zstd; then
  tar --zstd -cf "$out" releases current .env ops/geo_gate.json 2>/dev/null || tar -cf "$out" releases current .env ops/geo_gate.json
else
  out="${out%.zst}.tar.gz"
  tar -czf "$out" releases current .env ops/geo_gate.json 2>/dev/null || tar -cf "$out" releases current .env ops/geo_gate.json
fi
echo "[SNAPSHOT] $out"
