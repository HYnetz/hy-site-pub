#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/hy"; OUT="$ROOT/ops/worm"; CUR="$ROOT/current"
mkdir -p "$OUT"
ts="$(date +%F_%H%M%S)"
tgz="$OUT/$ts.current.tgz"
( cd "$CUR" && tar -czf "$tgz" . )
sha256sum "$tgz" > "$tgz.sha256"
# retain last 14
ls -1t "$OUT"/*.tgz 2>/dev/null | tail -n +15 | xargs -r rm -f
echo "[WORM] snapshot $tgz"
