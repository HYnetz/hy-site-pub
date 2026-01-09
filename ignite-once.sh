#!/usr/bin/env bash
set -euo pipefail
python3 scripts/fabricate.py --cities_per_locale "${CITIES_PER_LOCALE:-500}" --lanes_max "${LANES_MAX:-15}" --locales_max "${LOCALES_MAX:-6}" --limit_pages "${LIMIT_PAGES:-10000}" --words_min "${WORDS_MIN:=260}"
python3 scripts/ready_gate.py
python3 scripts/sitemap_build.py
./scoreboard.sh
./anchor-receipts.sh
