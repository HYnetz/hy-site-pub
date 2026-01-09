#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/hy"; cd "$ROOT"
python3 scripts/ingest_fetch.py
python3 scripts/ingest_dedupe.py 2>/dev/null || true
python3 scripts/ingest_to_pages.py 2>/dev/null || true
python3 scripts/sitemap_data.py  2>/dev/null || true
