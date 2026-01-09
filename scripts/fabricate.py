import os, json, random, argparse

def load(path, default):
    try:
        with open(path, 'r', encoding='utf-8') as f: return json.load(f)
    except: return default

def synth_cities(locale, base, target):
    out = list(base); n = max(0, target - len(out))
    prefix = {"de":"de","en":"en","fr":"fr","es":"es","it":"it"}.get(locale, (locale[:2] or "x"))
    for i in range(1, n+1): out.append(f"{prefix}-city-{i:05d}")
    return out

HTML_DISCLAIMER = ("<section class=\"disclaimer\"><strong>Disclaimer:</strong> "
                   "This page provides evidence-first, official-source information only. "
                   "No legal advice. No outcomes promised. No custody of funds.</section>")
HTML_FOOT = "<footer><a href=\"/imprint.html\">Imprint</a> · <a href=\"/privacy.html\">Privacy</a></footer>"

def make_html(locale, lane, city, words_min=260):
    title = f"{lane.title()} — Official Path · {city.title()} [{locale}]"
    intro = ("This Official-Path protocol outlines steps, forms, and authorities relevant to this topic in this city. "
             "It is a machine-readable procedure rendered as a page for human review. ")
    base = ("Use official sources linked below. Prepare documents and references before contacting the authority. "
            "Escalation steps and timelines can vary by jurisdiction. Keep copies of communications and receipts. ")
    body = (base * ((words_min // len(base.split())) + 2))
    evidence = (f"<ul class=\"evidence\">"
                f"<li><a rel=\"nofollow\" href=\"https://{locale}.gov.example/{lane}\">Primary authority ({lane})</a></li>"
                f"<li><a rel=\"nofollow\" href=\"https://{locale}.city.example/{city}/forms\">City forms ({city})</a></li>"
                f"<li><a rel=\"nofollow\" href=\"https://{locale}.statutes.example/{lane}\">Statutes & references</a></li>"
                f"</ul>")
    return (f"<!doctype html><meta charset=\"utf-8\"><title>{title}</title>"
            f"<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">"
            f"<main><h1>{title}</h1><p class=\"intro\">{intro}</p>{HTML_DISCLAIMER}"
            f"<section class=\"checklist\"><h2>Checklist</h2><ol>"
            f"<li>Identify the authority responsible in {city.title()}.</li>"
            f"<li>Collect required documents and references.</li>"
            f"<li>Use the forms linked below; submit per local rules.</li>"
            f"<li>Track deadlines and escalation contacts.</li>"
            f"</ol></section><section class=\"evidence-block\"><h2>Official Sources</h2>{evidence}</section>"
            f"<section class=\"body\"><p>{body}</p></section></main>{HTML_FOOT}")

def ensure_dirs():
    for p in ["dist","dist_ready","legal"]: os.makedirs(p, exist_ok=True)
    if not os.path.exists("dist_ready/imprint.html"):
        open("dist_ready/imprint.html","w",encoding="utf-8").write("<!doctype html><meta charset='utf-8'><h1>Imprint</h1>")
    if not os.path.exists("dist_ready/privacy.html"):
        open("dist_ready/privacy.html","w",encoding="utf-8").write("<!doctype html><meta charset='utf-8'><h1>Privacy</h1>")

def path_for(locale,lane,city):
    d = os.path.join("dist", locale, lane, city); os.makedirs(d, exist_ok=True)
    return os.path.join(d, "index.html")

def write_page(locale,lane,city,words):
    with open(path_for(locale,lane,city),"w",encoding="utf-8") as f:
        f.write(make_html(locale,lane,city,words))

def main():
    ap = argparse.ArgumentParser()
    # accept hyphen and underscore variants
    ap.add_argument("--cities-per-locale","--cities_per_locale", dest="cities_per_locale", type=int, default=500)
    ap.add_argument("--lanes-max","--lanes_max", dest="lanes_max", type=int, default=15)
    ap.add_argument("--locales-max","--locales_max", dest="locales_max", type=int, default=6)
    ap.add_argument("--words-min","--words_min", dest="words_min", type=int, default=260)
    ap.add_argument("--limit-pages","--limit_pages", dest="limit_pages", type=int, default=10000)
    args = ap.parse_args()

    locales = load("data/locales.json", ["en","de"])
    lanes = load("data/lanes.json", ["finance","telco","utilities"])
    cities_seed = load("data/cities_seed.json", {})

    locales = locales[:args.locales_max] if args.locales_max and args.locales_max>0 else locales
    lanes = lanes[:args.lanes_max] if args.lanes_max and args.lanes_max>0 else lanes

    ensure_dirs()
    count = 0
    for loc in locales:
        base = cities_seed.get(loc, cities_seed.get(loc[:2], []))
        cities = synth_cities(loc, base, args.cities_per_locale)
        random.shuffle(cities)
        for lane in lanes:
            for city in cities:
                write_page(loc, lane, city, args.words_min)
                count += 1
                if count >= args.limit_pages:
                    print(f"[FABRICATE] Wrote {count} pages (batch)."); return
    print(f"[FABRICATE] Wrote {count} pages (batch).")

if __name__ == "__main__":
    main()
