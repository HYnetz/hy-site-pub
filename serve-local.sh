#!/usr/bin/env bash
set -euo pipefail
cd dist_ready
python3 -m http.server 8080 >/dev/null 2>&1 &
echo "[SERVE] http://localhost:8080  (Ctrl+C won't stop; use: pkill -f 'http.server 8080')"
