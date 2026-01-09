#!/usr/bin/env bash
set -u
ROOT="$HOME/hy"; cd "$ROOT" || { echo "[FAIL] $ROOT missing"; exit 1; }
ok(){ printf "\033[32m[OK]\033[0m %s\n" "$*"; }
wr(){ printf "\033[33m[WARN]\033[0m %s\n" "$*"; }
pass=1

# timers
for t in hy-omni.timer hy-guard.timer hy-worm.timer; do
  s=$(systemctl --user is-active "$t" 2>/dev/null || echo inactive)
  [[ "$s" = active ]] && ok "timer $t active" || wr "timer $t $s"
done

# ensure server
pgrep -f "http.server 8080" >/dev/null || { nohup python3 -m http.server 8080 -d "$ROOT/current" >> "$ROOT/ops/logs/hy-serve.err.log" 2>&1 & sleep 1; }

# HTTP checks
hc(){ curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080$1" || echo 000; }
for p in / /data/ /sitemap_index.xml /sitemap-data.xml /imprint.html /privacy.html /robots.txt /status.html /health.html; do
  c=$(hc "$p"); [[ "$c" = 200 ]] && ok "HTTP $p = 200" || { wr "HTTP $p = $c"; pass=0; }
done

# data presence
if [[ -d current/data ]]; then
  cnt=$(find current/data -mindepth 1 -maxdepth 1 -type d | wc -l)
  [[ "$cnt" -gt 0 ]] && ok "data folders: $cnt" || wr "no data folders"
else wr "current/data missing"; pass=0; fi

# sitemap lists data
grep -q 'sitemap-data.xml' current/sitemap_index.xml 2>/dev/null && ok "sitemap-data.xml listed" || wr "sitemap-data.xml not listed"

# money lock
grep -q '^MONEY_MODE=false' .env 2>/dev/null && ok "MONEY_MODE=false" || { wr ".env missing or not false"; pass=0; }
[[ -f ops/MONEY_LOCK_OFF ]] && ok "money lock file present" || wr "money lock file missing"

# integrity verify
if [[ -x bin/harden-verify.sh ]]; then
  OUT=$(bin/harden-verify.sh || true)
  echo "$OUT"
  if echo "$OUT" | grep -qE 'verify OK|manifest \(re\)created'; then
    ok "integrity OK"
  else
    wr "integrity not verified"
    pass=0
  fi
else wr "harden-verify.sh missing (optional)"; fi

# last omni counts
[[ -f ops/logs/hy-omni.out.log ]] && tac ops/logs/hy-omni.out.log | grep -m1 'counts:' >/dev/null && ok "omni counts present" || wr "no recent omni counts"

[[ $pass -eq 1 ]] && echo "HEALTH: OK" || echo "HEALTH: CHECK WARNINGS"
