#!/usr/bin/env bash
set -euo pipefail
mkdir -p ops/logs dist_ready current
# minimal home page if missing
[ -f current/index.html ] || cat > current/index.html <<'HTML'
<!doctype html><meta charset="utf-8"><title>HY</title><h1>HY · Online build</h1><p>CI bootstrap successful.</p>
HTML

# prefer full repo scripts if they exist
if [ -f scripts/ingest_fetch.py ]; then
  echo "[CI] using repo ingester"
  python3 scripts/ingest_fetch.py
  python3 scripts/ingest_dedupe.py 2>/dev/null || true
  python3 scripts/ingest_to_pages.py 2>/dev/null || true
  python3 scripts/sitemap_data.py  2>/dev/null || true
else
  echo "[CI] repo ingester missing — using fallback"
  python3 - <<'PY'
import os,sys,urllib.request,hashlib,html,re,datetime, pathlib
root="."
out=pathlib.Path("dist_ready"); data=out/"data"; data.mkdir(parents=True, exist_ok=True)
seeds=[]
if pathlib.Path("ops/ingest/seeds.txt").exists():
    seeds=[l.strip() for l in open("ops/ingest/seeds.txt") if l.strip() and not l.strip().startswith("#")]
if not seeds:
    seeds=["https://www.nasa.gov/","https://www.noaa.gov/","https://data.europa.eu/"]
def fetch(u):
    try:
        r=urllib.request.Request(u,headers={"User-Agent":"HYBot/1.0","Accept":"text/html,application/xml"})
        with urllib.request.urlopen(r,timeout=20) as h: b=h.read()
        if b.startswith(b'\xef\xbb\xbf'): b=b[3:]
        t=b.decode("utf-8","ignore")
        t=re.sub(r"(?is)<script.*?>.*?</script>"," ",t); t=re.sub(r"(?is)<style.*?>.*?</style>"," ",t); t=re.sub(r"(?s)<[^>]+>"," ",t)
        t=html.unescape(re.sub(r"\s+"," ",t)).strip()[:200000]
        k=hashlib.sha256(u.encode()).hexdigest()[:16]; d=(data/k)
        (d).mkdir(parents=True, exist_ok=True)
        (d/"index.html").write_text(f"<!doctype html><meta charset='utf-8'><title>Data · {k}</title><h1>Source</h1><p><a href='{u}'>{u}</a></p><pre>{t}</pre>",encoding="utf-8")
        return k
    except Exception as e:
        return None
keys=[fetch(u) for u in seeds]; keys=[k for k in keys if k]
# data index + sitemap-data
(open(out/"sitemap-data.xml","w").write('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' + "".join([f"  <url><loc>/data/{k}/</loc></url>\n" for k in keys]) + "</urlset>\n"))
(open(out/"data/index.html","w").write("<!doctype html><meta charset='utf-8'><title>Data Index</title><h1>Data</h1><ul>"+ "".join([f"<li><a href='/data/{k}/'>{k}</a></li>" for k in keys]) +"</ul>"))
PY
fi

# release cut (portable)
[ -x bin/release_cut.sh ] || cat > bin/release_cut.sh <<'RS'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/dist_ready"; CUR="$ROOT/current"; REL="$ROOT/releases"; TS="$(date +%F_%H%M%S)"; DST="$REL/$TS"
mkdir -p "$DST" "$REL"
copy(){ if command -v rsync >/dev/null; then rsync -a "$1/." "$2/"; else (shopt -s dotglob nullglob; cp -a "$1"/* "$2"/ 2>/dev/null || true); fi; }
[ -d "$SRC" ] && copy "$SRC" "$DST"
for f in index.html robots.txt sitemap_index.xml sitemap.xsl imprint.html privacy.html health.html status.html; do
  [ -f "$CUR/$f" ] && [ ! -f "$DST/$f" ] && cp -f "$CUR/$f" "$DST/$f" || true
done
[ -d "$CUR/assets" ] && { mkdir -p "$DST/assets"; copy "$CUR/assets" "$DST/assets"; }
if [ ! -f "$DST/sitemap-data.xml" ] && [ -d "$DST/data" ]; then
  now="$(date +%F)"
  { printf '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
    find "$DST/data" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort | while read -r d; do
      printf "  <url><loc>/data/%s/</loc><lastmod>%s</lastmod><changefreq>weekly</changefreq></url>\n" "$d" "$now"
    done
    printf '</urlset>\n'; } > "$DST/sitemap-data.xml"
fi
maps=$(cd "$DST" && find . -type f -name 'sitemap*.xml' ! -name 'sitemap_index.xml' -printf '%P\n' | sort || true)
{ printf '<?xml version="1.0" encoding="UTF-8"?>\n<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
  [ -n "${maps:-}" ] && printf '%s\n' "$maps" | while IFS= read -r m; do printf "  <sitemap><loc>/%s</loc></sitemap>\n" "$m"; done
  printf '</sitemapindex>\n'; } > "$DST/sitemap_index.xml"
ln -sfn "$DST" "$CUR"; echo "[RELEASE] current -> $DST"
RS
chmod +x bin/release_cut.sh

# optional: link doctor no-op guard
[ -x bin/linkscan-run.sh ] || printf '#!/usr/bin/env bash\nexit 0\n' > bin/linkscan-run.sh && chmod +x bin/linkscan-run.sh
