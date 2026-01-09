import sys, pathlib, urllib.request, re
ROOT=pathlib.Path.home()/ "hy"
allow=[l.strip() for l in (ROOT/"ops/ingest/allowlist.txt").read_text(encoding="utf-8").splitlines()
       if l.strip() and not l.strip().startswith("#")]
targets=sys.argv[1:] or allow
ua='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36'
hdr={"User-Agent":ua,"Accept":"text/plain,text/html,*/*;q=0.1","Accept-Language":"en-US,en;q=0.9"}
found=[]
for d in targets:
    for scheme in ("https","http"):
        url=f"{scheme}://{d}/robots.txt"
        try:
            req=urllib.request.Request(url,headers=hdr)
            txt=urllib.request.urlopen(req,timeout=15).read().decode("utf-8","ignore")
        except Exception:
            continue
        for line in txt.splitlines():
            if line.lower().startswith("sitemap:"):
                sm=line.split(":",1)[1].strip()
                if sm and d in sm:
                    found.append(sm)
        break
seeds_path=ROOT/"ops/ingest/seeds.txt"
existing=set(l.strip() for l in seeds_path.read_text(encoding="utf-8").splitlines() if l.strip() and not l.startswith("#")) if seeds_path.exists() else set()
new=[u for u in found if u not in existing]
if new:
    with seeds_path.open("a",encoding="utf-8") as w:
        for u in new[:50]: w.write(u+"\n")
print(f"[DISCOVER] added {len(new[:50])} sitemaps -> {seeds_path}")
