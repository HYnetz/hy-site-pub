import os, json, sys
ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
READY=os.path.join(ROOT,"dist_ready")
CFG=os.path.join(ROOT,"ops","geo_gate.json")
try:
    cfg=json.load(open(CFG,"r",encoding="utf-8"))
except Exception:
    sys.exit(0)
mode=cfg.get("mode","allow")
allow_locales=set(cfg.get("locales_allow",[]))
deny_lanes=set(cfg.get("lanes_deny",[]))
deny_cities=set(cfg.get("cities_deny",[]))
def allowed(locale,lane,city):
    if lane in deny_lanes or city in deny_cities:
        return False
    if mode=="allow" and allow_locales:
        return locale in allow_locales
    if mode=="deny" and allow_locales:
        return locale not in allow_locales
    return True
removed=0
for dirpath,_,filenames in os.walk(READY):
    for fn in filenames:
        if not fn.endswith(".html"): continue
        rel=os.path.relpath(os.path.join(dirpath,fn), READY)
        parts=rel.split(os.sep)
        if len(parts) < 4:  # locale/lane/city/index.html
            continue
        locale,lane,city = parts[0],parts[1],parts[2]
        if not allowed(locale,lane,city):
            try:
                os.remove(os.path.join(dirpath,fn)); removed+=1
            except: pass
print(f"[GEO] removed={removed}")
