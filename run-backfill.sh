#!/usr/bin/env bash
# Backfill profundo: re-clona cada repo e corre o Codex SÓ para as 6 dimensões novas
# (observability, evidência, evals, untrusted-input, human-steering, concorrência),
# escrevendo reports/_delta/<owner__repo>.md. O Claude integra depois nos reports.
# CORRE EM PARALELO. Resumível: salta repos que já têm delta. Uso: ./run-backfill.sh [repo...]
set -uo pipefail
ROOT="$HOME/src/agent-study"
CLONES="$ROOT/clones"; DELTA="$ROOT/reports/_delta"; LOGS="$ROOT/logs"
mkdir -p "$CLONES" "$DELTA" "$LOGS"

# Os 13 originais do Codex (fugu e pi são feitos pelo Claude à mão).
REPOS=(
  paperclipai/paperclip
  cline/cline
  NousResearch/hermes-agent
  langchain-ai/open-swe
  openclaw/openclaw
  mattpocock/sandcastle
  tinyhumansai/openhuman
  pewdiepie-archdaemon/odysseus
  ruvnet/ruflo
  omnigent-ai/omnigent
  coleam00/Archon
  gobii-ai/gobii-platform
  tanbiralam/claude-code
)
[[ $# -gt 0 ]] && REPOS=("$@")
CODEX_TIMEOUT="${CODEX_TIMEOUT:-1800}"

one_repo() {
  local repo="$1" name delta log prompt rc
  name="${repo//\//__}"; delta="$DELTA/$name.md"; log="$LOGS/$name.delta.log"
  if [[ -f "$delta" ]]; then echo "SKIP (delta feito) $repo"; return 0; fi
  if [[ ! -d "$CLONES/$name/.git" ]]; then
    rm -rf "$CLONES/$name"
    if ! git clone --depth 1 "https://github.com/$repo" "$CLONES/$name" >"$log" 2>&1; then
      echo "DEAD/clone-fail $repo"; return 0
    fi
  fi
  prompt="$(sed "s|__NAME__|$name|g" "$ROOT/contract-backfill.tmpl")"
  timeout "$CODEX_TIMEOUT" codex exec \
    -C "$ROOT" -s workspace-write --skip-git-repo-check --ignore-rules \
    "$prompt" >>"$log" 2>&1
  rc=$?
  if [[ -f "$delta" ]]; then echo "OK $repo"; else echo "NO-DELTA $repo (rc=$rc, ver logs/$name.delta.log)"; fi
}

echo "=== $(date +%H:%M:%S) backfill: lançar ${#REPOS[@]} repos EM PARALELO ==="
for repo in "${REPOS[@]}"; do
  one_repo "$repo" &
done
wait
echo "=== $(date +%H:%M:%S) FIM. Deltas: $(ls -1 "$DELTA"/*.md 2>/dev/null | wc -l)/${#REPOS[@]} ==="
ls -1 "$DELTA"/*.md 2>/dev/null | xargs -n1 basename 2>/dev/null