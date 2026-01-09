#!/usr/bin/env bash
[[ -x bin/ingest-once.sh ]] && bin/ingest-once.sh || true
# HY OmniDrive: Bloom → Gate → GeoFilter → Sitemaps → Release (non-fatal)
set -euo pipefail
ROOT="$HOME/hy"; cd "$ROOT"
TS="$(date +%F_%H%M%S)"
log(){ echo "[OMNI] $*"; }

log "cycle ts=$TS"
free_mb=$(df -Pm "$ROOT" | awk 'NR==2{print $4}'); log "free_mb=$free_mb"

# optional tuning
[[ -f ops/omni.env ]] && . ops/omni.env || true

set +e
E=0

if [[ -f scripts/fabricate.py ]]; then
  log "fabricate…"
  python3 scripts/fabricate.py || { log "[ERR] fabricate failed"; E=1; }
else
  log "[WARN] scripts/fabricate.py missing"
fi

if [[ -f scripts/ready_gate.py ]]; then
  log "ready gate…"
  python3 scripts/ready_gate.py || { log "[ERR] ready gate failed"; E=1; }
else
  log "[WARN] scripts/ready_gate.py missing"
fi

if [[ -x bin/geo-filter.sh ]]; then
  log "geo filter…"
  bin/geo-filter.sh || log "[WARN] geo filter nonfatal"
fi

if [[ -f scripts/sitemap_build.py ]]; then
  log "sitemaps…"
  python3 scripts/sitemap_build.py || log "[WARN] sitemap build nonfatal"
fi

if [[ -x bin/release_cut.sh ]]; then
  log "release cut…"
  bin/release_cut.sh || { log "[ERR] release cut failed"; E=1; }
else
  log "[WARN] bin/release_cut.sh missing"
fi

all=$(find dist -type f -name '*.html' 2>/dev/null | wc -l)
ready=$(find dist_ready -type f -name '*.html' 2>/dev/null | wc -l)
log "counts: all=$all ready=$ready err=$E"
exit 0   # keep systemd green; check logs for [ERR]

[[ -x bin/autotune.sh ]] && bin/autotune.sh

[[ -x bin/harden-verify.sh ]] && bin/harden-verify.sh

[[ -x bin/status-gen.sh ]] && bin/status-gen.sh

[[ -x bin/health-html.sh ]] && bin/health-html.sh

[[ -x bin/publish-free.sh ]] && bin/publish-free.sh

[[ -x bin/grow-seeds.sh ]] && bin/grow-seeds.sh

[[ -x bin/linkscan-run.sh ]] && bin/linkscan-run.sh
