---
tags: [knowledge, synthesis, ai-software, agente-estudo]
created: 2026-06-22
summary: Paperclip — control plane de agentes de coding; importar run ledger, wake/context contract, sessões por tarefa e summaries, não a máquina multi-company inteira.
agente: Paperclip
repo: paperclipai/paperclip
commit: 1ca3331
---

# Paperclip — estudo de source

> Veredito: Paperclip não é um agente único: é um control plane que invoca agentes externos via adapters, guarda estado operacional e gere workspaces, permissões, skills e wakes. Estudado no commit 1ca3331.

## Identidade
- É uma plataforma TypeScript/Node para empresas de agentes: o `AGENTS.md` define Paperclip como “control plane for AI-agent companies” e separa `server/`, `ui/`, `packages/db/`, `packages/adapters/` e MCP (`clones/paperclipai__paperclip/AGENTS.md:1`).
- Provider: multi-provider por adapters, não provider próprio; inclui Claude, Codex, Cursor, Gemini, Grok, OpenCode, Pi, OpenClaw, Hermes, process e HTTP (`clones/paperclipai__paperclip/server/src/adapters/registry.ts:538`). Licença MIT (`clones/paperclipai__paperclip/LICENSE:1`). Linguagem/package base: TypeScript ESM, Node >=20, pnpm (`clones/paperclipai__paperclip/package.json:2`, `clones/paperclipai__paperclip/package.json:63`).

## Anatomia (como faz cada coisa)
| Termo | Como o faz (`ficheiro`) | Força/Fraqueza | vs agente-autor simples |
|---|---|---|---|
| regressão/autoregressão | Não implementa decoder/model loop próprio; delega a execução para adapters com contrato `AdapterExecutionContext`/`AdapterExecutionResult` (`clones/paperclipai__paperclip/packages/adapter-utils/src/types.ts:69`, `clones/paperclipai__paperclip/packages/adapter-utils/src/types.ts:122`). | Força: abstrai providers. Fraqueza: pouco controlo fino sobre raciocínio/tokenização. | Pior para experimentar kernels cognitivos próprios; melhor para trocar providers sem reescrever a app. |
| loop | O loop real é o `heartbeatService`: reclama runs queued, prepara contexto/workspace, chama `adapter.execute`, persiste resultado, agenda retries/wakes (`clones/paperclipai__paperclip/server/src/services/heartbeat.ts:3370`, `clones/paperclipai__paperclip/server/src/services/heartbeat.ts:7232`, `clones/paperclipai__paperclip/server/src/services/heartbeat.ts:9540`). | Força: robusto, persistente, recuperável. Fraqueza: muito acoplado a issues/empresa/orçamento. | Melhor que um loop simples para produção; pesado demais para um agente-autor local. |
| harness | O harness é task/workspace/env: auto-checkout de issue (`clones/paperclipai__paperclip/server/src/services/heartbeat.ts:8290`), resolução de ambiente e workspace (`clones/paperclipai__paperclip/server/src/services/environment-run-orchestrator.ts:166`), e passagem de `executionTarget` ao adapter (`clones/paperclipai__paperclip/packages/adapter-utils/src/types.ts:122`). | Força: separa run, workspace e permissões. Fraqueza: complexo. | Melhor para relay Claude-Codex e tarefas persistentes; um autor simples pode usar versão reduzida. |
| memory | Memória operacional em Postgres: issues, comments, documents/revisions, runs, events, runtime state e task sessions (`clones/paperclipai__paperclip/packages/db/src/schema/issues.ts:22`, `clones/paperclipai__paperclip/packages/db/src/schema/documents.ts:6`, `clones/paperclipai__paperclip/packages/db/src/schema/heartbeat_runs.ts:6`, `clones/paperclipai__paperclip/packages/db/src/schema/agent_task_sessions.ts:6`). | Força: auditável e relacional. Fraqueza: memory é mais ledger do que conhecimento semântico. | Melhor para histórico verificável; pior que mem-vector se o objectivo central for RAG/vector recall. |
| recall | Search lexical/fuzzy em issues, comments e documents com tokens, `LIKE`, snippet e trigram/similarity; embeddings/vector store não encontrado no core (`clones/paperclipai__paperclip/server/src/services/company-search.ts:65`, `clones/paperclipai__paperclip/server/src/services/company-search.ts:353`). | Força: simples, explicável, sem infra de embeddings. Fraqueza: recall semântico fraco. | Pior que mem-vector para conhecimento; bom como fallback lexical e fonte de snippets. |
| context | Constrói markdown de task com issue, assignee, work mode, comentário recente e regras de execução (`clones/paperclipai__paperclip/server/src/services/heartbeat.ts:3023`); injecta `paperclipIssue`, `paperclipWakeComment`, `paperclipWorkspace` e `paperclipEnvironment` no contexto (`clones/paperclipai__paperclip/server/src/services/heartbeat.ts:8548`, `clones/paperclipai__paperclip/server/src/services/heartbeat.ts:9138`). | Força: contexto explícito, task-scoped. Fraqueza: prompt/context pode crescer e duplicar estado. | Melhor que um autor simples sem envelope de tarefa; importar a estrutura, não todo o payload. |
| tools | Expõe ferramentas MCP para issues, comments, docs, goals, approvals, interactions e runtime (`clones/paperclipai__paperclip/packages/mcp-server/src/tools.ts:236`); plugins têm capabilities mapeadas por método (`clones/paperclipai__paperclip/packages/plugins/sdk/src/host-client-factory.ts:420`). | Força: API de acção explícita. Fraqueza: superfície grande. | Melhor para agent-as-OS; mem-vector deve copiar só tools de vault/task/relay. |
| system prompt/kernel | Usa `DEFAULT_PAPERCLIP_AGENT_PROMPT_TEMPLATE` com contrato de progresso, final disposition, child issues, approvals e budget (`clones/paperclipai__paperclip/packages/adapter-utils/src/server-utils.ts:113`); wake prompt reforça payload, escopo e regras (`clones/paperclipai__paperclip/packages/adapter-utils/src/server-utils.ts:828`). | Força: kernel comportamental claro. Fraqueza: muita governação em prompt. | Melhor do que prompt avulso; mem-vector deve transformar isto em contratos curtos por modo. |
| skills | Skills são artefactos versionados na DB com markdown/source/trust/file inventory (`clones/paperclipai__paperclip/packages/db/src/schema/company_skills.ts:16`), validados contra scripts externos perigosos e sources não pinned (`clones/paperclipai__paperclip/server/src/services/company-skills.ts:189`), depois materializados no runtime (`clones/paperclipai__paperclip/server/src/services/company-skills.ts:3956`). | Força: skill registry auditável. Fraqueza: overhead alto. | Melhor para equipas; para mem-vector basta skills versionadas no vault/DB. |
| planning | `workMode` de issue altera instruções: `ask`, `planning`, `accepted_plan`, blocker/tree hold e reviewer role (`clones/paperclipai__paperclip/server/src/services/heartbeat.ts:3070`, `clones/paperclipai__paperclip/packages/adapter-utils/src/server-utils.ts:886`). | Força: planning é estado persistido, não só texto. Fraqueza: depende de convenções e prompts. | Melhor que um plano solto no chat; vale importar como estado de tarefa. |
| behavior | Prompt manda começar trabalho accionável, preservar progresso durável, preferir verificação pequena e encerrar com disposição clara (`clones/paperclipai__paperclip/packages/adapter-utils/src/server-utils.ts:113`). Interactions/approvals criam gates humanos estruturados (`clones/paperclipai__paperclip/packages/db/src/schema/approvals.ts:5`, `clones/paperclipai__paperclip/server/src/services/issue-thread-interactions.ts:758`). | Força: reduz ambiguidades operacionais. Fraqueza: verificação ainda depende do agente/provider. | Melhor para disciplina de execução; mem-vector deve copiar gates e dispositions. |
| subagentes/orquestração | Suporta reporting hierarchy em agents (`clones/paperclipai__paperclip/packages/db/src/schema/agents.ts:23`), parent/child issues (`clones/paperclipai__paperclip/packages/db/src/schema/issues.ts:78`) e criação/decomposição de child tasks a partir de plano aceite (`clones/paperclipai__paperclip/server/src/services/issues.ts:4568`, `clones/paperclipai__paperclip/server/src/services/issues.ts:4625`). | Força: decomposição persistente e atribuível. Fraqueza: complexo se só há um autor. | Melhor para relay multi-agente; mem-vector deve importar child tasks, não organigramas. |
| stop/terminação | Estados terminais definidos (`clones/paperclipai__paperclip/server/src/services/heartbeat.ts:238`), cancelamento mata process group e marca status (`clones/paperclipai__paperclip/server/src/services/heartbeat.ts:11756`), retries e recovery são criados por heartbeat (`clones/paperclipai__paperclip/server/src/services/heartbeat.ts:9816`, `clones/paperclipai__paperclip/server/src/services/heartbeat.ts:10577`). | Força: stop é persistente e observável. Fraqueza: recovery machinery grande. | Melhor que processo local solto; importar estados simples e kill/retry auditável. |
| verificação | Não há verifier universal encontrado; o kernel manda “smallest verification” (`clones/paperclipai__paperclip/packages/adapter-utils/src/server-utils.ts:121`) e o harness guarda logs/result/cost/session (`clones/paperclipai__paperclip/packages/db/src/schema/heartbeat_runs.ts:21`). Tem scripts de test/e2e/evals no repo (`clones/paperclipai__paperclip/package.json:20`, `clones/paperclipai__paperclip/package.json:50`). | Força: captura evidência de run. Fraqueza: verificação é recomendação, não garantia. | Um agente-autor simples com verificador explícito por task pode ser melhor. |
| permissões/sandbox | Low-trust runtime exige workspaces isolados, sandbox e boundary checks (`clones/paperclipai__paperclip/server/src/services/low-trust-runtime-containment.ts:44`); ambientes são leaseados/adquiridos e validados (`clones/paperclipai__paperclip/server/src/services/environment-runtime.ts:430`, `clones/paperclipai__paperclip/server/src/services/environment-runtime.ts:562`); orçamentos podem bloquear ou cancelar runs (`clones/paperclipai__paperclip/packages/db/src/schema/budget_policies.ts:4`, `clones/paperclipai__paperclip/server/src/services/heartbeat.ts:11912`). | Força: boa separação para código não confiável. Fraqueza: custo operacional. | Melhor para SaaS; mem-vector local deve usar uma versão mínima: allowlist, approvals, budget. |
| providers | Registry de adapters built-in e externos (`clones/paperclipai__paperclip/server/src/adapters/registry.ts:538`, `clones/paperclipai__paperclip/server/src/adapters/registry.ts:560`). Codex local prepara `CODEX_HOME`, skills, prompt, env `PAPERCLIP_*` e executa `codex exec --json` (`clones/paperclipai__paperclip/packages/adapters/codex-local/src/server/execute.ts:323`, `clones/paperclipai__paperclip/packages/adapters/codex-local/src/server/codex-args.ts:31`). | Força: portabilidade entre agentes. Fraqueza: cada provider traz edge cases. | Melhor para relay Claude-Codex; não importar providers que não sejam necessários. |

## Pontos fortes (rankeados)
1. Run ledger persistente: `heartbeat_runs` + `heartbeat_run_events` guardam estado, logs, contexto, uso, processo e eventos (`clones/paperclipai__paperclip/packages/db/src/schema/heartbeat_runs.ts:6`, `clones/paperclipai__paperclip/packages/db/src/schema/heartbeat_run_events.ts:6`).
2. Context envelope por tarefa/wake: issue, comentário recente, workspace, environment e runtime entram de forma estruturada antes do adapter (`clones/paperclipai__paperclip/server/src/services/heartbeat.ts:8548`, `clones/paperclipai__paperclip/server/src/services/heartbeat.ts:9086`).
3. Sessões por tarefa e continuação: `agent_task_sessions` persiste session params/display ids (`clones/paperclipai__paperclip/packages/db/src/schema/agent_task_sessions.ts:6`) e `issue-continuation-summary` mantém um documento resumido com estado/next action (`clones/paperclipai__paperclip/server/src/services/issue-continuation-summary.ts:136`).
4. Skills versionadas e materializadas no runtime, com validação de confiança/source (`clones/paperclipai__paperclip/packages/db/src/schema/company_skills.ts:16`, `clones/paperclipai__paperclip/server/src/services/company-skills.ts:189`).
5. Gates humanos e governação operacional: approvals, interactions, budgets e low-trust containment estão modelados como estado, não só prompt (`clones/paperclipai__paperclip/packages/db/src/schema/approvals.ts:5`, `clones/paperclipai__paperclip/server/src/services/low-trust-runtime-containment.ts:44`).

## O que vale importar para o mem-vector
- [ ] Run/event ledger mínimo — guardar run, provider, prompt/context hash, logs, outcome, cost, session id e next action; encaixa na DB do mem-vector como trilho auditável de chat/RAG/tasks.
- [ ] Wake/context contract — criar um payload canónico para daily/task/relay com issue, comentário mais recente, blockers, workspace e memória recuperada; encaixa no relay Claude↔Codex e no arranque de tarefas.
- [ ] Task-scoped sessions — manter `task_key -> provider session id + summary + cost` para retomar Claude/Codex sem misturar tarefas; encaixa na camada de execução.
- [ ] Continuation summary como documento de vault — depois de cada run, actualizar um resumo curto com estado, decisões, ficheiros tocados, verificação e next action; encaixa em daily notes e RAG.
- [ ] Search lexical como fallback ao vector — copiar a ideia de procurar em issues/comments/docs por tokens/snippets antes ou depois do vector recall; melhora debug e explicabilidade.
- [ ] Skills versionadas — tratar prompts, workflows e policies como documentos versionados e montáveis por run; encaixa no vault/DB de conhecimento.
- [ ] Gates estruturados de approval/interaction — modelar perguntas, aprovações e blockers como objectos com estado; evita perder decisões no chat.
- [ ] Workspace/environment envelope reduzido — para runs de coding, guardar root, branch, sandbox/approval mode e secrets permitidos; suficiente sem importar o orquestrador inteiro.

## Não importar / armadilhas
- Não importar a arquitectura multi-company completa: agents hierárquicos, plugin host, environments, leases e UI tornam-se lastro se mem-vector for primeiro um agente-autor pessoal.
- Não confundir ledger relacional com memória semântica: embeddings/vector RAG no core não encontrado; Paperclip precisa de mem-vector mais do que o substitui.
- Não copiar provider sprawl: Claude/Codex relay é suficiente até haver necessidade real de Cursor/Gemini/Grok/etc.
- Não depender só de prompt para verificação: Paperclip recomenda verificação, mas verifier universal não encontrado.
- Não mover todos os gates para permissões complexas: approvals/budgets simples dão 80% do valor sem sandbox SaaS.
- Não materializar skills externas executáveis sem política forte: o próprio Paperclip bloqueia scripts e sources não pinned (`clones/paperclipai__paperclip/server/src/services/company-skills.ts:189`).

## Fontes
- `clones/paperclipai__paperclip/AGENTS.md`
- `clones/paperclipai__paperclip/package.json`
- `clones/paperclipai__paperclip/LICENSE`
- `clones/paperclipai__paperclip/server/src/services/heartbeat.ts`
- `clones/paperclipai__paperclip/server/src/services/company-search.ts`
- `clones/paperclipai__paperclip/server/src/services/company-skills.ts`
- `clones/paperclipai__paperclip/server/src/services/environment-run-orchestrator.ts`
- `clones/paperclipai__paperclip/server/src/services/environment-runtime.ts`
- `clones/paperclipai__paperclip/server/src/services/low-trust-runtime-containment.ts`
- `clones/paperclipai__paperclip/server/src/services/issue-continuation-summary.ts`
- `clones/paperclipai__paperclip/server/src/services/issues.ts`
- `clones/paperclipai__paperclip/server/src/services/issue-thread-interactions.ts`
- `clones/paperclipai__paperclip/server/src/adapters/registry.ts`
- `clones/paperclipai__paperclip/packages/adapter-utils/src/types.ts`
- `clones/paperclipai__paperclip/packages/adapter-utils/src/server-utils.ts`
- `clones/paperclipai__paperclip/packages/adapters/codex-local/src/server/execute.ts`
- `clones/paperclipai__paperclip/packages/adapters/codex-local/src/server/codex-args.ts`
- `clones/paperclipai__paperclip/packages/mcp-server/src/tools.ts`
- `clones/paperclipai__paperclip/packages/plugins/sdk/src/host-client-factory.ts`
- `clones/paperclipai__paperclip/packages/db/src/schema/agents.ts`
- `clones/paperclipai__paperclip/packages/db/src/schema/issues.ts`
- `clones/paperclipai__paperclip/packages/db/src/schema/issue_comments.ts`
- `clones/paperclipai__paperclip/packages/db/src/schema/documents.ts`
- `clones/paperclipai__paperclip/packages/db/src/schema/document_revisions.ts`
- `clones/paperclipai__paperclip/packages/db/src/schema/heartbeat_runs.ts`
- `clones/paperclipai__paperclip/packages/db/src/schema/heartbeat_run_events.ts`
- `clones/paperclipai__paperclip/packages/db/src/schema/agent_runtime_state.ts`
- `clones/paperclipai__paperclip/packages/db/src/schema/agent_task_sessions.ts`
- `clones/paperclipai__paperclip/packages/db/src/schema/company_skills.ts`
- `clones/paperclipai__paperclip/packages/db/src/schema/approvals.ts`
- `clones/paperclipai__paperclip/packages/db/src/schema/budget_policies.ts`
