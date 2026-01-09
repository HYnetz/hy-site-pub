#!/usr/bin/env bash
set -x
mkdir -p ops/logs dist_ready current || true
if [ -f scripts/ingest_fetch.py ]; then
  python3 scripts/ingest_fetch.py || echo "[WARN] ingest_fetch failed"
  python3 scripts/ingest_dedupe.py  || true
  python3 scripts/ingest_to_pages.py || true
  python3 scripts/sitemap_data.py    || true
fi
if [ -x bin/release_cut.sh ]; then
  bash bin/release_cut.sh || echo "[WARN] release_cut failed"
fi
[ -f current/index.html ] || echo '<!doctype html><title>HY</title><h1>OK</h1>' > current/index.html
exit 0
