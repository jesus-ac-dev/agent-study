---
tags: [knowledge, synthesis, ai-software, agente-estudo]
created: 2026-06-22
summary: Hermes Agent — agente real e completo; importar memória snapshot+batch, recall FTS5, toolsets gated, cron com wake-gate e relay por capacidades para o mem-vector.
agente: Hermes Agent
repo: NousResearch/hermes-agent
commit: e9b86f3
---

# Hermes Agent — estudo de source

> Veredito: agente real, grande e operacional, com loop de tools, memória, DB de sessões, cron, gateway/relay e subagentes. Estudado no commit e9b86f3.
> Vale importar padrões pequenos e robustos; não vale copiar a arquitectura inteira.

## Identidade
- O que é: agente pessoal/self-improving em Python, exposto por CLI/TUI/gateway/ACP, com tools, skills, memória, cron e subagentes. O núcleo é `AIAgent` em `clones/NousResearch__hermes-agent/run_agent.py:333`.
- Provider, linguagem, licença: Python `>=3.11,<3.14`, MIT, multi-provider via perfis/transports (`pyproject.toml`, `clones/NousResearch__hermes-agent/providers/base.py:38`, `clones/NousResearch__hermes-agent/agent/transports/base.py:16`).

## Anatomia (como faz cada coisa)
| Termo | Como o faz (`ficheiro`) | Força/Fraqueza | vs agente-autor simples |
|---|---|---|---|
| regressão/autoregressão | Autoregressivo: cada iteração envia histórico, recebe texto/tool_calls, executa tools e reinsere resultados (`clones/NousResearch__hermes-agent/agent/conversation_loop.py:589`, `clones/NousResearch__hermes-agent/agent/conversation_loop.py:3812`, `clones/NousResearch__hermes-agent/agent/conversation_loop.py:3988`). Regressão/treino online: não encontrado. | Força: ciclo defensivo com retries e reparação. Fraqueza: sem aprendizagem supervisionada integrada. | Melhor em robustez de loop; pior se o mem-vector só precisa escrever conhecimento e não executar muitos passos. |
| loop | `run_conversation` prepara turno, executa `while` até `max_iterations`/budget, trata tool calls, finais vazios, fallback e finalização (`clones/NousResearch__hermes-agent/agent/conversation_loop.py:495`, `clones/NousResearch__hermes-agent/agent/conversation_loop.py:589`, `clones/NousResearch__hermes-agent/agent/conversation_loop.py:4165`, `clones/NousResearch__hermes-agent/agent/turn_finalizer.py:30`). | Força: muita recuperação de falhas. Fraqueza: ficheiro/fluxo muito grande. | Melhor para agente geral; excessivo para agente-autor simples. |
| harness | CLI/gateway/TUI/ACP/cron. Gateway gere sessões e origem (`clones/NousResearch__hermes-agent/gateway/session.py:1`, `clones/NousResearch__hermes-agent/hermes_cli/subcommands/gateway.py:32`); ACP expõe Hermes via Agent Client Protocol (`clones/NousResearch__hermes-agent/acp_adapter/server.py:1`); TUI usa JSON-RPC e pool para handlers lentos (`clones/NousResearch__hermes-agent/tui_gateway/server.py:166`). | Força: muitas superfícies reais. Fraqueza: acoplamento operacional grande. | Mem-vector deve ter 1-2 harnesses claros, não todos. |
| memory | Duas camadas: built-in `MEMORY.md`/`USER.md` com snapshot congelado no prompt e writes duráveis (`clones/NousResearch__hermes-agent/tools/memory_tool.py:3`, `clones/NousResearch__hermes-agent/tools/memory_tool.py:113`, `clones/NousResearch__hermes-agent/tools/memory_tool.py:567`); providers externos por `MemoryProvider` (`clones/NousResearch__hermes-agent/agent/memory_provider.py:1`, `clones/NousResearch__hermes-agent/agent/memory_manager.py:335`). | Força: memória estável, cache-friendly, pluggable. Fraqueza: é memória curta/curada, não vault semântico completo. | Melhor que um agente-autor simples por separar snapshot, live state e provider hooks. |
| recall | Histórico em SQLite com FTS5/trigram (`clones/NousResearch__hermes-agent/hermes_state.py:611`, `clones/NousResearch__hermes-agent/hermes_state.py:636`, `clones/NousResearch__hermes-agent/hermes_state.py:3466`); tool `session_search` dá discovery/scroll/recent sem LLM (`clones/NousResearch__hermes-agent/tools/session_search_tool.py:1`, `clones/NousResearch__hermes-agent/tools/session_search_tool.py:394`). Vector/RAG embeddings: não encontrado no núcleo lido. | Força: recall barato, determinístico e auditável. Fraqueza: sem ranking semântico/vectorial. | Muito importável: mem-vector pode combinar isto com vector search. |
| context | Prompt em tiers stable/context/volatile para preservar prefix cache (`clones/NousResearch__hermes-agent/agent/system_prompt.py:1`, `clones/NousResearch__hermes-agent/agent/system_prompt.py:113`, `clones/NousResearch__hermes-agent/agent/system_prompt.py:470`); context files com prioridade (`clones/NousResearch__hermes-agent/agent/prompt_builder.py:1841`). Compressão por engine (`clones/NousResearch__hermes-agent/agent/context_engine.py:1`, `clones/NousResearch__hermes-agent/agent/conversation_compression.py:281`). | Força: disciplina de cache e compressão. Fraqueza: muita maquinaria. | Melhor para sessões longas; mem-vector deve importar só tiers + compressão auditável. |
| tools | Registry central com self-registering modules e toolsets (`clones/NousResearch__hermes-agent/tools/registry.py:1`, `clones/NousResearch__hermes-agent/tools/registry.py:77`, `clones/NousResearch__hermes-agent/toolsets.py:31`); schemas filtrados/cached por toolsets e progressive disclosure via tool_search (`clones/NousResearch__hermes-agent/model_tools.py:276`, `clones/NousResearch__hermes-agent/model_tools.py:519`). | Força: superfície controlável. Fraqueza: schema/toolset complexity alta. | Melhor que lista fixa de tools; importar versão pequena. |
| system prompt/kernel | Kernel montado uma vez por sessão: identidade, guidance de tools carregadas, skills, context files, memória, timestamp/model/provider (`clones/NousResearch__hermes-agent/agent/system_prompt.py:147`, `clones/NousResearch__hermes-agent/agent/system_prompt.py:187`, `clones/NousResearch__hermes-agent/agent/system_prompt.py:423`). | Força: kernel estável e explícito. Fraqueza: depende muito de prompt discipline. | Melhor; mem-vector precisa de kernel mais estreito e verificável. |
| skills | Skills são `SKILL.md`/`DESCRIPTION.md`, indexadas em prompt com cache em disco e LRU (`clones/NousResearch__hermes-agent/agent/prompt_builder.py:1334`, `clones/NousResearch__hermes-agent/agent/prompt_builder.py:1423`); prompt obriga `skill_view` para conteúdo relevante (`clones/NousResearch__hermes-agent/agent/prompt_builder.py:1563`). | Força: skills como memória procedimental. Fraqueza: risco de virar segundo vault paralelo. | Importar só skill index + carregamento progressivo; não duplicar conhecimento factual. |
| planning | Todo tool por sessão, in-memory, reinjectado após compressão (`clones/NousResearch__hermes-agent/tools/todo_tool.py:1`, `clones/NousResearch__hermes-agent/tools/todo_tool.py:106`); guidance para 3+ passos e um `in_progress` (`clones/NousResearch__hermes-agent/tools/todo_tool.py:240`). | Força: plano operacional leve. Fraqueza: não é planner formal. | Igual/melhor que agente-autor simples; importar como task scratchpad. |
| behavior | Comportamento vem de system prompt, schemas de tools e guardrails de tool-loop (`clones/NousResearch__hermes-agent/agent/system_prompt.py:173`, `clones/NousResearch__hermes-agent/agent/tool_guardrails.py:1`, `clones/NousResearch__hermes-agent/agent/tool_guardrails.py:63`). Policy DSL forte: não encontrado. | Força: pragmaticamente suficiente. Fraqueza: regras espalhadas por prompts/schemas/código. | Para mem-vector, concentrar comportamento em kernel + invariantes testáveis. |
| subagentes/orquestração | `delegate_task` cria child `AIAgent` isolado, sem memória/context files, com toolsets restritos e limite de profundidade/concurrency (`clones/NousResearch__hermes-agent/tools/delegate_tool.py:1`, `clones/NousResearch__hermes-agent/tools/delegate_tool.py:44`, `clones/NousResearch__hermes-agent/tools/delegate_tool.py:132`, `clones/NousResearch__hermes-agent/tools/delegate_tool.py:1219`). | Força: isolamento e summaries. Fraqueza: muita complexidade para coordenação. | Melhor para investigação paralela; mem-vector só precisa subagente de ingest/review se houver volume. |
| stop/terminação | Orçamento por agente/subagente (`clones/NousResearch__hermes-agent/agent/iteration_budget.py:17`), interrupção no loop (`clones/NousResearch__hermes-agent/agent/conversation_loop.py:593`), hard stops opcionais em guardrails (`clones/NousResearch__hermes-agent/agent/tool_guardrails.py:72`), finalização com razão de saída (`clones/NousResearch__hermes-agent/agent/turn_finalizer.py:174`). | Força: evita loops silenciosos. Fraqueza: muitas saídas especiais. | Importar budget + reason explícito; não importar todos os fallbacks. |
| verificação | Verifica mutações de ficheiros: executor regista resultados (`clones/NousResearch__hermes-agent/agent/tool_executor.py:697`), `AIAgent` mantém falhas por path (`clones/NousResearch__hermes-agent/run_agent.py:2529`) e finalizer acrescenta footer se o modelo reclamar edição que falhou (`clones/NousResearch__hermes-agent/agent/turn_finalizer.py:218`). Checkpoints antes de mutações (`clones/NousResearch__hermes-agent/tools/checkpoint_manager.py:1`). | Força: reduz overclaiming. Fraqueza: específico a ficheiros, não valida semântica. | Muito melhor que agente-autor simples; mem-vector deve verificar writes no vault/DB. |
| permissões/sandbox | File safety bloqueia reads/writes sensíveis e avisa que não é boundary (`clones/NousResearch__hermes-agent/agent/file_safety.py:28`, `clones/NousResearch__hermes-agent/agent/file_safety.py:148`, `clones/NousResearch__hermes-agent/agent/file_safety.py:171`); guards cross-profile e sandbox-mirror (`clones/NousResearch__hermes-agent/agent/file_safety.py:347`, `clones/NousResearch__hermes-agent/agent/file_safety.py:517`); ambientes terminal local/Docker/SSH/Singularity/Modal/Daytona (`clones/NousResearch__hermes-agent/tools/environments/__init__.py:1`). | Força: boa redução de footguns. Fraqueza: terminal pode contornar; não é segurança forte. | Importar deny/allow rules para vault; evitar prometer sandbox. |
| providers | Perfis declarativos por provider (`clones/NousResearch__hermes-agent/providers/base.py:38`), transports por `api_mode` (`clones/NousResearch__hermes-agent/agent/transports/base.py:1`), autodetecção OpenAI Codex/xAI/Anthropic/Bedrock (`clones/NousResearch__hermes-agent/agent/agent_init.py:317`) e router central (`clones/NousResearch__hermes-agent/agent/agent_init.py:617`). | Força: portabilidade. Fraqueza: provider quirks dominam o código. | Pior para mem-vector se o objectivo é estabilidade; escolher poucos providers. |
| tasks/daily/cron | Jobs em JSON/output markdown, tick com lock, at-most-once por avançar `next_run` antes de executar, `no_agent` e `wakeAgent=false` para poupar LLM (`clones/NousResearch__hermes-agent/cron/jobs.py:1`, `clones/NousResearch__hermes-agent/cron/scheduler.py:1`, `clones/NousResearch__hermes-agent/cron/scheduler.py:1615`, `clones/NousResearch__hermes-agent/cron/scheduler.py:1735`, `clones/NousResearch__hermes-agent/cron/scheduler.py:2425`). | Força: excelente para daily/tasks. Fraqueza: scheduler grande. | Importar contrato pequeno de jobs + wake-gate. |
| relay/gateway | Relay genérico: gateway liga para connector, recebe `CapabilityDescriptor`, troca eventos/acções normalizados por WS, sem endpoint inbound público (`clones/NousResearch__hermes-agent/gateway/relay/adapter.py:1`, `clones/NousResearch__hermes-agent/gateway/relay/transport.py:1`, `clones/NousResearch__hermes-agent/gateway/relay/descriptor.py:41`, `clones/NousResearch__hermes-agent/docs/relay-connector-contract.md:13`). | Força: separa plataforma de agente e mantém tokens no connector. Fraqueza: experimental. | Muito relevante para relay Claude↔Codex; importar contrato de capacidades, não implementação. |

## Pontos fortes (rankeados)
1. Memória estável: snapshot congelado no prompt, live writes duráveis e batch all-or-nothing (`clones/NousResearch__hermes-agent/tools/memory_tool.py:449`, `clones/NousResearch__hermes-agent/tools/memory_tool.py:567`).
2. Recall simples e auditável: SQLite FTS5/trigram + scroll/recent sem chamadas LLM (`clones/NousResearch__hermes-agent/hermes_state.py:611`, `clones/NousResearch__hermes-agent/tools/session_search_tool.py:394`).
3. Tool surface governada: registry, toolsets, discovery/caching e progressive disclosure (`clones/NousResearch__hermes-agent/model_tools.py:276`, `clones/NousResearch__hermes-agent/model_tools.py:519`).
4. Verificação pós-tool contra overclaiming de edições (`clones/NousResearch__hermes-agent/run_agent.py:2529`, `clones/NousResearch__hermes-agent/agent/turn_finalizer.py:218`).
5. Cron com gates operacionais reais: locks, at-most-once, `no_agent`, `wakeAgent=false` e timeouts por actividade (`clones/NousResearch__hermes-agent/cron/scheduler.py:1615`, `clones/NousResearch__hermes-agent/cron/scheduler.py:2091`, `clones/NousResearch__hermes-agent/cron/scheduler.py:2425`).
6. Relay por capacidades: connector segura tokens/capacidades e gateway só vê eventos/acções semânticas (`clones/NousResearch__hermes-agent/gateway/relay/transport.py:96`, `clones/NousResearch__hermes-agent/docs/relay-connector-contract.md:207`).
7. Guards de confusão de estado: cross-profile e sandbox-mirror são exactamente o tipo de bug que corrompe vaults (`clones/NousResearch__hermes-agent/agent/file_safety.py:347`, `clones/NousResearch__hermes-agent/agent/file_safety.py:517`).

## O que vale importar para o mem-vector
- [ ] P1: snapshot de memória congelado por turno/sessão + writes live duráveis — encaixa no kernel do vault para preservar cache e evitar que uma write mude o prompt a meio do raciocínio.
- [ ] P2: tool `memory` com operações batch add/replace/remove all-or-nothing — encaixa como API de escrita do vault/DB, com validação antes de commit.
- [ ] P3: recall híbrido “FTS5 primeiro, vector depois” — usar `session_search` como base determinística para chat/task history e só acrescentar embeddings onde FTS falha.
- [ ] P4: footer/verificador de mutações para vault/DB — após cada write, comparar operação pedida vs linhas/records realmente alterados e impedir respostas que alegam sucesso falso.
- [ ] P5: tiers de prompt stable/context/volatile — stable: identidade e regras do autor; context: ficheiros/project notes; volatile: snapshot de memória, daily/task state.
- [ ] P6: tool registry pequeno com toolsets (`memory`, `recall`, `tasks`, `relay`, `files`) — permite ligar/desligar capacidades por superfície sem mudar o kernel.
- [ ] P7: cron `no_agent`/`wakeAgent=false` — daily/tasks devem correr scripts/checks sem LLM quando possível, e só acordar o agente quando há novidade.
- [ ] P8: relay por `CapabilityDescriptor` — Claude↔Codex deve trocar envelopes de capacidades/acções, não tokens nem APIs internas de cada lado.
- [ ] P9: write-approval pendente para memória/skills de background — revisões autónomas devem propor alterações ao vault, não commitar factos duvidosos sem gate (`clones/NousResearch__hermes-agent/tools/write_approval.py:1`).
- [ ] P10: guards cross-profile/sandbox-mirror adaptados a vaults — bloquear escritas em vault errado, profile errado ou mirror que o processo principal não lê.

## Não importar / armadilhas
- Não importar a matriz completa de providers; para mem-vector aumenta superfície de bugs sem melhorar autoria de conhecimento.
- Não copiar o god-loop inteiro; o valor está nos contratos pequenos, não no fluxo de milhares de linhas.
- Não usar `MEMORY.md`/`USER.md` como substituto do vault vectorial; é bom como camada curada, insuficiente como RAG.
- Não duplicar conhecimento factual em skills; skills devem ser procedimentos, o vault/DB deve guardar factos e fontes.
- Não tratar file safety como sandbox forte; o próprio código diz que é defesa em profundidade e o terminal pode contornar (`clones/NousResearch__hermes-agent/agent/file_safety.py:171`).
- Não activar subagentes cedo; são úteis para ingest/review paralela, mas complicam proveniência e conflitos de escrita.
- Não importar kanban/gateway completo antes de ter um modelo de sessão simples; o custo operacional é alto.
- Não confiar em cron sem idempotência; importar também locks, claim/advance e dedupe, não só agendamento.
- Não pôr tokens/capacidades no agente-relay; usar o padrão `follow_up` sem token material no gateway (`clones/NousResearch__hermes-agent/gateway/relay/transport.py:96`).

## Fontes
- `clones/NousResearch__hermes-agent/pyproject.toml`
- `clones/NousResearch__hermes-agent/run_agent.py`
- `clones/NousResearch__hermes-agent/agent/conversation_loop.py`
- `clones/NousResearch__hermes-agent/agent/turn_context.py`
- `clones/NousResearch__hermes-agent/agent/turn_finalizer.py`
- `clones/NousResearch__hermes-agent/agent/iteration_budget.py`
- `clones/NousResearch__hermes-agent/agent/system_prompt.py`
- `clones/NousResearch__hermes-agent/agent/prompt_builder.py`
- `clones/NousResearch__hermes-agent/agent/context_engine.py`
- `clones/NousResearch__hermes-agent/agent/conversation_compression.py`
- `clones/NousResearch__hermes-agent/agent/memory_provider.py`
- `clones/NousResearch__hermes-agent/agent/memory_manager.py`
- `clones/NousResearch__hermes-agent/tools/memory_tool.py`
- `clones/NousResearch__hermes-agent/hermes_state.py`
- `clones/NousResearch__hermes-agent/tools/session_search_tool.py`
- `clones/NousResearch__hermes-agent/tools/registry.py`
- `clones/NousResearch__hermes-agent/model_tools.py`
- `clones/NousResearch__hermes-agent/toolsets.py`
- `clones/NousResearch__hermes-agent/tools/todo_tool.py`
- `clones/NousResearch__hermes-agent/tools/delegate_tool.py`
- `clones/NousResearch__hermes-agent/tools/write_approval.py`
- `clones/NousResearch__hermes-agent/agent/tool_executor.py`
- `clones/NousResearch__hermes-agent/agent/tool_guardrails.py`
- `clones/NousResearch__hermes-agent/agent/file_safety.py`
- `clones/NousResearch__hermes-agent/tools/checkpoint_manager.py`
- `clones/NousResearch__hermes-agent/tools/environments/base.py`
- `clones/NousResearch__hermes-agent/tools/environments/__init__.py`
- `clones/NousResearch__hermes-agent/providers/base.py`
- `clones/NousResearch__hermes-agent/agent/transports/base.py`
- `clones/NousResearch__hermes-agent/agent/agent_init.py`
- `clones/NousResearch__hermes-agent/cron/jobs.py`
- `clones/NousResearch__hermes-agent/cron/scheduler.py`
- `clones/NousResearch__hermes-agent/gateway/session.py`
- `clones/NousResearch__hermes-agent/gateway/relay/adapter.py`
- `clones/NousResearch__hermes-agent/gateway/relay/transport.py`
- `clones/NousResearch__hermes-agent/gateway/relay/descriptor.py`
- `clones/NousResearch__hermes-agent/docs/relay-connector-contract.md`
- `clones/NousResearch__hermes-agent/acp_adapter/server.py`
- `clones/NousResearch__hermes-agent/tui_gateway/server.py`


## Dimensões novas — Hermes Agent

| Termo | Como o faz (`ficheiro:linha`) | Força/Fraqueza | vs mem-vector |
|---|---|---|---|
| observability | Persiste ledger de sessões/mensagens com contadores de tool calls, tokens, cache, reasoning, custo e estado de handoff em `clones/NousResearch__hermes-agent/hermes_state.py:523` e `clones/NousResearch__hermes-agent/hermes_state.py:560`; actualiza tokens/custos por chamada em `clones/NousResearch__hermes-agent/agent/conversation_loop.py:1809` e `clones/NousResearch__hermes-agent/agent/conversation_loop.py:1879`; expõe histórico por MCP em `clones/NousResearch__hermes-agent/mcp_serve.py:568`; tem snapshots JSON opcionais em `clones/NousResearch__hermes-agent/run_agent.py:2290`; e tracing opt-in Langfuse via hooks em `clones/NousResearch__hermes-agent/plugins/observability/langfuse/plugin.yaml:3` e `clones/NousResearch__hermes-agent/plugins/observability/langfuse/__init__.py:1128`. | Forte em ledger local, custos/tokens e tracing plugável; fraco por não ser tracing obrigatório e por alguns logs/snapshots serem opt-in. | Importável para mem-vector como ledger mínimo de runs e custos antes de observability externa completa. |
| evidência/proveniência | ACP deriva `_meta.hermes.sessionProvenance` com `acpSessionId`, `currentHermesSessionId`, root, parent e profundidade de compressão em `clones/NousResearch__hermes-agent/acp_adapter/provenance.py:22` e `clones/NousResearch__hermes-agent/acp_adapter/provenance.py:92`; anexos ACP entram no prompt com nome e `URI` em `clones/NousResearch__hermes-agent/acp_adapter/server.py:197` e `clones/NousResearch__hermes-agent/acp_adapter/server.py:270`; sessões têm `source` em `clones/NousResearch__hermes-agent/hermes_state.py:523`. | Boa proveniência de sessão/anexo; fraca para factos individuais ou memórias, pois não há citação por afirmação. | Mem-vector deve importar provenance por facto/memória, não apenas por sessão. |
| evals/avaliação | Há live eval de Tool Search que corre um AIAgent real com ferramentas MCP falsas, cenários esperados, transcript completo, tool calls e comparação enabled/disabled em `clones/NousResearch__hermes-agent/scripts/tool_search_livetest.py:2`, `clones/NousResearch__hermes-agent/scripts/tool_search_livetest.py:210`, `clones/NousResearch__hermes-agent/scripts/tool_search_livetest.py:353` e `clones/NousResearch__hermes-agent/scripts/tool_search_livetest.py:421`; o analisador compara ferramentas esperadas, erros, iterações e custo de round-trips em `clones/NousResearch__hermes-agent/scripts/analyze_livetest.py:1` e `clones/NousResearch__hermes-agent/scripts/analyze_livetest.py:78`; há benchmark manual de browser eval em `clones/NousResearch__hermes-agent/scripts/benchmark_browser_eval.py:1`. | Forte como regression harness dirigido a capacidades; fraco porque não é uma suite geral de qualidade do agente nem LLM-as-judge amplo. | Mem-vector pode copiar o padrão de cenários esperados mais transcript, mas deve evitar confundir benchmarks de latência com avaliação de qualidade. |
| untrusted-input | Trata comandos do LLM como input hostil no smart-approval, remove comentários e delimita em `<command>` com instrução para ignorar directivas embebidas em `clones/NousResearch__hermes-agent/tools/approval.py:1136` e `clones/NousResearch__hermes-agent/tools/approval.py:1142`; bloqueia bypass de aprovações por env mutável em `clones/NousResearch__hermes-agent/tools/approval.py:28`; bloqueia SSRF e metadata endpoints em `clones/NousResearch__hermes-agent/tools/url_safety.py:1`, `clones/NousResearch__hermes-agent/tools/url_safety.py:317` e `clones/NousResearch__hermes-agent/tools/url_safety.py:368`; detecta padrões de prompt injection em skills em `clones/NousResearch__hermes-agent/tools/skills_tool.py:163` e avisa ao carregar fora de dirs confiáveis em `clones/NousResearch__hermes-agent/tools/skills_tool.py:1133`. | Forte em comandos, URL/network e skill warnings; fraco porque o scanner de skills é heurístico e avisa em vez de isolar sempre. | Mem-vector deve importar a separação explícita “conteúdo recuperado é untrusted” e guardas SSRF se fizer fetch remoto. |
| human-steering | Suporta interrupção mid-run a partir de outra thread/mensagem e propaga para tools/children em `clones/NousResearch__hermes-agent/run_agent.py:2376`; suporta `/steer` sem interromper, guardado com lock e drenado no próximo resultado de tool em `clones/NousResearch__hermes-agent/run_agent.py:2477` e `clones/NousResearch__hermes-agent/run_agent.py:2513`; approvals de comandos perigosos têm estados once/session/always/deny em `clones/NousResearch__hermes-agent/tools/approval.py:1679`; ACP edit approvals pedem `allow_once` ou `deny` em `clones/NousResearch__hermes-agent/acp_adapter/edit_approval.py:237`; MCP expõe `permissions_respond` com `allow-once`, `allow-always`, `deny` em `clones/NousResearch__hermes-agent/mcp_serve.py:846`. | Forte em steering assíncrono e aprovações por superfície; fraco por ter vários caminhos de approval com semânticas diferentes. | Mem-vector pode adoptar steering simples e fila de aprovações, mas deve manter uma política única para evitar divergência UX. |
| concorrência/multi-sessão | `SessionDB` é thread-safe para leitores concorrentes e um escritor via WAL em `clones/NousResearch__hermes-agent/hermes_state.py:667`; writes usam `BEGIN IMMEDIATE` com retry/jitter contra lock contention em `clones/NousResearch__hermes-agent/hermes_state.py:928`; compressão tem lock por `session_id` para evitar forks órfãos em `clones/NousResearch__hermes-agent/hermes_state.py:1422` e `clones/NousResearch__hermes-agent/hermes_state.py:1440`; leases cross-process de sessões activas usam file lock e pruning em `clones/NousResearch__hermes-agent/hermes_cli/active_sessions.py:92` e `clones/NousResearch__hermes-agent/hermes_cli/active_sessions.py:234`; gateway tem runtime lock/PID race guard em `clones/NousResearch__hermes-agent/gateway/status.py:529` e `clones/NousResearch__hermes-agent/gateway/status.py:587`; handoff é claim atómico pending→running em `clones/NousResearch__hermes-agent/hermes_state.py:5074`. | Muito forte para multi-superfície e multi-processo; complexidade alta e várias locks podem ser pesadas para agentes pequenos. | Mem-vector deve importar só locks por recurso partilhado e retries SQLite se tiver múltiplas sessões reais. |

### Importar (só destas 6 dimensões; se nada valer, escreve "nada")
- [ ] Ledger de runs/sessões com mensagens, tool calls, tokens e custo — dá auditoria mínima; encaixa no storage principal de execuções/memórias.
- [ ] Provenance por memória/facto inspirada no ACP `sessionProvenance`, mas mais granular — encaixa na escrita/actualização de memórias.
- [ ] Harness de eval com cenários esperados e transcripts — encaixa em regressão de retrieval, escrita de memória e uso de tools.
- [ ] Guardas de untrusted input para comandos, URLs e docs recuperados — encaixa antes de executar tools e antes de promover conteúdo externo a memória.
- [ ] Steering simples: interrupt + approve/deny + comentário mid-run — encaixa na UI/API de runs activos.
- [ ] Lock por sessão/recurso partilhado com claim atómico — encaixa quando houver múltiplas sessões a escrever no mesmo índice/DB.

### Não importar / armadilhas (destas 6)
- Não importar Langfuse/tracing externo como dependência obrigatória; manter opt-in.
- Não copiar todos os locks/leases se mem-vector ainda não tiver multi-processo real.
- Não tratar provenance de sessão como suficiente para memória: é preciso fonte por facto.
- Não confundir live eval estreito ou benchmark de browser com avaliação geral de qualidade.
- Não depender só de heurísticas de prompt-injection em texto; combinar com fronteiras de confiança e permissões.
