---
tags: [knowledge, synthesis, ai-software, agente-estudo]
created: 2026-06-23
summary: Sakana Fugu — sistema multi-agente entregue como UM modelo (hospedado, Sakana API); o repo open é só o instalador/launcher/config p/ Codex. Importar o guard de auto-proteção do runtime, a disciplina de gestão do provider e a resiliência de stream — não há loop/memória/recall no source.
agente: Sakana Fugu
repo: SakanaAI/fugu
commit: 655675e
---

# Sakana Fugu — estudo de source

> Veredito: **não é o código de um agente** — é o *client-side* (instalador + bundle de config + launcher) que liga o **Codex** a um sistema multi-agente **hospedado** (Sakana API), acedido como um único LLM. A inteligência agêntica real (coordenadores TRINITY/Conductor, papers ICLR 2026) vive no servidor fechado e **não está neste repo**. Estudado no commit 655675e.

## Identidade
- "Multi-agent system delivered as one model": orquestra dinamicamente um pool de modelos de fronteira atrás de um endpoint único (`README.md`; provider em `configs/injects/model_providers.sakana.toml` → `base_url=https://api.sakana.ai/v1`, `wire_api="responses"`). Dois tiers: `fugu` (default, custo/perf) e `fugu-ultra` (premium), nudge a favor do default no launcher (`scripts/codex-fugu:118-119`).
- O que o repo CONTÉM: um wrapper de launch (`scripts/codex-fugu`), um instalador (`scripts/install.sh`), o bundle de config (`configs/`) e o technical report (PDF + arXiv 2606.21228). Provider: agnóstico via Codex CLI. Linguagem: **Bash** (não há código de agente). Licença: ver repo.

## Anatomia (como faz cada coisa)
| Termo | Como o faz (`ficheiro`) | Força/Fraqueza | vs agente-autor simples |
|---|---|---|---|
| regressão/autoregressão | Não no repo — a geração é o endpoint hospedado (`model_providers.sakana.toml`). | n/a | n/a (delega 100% ao serviço) |
| loop | **Não encontrado** no source; o agentic loop é o do próprio Codex + a orquestração server-side. | — | — |
| harness | O harness aqui é de **distribuição/launch**, não de inferência: `codex-fugu` resolve o binário real e faz `exec codex -p fugu` (`scripts/codex-fugu:190-197`), nunca bloqueia o launch (`:495-501`). | Força: wrapper fino e robusto sobre uma CLI alheia. Fraqueza: não é um harness de agente. | Não comparável — é a camada de empacotamento, não o motor. |
| memory | **Não encontrado** (hospedado). O install só faz **backup** do índice de sessão do Codex (`state_*.sqlite`, `memories_*.sqlite`, `goals_*.sqlite`) antes de trocar versão (`scripts/install.sh:876-886`). | Força: trata o índice de memória como artefacto a preservar em migrações. | A ideia "backup do estado antes de migrar" é boa; a memória em si não está aqui. |
| recall | **Não encontrado** (hospedado). | — | — |
| context | Catálogo declara janela de **1M tokens** e `truncation_policy {mode:"tokens", limit:10000}` (`configs/files/fugu.json`). | Força: política de truncagem explícita por tokens. Fraqueza: é config, não implementação. | Útil como parâmetro, não como mecanismo. |
| tools | Não define tools próprias; usa as do Codex (`apply_patch_tool_type:"freeform"`, `supports_parallel_tool_calls:true` em `fugu.json`). | — | Delega ao host. |
| system prompt/kernel | **`base_instructions`** no catálogo do modelo = um system-prompt de **auto-proteção** injetado pelo provider (`configs/files/fugu.json`): não correr comandos que matem o próprio runtime (reboot/`systemctl`/`wsl --shutdown`), **nunca `kill -9` a PIDs arbitrários** ("the agent runtime depends on its own child processes; force-killing them can permanently break the session"). | **Força grande**: guard de segurança operacional embutido no modelo, agnóstico ao host. | Muito melhor que um agente simples sem guardas — é importável quase verbatim. |
| skills | Não encontrado. | — | — |
| planning | Não no repo — é o miolo dos papers (Conductor desenha topologias agente-a-agente; TRINITY delega 3 papéis por turno). | Força (conceito): coordenador treinado supera qualquer modelo único. | Conceito de investigação, não código a importar. |
| behavior | Definido por `base_instructions` (auto-proteção) + tier default vs ultra. | Força: comportamento de segurança no provider. | Importável como contrato. |
| subagentes/orquestração | **O coração do produto** — mas hospedado e fechado (Sakana API). O repo não o expõe. | Força conceptual / Fraqueza prática (caixa preta). | Não importável como source. |
| stop/terminação | Resiliência de stream como dados: `stream_idle_timeout_ms=7200000` (2h), `stream_max_retries=5`, `request_max_retries=4` (`model_providers.sakana.toml`). | Força: knobs explícitos contra streams pendurados. | Importável como config do provider. |
| verificação | Forte na **distribuição**: backup com `SHA256SUMS` + verificação de integridade que recusa trocar versão se falhar (`scripts/install.sh:904-914`); `verify_installed_version` pós-install (`:743-759`). | Força: nunca migra sem rede de segurança verificada. | Melhor que um instalador ingénuo; aplica-se ao runner, não ao conteúdo. |
| permissões/sandbox | Chave em `~/.codex/.env` modo **0600** (não no shell rc) carregada pelo Codex (`notes/0001`, `scripts/install.sh:557`); ficheiros de estado `chmod 600/700` (`scripts/codex-fugu:137-146`). | Força: gestão de segredo limpa e por-ficheiro. | Importável: segredo em store 0600 dedicado, não em rc. |
| providers | **Gestão de provider madura**: pin de versão do Codex + deteção de mismatch config↔binário (`scripts/codex-fugu:512-513`), update throttled 1×/h com **flock** (`:503-506`, `:516-518`), formatos modern/legacy migráveis (`configs/formats/*`), adoção de instalações pré-existentes (`maybe_adopt :397`), `--dry-run`/`--remove-config`/rollback. | **Força grande**: como gerir uma CLI-provider externa de forma segura e não-bloqueante. | Muito melhor que "assume que o codex está bem"; relevante para o runner do relay. |
| observability | Inteligência hospedada (sem observabilidade de runtime no repo). O instalador faz **backup verificado (SHA256)** dos índices de sessão/memória/goals antes de trocar versão (`scripts/install.sh:876,904`) + notices/decisions no launcher. | Parcial: observabilidade de **migração**, não de corrida. | Só o princípio "backup verificado antes de migrar". |
| evidência/proveniência | Não encontrado (hospedado). | — | — |
| evals/avaliação | Não encontrado no repo (TRINITY/Conductor e métricas são server-side / papers). | — | — |
| untrusted-input | Não encontrado como defesa de input. Há o **guard de auto-proteção do runtime** (`base_instructions`, `configs/files/fugu.json`) e o segredo em store 0600. | n/a (safety de runtime, não input-trust). | O guard já está nos imports. |
| human-steering | Não encontrado (é launcher; o steering é do Codex que ele lança). | — | — |
| concorrência/multi-sessão | `flock` no update do provider (throttle 1×/h) + backup com índice de sessão (`scripts/codex-fugu:503`, `scripts/install.sh`). | Parcial: lock no **update do provider**, não multi-sessão de agente. | Princípio flock no update do provider-CLI (já nos imports). |

## Pontos fortes (rankeados)
1. **Guard de auto-proteção no system prompt** (`configs/files/fugu.json` → `base_instructions`): não matar o próprio runtime, nunca `kill -9` PIDs arbitrários, parar tarefas por nome. Segurança operacional embutida, agnóstica ao host.
2. **Disciplina de gestão do provider-CLI**: pin de versão, deteção de mismatch, update não-bloqueante com lock (flock) e throttle, formatos migráveis, backup-antes-de-trocar (com índice de sessão) e rollback (`scripts/install.sh`, `scripts/codex-fugu`).
3. **Resiliência de stream como config** (`model_providers.sakana.toml`): idle timeout longo + retries de stream/request.
4. **Segredo em store 0600 dedicado** (`~/.codex/.env`), não no shell rc — funciona em todo o lado (IDE, cron) sem novo terminal (`notes/0001`).
5. **Conceito de produto** (papers): multi-agente atrás de um endpoint único, com coordenador treinado (TRINITY/Conductor) e tiers default/premium.

## O que vale importar para o mem-vector
- [ ] **Guard de auto-proteção no Kernel/relay** — adotar quase verbatim o `base_instructions`: o agente-autor e o runner do relay nunca devem `kill -9` PIDs arbitrários nem reiniciar o próprio runtime; parar processos por nome, avisar o utilizador. (Evita o runner partir a própria sessão — guard técnico barato.)
- [ ] **Stream resilience knobs** no provider do mem-vector — idle timeout generoso + `stream_max_retries`/`request_max_retries`, encaixa no streaming (#66/#100/#112).
- [ ] **Gestão do provider Codex no relay** — quando o relay despacha o Codex, vale a disciplina do fugu: conhecer a versão alvo, backup-antes-de-mudar, update não-bloqueante, lock (um relay/repo já existe). O runner não deve herdar config do host às cegas.
- [ ] **Segredo em store 0600 dedicado** (não em env do shell) — o mem-vector já cifra keys na BD; o princípio "segredo fora do rc, carregado no arranque" reforça-o.
- [ ] **Backup do estado antes de migrar** — preservar o índice/estado (sessões, memória) antes de qualquer troca de versão/migração destrutiva, com verificação de integridade (SHA256) que recusa avançar se falhar.

## Não importar / armadilhas
- **Não tentar importar a orquestração** (TRINITY/Conductor) — é hospedada, fechada e research-grade; o mem-vector usa providers CLI (Claude/Codex), não um coordenador treinado próprio. O "multi-agente como um modelo" é um caminho de produto diferente.
- **Não copiar o `curl … | bash`** como padrão de instalação — é supply-chain arriscado; se o mem-vector distribuir algo, fazê-lo de forma verificável.
- **Não confundir este repo com um agente** — não há loop/memória/recall para estudar; a maquinaria de instalador só se aplica se o mem-vector gerir uma CLI-provider externa (que o relay gere — daí a parte 2/3 valerem).
- Não importar a complexidade de formatos legacy/modern a menos que precises de migrar config de terceiros.
- Não tomar o fugu como referência destas 6: é um launcher, a maioria é "não encontrado" (vive no serviço hospedado).

## Fontes
- `README.md` (o que é, install, papers TRINITY/Conductor), `Fugu_technical_report.pdf` (não lido em detalhe — 6.6MB).
- `configs/files/fugu.json` (catálogo de modelos + `base_instructions` de auto-proteção + 1M context + truncation).
- `configs/injects/model_providers.sakana.toml` (provider Sakana, stream resilience).
- `configs/bundle.sh` (manifesto: BUNDLE_CODEX_VERSION=0.142.0, ENV_KEYS Sakana), `configs/formats/{modern,legacy}/*`.
- `scripts/codex-fugu` (launcher: exec-delegação, mismatch, update throttled+flock, notices/decisions, adoção).
- `scripts/install.sh` (pin de versão, backup+SHA256 com índice de sessão, deploy do bundle, set-key 0600, rollback).
- `notes/0001` (key em `.env` 0600), `notes/0002` (índice de sessão no backup), `docs/commands_details.md`.
