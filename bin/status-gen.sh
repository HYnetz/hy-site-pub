#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/hy"; CUR="$ROOT/current"; LOG="$ROOT/ops/logs/hy-omni.out.log"
ts="$(date -Is)"
counts="$(tac "$LOG" 2>/dev/null | grep -m1 'counts:' || echo 'counts: all=? ready=? err=?')"
datacnt="$(find "$CUR/data" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l || echo 0)"
rel="$(readlink -f "$CUR" || echo unknown)"; durel="$(du -sh "$CUR" 2>/dev/null | awk '{print $1}')"
mkdir -p "$CUR"
cat > "$CUR/status.html" <<HTML
<!doctype html><meta charset="utf-8"><title>HY · Status</title>
<link rel="stylesheet" href="/assets/site.css">
<nav><a href="/">Home</a><a href="/health.html">Health</a><a href="/data/">Data</a><a href="/sitemap_index.xml">Sitemap</a></nav>
<h1>HY · Self-Build Status</h1>
<section><div class="badge" style="color:#9aa4ad">$ts</div>
<ul>
<li><span class="k">Release:</span> <strong>$(basename "$rel")</strong> <span class="k">(~$durel)</span></li>
<li><span class="k">Counts:</span> <strong>$counts</strong></li>
<li><span class="k">/data folders:</span> <strong>$datacnt</strong></li>
</ul></section>
HTML
echo "[STATUSHTML] wrote $CUR/status.html"
