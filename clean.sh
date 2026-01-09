#!/usr/bin/env bash
set -euo pipefail
find dist -type f -name '*.html' -mmin +360 -print0 2>/dev/null | xargs -0r rm -f || true
echo "[CLEAN] done"
