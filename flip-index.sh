#!/usr/bin/env bash
set -euo pipefail
mode="${1:-}"; [[ "$mode" =~ ^(public|stealth)$ ]] || { echo "use: public|stealth"; exit 2; }
ROOT="$HOME/hy/current"
pub="$ROOT/robots.public.txt"; stl="$ROOT/robots.stealth.txt"
[[ -f "$pub" ]] || printf "User-agent: *\nDisallow:\nSitemap: /sitemap_index.xml\n" > "$pub"
[[ -f "$stl" ]] || printf "User-agent: *\nDisallow: /\n" > "$stl"
if [[ "$mode" == "public" ]]; then cp -f "$pub" "$ROOT/robots.txt" && echo "[INDEX] public"; else cp -f "$stl" "$ROOT/robots.txt" && echo "[INDEX] stealth"; fi
