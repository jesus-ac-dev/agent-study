---
tags: [knowledge, synthesis, ai-software, agente-estudo]
created: 2026-06-22
summary: Sandcastle — harness TypeScript para executar agentes de coding em sandboxes/worktrees; importar isolamento git+sandbox, captura/retoma de sessões e output estruturado, não a lógica de produto/tarefas.
agente: Sandcastle
repo: mattpocock/sandcastle
commit: 2d93226
---

# Sandcastle — estudo de source

> Veredito: não é um agente autónomo em si; é uma biblioteca/CLI para orquestrar agentes de coding externos em sandboxes isoladas. Estudado no commit 2d93226.

## Identidade
- Sandcastle é um harness TypeScript para `run()`, `interactive()`, `createSandbox()` e `createWorktree()`, exportando providers de agente e providers de sandbox (`src/index.ts:1`, `src/index.ts:55`, `src/index.ts:74`).
- Provider: agnóstico; inclui Claude Code, Codex, Pi, Cursor, OpenCode e Copilot como CLIs externas (`src/AgentProvider.ts:628`, `src/AgentProvider.ts:773`, `src/AgentProvider.ts:837`, `src/AgentProvider.ts:959`, `src/AgentProvider.ts:1109`, `src/AgentProvider.ts:1181`). Linguagem: TypeScript/Node ESM (`package.json:5`, `package.json:65`). Licença: MIT (`package.json:64`, `LICENSE:1`).

## Anatomia (como faz cada coisa)
| Termo | Como o faz (`ficheiro`) | Força/Fraqueza | vs agente-autor simples |
|---|---|---|---|
| regressão/autoregressão | Autoregressão não é implementada: o texto vem do CLI externo via `provider.buildPrintCommand()` e stream JSON (`src/Orchestrator.ts:140`, `src/AgentProvider.ts:264`). Regressão existe como retry de output estruturado: se o XML/JSON falha, retoma a sessão com feedback curto (`src/run.ts:52`, `src/run.ts:842`). | Força: separa execução do modelo e valida output. Fraqueza: sem controlo interno sobre decoding/raciocínio; retry só cobre output, não qualidade de tarefa. | Melhor que um agente-autor simples para contratos de output; pior para adaptar comportamento cognitivo, porque delega tudo ao provider. |
| loop | `orchestrate()` corre `for (let i = 1; i <= iterations; i++)`, invoca agente, captura sessão, testa completion signal e pára cedo (`src/Orchestrator.ts:355`, `src/Orchestrator.ts:474`, `src/Orchestrator.ts:575`). `run()` define `DEFAULT_MAX_ITERATIONS = 1` (`src/run.ts:90`). | Força: loop pequeno, explícito, observável. Fraqueza: não há loop deliberativo próprio nem política de escolha de próxima tarefa fora do prompt/template. | Melhor operacionalmente; mais simples que um agente-autor completo, mas menos inteligente sem uma camada de agenda/memória. |
| harness | `run()` resolve cwd, prompt, env, branch, logging e layers Effect antes de chamar `orchestrate()` (`src/run.ts:493`, `src/run.ts:582`, `src/run.ts:618`, `src/run.ts:741`). `SandboxFactory` encapsula worktree, sandbox e cleanup (`src/SandboxFactory.ts:153`, `src/SandboxFactory.ts:290`). | Força: excelente separação de harness vs provider. Fraqueza: bastante infra para um agente local simples. | Muito melhor que um agente-autor simples para execução repetível e isolada. |
| memory | Não há vault, DB, embeddings ou RAG encontrados. A memória é sessão JSONL do provider: Claude/Codex/Pi capturam e reescrevem paths de sessão entre sandbox e host (`src/AgentProvider.ts:352`, `src/AgentProvider.ts:441`, `src/AgentProvider.ts:495`; `src/SessionStore.ts:153`, `src/SessionStore.ts:276`, `src/SessionStore.ts:389`). | Força: retoma conversas reais do provider. Fraqueza: memória opaca, filesystem-specific, sem indexação semântica nem curadoria. | Pior que mem-vector deve ser em conhecimento durável; melhor como mecanismo de continuação fiel de sessões Claude/Codex. |
| recall | Recall = localizar sessão por ID no host e injectá-la na sandbox antes da iteração 1 (`src/SessionStore.ts:131`, `src/SessionStore.ts:234`, `src/Orchestrator.ts:379`). `run()` expõe `.resume()` e `.fork()` com último `sessionId` (`src/run.ts:801`). | Força: bom modelo de continuidade/fan-out. Fraqueza: só por ID, não por consulta semântica; `resumeSession` não suporta multi-iteration (`src/run.ts:534`). | Importável para relay Claude↔Codex; insuficiente para recall de conhecimento. |
| context | Contexto vem de `prompt`/`promptFile`, `promptArgs`, built-ins `SOURCE_BRANCH`/`TARGET_BRANCH`, e shell expansion do padrão `!` + bloco entre backticks executado dentro da sandbox (`src/PromptResolver.ts:23`, `src/PromptArgumentSubstitution.ts:19`, `src/run.ts:713`, `src/PromptPreprocessor.ts:23`). | Força: contexto fresco e reproduzível a partir de comandos. Fraqueza: shell expansion em prompts aumenta superfície de risco e custo; sem orçamento/context packing sofisticado. | Melhor que prompt hardcoded simples; pior que mem-vector com seleção RAG e compressão. |
| tools | Não implementa ferramentas LLM próprias; executa ferramentas disponíveis no CLI provider e apenas parseia tool calls allowlisted para display (`src/AgentProvider.ts:43`, `src/AgentProvider.ts:67`, `src/AgentProvider.ts:699`). Também expõe hooks host/sandbox (`src/SandboxLifecycle.ts:86`). | Força: provider-agnostic e observável. Fraqueza: não há schema de tools unificado nem autorização semântica. | Melhor para interop com CLIs existentes; pior para um agente-autor que quer tools tipadas e auditáveis. |
| system prompt/kernel | Kernel real é o prompt/template; não encontrei system prompt interno persistente. Templates definem persona RALPH, workflow RGR, regras de commit e completion signal (`src/templates/simple-loop/prompt.md:13`, `src/templates/simple-loop/prompt.md:28`, `src/templates/simple-loop/prompt.md:51`). | Força: kernel editável por ficheiro. Fraqueza: comportamento crítico vive em prompt prose, não em código verificável. | Igual ou ligeiramente melhor que agente simples se os templates forem versionados; pior que políticas codificadas para memória/tarefas. |
| skills | Skills como sistema interno: não encontrado. Há templates scaffoldáveis (`blank`, `simple-loop`, `sequential-reviewer`, `parallel-planner`, `parallel-planner-with-review`) em registry (`src/InitService.ts:32`) e instruções locais em `AGENTS.md` (`AGENTS.md:9`). | Força: templates são bons padrões de workflow. Fraqueza: não há skill loading/routing runtime. | Melhor como starter kit; pior que mem-vector se este precisar de skills invocáveis por intenção. |
| planning | O core não planeia. O template `parallel-planner` usa um agente Opus para emitir `<plan>` validado por Zod/Standard Schema (`src/templates/parallel-planner/main.mts:23`, `src/templates/parallel-planner/main.mts:68`, `src/templates/parallel-planner/plan-prompt.md:15`). | Força: planning é uma fase explícita com output estruturado. Fraqueza: só no template; se o plano for mau, o harness não o corrige salvo validação estrutural. | Melhor que agente simples por separar plan/execute/merge; importar como padrão, não como motor pronto. |
| behavior | Comportamento vem de prompts: explorar, planear, RGR, verificar, commit, fechar issue (`src/templates/simple-loop/prompt.md:28`). O harness só garante execução/branch/logs. | Força: fácil adaptar. Fraqueza: sem enforcement forte de “um issue por iteração” excepto instrução textual. | Similar a agente simples; o valor está na disciplina de template mais do que em código. |
| subagentes/orquestração | Orquestração existe em templates: implementer→reviewer sequencial partilhando sandbox (`src/templates/sequential-reviewer/main.mts:50`, `src/templates/sequential-reviewer/main.mts:79`, `src/templates/sequential-reviewer/main.mts:103`) e planner→N implementers em `Promise.allSettled`→merger (`src/templates/parallel-planner/main.mts:68`, `src/templates/parallel-planner/main.mts:108`, `src/templates/parallel-planner/main.mts:185`). Captura também transcripts de subagentes Claude best-effort (`src/AgentProvider.ts:385`). | Força: padrões claros de fan-out/fan-in. Fraqueza: merge/review dependem de agentes e git; não há scheduler persistente. | Muito melhor que agente-autor simples para paralelismo; falta fila/task DB para mem-vector. |
| stop/terminação | Completion signal default `<promise>COMPLETE</promise>`, idle timeout de 10 min, grace timeout pós-sinal de 60s, abort signal e limite de iterações (`src/Orchestrator.ts:246`, `src/Orchestrator.ts:52`, `src/Orchestrator.ts:575`, `src/run.ts:365`, `src/run.ts:399`). | Força: terminação operacional robusta contra hangs. Fraqueza: stop semântico é string matching em stdout. | Melhor que agente simples; importar quase directamente. |
| verificação | O harness valida exit code, commits, output estruturado XML/JSON+schema, timeouts e recolha de commits (`src/Orchestrator.ts:191`, `src/extractStructuredOutput.ts:16`, `src/SandboxLifecycle.ts:485`). Verificação de código fica no prompt/template: `npm run typecheck` e `npm run test` (`src/templates/simple-loop/prompt.md:33`). | Força: contratos estruturados fortes. Fraqueza: testes são instrução ao agente, não etapa obrigatória do harness salvo hooks custom. | Melhor em output; pior que um autor simples bem integrado se este executar checks obrigatórios fora do LLM. |
| permissões/sandbox | Providers de sandbox têm tags `bind-mount`, `isolated`, `none` (`src/SandboxProvider.ts:161`, `src/SandboxProvider.ts:180`, `src/SandboxProvider.ts:228`). `run()` recusa `head` com isolated e `copyToWorktree` em head (`src/run.ts:515`, `src/run.ts:522`). Docker cria container com UID/GID, mounts, network/devices/cpus (`src/sandboxes/docker.ts:37`, `src/sandboxes/docker.ts:147`, `src/sandboxes/docker.ts:173`). Providers de agente usam bypass por default em AFK, salvo modos específicos (`src/AgentProvider.ts:1196`, `src/AgentProvider.ts:790`). | Força: isolamento e branch strategy bem pensados. Fraqueza: `noSandbox` e bypass permissions são perigosos se usados sem política. | Muito melhor que agente simples, desde que mem-vector mantenha defaults conservadores. |
| providers | Interface `AgentProvider` normaliza `env`, sessão, comando print/interactive e parser de stream (`src/AgentProvider.ts:264`). Interface `SandboxProvider` normaliza exec/copy/close e branch strategies (`src/SandboxProvider.ts:23`, `src/SandboxProvider.ts:243`). Init regista agentes e sandboxes (`src/InitService.ts:411`, `src/InitService.ts:597`). | Força: plugin surface pequena e pragmática. Fraqueza: cada provider tem parsing ad hoc do JSONL. | Melhor que hardcode Claude/Codex; importar a ideia de contrato fino. |
| observability | Expõe eventos de stream parseados e raw para callback/log (`clones/mattpocock__sandcastle/src/AgentStreamEmitter.ts:3`, `clones/mattpocock__sandcastle/src/run.ts:218`, `clones/mattpocock__sandcastle/src/run.ts:271`); escreve logs em ficheiro com delimitador e tempos por task (`clones/mattpocock__sandcastle/src/Display.ts:141`); emite texto/tool/raw por iteração com timestamp (`clones/mattpocock__sandcastle/src/Orchestrator.ts:423`); captura `sessionId`, `sessionFilePath` e `usage` por iteração (`clones/mattpocock__sandcastle/src/Orchestrator.ts:292`, `clones/mattpocock__sandcastle/src/Orchestrator.ts:502`). | Forte para debug/auditoria operacional de corridas; fraqueza: não há traces/spans distribuídos nem ledger/custo completo, só tokens/context window e logs/JSONL. | Mais operacional que mem-vector: serve para observar a execução que alimentaria memória, não para recordar factos. |
| evidência/proveniência | não encontrado | Fraqueza: há sessões/logs/commits rastreáveis, mas outputs estruturados não obrigam citações nem `source` por facto. | Menos útil que mem-vector se a comparação for memória com fontes; Sandcastle só preserva artefactos da corrida. |
| evals/avaliação | não encontrado | Fraqueza: existem testes normais (`clones/mattpocock__sandcastle/package.json:40`), mas não datasets de qualidade do agente, regressões comportamentais ou LLM-as-judge. | Sem vantagem face a mem-vector nesta dimensão. |
| untrusted-input | Distingue prompt inline literal de template processável (`clones/mattpocock__sandcastle/src/PromptResolver.ts:10`); marca apenas shell blocks escritos no template e trata `!`...`` vindos de `promptArgs` como dados (`clones/mattpocock__sandcastle/src/PromptPreprocessor.ts:9`, `clones/mattpocock__sandcastle/src/PromptArgumentSubstitution.ts:92`); remove marcadores injetados em args (`clones/mattpocock__sandcastle/src/PromptArgumentSubstitution.ts:98`); documenta que conteúdo de issues/PR/docs em `promptArgs` não executa shell (`clones/mattpocock__sandcastle/README.md:624`). | Forte contra injeção de shell via argumentos de prompt; fraqueza: não marca conteúdo recuperado como untrusted no prompt do modelo, nem há defesa explícita de prompt injection, SSRF/DNS ou allowlist de web. | Importável para mem-vector como fronteira entre template confiável e conteúdo recuperado/user-authored. |
| human-steering | Tem modo `interactive()` com TUI direta do agente (`clones/mattpocock__sandcastle/src/interactive.ts:103`) e liga stdin/stdout/stderr ao processo interativo (`clones/mattpocock__sandcastle/src/interactive.ts:401`); recolhe `promptArgs` em falta via `clack.text` e permite cancelar (`clones/mattpocock__sandcastle/src/interactive.ts:199`); aceita `AbortSignal` para cancelar corridas (`clones/mattpocock__sandcastle/src/run.ts:398`); suporta modos de permissão/approval dos providers (`clones/mattpocock__sandcastle/src/AgentProvider.ts:761`, `clones/mattpocock__sandcastle/src/AgentProvider.ts:1166`). | Forte para steering manual/interrupção em modo interativo; fraqueza: o modo AFK tende a bypass/auto-approval dentro da sandbox, sem fila própria de aprovações Sandcastle. | Mais forte que mem-vector em controlo de execução; mem-vector precisaria de fila de steering se correr ações. |
| concorrência/multi-sessão | Templates lançam N agentes em paralelo com `Promise.allSettled`, cada um numa branch própria (`clones/mattpocock__sandcastle/src/templates/parallel-planner/main.mts:7`, `clones/mattpocock__sandcastle/src/templates/parallel-planner/main.mts:108`, `clones/mattpocock__sandcastle/src/templates/parallel-planner/main.mts:115`); `fork()` isola só a sessão e avisa que fan-out seguro requer branches distintas (`clones/mattpocock__sandcastle/src/run.ts:463`, `clones/mattpocock__sandcastle/README.md:952`); branches temporárias recebem sufixo aleatório para evitar colisões (`clones/mattpocock__sandcastle/src/WorktreeManager.ts:32`, `clones/mattpocock__sandcastle/src/WorktreeManager.ts:73`); deteta worktree/branch já checkout e falha ou reutiliza (`clones/mattpocock__sandcastle/src/WorktreeManager.ts:331`). | Forte para paralelismo por branch/sandbox; fraqueza: não encontrei lock ativo em `src`, e a própria doc de fork diz que `head`/`merge-to-head` não são seguros para forks concorrentes. | Mais maduro que mem-vector para isolamento por execução; armadilha se mem-vector copiar fan-out sem isolamento de estado escrito. |

## Pontos fortes (rankeados)
1. Harness de sandbox/worktree/branch robusto: cria worktrees, corre em container/isolated/no-sandbox, preserva worktree suja e recolhe commits (`src/SandboxFactory.ts:187`, `src/SandboxFactory.ts:392`, `src/SandboxLifecycle.ts:404`).
2. Captura/retoma/fork de sessões Claude/Codex/Pi com reescrita de cwd, útil para relay e fan-out (`src/SessionStore.ts:153`, `src/run.ts:801`).
3. Output estruturado com validação Standard Schema e retry via sessão retomada (`src/Output.ts:67`, `src/run.ts:842`).
4. Terminação prática: completion signal, idle timeout, completion grace window e abort signal (`src/Orchestrator.ts:52`, `src/Orchestrator.ts:246`, `src/run.ts:399`).
5. Templates de orquestração multi-agente que separam plan/execute/review/merge (`src/templates/parallel-planner/main.mts:1`, `src/templates/parallel-planner-with-review/main.mts:1`).

## O que vale importar para o mem-vector
- [ ] Contrato `AgentProvider`/`SandboxProvider` fino — encaixa na camada relay Claude↔Codex para trocar provider sem mudar o loop.
- [ ] Captura/retoma/fork de sessões por provider — usar como ponte operacional, separada da memória semântica do vault/DB.
- [ ] Completion signal + idle/completion timeouts — encaixa no runner de tasks/daily para impedir runs pendurados.
- [ ] Output estruturado com schema + retry por sessão — encaixa em tarefas que têm de devolver decisões, diffs, planos ou entradas de knowledge base.
- [ ] Templates plan→execute→review→merge como blueprints — adaptar para task queues do mem-vector, substituindo issues por entradas do vault/daily.
- [ ] Shell expansion controlada em prompt templates — útil para contexto fresco (`git log`, tasks), mas só com allowlist/quoting e logs.
- [ ] Preservação de artefactos em falha — worktree/patch/session paths devem ser first-class no mem-vector para auditoria e recuperação.
- [ ] `onAgentStreamEvent` + raw verbose stream - dá a mem-vector um gancho simples para audit/debug sem acoplar ao logger principal.
- [ ] Marcação de shell blocks confiáveis antes de substituir argumentos - encaixa onde mem-vector injeta conteúdo recuperado/user-authored em prompts.
- [ ] Fan-out só com branch/sandbox/sessão explicitamente isolados - encaixa em qualquer modo paralelo de mem-vector que escreva ficheiros ou memória partilhada.

## Não importar / armadilhas
- Não importar a “memória” como memória de produto: é apenas sessão JSONL de CLI, sem RAG, sem vault e sem recall semântico.
- Não importar `dangerously-skip-permissions`/`danger-full-access` como default para mem-vector; em vault/DB, permissões devem ser explícitas e por ferramenta.
- Não depender de stop por string em stdout como única garantia; usar também estado persistido da task e checks externos.
- Não deixar comportamento crítico só em prompts longos; para mem-vector, policies de escrita no vault, deduplicação, tags e provenance devem estar em código.
- Não copiar shell expansion livre em prompts; é conveniente mas pode virar execução arbitrária se argumentos vierem de chat/tasks.
- Não assumir que providers não-resumable equivalem a relay completo: Cursor/OpenCode/Copilot não têm `sessionStorage` neste source (`src/AgentProvider.ts:843`, `src/AgentProvider.ts:965`, `src/AgentProvider.ts:1115`).
- Não tratar validação de `Output.object` como eval: é parsing/verificação de formato, não avaliação sistemática de qualidade.
- Não copiar o bypass de permissões como default fora de uma sandbox forte.
- Não assumir que `fork()` resolve concorrência: no próprio Sandcastle, fork isola sessão, não branch/worktree/sandbox.
- Não contar logs e session JSONL como proveniência factual: ajudam auditoria da corrida, mas não ligam cada facto a uma fonte.

## Fontes
- `clones/mattpocock__sandcastle/package.json`
- `clones/mattpocock__sandcastle/LICENSE`
- `clones/mattpocock__sandcastle/AGENTS.md`
- `clones/mattpocock__sandcastle/src/index.ts`
- `clones/mattpocock__sandcastle/src/run.ts`
- `clones/mattpocock__sandcastle/src/Orchestrator.ts`
- `clones/mattpocock__sandcastle/src/AgentProvider.ts`
- `clones/mattpocock__sandcastle/src/SessionStore.ts`
- `clones/mattpocock__sandcastle/src/SandboxProvider.ts`
- `clones/mattpocock__sandcastle/src/SandboxFactory.ts`
- `clones/mattpocock__sandcastle/src/SandboxLifecycle.ts`
- `clones/mattpocock__sandcastle/src/startSandbox.ts`
- `clones/mattpocock__sandcastle/src/WorktreeManager.ts`
- `clones/mattpocock__sandcastle/src/syncOut.ts`
- `clones/mattpocock__sandcastle/src/PromptResolver.ts`
- `clones/mattpocock__sandcastle/src/PromptArgumentSubstitution.ts`
- `clones/mattpocock__sandcastle/src/PromptPreprocessor.ts`
- `clones/mattpocock__sandcastle/src/Output.ts`
- `clones/mattpocock__sandcastle/src/extractStructuredOutput.ts`
- `clones/mattpocock__sandcastle/src/AgentStreamEmitter.ts`
- `clones/mattpocock__sandcastle/src/InitService.ts`
- `clones/mattpocock__sandcastle/src/interactive.ts`
- `clones/mattpocock__sandcastle/src/createSandbox.ts`
- `clones/mattpocock__sandcastle/src/sandboxes/docker.ts`
- `clones/mattpocock__sandcastle/src/templates/simple-loop/main.mts`
- `clones/mattpocock__sandcastle/src/templates/simple-loop/prompt.md`
- `clones/mattpocock__sandcastle/src/templates/sequential-reviewer/main.mts`
- `clones/mattpocock__sandcastle/src/templates/sequential-reviewer/implement-prompt.md`
- `clones/mattpocock__sandcastle/src/templates/sequential-reviewer/review-prompt.md`
- `clones/mattpocock__sandcastle/src/templates/parallel-planner/main.mts`
- `clones/mattpocock__sandcastle/src/templates/parallel-planner/plan-prompt.md`
- `clones/mattpocock__sandcastle/src/templates/parallel-planner/merge-prompt.md`
- `clones/mattpocock__sandcastle/src/templates/parallel-planner-with-review/main.mts`
