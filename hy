#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/hy"
UNIT_SRV="hy-serve.service"
UNIT_OMNI="hy-omni.service"
TIMER_OMNI="hy-omni.timer"

log(){ printf "%s\n" "$*"; }
has_systemd_user(){ command -v systemctl >/dev/null 2>&1 && systemctl --user --version >/dev/null 2>&1; }

serve_start_sysd(){ systemctl --user daemon-reload; systemctl --user enable --now "$UNIT_SRV"; }
serve_stop_sysd(){ systemctl --user stop "$UNIT_SRV" || true; }
serve_status_sysd(){ systemctl --user status "$UNIT_SRV" --no-pager || true; }

serve_start_nohup(){
  pkill -f "http.server 8080" 2>/dev/null || true
  nohup python3 -m http.server 8080 --directory "$ROOT/current" >/dev/null 2>&1 & echo $! > "$ROOT/ops/http8080.pid"
  log "[SERVE] nohup started :8080 (PID $(cat "$ROOT/ops/http8080.pid"))"
}
serve_stop_nohup(){
  [[ -f "$ROOT/ops/http8080.pid" ]] && kill "$(cat "$ROOT/ops/http8080.pid")" 2>/dev/null || pkill -f "http.server 8080" 2>/dev/null || true
  rm -f "$ROOT/ops/http8080.pid" 2>/dev/null || true
  log "[SERVE] nohup stopped"
}
serve_status_nohup(){
  if [[ -f "$ROOT/ops/http8080.pid" ]] && ps -p "$(cat "$ROOT/ops/http8080.pid")" >/dev/null 2>&1; then
    log "[SERVE] nohup running (PID $(cat "$ROOT/ops/http8080.pid"))"
  else
    pid=$(pgrep -f "http.server 8080" || true)
    [[ -n "$pid" ]] && log "[SERVE] http.server running (PID $pid)" || log "[SERVE] not running"
  fi
}

case "${1:-}" in
  serve)
    case "${2:-}" in
      start) if has_systemd_user; then serve_start_sysd; else serve_start_nohup; fi ;;
      stop)  if has_systemd_user; then serve_stop_sysd;  else serve_stop_nohup;  fi ;;
      restart) if has_systemd_user; then serve_stop_sysd; serve_start_sysd; else serve_stop_nohup; serve_start_nohup; fi ;;
      status|"") if has_systemd_user; then serve_status_sysd; else serve_status_nohup; fi ;;
      *) log "use: hy serve [start|stop|restart|status]"; exit 2;;
    esac
    ;;
  flip-index)
    [[ -x "$ROOT/flip-index.sh" ]] || { log "[ERR] flip-index.sh missing"; exit 3; }
    "$ROOT/flip-index.sh" "${2:-}";;
  money)
    [[ "${2:-}" =~ ^(on|off)$ ]] || { log "use: hy money on|off"; exit 2; }
    if [[ -x "$ROOT/money-${2}.sh" ]]; then "$ROOT/money-${2}.sh";
    elif [[ -x "$ROOT/scripts/flip-money-mode.sh" ]]; then "$ROOT/scripts/flip-money-mode.sh" "${2}";
    else log "[ERR] money scripts missing"; exit 3; fi
    ;;
  release)
    case "${2:-}" in
      point) target="${3:-}"; [[ -n "$target" && -d "$ROOT/releases/$target" ]] || { log "use: hy release point <timestamp_dir>"; exit 2; }
             ln -sfn "$ROOT/releases/$target" "$ROOT/current"; log "[RELEASE] current -> releases/$target" ;;
      list)  ls -1 "$ROOT/releases" || true;;
      *) log "use: hy release [list|point <timestamp_dir>]"; exit 2;;
    esac
    ;;
  omni)
    case "${2:-}" in
      once)  "$ROOT/bin/omni-cycle.sh" ;;
      start) if has_systemd_user; then systemctl --user daemon-reload; systemctl --user enable --now hy-omni.timer; else log "[NO-SYSTEMD] run: hy omni once & (or cron)"; fi ;;
      stop)  if has_systemd_user; then systemctl --user disable --now hy-omni.timer; systemctl --user stop hy-omni.service || true; else log "[NO-SYSTEMD] stop via your process manager"; fi ;;
      status|"") if has_systemd_user; then systemctl --user list-timers hy-omni.timer --no-pager || true; systemctl --user status hy-omni.service --no-pager || true; else log "[NO-SYSTEMD] no status"; fi ;;
      *) log "use: hy omni [once|start|stop|status]"; exit 2;;
    esac
    ;;
  status|"")
    echo "=== HY status ==="
    echo "current -> $(readlink -f "$ROOT/current" 2>/dev/null || echo '(missing)')"
    $0 serve status || true
    [[ -x "$ROOT/scoreboard.sh" ]] && "$ROOT/scoreboard.sh" || echo "(scoreboard not installed yet)"
    [[ -x "$ROOT/sec-status.sh" ]] && "$ROOT/sec-status.sh" || echo "(security pack not installed yet)"
    if has_systemd_user; then systemctl --user list-timers hy-omni.timer --no-pager || true; fi
    ;;
  *)
    log "Commands: serve [start|stop|restart|status] | flip-index public|stealth | money on|off | release [list|point <dir>] | omni [once|start|stop|status] | status"
    exit 2;;
esac
