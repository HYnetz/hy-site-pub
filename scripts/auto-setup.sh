#!/usr/bin/env bash
set -euo pipefail
PROFILE="seednet"; DOMAIN="yourdomain.tld"; FORCE=0
while [[ $# -gt 0 ]]; do case "$1" in
  --profile) PROFILE="${2:-seednet}"; shift 2;;
  --domain) DOMAIN="${2:-yourdomain.tld}"; shift 2;;
  --force) FORCE=1; shift;;
  -h|--help) echo "USAGE: $0 [--profile seednet|moneynet|omega] [--domain yourdomain.tld] [--force]"; exit 0;;
  *) echo "Unknown arg: $1"; exit 1;;
esac; done
if [[ -f ".env" && "$FORCE" -ne 1 ]]; then echo "[ok] .env exists"; else sed "s|yourdomain.tld|$DOMAIN|g" .env.example > .env; echo "[ok] wrote .env"; fi
mkdir -p switchboard/active
echo "inherit=../profiles/${PROFILE}.ini" > switchboard/active/active_profile.ini
cp -n floor/floor_v4.ini floor/active_floor.ini || true
echo "[ok] Active profile=${PROFILE}; floors=v4; MoneyMode=OFF; Stealth=ON"
echo "NEXT: portal content + partner outreach; see ops/ and partner/"
