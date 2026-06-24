# Síntese transversal — o que 16 agentes ensinam ao mem-vector

Padrões que aparecem em vários relatórios, com quem o faz bem (e ficheiro). Base: os 16 `reports/*.md` (13 com source de agente + `fugu` hospedado + `pi` harness TS + `gstack`, camada metodológica sobre o Claude Code). Após o backfill de 2026-06-24, cada report cobre **21 dimensões** da anatomia (secção "Dimensões novas"). Para a DB do mem-vector, migrar à mão.

## TL;DR

1. **A memória semântica durável era o fosso — até ao `gstack`.** Em quase todos era "vector/RAG geral não encontrado" (gobii, omnigent, paperclip, open-swe, cline, archon; o `pi` confirma-o no harness mais maduro). **MAS o `gstack`/gbrain (Garry Tan, 2026-06-24) fá-lo mesmo:** Supabase, páginas tipadas, vector recall, ingest de transcripts+artefactos, dedup, datamark untrusted. **Correção honesta:** o fosso do mem-vector **não** é "ser o único com RAG de conhecimento" (já existe lá fora) — é o **agente-autor + organização mental do utilizador (pastas/wikilinks) + chat-first**. O ingest+retrieval é commodity; a curadoria-por-agente e a liberdade de organização não.
2. **O campo valida o teu próprio modelo de memória.** O `tanbiralam/claude-code` usa exatamente o que já tens neste vault: índice `MEMORY.md` curto + ficheiros por tópico, taxonomia `user/feedback/project/reference`, excluir o que é derivável de git, exigir `Why`/`How to apply`. Não é coincidência — é o padrão certo.
3. **O que vale importar é disciplina, não plataformas.** Quase todos os "não importar" dizem o mesmo: deixa a stack multi-provider/multi-canal/UI, fica com os contratos pequenos.
4. **O `fugu` é o caso à parte: orquestração não-importável, mas dois presentes.** É um sistema multi-agente hospedado, acedido como um modelo — a coordenação (TRINITY/Conductor) é fechada, não se importa. Mas o repo (instalador/launcher do Codex) dá dois ganhos que os outros não focam: um **guard de auto-proteção do runtime** e a **disciplina de gestão do provider-CLI** (ver padrão 9).
5. **O backfill de 6 dimensões (2026-06-24) mostra onde o campo já é maduro vs onde está o gap.** Maduros e transversais: **observability** (run-ledger/event-log/transcript/custo — quase universal), **untrusted-input** (fronteira anti-injeção), **human-steering** (mid-run + gates), **concorrência** (locks/isolamento). Gaps: **evals de qualidade** (só os mais maduros têm) e **proveniência por-facto** (todos a fazem por sessão/artefacto, ninguém por afirmação). Os dois gaps caem ao lado do fosso (RAG durável) — é o cluster a construir, não a importar.

## Os 16 padrões

### 1. Memória em duas camadas: store canónico + superfície markdown
Store consultável + markdown legível por humanos, e estado de trabalho **reconciliado**, nunca fonte de verdade.
- `ruflo`: bridge AgentDB/RVF ↔ markdown com `MEMORY.md` + topic files (`auto-memory-bridge.ts:457`).
- `gobii`: SQLite efémero por execução, aplica só **diffs validados** ao durável (`sqlite_state.py:32`).
- `openhuman`: SQLite + Markdown sidecars + vector chunks + FTS num só substrate (`memory_store/unified/init.rs:83`).
- `tanbiralam`: memdir, índice curto + ficheiros por tópico (`memdir.ts:199`).
- `hermes`: snapshot **congelado no prompt** + live writes duráveis + batch all-or-nothing (`memory_tool.py:449`).
→ mem-vector: o vault É a superfície markdown; falta a camada canónica consultável + a regra "working-state reconcilia, não manda".

### 2. Recall híbrido: lexical/FTS primeiro, vector depois, com degradação e citações
Não confiar em vector puro. Base determinística barata, embeddings onde acrescentam, sempre com scores/excertos.
- `openclaw`: FTS + vector + MMR + decay temporal + fallback lexical + citações; par `memory_search`→`memory_get` (`memory/manager.ts:667`).
- `ruflo`: SmartRetrieval sem LLM — expansão/RRF/recência/MMR/diversidade (`smart-retrieval.ts:372`).
- `hermes`: FTS5/trigram primeiro, vector só onde FTS falha (`hermes_state.py:611`).
- `odysseus`, `openhuman`, `paperclip`, `tanbiralam`: todos com fallback lexical / manifest antes de embeddings.
- `gstack`/gbrain: recall por kind (`vector`/`list`/`filesystem`) declarado no frontmatter da skill, com timeout 500ms/query, filtro `repo:` (anti cross-repo) e degradação graciosa (`gstack-brain-context-load.ts`).
→ mem-vector: "evidência antes de síntese" = procurar por relevância, depois puxar excerto exato com citação. Expor scores para auditoria. O recall declarativo-por-frontmatter do `gstack` é um bom molde.

### 3. Montagem de contexto + compactação em camadas
Assembler explícito antes do model-call; compactar sem partir pares tool_use/tool_result; marcar o externo como **não confiável**.
- `gobii`: promptree (árvore com prioridades, shrinker head/mid/tail) (`promptree.py:16`).
- `omnigent`: compaction 3 camadas — limpar outputs pesados, resumir antigo, truncar só no fim (`compaction.py:521`).
- `cline`/`tanbiralam`: compaction preserva pares tool_use/tool_result (invariante).
- `hermes`: tiers stable/context/volatile. `openhuman`: prompt estável vs contexto por turno (ganho de cache).
- `odysseus`: `untrusted_context_message` separado do kernel (anti prompt-injection) (`agent_loop.py:1305`).
- `pi`: compaction por **usage real do provider** (não heurística), cut-point que **nunca parte pares tool_use/tool_result**, trata **split-turn** (resume o prefixo à parte) e summary **incremental estruturado** (Goal/Progress/Decisions/Next Steps) + ficheiros lidos/modificados preservados (`compaction/compaction.ts:200,265,387`).
→ mem-vector: construtor de contexto por fontes (mensagens novas, tasks abertas, daily, recalls RAG, permissões), com tiers e tudo o que é RAG/chat marcado untrusted.

### 4. Terminação como dados estruturados + travões de loop
Razão de paragem é um enum, não string em stdout. E travões contra loops.
- `openclaw`: outcome `completed/failed/blocked/aborted/cancelled/hard_timeout` (`agent-run-terminal-outcome.ts:17`).
- `openhuman`: stop hooks + repeat-failure guards (importar quase literal) (`stop_hooks.rs:99`).
- `odysseus`: repeated-call detector + stall breaker + round cap (`agent_loop.py:1922`).
- `open-swe`: stop reasons user-facing (step-limit, circuit breaker) — falha visível, não silêncio.
- `hermes`/`gobii`: termination budget (limite de passos, streak sem tools, razão).
→ mem-vector: estados de run com reason codes, propagados ao relay; travões em jobs longos de vault.

### 5. Relay Claude↔Codex e orquestração
Trocar **envelopes de capacidades/ações**, não tokens nem APIs internas. Fila por canal. Sessões-filhas duráveis e endereçáveis.
- `hermes`: relay por `CapabilityDescriptor`, sem token material no gateway (`relay/transport.py:96`).
- `open-swe`: FIFO queue por thread, consumida antes do próximo model-call (`thread_ops.py:43`).
- `omnigent`: sub-sessões duráveis em vez de subagentes efémeros (`spawn.py:56`).
- `ruflo`: workers por nível de dependência + namespace partilhado, cada um escreve em chave previsível (`dual-mode/orchestrator.ts:258`).
- `archon`: capability registry para escolher provider + **lock por conversa/task** (`conversation-lock.ts:37`).
- `paperclip`: `task_key → session id + summary + cost`. `sandcastle`: contrato provider fino + captura/retoma/fork de sessões.
→ mem-vector: o relay (módulo GitHub) ganha fila por thread, lock por nota/task, e sessões-filhas duráveis Claude/Codex.

### 6. Segurança de escrita + verificação determinística (crítico para um agente-autor)
Verificar **depois** da escrita, com checks de código — não confiar no juízo do LLM. Gate ao que é irreversível.
- `hermes`: verificador pós-tool compara op pedida vs linhas/records realmente alterados; bloqueia falso sucesso (`run_agent.py:2529`).
- `odysseus`: verifier só depois de writes/effects — ficheiro criado? backlinks atualizados? task fechada? (`agent_loop.py:2973`).
- `archon`: structured-output validado antes de persistir + gates humanos para writes perigosos.
- `gobii`: evals durável-vs-efémero **antes** de deixar escrever memória; verificadores determinísticos para integridade.
- `tanbiralam`: escrita confinada a path allowlistado; excluir o que é derivável de git.
- `cline`: policy engine antes de tools (`.memignore`, allow/deny, bloqueio de destrutivas).
- `pi`: **lock de mutação por-ficheiro** (`realpath`, paralelo entre ficheiros, série no mesmo — `file-mutation-queue.ts:32`) + **writes de sessão diferidos→flush em save point** (`agent-harness.ts:462,504`) = consistência sem transação. **MAS sem verify pós-write** (o write só devolve "wrote N bytes") — é o contraexemplo: ótima concorrência, zero verificação.
→ mem-vector: após cada write ao vault, check determinístico (ficheiro, wikilinks, task, dedupe). Gate em apagar/reescrever factos. A lock por-ficheiro do `pi` resolve a concorrência; o verify continua a ser obrigatório (hermes/odysseus), porque o `pi` não o tem. Apagar/reescrever factos é uma operação a confirmar, não a automatizar.

### 7. Skills como playbooks versionados, lazy, de fonte confiável
Skills = procedimentos versionados, carregados sob pedido, **só de fonte confiável**. Factos vão para o vault, não para skills.
- `cline`/`omnigent`/`odysseus`/`paperclip`: `SKILL.md` lazy por frontmatter, versionada, com validação de trust/source.
- `open-swe`: skills extraídas do `base_sha`, nunca de conteúdo não confiável (anti skill-injection) (`repo_prep.py:124`).
→ mem-vector: router determinístico por intent (não só o LLM a escolher); skills novas em quarentena/revisão.

### 8. Tasks/plano como estado operacional (não texto)
- `openhuman`: board com plan/acceptance/evidence/blocker (`todos/ops.rs:181`).
- `openclaw`: `update_plan` com um item `in_progress` + `goal` com bloqueio repetido.
- `cline`/`odysseus`/`tanbiralam`: todo/focus-chain persistido em markdown, re-injetado quando muda.
→ mem-vector: as tasks do vault ganham acceptance/evidence/blocker e re-injeção.

### 9. Gestão do provider-CLI + auto-proteção do runtime (sobretudo do `fugu`)
Quando o agente corre OUTRA CLI (Codex) como provider, há uma camada operacional que os 8 padrões não cobrem: gerir esse binário e proteger o runtime de si próprio.
- **Auto-proteção no system prompt** — `fugu`: `base_instructions` proíbe matar o próprio runtime, `kill -9` a PIDs arbitrários ou reiniciar o ambiente onde corre ("can permanently break the session"); parar processos por nome e avisar o utilizador (`configs/files/fugu.json`). Guard agnóstico ao host.
- **Gestão do provider-CLI** — `fugu`: pin de versão + deteção de mismatch config↔binário, update não-bloqueante com lock (flock) + throttle, backup-antes-de-trocar (com índice de sessão) + rollback, segredo em store 0600 fora do shell rc (`scripts/codex-fugu`, `scripts/install.sh`). Ecoa `sandcastle` (contrato provider fino), `archon` (capability registry) e `omnigent` (provider router) — mas o fugu é o único que trata a **gestão operacional** do provider, não só a seleção.
- **Stream-resilience como config** — `fugu`: idle timeout longo + `stream_max_retries`/`request_max_retries` (`configs/injects/model_providers.sakana.toml`).
→ mem-vector: o relay despacha o Codex, logo herda esta camada. O guard de auto-proteção entra no Kernel/relay (não matar o próprio runtime — evita partir a própria sessão); versão/backup/lock do Codex (o runner não herda config do host às cegas); os knobs de stream entram no provider.

### 10. Núcleo mínimo + tudo-é-extensão (hook bus tipado) — sobretudo do `pi`
O loop/sessão/compaction/contrato-de-tool ficam pequenos e estáveis; **permissões, planeamento, subagentes, structured-output e providers à medida vivem como extensões** sobre um event bus tipado. Cresce-se sem reescrever o motor.
- `pi`: hook bus tipado (`agent-harness.ts` `on`/`subscribe`) com eventos Context / ToolCall(bloqueia) / ToolResult(verifica/termina) / Session(before-compact/tree/fork) / Provider(before-request/payload); `defineTool` para tools de extensão; ~60 extensões reais em `examples/extensions/` — `permission-gate`, `confirm-destructive`, `protected-paths`, `subagent`, `handoff`, `plan-mode`, `todo`, `structured-output`, `custom-provider-*`.
- `cline`: policy engine como camada antes das tools. `sandcastle`: contrato de provider fino e plugável. `hermes`: relay por `CapabilityDescriptor`. `archon`: capability registry para escolher provider.
→ mem-vector: modelar os add-ons (relay, tasks, permissões) como **extensões sobre um core estável**, com os mesmos pontos de hook (before/after tool, context, before-compact). Encaixa no "módulos = add-ons" já decidido; o relay deixa de exigir reescrever o loop. **Atenção:** o que é integridade do produto (verify pós-write, gate destrutivo) fica no **core**, não em extensão opt-in — o `pi` erra aqui (permissões e guard-rails são todos extensões, nada imposto por omissão).

### 11. Observability: run-ledger + event-log + transcript + custo, de primeira classe
Quase universal — o campo todo externaliza a corrida (e foi o que a anatomia v1 não tinha como termo).
- `paperclip`: `heartbeat_runs` (estado/usage/log NDJSON com SHA + custo) + eventos live (`heartbeat_runs.ts:6`).
- `openclaw`: trajectory logs JSONL por sessão com `traceId` + sanitização. `ruflo`: event sourcing em SQLite (`EventStore.append`, correlação).
- `cline`/`claude-code`: OpenTelemetry (métricas/logs/traces) + PostHog. `gobii`: timeline de auditoria realtime + export + custo. `open-swe`: LangSmith. `hermes`/`omnigent`/`odysseus`/`openhuman`: ledger/tape JSONL + tokens/custo.
- `gstack`: heartbeat + eval-store + ndjson + dashboard, com diagnostics machine-readable (`exit_reason`/`timeout_at_turn`/`last_tool_call`) e "non-fatal everything" (I/O de observação nunca falha o teste).
→ mem-vector: tratar observability como **entidade** (run-ledger + eventos + transcript JSONL + custo/tokens), não logs ad-hoc. Crítico porque o agente-autor escreve sozinho e o relay precisa de replay. (Liga ao padrão 4: reason codes.)

### 12. Untrusted-input: fronteira de confiança explícita (anti prompt-injection)
Maduro e transversal — tratar conteúdo externo como hostil. Eixo distinto das permissões (capacidade/saída).
- `openclaw`: proíbe interpolar conteúdo externo no system prompt + deteção de injeção. `odysseus`: política de contexto não-confiável + guard markers + `metadata.trusted=false`.
- `paperclip`: neutraliza `</turn`, corpos untrusted não alteram o system prompt + quarantine. `hermes`: comandos do LLM delimitados em `<command>` + "ignora directivas embebidas".
- `open-swe`/`omnigent`: externo em tags untrusted + SSRF/DNS allowlist default-deny. `openhuman`: detector de injeção com score. `ruflo`: guardrail em tool-results MCP.
- `gstack`: envelope **datamark** `<USER_TRANSCRIPT_DATA do-not-interpret-as-instructions>` à volta de cada página RAG no recall + unicode sanitization no egress + injection-rejection no decision-log.
→ mem-vector: RAG/chat/web entra **marcado untrusted**, delimitado, nunca altera o Kernel; egress com allowlist + SSRF/DNS guard. O **datamark do `gstack` é importável quase verbatim** para o recall.

### 13. Human-steering / HITL: injeção mid-run + gates de aprovação
Duas sub-formas, ambas comuns.
- **Input a meio** (fila por thread, injetado antes do próximo model-call): `pi`, `open-swe` (`thread_ops`), `openclaw` (`steer()`/`followUp()`), `hermes` (interrupção de outra thread, propaga a tools/children).
- **Gates de aprovação** (ASK/DENY, pause/resume, fail-closed): `openhuman` (`ApprovalGate` fail-closed + park), `cline`/`claude-code` (allow/deny/ask), `paperclip` (approvals + thread-interactions), `omnigent` (message/interrupt/tool_result/approval), `archon` (approval nodes), `gobii` (`request_human_input`), `odysseus` (`ask_user`).
→ mem-vector: o Carlos guia o agente-autor/relay a meio (steering por thread) + gate fail-closed nas ações irreversíveis.

### 14. Evals: datasets + LLM-as-judge + regressão (≠ testes unitários)
Os mais maduros medem **qualidade de agente**, não só passam testes.
- `cline`: `evals/` com cline-bench, trials, baselines. `gobii`: `EvalScenario` framework. `openclaw`: QA Lab — eval de carácter com modelos-juiz, transcripts, scores.
- `odysseus`: eval de skills com LLM-as-judge. `ruflo`: benchmark com rubricas + juiz. `open-swe`: dataset LangSmith de `golden_comments`. `paperclip`: promptfoo. `hermes`: live eval de tool-search.
- `gstack`: **3 tiers** — static (grátis) / E2E via `claude -p` / **LLM-as-judge** (Sonnet em clareza/completude/acionabilidade), com `eval:compare`/`summary`, persistência timestamped e custo declarado. O molde mais limpo dos 16.
- Não encontrado: `archon` (só roadmap), `omnigent`, `claude-code`, `sandcastle`, `openhuman`.
→ mem-vector: evals do **recall e da escrita** do agente-autor (dataset + juiz + regressão). Distinto do verify in-loop (1 ação) e da observability (ver a corrida).

### 15. Concorrência / multi-sessão: lock por unidade + isolamento + um-escritor
Maduro — N corridas sobre estado partilhado sem corromper.
- `pi`: lock por-ficheiro (`withFileMutationQueue`, realpath). `openclaw`: session-write-lock com owner + stale detection + watchdog. `hermes`: `SessionDB` WAL (um escritor).
- `gobii`: Redlock Redis + heartbeat. `paperclip`: `withAgentStartLock` + checkout locks transaccionais. `omnigent`: `asyncio.Lock` por conversa + DB locks. `claude-code`: lockfile cross-process. `archon`/`sandcastle`: isolamento por worktree/branch p/ agentes paralelos.
→ mem-vector: lock por nota/task + deteção de stale; isolar agentes paralelos; um-escritor por sessão. (Liga ao padrão 5: fila por thread, e ao 6: lock por-ficheiro.)

### 16. Evidência / proveniência: por sessão/artefacto é comum; por-facto é raro (o gap)
- Comum (sessão/artefacto/run): `paperclip` (`SourceTrustMetadata`), `openclaw` (`InputProvenance`), `hermes` (session provenance), `archon` (eventos com url/path).
- Recall com proveniência: `ruflo` (contribuição semântica+BM25 explicável), `odysseus` (`rag_sources` filename/snippet/similarity), `openhuman` (`RetrievalHit` source_ref), `open-swe` (findings com file/line/sha).
- Quase todos anotam "sem citações **por facto**" nos outputs normais.
→ mem-vector: proveniência **por-facto** (cada nota/afirmação cita a fonte) é a parte a construir — o lado "evidência antes de teoria" do produto. (Reforça o padrão 2: recall com citações.)

## Importar primeiro (maior alavanca, menor custo)

1. **Recall híbrido com fallback lexical + citações** (openclaw, hermes, ruflo) — é o coração do RAG e todos o fazem melhor que vector puro.
2. **Verificador determinístico pós-write** (hermes, odysseus) — barato, e protege a integridade do vault que é o produto.
3. **Memória em duas camadas + reconciliação de working-state** (gobii, ruflo, openhuman) — resolve "quem manda" entre efémero e durável.
4. **Terminação enum + travões de loop** (openclaw, openhuman, odysseus) — importar quase literal.
5. **Fila por thread + lock por nota/task no relay** (open-swe, archon) — desbloqueia o relay autónomo sem corrupção.
6. **Construtor de contexto por fontes + compaction em camadas + untrusted context** (omnigent, gobii, odysseus).
7. **Guard de auto-proteção do runtime no Kernel/relay** (fugu) — não matar o próprio runtime nem `kill -9` PIDs arbitrários; quase verbatim, barato, e evita partir a própria sessão.
8. **Lock de mutação por-ficheiro + writes diferidos→save point** (pi) — quase verbatim (`file-mutation-queue.ts`); resolve a concorrência de escrita ao vault/DB com custo mínimo.
9. **Seam de extensões/hooks tipado para os add-ons** (pi, cline, sandcastle) — relay/tasks/permissões como extensões sobre um core estável; integridade (verify/gate) fica no core.

## Não importar (quase unânime)

- A stack inteira: multi-provider sprawl, multi-canal (Slack/Telegram/GitHub), UI/IDE, billing. Claude+Codex chega.
- Tratar ledger/sessões/FTS como se fosse RAG de conhecimento — não é; é a tua parte a construir.
- Verificação só por juízo do LLM — usar checks determinísticos para vault, links, tasks.
- Regras críticas só em prompt prose — encodar em código.
- `danger-full-access`/bypass/shell livre como default — permissões explícitas por ferramenta.
- Guardar arquitectura/código (derivável de grep/git) como memória durável.
- Subagentes/swarms cedo — custo + proveniência + conflitos de escrita.

---
Anatomia e prompt-contrato: `../MythosEngine/knowledge/AI/software/anatomia-de-um-agente.md`. Relatórios por agente: `reports/`. Índice: `INDEX.md`.
