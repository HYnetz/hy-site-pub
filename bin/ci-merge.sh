#!/usr/bin/env bash
set -euo pipefail
mkdir -p current
for tgz in shards/*.tgz; do [ -f "$tgz" ] && tar -C current -xzf "$tgz" || true; done
now="$(date +%F %T)"
# sitemap-data if /data exists
if [ -d current/data ]; then
  { printf '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
    find current/data -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort | while read -r d; do
      printf "  <url><loc>/data/%s/</loc><lastmod>%s</lastmod></url>\n" "$d" "$(date +%F)"
    done
    printf '</urlset>\n'; } > current/sitemap-data.xml || true
fi
{ printf '<?xml version="1.0" encoding="UTF-8"?>\n<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
  find current -maxdepth 1 -type f -name 'sitemap*.xml' ! -name 'sitemap_index.xml' -printf '%P\n' | sort | while read -r m; do
    [ -n "$m" ] && printf "  <sitemap><loc>/%s</loc></sitemap>\n" "$m"
  done
  printf '</sitemapindex>\n'; } > current/sitemap_index.xml
# status
COUNT=$(find current/data -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
cat > current/status.html <<HTML
<!doctype html><meta charset="utf-8"><title>HY Status</title>
<h1>HY Status</h1>
<p>Last merge: ${now}</p>
<p>Data buckets: ${COUNT}</p>
HTML
[ -f current/index.html ] || echo '<!doctype html><title>HY</title><h1>OK</h1>' > current/index.html
echo "[CI] merge complete: buckets=${COUNT}"
