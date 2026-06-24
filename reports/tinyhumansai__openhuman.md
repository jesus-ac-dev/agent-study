---
tags: [knowledge, synthesis, ai-software, agente-estudo]
created: 2026-06-22
summary: OpenHuman — agente pessoal real e ambicioso; vale importar sobretudo o substrate de memória híbrida, o harness com guardrails, e o modelo de tasks/recall, não a complexidade completa.
agente: OpenHuman
repo: tinyhumansai/openhuman
commit: 7f5a746
---

# OpenHuman — estudo de source

> Veredito: É um agente real, não uma demo: Rust core com Tauri/React, memória local, tools, subagentes, scheduler e múltiplos providers. Para o mem-vector, o valor está na arquitectura de memória/recall/tasks e no harness defensivo, não na UI nem na matriz inteira de subagentes. Estudado no commit 7f5a746.

## Identidade
- OpenHuman é um agente pessoal local-first com vault/memória, execução de tools, subagentes e scheduler; o core Rust expõe a lógica de agente e RPC (`Cargo.toml:1`, `src/openhuman/agent/mod.rs:1`).
- Providers: OpenHuman Cloud/BYOK, Anthropic/Claude Code, Ollama, LM Studio, MLX e OpenAI-compatible (`src/openhuman/inference/provider/factory.rs:1`). Linguagem principal: Rust, com UI Tauri/React (`package.json:1`, `package.json:69`). Licença: GPL-3.0 (`LICENSE:1`).

## Anatomia (como faz cada coisa)
| Termo | Como o faz (`ficheiro`) | Força/Fraqueza | vs agente-autor simples |
|---|---|---|---|
| regressão/autoregressão | Autoregressão via `ChatRequest { messages, tools, stream }` e chamadas repetidas a `provider.chat` dentro do loop (`src/openhuman/inference/provider/traits.rs:145`, `src/openhuman/agent/harness/engine/core.rs:525`). Regressão ML/treino não encontrado; há harnesses/testes de regressão funcional, como `inference_probe` (`src/bin/inference_probe.rs:1`). | Força: separa request/response/tool calls. Fraqueza: não é sistema de aprendizagem por regressão. | Melhor no controlo de turnos e tools; irrelevante se o agente-autor só precisa de chat + RAG simples. |
| loop | `run_turn_engine` é o loop principal: stop hooks, context guard, request ao provider, parsing, final text ou tool calls, circuit breakers e checkpoint (`src/openhuman/agent/harness/engine/core.rs:1`, `src/openhuman/agent/harness/engine/core.rs:189`). | Força: loop explícito e defensivo. Fraqueza: muita superfície para manter. | Melhor que um loop simples por ter limites, persistência e recuperação; pior em custo cognitivo. |
| harness | `Agent::turn` prepara prompt, memória, tools, parser, observer e checkpoint antes de chamar o engine (`src/openhuman/agent/harness/session/turn/core.rs:48`, `src/openhuman/agent/harness/session/turn/core.rs:453`). `inference_probe` compara harness real com probe raw (`src/bin/inference_probe.rs:85`). | Força: bom isolamento entre sessão, provider e execução de tools. | Muito melhor para produto; um agente-autor simples pode importar só a interface `provider + tool_source + checkpoint`. |
| memory | `UnifiedMemory` cria SQLite WAL com docs, KV global/namespace, graph, vector chunks, FTS5, segments, events e profile (`src/openhuman/memory_store/unified/init.rs:1`, `src/openhuman/memory_store/unified/init.rs:83`). Docs têm sidecar Markdown em `memory/namespaces/<ns>/docs/` (`src/openhuman/memory_store/unified/documents.rs:1`). | Força: substrate rico e auditável. Fraqueza: esquema grande, com migrações e muitos modos. | Melhor que só vector DB; para mem-vector, importar a tríade SQLite + Markdown + embeddings, não tudo. |
| recall | Retrieval híbrido por graph, vector, keyword, episodic signal e freshness (`src/openhuman/memory_store/unified/query.rs:1`, `src/openhuman/memory_store/unified/query.rs:21`). `MemoryLoader` injecta working memory, prior conversations e cross-chat com thresholds/proveniência (`src/openhuman/agent_memory/memory_loader.rs:151`, `src/openhuman/agent_memory/memory_loader.rs:361`). | Força: recall com ranking plural e contexto datado. Fraqueza: heurístico e potencialmente caro. | Melhor que RAG vector-only; importar scoring híbrido simples e citações, não a planner inteira. |
| context | `ContextManager` monta prompt, reduz contexto mecanicamente e faz sumarização; o system prompt é construído uma vez para prefix cache (`src/openhuman/context/manager.rs:1`, `src/openhuman/context/manager.rs:256`). Turno injecta datetime e blocos de memória no user message (`src/openhuman/agent/harness/session/turn/core.rs:266`, `src/openhuman/agent/harness/session/turn/core.rs:431`). | Força: separa kernel estável de contexto dinâmico. | Melhor que reconstruir tudo por turno; ideal para mem-vector manter prompt estável e recall por blocos. |
| tools | `Tool` define schema, scope, categoria, permissões, efeitos externos, concorrência e limites de output (`src/openhuman/tools/traits.rs:9`, `src/openhuman/tools/traits.rs:122`). O registry exporta memory, todos, workflows, cron, MCP, artifacts e mais (`src/openhuman/tools/mod.rs:14`). | Força: contrato claro por tool. Fraqueza: registry enorme. | Melhor no contract; agente-autor simples deve copiar a forma, não a quantidade. |
| system prompt/kernel | `SystemPromptBuilder` compõe Identity, UserFiles, UserMemory, Tools, Safety, Workspace, DateTime e Runtime (`src/openhuman/agent/prompts/builder.rs:16`). Subagentes usam prompt estreito e omitem DateTime para cache (`src/openhuman/agent/prompts/builder.rs:56`). | Força: kernel modular e cache-aware. | Melhor que prompt monolítico; importar secções explícitas e freeze por sessão. |
| skills | A injecção directa de `SKILL.md` no histórico foi removida; usa catálogo compacto e `run_skill` em worker isolado (`src/openhuman/agent/harness/session/turn/core.rs:349`). Workflows têm tools para listar/descrever/ler recursos e install mutável default-off (`src/openhuman/workflows/tools.rs:1`). | Força: skills como capacidade invocável, não contexto bruto. | Melhor que despejar docs no prompt; mem-vector deve tratar skills como recursos consultáveis. |
| planning | `todowrite`, `update_task` e `plan_exit` mantêm board, estado, plano, evidência e saída de plan mode (`src/openhuman/agent/tools/todo.rs:1`, `src/openhuman/agent/tools/update_task.rs:1`, `src/openhuman/agent/tools/plan_exit.rs:1`). | Força: planeamento vira estado persistente. Fraqueza: plan mode ainda tem nota de integração futura em `plan_exit`. | Melhor que checklist em chat; importar board persistente com evidência/aceitação. |
| behavior | O comportamento é data-driven em `agent.toml`: orchestrator como router, memória on-demand, allowlist de subagentes e tools directas (`src/openhuman/agent_registry/agents/orchestrator/agent.toml:1`, `src/openhuman/agent_registry/agents/orchestrator/agent.toml:26`). | Força: comportamento configurável sem recompilar. | Melhor que hardcode; para mem-vector basta perfis pequenos e auditáveis. |
| subagentes/orquestração | `AgentDefinition` define tier, prompt, tools, sandbox, limite de iterações e hierarquia (`src/openhuman/agent/harness/definition.rs:1`, `src/openhuman/agent/harness/definition.rs:230`). Runner filtra tools, resolve provider/model e limita profundidade (`src/openhuman/agent/harness/subagent_runner/ops/runner.rs:40`, `src/openhuman/agent/harness/subagent_runner/ops/runner.rs:265`). | Força: delegação governada. Fraqueza: muitos agentes e caminhos especiais. | Melhor para suite completa; pior para agente-autor inicial. Importar só 2-3 papéis. |
| stop/terminação | Stop hooks por orçamento e max iterations (`src/openhuman/agent/stop_hooks.rs:1`, `src/openhuman/agent/stop_hooks.rs:99`), repeat-output e repeat-failure guards no loop (`src/openhuman/agent/harness/engine/core.rs:718`, `src/openhuman/agent/harness/engine/core.rs:814`). | Força: terminações explícitas e fail-closed. | Muito melhor que confiar no modelo; importar quase directo. |
| verificação | `inference_probe` testa tool calls por harness ou raw provider (`src/bin/inference_probe.rs:1`). Scripts de teste Rust/E2E existem em `package.json:25`. | Força: permite comparar provider, grammar e harness. Fraqueza: verificação é dispersa. | Melhor que nada; mem-vector deve ter probe mínimo de recall/tool loop. |
| permissões/sandbox | `SecurityPolicy` separa workspace/action dir, trusted roots, autonomia e bloqueios de dirs internos (`src/openhuman/security/policy/types.rs:26`, `src/openhuman/security/policy/types.rs:169`). `ShellTool` classifica comandos, limpa env, limita output/timeout e usa sandbox quando activo (`src/openhuman/tools/impl/system/shell.rs:204`, `src/openhuman/tools/impl/system/shell.rs:289`). | Força: threat model sério. Fraqueza: complexo, dependente de muitos casos. | Melhor que um agente-autor simples; importar action dir, env allowlist, output caps e markers. |
| providers | Factory resolve providers por papel: chat, reasoning, agentic, coding, vision, memory, embeddings, heartbeat, learning e subconscious (`src/openhuman/inference/provider/factory.rs:213`). Suporta OpenHuman, Anthropic/Claude Code, Ollama, LM Studio, MLX e OpenAI-compatible (`src/openhuman/inference/provider/factory.rs:482`). | Força: routing flexível por capacidade. Fraqueza: muita configuração. | Melhor que provider único; mem-vector deve ficar com adapter simples por papel. |
| tasks/daily | Task sources fazem fetch/dedup/enrich/route para todo board (`src/openhuman/task_sources/pipeline.rs:1`). Poller despacha cards por capacidade e urgência (`src/openhuman/agent/task_dispatcher/poller.rs:1`). Cron tem morning briefing e mensagens de erro sanitizadas (`src/openhuman/cron/scheduler.rs:18`, `src/openhuman/cron/scheduler.rs:28`). | Força: transforma integrações em trabalho persistente. Fraqueza: background autonomy exige política forte. | Melhor que tarefas soltas no chat; importar a pipeline em versão menor. |
| relay Claude↔Codex | Providers Claude/Claude Code e OpenAI-compatible existem (`src/openhuman/inference/provider/factory.rs:565`, `src/openhuman/inference/provider/factory.rs:1`), mas relay explícito Claude↔Codex não encontrado. | Fraqueza para o caso mem-vector relay: não há padrão pronto. | Pior que implementar relay dedicado com envelopes e logs próprios. |
| observability | Emite eventos de progresso por turno, incluindo tool start/complete, subagentes e custo/tokens (`clones/tinyhumansai__openhuman/src/openhuman/agent/progress.rs:16`, `clones/tinyhumansai__openhuman/src/openhuman/agent/progress.rs:31`, `clones/tinyhumansai__openhuman/src/openhuman/agent/progress.rs:244`); persiste transcripts JSONL/MD com metadados de tokens/custo/thread (`clones/tinyhumansai__openhuman/src/openhuman/agent/harness/session/transcript.rs:1`, `clones/tinyhumansai__openhuman/src/openhuman/agent/harness/session/transcript.rs:33`, `clones/tinyhumansai__openhuman/src/openhuman/agent/harness/session/turn/session_io.rs:163`); mantém run-ledger SQLite para runs/eventos/telemetria (`clones/tinyhumansai__openhuman/src/openhuman/session_db/run_ledger/store.rs:6`, `clones/tinyhumansai__openhuman/src/openhuman/session_db/run_ledger/store.rs:50`, `clones/tinyhumansai__openhuman/src/openhuman/session_db/run_ledger/store.rs:60`) e audit log estruturado (`clones/tinyhumansai__openhuman/src/openhuman/security/audit.rs:70`, `clones/tinyhumansai__openhuman/src/openhuman/security/audit.rs:175`). | Forte: execução visível em tempo real e persistente; fraqueza: transcripts são best-effort e não substituem sempre o store autoritativo. | Mais completo que mem-vector: cobre execução, custos, runs e auditoria, não só memória. |
| evidência/proveniência | Retrieval devolve `RetrievalHit` com `node_id`, `tree_id`, `tree_scope` e `source_ref` para folhas (`clones/tinyhumansai__openhuman/src/openhuman/memory_tree/retrieval/types.rs:47`, `clones/tinyhumansai__openhuman/src/openhuman/memory_tree/retrieval/types.rs:60`, `clones/tinyhumansai__openhuman/src/openhuman/memory_tree/retrieval/types.rs:74`, `clones/tinyhumansai__openhuman/src/openhuman/memory_tree/retrieval/types.rs:146`); o prompt do orchestrator exige footnotes com `node_id` e `source_ref` (`clones/tinyhumansai__openhuman/src/openhuman/agent_registry/agents/orchestrator/prompt.md:160`, `clones/tinyhumansai__openhuman/src/openhuman/agent_registry/agents/orchestrator/prompt.md:164`, `clones/tinyhumansai__openhuman/src/openhuman/agent_registry/agents/orchestrator/prompt.md:172`); ferramentas WhatsApp devolvem tag `provider` (`clones/tinyhumansai__openhuman/src/openhuman/whatsapp_data/tools/list_messages.rs:27`, `clones/tinyhumansai__openhuman/src/openhuman/whatsapp_data/tools/list_messages.rs:91`). | Boa em memória/retrieval; fraqueza: `source_ref` é `None` em summaries e a citação depende do prompt, não de um renderer obrigatório. | Mais rastreável que mem-vector quando há retrieval hit; ainda parcial fora das memórias/ferramentas instrumentadas. |
| evals/avaliação | não encontrado | Há benchmarks de performance de retrieval (`clones/tinyhumansai__openhuman/src/openhuman/agent_memory/ops.rs:1`, `clones/tinyhumansai__openhuman/src/openhuman/agent_memory/types.rs:33`), mas não encontrei datasets de qualidade, regressão de agente ou LLM-as-judge. | Pior que mem-vector se este tiver evals; aqui há testes/benchmarks, não avaliação sistemática da qualidade do agente. |
| untrusted-input | Guarda de prompt-injection normaliza/scora inputs e bloqueia/review-block (`clones/tinyhumansai__openhuman/src/openhuman/prompt_injection/detector.rs:48`, `clones/tinyhumansai__openhuman/src/openhuman/prompt_injection/detector.rs:488`), aplicada antes de `run_single` e em ingress web (`clones/tinyhumansai__openhuman/src/openhuman/agent/harness/session/runtime.rs:480`, `clones/tinyhumansai__openhuman/src/openhuman/channels/providers/web/ops.rs:203`); também faz scan de definições de tools remotas (`clones/tinyhumansai__openhuman/src/openhuman/prompt_injection/detector.rs:440`); URL guard bloqueia hosts privados/locais, allowlist estrita e DNS rebinding (`clones/tinyhumansai__openhuman/src/openhuman/tools/impl/network/url_guard.rs:1`, `clones/tinyhumansai__openhuman/src/openhuman/tools/impl/network/url_guard.rs:51`, `clones/tinyhumansai__openhuman/src/openhuman/tools/impl/network/url_guard.rs:92`, `clones/tinyhumansai__openhuman/src/openhuman/tools/impl/browser/browser.rs:267`). | Forte e explícito; fraqueza: regex/heurística pode ter falsos positivos/negativos e a cobertura total de todos os canais externos não é provada só por estes pontos. | Mais defensivo que mem-vector se este apenas separa recall; aqui há fronteira activa para prompt, tool metadata e rede. |
| human-steering | ApprovalGate intercepta tools com efeito externo, persiste `pending_approvals`, publica evento e estaciona em `oneshot` até decisão (`clones/tinyhumansai__openhuman/src/openhuman/approval/gate.rs:1`, `clones/tinyhumansai__openhuman/src/openhuman/approval/gate.rs:12`, `clones/tinyhumansai__openhuman/src/openhuman/approval/gate.rs:436`, `clones/tinyhumansai__openhuman/src/openhuman/approval/gate.rs:500`, `clones/tinyhumansai__openhuman/src/openhuman/approval/gate.rs:671`); decisões são approve once/always/deny (`clones/tinyhumansai__openhuman/src/openhuman/approval/types.rs:72`); `steer_subagent` injecta mensagens em subagentes em execução (`clones/tinyhumansai__openhuman/src/openhuman/agent_orchestration/tools/steer_subagent.rs:1`, `clones/tinyhumansai__openhuman/src/openhuman/agent_orchestration/tools/steer_subagent.rs:36`, `clones/tinyhumansai__openhuman/src/openhuman/agent_orchestration/tools/steer_subagent.rs:148`) e o command center suporta stop/retry/continue/follow_up (`clones/tinyhumansai__openhuman/src/openhuman/agent_orchestration/command_center/control.rs:1`, `clones/tinyhumansai__openhuman/src/openhuman/agent_orchestration/command_center/control.rs:40`). | Muito forte: aprovação, negação, timeout fail-closed, steering e controlo durável; fraqueza: alguns contextos CLI/trusted automation passam sem prompt. | Mais rico que mem-vector: é steering operacional, não só configuração inicial. |
| concorrência/multi-sessão | RunQueue partilhada por `Arc<Mutex<...>>` separa steers/followups/collects e drena em pontos seguros (`clones/tinyhumansai__openhuman/src/openhuman/agent/harness/run_queue/mod.rs:1`, `clones/tinyhumansai__openhuman/src/openhuman/agent/harness/run_queue/mod.rs:22`, `clones/tinyhumansai__openhuman/src/openhuman/agent/harness/run_queue/mod.rs:43`, `clones/tinyhumansai__openhuman/src/openhuman/agent/harness/run_queue/mod.rs:63`); running-subagents tem registry global com ownership por `parent_session` (`clones/tinyhumansai__openhuman/src/openhuman/agent_orchestration/running_subagents.rs:1`, `clones/tinyhumansai__openhuman/src/openhuman/agent_orchestration/running_subagents.rs:15`, `clones/tinyhumansai__openhuman/src/openhuman/agent_orchestration/running_subagents.rs:77`, `clones/tinyhumansai__openhuman/src/openhuman/agent_orchestration/running_subagents.rs:196`); agentes paralelos podem isolar escrita em git worktrees e detectar overlaps (`clones/tinyhumansai__openhuman/src/openhuman/agent_orchestration/tools/spawn_parallel_agents.rs:39`, `clones/tinyhumansai__openhuman/src/openhuman/agent_orchestration/tools/spawn_parallel_agents.rs:92`, `clones/tinyhumansai__openhuman/src/openhuman/agent_orchestration/tools/spawn_parallel_agents.rs:603`, `clones/tinyhumansai__openhuman/src/openhuman/agent_orchestration/worktree.rs:1`, `clones/tinyhumansai__openhuman/src/openhuman/agent_orchestration/worktree.rs:413`); task claiming/completion usa CAS em SQLite (`clones/tinyhumansai__openhuman/src/openhuman/session_db/run_ledger/ops.rs:912`, `clones/tinyhumansai__openhuman/src/openhuman/session_db/run_ledger/ops.rs:1022`). | Forte: há filas, ownership, CAS e isolamento opcional; fraqueza: worktree não é automático e modo `none` ainda partilha workspace. | Mais maduro que mem-vector: resolve concorrência de execução e escrita, não apenas estado de memória. |

## Pontos fortes (rankeados)
1. Memória híbrida persistente: SQLite + Markdown sidecars + graph + vector chunks + FTS/eventos (`src/openhuman/memory_store/unified/init.rs:83`, `src/openhuman/memory_store/unified/documents.rs:90`).
2. Harness de turno robusto, com checkpoint, guards, tool execution e contexto budgetado (`src/openhuman/agent/harness/engine/core.rs:180`).
3. Recall pragmático: mistura sinais sem depender só de embeddings (`src/openhuman/memory_store/unified/query.rs:132`).
4. Tasks como estado operacional, não só plano textual (`src/openhuman/todos/ops.rs:181`).
5. Segurança concreta para tools/shell: action dir, env limpa, sandbox e bloqueio de memória interna (`src/openhuman/tools/impl/system/shell.rs:289`, `src/openhuman/security/policy/types.rs:169`).
6. Subagentes definidos por dados, com hierarquia e tool scopes (`src/openhuman/agent/harness/definition.rs:197`).

## O que vale importar para o mem-vector
- [ ] 1. Substrate de memória SQLite + Markdown + vector chunks + FTS — dá vault legível por humanos e DB consultável por agente (`src/openhuman/memory_store/unified/init.rs:61`, `src/openhuman/memory_store/unified/documents.rs:90`).
- [ ] 2. Recall híbrido com citações, thresholds e provenance — encaixa no RAG/chat do mem-vector e reduz falso contexto (`src/openhuman/agent_memory/memory_loader.rs:85`, `src/openhuman/memory_store/unified/query.rs:350`).
- [ ] 3. Separação entre prompt estável e contexto injectado por turno — melhora cache, auditabilidade e previsibilidade (`src/openhuman/context/manager.rs:256`, `src/openhuman/agent/harness/session/turn/core.rs:431`).
- [ ] 4. Tool contract com `PermissionLevel`, `external_effect` e limites de output — essencial para um agente-autor que mexe em vault/DB (`src/openhuman/tools/traits.rs:63`, `src/openhuman/tools/traits.rs:230`).
- [ ] 5. Stop hooks + repeat-failure guards — importar quase literalmente como política de terminação (`src/openhuman/agent/stop_hooks.rs:99`, `src/openhuman/agent/harness/tool_loop.rs:189`).
- [ ] 6. Board de tasks com plano, acceptance, evidence e blocker — serve para daily/tasks e para relay humano↔agentes (`src/openhuman/todos/ops.rs:84`, `src/openhuman/todos/ops.rs:181`).
- [ ] 7. Task-source pipeline fetch/dedup/enrich/route — bom modelo para transformar GitHub/Notion/Linear em memória e acções (`src/openhuman/task_sources/pipeline.rs:111`).
- [ ] 8. Subagentes mínimos por definição declarativa — importar só `planner`, `memory/researcher` e `executor`, com tool allowlists (`src/openhuman/agent_registry/agents/planner/agent.toml:1`, `src/openhuman/agent/harness/definition.rs:129`).
- [ ] 9. Probe de inferência raw vs harness — útil para testar providers, tool schemas e regressões de loop (`src/bin/inference_probe.rs:85`).
- [ ] Run-ledger com `run_events` e `run_telemetry` — dá replay/auditoria mínima de execuções e encaixa no plano de observability sem depender de logs textuais.
- [ ] `source_ref` obrigatório em hits citáveis — melhora proveniência por facto; encaixa no output de retrieval/memória.
- [ ] ApprovalGate com approve-once/always/deny e timeout fail-closed — bom padrão para human-steering em tools com efeito externo.
- [ ] Worktree opcional + overlap warnings para workers paralelos — encaixa em concorrência/multi-sessão quando houver agentes que escrevem ficheiros.

## Não importar / armadilhas
- Não copiar a matriz completa de subagentes; é pesada para um agente-autor inicial e aumenta bugs de routing (`src/openhuman/agent_registry/agents/loader.rs:60`).
- Não importar UI/Tauri, Composio ou integrações todas de uma vez; não são o core de mem-vector (`src/openhuman/tools/mod.rs:14`).
- Não reintroduzir injecção directa de `SKILL.md` no histórico; o próprio código indica que foi removida em favor de catálogo + worker (`src/openhuman/agent/harness/session/turn/core.rs:349`).
- Não activar background autonomy com egress amplo sem gate forte; há threat model explícito para cards externos (`src/openhuman/agent/task_dispatcher/executor.rs:115`, `src/openhuman/agent/task_dispatcher/executor.rs:132`).
- Não copiar código GPL para um projecto com licença incompatível; a licença é GPL-3.0 (`LICENSE:1`).
- Não assumir que isto resolve relay Claude↔Codex; relay explícito não encontrado.
- Não adoptar retrieval vector brute-force sem limites; o código faz guard por assinatura/dimensão, mas o scoring pode escalar mal sem índice ANN (`src/openhuman/memory_store/unified/query.rs:551`).
- Não confundir benchmarks de retrieval com evals de qualidade do agente.
- Não depender só de prompt para citações; se a citação é obrigatória, o renderer/schema deve forçá-la.
- Worktree opcional deixa o modo partilhado exposto a colisões; auto-isolamento ou gate explícito seria mais seguro.
- Regex de prompt-injection é útil, mas não substitui separação estrutural entre conteúdo externo e instruções do sistema.

## Fontes
- `Cargo.toml`
- `package.json`
- `LICENSE`
- `src/openhuman/agent/mod.rs`
- `src/openhuman/agent/harness/engine/core.rs`
- `src/openhuman/agent/harness/session/turn/core.rs`
- `src/openhuman/agent/harness/tool_loop.rs`
- `src/openhuman/agent/stop_hooks.rs`
- `src/openhuman/agent/prompts/builder.rs`
- `src/openhuman/context/manager.rs`
- `src/openhuman/memory/mod.rs`
- `src/openhuman/agent_memory/memory_loader.rs`
- `src/openhuman/memory/preferences.rs`
- `src/openhuman/memory_store/unified/init.rs`
- `src/openhuman/memory_store/unified/documents.rs`
- `src/openhuman/memory_store/unified/query.rs`
- `src/openhuman/memory_store/chunks/semantic.rs`
- `src/openhuman/memory_tree/ingest.rs`
- `src/openhuman/memory_tree/tree_runtime/engine.rs`
- `src/openhuman/tools/traits.rs`
- `src/openhuman/tools/mod.rs`
- `src/openhuman/memory/tools/recall.rs`
- `src/openhuman/security/policy/types.rs`
- `src/openhuman/security/policy/enforcement.rs`
- `src/openhuman/security/policy/policy_command.rs`
- `src/openhuman/tools/impl/system/shell.rs`
- `src/openhuman/inference/provider/factory.rs`
- `src/openhuman/inference/provider/traits.rs`
- `src/openhuman/agent/harness/definition.rs`
- `src/openhuman/agent_registry/agents/orchestrator/agent.toml`
- `src/openhuman/agent_registry/agents/planner/agent.toml`
- `src/openhuman/agent_registry/agents/loader.rs`
- `src/openhuman/agent/harness/subagent_runner/ops/runner.rs`
- `src/openhuman/agent/harness/subagent_runner/ops/loop_.rs`
- `src/openhuman/agent/tools/todo.rs`
- `src/openhuman/agent/tools/update_task.rs`
- `src/openhuman/agent/tools/plan_exit.rs`
- `src/openhuman/todos/ops.rs`
- `src/openhuman/task_sources/types.rs`
- `src/openhuman/task_sources/pipeline.rs`
- `src/openhuman/agent/task_dispatcher/poller.rs`
- `src/openhuman/agent/task_dispatcher/executor.rs`
- `src/openhuman/cron/scheduler.rs`
- `src/openhuman/workflows/tools.rs`
- `src/bin/inference_probe.rs`
