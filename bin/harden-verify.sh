#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/hy"; CUR="$ROOT/current"; HDIR="$ROOT/ops/harden"
MAN="$HDIR/manifest.sha256"; REL="$HDIR/manifest.release"; CHN="$HDIR/chain.log"
mkdir -p "$HDIR"
cur_path="$(readlink -f "$CUR" || echo "")"
old_path="$(cat "$REL" 2>/dev/null || echo "")"
if [[ "$cur_path" != "$old_path" || ! -f "$MAN" ]]; then
  (cd "$CUR" && find . -maxdepth 3 -type f -print0 | xargs -0 sha256sum) > "$MAN"
  echo "$cur_path" > "$REL"
  echo "$(date -Is) NEW $(basename "$cur_path") $(sha256sum "$MAN" | awk '{print $1}')" >> "$CHN"
  echo "[HARDEN] manifest (re)created"
  exit 0
fi
(cd "$CUR" && sha256sum --quiet -c "$MAN") && echo "[HARDEN] verify OK" || echo "[HARDEN] drift DETECTED"
