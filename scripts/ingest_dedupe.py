import os, hashlib, pathlib, csv
ROOT=pathlib.Path.home()/ "hy"
CLEAN=ROOT/"ops/ingest/clean"
UNIQ =ROOT/"ops/ingest/unique"; UNIQ.mkdir(parents=True, exist_ok=True)
MAP  =ROOT/"ops/ingest/map.csv"
rows=[]
for p in CLEAN.glob("*.txt"):
    txt = p.read_text(encoding="utf-8", errors="ignore")
    h = hashlib.sha256(txt.encode("utf-8","ignore")).hexdigest()[:32]
    dst = UNIQ/f"{h}.txt"
    if not dst.exists():
        dst.write_text(txt, encoding="utf-8")
    rows.append((p.stem,h,len(txt)))
with open(MAP,"w",newline="",encoding="utf-8") as f:
    w=csv.writer(f); w.writerow(["source_key","content_hash","bytes"]); w.writerows(rows)
print(f"[DEDUPE] unique={len(list(UNIQ.glob('*.txt')))} mapped={len(rows)}")
