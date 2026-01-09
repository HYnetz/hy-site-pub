#!/usr/bin/env bash
set -euo pipefail
B=${1:-http://localhost:8080}
check(){ printf "%-20s %s\n" "$1" "$(curl -s -o /dev/null -w "%{http_code}" "$B$1" || echo 000)"; }
# make sure server is up (fallback)
pgrep -f "http.server 8080" >/dev/null || nohup python3 -m http.server 8080 -d "$HOME/hy/current" >> "$HOME/hy/ops/logs/hy-serve.err.log" 2>&1 &
sleep 1
for p in / /data/ /sitemap-data.xml /sitemap_index.xml /imprint.html /privacy.html /robots.txt /t/test/ /t/doc/; do check "$p"; done
# sample a few data children if present
if [ -d "$HOME/hy/current/data" ]; then
  for d in $(find "$HOME/hy/current/data" -mindepth 1 -maxdepth 1 -type d -printf "%f/\n" 2>/dev/null | head -n 10); do
    check "/data/$d"
  done
fi
