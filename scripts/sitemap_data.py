import os, time, pathlib
ROOT=pathlib.Path.home()/ "hy"
OUT =ROOT/"dist_ready"
DATA=ROOT/"dist_ready"/"data"
sm=OUT/"sitemap-data.xml"
now=time.strftime("%Y-%m-%d")
with open(sm,"w",encoding="utf-8") as w:
    w.write('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n')
    for d in sorted([p for p in DATA.iterdir() if p.is_dir()]):
        loc=f"/data/{d.name}/"
        w.write(f"  <url><loc>{loc}</loc><lastmod>{now}</lastmod><changefreq>weekly</changefreq></url>\n")
    w.write("</urlset>\n")
print("[SITEMAP] data ok")
