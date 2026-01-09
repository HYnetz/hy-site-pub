#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/hy"; CUR="$ROOT/current"
ok(){ echo "[GUARD] $*"; }

# 1) HTTP health
http(){ curl -s -o /dev/null -w "%{http_code}" "$1" || echo 000; }
h1=$(http http://localhost:8080/); h2=$(http http://localhost:8080/data/ || true)
[[ "$h1" = "200" ]] && ok "HTTP / =200" || { ok "restart server"; pkill -f "http.server 8080" 2>/dev/null || true; nohup python3 -m http.server 8080 -d "$CUR" >> "$ROOT/ops/logs/hy-serve.err.log" 2>&1 & }

# 2) Integrity check (uses your existing harden-verify)
[[ -x "$ROOT/bin/harden-verify.sh" ]] && OUT=$("$ROOT/bin/harden-verify.sh" || true) || OUT=""
echo "$OUT"
if echo "$OUT" | grep -q "drift DETECTED"; then
  # rollback to previous release
  PREV=$(ls -1dt "$ROOT"/releases/* 2>/dev/null | sed -n '2p')
  if [[ -n "${PREV:-}" && -d "$PREV" ]]; then
    ln -sfn "$PREV" "$CUR"
    ok "rollback -> $PREV"
  else
    ok "no previous release to rollback"
  fi
fi
