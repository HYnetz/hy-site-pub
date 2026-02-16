#!/usr/bin/env bash
set -euo pipefail

CMD="${1:-}"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
URL="$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)"

# Defaults based on which repo we're sitting in
if [[ "$URL" == *"hy-site-pub"* ]]; then
  REPO_DEFAULT="HYnetz/hy-site-pub"
  BR_DEFAULT="gh-pages"
else
  REPO_DEFAULT="HYnetz/hy-site"
  BR_DEFAULT="main"
fi

REPO="${REPO:-$REPO_DEFAULT}"
BR="${BR:-$BR_DEFAULT}"
WF="${WF:-hy-cycle-wrapper.yml}"

usage() {
  echo "usage: ops/hyctl.sh {run|watch|pull|lsremote|pack}"
  echo "env overrides: REPO=... BR=... WF=..."
}

case "$CMD" in
  run)
    echo "Dispatch: $REPO / $WF @ $BR"
    gh workflow run -R "$REPO" "$WF" --ref "$BR"
    sleep 2
    RID="$(gh run list -R "$REPO" --workflow "$WF" -L 1 --json databaseId -q '.[0].databaseId')"
    echo "RID=$RID"
    gh run watch -R "$REPO" "$RID" --interval 5 || true
    ;;
  watch)
    RID="${2:-}"
    [[ -n "$RID" ]] || { echo "need RID"; exit 2; }
    gh run watch -R "$REPO" "$RID" --interval 5 || true
    ;;
  pull)
    echo "Sync local with origin/$BR (rebase)"
    git -C "$ROOT" fetch origin "$BR"
    git -C "$ROOT" rebase "origin/$BR"
    ;;
  lsremote)
    echo "Remote current/ ($REPO:$BR)"
    gh api "repos/$REPO/contents/current?ref=$BR" --jq '.[].name'
    ;;
  pack)
    OUT="HY_CHECKUP_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$OUT"
    {
      echo "REPO=$REPO"
      echo "BR=$BR"
      echo "WF=$WF"
      echo "ROOT=$ROOT"
      echo "URL=$URL"
    } > "$OUT/meta.txt"
    (cd "$ROOT" && {
      git status -sb > "../$OUT/git_status.txt" || true
      git log -n 25 --oneline > "../$OUT/git_log.txt" || true
      ls -la current > "../$OUT/current_ls.txt" 2>/dev/null || true
      ls -la .github/workflows > "../$OUT/workflows_ls.txt" 2>/dev/null || true
      for f in .github/workflows/*.yml .github/workflows/*.yaml; do
        [ -f "$f" ] || continue
        echo "----- $f -----" >> "../$OUT/workflows_dump.txt"
        nl -ba "$f" | sed -n '1,260p' >> "../$OUT/workflows_dump.txt"
        echo >> "../$OUT/workflows_dump.txt"
      done
    })
    zip -r "$OUT.zip" "$OUT" >/dev/null
    echo "Wrote $OUT.zip"
    ;;
  *)
    usage
    exit 2
    ;;
esac
