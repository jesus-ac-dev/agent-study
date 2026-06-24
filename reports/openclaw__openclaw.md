---
tags: [knowledge, synthesis, ai-software, agente-estudo]
created: 2026-06-22
summary: OpenClaw — runtime/plataforma de agentes real, com memória híbrida e bom isolamento de harness/tooling; vale importar sobretudo o contrato de memória, recall híbrido e terminação explícita para o mem-vector.
agente: OpenClaw
repo: openclaw/openclaw
commit: e9756f9e
---

# OpenClaw — estudo de source

> Veredito: É um agente/plataforma real, não uma demo: um gateway multi-canal com runner de agentes, harnesses, memória, plugins, sandbox e subagentes. Para o mem-vector, o valor está menos no tamanho da plataforma e mais nos padrões de memória/recall/flush, terminação e isolamento de ferramentas. Estudado no commit e9756f9e.

## Identidade
- OpenClaw é descrito no pacote como "Multi-channel AI gateway with extensible messaging integrations"; é Node/TypeScript ESM, com binário `openclaw` e licença MIT (`package.json:2-17`).
- Suporta providers e runtimes por plugins; o código mostra integrações OpenAI, Anthropic, Google, Ollama, OpenRouter, Codex/Copilot e outros via `extensions/*/openclaw.plugin.json`, com normalização em `src/plugins/provider-runtime.ts:100-123`.

## Anatomia (como faz cada coisa)
| Termo | Como o faz (`ficheiro`) | Força/Fraqueza | vs agente-autor simples |
|---|---|---|---|
| regressão/autoregressão | Regressão/treino não encontrado. A geração autoregressiva é delegada ao provider/harness: o runner escolhe provider/modelo e passa a tentativa para `runEmbeddedAttemptWithBackend`/`runAgentHarnessAttempt` (`src/agents/embedded-agent-runner/run.ts:1064-1125`, `src/agents/harness/selection.ts:300-340`). | Força: não mistura runtime com treino/model serving. Fraqueza: muita lógica de compatibilidade e fallback externa ao agente. | Melhor do que um agente-autor simples se houver vários providers; pior se o mem-vector só precisar de 1-2 modelos e controlo previsível. |
| loop | `runEmbeddedAgent` entra no runner com filas por sessão/lane, aborts e timeouts (`src/agents/embedded-agent-runner/run.ts:597-780`). A tentativa principal vive num `while (true)` com limite de retries, compaction em overflow e reentrada após falha recuperável (`src/agents/embedded-agent-runner/run.ts:1872-1907`, `src/agents/embedded-agent-runner/run.ts:2407-2680`). | Força: robusto para sessões longas e falhas de contexto. Fraqueza: loop pesado, difícil de auditar. | Melhor para gateway multiutilizador; para mem-vector convém importar só a ideia de estados/retries explícitos, não o loop inteiro. |
| harness | Há contrato `AgentHarness` com `runAttempt`, side questions, classificação, compactação e reset (`src/agents/harness/types.ts:86-125`). A seleção separa built-in OpenClaw de harnesses plugin e falha fechado quando um plugin explícito falha (`src/agents/harness/selection.ts:156-340`). | Força: separação limpa entre runner e executor. Fraqueza: seleção e políticas tornam-se complexas. | Melhor se mem-vector fizer relay Claude↔Codex; excessivo para um único executor local. |
| memory | A memória é uma capability plugin com `promptBuilder`, `flushPlanResolver`, runtime e artefactos públicos (`src/plugins/memory-state.ts:130-185`). O plugin `memory-core` regista essa capability e ferramentas `memory_search`/`memory_get` (`extensions/memory-core/index.ts:178-234`). | Força: memória desacoplada do loop e extensível. Fraqueza: várias camadas de inicialização/cache. | Muito melhor do que memória embebida num prompt; mem-vector deve copiar o contrato, simplificando a implementação. |
| recall | `memory_search` é ferramenta explícita com timeout, cooldown, corpus `memory/wiki/all/session`, retry de sync e citações (`extensions/memory-core/src/tools.ts:48-51`, `extensions/memory-core/src/tools.ts:362-631`). A pesquisa combina FTS, embeddings, MMR, decay temporal e fallback lexical (`extensions/memory-core/src/memory/manager.ts:667-814`). | Força: recall auditável e degradável. Fraqueza: muitos knobs podem esconder erros de ranking. | Melhor do que RAG simples por vetor puro; mem-vector deve importar FTS+vector+exact-get. |
| context | Resolve janelas de contexto por catálogo/provider/config (`src/agents/context-resolution.ts:167-255`), aplica guardas de threshold/block (`src/agents/context-window-guard.ts:53-98`, `src/agents/context-window-guard.ts:202-228`), injeta bootstrap files e evita reinjeção após marcador (`src/agents/bootstrap-files.ts:63-148`). | Força: trata contexto como orçamento real. Fraqueza: muita heurística provider-specific. | Melhor em sessões longas; mem-vector precisa só de orçamento, resumo e proveniência por artefacto. |
| tools | `createOpenClawCodingTools` monta ferramentas com contexto de agente/sessão/sandbox/provider/políticas (`src/agents/agent-tools.ts:426-620`). Filtra por políticas de provider/modelo e camadas de configuração (`src/agents/agent-tools.ts:271-312`, `src/agents/agent-tools.policy.ts:148-183`). | Força: superfície de tools controlada por contexto. Fraqueza: risco de complexidade acidental. | Melhor para plataforma; mem-vector deve importar policy layering mínimo: core, memória, filesystem, relay. |
| system prompt/kernel | Kernel construído por `system-prompt.ts`: inclui viés de execução, subagentes, segurança, sandbox, tools, skills e memória (`src/agents/system-prompt.ts:449-519`, `src/agents/system-prompt.ts:930-966`, `src/agents/system-prompt.ts:1045-1142`). Usa cache de prefixo estável (`src/agents/system-prompt.ts:1001-1044`). | Força: prompt modular com partes estáveis. Fraqueza: muita política em texto. | Melhor que prompt monolítico; para mem-vector, regras críticas devem viver em código/DB e só expor instruções curtas. |
| skills | O prompt manda descobrir skills disponíveis e ler `SKILL.md` antes de usar (`src/agents/system-prompt.ts:269-284`). O repo inclui skills como `skills/coding-agent/SKILL.md` e `skills/obsidian/SKILL.md`. | Força: capacidades procedimentais versionadas. Fraqueza: dependência disciplinar do modelo para cumprir leitura. | Útil para mem-vector como runbooks de vault/relay, mas não como substituto de validação programática. |
| planning | Ferramenta `update_plan` impõe estados `pending/in_progress/completed` e no máximo um item em progresso (`src/agents/tools/update-plan-tool.ts:14-37`, `src/agents/tools/update-plan-tool.ts:82-103`). Ferramentas de goal exigem criação explícita e bloqueio só após repetição do mesmo blocker (`src/agents/tools/goal-tools.ts:37-149`). | Força: planeamento observável e compacto. Fraqueza: não prova execução. | Melhor que planos livres no chat; mem-vector deve ligar isto a tasks/daily. |
| behavior | O comportamento base exige agir no turno, continuar até terminado/bloqueado, exigir evidência e usar subagentes para trabalho longo (`src/agents/system-prompt.ts:449-463`). A memória acrescenta instruções de recall obrigatório antes de trabalho prévio/decisões/datas/pessoas/preferências/todos (`extensions/memory-core/src/prompt-section.ts:4-39`). | Força: boas normas operacionais. Fraqueza: depende de adesão do modelo. | Importar como policy curta; melhor reforçar com ferramentas que detectem falta de recall quando há termos de memória. |
| subagentes/orquestração | `sessions_spawn` cria sessões subagente/ACP com policy herdada, sandbox e contexto configuráveis (`src/agents/tools/sessions-spawn-tool.ts:1-5`, `src/agents/tools/sessions-spawn-tool.ts:162-250`). `subagent-spawn.ts` impõe profundidade máxima, agentes permitidos, sandbox inheritance, thread binding e contexto isolado/forked (`src/agents/subagent-spawn.ts:1166-1282`, `src/agents/subagent-spawn.ts:1338-1592`). | Força: isolamento e controlo de fan-out. Fraqueza: bastante maquinaria. | Melhor para relay Claude↔Codex; para mem-vector, importar só fila, estado e restrições de sandbox. |
| stop/terminação | Terminal outcome normaliza `completed`, `failed`, `blocked`, `aborted`, `cancelled`, `hard_timeout` e preserva estados sticky (`src/agents/agent-run-terminal-outcome.ts:17-38`, `src/agents/agent-run-terminal-outcome.ts:97-221`). Lifecycle calcula terminal liveness/replay invalid e emite stopReason/yielded/timeout/provider/abort (`src/agents/embedded-agent-subscribe.handlers.lifecycle.ts:59-218`). | Força: fim de execução é estado de primeira classe. Fraqueza: semântica extensa. | Muito melhor do que "acabou quando o texto parou"; mem-vector deve importar diretamente um enum simples de terminação. |
| verificação | Harness lifecycle emite diagnósticos e classifica resultados (`src/agents/harness/lifecycle.ts:201-260`). Há testes para runner, tools e memória, incluindo `src/agents/embedded-agent-runner.e2e.test.ts`, `src/agents/agent-tools.before-tool-call.e2e.test.ts`, `extensions/memory-core/src/tools.test.ts` e `extensions/memory-core/src/memory/manager-search.test.ts`. Verificador semântico autónomo de tarefas não encontrado. | Força: boa cobertura técnica do runtime. Fraqueza: verificação de "tarefa feita" fica sobretudo em prompt/tools. | Mem-vector deve ter verificações específicas: nota criada, índice atualizado, task fechada, relay entregue. |
| permissões/sandbox | FS policy limita roots e workspaceOnly (`src/agents/tool-fs-policy.ts:15-64`). Exec filtra env perigoso e gere aprovação em duas fases (`src/agents/bash-tools.exec.ts:124-143`, `src/agents/bash-tools.exec-approval-request.ts:141-185`). Subagente sandboxed não pode criar filho unsandboxed nem mudar `cwd` fora do permitido (`src/agents/subagent-spawn.ts:1250-1282`). | Força: fronteiras explícitas. Fraqueza: muitas combinações policy/profile. | Melhor do que permissões ad hoc; mem-vector deve importar allow/deny por ferramenta e root de vault. |
| providers | Providers são plugins normalizados por id/aliases/hook aliases (`src/plugins/provider-runtime.ts:100-123`), descobrem modelos por hooks e compat (`src/agents/agent-model-discovery.ts:41-86`), e podem contribuir system prompt/model overlays (`src/plugins/provider-runtime.ts:215-239`). | Força: portabilidade. Fraqueza: superfície enorme para um agente-autor. | Pior para mem-vector se importado inteiro; manter interface pequena `generate/embed/rerank/transcribe` chega. |

## Pontos fortes (rankeados)
1. Memória como capability modular, não como detalhe do runner (`src/plugins/memory-state.ts:130-185`, `extensions/memory-core/index.ts:178-234`).
2. Recall híbrido robusto: FTS + vector + MMR + decay temporal + fallback lexical + citações (`extensions/memory-core/src/memory/manager.ts:667-814`, `extensions/memory-core/src/tools.ts:415-631`).
3. Flush pré-compaction para ficheiros duráveis `memory/YYYY-MM-DD.md`, com thresholds e regras append-only (`extensions/memory-core/src/flush-plan.ts:12-34`, `extensions/memory-core/src/flush-plan.ts:97-141`).
4. Terminação e liveness como dados estruturados, incluindo timeout, abort, yielded e replay invalid (`src/agents/agent-run-terminal-outcome.ts:17-221`, `src/agents/embedded-agent-subscribe.handlers.lifecycle.ts:59-218`).
5. Harness/runner separados, permitindo relay e executores alternativos sem reescrever a orquestração (`src/agents/harness/types.ts:86-125`, `src/agents/harness/selection.ts:156-340`).
6. Sandbox e tool policy herdáveis para subagentes (`src/agents/agent-tools.policy.ts:46-113`, `src/agents/subagent-spawn.ts:1250-1282`).
7. Promoção de short-term recalls por contagem, dias, queries e score antes de virar memória durável (`extensions/memory-core/src/short-term-promotion.ts:47-127`).

## O que vale importar para o mem-vector
- [ ] Contrato de memória separado do loop — `promptBuilder`, `flushPlanResolver`, `runtime` e artefactos públicos; encaixa como fronteira entre vault/DB e agente-autor (`src/plugins/memory-state.ts:130-185`).
- [ ] Flush plan antes de compactar — escrever só memórias duráveis em `memory/YYYY-MM-DD.md`, com token de flush silencioso; encaixa em daily notes e preservação de decisões (`extensions/memory-core/src/flush-plan.ts:12-34`).
- [ ] Recall híbrido com degradação explícita — FTS primeiro, vector quando disponível, MMR/decay temporal, fallback lexical e resultado `unavailable` com ação sugerida; encaixa no RAG do vault (`extensions/memory-core/src/memory/manager.ts:667-814`, `extensions/memory-core/src/tools.shared.ts:108-140`).
- [ ] Par `memory_search` + `memory_get` — procurar por relevância e depois obter excertos exactos por linhas/citações; encaixa na disciplina "evidência antes de síntese" (`extensions/memory-core/src/tools.ts:362-735`).
- [ ] Short-term recall promotion — guardar recalls recorrentes e promover só quando há score/contagem/dias suficientes; encaixa em aprendizagem gradual sem poluir o vault (`extensions/memory-core/src/short-term-promotion.ts:47-127`).
- [ ] Maintenance/cron isolado para promoção — job gerido que corre como agent turn separado; encaixa em daily review e limpeza de knowledge base (`extensions/memory-core/src/dreaming.ts:158-187`).
- [ ] Enum simples de terminação — `completed/failed/blocked/aborted/cancelled/hard_timeout`; encaixa no relay Claude↔Codex e em tasks longas (`src/agents/agent-run-terminal-outcome.ts:17-221`).
- [ ] Harness mínimo para relay — uma interface `supports/runAttempt/classify/compact` permite trocar executor Codex/Claude sem mexer no vault (`src/agents/harness/types.ts:86-125`).
- [ ] Policy layering de tools — core + vault root + sandbox + subagente herdado, com deny explícito; encaixa em permissões de escrita no vault (`src/agents/agent-tools.policy.ts:148-183`, `src/agents/tool-fs-policy.ts:15-64`).
- [ ] Plan/goals ligados a tasks/daily — `update_plan` com um item `in_progress` e `goal` com bloqueio repetido; encaixa directamente em tasks persistentes (`src/agents/tools/update-plan-tool.ts:14-103`, `src/agents/tools/goal-tools.ts:37-149`).

## Não importar / armadilhas
- Não importar a plataforma inteira de providers/plugins/canais; para mem-vector, uma interface pequena por capacidade é mais auditável (`src/plugins/provider-runtime.ts:100-123`).
- Não copiar o loop completo de retry/failover/compaction; ele resolve problemas de gateway que um agente-autor simples não deve herdar (`src/agents/embedded-agent-runner/run.ts:1872-2680`).
- Não usar `memory-lancedb` como base principal: é plugin separado/legado com LanceDB e embeddings OpenAI, menos alinhado com o núcleo SQLite/FTS/vector (`extensions/memory-lancedb/index.ts:1-7`, `extensions/memory-lancedb/lancedb-runtime.ts:41-78`).
- Não pôr demasiadas garantias em texto de system prompt; regras críticas de vault, permissões e task state devem ser verificadas em código (`src/agents/system-prompt.ts:1045-1142`).
- Não importar subagentes profundos/thread binding/canais se o primeiro caso de uso é vault local; começar por uma fila relay com estados claros (`src/agents/subagent-spawn.ts:1166-1282`).
- Não aceitar ranking RAG opaco: se houver MMR/decay/fallback, expor debug/citações/scores para auditoria (`extensions/memory-core/src/tools.ts:415-631`).
- Não deixar auto-promoção escrever memória canónica sem thresholds e revisão; OpenClaw já evita isso com contagens/dias/scores (`extensions/memory-core/src/short-term-promotion.ts:47-127`).

## Fontes
- `package.json`
- `src/agents/embedded-agent-runner.ts`
- `src/agents/embedded-agent-runner/run.ts`
- `src/agents/embedded-agent-runner/run/backend.ts`
- `src/agents/harness/types.ts`
- `src/agents/harness/selection.ts`
- `src/agents/harness/builtin-openclaw.ts`
- `src/agents/harness/lifecycle.ts`
- `src/agents/embedded-agent-subscribe.handlers.ts`
- `src/agents/embedded-agent-subscribe.handlers.lifecycle.ts`
- `src/agents/agent-run-terminal-outcome.ts`
- `src/agents/system-prompt.ts`
- `src/agents/agent-tools.ts`
- `src/agents/agent-tools.policy.ts`
- `src/agents/tools/update-plan-tool.ts`
- `src/agents/tools/goal-tools.ts`
- `src/agents/tools/sessions-spawn-tool.ts`
- `src/agents/subagent-spawn.ts`
- `src/agents/tool-fs-policy.ts`
- `src/agents/bash-tools.exec.ts`
- `src/agents/bash-tools.exec-approval-request.ts`
- `src/agents/context.ts`
- `src/agents/context-resolution.ts`
- `src/agents/context-window-guard.ts`
- `src/agents/bootstrap-files.ts`
- `src/agents/agent-model-discovery.ts`
- `src/plugins/provider-runtime.ts`
- `src/plugins/memory-state.ts`
- `extensions/memory-core/index.ts`
- `extensions/memory-core/src/prompt-section.ts`
- `extensions/memory-core/src/flush-plan.ts`
- `extensions/memory-core/src/memory/manager.ts`
- `extensions/memory-core/src/memory/manager-search.ts`
- `extensions/memory-core/src/tools.ts`
- `extensions/memory-core/src/tools.shared.ts`
- `extensions/memory-core/src/short-term-promotion.ts`
- `extensions/memory-core/src/dreaming.ts`
- `extensions/memory-lancedb/index.ts`
- `extensions/memory-lancedb/lancedb-runtime.ts`
- `src/agents/embedded-agent-runner.e2e.test.ts`
- `src/agents/agent-tools.before-tool-call.e2e.test.ts`
- `extensions/memory-core/src/tools.test.ts`
- `extensions/memory-core/src/memory/manager-search.test.ts`


## Dimensões novas — OpenClaw

| Termo | Como o faz (`ficheiro:linha`) | Força/Fraqueza | vs mem-vector |
|---|---|---|---|
| observability | Grava trajectory logs JSONL por sessão/run, com pointer sidecar, sequência, traceId, provider/model, workspace e sanitização/truncagem de payloads (`src/trajectory/runtime.ts:25`, `src/trajectory/runtime.ts:65`, `src/trajectory/runtime.ts:123`, `src/trajectory/runtime.ts:468`); resolve paths via `OPENCLAW_TRAJECTORY_DIR` ou ao lado da sessão (`src/trajectory/paths.ts:47`); emite eventos diagnósticos de usage/custo/duração/segurança/filas (`src/infra/diagnostic-events.ts:20`, `src/infra/diagnostic-events.ts:101`, `src/infra/diagnostic-events.ts:155`); o wrapper de chamadas de modelo propaga traceparent e eventos start/completed/error (`src/agents/embedded-agent-runner/run/attempt.model-diagnostic-events.ts:703`). | Forte: observabilidade de runtime é explícita, persistente e redigida; fraqueza: bastante superfície de logging e risco se `OPENCLAW_TRAJECTORY_CAPTURE_CONTENT` capturar conteúdo sensível. | Importar o padrão mínimo: ledger JSONL por execução + redaction + pointer para debug; não importar o volume inteiro de diagnósticos antes de haver consumidores reais. |
| evidência/proveniência | Mensagens de input podem carregar `InputProvenance` com kind/originSession/sourceChannel/sourceTool (`src/sessions/input-provenance.ts:15`), são normalizadas/anexadas a mensagens user (`src/sessions/input-provenance.ts:39`, `src/sessions/input-provenance.ts:56`) e podem receber envelope model-facing para handoffs inter-sessão (`src/sessions/input-provenance.ts:115`, `src/sessions/input-provenance.ts:162`); skills carregadas têm source normalizada e classificada como bundled/workspace/unknown (`src/skills/loading/source.ts:12`, `src/skills/loading/source.ts:23`); transcripts externos persistem locator de origem (`src/transcripts/provider-types.ts:17`, `src/transcripts/provider-types.ts:48`); o provider Kimi recolhe citações/grounding de web search (`extensions/moonshot/src/kimi-web-search-provider.runtime.ts:87`, `extensions/moonshot/src/kimi-web-search-provider.runtime.ts:144`, `extensions/moonshot/src/kimi-web-search-provider.runtime.ts:247`). | Média: há provenance estrutural de input/skills/transcripts e citações num provider; fraqueza: não há garantia geral de citações por facto nos outputs finais ou nas memórias. | Importar provenance leve no schema de mensagens/memórias; não vender isto como evidência factual se cada afirmação não transportar fonte. |
| evals/avaliação | QA Lab tem eval de carácter com modelos candidatos, modelos-juiz, concorrência, transcripts, estatísticas, scores, strengths/weaknesses (`extensions/qa-lab/src/character-eval.ts:19`, `extensions/qa-lab/src/character-eval.ts:57`, `extensions/qa-lab/src/character-eval.ts:87`, `extensions/qa-lab/src/character-eval.ts:107`); discovery eval verifica leitura de refs obrigatórias, resultado worked/failed/blocked e leaks de escopo (`extensions/qa-lab/src/discovery-eval.ts:5`, `extensions/qa-lab/src/discovery-eval.ts:31`, `extensions/qa-lab/src/discovery-eval.ts:47`, `extensions/qa-lab/src/discovery-eval.ts:70`); model-switch eval mede continuidade e rejeita leaks/saída longa (`extensions/qa-lab/src/model-switch-eval.ts:4`); scorecards validam evidência QA e maturidade (`extensions/qa-lab/src/scorecard-taxonomy.ts:67`, `extensions/qa-lab/src/scorecard-taxonomy.ts:107`). | Forte: existe avaliação sistemática do agente, incluindo LLM-as-judge e regressões comportamentais; fraqueza: parece centrada no QA Lab e não necessariamente obrigatória em cada mudança. | Importar poucos evals de regressão com transcript + rubrica; evitar transformar testes normais em “evals” sem dataset, juiz ou critério repetível. |
| untrusted-input | Tem utilitário dedicado que proíbe interpolar conteúdo externo em system prompts, detecta padrões de prompt injection, remove tokens/markers especiais, cria boundaries aleatórios e acrescenta aviso de conteúdo não confiável (`src/security/external-content.ts:14`, `src/security/external-content.ts:24`, `src/security/external-content.ts:58`, `src/security/external-content.ts:79`, `src/security/external-content.ts:116`, `src/security/external-content.ts:324`); web search/fetch são embrulhados como conteúdo externo (`src/security/external-content.ts:416`); `web_fetch` só aceita HTTP(S) e passa por guardas SSRF (`src/agents/tools/web-fetch.ts:476`); a camada de rede aplica SSRF checks, DNS pinning, política de redirects e remoção de headers sensíveis (`src/infra/net/fetch-guard.ts:1`, `src/infra/net/fetch-guard.ts:73`, `src/infra/net/ssrf.ts:46`, `src/infra/net/ssrf.ts:365`, `src/infra/net/ssrf.ts:541`). | Forte: fronteira de confiança é explícita, com prompt-injection hardening e defesa SSRF/DNS; fraqueza: só funciona se toda a ingestão externa passar por estes wrappers. | Importar boundary + aviso + source antes de qualquer conteúdo recuperado; no fetch/import de docs, importar também allowlist/SSRF guard. |
| human-steering | O core permite `steer()` e `followUp()` para injetar mensagens durante uma corrida ou quando o agente iria parar (`packages/agent-core/src/agent.ts:312`), e o loop consome steering/follow-ups entre turnos (`packages/agent-core/src/agent-loop.ts:271`, `packages/agent-core/src/agent-loop.ts:314`, `packages/agent-core/src/agent-loop.ts:413`); embedded sessions têm fila de steering, cancelamento e espera por commit no transcript (`src/agents/embedded-agent-runner/run/attempt.queue-message.ts:1`, `src/agents/embedded-agent-runner/run/attempt.queue-message.ts:93`, `src/agents/embedded-agent-runner/run/attempt.queue-message.ts:120`, `src/agents/embedded-agent-runner/run/attempt.queue-message.ts:219`); execuções sensíveis usam approvals com allow/deny/allow-once/allow-always e validação contra command/cwd/session/env (`packages/gateway-protocol/src/schema/exec-approvals.ts:115`, `src/auto-reply/reply/commands-approve.ts:19`, `src/gateway/node-invoke-system-run-approval.ts:220`, `src/gateway/node-invoke-system-run-approval.ts:385`); `/stop` aborta corrida, limpa filas e subagentes (`src/auto-reply/reply/commands-session-abort.ts:123`). | Forte: steering operacional e approvals são primeira classe; fraqueza: aumenta complexidade de estados pendentes e de autorização. | Importar só dois canais: interrupt/steer e approvals para ações destrutivas; evitar `allow-always` sem binding estrito a comando, sessão e ambiente. |
| concorrência/multi-sessão | Escritas de sessão usam file locks com owner metadata, stale detection, cleanup por sinal, watchdog e timeouts (`src/agents/session-write-lock.ts:1`, `src/agents/session-write-lock.ts:89`, `src/agents/session-write-lock.ts:907`, `src/agents/session-write-lock.ts:925`, `src/agents/session-write-lock.ts:964`); append de transcript passa por fila FIFO em processo e lock cross-process (`src/config/sessions/transcript-append.ts:395`, `src/config/sessions/transcript-append.ts:458`, `src/config/sessions/transcript-append.ts:528`, `src/config/sessions/transcript-append.ts:612`); embedded runner separa lanes por sessão/global para filas (`src/agents/embedded-agent-runner/lanes.ts:1`, `src/agents/embedded-agent-runner/lanes.ts:6`, `src/agents/embedded-agent-runner/lanes.ts:11`); session lock/fence detecta takeover e rejeita writes quando a posse mudou (`src/agents/embedded-agent-runner/run/attempt.session-lock.ts:1`, `src/agents/embedded-agent-runner/run/attempt.session-lock.ts:1150`, `src/agents/embedded-agent-runner/run/attempt.session-lock.ts:1839`). | Forte: protege bem transcripts/sessões contra escrita concorrente e takeover; fraqueza: não é um modelo geral de merge para estado arbitrário partilhado. | Importar lock/fila por recurso de escrita partilhado, sobretudo memória/transcript; não assumir que isto resolve conflitos semânticos entre agentes. |

### Importar (só destas 6 dimensões; se nada valer, escreve "nada")
- [ ] Ledger JSONL por execução com redaction e pointer por sessão — encaixa no runner para debug, replay leve e auditoria sem acoplar a UI.
- [ ] Envelope de input não confiável com source, aviso e boundary aleatório — encaixa na ingestão de web/docs/memórias antes de entrar no prompt.
- [ ] Provenance mínima em mensagens e memórias (`source`, canal, ferramenta, timestamp) — encaixa no schema de recall para distinguir facto, memória e handoff.
- [ ] Evals pequenas com transcript, rubrica e juiz opcional — encaixa em regressões de agente onde testes unitários não capturam qualidade.
- [ ] Lock/fila por recurso persistente partilhado — encaixa em writes de memória/transcript para evitar corrida multi-sessão.

### Não importar / armadilhas (destas 6)
- Não copiar a pilha inteira de diagnósticos antes de haver consumidores claros; observability sem uso vira ruído e risco de privacidade.
- Não confundir provenance de input com citações por facto: são garantias diferentes.
- Não guardar payloads externos/model content em logs sem redaction, limites de tamanho e opção de desligar.
- Não deixar conteúdo externo contornar o wrapper de untrusted input; basta uma rota paralela para quebrar a fronteira.
- Não usar approvals permanentes sem binding forte a comando, sessão, cwd, env e identidade do aprovador.
- Não tratar file locks como resolução de conflito semântico; eles serializam writes, não decidem qual estado está correto.
