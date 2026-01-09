#!/usr/bin/env bash
set -euo pipefail
echo "=== HY Security Status ==="
printf "Money mode: "
grep -E '^MONEY_MODE=' .env 2>/dev/null | cut -d= -f2 || echo "(unset)"
printf "Robots:     "
head -n1 current/robots.txt 2>/dev/null || echo "(unknown)"
printf "Guard key:  "
if [[ -x ops/guard.sh ]] && ops/guard.sh >/dev/null 2>&1; then echo "PRESENT"; else echo "MISSING/STALE"; fi
printf "Geo gate:   "
if command -v jq >/dev/null 2>&1; then
  jq -r '.mode+" locales="+(.locales_allow|join(","))' ops/geo_gate.json 2>/dev/null || echo "(no cfg)"
else
  sed -n 's/.*"mode": *"\([^"]*\)".*/mode=\1/p; s/.*"locales_allow": *\[\(.*\)\].*/locales=\1/p' ops/geo_gate.json 2>/dev/null | paste -sd" " -
fi
