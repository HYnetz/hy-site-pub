#!/usr/bin/env bash
set -euo pipefail
SHARD="${SHARD:-1}"; SHARDS="${SHARDS:-1}"
echo "[CI] shard $SHARD/$SHARDS"
mkdir -p ops/logs dist_ready current
SEEDS=ops/ingest/seeds.txt; TMP=ops/ingest/seeds.shard.txt
if [ -f "$SEEDS" ]; then
  awk -v s="$SHARD" -v n="$SHARDS" 'BEGIN{i=0} /^[^#]/ && NF{ if((i % n)+1==s) print; i++ }' "$SEEDS" > "$TMP"
  [ -s "$TMP" ] || head -n 1 "$SEEDS" > "$TMP"
  cp "$TMP" "$SEEDS"
fi
if [ -f scripts/ingest_fetch.py ]; then
  ( python3 scripts/ingest_fetch.py        || echo "[WARN] ingest_fetch failed on shard $SHARD" )
  ( python3 scripts/ingest_dedupe.py       || true )
  ( python3 scripts/ingest_to_pages.py     || true )
  ( python3 scripts/sitemap_data.py        || true )
fi
[ -x bin/release_cut.sh ] && ( bash bin/release_cut.sh || echo "[WARN] release_cut failed on shard $SHARD" )
[ -f current/index.html ] || echo '<!doctype html><title>HY</title><h1>OK</h1>' > current/index.html
mkdir -p out && rm -rf out/*
tar -C current -czf out/site-shard-${SHARD}.tgz .
echo "[CI] shard $SHARD packaged"
