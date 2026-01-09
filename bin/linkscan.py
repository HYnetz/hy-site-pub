import re, os, pathlib, subprocess, collections
ROOT=pathlib.Path.home()/ "hy"
BASE="http://localhost:8080"
files=[p for p in (ROOT/"current").rglob("*.html")]
files=files[:5000]  # cap so it stays fast
pat=re.compile(r'''(?:href|src)\s*=\s*["'](/[^"']+)["']''', re.I)
refs=collections.defaultdict(set)
for fp in files:
    try: s=fp.read_text('utf-8',errors='ignore')
    except: continue
    for m in pat.finditer(s):
        url=m.group(1)
        if url.startswith("/"): refs[url].add(str(fp.relative_to(ROOT)))
bad={}
for url,froms in refs.items():
    try:
        code=subprocess.check_output(["bash","-lc", f"curl -s -o /dev/null -w '%{{http_code}}' {BASE}{url}"], text=True).strip()
    except Exception: code="000"
    if code.startswith("4") or code.startswith("5") or code=="000":
        bad[url]=froms
out=ROOT/"ops/logs/linkscan.txt"
with out.open("w",encoding="utf-8") as w:
    for url,froms in sorted(bad.items()):
        w.write(f"{url}\t{len(froms)}\n")
        for f in sorted(froms)[:10]: w.write(f"  {f}\n")
print(f"[LINKSCAN] broken={len(bad)} -> {out}")
