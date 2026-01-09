#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REL_DIR="$ROOT/releases"
SRC="$ROOT/dist_ready"
CUR="$ROOT/current"
mkdir -p "$REL_DIR"
ts="$(date +%F_%H%M%S)"
dst="$REL_DIR/$ts"; mkdir -p "$dst"

copy_tree() {
  if command -v rsync >/dev/null 2>&1; then rsync -a "$1/." "$2/";
  else ( shopt -s dotglob nullglob; cp -a "$1"/* "$2"/ 2>/dev/null || true ); fi
}

# 1) Copy new build (including /data) without deleting existing
[[ -d "$SRC" ]] && find "$SRC" -type f 2>/dev/null | grep -q . && copy_tree "$SRC" "$dst" || true

# 2) Carry protected top-level if missing
for f in index.html robots.txt sitemap_index.xml sitemap.xsl imprint.html privacy.html health.html status.html; do
  [[ -f "$CUR/$f" && ! -f "$dst/$f" ]] && cp -f "$CUR/$f" "$dst/$f"
done
# carry assets (css/images)
[[ -d "$CUR/assets" ]] && { mkdir -p "$dst/assets"; copy_tree "$CUR/assets" "$dst/assets"; }

# 3) Ensure /data exists: prefer new build; else carry from current
if [[ ! -d "$dst/data" || -z "$(find "$dst/data" -type f -name index.html 2>/dev/null | head -n1)" ]]; then
  if [[ -d "$CUR/data" ]]; then
    mkdir -p "$dst/data"; copy_tree "$CUR/data" "$dst/data"
  fi
fi

# 4) Merge redirects (/t) from current
if [[ -d "$CUR/t" ]]; then mkdir -p "$dst/t"; ( shopt -s dotglob nullglob; cp -an "$CUR/t"/* "$dst/t"/ 2>/dev/null || true ); fi

# 5) Backfill legal + robots if still missing
for f in imprint.html privacy.html; do [[ -f "$dst/$f" ]] || echo "<!doctype html><meta charset='utf-8'><link rel='stylesheet' href='/assets/site.css'><h1>${f%.*}</h1>" > "$dst/$f"; done
[[ -f "$dst/robots.txt" ]] || printf "User-agent: *\nDisallow: /\n" > "$dst/robots.txt"

# 6) Generate sitemap-data.xml from /data if missing
if [[ ! -f "$dst/sitemap-data.xml" && -d "$dst/data" ]]; then
  now="$(date +%F)"
  { printf '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
    find "$dst/data" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort | while read -r d; do
      printf "  <url><loc>/data/%s/</loc><lastmod>%s</lastmod><changefreq>weekly</changefreq></url>\n" "$d" "$now"
    done
    printf '</urlset>\n'; } > "$dst/sitemap-data.xml"
fi

# 7) Always rebuild sitemap_index.xml from whatever sitemaps exist
maps=$(cd "$dst" && find . -type f -name 'sitemap*.xml' ! -name 'sitemap_index.xml' -printf '%P\n' | sort || true)
{ printf '<?xml version="1.0" encoding="UTF-8"?>\n<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
  [[ -n "${maps:-}" ]] && printf '%s\n' "$maps" | while IFS= read -r m; do printf "  <sitemap><loc>/%s</loc></sitemap>\n" "$m"; done
  printf '</sitemapindex>\n'; } > "$dst/sitemap_index.xml"

ln -sfn "$dst" "$ROOT/current"
echo "[RELEASE] current -> $dst"
