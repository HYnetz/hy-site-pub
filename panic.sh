#!/usr/bin/env bash
set -euo pipefail
echo "[PANIC] Stealth + Money OFF + stop timers/services."
if [[ -f current/robots.public.txt ]]; then cp -f current/robots.stealth.txt current/robots.txt 2>/dev/null || true; else printf "User-agent: *\nDisallow: /\n" > current/robots.txt; fi
sed -i 's/^MONEY_MODE=.*/MONEY_MODE=false/' .env 2>/dev/null || echo "MONEY_MODE=false" >> .env
if command -v systemctl >/dev/null 2>&1 && systemctl --user --version >/dev/null 2>&1; then
  systemctl --user disable --now hy-omni.timer 2>/dev/null || true
  systemctl --user stop hy-omni.service 2>/dev/null || true
fi
echo "[PANIC] Done."
