---
tags: [knowledge, synthesis, ai-software, agente-estudo]
created: 2026-06-22
summary: Archon — harness real para agentes de coding; vale importar DAGs, gates humanos, eventos/resume e artefactos tipados, não a camada pesada multi-plataforma.
agente: Archon
repo: coleam00/Archon
commit: e77a338
---

# Archon — estudo de source

> Veredito: É um agente/harness de coding real: orquestra Claude/Codex/outros providers sobre workflows YAML, conversas e worktrees. Para o mem-vector, o ouro está no motor DAG+resume+artefactos, não em RAG/vector DB — isso não foi encontrado no branch clonado. Estudado no commit e77a338.

## Identidade
- O que é: plataforma/harness remoto para agentes de coding, com chat, workflows DAG, isolamento por git worktree e execução via providers (`packages/core/src/orchestrator/orchestrator-agent.ts`, `packages/workflows/src/dag-executor.ts`).
- Provider, linguagem, licença: TypeScript/Bun (`package.json`), providers Claude, Codex, Copilot, Pi e OpenCode por registry (`packages/providers/src/registry.ts:110`), licença MIT (`LICENSE`).

## Anatomia (como faz cada coisa)
| Termo | Como o faz (`ficheiro`) | Força/Fraqueza | vs agente-autor simples |
|---|---|---|---|
| regressão/autoregressão | Autoregressão delegada aos SDKs dos providers via `sendQuery()` em streams (`packages/providers/src/claude/provider.ts:851`, `packages/providers/src/codex/provider.ts:725`). Regressão/eval formal não encontrado; há testes unitários e workflows de validação. | Força como wrapper multi-provider; fraqueza porque não há ciclo de aprendizagem/avaliação próprio. | Melhor para execução; pior se o mem-vector precisar de medir qualidade de escrita de memória ao longo do tempo. |
| loop | Nó `loop` com `prompt`, `until`, `max_iterations`, `fresh_context`, `until_bash` e gate interactivo (`packages/workflows/src/schemas/loop.ts:6`). Runtime itera, detecta sinal, corre bash determinístico e pausa para input humano (`packages/workflows/src/dag-executor.ts:2031`, `packages/workflows/src/dag-executor.ts:2444`). | Força: limite explícito, condição textual e condição bash. Fraqueza: conclusão por string pode ser frágil. | Melhor que um agente-autor simples porque separa iteração de critérios; importar a forma, não a dependência em magic string. |
| harness | Workflows YAML viram nós tipados: `command`, `prompt`, `bash`, `script`, `loop`, `approval`, `cancel` (`packages/workflows/src/schemas/dag-node.ts:348`). Executor corre por camadas topológicas e paraleliza com `Promise.allSettled` (`packages/workflows/src/dag-executor.ts:2865`, `packages/workflows/src/dag-executor.ts:2963`). | Força principal: estrutura determinística à volta de agentes probabilísticos. Fraqueza: grande superfície de configuração. | Muito melhor para mem-vector do que um loop simples; dá receitas reprodutíveis para daily, relay e manutenção de vault. |
| memory | Guarda conversas, sessões, runs, eventos, mensagens e sessões por nó em tabelas SQL (`migrations/000_combined.sql:108`, `migrations/000_combined.sql:139`, `migrations/000_combined.sql:228`, `migrations/000_combined.sql:263`, `migrations/000_combined.sql:289`, `migrations/000_combined.sql:313`). Não encontrei vector store/RAG no código clonado. | Força: memória operacional auditável. Fraqueza: não é memória semântica. | Pior que mem-vector para conhecimento; melhor como trilho transaccional que complementa o vault/vector DB. |
| recall | Direct chat injeta resultados recentes de workflows no prompt (`packages/core/src/db/messages.ts:72`, `packages/core/src/orchestrator/orchestrator-agent.ts:1127`). Resume de DAG preenche outputs já concluídos (`packages/workflows/src/store.ts:112`, `packages/workflows/src/dag-executor.ts:2903`). | Força: recall pragmático e barato. Fraqueza: limitado a resultados recentes/eventos, não busca semântica. | Melhor para continuidade de task; inferior para perguntas abertas sobre conhecimento acumulado. |
| context | Prompt inclui mensagem actual, thread context, anexos, issue context e resultados recentes (`packages/core/src/orchestrator/orchestrator-agent.ts:817`). Outputs de nós anteriores entram por `$node.output` e `$node.output.field` (`packages/workflows/src/dag-executor.ts:397`). | Força: contexto explícito e referenciável. Fraqueza: risco de prompts grandes e substituições textuais. | Melhor que agente simples porque torna dependências visíveis. Para mem-vector, mapear cada fonte de contexto como bloco citável. |
| tools | Providers normalizam tool calls/resultados para `MessageChunk` (`packages/providers/src/types.ts:178`). Claude captura `PostToolUse`/falhas por hooks (`packages/providers/src/claude/provider.ts:569`); Codex normaliza comandos, web search, ficheiros e MCP (`packages/providers/src/codex/provider.ts:427`). | Força: UI/DB vê tools uniformes. Fraqueza: semânticas diferentes por provider. | Melhor se mem-vector tiver relay Claude↔Codex; importar envelope comum de eventos. |
| system prompt/kernel | Kernel de routing constrói prompt com projectos, workflows e regras para emitir `/invoke-workflow` ou `/register-project` (`packages/core/src/orchestrator/prompt-builder.ts:142`, `packages/core/src/orchestrator/prompt-builder.ts:84`). Claude usa preset `claude_code` com append (`packages/core/src/orchestrator/orchestrator-agent.ts:1335`). | Força: política operacional explícita. Fraqueza: routing por texto/comando gerado pelo modelo é delicado. | Melhor que um agente-autor ad hoc; para mem-vector convém trocar comandos textuais por tool calls sempre que possível. |
| skills | Nó suporta `skills` e `agents` no schema (`packages/workflows/src/schemas/dag-node.ts:155`). Claude embrulha skills num agente interno `dag-node-skills` (`packages/providers/src/claude/provider.ts:345`); resolver procura `.agents/skills` e `.claude/skills` em projecto e home (`packages/providers/src/shared/skills.ts:12`). | Força: skills portáveis por filesystem. Fraqueza: colisão de IDs e suporte desigual por provider. | Melhor que agente simples se mem-vector tiver capacidades plugáveis; usar nomes e resolução explícita. |
| planning | Planeamento é uma fase de workflow/command, não módulo cognitivo separado; workflows default e comandos em `.archon/workflows/defaults/` e `.archon/commands/defaults/`. Orchestrator escolhe workflow por descrição (`packages/core/src/orchestrator/prompt-builder.ts:25`). | Força: planning é artefacto versionável. Fraqueza: qualidade depende do prompt/command. | Melhor para mem-vector: planos como nós/artefactos persistidos em vez de pensamento efémero. |
| behavior | Comandos slash determinísticos têm prioridade (`packages/core/src/orchestrator/orchestrator-agent.ts:1022`). Caso contrário, o agente decide responder ou invocar workflow e o parser intercepta o comando emitido (`packages/core/src/orchestrator/orchestrator-agent.ts:1510`, `packages/core/src/orchestrator/orchestrator-agent.ts:1635`). | Força: separa comandos seguros de linguagem natural. Fraqueza: parsing de output de modelo é uma fronteira fraca. | Melhor que simples para controlo; mem-vector deve preferir dispatch tipado/JSON. |
| subagentes/orquestração | Claude aceita `agents` inline como subagentes invocáveis via Task (`packages/workflows/src/schemas/dag-node.ts:117`, `packages/providers/src/claude/provider.ts:372`). Orquestração global é DAG + background worker conversations (`packages/core/src/orchestrator/orchestrator.ts:284`). | Força: paralelismo e especialização. Fraqueza: acoplado a capacidades Claude; Codex marca `agents: false` (`packages/providers/src/codex/capabilities.ts:8`). | Melhor se mem-vector precisar de reviewer/summarizer/archivist; pior se simplicidade e provider-neutralidade forem prioridade. |
| stop/terminação | Cancela streams por status de run, idle timeout e abort controller (`packages/workflows/src/dag-executor.ts:287`, `packages/workflows/src/dag-executor.ts:917`). Nós `cancel`, approval pause e max iterations terminam workflows (`packages/workflows/src/schemas/dag-node.ts:330`, `packages/workflows/src/dag-executor.ts:2655`). | Força: muitos pontos de stop explícitos. Fraqueza: estados `paused/running/failed` têm semântica complexa. | Melhor que simples para runs longos; importar watchdog + estados, mas manter menos estados. |
| verificação | Valida YAML com Zod, IDs únicos, deps, ciclos e refs `$node.output` (`packages/workflows/src/loader.ts:96`, `packages/workflows/src/loader.ts:134`). `output_format` é validado e pode re-perguntar em providers best-effort (`packages/workflows/src/dag-executor.ts:1215`). Bash/script nodes dão checks determinísticos (`packages/workflows/src/schemas/dag-node.ts:244`). | Força: fail-fast e schema-driven. Fraqueza: verificação semântica final ainda depende de workflow author. | Muito melhor; mem-vector deve importar schemas de outputs e validação antes de gravar memória. |
| permissões/sandbox | Claude suporta sandbox no schema e options (`packages/workflows/src/schemas/dag-node.ts:74`, `packages/providers/src/claude/provider.ts:408`), mas base usa `permissionMode: bypassPermissions` e `allowDangerouslySkipPermissions` (`packages/providers/src/claude/provider.ts:533`). Codex cria thread com `danger-full-access`, network on, approval never (`packages/providers/src/codex/provider.ts:84`). | Fraqueza séria para ambiente de conhecimento: é optimizado para coding com confiança no host. | Pior que um agente-autor simples seguro. Não importar defaults permissivos; desenhar sandbox restrito por tarefa. |
| providers | Registry tipado com factories/capabilities para Claude/Codex e community providers (`packages/providers/src/registry.ts:33`, `packages/providers/src/registry.ts:110`, `packages/providers/src/registry.ts:178`). Executor avisa quando nó usa capability não suportada (`packages/workflows/src/dag-executor.ts:535`). | Força: abstração clara e capability checks. Fraqueza: denominador comum desigual; muitos ramos provider-specific. | Melhor para relay Claude↔Codex; importar registry + capabilities, não todos os providers. |
| isolamento | Resolver escolhe worktree existente, reutilizável, branch PR ou cria novo (`packages/isolation/src/resolver.ts:57`). Factory só suporta WorktreeProvider actualmente (`packages/isolation/src/factory.ts:1`). | Força: reduz colisões entre runs. Fraqueza: pesado para vault pessoal; worktree não protege DB/vault por si. | Melhor para coding; para mem-vector importar “workspace por task” se houver escrita perigosa, não como default universal. |
| observabilidade | Eventos de workflow são armazenados e emitidos: node start/complete/fail, tool called, approvals, session resumed (`packages/workflows/src/store.ts:25`, `packages/workflows/src/dag-executor.ts:766`, `packages/workflows/src/dag-executor.ts:1031`). Logs JSONL ficam fora da DB segundo comentário de migration (`migrations/012_workflow_events.sql`). | Força: excelente para UI, resume e auditoria. Fraqueza: dois canais de verdade (DB events + logs). | Melhor que simples; mem-vector deve ter event log pequeno e append-only. |
| concurrency | Lock por conversa com fila e limite global (`packages/core/src/utils/conversation-lock.ts:1`). DAG paraleliza nós independentes por camada (`packages/workflows/src/dag-executor.ts:2963`). | Força: evita interleaving dentro da mesma conversa. Fraqueza: estado em memória de processo. | Melhor para relay/chat; para mem-vector persistir locks se houver multi-processo. |

## Pontos fortes (rankeados)
1. DAG executor com nós heterogéneos, deps, condições, retry, paralelismo e outputs reutilizáveis (`packages/workflows/src/dag-executor.ts:2865`).
2. Resume real: eventos de nós concluídos e sessões por nó permitem continuar sem repetir tudo (`packages/workflows/src/store.ts:112`, `packages/workflows/src/dag-executor.ts:2903`, `packages/core/src/db/workflow-node-sessions.ts:27`).
3. Artefactos tipados por nó (`output_type`) em ficheiros sidecar, com metadata e lookup por tipo (`packages/workflows/src/artifacts-index.ts:40`, `packages/workflows/src/dag-executor.ts:3561`).
4. Capability model por provider, com avisos quando workflow usa recursos não suportados (`packages/providers/src/registry.ts:76`, `packages/workflows/src/dag-executor.ts:538`).
5. Gates humanos e gestão de runs incorporados, incluindo approval/reject/resume/cancel (`packages/workflows/src/dag-executor.ts:2672`, `packages/core/src/orchestrator/manage-run-tool.ts:25`).

## O que vale importar para o mem-vector
- [ ] Motor DAG mínimo para knowledge tasks — usar nós `read/chat/retrieve/write/verify/relay`, deps e `when`, inspirado em `packages/workflows/src/schemas/dag-node.ts:140`.
- [ ] Event log append-only para runs de memória — `workflow_events` como trilho auditável de decisões e writes, inspirado em `migrations/000_combined.sql:263`.
- [ ] Artefactos tipados por nó — gravar `summary`, `fact`, `decision`, `task`, `daily`, `relay_message` com sidecar metadata, inspirado em `packages/workflows/src/artifacts-index.ts:40`.
- [ ] Resume por outputs concluídos — evitar reprocessar ingestões longas e permitir “continuar daily”, inspirado em `packages/workflows/src/dag-executor.ts:2903`.
- [ ] Capability registry Claude↔Codex — escolher provider conforme tools/sandbox/structured output, inspirado em `packages/providers/src/registry.ts:110`.
- [ ] Gates humanos para writes perigosos no vault — approval antes de apagar/reescrever factos ou enviar relay, inspirado em `packages/workflows/src/dag-executor.ts:2816`.
- [ ] Structured output + validação antes de persistir memória — schema obrigatório para novas facts/tasks, inspirado em `packages/workflows/src/dag-executor.ts:1240`.
- [ ] Lock por conversa/task — impedir duas mensagens a editar a mesma nota/vault em paralelo, inspirado em `packages/core/src/utils/conversation-lock.ts:37`.

## Não importar / armadilhas
- Não importar os defaults permissivos: Claude com bypass permissions e Codex `danger-full-access`/network/approval never (`packages/providers/src/claude/provider.ts:533`, `packages/providers/src/codex/provider.ts:84`).
- Não assumir que isto resolve RAG: vector DB, embeddings e retrieval semântico não encontrado no source clonado.
- Não copiar a camada multi-plataforma inteira; Slack/Telegram/GitHub/Web aumentam complexidade sem melhorar a autoria de conhecimento.
- Não depender de comandos emitidos em texto pelo modelo como API interna principal; Archon usa parsing robusto, mas mem-vector deve preferir tool calls/JSON.
- Não importar todos os estados e excepções de workflow; para mem-vector bastam `pending/running/paused/completed/failed/cancelled`.
- Não fazer worktree por tudo; útil para coding, pesado para vault/DB se o problema é transacção e lock.

## Fontes
- `clones/coleam00__Archon/package.json`
- `clones/coleam00__Archon/LICENSE`
- `clones/coleam00__Archon/AGENTS.md`
- `clones/coleam00__Archon/migrations/000_combined.sql`
- `clones/coleam00__Archon/packages/workflows/src/schemas/dag-node.ts`
- `clones/coleam00__Archon/packages/workflows/src/schemas/loop.ts`
- `clones/coleam00__Archon/packages/workflows/src/loader.ts`
- `clones/coleam00__Archon/packages/workflows/src/dag-executor.ts`
- `clones/coleam00__Archon/packages/workflows/src/store.ts`
- `clones/coleam00__Archon/packages/workflows/src/artifacts-index.ts`
- `clones/coleam00__Archon/packages/providers/src/types.ts`
- `clones/coleam00__Archon/packages/providers/src/registry.ts`
- `clones/coleam00__Archon/packages/providers/src/claude/provider.ts`
- `clones/coleam00__Archon/packages/providers/src/codex/provider.ts`
- `clones/coleam00__Archon/packages/providers/src/shared/skills.ts`
- `clones/coleam00__Archon/packages/core/src/orchestrator/orchestrator-agent.ts`
- `clones/coleam00__Archon/packages/core/src/orchestrator/orchestrator.ts`
- `clones/coleam00__Archon/packages/core/src/orchestrator/prompt-builder.ts`
- `clones/coleam00__Archon/packages/core/src/orchestrator/manage-run-tool.ts`
- `clones/coleam00__Archon/packages/core/src/db/messages.ts`
- `clones/coleam00__Archon/packages/core/src/db/sessions.ts`
- `clones/coleam00__Archon/packages/core/src/db/conversations.ts`
- `clones/coleam00__Archon/packages/core/src/db/workflow-node-sessions.ts`
- `clones/coleam00__Archon/packages/core/src/utils/conversation-lock.ts`
- `clones/coleam00__Archon/packages/isolation/src/factory.ts`
- `clones/coleam00__Archon/packages/isolation/src/resolver.ts`
