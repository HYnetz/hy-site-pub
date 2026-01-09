#!/usr/bin/env bash
set -euo pipefail
p_all=$(find dist -type f -name '*.html' 2>/dev/null | wc -l | tr -d ' ')
p_ready=$(find dist_ready -type f -name '*.html' 2>/dev/null | wc -l | tr -d ' ')
sitemaps=$(find dist_ready -type f -name 'sitemap_*.xml' 2>/dev/null | wc -l | tr -d ' ')
echo "=== HY Scoreboard ==="
echo "Pages (all):   $p_all"
echo "Pages (ready): $p_ready"
echo "Ready-rate:    $(python3 - <<'PY'
a=int("""$p_all"""); r=int("""$p_ready"""); 
print("0.00%" if a==0 else f"{(r/max(a,1))*100:.2f}%")
PY
)"
echo "Sitemaps:      $sitemaps"
echo "Robots:        $(head -n1 dist/robots.txt 2>/dev/null || echo '(missing)')"
echo "Money mode:    $(grep -E '^MONEY_MODE=' .env | cut -d= -f2)"
echo "Stealth:       $(grep -E '^STEALTH=' .env | cut -d= -f2)"
echo "[OK]"
