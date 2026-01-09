#!/usr/bin/env bash
set -euo pipefail
ROOT="${HY_ROOT:-$HOME/hy/current}"
PORT="${HY_PORT:-8080}"
exec python3 -m http.server "$PORT" --directory "$ROOT"
