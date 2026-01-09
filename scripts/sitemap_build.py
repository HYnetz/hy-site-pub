import os, time, hashlib, xml.sax.saxutils as s

BASE="dist_ready"
HOST="https://preview.local"  # replaced later if you mirror
urls=[]
for r,_,fs in os.walk(BASE):
    for fn in fs:
        if fn.endswith(".html"):
            p=os.path.join(r,fn)
            rel=os.path.relpath(p, BASE)
            url = HOST + "/" + rel.replace("\\","/")
            urls.append(url)

# split into chunks (≤1000 per sitemap)
chunks=[urls[i:i+1000] for i in range(0,len(urls),1000)]
os.makedirs("dist_ready",exist_ok=True)
index_entries=[]
for i,chunk in enumerate(chunks, start=1):
    sm=f"dist_ready/sitemap_{i:04d}.xml"
    with open(sm,"w",encoding="utf-8") as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n')
        for u in chunk:
            f.write(f"<url><loc>{s.escape(u)}</loc></url>\n")
        f.write("</urlset>")
    index_entries.append(sm)

# index
with open("dist_ready/sitemap_index.xml","w",encoding="utf-8") as f:
    f.write('<?xml version="1.0" encoding="UTF-8"?>\n<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n')
    for sm in index_entries:
        f.write(f"<sitemap><loc>{s.escape('https://preview.local/'+os.path.basename(sm))}</loc></sitemap>\n")
    f.write("</sitemapindex>\n")
print(f"[SITEMAP] files={len(index_entries)} total_urls={len(urls)}")
