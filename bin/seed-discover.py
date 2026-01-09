import re,urllib.request,ssl,sys, pathlib
B=pathlib.Path("ops/ingest/base_domains.txt")
S=pathlib.Path("ops/ingest/seeds.txt"); S.parent.mkdir(parents=True, exist_ok=True)
ua="HYBot/1.0"; ctx=ssl.create_default_context()
domains=[l.strip() for l in (B.read_text().splitlines() if B.exists() else []) if l.strip() and not l.startswith("#")]
seeds=set()
def get(u):
    try:
        r=urllib.request.Request(u,headers={"User-Agent":ua})
        with urllib.request.urlopen(r,timeout=12,context=ctx) as h: return h.read().decode("utf-8","ignore")
    except: return ""
for d in domains:
    scheme="https://"+d
    robots=get(scheme+"/robots.txt")
    for m in re.findall(r'(?im)^\s*Sitemap:\s*(\S+)', robots): seeds.add(m.strip())
    for p in ("/sitemap.xml","/sitemap_index.xml","/sitemap/sitemap.xml","/sitemap/sitemap-index.xml"):
        seeds.add(scheme+p)
norm=[u for u in sorted(seeds) if u.startswith("http")]
S.write_text("\n".join(norm)+"\n")
print(f"[DISCOVER] seeds={len(norm)} -> {S}")
