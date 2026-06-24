# Estudo de agentes — índice

15 agentes/harnesses do open source, estudados na source contra a anatomia em `../MythosEngine` → `knowledge/AI/software/anatomia-de-um-agente.md`. Um relatório por agente em `reports/`. Síntese transversal em `SYNTHESIS.md`.

Os 13 primeiros estudados a 2026-06-22 pelo Codex (relay, fan-out); fugu a 2026-06-23 e pi a 2026-06-24 pelo Claude. Tudo verificado (sem stubs, sem falhas, sem limites). Migrar à mão o que valer para a DB do mem-vector.

| Agente | Tipo | Veredito (1 linha) | Importar primeiro | Report |
|---|---|---|---|---|
| **NousResearch/hermes-agent** | agente real, grande | loop+tools+memória+cron+relay completos | snapshot+batch memory, recall FTS5, verificador pós-tool, relay por capacidades | `reports/NousResearch__hermes-agent.md` |
| **openclaw/openclaw** | runtime/plataforma | memória como capability + recall híbrido + flush | recall híbrido (FTS+vector+MMR+decay+fallback), flush pré-compaction, terminação enum | `reports/openclaw__openclaw.md` |
| **tanbiralam/claude-code** | agente real (CC clone) | memdir + taxonomia + extracção assíncrona | índice MEMORY.md + taxonomia user/feedback/project/reference, recall por manifest, freshness | `reports/tanbiralam__claude-code.md` |
| **tinyhumansai/openhuman** | agente pessoal (Rust) | substrate de memória híbrida + harness defensivo | SQLite+MD+vector+FTS, recall c/ citações, stop hooks, tool contract c/ permission level | `reports/tinyhumansai__openhuman.md` |
| **gobii-ai/gobii-platform** | plataforma persistente | compaction + SQLite working-state + evals memória | promptree token budget, SQLite efémero→reconcile, evals durável-vs-efémero, audit log | `reports/gobii-ai__gobii-platform.md` |
| **langchain-ai/open-swe** | agente real (LangGraph) | queue/eventos + memória estruturada + analyzer | FIFO queue por thread, ledger de memória ≠ RAG, analyzer/continual-learning, stop reasons | `reports/langchain-ai__open-swe.md` |
| **coleam00/Archon** | harness (DAG) | motor DAG + resume + artefactos tipados + gates | DAG mínimo, event log append-only, structured-output antes de persistir, lock por task | `reports/coleam00__Archon.md` |
| **pewdiepie-archdaemon/odysseus** | agente real, pesado | tool-RAG + contexto não confiável + travões | untrusted context, tool-RAG, extracção conservadora, repeat/stall/round-cap, verifier pós-write | `reports/pewdiepie-archdaemon__odysseus.md` |
| **paperclipai/paperclip** | control plane | run ledger + wake/context contract + sessões | run/event ledger, wake/context envelope, continuation summary, task-scoped sessions | `reports/paperclipai__paperclip.md` |
| **omnigent-ai/omnigent** | meta-harness/runtime | event store + compaction 3 camadas + políticas | event store tipado, compaction em camadas, sub-sessões duráveis, ALLOW/ASK/DENY | `reports/omnigent-ai__omnigent.md` |
| **ruvnet/ruflo** | orquestrador, irregular | bridge DB↔markdown + SmartRetrieval + relay | bridge RVF↔markdown, SmartRetrieval (RRF/recency/MMR), loop persistido, relay namespace | `reports/ruvnet__ruflo.md` |
| **mattpocock/sandcastle** | harness (sandbox) | isolamento git+sandbox + sessões + output schema | contrato provider fino, captura/retoma de sessões, completion+timeouts, output validado | `reports/mattpocock__sandcastle.md` |
| **cline/cline** | agente real (IDE) | loop tool-result + checkpoints + skills lazy | completion estruturada, separar histórico UI/LLM/searchável, skills lazy, policy antes de tools | `reports/cline__cline.md` |
| **SakanaAI/fugu** | multi-agente hospedado (≠ source) | sistema multi-agente como UM modelo; o repo é só instalador/launcher/config p/ Codex | **guard de auto-proteção do runtime** (não matar PIDs/próprio runtime), stream-resilience, gestão do provider-CLI, segredo 0600 | `reports/SakanaAI__fugu.md` |
| **earendil-works/pi** | harness de coding (TS, real) | núcleo mínimo + **tudo-é-extensão** (hook bus tipado); sessão em árvore top, mas zero RAG/conhecimento | seam de extensões/hooks, lock de mutação por-ficheiro, writes diferidos→save point, compaction por usage real + estruturada, project-trust, getApiKey per-call | `reports/earendil-works__pi.md` |

Ler a seguir: **`SYNTHESIS.md`** — os padrões que aparecem em vários e o que vale a pena importar primeiro.
