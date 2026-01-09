import os, re, json, html, time, hashlib, urllib.parse, urllib.request, threading
from concurrent.futures import ThreadPoolExecutor, as_completed

ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),'..'))
POL=json.load(open(os.path.join(ROOT,'ops','ingest','policy.json'),encoding='utf-8'))
ALLOW=set(x.strip() for x in open(os.path.join(ROOT,'ops','ingest','allowlist.txt'),encoding='utf-8') if x.strip() and not x.startswith('#'))
SEEDS=[x.strip() for x in open(os.path.join(ROOT,'ops','ingest','seeds.txt'),encoding='utf-8') if x.strip() and not x.startswith('#')]
RAW=os.path.join(ROOT,'ops','ingest','raw'); CLEAN=os.path.join(ROOT,'ops','ingest','clean')
os.makedirs(RAW,exist_ok=True); os.makedirs(CLEAN,exist_ok=True)

UA=POL.get("user_agent","HYBot/1.0"); TIMEOUT=int(POL.get("timeout_sec",20))
MAXB=int(POL.get("max_bytes",5*1024*1024)); SMAXB=int(POL.get("sitemap_max_bytes",64*1024*1024))
LOC_TARGET=int(POL.get("sitemap_loc_target",800))
ALLOW_UNKNOWN=bool(POL.get("allow_unknown_robots",False))
CONC=int(POL.get("concurrency",8)); RETRIES=int(POL.get("retries",3))
PHD=int(POL.get("per_host_delay_ms",300))/1000.0
HDR={"User-Agent":UA,"Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8","Accept-Language":"en-US,en;q=0.9","Referer":"https://www.google.com/"}

RLOCK=threading.Lock(); RBTX={}; LAST_REQ={}

def h(s): return hashlib.sha256(s.encode('utf-8','ignore')).hexdigest()[:16]
def host(u): return urllib.parse.urlparse(u).hostname or ''
def ok_host(u): 
    ho=host(u) or ''
    return any(ho==d or ho.endswith('.'+d) for d in ALLOW)

def robots_txt(hst):
    with RLOCK:
        ent=RBTX.get(hst); now=time.time()
        if ent and now<ent['exp']: return ent['txt']
    url=f"https://{hst}/robots.txt"
    try:
        req=urllib.request.Request(url,headers={"User-Agent":UA,"Accept":"text/plain,*/*;q=0.1"})
        txt=urllib.request.urlopen(req,timeout=TIMEOUT).read(128*1024).decode('utf-8','ignore')
    except Exception: txt=''
    with RLOCK: RBTX[hst]={'txt':txt,'exp':time.time()+3600}
    return txt

def robots_ok(u):
    hst=host(u); txt=robots_txt(hst)
    if not txt: return ALLOW_UNKNOWN
    ua_any=False; dis=[]
    for line in txt.splitlines():
        line=line.strip()
        if not line or line.startswith('#') or ':' not in line: continue
        k,v=[x.strip() for x in line.split(':',1)]
        if k.lower()=="user-agent": ua_any=(v=='*')
        elif k.lower()=="disallow" and ua_any: dis.append(v or '')
    path=urllib.parse.urlparse(u).path or '/'
    return not any(r and path.startswith(r) for r in dis)

def throttle(u):
    hst=host(u)
    with RLOCK:
        last=LAST_REQ.get(hst,0.0); now=time.time()
        wait=PHD-(now-last)
        if wait>0: time.sleep(wait)
        LAST_REQ[hst]=time.time()

def fetch_stream(u):
    # returns (text, content_type, is_sitemap_guess, early_stopped)
    req=urllib.request.Request(u,headers=HDR)
    with urllib.request.urlopen(req,timeout=TIMEOUT) as r:
        ctype=(r.headers.get('Content-Type','') or '').lower()
        buf=bytearray(); locs=0; early=False
        # choose byte ceiling
        is_sm_hint = ('xml' in ctype) or ('sitemap' in u.lower()) or u.lower().endswith('.xml')
        ceil = SMAXB if is_sm_hint else MAXB
        while True:
            chunk=r.read(65536)
            if not chunk: break
            buf.extend(chunk)
            # early stop for giant sitemaps once we collected enough <loc>
            if is_sm_hint:
                # count <loc> in current buffer (cheap)
                try:
                    locs = len(re.findall(br'<loc>\s*[^<\s]+', buf, flags=re.I))
                except Exception: pass
                if locs >= LOC_TARGET:
                    early=True; break
            if len(buf) > ceil:
                raise RuntimeError("over max bytes")
    try:
        txt=buf.decode('utf-8','ignore')
    except Exception:
        txt=''
    return txt,ctype,is_sm_hint,early

def is_sitemap(txt,ctype,u):
    ul=u.lower()
    return ('xml' in ctype or ul.endswith('.xml') or 'sitemap' in ul) and re.search(r'<(urlset|sitemapindex)\b', txt, re.I)

def expand_sitemap(txt,limit=400):
    locs=re.findall(r'<loc>\s*([^<\s]+)\s*</loc>', txt, re.I)
    out=[]; seen=set()
    for x in locs:
        x=x.strip()
        if x and x not in seen:
            out.append(x); seen.add(x)
        if len(out)>=limit: break
    return out

def clean_text(txt,ctype):
    if 'html' in ctype:
        txt=re.sub(r'(?is)<script.*?>.*?</script>',' ',txt)
        txt=re.sub(r'(?is)<style.*?>.*?</style>',' ',txt)
        txt=re.sub(r'(?s)<[^>]+>',' ',txt)
    txt=html.unescape(txt)
    txt=re.sub(r'\s+',' ',txt).strip()
    return txt[:500000]

def process(u):
    key=h(u); rawf=os.path.join(RAW,f"{key}.txt"); clnf=os.path.join(CLEAN,f"{key}.txt")
    if os.path.exists(clnf): return f"[INGEST] cached {u}"
    throttle(u)
    for i in range(RETRIES):
        try:
            (txt,ctype,is_sm,early)=fetch_stream(u)
            break
        except Exception as e:
            if i==RETRIES-1: return f"[INGEST] [ERR] fetch {e} {u}"
            time.sleep(0.6*(i+1))
    # sitemap fan-out
    if is_sitemap(txt,ctype,u):
        children=expand_sitemap(txt,limit=400)
        children=[c for c in children if ok_host(c) and robots_ok(c)]
        outs=[]
        with ThreadPoolExecutor(max_workers=max(1,int(CONC/2))) as ex2:
            futs=[ex2.submit(process,c) for c in children[:800]]
            for fu in as_completed(futs):
                try: outs.append(fu.result())
                except Exception as e: outs.append(f"[INGEST] worker err {e}")
        return ("\n".join(outs) if outs else f"[INGEST] empty-sitemap {u}") + ( " [EARLY]" if early else "" )
    # regular page
    open(rawf,'wb').write(txt.encode('utf-8','ignore'))
    clean=clean_text(txt,ctype)
    open(clnf,'wb').write(clean.encode('utf-8','ignore'))
    return f"[INGEST] ok {u} -> {key} bytes={len(clean)}"

# discover extra sitemaps from robots for allowlist
disc=[]
for d in list(ALLOW):
    for scheme in ('https','http'):
        rob=f"{scheme}://{d}/robots.txt"
        try:
            req=urllib.request.Request(rob,headers={"User-Agent":UA,"Accept":"text/plain"})
            t=urllib.request.urlopen(req,timeout=10).read().decode('utf-8','ignore')
            for line in t.splitlines():
                if line.lower().startswith('sitemap:'):
                    u=line.split(':',1)[1].strip()
                    if u and d in u and (u not in disc): disc.append(u)
            break
        except Exception: continue

queue=list(dict.fromkeys(SEEDS+disc))[:200]
logs=[]
with ThreadPoolExecutor(max_workers=CONC) as ex:
    futs=[ex.submit(process,u) for u in queue]
    for fu in as_completed(futs):
        try: logs.append(fu.result())
        except Exception as e: logs.append(f"[INGEST] worker err {e}")
for line in logs: print(line)
print("[INGEST] done")
