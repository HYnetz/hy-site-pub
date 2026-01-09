#!/usr/bin/env bash
set -euo pipefail
echo "[DIST] $(find dist -type f -name '*.html' | wc -l) pages"
echo "[READY] $(find dist_ready -type f -name '*.html' | wc -l) pages"
du -sh dist dist_ready 2>/dev/null || true
