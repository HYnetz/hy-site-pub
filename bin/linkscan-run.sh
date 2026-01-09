#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/hy"
python3 "$ROOT/bin/linkscan.py"  >/dev/null 2>&1 || true
FALLBACK=/data/ python3 "$ROOT/bin/linkfix.py" >/dev/null 2>&1 || true
echo "[LINK] after fix: "
"$ROOT/bin/check_links.sh" | sed -n '1,20p' || true
