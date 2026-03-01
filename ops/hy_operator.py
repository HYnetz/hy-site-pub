#!/usr/bin/env python3
import os, json, time
from pathlib import Path
from urllib.parse import urlparse

RAW = os.environ.get("HY_CMD") or ""

def first_hy_line(text: str) -> str:
    for line in (text or "").splitlines():
        s = line.strip()
        if s.startswith("/hy"):
            return s
    return ""

def safe_url(u: str) -> str | None:
    u = (u or "").strip()
    p = urlparse(u)
    if p.scheme not in ("http", "https"): return None
    if not p.netloc: return None
    return u

def count_lines(p: Path) -> int:
    try:
        return sum(1 for _ in p.open("r", encoding="utf-8", errors="ignore"))
    except Exception:
        return 0

def status_md():
    cur = Path("current")
    meta = {}
    try:
        meta = json.loads((cur / "meta.json").read_text(encoding="utf-8", errors="ignore"))
    except Exception:
        pass
    ts = meta.get("ts_utc") or meta.get("ts") or time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    urls  = count_lines(cur / "urls.txt")
    queue = count_lines(cur / "queue.txt")
    seen  = count_lines(cur / "seen.txt")
    files = sorted([p.name for p in cur.glob("*") if p.is_file()]) if cur.exists() else []
    return (
        "### HY status\n"
        f"- ts: `{ts}`\n"
        f"- urls: **{urls}**\n"
        f"- queue: **{queue}**\n"
        f"- seen: **{seen}**\n"
        f"- current/: `{', '.join(files)}`\n"
    )

def seeds_add_md(u: str):
    u = safe_url(u)
    if not u:
        return "### seeds add\nInvalid URL (must be http/https)\n"
    p = Path("seeds/all.txt")
    p.parent.mkdir(parents=True, exist_ok=True)
    existing = set()
    if p.exists():
        existing = set(x.strip() for x in p.read_text(errors="ignore").splitlines() if x.strip())
    if u in existing:
        return f"### seeds add\nAlready present: `{u}`\n"
    with p.open("a", encoding="utf-8") as f:
        f.write(u + "\n")
    return f"### seeds add\nAdded: `{u}`\n"

def seeds_count_md():
    p = Path("seeds/all.txt")
    n = count_lines(p)
    return f"### seeds count\n- lines: **{n}**\n"

def main():
    cmdline = first_hy_line(RAW)
    if not cmdline:
        print("### HY\nI didn’t see a `/hy ...` command. Try: `/hy status`")
        return

    parts = cmdline.split()
    action = parts[1] if len(parts) > 1 else "status"

    if action == "status":
        print(status_md()); return
    if action == "seeds":
        sub = parts[2] if len(parts) > 2 else ""
        if sub == "add":
            url = parts[3] if len(parts) > 3 else ""
            print(seeds_add_md(url)); return
        if sub == "count":
            print(seeds_count_md()); return
        print("### seeds\nUse `/hy seeds add <url>` or `/hy seeds count`"); return
    if action == "help":
        print("### HY help\n- `/hy status`\n- `/hy seeds count`\n- `/hy seeds add <url>`"); return

    print("### HY\nUnknown command. Try `/hy help`")

if __name__ == "__main__":
    main()
