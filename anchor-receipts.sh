#!/usr/bin/env bash
set -euo pipefail
python3 - "$@" <<'PY'
import os,hashlib,json,datetime
paths=[]
for r,_,fs in os.walk("dist_ready"):
  for fn in fs:
    if fn.endswith((".html",".xml","txt")):
      p=os.path.join(r,fn)
      h=hashlib.sha256(open(p,"rb").read()).hexdigest()
      paths.append({"path":p,"sha256":h})
paths.sort(key=lambda x:x["path"])
root=""
if paths:
  leaves=[bytes.fromhex(x["sha256"]) for x in paths]
  while len(leaves)>1:
    nxt=[]
    for i in range(0,len(leaves),2):
      a=leaves[i]; b=leaves[i+1] if i+1<len(leaves) else a
      nxt.append(hashlib.sha256(a+b).digest())
    leaves=nxt
  root=leaves[0].hex()
os.makedirs("receipts",exist_ok=True)
meta={"root":root,"files":paths,"ts":datetime.datetime.utcnow().isoformat()+"Z"}
open("receipts/anchor.json","w").write(json.dumps(meta,indent=2))
print("[ANCHOR]",root or "(empty)")
PY
