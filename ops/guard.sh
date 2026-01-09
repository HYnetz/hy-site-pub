#!/usr/bin/env bash
set -euo pipefail
KEY_HINT="${HY_KEY_FILE:-${1:-}}"
[[ -z "$KEY_HINT" ]] && KEY_HINT="$HOME/.hy_key/ok"
try_paths=("$KEY_HINT" "/media/$USER/HY_KEY/ok" "/mnt/HY_KEY/ok" "$HOME/.hy_key/ok")
for p in "${try_paths[@]}"; do
  if [[ -f "$p" ]]; then
    if find "$p" -mmin -$((24*60)) >/dev/null 2>&1; then
      echo "[GUARD] key OK at $p"; exit 0
    else
      echo "[GUARD] key stale at $p (touch to refresh: 'touch $p')"; exit 3
    fi
  fi
done
echo "[GUARD] key not found; set HY_KEY_FILE or insert HY_KEY drive."
exit 2
