#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/hy"; AL="$ROOT/ops/ingest/allowlist.txt"; SEEDS="$ROOT/ops/ingest/seeds.txt"; ST="$ROOT/ops/ingest/.grow_ts"
# run at most once/hour
now=$(date +%s); last=$(cat "$ST" 2>/dev/null || echo 0)
(( now - last < 3600 )) && { echo "[GROW] skip (recent)"; exit 0; }
touch "$ST"
tmp=$(mktemp)
while read -r d; do
  [[ -z "$d" || "$d" =~ ^# ]] && continue
  for scheme in https http; do
    url="$scheme://$d/robots.txt"
    txt=$(curl -fsL --max-time 15 -A "Mozilla/5.0" "$url" || true)
    [[ -z "$txt" ]] && continue
    echo "$txt" | awk -v host="$d" 'tolower($1)=="sitemap:"{print $2}' | grep -F "$d" >> "$tmp"
    break
  done
done < "$AL"
# merge + dedupe + cap
touch "$SEEDS"
cat "$SEEDS" "$tmp" | awk 'NF && $0 !~ /^#/' | awk '!seen[$0]++' | head -n 2000 > "$SEEDS.new" && mv "$SEEDS.new" "$SEEDS"
rm -f "$tmp"
echo "[GROW] seeds=$(wc -l < "$SEEDS")"
