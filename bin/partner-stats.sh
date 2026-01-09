#!/usr/bin/env bash
set -euo pipefail
LOG="$HOME/hy/ops/logs/hy-serve.err.log"
[[ -f "$LOG" ]] || { echo "[ERR] no server log at $LOG"; exit 1; }
awk '$7 ~ /^\/t\// {print $7}' "$LOG" | awk -F'/' '{print $3}' | sort | uniq -c | sort -nr | awk '{printf "%7d  %s\n", $1, $2}'
