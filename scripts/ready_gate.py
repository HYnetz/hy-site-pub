import os, re, hashlib, shutil, sys

ROOT="dist"
OUT="dist_ready"
WORD_MIN=250

def words(text):
    return len(re.findall(r"\w+", text))

def has_disclaimer(text):
    return "Disclaimer:" in text

def promote(src):
    rel = os.path.relpath(src, ROOT)
    dst = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(src, dst)

ok=0; fail=0
for r,_,fs in os.walk(ROOT):
    for fn in fs:
        if not fn.endswith(".html"): continue
        p=os.path.join(r,fn)
        try:
            t=open(p,"r",encoding="utf-8",errors="ignore").read()
            if words(t) >= WORD_MIN and has_disclaimer(t):
                promote(p); ok+=1
            else:
                fail+=1
        except Exception as e:
            fail+=1
print(f"[READY] promoted={ok} failed={fail}")
