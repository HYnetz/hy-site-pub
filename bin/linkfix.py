import os, pathlib, hashlib, re
ROOT=pathlib.Path.home()/ "hy"
SCAN=ROOT/"ops/logs/linkscan.txt"
FALLBACK=os.environ.get("FALLBACK","/data/")
TDEST=ROOT/"dist_ready"/"t"
TDEST.mkdir(parents=True, exist_ok=True)
if not SCAN.exists():
    print("[LINKFIX] no scan file; run linkscan first"); raise SystemExit(0)
# parse scan
broken=[]; srcs={}
cur=None
for line in SCAN.read_text(encoding="utf-8").splitlines():
    if not line.strip(): continue
    if line.startswith("/"):
        cur=line.split("\t",1)[0].strip(); broken.append(cur); srcs[cur]=[]
    elif line.startswith("  ") and cur:
        srcs[cur].append(line.strip())
def mkredir(path, target):
    h=hashlib.sha1(path.encode()).hexdigest()[:10]
    d=TDEST/f"fix-{h}"
    d.mkdir(parents=True, exist_ok=True)
    (d/"index.html").write_text(f"<!doctype html><meta http-equiv='refresh' content='0;url={target}'>",encoding="utf-8")
    return f"/t/{d.name}/"
# rewrite links in CURRENT (fast feedback)
changed=0
for br in broken:
    new=mkredir(br, FALLBACK)
    for rel in srcs.get(br,[]):
        f=ROOT/rel
        if not f.exists(): continue
        txt=f.read_text(encoding="utf-8",errors="ignore")
        ntxt=txt.replace(f'"{br}"', f'"{new}"').replace(f"'{br}'", f"'{new}'")
        if ntxt!=txt:
            f.write_text(ntxt, encoding="utf-8"); changed+=1
print(f"[LINKFIX] redirects made={len(broken)} files_rewritten={changed} fallback={FALLBACK}")
