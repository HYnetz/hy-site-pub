#!/usr/bin/env bash
set -euo pipefail
echo "[i] Snapshotting key configs -> ops/snap/"
mkdir -p ops/snap
tar -czf "ops/snap/hy_configs_$(date +%F_%H%M).tgz" \
  .env switchboard floor legal partner/*.md partner/outreach_email.txt 2>/dev/null || true
echo "[i] Removing only generated/ephemeral artifacts…"
rm -rf dist content/generated content/ready partner/packs_bulk partner/links \
       ops/logs ops/scores crawl/cache vendor quantum/jobs receipts/*.json 2>/dev/null || true
find . -name "*.tmp" -o -name "*.swp" -o -name ".DS_Store" -delete 2>/dev/null || true
# enforce safe mode
sed -i 's/^MONEY_MODE=.*/MONEY_MODE=false/' .env 2>/dev/null || true
sed -i 's/^STEALTH=.*/STEALTH=true/' .env 2>/dev/null || true
echo "[✓] Clean complete. MoneyMode=OFF, Stealth=ON."
