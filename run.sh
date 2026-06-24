#!/usr/bin/env bash
# Estudo de agentes do open source: clona cada repo e corre o Codex (relay autónomo)
# para extrair pontos fortes a importar para o mem-vector. CORRE EM PARALELO.
# Saída: reports/<owner__repo>.md  | Logs: logs/<owner__repo>.log
# Resumível: salta repos que já têm relatório. Uso: ./run.sh [repo1 repo2 ...]
set -uo pipefail
ROOT="$HOME/src/agent-study"
CLONES="$ROOT/clones"; REPORTS="$ROOT/reports"; LOGS="$ROOT/logs"
mkdir -p "$CLONES" "$REPORTS" "$LOGS"

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
CODEX_TIMEOUT="${CODEX_TIMEOUT:-1800}"   # 30 min por repo (rede contra hangs)

one_repo() {
  local repo="$1" name report log prompt rc
  name="${repo//\//__}"; report="$REPORTS/$name.md"; log="$LOGS/$name.log"
  if [[ -f "$report" ]]; then echo "SKIP (já feito) $repo"; return 0; fi
  if [[ ! -d "$CLONES/$name/.git" ]]; then
    rm -rf "$CLONES/$name"
    if ! git clone --depth 1 "https://github.com/$repo" "$CLONES/$name" >"$log" 2>&1; then
      echo "DEAD/clone-fail $repo"; return 0
    fi
  fi
  prompt="$(sed "s|__NAME__|$name|g" "$ROOT/contract.tmpl")"
  timeout "$CODEX_TIMEOUT" codex exec \
    -C "$ROOT" -s workspace-write --skip-git-repo-check --ignore-rules \
    "$prompt" >>"$log" 2>&1
  rc=$?
  if [[ -f "$report" ]]; then echo "OK $repo"; else echo "NO-REPORT $repo (rc=$rc, ver logs/$name.log)"; fi
}

echo "=== $(date +%H:%M:%S) lançar ${#REPOS[@]} repos EM PARALELO ==="
for repo in "${REPOS[@]}"; do
  one_repo "$repo" &
done
wait
echo "=== $(date +%H:%M:%S) FIM. Reports escritos: $(ls -1 "$REPORTS"/*.md 2>/dev/null | wc -l)/13 ==="
ls -1 "$REPORTS"/*.md 2>/dev/null | xargs -n1 basename
