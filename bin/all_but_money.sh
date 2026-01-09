#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/hy"; cd "$ROOT"
mkdir -p ops/logs ops/harden bin

echo "[LOCK] money OFF"
grep -q '^MONEY_MODE=' .env 2>/dev/null || echo "MONEY_MODE=false" >> .env
sed -i 's/^MONEY_MODE=.*/MONEY_MODE=false/' .env || true
touch ops/MONEY_LOCK_OFF

# Guard money flip script (if present) to respect lock
if [[ -f scripts/flip-money-mode.sh ]] && ! grep -q 'MONEY_LOCK_OFF' scripts/flip-money-mode.sh; then
  awk 'NR==1{print; print "[ -f ops/MONEY_LOCK_OFF ] && { echo \"[MONEY] locked OFF\"; exit 0; }"; next}1' \
    scripts/flip-money-mode.sh > scripts/.flip.tmp && mv scripts/.flip.tmp scripts/flip-money-mode.sh && chmod +x scripts/flip-money-mode.sh
fi

# Ensure omni runner exists (non-fatal, logs errors but keeps timer green)
if [[ ! -x bin/omni-cycle.sh ]]; then
  cat > bin/omni-cycle.sh <<'X'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/hy"; cd "$ROOT"
log(){ echo "[OMNI] $*"; }
log "cycle ts=$(date +%F_%H%M%S)"
free_mb=$(df -Pm "$ROOT" | awk 'NR==2{print $4}'); log "free_mb=$free_mb"
set +e; E=0
[[ -x bin/ingest-once.sh ]] && { log "ingest…"; bin/ingest-once.sh || log "[WARN] ingest failed"; }
[[ -f scripts/fabricate.py ]] && { log "fabricate…"; python3 scripts/fabricate.py || { log "[ERR] fabricate"; E=1; }; } || log "[WARN] no fabricate.py"
[[ -f scripts/ready_gate.py ]] && { log "ready gate…"; python3 scripts/ready_gate.py || { log "[ERR] ready"; E=1; }; } || log "[WARN] no ready_gate.py"
[[ -f scripts/sitemap_build.py ]] && { log "sitemaps…"; python3 scripts/sitemap_build.py || log "[WARN] sitemap"; } || true
[[ -x bin/release_cut.sh ]] && { log "release cut…"; bin/release_cut.sh || { log "[ERR] release"; E=1; }; } || log "[WARN] no release_cut.sh"
all=$(find dist -type f -name '*.html' 2>/dev/null | wc -l); ready=$(find dist_ready -type f -name '*.html' 2>/dev/null | wc -l)
log "counts: all=$all ready=$ready err=$E"; exit 0
X
  chmod +x bin/omni-cycle.sh
fi

# Make sure ingest + autotune are hooked (if installed)
grep -q 'bin/ingest-once.sh' bin/omni-cycle.sh 2>/dev/null || sed -i '1a [[ -x bin/ingest-once.sh ]] && bin/ingest-once.sh || true' bin/omni-cycle.sh || true
grep -q 'bin/autotune.sh'    bin/omni-cycle.sh 2>/dev/null || printf '\n[[ -x bin/autotune.sh ]] && bin/autotune.sh\n' >> bin/omni-cycle.sh || true

# Basic hardening: checksums for release + quick verify on each cut; simple log rotate
cat > bin/harden-verify.sh <<'X'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/hy"; CUR="$ROOT/current"; MAN="$ROOT/ops/harden/manifest.sha256"
mkdir -p "$ROOT/ops/harden"
# build manifest if missing
if [[ ! -f "$MAN" ]]; then (cd "$CUR" && find . -type f -maxdepth 3 -print0 | xargs -0 sha256sum) > "$MAN"; echo "[HARDEN] manifest created"; exit 0; fi
# verify current
(cd "$CUR" && sha256sum --quiet -c "$MAN") && echo "[HARDEN] verify OK" || echo "[HARDEN] drift DETECTED"
# rotate big logs
for L in "$ROOT/ops/logs/hy-omni.out.log" "$ROOT/ops/logs/hy-omni.err.log" "$ROOT/ops/logs/hy-serve.err.log"; do
  [[ -f "$L" ]] || continue; sz=$(du -m "$L" | awk '{print $1}'); [[ $sz -gt 50 ]] && : > "$L" && echo "[LOG] rotated $L"
done
X
chmod +x bin/harden-verify.sh
grep -q 'harden-verify.sh' bin/omni-cycle.sh 2>/dev/null || printf '\n[[ -x bin/harden-verify.sh ]] && bin/harden-verify.sh\n' >> bin/omni-cycle.sh

# Ensure top-level basics exist
mkdir -p current
[[ -f current/index.html ]] || echo "<!doctype html><meta charset='utf-8'><h1>HY · Control</h1>" > current/index.html
[[ -f current/imprint.html ]] || echo "<!doctype html><meta charset='utf-8'><h1>Imprint</h1>" > current/imprint.html
[[ -f current/privacy.html ]] || echo "<!doctype html><meta charset='utf-8'><h1>Privacy</h1>" > current/privacy.html
[[ -f current/robots.txt ]] || printf "User-agent: *\nDisallow: /\n" > current/robots.txt
[[ -f current/sitemap_index.xml ]] || printf '<?xml version="1.0" encoding="UTF-8"?>\n<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n</sitemapindex>\n' > current/sitemap_index.xml

# Timer + one kick
systemctl --user daemon-reload || true
systemctl --user enable --now hy-omni.timer || true
systemctl --user start hy-omni.service || true

# Summary
echo "---- SUMMARY ----"
echo "Money: $(grep -oE '^MONEY_MODE=.*' .env | head -n1)"
systemctl --user is-active hy-omni.timer && echo "Timer: active" || echo "Timer: inactive"
echo "Counts: dist=$(find dist -type f -name '*.html' 2>/dev/null|wc -l) ready=$(find dist_ready -type f -name '*.html' 2>/dev/null|wc -l)"
echo "HTTP / : $(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/ || echo NA)"
