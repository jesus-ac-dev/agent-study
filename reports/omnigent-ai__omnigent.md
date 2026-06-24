---
tags: [knowledge, synthesis, ai-software, agente-estudo]
created: 2026-06-22
summary: Omnigent — runtime/meta-harness real para agentes; vale importar compactação em camadas, sessões-subagente e políticas, não a plataforma inteira.
agente: Omnigent
repo: omnigent-ai/omnigent
commit: 992a458
---

# Omnigent — estudo de source

> Veredito: É um framework/meta-harness de agentes real, não um agente único; a anatomia útil está no runtime, specs YAML, harnesses, políticas, sandbox e sub-sessões. Estudado no commit 992a458.

## Identidade
- Framework open-source de authoring/runtime para agentes, com CLI, servidor FastAPI, runner e UI; orquestra Claude Code, Codex, Cursor, Pi, OpenAI Agents e agentes YAML (`pyproject.toml`, `omnigent/runtime/harnesses/_scaffold.py:1`, `omnigent/spec/parser.py:114`).
- Provider multi-model por prefixo (`openai`, `anthropic`, `gemini`, `bedrock`, `vertex`, `databricks`, `groq`, `deepseek`, `xai`, `openrouter`, `ollama`, `moonshot`) em Python 3.12+, licença Apache-2.0 (`omnigent/llms/routing.py:15`, `pyproject.toml`, `LICENSE`).

## Anatomia (como faz cada coisa)
| Termo | Como o faz (`ficheiro`) | Força/Fraqueza | vs agente-autor simples |
|---|---|---|---|
| regressão/autoregressão | Usa LLMs autoregressivos via interface Responses; OpenAI fica nativo, outros providers são convertidos para chat completions (`omnigent/llms/client.py:73`, `omnigent/llms/client.py:181`, `omnigent/llms/client.py:206`). Regressão estatística: não encontrado. | Força: router unifica providers; fraqueza: muita compatibilidade de adapters. | Melhor em portabilidade; pior em simplicidade para um agente-autor que só precisa de 1 provider. |
| loop | O loop concreto fica no harness: `HarnessApp.run_turn` é obrigatório e o `ExecutorAdapter` faz `async for event in executor.run_turn(...)`, traduz eventos, tools, cancelamento e completion (`omnigent/runtime/harnesses/_scaffold.py:793`, `omnigent/runtime/harnesses/_executor_adapter.py:251`, `omnigent/runtime/harnesses/_executor_adapter.py:393`). | Força: separa loop de transporte; fraqueza: difícil seguir end-to-end. | Melhor para múltiplos harnesses; pior que um loop local simples para mem-vector. |
| harness | Scaffold FastAPI expõe `/v1/sessions/{conversation_id}/events`, SSE, heartbeats, tool results, approvals, interrupt e shutdown (`omnigent/runtime/harnesses/_scaffold.py:1`, `omnigent/runtime/harnesses/_scaffold.py:846`, `omnigent/runtime/harnesses/_scaffold.py:1015`). Adapter partilhado envolve Claude SDK, Codex, Pi e OpenAI Agents (`omnigent/runtime/harnesses/_executor_adapter.py:1`). | Força grande: contrato uniforme; fraqueza: muita infraestrutura. | Melhor se mem-vector quiser relay Claude↔Codex; demasiado pesado para chat+RAG local. |
| memory | Persistência relacional: `conversations`, `conversation_items`, labels, `session_state`, usage e parent/root IDs (`omnigent/db/db_models.py:236`, `omnigent/db/db_models.py:452`, `omnigent/db/db_models.py:507`). Não há vector DB/embeddings/RAG no source pesquisado. | Força: histórico tipado, ordenado e auditável; fraqueza: memória sem retrieval semântico. | Melhor como event store; pior que mem-vector no eixo vector recall/RAG. |
| recall | Converte itens persistidos para input do LLM e permite ler caudas de outras sessões via `sys_session_get_history`; limite default 10, max 50 (`omnigent/runtime/prompt.py:90`, `omnigent/tools/builtins/spawn.py:41`, `omnigent/tools/builtins/spawn.py:1066`). Search semântico/vector: não encontrado. | Força: recall explícito e permissionado; fraqueza: tail recall, não recuperação por relevância. | Melhor para orquestração multi-sessão; pior para vault de conhecimento. |
| context | Compactação em 3 camadas: limpa tool/binary outputs, resume via LLM e trunca como fallback; protege janela recente (`omnigent/runtime/compaction.py:1`, `omnigent/runtime/compaction.py:521`, `omnigent/runtime/compaction.py:601`). System prompt junta instructions, overrides e skills quando `load_skill` existe (`omnigent/runtime/prompt.py:17`). | Força: estratégia pragmática e persistível; fraqueza: resumo lossy e sem citações. | Melhor que agente-autor simples; importar quase direto. |
| tools | ToolManager regista builtins, sub-sessões, agent reads, client tools e callable tools; runner despacha OS, file, terminal, MCP, async inbox, session, skill, comments e policy tools localmente/REST (`omnigent/tools/manager.py:373`, `omnigent/tools/manager.py:798`, `omnigent/runner/tool_dispatch.py:1`, `omnigent/runner/tool_dispatch.py:152`). | Força: tipologia de tools clara; fraqueza: superfície enorme. | Melhor como catálogo de padrões; pior se copiado inteiro. |
| system prompt/kernel | `instructions` ganha a `prompt`, lê ficheiros de contexto por prioridade e constrói instructions com skills (`omnigent/spec/parser.py:216`, `omnigent/spec/parser.py:55`, `omnigent/runtime/prompt.py:40`). Kernel real é a combinação spec YAML + scaffold + adapter. | Força: declarativo; fraqueza: kernel distribuído por muitos módulos. | Melhor para agentes configuráveis; mem-vector pode usar subset YAML. |
| skills | Descobre `skills/<name>/SKILL.md` e host skills `.claude/.agents`; `load_skill` devolve conteúdo e lista recursos (`omnigent/spec/parser.py:1874`, `omnigent/spec/parser.py:1796`, `omnigent/tools/builtins/load_skill.py:13`, `omnigent/tools/builtins/load_skill.py:138`). | Força: lazy-load reduz contexto; fraqueza: gestão de instruções não versiona conhecimento. | Melhor que prompts monolíticos; importar para rotinas do mem-vector. |
| planning | Planeamento autónomo genérico: não encontrado como módulo dedicado. Exemplos `polly` e skills instruem fanout/debate por prompt e `sys_session_send`, não por planner algorítmico (`examples/polly/config.yaml`, `examples/polly/skills/fanout/SKILL.md`, `examples/debby/config.yaml`). | Fraqueza: depende do LLM seguir instruções. | Igual ou ligeiramente pior que agente-autor simples com planner explícito. |
| behavior | Behavior é declarado em YAML: `async`, `timers`, `spawn`, `tools`, `os_env`, `terminals`, guardrails, prompt/instructions (`omnigent/spec/parser.py:186`, `omnigent/spec/parser.py:200`, `omnigent/spec/parser.py:207`, `omnigent/spec/parser.py:214`). | Força: authoring declarativo; fraqueza: muitas opções com interações. | Melhor para criar agentes por configuração; mem-vector deve reduzir o schema. |
| subagentes/orquestração | Sessões-filhas reais com `parent_conversation_id`, `root_conversation_id`, `kind=sub_agent`; `sys_session_send` cria/continua child sessions e `sys_session_create` cria filhos assíncronos (`omnigent/db/db_models.py:251`, `omnigent/tools/builtins/spawn.py:56`, `omnigent/tools/builtins/spawn.py:560`). | Força: subagentes duráveis e inspecionáveis; fraqueza: complexidade operacional. | Muito melhor que subagent inline simples; relevante para relay Claude↔Codex. |
| stop/terminação | Interrupt event marca `ctx.cancelled`, cancela futures, watchdog idle/absolute transforma turn wedged em failed, shutdown drena por grace period (`omnigent/runtime/harnesses/_scaffold.py:101`, `omnigent/runtime/harnesses/_scaffold.py:1085`, `omnigent/runtime/harnesses/_scaffold.py:1391`, `omnigent/runtime/harnesses/_scaffold.py:921`). | Força: terminação explícita e bounded; fraqueza: precisa de disciplina dos harnesses. | Melhor que agente-autor simples; importar cancelamento/futures/watchdog. |
| verificação | Verificação interna como testes e contratos; runtime emite completed/failed/cancelled e tracing MLflow, mas verificador de tarefa/código pelo agente: não encontrado (`omnigent/runtime/harnesses/_executor_adapter.py:340`, `omnigent/runtime/harnesses/_scaffold.py:1514`, `tests/codex_parity/test_codex_executor_parity.py`). | Fraqueza para agente-autor: falta loop “verify before answer”. | Pior que mem-vector deveria ter para tasks/daily. |
| permissões/sandbox | Sandbox por OS env com read/write roots, env passthrough allowlist, egress rules, credential proxy; helper filtra env e remove runner auth secrets (`omnigent/inner/sandbox.py:49`, `omnigent/inner/os_env.py:72`, `omnigent/inner/os_env.py:154`, `omnigent/spec/parser.py:763`). | Força muito alta: segurança prática; fraqueza: pesado e platform-specific. | Melhor em segurança; importar conceitos, não implementação inteira. |
| providers | Model string routing por prefixo, default OpenAI, adapters; auth por API key, Databricks profile ou provider nomeado (`omnigent/llms/routing.py:51`, `omnigent/spec/types.py:374`, `omnigent/spec/types.py:415`, `omnigent/spec/types.py:442`). | Força: portabilidade; fraqueza: provider drift e compat layers. | Melhor se mem-vector alternar Claude/Codex; excessivo se usar só OpenAI. |

## Pontos fortes (rankeados)
1. Contrato de harness/eventos bem separado: mensagens, tool results, approvals, policy verdicts, interrupts e SSE num canal previsível (`omnigent/runtime/harnesses/_scaffold.py:1015`).
2. Histórico tipado e relacional com árvore de sessões/subagentes, labels, state e usage (`omnigent/db/db_models.py:236`, `omnigent/db/db_models.py:452`, `omnigent/db/db_models.py:507`).
3. Compactação em camadas com janela recente protegida e resumo persistível (`omnigent/runtime/compaction.py:521`).
4. Orquestração por sessões-filhas duráveis em vez de subagentes efémeros (`omnigent/tools/builtins/spawn.py:56`, `omnigent/tools/builtins/spawn.py:560`).
5. Políticas composáveis com ALLOW/ASK/DENY, labels/state e fail-closed nos pontos certos (`omnigent/runtime/policies/engine.py:222`, `omnigent/runner/policy.py:228`).

## O que vale importar para o mem-vector
- [ ] Event store tipado para chat/tasks/daily — guardar mensagens, tool calls, tool outputs, reasoning/metadata e labels como itens ordenados; encaixa na DB do vault e melhora auditabilidade.
- [ ] Compactação em 3 camadas — limpar outputs pesados, resumir histórico antigo e só truncar no fim; encaixa no construtor de contexto antes do RAG.
- [ ] `sys_session_get_history`/sub-sessões — tratar Claude, Codex e workers como conversas-filhas endereçáveis, com tail recall e permissões; encaixa no relay Claude↔Codex.
- [ ] Skills lazy-load tipo `SKILL.md` — manter rotinas do autor fora do prompt base e carregar sob pedido; encaixa em workflows de daily, ingest, revisão e publicação.
- [ ] Políticas ALLOW/ASK/DENY — gates para escrita no vault, shell, envio externo, custo e ações irreversíveis; encaixa como middleware antes de tools.
- [ ] Cancelamento/watchdogs — cada turn/tool async deve ter future correlacionada, interrupt e timeout idle/absolute; encaixa no runner de tasks.
- [ ] Provider router mínimo — prefixo `provider/model` e auth explícita por provider; encaixa no relay sem herdar todo o framework.

## Não importar / armadilhas
- Não importar a plataforma inteira: servidor, runner, UI, tunnel, terminal registry e deploys são muito mais do que o mem-vector precisa.
- Não copiar a memória como “RAG”: Omnigent não tem embeddings/vector recall; a parte útil é o event store e a compactação, não retrieval semântico.
- Não adotar o schema completo de YAML: `executor.config` é reconhecido pelo próprio código como debt/escape hatch (`omnigent/spec/types.py:520`).
- Não depender só de prompt-planning: os exemplos planeiam por instrução; para mem-vector convém planner/verificador explícito.
- Não usar `sandbox.type: none` como padrão: os exemplos fazem-no para dev, mas o código mostra que isso também desativa filtragem de env (`omnigent/inner/os_env.py:181`).
- Não aceitar stdio MCP como “sandboxed”: o source diz que stdio MCP corre unsandboxed e deixa sandboxing per-MCP para desenho futuro (`omnigent/spec/types.py:850`).

## Fontes
- `pyproject.toml`
- `LICENSE`
- `README.md`
- `omnigent/spec/parser.py`
- `omnigent/spec/types.py`
- `omnigent/runtime/harnesses/_scaffold.py`
- `omnigent/runtime/harnesses/_executor_adapter.py`
- `omnigent/runtime/prompt.py`
- `omnigent/runtime/compaction.py`
- `omnigent/db/db_models.py`
- `omnigent/tools/manager.py`
- `omnigent/tools/builtins/spawn.py`
- `omnigent/tools/builtins/load_skill.py`
- `omnigent/runner/tool_dispatch.py`
- `omnigent/runner/policy.py`
- `omnigent/runtime/policies/engine.py`
- `omnigent/llms/client.py`
- `omnigent/llms/routing.py`
- `omnigent/inner/sandbox.py`
- `omnigent/inner/os_env.py`
- `examples/polly/config.yaml`
- `examples/debby/config.yaml`
- `docs/AGENT_YAML_SPEC.md`
- `docs/POLICIES.md`
