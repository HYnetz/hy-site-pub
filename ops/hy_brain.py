#!/usr/bin/env python3
import argparse, glob, json, os, re, sys, time, hashlib, sqlite3, urllib.request
from urllib.parse import urljoin, urldefrag, urlparse
import xml.etree.ElementTree as ET
from pathlib import Path

UA = os.environ.get("HY_UA", "HYnetzBot/0.1 (+https://github.com/HYnetz)")
DEFAULT_TIMEOUT = int(os.environ.get("HY_TIMEOUT", "15"))

def db_connect(db_path: Path) -> sqlite3.Connection:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    con = sqlite3.connect(str(db_path))
    con.execute("PRAGMA journal_mode=WAL;")
    con.execute("PRAGMA synchronous=NORMAL;")
    con.execute("""
      CREATE TABLE IF NOT EXISTS known(
        url TEXT PRIMARY KEY,
        first_seen INTEGER,
        source TEXT
      );
    """)
    con.execute("""
      CREATE TABLE IF NOT EXISTS queue(
        url TEXT PRIMARY KEY,
        added INTEGER,
        priority INTEGER DEFAULT 0
      );
    """)
    con.execute("""
      CREATE TABLE IF NOT EXISTS fetched(
        url TEXT PRIMARY KEY,
        fetched INTEGER,
        status INTEGER,
        ctype TEXT,
        bytes INTEGER,
        sha256 TEXT
      );
    """)
    con.execute("""
      CREATE TABLE IF NOT EXISTS errors(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        at INTEGER,
        stage TEXT,
        url TEXT,
        err TEXT
      );
    """)
    con.commit()
    return con

def norm_url(u: str) -> str | None:
    u = (u or "").strip()
    if not u:
        return None
    if u.startswith("//"):
        u = "https:" + u
    p = urlparse(u)
    if p.scheme not in ("http", "https"):
        return None
    u, _frag = urldefrag(u)
    # tiny normalization
    u = re.sub(r"[ \t\r\n]+", "", u)
    return u

def add_known_and_queue(con, urls, source=""):
    now = int(time.time())
    cur = con.cursor()
    for u in urls:
        u = norm_url(u)
        if not u: 
            continue
        cur.execute("INSERT OR IGNORE INTO known(url, first_seen, source) VALUES(?,?,?)", (u, now, source))
        cur.execute("INSERT OR IGNORE INTO queue(url, added, priority) VALUES(?,?,0)", (u, now))
    con.commit()

def add_queue_only(con, urls):
    now = int(time.time())
    cur = con.cursor()
    for u in urls:
        u = norm_url(u)
        if not u:
            continue
        cur.execute("INSERT OR IGNORE INTO known(url, first_seen, source) VALUES(?,?,?)", (u, now, "import:queue"))
        cur.execute("INSERT OR IGNORE INTO queue(url, added, priority) VALUES(?,?,0)", (u, now))
    con.commit()

def mark_fetched(con, url, status, ctype, bts):
    now = int(time.time())
    sha = hashlib.sha256(bts).hexdigest()
    con.execute(
        "INSERT OR REPLACE INTO fetched(url, fetched, status, ctype, bytes, sha256) VALUES(?,?,?,?,?,?)",
        (url, now, int(status or 0), (ctype or "")[:200], len(bts), sha)
    )
    con.commit()

def pop_queue(con, n: int):
    cur = con.cursor()
    rows = cur.execute(
        "SELECT url FROM queue ORDER BY priority DESC, added ASC LIMIT ?",
        (int(n),)
    ).fetchall()
    urls = [r[0] for r in rows]
    for u in urls:
        cur.execute("DELETE FROM queue WHERE url=?", (u,))
    con.commit()
    return urls

def log_error(con, stage, url, err):
    con.execute(
        "INSERT INTO errors(at, stage, url, err) VALUES(?,?,?,?)",
        (int(time.time()), stage, url, str(err)[:2000])
    )
    con.commit()

def fetch(url: str, timeout=DEFAULT_TIMEOUT):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "*/*"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        b = resp.read()
        return resp.getcode(), resp.headers.get("content-type", ""), b

def parse_sitemap_xml(b: bytes):
    # returns (urls, sitemap_children)
    try:
        root = ET.fromstring(b)
    except Exception:
        return [], []
    tag = root.tag.lower()
    ns = {"sm": "http://www.sitemaps.org/schemas/sitemap/0.9"}
    urls, kids = [], []
    if "sitemapindex" in tag:
        for loc in root.findall(".//sm:sitemap/sm:loc", ns):
            if loc.text: kids.append(loc.text.strip())
    elif "urlset" in tag:
        for loc in root.findall(".//sm:url/sm:loc", ns):
            if loc.text: urls.append(loc.text.strip())
    else:
        # try without ns
        for loc in root.findall(".//loc"):
            if loc.text:
                t = loc.text.strip()
                if t.endswith(".xml"): kids.append(t)
                else: urls.append(t)
    return urls, kids

_href_re = re.compile(r"""href\s*=\s*["']([^"'#]+)""", re.IGNORECASE)

def extract_links(html_bytes: bytes, base_url: str, limit=200):
    try:
        txt = html_bytes.decode("utf-8", "ignore")
    except Exception:
        return []
    out = []
    for m in _href_re.finditer(txt):
        raw = m.group(1).strip()
        if raw.startswith("mailto:") or raw.startswith("javascript:"):
            continue
        u = urljoin(base_url, raw)
        u = norm_url(u)
        if not u:
            continue
        out.append(u)
        if len(out) >= limit:
            break
    return out

def import_current(con, curdir: Path):
    # known
    if (curdir / "urls_raw.txt").exists():
        add_known_and_queue(con, (curdir/"urls_raw.txt").read_text(errors="ignore").splitlines(), "import:urls_raw")
    elif (curdir / "urls.txt").exists():
        add_known_and_queue(con, (curdir/"urls.txt").read_text(errors="ignore").splitlines(), "import:urls")
    # queue
    if (curdir / "queue.txt").exists():
        add_queue_only(con, (curdir/"queue.txt").read_text(errors="ignore").splitlines())
    # seen (best-effort: mark as fetched=unknown)
    if (curdir / "seen.txt").exists():
        now = int(time.time())
        for u in (curdir/"seen.txt").read_text(errors="ignore").splitlines():
            u = norm_url(u)
            if not u: 
                continue
            con.execute("INSERT OR IGNORE INTO fetched(url,fetched,status,ctype,bytes,sha256) VALUES(?,?,?,?,?,?)",
                        (u, now, 0, "", 0, ""))
        con.commit()

def export_current(con, outdir: Path, queue_limit=5000, seen_limit=500):
    outdir.mkdir(parents=True, exist_ok=True)
    known = [r[0] for r in con.execute("SELECT url FROM known").fetchall()]
    # urls_raw = insertion-ish order not available; keep unsorted for “raw”
    (outdir/"urls_raw.txt").write_text("\n".join(known) + ("\n" if known else ""), encoding="utf-8")

    known_sorted = sorted(set(known))
    (outdir/"urls.txt").write_text("\n".join(known_sorted) + ("\n" if known_sorted else ""), encoding="utf-8")

    q = [r[0] for r in con.execute(
        "SELECT url FROM queue ORDER BY priority DESC, added ASC LIMIT ?",
        (int(queue_limit),)
    ).fetchall()]
    (outdir/"queue.txt").write_text("\n".join(q) + ("\n" if q else ""), encoding="utf-8")

    s = [r[0] for r in con.execute(
        "SELECT url FROM fetched ORDER BY fetched DESC LIMIT ?",
        (int(seen_limit),)
    ).fetchall()]
    (outdir/"seen.txt").write_text("\n".join(s) + ("\n" if s else ""), encoding="utf-8")

    meta = {
        "ts_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "known": int(con.execute("SELECT COUNT(*) FROM known").fetchone()[0]),
        "queue": int(con.execute("SELECT COUNT(*) FROM queue").fetchone()[0]),
        "fetched": int(con.execute("SELECT COUNT(*) FROM fetched").fetchone()[0]),
        "version": "hy_brain_v0"
    }
    (outdir/"meta.json").write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")

    now = meta["ts_utc"]
    (outdir/"status.html").write_text(
        f'<!doctype html><meta charset="utf-8"><title>HY Status</title>'
        f'<h1>HY OK</h1><p>{now}</p><p>known={meta["known"]} queue={meta["queue"]} fetched={meta["fetched"]}</p>\n',
        encoding="utf-8"
    )
    (outdir/"sitemap_index.xml").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"></sitemapindex>\n',
        encoding="utf-8"
    )
    (outdir/"robots.txt").write_text(
        "User-agent: *\n"
        "Disallow:\n",
        encoding="utf-8"
    )

def load_seed_urls(seed_path: str | None):
    seeds = []
    if seed_path and Path(seed_path).exists():
        seeds += Path(seed_path).read_text(errors="ignore").splitlines()
    # your repo seed bank
    for p in glob.glob("ops/ingest/unique/*.txt"):
        try:
            seeds += Path(p).read_text(errors="ignore").splitlines()
        except Exception:
            pass
    if Path("seeds/all.txt").exists():
        seeds += Path("seeds/all.txt").read_text(errors="ignore").splitlines()
    seeds = [s.strip() for s in seeds if s.strip()]
    if not seeds:
        seeds = [
            "https://www.nasa.gov/sitemap.xml",
            "https://www.noaa.gov/sitemap.xml",
            "https://www.usgs.gov/sitemap.xml",
            "https://data.gov/sitemap.xml",
            "https://data.europa.eu/sitemap.xml",
            "https://www.gov.uk/sitemap.xml",
            "https://www.un.org/sitemap.xml",
        ]
    return seeds

def cmd_status(args):
    con = db_connect(Path(args.db))
    if args.import_current:
        import_current(con, Path(args.out))
    print("known =", con.execute("SELECT COUNT(*) FROM known").fetchone()[0])
    print("queue =", con.execute("SELECT COUNT(*) FROM queue").fetchone()[0])
    print("fetched =", con.execute("SELECT COUNT(*) FROM fetched").fetchone()[0])

def cmd_seed(args):
    con = db_connect(Path(args.db))
    if args.import_current:
        import_current(con, Path(args.out))
    seeds = load_seed_urls(args.seeds)
    add_known_and_queue(con, seeds, "seed")
    print("seeded:", len(seeds))

def cmd_sitemap(args):
    con = db_connect(Path(args.db))
    if args.import_current:
        import_current(con, Path(args.out))
    seeds = load_seed_urls(args.seeds)
    added_total = 0
    max_children = int(args.max_children)
    for s in seeds[: int(args.max_seeds)]:
        s = norm_url(s)
        if not s:
            continue
        try:
            code, ctype, b = fetch(s, timeout=int(args.timeout))
            urls, kids = parse_sitemap_xml(b)
            add_known_and_queue(con, urls, "sitemap:urlset")
            added_total += len(urls)
            # one-level expansion for sitemapindex
            for child in kids[:max_children]:
                child = norm_url(child)
                if not child:
                    continue
                try:
                    c2, ct2, b2 = fetch(child, timeout=int(args.timeout))
                    u2, _k2 = parse_sitemap_xml(b2)
                    add_known_and_queue(con, u2, "sitemap:child")
                    added_total += len(u2)
                except Exception as e:
                    log_error(con, "sitemap_child", child, e)
        except Exception as e:
            log_error(con, "sitemap_seed", s, e)
    print("sitemap_added:", added_total)

def cmd_crawl(args):
    con = db_connect(Path(args.db))
    if args.import_current:
        import_current(con, Path(args.out))

    n = int(args.n)
    urls = pop_queue(con, n)
    got = 0
    for u in urls:
        try:
            code, ctype, b = fetch(u, timeout=int(args.timeout))
            mark_fetched(con, u, code, ctype, b)
            got += 1
            # only extract links from html-ish
            if "html" in (ctype or "").lower():
                links = extract_links(b, u, limit=int(args.max_links))
                add_known_and_queue(con, links, "crawl:links")
        except Exception as e:
            log_error(con, "crawl", u, e)
    print("crawled:", got, "from_queue:", len(urls))

def cmd_export(args):
    con = db_connect(Path(args.db))
    if args.import_current:
        import_current(con, Path(args.out))
    export_current(con, Path(args.out), queue_limit=int(args.queue_limit), seen_limit=int(args.seen_limit))
    print("exported ->", args.out)

def cmd_run(args):
    con = db_connect(Path(args.db))
    if args.import_current:
        import_current(con, Path(args.out))

    # 1) seed urls as known+queue
    seeds = load_seed_urls(args.seeds)
    add_known_and_queue(con, seeds, "seed")

    # 2) sitemap expansion
    added_total = 0
    max_children = int(args.max_children)
    for s in seeds[: int(args.max_seeds)]:
        s = norm_url(s)
        if not s:
            continue
        try:
            code, ctype, b = fetch(s, timeout=int(args.timeout))
            urls, kids = parse_sitemap_xml(b)
            add_known_and_queue(con, urls, "sitemap:urlset")
            added_total += len(urls)
            for child in kids[:max_children]:
                child = norm_url(child)
                if not child:
                    continue
                try:
                    c2, ct2, b2 = fetch(child, timeout=int(args.timeout))
                    u2, _k2 = parse_sitemap_xml(b2)
                    add_known_and_queue(con, u2, "sitemap:child")
                    added_total += len(u2)
                except Exception as e:
                    log_error(con, "sitemap_child", child, e)
        except Exception as e:
            log_error(con, "sitemap_seed", s, e)

    # 3) crawl a bit (stage2)
    urls = pop_queue(con, int(args.pages))
    got = 0
    for u in urls:
        try:
            code, ctype, b = fetch(u, timeout=int(args.timeout))
            mark_fetched(con, u, code, ctype, b)
            got += 1
            if "html" in (ctype or "").lower():
                links = extract_links(b, u, limit=int(args.max_links))
                add_known_and_queue(con, links, "crawl:links")
        except Exception as e:
            log_error(con, "crawl", u, e)

    # 4) export
    export_current(con, Path(args.out), queue_limit=int(args.queue_limit), seen_limit=int(args.seen_limit))
    print(f"run_ok: sitemap_added={added_total} crawled={got} out={args.out}")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", default="current/hy_state.sqlite3")
    ap.add_argument("--out", default="current")
    ap.add_argument("--import-current", dest="import_current", action="store_true", default=True)
    ap.add_argument("--no-import-current", dest="import_current", action="store_false")
    sub = ap.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("status")
    s.set_defaults(func=cmd_status)

    s = sub.add_parser("seed")
    s.add_argument("--seeds", default=None)
    s.set_defaults(func=cmd_seed)

    s = sub.add_parser("sitemap")
    s.add_argument("--seeds", default=None)
    s.add_argument("--max-seeds", default="50")
    s.add_argument("--max-children", default="25")
    s.add_argument("--timeout", default=str(DEFAULT_TIMEOUT))
    s.set_defaults(func=cmd_sitemap)

    s = sub.add_parser("crawl")
    s.add_argument("-n", default="30")
    s.add_argument("--timeout", default=str(DEFAULT_TIMEOUT))
    s.add_argument("--max-links", default="200")
    s.set_defaults(func=cmd_crawl)

    s = sub.add_parser("export")
    s.add_argument("--queue-limit", default="5000")
    s.add_argument("--seen-limit", default="500")
    s.set_defaults(func=cmd_export)

    s = sub.add_parser("run")
    s.add_argument("--seeds", default=None)
    s.add_argument("--max-seeds", default="50")
    s.add_argument("--max-children", default="25")
    s.add_argument("--pages", default="30")
    s.add_argument("--timeout", default=str(DEFAULT_TIMEOUT))
    s.add_argument("--max-links", default="200")
    s.add_argument("--queue-limit", default="5000")
    s.add_argument("--seen-limit", default="500")
    s.set_defaults(func=cmd_run)

    args = ap.parse_args()
    return args.func(args)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)
