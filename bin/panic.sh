#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/hy"; CUR="$ROOT/current"
# robots: disallow everything
printf "User-agent: *\nDisallow: /\n" > "$CUR/robots.txt"
# maintenance index
cat > "$CUR/index.html" <<HTML
<!doctype html><meta charset="utf-8"><title>Maintenance</title>
<h1>Temporarily offline</h1><p>Please check back later.</p>
HTML
# force money OFF
grep -q '^MONEY_MODE=' "$ROOT/.env" || echo "MONEY_MODE=false" >> "$ROOT/.env"
sed -i 's/^MONEY_MODE=.*/MONEY_MODE=false/' "$ROOT/.env"
touch "$ROOT/ops/MONEY_LOCK_OFF"
# refresh server (fallback)
pkill -f "http.server 8080" 2>/dev/null || true
nohup python3 -m http.server 8080 -d "$CUR" >> "$ROOT/ops/logs/hy-serve.err.log" 2>&1 &
echo "[PANIC] engaged: stealth + money OFF"
