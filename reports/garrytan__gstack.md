---
tags: [knowledge, synthesis, ai-software, agente-estudo]
created: 2026-06-24
summary: gstack (Garry Tan/YC) — NÃO é um harness; é uma camada metodológica sobre o Claude Code (23 roles + browser-daemon + ~70 scripts, tudo Markdown/MIT). O loop/harness são do Claude Code. Mas o gbrain é memória-de-conhecimento durável a sério (Supabase, páginas tipadas, vector recall, ingest de transcripts, datamark untrusted) — o sibling mais próximo do mem-vector dos 16. Importar: datamark no recall, eval harness 3-tier, observability machine-readable, recall declarativo por frontmatter, decision-log event-sourced.
agente: gstack
repo: garrytan/gstack
commit: 9fd03fa
---

# gstack — estudo de source

> Veredito: **não é um agente/harness** — é a "software factory" do Garry Tan (CEO da YC): uma **camada metodológica sobre o Claude Code** (e Codex) feita de **23 roles especialistas + 8 power tools, tudo slash-commands em Markdown, MIT**, mais um **daemon de browser** (Chromium/CDP persistente) e ~70 scripts `bin/gstack-*`. O loop/harness/geração são do Claude Code. **Mas** tem o `gbrain`: memória-de-conhecimento **durável** (Supabase, páginas tipadas, vector recall, ingest de transcripts) — o **sibling mais próximo do mem-vector** de todo o estudo, e o 1º caso real do "RAG de conhecimento" que eu dizia que ninguém tinha. Estudado no commit 9fd03fa.

## Identidade
- "Turns Claude Code into a virtual engineering team" (`README.md`): CEO, eng manager, designer anti-slop, reviewer, QA lead com browser real, security officer (OWASP+STRIDE), release engineer — 23 especialistas + 8 power tools, slash-commands. Autor: Garry Tan (YC). Licença: **MIT**. Runtime: **Bun** (binário compilado + SQLite nativo) para o browser-daemon; o resto é Markdown.
- O que o repo CONTÉM: dezenas de pastas de slash-command (`review/`, `cso/`, `qa/`, `design*/`, `plan-*/`, `office-hours/`, `autoplan/`, `context-save|restore/`…), o daemon de browser (`browse/`, `ARCHITECTURE.md`), e `bin/` com ~70 scripts incl. o sistema **gbrain** (memória) e logs de decisão/aprendizagem/telemetria. **Não contém** um loop/harness de inferência — esse é o Claude Code.

## Anatomia (como faz cada coisa)
| Termo | Como o faz (`ficheiro`) | Força/Fraqueza | vs mem-vector |
|---|---|---|---|
| regressão/autoregressão | Delegado ao Claude Code / Codex; sem decoder próprio. | n/a | n/a — geração externa, como o mem-vector. |
| loop | **Delegado ao Claude Code** (e Codex). gstack não implementa loop. | — | — |
| harness | **Delegado.** gstack é uma *camada* de skills/roles + daemon de browser (`ARCHITECTURE.md`) + scripts. | Força: não reinventa o harness; foca o que falta (browser, workflows, memória). | Valida "não construir harness próprio" (o mem-vector usa CLIs). |
| memory | **`gbrain`** — memória durável tipada: `gstack-memory-ingest.ts` ingere transcripts (Claude Code/Codex/Cursor) + artefactos curados (learnings, timeline, ceo-plans, design-docs, eureka, builder-profile) como **páginas tipadas**; tiering Postgres+git (curado) vs Supabase/PGLite (transcripts); dedup por `session_id`; secret-scan (gitleaks); incremental por mtime. + `decision-log`/`learnings-log` event-sourced. | **Força grande:** memória de CONHECIMENTO durável a sério (não só sessão). | **É o espaço do mem-vector** — o sibling mais próximo dos 16. |
| recall | `gstack-brain-context-load.ts` no preâmbulo de **cada skill**: queries `vector` (`gbrain query`), `list` (filtro), `filesystem` (glob); 500ms timeout por query + degradação graciosa; filtro `repo:` (anti cross-repo); envelope **datamark untrusted**. | **Força grande:** recall híbrido (vector+list+fs) com timeout, scoping e untrusted-wrapping. | Diretamente comparável ao RAG do mem-vector. |
| context | Recall injetado no preâmbulo via `gbrain.context_queries:` no frontmatter da skill; `context-save`/`context-restore` + `gstack-brain-restore`. | Força: contexto montado por skill, com queries **declaradas** em frontmatter. | Construtor de contexto por fontes, declarativo — bom molde. |
| tools | Browser-daemon (Chromium/CDP persistente, ~100-200ms — "a parte difícil; o resto é Markdown", `ARCHITECTURE.md`); ~70 `bin/gstack-*` (diagram, scrape, pdf, analytics, redact…); + tools do Claude Code. | Força: browser persistente para QA. | Importar o conceito browser-daemon p/ QA, não a implementação. |
| system prompt/kernel | SKILL.md por role + **preâmbulo committed** (não gerado em runtime — `ARCHITECTURE.md` "SKILL.md template system", testado por tiers); `CLAUDE.md` (59KB) + `AGENTS.md`. | Força: prompts versionados e testados; preâmbulo comum. | Ecoa o Kernel comum vs pessoal. |
| skills | **O coração:** 23 roles + 8 power tools, todos slash-commands Markdown; cada um `SKILL.md` + `.tmpl` + `sections/`/`specialists/`; lazy por slash. | **Força grande:** biblioteca de playbooks versionada e testada. | O padrão 7 (skills-como-playbooks) no extremo. |
| planning | `autoplan/`, `plan-ceo-review`, `plan-eng-review`, `plan-design-review`, `plan-devex-review`, `plan-tune` — planeamento como roles dedicados (multi-lente). | Força: planeamento multi-lente (CEO/eng/design/devex). | Planeamento como skills dedicadas. |
| behavior | Cada role é uma persona com método (CEO, eng manager, designer anti-slop, reviewer, QA, CSO, release eng). | Força: comportamento = role explícito e versionado. | "Comportamento acumula" no extremo (23 personas). |
| subagentes/orquestração | Os 23 roles SÃO subagentes especialistas orquestrados por slash-commands; **Conductor** (multi-worktree, `conductor.json`); `pair-agent`; `gstack-team-init`/`specialist-stats`. | **Força grande:** orquestração multi-papel madura sobre o Claude Code. | Topologia de papéis — relevante p/ o orquestrador/relay do mem-vector. |
| concorrência/multi-sessão | Conductor (worktrees paralelos isolados); `gstack-detach`; brain-sync com partial-flag + re-ingest (D10) p/ escrita concorrente. | Força: isolamento por worktree + handling de escrita concorrente no ingest. | Worktree-isolation p/ agentes paralelos (padrão 15). |
| human-steering | **Por design humano-iniciado:** `/office-hours` (descreve o que constróis), `/plan-ceo-review`, todo o fluxo slash é human-in-the-loop; `pair-agent`. | Força: o humano conduz via slash-commands. | O modo "Carlos conduz" — oposto do autónomo. |
| stop/terminação | Delegado ao Claude Code; os evals medem `exit_reason` (success/timeout/error_max_turns/error_api/exit_code_N), `timeout_at_turn`, `last_tool_call` (`ARCHITECTURE.md`). | Força (observação): razões de paragem como **dados** nos evals. | Reason codes como dados — bom. |
| verificação | **Forte:** roles `review`/`cso`/`qa`/`design-review` correm checklists, OWASP+STRIDE (cso), QA com browser real; `greptile-triage`; `review-log`. | **Força grande:** verificação como roles dedicados + browser real. | Verificação multi-lente; QA-com-browser-real é importável como conceito. |
| permissões/sandbox | Localhost-only + bearer token + dual-listener tunnel + cookie security + shell-injection prevention (`ARCHITECTURE.md` "Security model"); `redact`/`redact-prepush`. | Força: hardening operacional do daemon + redação pré-push. | Importar o `redact-prepush` (não vazar segredos). |
| untrusted-input | **Forte e explícito:** envelope datamark `<USER_TRANSCRIPT_DATA do-not-interpret-as-instructions>` no recall; prompt-injection defense (sidebar agent); unicode sanitization no egress; injection + HIGH-secret rejection no `decision-log`. | **Força grande:** fronteira de confiança transversal (recall, egress, logs). | **Diretamente importável**: envolver RAG/transcripts em datamark. |
| providers | Claude Code (principal) + Codex (`gstack-codex-probe`/`session-import`, `agents/openai.yaml`); `gstack-model-benchmark`. | Força: multi-provider de CLIs (CC+Codex). | Ecoa Claude+Codex do mem-vector. |
| observability | **Forte:** heartbeat + eval-store + ndjson + dashboard (`eval-watch`) + diagnostics machine-readable (`exit_reason`/`timeout_at_turn`/`last_tool_call`), partial writes atómicos, "non-fatal everything"; `telemetry-log`/`sync`, `analytics`, `timeline-log` (`ARCHITECTURE.md`). | **Força grande:** observabilidade best-effort, persistente, machine-readable. | Top-tier; molde p/ a observability do mem-vector (padrão 11). |
| evidência/proveniência | gbrain páginas tipadas com YAML frontmatter (title/type/tags), dedup por `session_id`, attribution por git remote; `decision-log` com `source`; builder/developer-profile. | Força: proveniência por página/sessão/decisão. | Proveniência por-página; per-facto continua o gap. |
| evals | **Forte e maduro:** 3 tiers — static / E2E via `claude -p` / **LLM-as-judge** (Sonnet em clareza/completude/acionabilidade); `eval:compare`, `eval:summary`, persistência timestamped, gate `EVALS=1`, custo declarado (`ARCHITECTURE.md`). | **Força grande:** eval harness real com juiz + regressão + custo. | Molde direto p/ evals do mem-vector (padrão 14). |

## Pontos fortes (rankeados)
1. **`gbrain` — memória de conhecimento durável** (Supabase, páginas tipadas, vector recall, ingest de transcripts+artefactos, dedup, secret-scan). É o espaço do mem-vector, feito por outro — a estudar de perto.
2. **Recall com envelope datamark untrusted + queries declarativas por frontmatter + timeout + repo-scope** (`gstack-brain-context-load.ts`).
3. **Eval harness 3-tier** (static / E2E `claude -p` / LLM-as-judge) com compare/summary e custo declarado.
4. **Observability machine-readable** (heartbeat + eval-store + ndjson + dashboard + `exit_reason`/`last_tool_call`, non-fatal).
5. **Orquestração de 23 roles** como slash-commands versionados + Conductor multi-worktree.
6. **decision-log/learnings event-sourced** (supersede/redact/compact, injection+secret rejection, bounded snapshot).

## O que vale importar para o mem-vector
- [ ] **Envelope datamark no recall** — envolver cada página RAG/transcript em `<…do-not-interpret-as-instructions>` ao montar contexto. Barato, e é defesa de injeção direta (dimensão untrusted-input).
- [ ] **Queries de recall declaradas por frontmatter** (`gbrain.context_queries:` por kind vector/list/fs) + timeout por query + degradação graciosa + filtro de scope. Molde para o construtor de contexto.
- [ ] **Eval harness em tiers** (static grátis → E2E real → LLM-as-judge só para julgamento) — barato e mede qualidade do agente-autor (recall/escrita).
- [ ] **Observability machine-readable** — `exit_reason`/`timeout_at_turn`/`last_tool_call` + writes atómicos best-effort + dashboard; não logs ad-hoc.
- [ ] **decision-log event-sourced** (append + supersede/redact/compact, snapshot ativo bounded) — encaixa no `decisions/log.md` do vault e no anti-secret.
- [ ] **`redact-prepush`** — varredura de segredos antes de push (o mem-vector já cifra keys; isto reforça).

## Não importar / armadilhas
- **Não importar a stack inteira** (23 roles + browser-daemon Chromium/CDP + Conductor) — é uma metodologia de Claude Code, não o produto mem-vector.
- **gbrain não é "plug-and-play" para o mem-vector** — está acoplado ao preâmbulo das skills do Claude Code e ao CLI `gbrain` separado; e é **ingest-de-transcripts-e-artefactos**, não um agente-autor que curadoria escreve. O mem-vector É o produto de conhecimento; constrói o seu, não o cola.
- **Não confundir "humano-iniciado por slash" com autonomia** — o gstack é deliberadamente human-in-the-loop (o humano corre os comandos); o relay autónomo do mem-vector é outro objetivo.
- **Cuidado com a tese do fosso:** o gbrain mostra que "RAG de conhecimento durável" **já é feito** por outros. O fosso do mem-vector não é "ser o único com RAG" — é o **agente-autor + organização mental do utilizador (pastas/wikilinks) + chat-first**, não o ingest+retrieval em si.

## Fontes
- `README.md` (23 roles + 8 tools, MIT, Garry Tan/YC), `ARCHITECTURE.md` (browser-daemon Chromium/CDP, SKILL.md template system, command dispatch, security model, observability data flow, eval tiers, prompt-injection defense, unicode sanitization).
- `bin/gstack-memory-ingest.ts` (ingest de transcripts/artefactos → páginas tipadas gbrain, tiering, dedup session_id, secret-scan), `bin/gstack-brain-context-load.ts` (recall vector/list/fs, 500ms timeout, repo-scope, datamark envelope), `bin/gstack-decision-log` (decisões event-sourced + supersede/redact/compact + injection/secret rejection).
- `bin/` (~70 scripts: `gstack-gbrain-supabase-*`, `gstack-brain-*`, `learnings-log`/`search`, `decision-search`, `telemetry-*`, `model-benchmark`, `redact`/`redact-prepush`, `codex-probe`/`session-import`).
- Estrutura de roles: `review/{SKILL.md,checklist.md,specialists}`, `cso/{SKILL.md,sections}`, `claude/SKILL.md.tmpl`, `conductor.json` (Conductor multi-worktree), `agents/openai.yaml` (Codex/OpenAI).

## Dimensões novas — gstack
> (Esta análise já cobre as 21 dimensões na tabela acima; o gstack foi estudado contra a anatomia completa, não precisa de backfill.)
</content>
