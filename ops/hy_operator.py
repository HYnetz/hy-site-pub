#!/usr/bin/env python3
import os, re, json, subprocess
from pathlib import Path
from urllib.parse import urlparse

CMD = (os.environ.get("HY_CMD") or "").strip()

def sh(*args):
    return subprocess.check_output(list(args), text=True).strip()

def safe_url(u: str) -> str | None:
    u = u.strip()
    p = urlparse(u)
    if p.scheme not in ("http", "https"): return None
    if not p.netloc: return None
    return u

def status_md():
    def count(p):
        try: return sum(1 for _ in open(p, "r", encoding="utf-8", errors="ignore"))
        except Exception: return 0

    meta = {}
    try:
        meta = json.loads(Path("current/meta.json").read_text(encoding="utf-8", errors="ignore"))
    except Exception:
        pass

    urls = count("current/urls.txt")
    queue = count("current/queue.txt")
    seen = count("current/seen.txt")
    ts = meta.get("ts_utc") or meta.get("ts") or "unknown"

    return (
        f"### HY status\n"
        f"- ts: `{ts}`\n"
        f"- urls: **{urls}**\n"
        f"- queue: **{queue}**\n"
        f"- seen: **{seen}**\n"
        f"\n"
        f"Files in `current/`: `{', '.join(sorted([p.name for p in Path('current').glob('*') if p.is_file()]))}`\n"
    )

def run_md():
    # Trigger the wrapper workflow on gh-pages
    try:
        sh("gh", "workflow", "run", "hy-cycle-wrapper.yml", "--ref", "gh-pages")
        rid = sh("gh", "run", "list", "-L", "1", "--json", "databaseId", "-q", ".[0].databaseId")
        return f"### HY run triggered\n- run id: `{rid}`\n"
    except Exception as e:
        return f"### HY run failed\n`{e}`\n"

def seeds_add_md(u: str):
    u = safe_url(u)
    if not u:
        return "### seeds add\nInvalid URL (must be http/https)\n"
    p = Path("seeds/all.txt")
    p.parent.mkdir(exist_ok=True)
    existing = set()
    if p.exists():
        existing = set([x.strip() for x in p.read_text(errors="ignore").splitlines() if x.strip()])
    if u in existing:
        return f"### seeds add\nAlready present: `{u}`\n"
    with p.open("a", encoding="utf-8") as f:
        f.write(u + "\n")
    return f"### seeds add\nAdded: `{u}`\n"

def main():
    cmd = CMD.strip()
    if not cmd.startswith("/hy"):
        print("No /hy command found.")
        return

    parts = cmd.split()
    action = parts[1] if len(parts) > 1 else "status"

    if action == "status":
        print(status_md())
        return

    if action == "run":
        print(run_md())
        return

    if action == "seeds":
        sub = parts[2] if len(parts) > 2 else ""
        if sub == "add":
            url = parts[3] if len(parts) > 3 else ""
            print(seeds_add_md(url))
            return
        if sub == "count":
            p = Path("seeds/all.txt")
            n = 0
            if p.exists():
                n = sum(1 for _ in p.open("r", encoding="utf-8", errors="ignore"))
            print(f"### seeds count\n- lines: **{n}**\n")
            return
        print("### seeds\nUse `/hy seeds add <url>` or `/hy seeds count`\n")
        return

    print("### HY\nCommands:\n- `/hy status`\n- `/hy run`\n- `/hy seeds add <url>`\n- `/hy seeds count`\n")

if __name__ == "__main__":
    main()
