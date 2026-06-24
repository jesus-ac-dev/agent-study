---
tags: [knowledge, synthesis, ai-software, agente-estudo]
created: 2026-06-22
summary: Odysseus — agente real, muito completo mas pesado; importar sobretudo tool-RAG, contexto não confiável, memória híbrida e travões de loop para o mem-vector.
agente: Odysseus
repo: pewdiepie-archdaemon/odysseus
commit: 7e5db9a
---

# Odysseus — estudo de source

> Veredito: é um workspace self-hosted com agente multi-round, tools, MCP, memória, skills, tarefas e providers múltiplos. Estudado no commit 7e5db9a.

## Identidade
- Odysseus é um workspace AI self-hosted para chat, agentes, research, documentos, email, notas, calendário e modelos locais/API (`clones/pewdiepie-archdaemon__odysseus/README.md:5-7`, `clones/pewdiepie-archdaemon__odysseus/README.md:41-50`).
- Linguagem principal: Python/FastAPI (`clones/pewdiepie-archdaemon__odysseus/requirements.txt:1`). Providers: OpenAI-compatible, Anthropic, OpenRouter, Groq, Mistral, Cohere, DeepSeek, Together, Fireworks, Perplexity, xAI, Ollama, Venice, Kimi e Copilot (`clones/pewdiepie-archdaemon__odysseus/src/agent_loop.py:631-647`, `clones/pewdiepie-archdaemon__odysseus/src/llm_core.py:590-621`). Licença: AGPL-3.0-or-later (`clones/pewdiepie-archdaemon__odysseus/README.md:74-76`, `clones/pewdiepie-archdaemon__odysseus/LICENSE:1`).

## Anatomia (como faz cada coisa)
| Termo | Como o faz (`ficheiro`) | Força/Fraqueza | vs agente-autor simples |
|---|---|---|---|
| regressão/autoregressão | Autoregressão clássica: cada round chama o LLM, extrai tool calls, executa tools e reinsere resultados no histórico (`clones/pewdiepie-archdaemon__odysseus/src/agent_loop.py:2499-2561`, `clones/pewdiepie-archdaemon__odysseus/src/agent_loop.py:3416-3419`). Regressão/treino de modelo: não encontrado. | Força: suporta raciocínio multi-step com observações reais. Fraqueza: complexidade e risco de loops/contexto inchado. | Melhor que um agente-autor simples em execução multi-round; pior se o objectivo for só manter um vault com baixa latência. |
| loop | `stream_agent_loop` faz SSE, seleção de tools, prompt build, trimming, rounds até `max_rounds`, execução e métricas (`clones/pewdiepie-archdaemon__odysseus/src/agent_loop.py:1934-1968`, `clones/pewdiepie-archdaemon__odysseus/src/agent_loop.py:2365-2415`, `clones/pewdiepie-archdaemon__odysseus/src/agent_loop.py:3437-3463`). | Força: loop maduro e observável. Fraqueza: monólito grande, difícil de auditar. | Melhor em robustez; pior em simplicidade para mem-vector. |
| harness | O agente corre via rota de chat streaming e também em modo headless para tarefas/background jobs (`clones/pewdiepie-archdaemon__odysseus/routes/chat_routes.py:1249-1293`, `clones/pewdiepie-archdaemon__odysseus/src/bg_monitor.py:28-72`, `clones/pewdiepie-archdaemon__odysseus/src/task_scheduler.py:1675-1735`). | Força: o mesmo kernel serve UI, tarefas e continuação automática. Fraqueza: harness acoplado a produto grande. | Melhor por reutilização; para agente-autor simples bastava um harness CLI/API mais estreito. |
| memory | `MemoryService` envolve `MemoryManager`, vector store opcional e provider nativo (`clones/pewdiepie-archdaemon__odysseus/services/memory/service.py:32-48`). Auto-extração pós-resposta guarda factos pessoais duráveis, máx. 2 por passagem, com fallback regex (`clones/pewdiepie-archdaemon__odysseus/services/memory/memory_extractor.py:71-86`, `clones/pewdiepie-archdaemon__odysseus/services/memory/memory_extractor.py:150-220`). | Força: separa guardar/recordar/listar/apagar e é conservador. Fraqueza: memória centrada em factos pessoais, não em notas/vault operacional. | Melhor que um autor simples por ter extração assíncrona e auditoria; precisa adaptação para conhecimento de projecto, decisões e tarefas. |
| recall | Recall híbrido: vector search se houver ChromaDB, fallback por relevância textual, filtro por owner e incremento de uses (`clones/pewdiepie-archdaemon__odysseus/src/memory_provider.py:169-212`, `clones/pewdiepie-archdaemon__odysseus/src/memory_vector.py:132-163`, `clones/pewdiepie-archdaemon__odysseus/src/chat_processor.py:206-248`). | Força: recall pequeno, proprietário e deduplicado. Fraqueza: scoring simples e pouca semântica de proveniência. | Melhor que simples keyword search; pior que um mem-vector orientado a vault se não modelar fontes, backlinks e validade temporal. |
| context | Injeta memória, RAG, web e skills como `untrusted_context_message`, não dentro do system prompt, para reduzir prompt injection e preservar KV-cache (`clones/pewdiepie-archdaemon__odysseus/src/chat_processor.py:179-204`, `clones/pewdiepie-archdaemon__odysseus/src/chat_processor.py:252-287`, `clones/pewdiepie-archdaemon__odysseus/src/agent_loop.py:1040-1051`). | Força: boa fronteira entre kernel e contexto externo. Fraqueza: muitas fontes competem pelo orçamento. | Muito melhor que agente-autor simples; importar quase directamente. |
| tools | Tools são descritas em `TOOL_SECTIONS`, selecionadas por RAG/keywords, com parsing de fenced blocks/XML/native calls e execução centralizada (`clones/pewdiepie-archdaemon__odysseus/src/agent_loop.py:302-521`, `clones/pewdiepie-archdaemon__odysseus/src/tool_index.py:1-7`, `clones/pewdiepie-archdaemon__odysseus/src/tool_parsing.py:1-6`, `clones/pewdiepie-archdaemon__odysseus/src/tool_execution.py:521-547`). | Força: toolset grande sem injectar tudo sempre. Fraqueza: aliases/parsers muitos aumentam superfície de erro. | Melhor para ecossistema amplo; para mem-vector deve ficar só o padrão tool-RAG + schema estrito. |
| system prompt/kernel | Kernel montado por `_assemble_prompt`, com tool sections por domínio, regras base e diretivas de plan/guide-only adicionadas em runtime (`clones/pewdiepie-archdaemon__odysseus/src/agent_loop.py:568-625`, `clones/pewdiepie-archdaemon__odysseus/src/agent_loop.py:2327-2363`). | Força: prompt modular. Fraqueza: demasiado texto e regras duplicadas/antigas no ficheiro (`clones/pewdiepie-archdaemon__odysseus/src/agent_loop.py:68-200`). | Melhor que prompt único artesanal; pior em legibilidade e manutenção. |
| skills | Skills são `SKILL.md` em `data/skills/<category>/<name>/`, com frontmatter, sidecar de uso, owner filter e injeção só quando relevantes (`clones/pewdiepie-archdaemon__odysseus/services/memory/skills.py:1-18`, `clones/pewdiepie-archdaemon__odysseus/services/memory/skills.py:159-181`, `clones/pewdiepie-archdaemon__odysseus/services/memory/skills.py:278-287`, `clones/pewdiepie-archdaemon__odysseus/src/agent_loop.py:1305-1409`). | Força: formato durável e editável. Fraqueza: mistura memória procedimental com produto/UI. | Melhor que um agente-autor sem skills; para mem-vector é útil como camada de procedimentos do vault. |
| planning | `update_plan` mantém checklist live; plan mode bloqueia tools não read-only e força perguntar antes de executar (`clones/pewdiepie-archdaemon__odysseus/src/tool_execution.py:695-723`, `clones/pewdiepie-archdaemon__odysseus/src/tool_security.py:91-151`, `clones/pewdiepie-archdaemon__odysseus/src/agent_loop.py:1904-1919`). | Força: separa planeamento de execução. Fraqueza: plano é estado de UI, não parece virar artefacto persistente de projecto. | Melhor para sessões interativas; mem-vector deve persistir decisões/plano no vault. |
| behavior | Classifica intent/domínios, usa caminho direto para low-signal, força tools por contexto ativo e aplica nudges quando o modelo promete ação sem tool (`clones/pewdiepie-archdaemon__odysseus/src/agent_loop.py:860-944`, `clones/pewdiepie-archdaemon__odysseus/src/agent_loop.py:2022-2095`, `clones/pewdiepie-archdaemon__odysseus/src/agent_loop.py:2920-2971`). | Força: evita over-tooling e corrige falhas comuns. Fraqueza: heurísticas extensas difíceis de prever. | Melhor que simples sempre-agent; para mem-vector importar só gates claros: low-signal, context-active e nudge de tool prometida. |
| subagentes/orquestração | Subagentes genéricos: não encontrado. Há teacher escalation que, após falha de modelo self-hosted, chama provider mais forte e grava skill corretiva se houver sucesso (`clones/pewdiepie-archdaemon__odysseus/src/teacher_escalation.py:1-22`, `clones/pewdiepie-archdaemon__odysseus/src/teacher_escalation.py:147-220`, `clones/pewdiepie-archdaemon__odysseus/src/agent_loop.py:3465-3483`). | Força: aprendizagem procedimental após falha. Fraqueza: pode transformar correções episódicas em skills demasiado cedo. | Melhor que simples sem reflexão; para mem-vector usar com quarentena/revisão humana. |
| stop/terminação | Termina quando não há tool calls; tem round cap, detector de chamadas repetidas, stall detector e emissão `rounds_exhausted` (`clones/pewdiepie-archdaemon__odysseus/src/agent_loop.py:1922-1931`, `clones/pewdiepie-archdaemon__odysseus/src/agent_loop.py:2973-3029`, `clones/pewdiepie-archdaemon__odysseus/src/agent_loop.py:3437-3442`). | Força: travões explícitos contra loops. Fraqueza: sintomas tratados por heurística, não por contrato formal de tarefa. | Melhor que agente-autor simples; importar os travões mínimos. |
| verificação | Verifier opcional para tools com efeitos, limitado a 2 rounds; supervisor também deteta intent sem ação (`clones/pewdiepie-archdaemon__odysseus/src/agent_loop.py:1772-1780`, `clones/pewdiepie-archdaemon__odysseus/src/agent_loop.py:2877-2920`). | Força: só verifica quando houve ação relevante. Fraqueza: verificador é LLM e não substitui testes/validação determinística. | Melhor que nada; para mem-vector deve combinar com checks determinísticos de escrita no vault/DB. |
| permissões/sandbox | File tools são confinadas a roots/workspace e bloqueiam paths sensíveis (`clones/pewdiepie-archdaemon__odysseus/src/tool_execution.py:38-88`, `clones/pewdiepie-archdaemon__odysseus/src/tool_execution.py:182-213`). Shell começa no workspace mas o próprio prompt avisa que não é sandboxed (`clones/pewdiepie-archdaemon__odysseus/src/agent_loop.py:362-365`). Public/non-admin/plan mode bloqueiam tools perigosas (`clones/pewdiepie-archdaemon__odysseus/src/tool_security.py:11-53`, `clones/pewdiepie-archdaemon__odysseus/src/tool_security.py:154-167`). | Força: boa camada de policy. Fraqueza: shell continua demasiado poderoso. | Melhor que agente simples sem ACL; mem-vector não deve importar shell livre. |
| providers | Deteta provider por endpoint/modelo e adapta payloads para OpenAI-compatible, Anthropic e Ollama, incluindo tool/native support e fallback (`clones/pewdiepie-archdaemon__odysseus/src/llm_core.py:590-668`, `clones/pewdiepie-archdaemon__odysseus/src/llm_core.py:965-1050`, `clones/pewdiepie-archdaemon__odysseus/src/agent_loop.py:2255-2327`). | Força: portabilidade forte. Fraqueza: matriz de compatibilidade grande e frágil. | Melhor se mem-vector quer relay Claude<->Codex; excessivo se só usar 1-2 providers. |
| tasks/daily | Scheduler corre agent loop para tarefas; prompt de assistente pessoal usa ladder search_chats -> manage_memory -> web_search -> trigger_research e regras de autonomia para calendário/email (`clones/pewdiepie-archdaemon__odysseus/src/task_scheduler.py:2328-2358`). | Força: encaixa bem em rotinas diárias. Fraqueza: produto-specific e com risco de autonomia excessiva. | Melhor que cron simples; importar só task envelopes e limites de autonomia. |
| MCP/integrações | `MCPManager` liga stdio/SSE/HTTP, namespaceia tools como `mcp__server__tool`, sanitiza schemas e classifica read-only para plan mode (`clones/pewdiepie-archdaemon__odysseus/src/mcp_manager.py:150-179`, `clones/pewdiepie-archdaemon__odysseus/src/mcp_manager.py:536-568`, `clones/pewdiepie-archdaemon__odysseus/src/mcp_manager.py:95-130`). | Força: extensibilidade limpa. Fraqueza: mais uma superfície de confiança. | Melhor para relay/integrações; mem-vector deve manter allowlist curta e schemas sanitizados. |

## Pontos fortes (rankeados)
1. Contexto externo como `untrusted_context_message`, separado do kernel/system prompt (`clones/pewdiepie-archdaemon__odysseus/src/chat_processor.py:179-204`, `clones/pewdiepie-archdaemon__odysseus/src/agent_loop.py:1305-1409`).
2. Tool-RAG + hints determinísticos para não despejar todas as ferramentas no prompt (`clones/pewdiepie-archdaemon__odysseus/src/tool_index.py:1-7`, `clones/pewdiepie-archdaemon__odysseus/src/tool_index.py:510-585`).
3. Memória híbrida simples: store JSON/manager + Chroma opcional + fallback lexical (`clones/pewdiepie-archdaemon__odysseus/services/memory/service.py:32-48`, `clones/pewdiepie-archdaemon__odysseus/src/memory_provider.py:169-212`).
4. Travões de loop: repeated-call detection, stall breaker, round cap e verifier restrito (`clones/pewdiepie-archdaemon__odysseus/src/agent_loop.py:1922-1931`, `clones/pewdiepie-archdaemon__odysseus/src/agent_loop.py:2973-3029`).
5. Skills em Markdown com frontmatter e owner filter, bom formato para conhecimento procedimental (`clones/pewdiepie-archdaemon__odysseus/services/memory/skills.py:1-18`, `clones/pewdiepie-archdaemon__odysseus/services/memory/skills.py:278-287`).

## O que vale importar para o mem-vector
- [ ] Separar kernel fixo de contexto recuperado e marcar todo o RAG/chat/email/tool output como não confiável — encaixa no relay Claude<->Codex e reduz prompt injection.
- [ ] Tool-RAG com `ALWAYS_AVAILABLE` pequeno + keywords de alta precisão — encaixa na seleção entre vault, DB, tasks, daily, chat search e relay, sem prompt gigante.
- [ ] Memória híbrida com vector store opcional e fallback lexical — encaixa no vault/DB quando embeddings falham ou ainda não estão construídos.
- [ ] Extração assíncrona e conservadora de memórias, com limite por resposta — encaixa em chat diário sem poluir o vault com cada detalhe.
- [ ] `SKILL.md` como artefacto procedimental versionável — encaixa em rotinas de escrita, revisão, ingestão RAG, daily note e handoff Claude/Codex.
- [ ] Checklist `update_plan` persistível — adaptar para criar/actualizar tasks/daily notes, não só estado de UI.
- [ ] Travões de loop: repeated-call detector, stall breaker e round cap — encaixa em jobs longos de vault e evita loops de ferramenta.
- [ ] Verificador apenas depois de writes/effects — encaixa em operações de DB/vault: confirmar ficheiro criado, backlinks actualizados, task fechada.
- [ ] Policy read-only para modo plan/review — encaixa em “analisa antes de escrever” no mem-vector.
- [ ] MCP com allowlist e schema sanitizado — útil para relay e integrações, mas com menos providers/tools.

## Não importar / armadilhas
- Não importar o monólito inteiro de `agent_loop.py`; a maturidade vem com custo de manutenção alto.
- Não importar shell livre: o próprio prompt diz que `bash` não é sandboxed (`clones/pewdiepie-archdaemon__odysseus/src/agent_loop.py:362-365`).
- Não transformar toda correção de teacher em skill automaticamente; para mem-vector, skills novas devem passar por revisão/quarentena.
- Não misturar memória pessoal, contactos, tasks e notas no mesmo schema sem proveniência; Odysseus separa algumas rotas, mas o mem-vector precisa de um modelo de conhecimento mais explícito.
- Não copiar a matriz enorme de providers antes de haver necessidade; para relay Claude<->Codex bastam adaptadores pequenos e testados.
- Não depender só de verificador LLM para writes; usar checks determinísticos no vault/DB.
- Não deixar heurísticas de intent crescerem sem testes; Odysseus tem muitas keywords/domínios (`clones/pewdiepie-archdaemon__odysseus/src/agent_loop.py:215-288`, `clones/pewdiepie-archdaemon__odysseus/src/tool_index.py:343-508`).

## Fontes
- `clones/pewdiepie-archdaemon__odysseus/README.md`
- `clones/pewdiepie-archdaemon__odysseus/LICENSE`
- `clones/pewdiepie-archdaemon__odysseus/requirements.txt`
- `clones/pewdiepie-archdaemon__odysseus/src/agent_loop.py`
- `clones/pewdiepie-archdaemon__odysseus/src/agent_tools/__init__.py`
- `clones/pewdiepie-archdaemon__odysseus/src/tool_execution.py`
- `clones/pewdiepie-archdaemon__odysseus/src/tool_policy.py`
- `clones/pewdiepie-archdaemon__odysseus/src/tool_parsing.py`
- `clones/pewdiepie-archdaemon__odysseus/src/tool_index.py`
- `clones/pewdiepie-archdaemon__odysseus/src/tool_security.py`
- `clones/pewdiepie-archdaemon__odysseus/src/memory.py`
- `clones/pewdiepie-archdaemon__odysseus/src/memory_provider.py`
- `clones/pewdiepie-archdaemon__odysseus/src/memory_vector.py`
- `clones/pewdiepie-archdaemon__odysseus/services/memory/service.py`
- `clones/pewdiepie-archdaemon__odysseus/services/memory/memory_extractor.py`
- `clones/pewdiepie-archdaemon__odysseus/services/memory/skills.py`
- `clones/pewdiepie-archdaemon__odysseus/src/chat_processor.py`
- `clones/pewdiepie-archdaemon__odysseus/src/context_compactor.py`
- `clones/pewdiepie-archdaemon__odysseus/routes/chat_helpers.py`
- `clones/pewdiepie-archdaemon__odysseus/routes/chat_routes.py`
- `clones/pewdiepie-archdaemon__odysseus/src/bg_monitor.py`
- `clones/pewdiepie-archdaemon__odysseus/src/task_scheduler.py`
- `clones/pewdiepie-archdaemon__odysseus/src/mcp_manager.py`
- `clones/pewdiepie-archdaemon__odysseus/src/llm_core.py`
- `clones/pewdiepie-archdaemon__odysseus/src/teacher_escalation.py`
