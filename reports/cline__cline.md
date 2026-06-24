---
tags: [knowledge, synthesis, ai-software, agente-estudo]
created: 2026-06-22
summary: Cline — agente real e maduro de coding; vale importar loop task-state+tool-result, checkpoints, skills lazy e hooks, não a complexidade de IDE/providers.
agente: Cline
repo: cline/cline
commit: 6ddf48d
---

# Cline — estudo de source

> Veredito: Agente de coding real, não demo: VS Code/CLI agent com loop autoregressivo, tools, approvals, checkpoints, skills e subagentes. Estudado no commit 6ddf48d.

## Identidade
- O que é: agente de coding interactivo com UI de IDE, shell, edição de ficheiros, browser, MCP, hooks, skills, subagentes e histórico de tarefas. A implementação principal estudada está em TypeScript, sobretudo `apps/vscode/src/core/task/index.ts`.
- Provider, linguagem, licença: suporta muitos providers via `ApiHandler` (`apps/vscode/src/core/api/index.ts:8`, `apps/vscode/src/core/api/index.ts:78`); TypeScript/Node/Bun (`package.json`); licença Apache-2.0 (`LICENSE`).

## Anatomia (como faz cada coisa)
| Termo | Como o faz (`ficheiro`) | Força/Fraqueza | vs agente-autor simples |
|---|---|---|---|
| regressão/autoregressão | Autoregressivo: adiciona user/tool result ao histórico, chama `api.createMessage`, faz parse do stream, executa tool, volta a chamar o modelo (`apps/vscode/src/core/task/index.ts:2383`, `apps/vscode/src/core/task/index.ts:3493`, `apps/vscode/src/core/task/index.ts:3815`). Regressão/eval formal não encontrado no loop. | Força no ciclo de tool-result; fraqueza em complexidade e recursão difícil de auditar. | Melhor para IDE coding; para mem-vector basta um loop explícito iterativo, não esta máquina inteira. |
| loop | `initiateTaskLoop` chama `recursivelyMakeClineRequests` até abort/end; se não há tool, injecta `noToolsUsed` e incrementa erros (`apps/vscode/src/core/task/index.ts:1718`, `apps/vscode/src/core/task/index.ts:1740`). | Força: força progresso e não aceita texto solto como conclusão. Fraqueza: recursão + muito estado partilhado. | Melhor em robustez; pior em simplicidade. Importar a regra “tool result ou completion obrigatória”. |
| harness | `Task` é o harness runtime: dependências, estado, UI ask/say, terminal, browser, MCP, checkpoints, context manager e executor de tools (`apps/vscode/src/core/task/index.ts:189`, `apps/vscode/src/core/task/index.ts:247`, `apps/vscode/src/core/task/index.ts:705`). | Força: integra tudo num ciclo controlado. Fraqueza: acoplamento grande. | Um agente-autor simples deve separar harness de domínio/vault mais limpo. |
| memory | Memória persistente é histórica/operacional: `api_conversation_history.json`, `ui_messages.json`, `context_history.json`, `taskHistory`, global/workspace/secrets (`apps/vscode/src/core/storage/disk.ts:48`, `apps/vscode/src/core/task/message-state.ts:120`, `apps/vscode/src/shared/storage/storage-context.ts:86`). Memória semântica/vector DB não encontrado. | Força: persistência por task e recuperação. Fraqueza: não é memória conceptual/RAG. | Pior que mem-vector para conhecimento durável; melhor como audit log. |
| recall | Recupera tasks por histórico, reabre mensagens/API history e pergunta se retoma (`apps/vscode/src/core/task/index.ts:1393`, `apps/vscode/src/core/task/index.ts:1401`, `apps/vscode/src/core/task/index.ts:1435`, `apps/vscode/src/core/task/index.ts:1467`). Recall semântico por embeddings não encontrado. | Força: continuidade exacta da task. Fraqueza: recall é linear/por task. | Importar replay/audit; mem-vector precisa ainda de retrieval semântico. |
| context | Processa menções `@file`, URLs, problems, terminal e git; gere truncation, auto-condense e preserva pares tool_use/tool_result (`apps/vscode/src/core/mentions/index.ts:59`, `apps/vscode/src/core/context/context-management/ContextManager.ts:227`, `apps/vscode/src/core/context/context-management/ContextManager.ts:299`, `apps/vscode/src/core/context/context-management/ContextManager.ts:371`). | Força: contexto actual e seguro. Fraqueza: muito orientado a código/IDE. | Melhor que agente simples no controlo de janela; para mem-vector adaptar para vault/RAG/doc references. |
| tools | Tool registry/dispatcher mapeia nomes para handlers: read/write/search/bash/browser/MCP/web/skills/subagents/attempt (`apps/vscode/src/core/task/tools/ToolExecutorCoordinator.ts:75`, `apps/vscode/src/core/task/tools/ToolExecutorCoordinator.ts:79`, `apps/vscode/src/core/task/ToolExecutor.ts:201`). | Força: handlers isolados e compatíveis com XML/native tools. Fraqueza: superfície enorme. | Melhor arquitectura de tools; mem-vector deve importar registry pequeno com schemas claros. |
| system prompt/kernel | Prompt por variantes/model family, componentes e native tools; monta contexto com regras, skills, MCP, ignore, tabs, provider, mode (`apps/vscode/src/core/prompts/system-prompt/registry/PromptRegistry.ts:86`, `apps/vscode/src/core/prompts/system-prompt/components/index.ts:21`, `apps/vscode/src/core/task/index.ts:2305`, `apps/vscode/src/core/task/index.ts:2355`). | Força: kernel modular e model-aware. Fraqueza: variantes acumulam dívida. | Melhor que prompt monolítico; importar composição por componentes, não todos os variants. |
| skills | Descobre `SKILL.md` em `.clinerules/skills`, `.cline/skills`, `.claude/skills`, `.agents/skills`, globais e remotos; expõe no prompt e carrega via `use_skill` (`apps/vscode/src/core/storage/disk.ts:220`, `apps/vscode/src/core/context/instructions/user-instructions/skills.ts:153`, `apps/vscode/src/core/prompts/system-prompt/components/skills.ts:6`, `apps/vscode/src/core/task/tools/handlers/UseSkillToolHandler.ts:38`). | Força: lazy-load reduz prompt e dá especialização. Fraqueza: depende do modelo escolher a skill. | Muito melhor que instruções sempre injectadas; importar quase directo para mem-vector. |
| planning | Plan/Act mode, com tool `plan_mode_respond` e restrição de file edits em plan mode (`apps/vscode/src/core/prompts/system-prompt/components/act_vs_plan_mode.ts:5`, `apps/vscode/src/core/prompts/system-prompt/tools/plan_mode_respond.ts:25`, `apps/vscode/src/core/task/ToolExecutor.ts:291`). | Força: separa exploração/plano de execução. Fraqueza: UI/mode toggle pesado. | Melhor para mudanças perigosas; para mem-vector usar modo “draft vs commit to vault”. |
| behavior | `TaskState` guarda flags de streaming, erro, abort, todo, tool-use, retry e loop; há detecção de tool repetida e limite de mistakes (`apps/vscode/src/core/task/TaskState.ts:11`, `apps/vscode/src/core/task/TaskState.ts:42`, `apps/vscode/src/core/task/loop-detection.ts:21`, `apps/vscode/src/core/task/index.ts:2819`). | Força: protege contra loops e respostas vazias. Fraqueza: estado mutable extenso. | Melhor em guardrails; agente simples deve manter menos flags, mas manter counters. |
| subagentes/orquestração | `use_subagents` aceita até 5 prompts, pede approval, corre `SubagentRunner` em paralelo e agrega status/uso/resultados (`apps/vscode/src/core/task/tools/handlers/SubagentToolHandler.ts:20`, `apps/vscode/src/core/task/tools/handlers/SubagentToolHandler.ts:215`, `apps/vscode/src/core/task/tools/handlers/SubagentToolHandler.ts:258`, `apps/vscode/src/core/task/tools/subagent/SubagentRunner.ts:295`). | Força: fan-out controlado com summaries. Fraqueza: caro e só útil quando a tarefa paraleliza. | Melhor para research; mem-vector pode importar subagentes como “research workers” limitados. |
| stop/terminação | Termina via `attempt_completion`, pergunta feedback/novo task, pode executar comando final e tem double-check opcional (`apps/vscode/src/core/task/tools/handlers/AttemptCompletionHandler.ts:57`, `apps/vscode/src/core/task/tools/handlers/AttemptCompletionHandler.ts:69`, `apps/vscode/src/core/task/tools/handlers/AttemptCompletionHandler.ts:231`). Abort limpa hooks, comandos, browser, diff, ignore e lock (`apps/vscode/src/core/task/index.ts:1802`). | Força: completion é uma tool auditável. Fraqueza: conclusão ainda espera UI. | Importar “completion como evento estruturado” para commits de memória. |
| verificação | Double-check antes de completion, checkpoints, command final opcional, PostToolUse hooks; testes existem para handlers críticos (`apps/vscode/src/core/task/tools/handlers/AttemptCompletionHandler.ts:69`, `apps/vscode/src/integrations/checkpoints/index.ts:114`, `apps/vscode/src/core/task/ToolExecutor.ts:460`). Verificação de conteúdo factual/RAG não encontrado. | Força: boa verificação operacional. Fraqueza: não valida verdade/conhecimento. | Para mem-vector, combinar com validação de sources/links antes de escrever no vault. |
| permissões/sandbox | `.clineignore` bloqueia ficheiros/comandos de leitura; auto-approve por tool/path; command permissions por env var allow/deny/redirects; strict Plan mode bloqueia edits (`apps/vscode/src/core/ignore/ClineIgnoreController.ts:15`, `apps/vscode/src/core/task/tools/autoApprove.ts:40`, `apps/vscode/src/core/permissions/CommandPermissionController.ts:26`, `apps/vscode/src/core/task/ToolExecutor.ts:342`). Sandbox OS completo não encontrado. | Força: permissões pragmáticas e explicáveis. Fraqueza: não é isolamento forte. | Melhor que agente simples; importar policy engine, não prometer sandbox real. |
| providers | Interface `ApiHandler` normaliza `createMessage/getModel/abort`; `createHandlerForProvider` faz switch para Anthropic/OpenRouter/OpenAI/Gemini/Ollama/etc.; provider plan/act pode diferir (`apps/vscode/src/core/api/index.ts:55`, `apps/vscode/src/core/api/index.ts:78`, `apps/vscode/src/core/api/index.ts:86`, `apps/vscode/src/shared/api.ts:4`). | Força: enorme compatibilidade. Fraqueza: muita manutenção e diferenças de tool-calling. | Pior para mem-vector se importado todo; usar 1-2 providers e interface estável. |

## Pontos fortes (rankeados)
1. Loop tool-result robusto: modelo não “conclui” por texto livre; precisa de tool ou `attempt_completion` (`apps/vscode/src/core/task/index.ts:3798`).
2. Persistência auditável por task: mensagens UI, API history, context history e taskHistory separados (`apps/vscode/src/core/task/message-state.ts:120`, `apps/vscode/src/core/storage/disk.ts:48`).
3. Skills lazy-load com precedência project/global/remote: bom encaixe para conhecimento operativo sem inflar prompt (`apps/vscode/src/core/context/instructions/user-instructions/skills.ts:144`).
4. Checkpoints e completion estruturada: cada ciclo pode guardar estado e marcar mudanças novas (`apps/vscode/src/core/task/index.ts:2891`, `apps/vscode/src/core/task/tools/handlers/AttemptCompletionHandler.ts:113`).
5. Hooks cancellable/context-modifying: pontos limpos para políticas, logging, injectar contexto e bloquear tools (`apps/vscode/src/core/hooks/hook-executor.ts:58`, `apps/vscode/src/core/task/tools/utils/ToolHookUtils.ts:72`).
6. Subagentes paralelos com budget/status: útil para leitura/research multi-ficheiro, desde que limitado (`apps/vscode/src/core/task/tools/handlers/SubagentToolHandler.ts:224`).

## O que vale importar para o mem-vector
- [ ] Completion como tool/evento estruturado — usar `attempt_completion` equivalente para “commit de conhecimento” no vault/DB, com double-check antes de gravar.
- [ ] Separar `ui_messages`, `api_conversation_history`, `context_history` e `taskHistory` — manter audit log humano, histórico para LLM e metadados pesquisáveis em tabelas diferentes.
- [ ] Skills lazy por `SKILL.md`/frontmatter — para modos como daily review, relay Claude-Codex, RAG ingestion, task triage e vault cleanup.
- [ ] Policy engine antes de tools — `.memignore`, allow/deny para comandos, auto-approve por tool/path e bloqueios para operações destrutivas.
- [ ] Hooks lifecycle — `TaskStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `TaskComplete`, `TaskResume`, `PreCompact` como extensões de workflows do vault.
- [ ] Context compaction com histórico de alterações — resumir/condensar sem perder pares tool_use/tool_result e guardar que partes foram removidas.
- [ ] Focus-chain/todo persistido em markdown — adaptar para daily/tasks: lista editável pelo utilizador e re-injectada quando alterada ou esquecida.
- [ ] Subagentes limitados para research — até N workers para “ler estes espaços do vault/repos e devolver fontes”, sem permissões de escrita.
- [ ] Prompt kernel por componentes — `rules`, `skills`, `context`, `tools`, `mode`, `objective`; evitar prompt monolítico.

## Não importar / armadilhas
- Não importar todos os providers: custo de manutenção alto e comportamento de tool calling divergente.
- Não importar a UI/IDE coupling como arquitectura base; mem-vector deve ser vault/DB-first.
- Não confundir task history com memória semântica: Cline não tem vector memory/RAG durável encontrado no código.
- Não prometer sandbox forte com `.ignore` e allow/deny; são guardrails, não isolamento de processo.
- Não copiar o loop recursivo e estado mutable extenso sem reduzir: a clareza de mem-vector sofrerá.
- Não activar subagentes como default; fan-out aumenta custo e ruído.
- Não depender só do modelo para escolher skills; para mem-vector convém router determinístico por intent/contexto.

## Fontes
- `clones/cline__cline/apps/vscode/src/core/task/index.ts` — loop principal, API stream, context, lifecycle, abort.
- `clones/cline__cline/apps/vscode/src/core/task/TaskState.ts` — estado operacional do agente.
- `clones/cline__cline/apps/vscode/src/core/task/ToolExecutor.ts` — execução e restrições de tools.
- `clones/cline__cline/apps/vscode/src/core/task/tools/ToolExecutorCoordinator.ts` — registry de tools.
- `clones/cline__cline/apps/vscode/src/core/task/tools/handlers/AttemptCompletionHandler.ts` — completion/terminação/verificação.
- `clones/cline__cline/apps/vscode/src/core/task/tools/handlers/SubagentToolHandler.ts` e `clones/cline__cline/apps/vscode/src/core/task/tools/subagent/SubagentRunner.ts` — subagentes.
- `clones/cline__cline/apps/vscode/src/core/context/context-management/ContextManager.ts` — truncation/compaction/context history.
- `clones/cline__cline/apps/vscode/src/core/context/instructions/user-instructions/skills.ts` e `clones/cline__cline/apps/vscode/src/core/task/tools/handlers/UseSkillToolHandler.ts` — skills.
- `clones/cline__cline/apps/vscode/src/core/prompts/system-prompt/*` — prompt registry/components/tools.
- `clones/cline__cline/apps/vscode/src/core/storage/disk.ts`, `clones/cline__cline/apps/vscode/src/core/storage/StateManager.ts`, `clones/cline__cline/apps/vscode/src/shared/storage/storage-context.ts` — storage.
- `clones/cline__cline/apps/vscode/src/core/ignore/ClineIgnoreController.ts`, `clones/cline__cline/apps/vscode/src/core/permissions/CommandPermissionController.ts`, `clones/cline__cline/apps/vscode/src/core/task/tools/autoApprove.ts` — permissões.
- `clones/cline__cline/apps/vscode/src/core/api/index.ts`, `clones/cline__cline/apps/vscode/src/shared/api.ts` — providers.
- `clones/cline__cline/LICENSE`, `clones/cline__cline/package.json`.
