#!/usr/bin/env bash
set -euo pipefail
REPO="${REPO:-HYnetz/hy-site-pub}"
BR="${BR:-gh-pages}"
WF="${WF:-hy-cycle-wrapper.yml}"

cmd="${1:-run}"
case "$cmd" in
  run)
    gh workflow run -R "$REPO" "$WF" --ref "$BR" >/dev/null
    RID="$(gh run list -R "$REPO" --workflow "$WF" -L 1 --json databaseId -q '.[0].databaseId')"
    gh run watch -R "$REPO" "$RID" --exit-status
    echo "OK: run=$RID"
    ;;
  pull)
    git fetch origin
    git checkout "$BR" >/dev/null 2>&1 || git checkout -b "$BR"
    git reset --hard "origin/$BR"
    git clean -fd
    ;;
  ls)
    gh api "repos/$REPO/contents/current?ref=$BR" --jq '.[].name' | sort
    ;;
  *)
    echo "usage: ops/hyctl.sh {run|pull|ls}" >&2
    exit 2
    ;;
esac
