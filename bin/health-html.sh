#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/hy"; CUR="$ROOT/current"
mkdir -p "$CUR"
OUT="$CUR/health.html"
HEALTH="$("$ROOT/bin/health.sh" 2>&1 || true)"
ts="$(date -Is)"
cat > "$OUT" <<HTML
<!doctype html><meta charset="utf-8"><title>HY · Health</title>
<link rel="stylesheet" href="/assets/site.css">
<nav><a href="/">Home</a><a href="/status.html">Status</a><a href="/data/">Data</a><a href="/sitemap_index.xml">Sitemap</a></nav>
<h1>HY · Health</h1>
<section><div class="badge" style="color:#9aa4ad">$ts</div><pre>$HEALTH</pre></section>
HTML
echo "[HEALTHHTML] wrote $OUT"
