#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/hy"; CUR="$ROOT/current"; RELDIR="$ROOT/releases"; LOG="$ROOT/ops/logs/publish.out.log"
SM="$CUR/sitemap_index.xml"
ts="$(date -Is)"
# ping engines that accept pings; ignore failures
if [[ -f "$SM" ]]; then
  SMURL="http://localhost:8080/sitemap_index.xml"
  curl -s "https://www.bing.com/ping?sitemap=$SMURL" -o /dev/null || true
  # some engines honor generic ping endpoints; best-effort
  curl -s "https://search.yahoo.com/ping?sitemap=$SMURL" -o /dev/null || true
fi
# make a lightweight snapshot zip you can toss anywhere (cloud drive, friend’s box, etc.)
dst="$RELDIR/$(date +%F_%H%M%S).snapshot.zip"
( cd "$CUR" && zip -qr "$dst" . ) || true
echo "[$ts] publish: pinged + snapshot=$dst" >> "$LOG"
