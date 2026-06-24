---
tags: [knowledge, synthesis, ai-software, agente-estudo]
created: 2026-06-22
summary: Ruflo — agente/orquestrador real, mas irregular; importar memória RVF+markdown, SmartRetrieval, loop Codex e relay Claude↔Codex.
agente: Ruflo
repo: ruvnet/ruflo
commit: ec1a187
---

# Ruflo — estudo de source

> Veredito: É um agente/orquestrador real para CLI/MCP, swarms e memória, não uma demo. O que vale para mem-vector é a ponte DB↔markdown, retrieval com diversidade/recência, loops persistidos e relay Claude↔Codex; evitar copiar a complexidade e claims não implementados. Estudado no commit ec1a187.

## Identidade
- Ruflo/Claude Flow V3 é um sistema TypeScript/Node para orquestração de agentes, MCP tools, memória vectorial e colaboração Claude Code + Codex; o binário root só encaminha para `v3/@claude-flow/cli/bin/cli.js` (`clones/ruvnet__ruflo/bin/cli.js:1`).
- Providers vistos no código: Anthropic, OpenAI, Google, Cohere, Ollama e RuVector via `ProviderManager` (`clones/ruvnet__ruflo/v3/@claude-flow/providers/src/provider-manager.ts:32`). Linguagem principal: TypeScript/JavaScript ESM (`clones/ruvnet__ruflo/package.json:2`). Licença MIT (`clones/ruvnet__ruflo/LICENSE:1`).

## Anatomia (como faz cada coisa)
| Termo | Como o faz (`ficheiro`) | Força/Fraqueza | vs agente-autor simples |
|---|---|---|---|
| regressão/autoregressão | Autoregressão própria não encontrada: delega geração às APIs/modelos em `agent_execute` e providers (`clones/ruvnet__ruflo/v3/@claude-flow/cli/src/mcp-tools/agent-execute-core.ts:125`, `clones/ruvnet__ruflo/v3/@claude-flow/providers/src/anthropic-provider.ts:144`). Regressão aparece como testes/smokes, não como treino online (`clones/ruvnet__ruflo/scripts/smoke-memory-db-path.mjs:3`). | Fraqueza: muita linguagem de “self-learning”, mas o loop de geração não é controlado internamente. | Pior para um agente-autor se copiado como claims; melhor só como harness de regressão operacional. |
| loop | Tem `/loop` para Codex: estado em `.codex/loop`, itera até marker file, stop file, maxIterations, timeout e sleep (`clones/ruvnet__ruflo/v3/@claude-flow/codex/src/loop/index.ts:67`, `clones/ruvnet__ruflo/v3/@claude-flow/codex/src/loop/index.ts:160`). | Força: mecanismo simples e auditável; fraqueza: não avalia qualidade semanticamente, só exit code/marker. | Melhor que um agente-autor simples porque dá persistência e stop externo; manter simples. |
| harness | Exposição MetaHarness como MCP read-only por subprocesso, com `success/degraded/exitCode` explícitos (`clones/ruvnet__ruflo/v3/@claude-flow/cli/src/mcp-tools/metaharness-tools.ts:1`, `clones/ruvnet__ruflo/v3/@claude-flow/cli/src/mcp-tools/metaharness-tools.ts:95`). | Força: resultados estruturados e degradados sem crash; fraqueza: depende de scripts/plugin externos. | Melhor que scripts soltos; importar o contrato de resultado, não a dependência. |
| memory | Camada útil em `@claude-flow/memory`: `UnifiedMemoryService`, `AgentDBAdapter`, snapshots e consolidador (`clones/ruvnet__ruflo/v3/@claude-flow/memory/src/index.ts:295`, `clones/ruvnet__ruflo/v3/@claude-flow/memory/src/index.ts:408`). RVF persiste entradas + embeddings com escrita atómica (`clones/ruvnet__ruflo/v3/@claude-flow/memory/src/rvf-backend.ts:213`, `clones/ruvnet__ruflo/v3/@claude-flow/memory/src/rvf-backend.ts:674`). | Força: namespaces, tags, snapshots, RVF; fraqueza: a camada `v3/src/memory` ainda é `Map` in-memory apesar do nome SQLite/AgentDB (`clones/ruvnet__ruflo/v3/src/memory/infrastructure/SQLiteBackend.ts:31`). | Melhor que agente-autor simples se for só o núcleo RVF/namespace; pior se importar camadas duplicadas. |
| recall | `memory_search` faz busca semântica e opcional `smart=true`; SmartRetrieval usa expansão, RRF, recência, MMR e round-robin por sessão (`clones/ruvnet__ruflo/v3/@claude-flow/cli/src/mcp-tools/memory-tools.ts:439`, `clones/ruvnet__ruflo/v3/@claude-flow/memory/src/smart-retrieval.ts:372`). | Força: retrieval pragmático sem LLM; fraqueza: query expansion é template simples. | Melhor que top-k simples de agente-autor; importar como pipeline pequeno. |
| context | AutoMemoryBridge sincroniza AgentDB com markdown que o agente pode carregar, com `MEMORY.md` limitado e topic files (`clones/ruvnet__ruflo/v3/@claude-flow/memory/src/auto-memory-bridge.ts:1`, `clones/ruvnet__ruflo/v3/@claude-flow/memory/src/auto-memory-bridge.ts:457`). Dual-mode injeta namespace e protocolo no prompt (`clones/ruvnet__ruflo/v3/@claude-flow/codex/src/dual-mode/orchestrator.ts:213`). | Força: separa índice curto de detalhe; fraqueza: classificação por tags/heurísticas. | Melhor que meter todo o vault no prompt; muito relevante para mem-vector. |
| tools | Regista muitas MCP tools numa registry única e chama handlers por nome (`clones/ruvnet__ruflo/v3/@claude-flow/cli/src/mcp-client.ts:86`, `clones/ruvnet__ruflo/v3/@claude-flow/cli/src/mcp-client.ts:177`). | Força: CLI como wrapper fino sobre MCP; fraqueza: superfície enorme e heterogénea. | Melhor para extensibilidade; pior para agente-autor simples se aumentar blast radius. |
| system prompt/kernel | Kernel de comportamento existe sobretudo como `CLAUDE.md` e prompts de hooks/dual-mode, não como runtime kernel único (`clones/ruvnet__ruflo/CLAUDE.md:7`, `clones/ruvnet__ruflo/plugin/hooks/hooks.json:159`). | Fraqueza: regras em markdown podem divergir do código. | Pior que um kernel pequeno e testável; importar só protocolos escritos como artefactos. |
| skills | Grande catálogo `.agents/skills/*/SKILL.md`; inicializador copia skills e cria `AGENTS.md`/config (`clones/ruvnet__ruflo/v3/@claude-flow/codex/src/initializer.ts:102`). | Força: empacotamento de capacidades; fraqueza: catálogo muito grande e difícil de governar. | Melhor que prompts dispersos se houver curadoria; pior se virar biblioteca de slogans. |
| planning | WorkflowEngine ordena tarefas por dependências, suporta pausa/resume, rollback e execução paralela (`clones/ruvnet__ruflo/v3/src/task-execution/application/WorkflowEngine.ts:117`, `clones/ruvnet__ruflo/v3/src/task-execution/application/WorkflowEngine.ts:367`). | Força: estado e trace de workflow; fraqueza: tarefas reais são callbacks/agent ids, sem planner LLM robusto. | Melhor como executor determinístico; não substitui planner de agente-autor. |
| behavior | Hooks ligam PreToolUse/PostToolUse/UserPromptSubmit/Stop a comandos e prompts (`clones/ruvnet__ruflo/plugin/hooks/hooks.json:9`, `clones/ruvnet__ruflo/plugin/hooks/hooks.json:133`). Regras comportamentais em `CLAUDE.md` (`clones/ruvnet__ruflo/CLAUDE.md:48`). | Força: captura eventos naturais do agente; fraqueza: muitos hooks são `continueOnError`, logo podem falhar silenciosamente. | Melhor para observabilidade; importar com falhas visíveis, não silenciosas. |
| subagentes/orquestração | `agent_spawn` persiste agentes, faz routing de modelo e regista em swarm (`clones/ruvnet__ruflo/v3/@claude-flow/cli/src/mcp-tools/agent-tools.ts:267`). `SwarmCoordinator` distribui por capacidade/carga e guarda resultados em memória (`clones/ruvnet__ruflo/v3/src/coordination/application/SwarmCoordinator.ts:145`). DualModeOrchestrator corre Claude/Codex por níveis de dependência (`clones/ruvnet__ruflo/v3/@claude-flow/codex/src/dual-mode/orchestrator.ts:258`). | Força: persistência de estado e relay multi-plataforma; fraqueza: parte do consensus é simulado com `Math.random()` (`clones/ruvnet__ruflo/v3/src/coordination/application/SwarmCoordinator.ts:377`). | Melhor para relay Claude↔Codex; não importar swarm/consensus pesado. |
| stop/terminação | CLI one-shot termina com `process.exit(0)`; MCP stdio termina em `stdin end` (`clones/ruvnet__ruflo/v3/@claude-flow/cli/bin/cli.js:209`, `clones/ruvnet__ruflo/v3/@claude-flow/cli/bin/cli.js:303`). Loop usa `.stop` e `.complete`; workflows cancelam no shutdown (`clones/ruvnet__ruflo/v3/@claude-flow/codex/src/loop/index.ts:84`, `clones/ruvnet__ruflo/v3/src/task-execution/application/WorkflowEngine.ts:70`). | Força: stop externo simples; fraqueza: prompts Stop podem continuar com decisão LLM sem verificação real (`clones/ruvnet__ruflo/plugin/hooks/hooks.json:159`). | Melhor que loop infinito; importar marker/stop file. |
| verificação | Tem testes Node/Vitest para RVF, SmartRetrieval e smokes CLI (`clones/ruvnet__ruflo/tests/rvf-backend.test.ts:52`, `clones/ruvnet__ruflo/v3/@claude-flow/memory/src/smart-retrieval.test.ts:37`, `clones/ruvnet__ruflo/scripts/smoke-memory-db-path.mjs:3`). | Força: cobre invariantes de memória/retrieval; fraqueza: muita superfície sem prova equivalente. | Melhor que agente-autor simples se importar testes junto com feature. |
| permissões/sandbox | Codex dual usa `codex exec --sandbox workspace-write` (`clones/ruvnet__ruflo/v3/@claude-flow/codex/src/dual-mode/orchestrator.ts:159`). Ficheiros sensíveis usam modo 0600/0700 e encriptação opt-in (`clones/ruvnet__ruflo/v3/@claude-flow/cli/src/fs-secure.ts:1`). Há guardrail de output e safe executor (`clones/ruvnet__ruflo/v3/@claude-flow/security/src/tool-output-guardrail.ts:1`, `clones/ruvnet__ruflo/v3/@claude-flow/security/src/safe-executor.ts:163`). | Força: boas peças de segurança; fraqueza: `terminal_execute` usa `execSync(command)` com shell (`clones/ruvnet__ruflo/v3/@claude-flow/cli/src/mcp-tools/terminal-tools.ts:191`) e há auto-allow MCP (`clones/ruvnet__ruflo/plugin/hooks/hooks.json:194`). | Importar guardrails e permissões de ficheiro; não importar terminal shell livre nem auto-approve. |
| providers | ProviderManager suporta load balancing, caching e fallback (`clones/ruvnet__ruflo/v3/@claude-flow/providers/src/provider-manager.ts:138`, `clones/ruvnet__ruflo/v3/@claude-flow/providers/src/provider-manager.ts:224`). `agent_execute` escolhe Anthropic, OpenRouter ou Ollama por env (`clones/ruvnet__ruflo/v3/@claude-flow/cli/src/mcp-tools/agent-execute-core.ts:125`). | Força: abstração multi-provider; fraqueza: modelos/preços hardcoded ficam obsoletos e divergentes. | Para mem-vector, melhor manter provider abstraction mínima e actualizar modelos fora do código. |

## Pontos fortes (rankeados)
1. Ponte AgentDB/RVF ↔ markdown humano com índice curto `MEMORY.md` e topic files; encaixa quase diretamente num vault autoral (`clones/ruvnet__ruflo/v3/@claude-flow/memory/src/auto-memory-bridge.ts:457`).
2. SmartRetrieval sem LLM: expansão barata, RRF, recência, MMR e diversidade por sessão (`clones/ruvnet__ruflo/v3/@claude-flow/memory/src/smart-retrieval.ts:372`).
3. Loop Codex persistido por ficheiros, com stop/completion externos e estado JSON (`clones/ruvnet__ruflo/v3/@claude-flow/codex/src/loop/index.ts:67`).
4. Relay Claude↔Codex por workers dependentes e namespace partilhado (`clones/ruvnet__ruflo/v3/@claude-flow/codex/src/dual-mode/orchestrator.ts:258`).
5. Guardrails práticos: output injection scanner, permissões 0600/0700 e escrita atómica RVF (`clones/ruvnet__ruflo/v3/@claude-flow/security/src/tool-output-guardrail.ts:233`, `clones/ruvnet__ruflo/v3/@claude-flow/memory/src/rvf-backend.ts:674`).

## O que vale importar para o mem-vector
- [ ] Bridge vault/DB em duas direções — AgentDB/RVF como store canónico e markdown como superfície humana; aplicar a `daily/`, `tasks/`, `knowledge/` e `MEMORY.md`.
- [ ] SmartRetrieval modular — pipeline `searchFn -> expansion/RRF/recency/MMR/session diversity` antes de montar contexto RAG.
- [ ] Loop persistido por markers — `.mem-vector/loop/<name>.json`, `.stop`, `.complete` para tarefas longas de manutenção do vault.
- [ ] Relay Claude↔Codex com namespace partilhado — executar workers por níveis de dependência e obrigar cada worker a escrever resultados numa chave previsível.
- [ ] Contrato de tool result `{success, data, degraded, exitCode}` — útil para harnesses, auditorias e verificações sem crashes.
- [ ] Content-boundary guardrail — filtrar outputs de ferramentas, web, memória e documentos antes de entrarem no prompt.
- [ ] Permissões de storage — ficheiros com modo 0600/0700, escrita atómica e encriptação opt-in para histórico, comandos e notas sensíveis.

## Não importar / armadilhas
- Não importar a superfície MCP inteira: muitas tools, nomes e claims aumentam manutenção sem melhorar um agente-autor.
- Não importar consensus/swarms tal como estão: parte do consensus é simulação (`Math.random()`), inadequado para decisões autorais.
- Não importar auto-approve de MCP nem terminal shell livre; para mem-vector, comandos devem ser allowlistados e auditáveis.
- Não copiar modelos/preços hardcoded; manter provider/model config externa e actualizável.
- Não duplicar camadas de memória: escolher um store real e apagar wrappers `Map`/mock.
- Não aceitar hooks `continueOnError` para memória crítica; falhas de sync/recall devem ser visíveis.
- Não transformar skills num catálogo gigante; usar poucas skills curadas para escrita, revisão, curadoria e relay.

## Fontes
- `clones/ruvnet__ruflo/package.json`
- `clones/ruvnet__ruflo/LICENSE`
- `clones/ruvnet__ruflo/bin/cli.js`
- `clones/ruvnet__ruflo/v3/@claude-flow/cli/bin/cli.js`
- `clones/ruvnet__ruflo/v3/@claude-flow/cli/src/mcp-client.ts`
- `clones/ruvnet__ruflo/v3/@claude-flow/cli/src/mcp-tools/memory-tools.ts`
- `clones/ruvnet__ruflo/v3/@claude-flow/cli/src/mcp-tools/agent-tools.ts`
- `clones/ruvnet__ruflo/v3/@claude-flow/cli/src/mcp-tools/agent-execute-core.ts`
- `clones/ruvnet__ruflo/v3/@claude-flow/cli/src/mcp-tools/swarm-tools.ts`
- `clones/ruvnet__ruflo/v3/@claude-flow/cli/src/mcp-tools/terminal-tools.ts`
- `clones/ruvnet__ruflo/v3/@claude-flow/cli/src/mcp-tools/metaharness-tools.ts`
- `clones/ruvnet__ruflo/v3/@claude-flow/memory/src/index.ts`
- `clones/ruvnet__ruflo/v3/@claude-flow/memory/src/rvf-backend.ts`
- `clones/ruvnet__ruflo/v3/@claude-flow/memory/src/smart-retrieval.ts`
- `clones/ruvnet__ruflo/v3/@claude-flow/memory/src/auto-memory-bridge.ts`
- `clones/ruvnet__ruflo/v3/@claude-flow/codex/src/dual-mode/orchestrator.ts`
- `clones/ruvnet__ruflo/v3/@claude-flow/codex/src/loop/index.ts`
- `clones/ruvnet__ruflo/v3/src/coordination/application/SwarmCoordinator.ts`
- `clones/ruvnet__ruflo/v3/src/task-execution/application/WorkflowEngine.ts`
- `clones/ruvnet__ruflo/plugin/hooks/hooks.json`
- `clones/ruvnet__ruflo/CLAUDE.md`
- `clones/ruvnet__ruflo/tests/rvf-backend.test.ts`
- `clones/ruvnet__ruflo/v3/@claude-flow/memory/src/smart-retrieval.test.ts`
- `clones/ruvnet__ruflo/scripts/smoke-memory-db-path.mjs`
