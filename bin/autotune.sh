#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/hy"; POL="$ROOT/ops/ingest/policy.json"; LOG="$ROOT/ops/logs/hy-omni.out.log"
free_mb=$(df -Pm "$ROOT" | awk 'NR==2{print $4}')
err=$(tac "$LOG" 2>/dev/null | sed -n 's/.*err=\([0-9]\+\).*/\1/p' | head -n1)
err=${err:-0}
python3 - <<PY
import json,sys
pol=json.load(open("$POL"))
conc=int(pol.get("concurrency",8)); delay=int(pol.get("per_host_delay_ms",300))
free=int("$free_mb"); err=int("$err")
# simple rules: more free+low errors => faster; low free/high err => slower
if free>200000 and err==0: conc=min(24, conc+2); delay=max(100, delay-25)
elif free<20000 or err>0: conc=max(4, conc-2); delay=min(600, delay+50)
pol["concurrency"]=conc; pol["per_host_delay_ms"]=delay
json.dump(pol,open("$POL","w"),indent=2)
print(f"[TUNE] concurrency={conc} delay_ms={delay} free_mb={free} err={err}")
PY
