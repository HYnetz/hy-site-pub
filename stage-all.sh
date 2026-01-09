#!/usr/bin/env bash
set -euo pipefail
mkdir -p switchboard/active switchboard/profiles floor dist ops/logs partner/packs_bulk partner/links receipts

# 1) Aggressive profile (Money OFF)
cat > switchboard/profiles/domination.ini <<'INI'
inherit=../base.ini
[modes] stealth=true
money_mode=false
[expansion]
partner_weekly_target_seed=100
portal_publish_weekly_seed=800
partner_weekly_target_money=150
portal_publish_weekly_money=1200
roas_capture_enabled=false
roas_min=1.0
capture_daily_cap_m1=1200
capture_daily_cap_m2=1800
capture_daily_cap_m3=2500
INI
echo "inherit=../profiles/domination.ini" > switchboard/active/active_profile.ini
cp floor/floor_v5_optional.ini floor/active_floor.ini 2>/dev/null || true

# 2) Robots & disclaimer
cat > dist/robots.public.txt <<R
User-agent: *
Disallow:
Sitemap: /sitemap_index.xml
R
cat > dist/robots.stealth.txt <<R
User-agent: *
Disallow: /
R
cp dist/robots.stealth.txt dist/robots.txt
cat > dist/_disclaimer.html <<HTML
<p><strong>No outcome promises.</strong> Evidence-first guides citing official sources. No custody of funds. WCAG AA. City/region gates apply.</p>
HTML

# 3) Generate 40k static pages (10 locales × 5 lanes)
PAGES="${1:-40000}"; LOCALES=(en de es fr it pt pl nl ro tr); LANES=(finance telco utilities travel housing)
count=0
for i in $(seq 1 "$PAGES"); do
  L=${LOCALES[$RANDOM % ${#LOCALES[@]}]}; V=${LANES[$RANDOM % ${#LANES[@]}]}
  d="dist/$L/$V"; slug="p-$L-$V-$i"; f="$d/$slug.html"; mkdir -p "$d"
  cat > "$f" <<HTML
<!doctype html><html lang="$L"><meta charset="utf-8">
<title>$V — evidence pack $i</title>
<link rel="canonical" href="/$L/$V/$slug.html"><meta name="viewport" content="width=device-width,initial-scale=1">
<main style="max-width:860px;margin:40px auto;font-family:sans-serif;line-height:1.5">
<h1>$V — Evidence pack #$i</h1>
<p>Plain summary (2–3 lines). Official path only.</p>
<h2>Evidence checklist</h2><ul><li>ID/contact</li><li>Account/contract no.</li><li>Timestamped emails/invoices</li><li>Official policy link(s)</li></ul>
<h2>Official steps</h2><ol><li>Gather evidence</li><li>Use letter/packet</li><li>Send via official channel</li><li>Wait statutory response → escalate</li></ol>
<h2>Letter/packet</h2><p>To: [authority] • Subject: [issue] • Text: [facts + policy cite] • Attach: [evidence]</p>
<hr><div id="disclaimer">$(cat dist/_disclaimer.html)</div>
</main></html>
HTML
  count=$((count+1))
done
echo "[✓] generated $count pages"

# 4) Sitemaps (chunk 1,000)
find dist -type f -name "*.html" | sed 's#^dist##' | awk 'BEGIN{c=0;f=0}
 {if(c%1000==0){if(c>0)print "</urlset>" > sprintf("dist/sitemap-%04d.xml",f); f++;
 print "<?xml version=\"1.0\" encoding=\"UTF-8\"?><urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">" > sprintf("dist/sitemap-%04d.xml",f)}
 print "<url><loc>"$0"</loc></url>" >> sprintf("dist/sitemap-%04d.xml",f); c++}
 END{print "</urlset>" >> sprintf("dist/sitemap-%04d.xml",f)}'
ls dist/sitemap-*.xml | awk 'BEGIN{print "<?xml version=\"1.0\" encoding=\"UTF-8\"?><sitemapindex xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">"}{gsub("dist/",""); print "<sitemap><loc>/"$0"</loc></sitemap>"}END{print "</sitemapindex>"}' > dist/sitemap_index.xml

# 5) 1,000 partner packs w/ unique keys + CSV
: > partner/links/partners.csv
for i in $(seq 1 1000); do
  key=$(tr -dc a-z0-9 </dev/urandom | head -c 12)
  d="partner/packs_bulk/partner_$i"; mkdir -p "$d"
  cat > "$d/embed_snippet.html" <<H
<script async src="https://YOURDOMAIN/widget.js"
  data-hy-portal="finance_cex_freeze" data-lang="en" data-evidence-required="true"
  data-partner-key="$key"></script>
<noscript>Enable JavaScript to use the Hy helper.</noscript>
H
  cat > "$d/one_pager_terms.md" <<T
Evidence-first helper; official sources only. No outcome promises. No custody of funds.
Auto-pause if complaints >1.2/1k; remove anytime. Daily micro-payouts post-S1. Paste snippet before </body>.
T
  ( cd "$d" && zip -qr "../partner_${i}_${key}.zip" embed_snippet.html one_pager_terms.md )
  echo "partner_${i},$key,/partner/packs_bulk/partner_${i}_${key}.zip,/l/partner?pk=$key&utm_source=partner_${i}&utm_medium=embed" >> partner/links/partners.csv
done

# 6) Toggles, preview, stats, simple integrity receipt
cat > toggle-index.sh <<'TGL'
#!/usr/bin/env bash
set -euo pipefail; m="${1:-}"; [[ -z "$m" ]] && { echo "use: public|stealth"; exit 1; }
[[ "$m" == "public" ]] && cp dist/robots.public.txt dist/robots.txt && echo "[ok] indexing ALLOWED"
[[ "$m" == "stealth" ]] && cp dist/robots.stealth.txt dist/robots.txt && echo "[ok] indexing BLOCKED"
TGL
chmod +x toggle-index.sh
cat > serve-local.sh <<'SRV'
#!/usr/bin/env bash
set -euo pipefail; cd dist && python3 -m http.server 8080
SRV
chmod +x serve-local.sh
cat > stats.sh <<'ST'
#!/usr/bin/env bash
set -euo pipefail
echo -n "[pages] "; find dist -type f -name "*.html" | wc -l
echo -n "[sitemaps] "; ls dist/sitemap-*.xml 2>/dev/null | wc -l
echo -n "[partner packs] "; ls partner/packs_bulk/*.zip 2>/dev/null | wc -l
ST
chmod +x stats.sh
python3 - <<'PY'
import os,hashlib,json
paths=[]
for r,_,fs in os.walk("dist"):
  for fn in fs:
    if fn.endswith((".html",".xml")) or fn=="robots.txt":
      p=os.path.join(r,fn); h=hashlib.sha256(open(p,"rb").read()).hexdigest()
      paths.append({"path":p,"sha256":h})
paths.sort(key=lambda x:x["path"])
def merkle(leaves):
  b=[bytes.fromhex(x["sha256"]) for x in leaves]
  if not b: return ""
  while len(b)>1:
    b=[hashlib.sha256(b[i]+(b[i+1] if i+1<len(b) else b[i])).digest() for i in range(0,len(b),2)]
  return b[0].hex()
root=merkle(paths)
os.makedirs("receipts",exist_ok=True)
json.dump({"root":root,"files":paths},open("receipts/anchor.json","w"),indent=2)
print("[ok] receipts/anchor.json",root)
PY

echo; ./stats.sh
echo "[✓] Staged: indexing OFF (stealth). Flip later with ./toggle-index.sh public"
