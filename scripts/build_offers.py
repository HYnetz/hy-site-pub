import os,csv,time,random,string,html
R=os.path.abspath(os.path.join(os.path.dirname(__file__),'..'))
OUT=os.path.join(R,'dist_ready','t'); os.makedirs(OUT,exist_ok=True)
def nonce(n=16): return ''.join(random.choice(string.ascii_letters+string.digits) for _ in range(n))
with open(os.path.join(R,'ops','partners.csv'),encoding='utf-8') as f:
  for row in csv.reader(f):
    if not row or row[0].startswith('#') or len(row)<3: continue
    slug,title,url=(c.strip() for c in row[:3]); n=nonce(); url=url.replace('{{nonce}}',n)
    d=os.path.join(OUT,slug); os.makedirs(d,exist_ok=True)
    open(os.path.join(d,'index.html'),'w',encoding='utf-8').write(
      '<!doctype html><meta charset="utf-8"><title>{t}</title>'
      '<meta http-equiv="refresh" content="0;url={u}">'
      '<p>Redirecting to <a rel="nofollow" href="{u}">{t}</a> ...</p>'.format(
        t=html.escape(title),u=html.escape(url)))
print('[OFFERS] ok')
