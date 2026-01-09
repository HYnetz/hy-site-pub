#!/usr/bin/env bash
[ -f ops/MONEY_LOCK_OFF ] && { echo "[MONEY] locked OFF"; exit 0; }
set -euo pipefail; m="${1:-}"; [[ "$m" =~ ^(on|off)$ ]] || { echo "use: on|off"; exit 2; }
touch .env; grep -q '^MONEY_MODE=' .env || echo "MONEY_MODE=false" >> .env
if [[ "$m" == "on" ]]; then sed -i 's/^MONEY_MODE=.*/MONEY_MODE=true/' .env; echo "[MONEY] ON"; else sed -i 's/^MONEY_MODE=.*/MONEY_MODE=false/' .env; echo "[MONEY] OFF"; fi
