import os, html, pathlib
ROOT=pathlib.Path.home()/ "hy"
SRCU=ROOT/"ops/ingest/unique"
SRCC=ROOT/"ops/ingest/clean"
OUT =ROOT/"dist_ready"/"data"; OUT.mkdir(parents=True, exist_ok=True)
SRC = SRCU if any(SRCU.glob("*.txt")) else SRCC
def esc(s): return html.escape(s,quote=True)
n=0
for p in SRC.glob("*.txt"):
    key=p.stem; txt=p.read_text(encoding="utf-8",errors="ignore")
    d=OUT/key; d.mkdir(parents=True, exist_ok=True)
    (d/"index.html").write_text(
        f"<!doctype html><meta charset='utf-8'><title>Data · {key}</title>"
        f"<h1>Data · {key}</h1><pre style='white-space:pre-wrap'>{esc(txt)}</pre>", encoding="utf-8")
    n+=1
# data index
items=sorted([q.name for q in OUT.iterdir() if q.is_dir()])
(OUT/"index.html").write_text(
    "<!doctype html><meta charset='utf-8'><title>Data Index</title><link rel='stylesheet' href='/assets/site.css'><nav><a href='/'`+`>Home</a><a href='/health.html'>Health</a></nav><h1>Data</h1><main><ul>"
    + "".join(f"<li><a href='/data/{i}/'>{i}</a></li>" for i in items[:2000])
    + "</ul></main>", encoding="utf-8")
print(f"[PAGES] built={n} src={'unique' if SRC==SRCU else 'clean'}")
