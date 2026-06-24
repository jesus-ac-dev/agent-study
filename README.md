# agent-study

Estudo da **source** de agentes/harnesses de coding do open source, contra uma anatomia comum, para decidir o que vale **importar** para o [mem-vector](https://github.com/jesus-ac-dev/mem-vector) (o agente-autor que mantém um vault/DB de conhecimento).

Um relatório por agente em `reports/`, um índice (`INDEX.md`) e uma síntese transversal (`SYNTHESIS.md`). No fim, migra-se para a DB do mem-vector (pasta `AI/software/agents`).

> Estado: 15 agentes estudados. Anatomia + prompt-contrato vivem no vault MythosEngine em `knowledge/AI/software/anatomia-de-um-agente.md`.

## Layout

```
contract.tmpl     # prompt de análise (com __NAME__) apontado à source clonada
run.sh            # batch: clona cada repo e corre o Codex em PARALELO → reports/
reports/          # um <owner__repo>.md por agente (o entregável)
clones/           # repos clonados (--depth 1); NÃO versionar
logs/             # log por repo do run.sh
INDEX.md          # tabela: 1 linha por agente (tipo, veredito, top-imports)
SYNTHESIS.md      # padrões transversais + o que importar primeiro
```

## 1. Adicionar um agente novo

### Opção A — em lote, pelo Codex (relay)
```bash
./run.sh                      # corre a lista default (13 repos), em paralelo, salta os já feitos
./run.sh owner/repo           # só este(s) repo(s)
```
Cada job: clona `https://github.com/owner/repo` para `clones/owner__repo`, injeta `__NAME__` no `contract.tmpl`, corre `codex exec` e escreve `reports/owner__repo.md`. Resumível (salta repos com relatório). `CODEX_TIMEOUT` (default 1800s) trava hangs.

### Opção B — pelo Claude (1 repo, direto)
Para um único repo, é mais rápido o próprio Claude fazer: clonar, **ler o código** (não só o README) e escrever o relatório seguindo o template. Foi assim com fugu e pi.
```bash
git clone --depth 1 https://github.com/owner/repo clones/owner__repo
git -C clones/owner__repo rev-parse --short HEAD     # commit p/ o frontmatter
```
Depois escreve `reports/owner__repo.md` no template de `contract.tmpl`.

### Regras do relatório (do contrato)
- **Evidência antes de teoria:** cita sempre `caminho/ficheiro:linha`. Se não viste no código, escreve "não encontrado".
- Mapeia contra a anatomia: regressão, loop, harness, memory, recall, context, tools, system prompt/kernel, skills, planning, behavior, subagentes/orquestração, stop/terminação, verificação, permissões/sandbox, providers.
- Fecha com **o que importar** (rankeado) e **o que NÃO importar** (armadilhas).
- Frontmatter: `agente`, `repo` (owner/repo), `commit` (sha curto). O H1 é `# <Agente> — estudo de source`.

## 2. Atualizar INDEX + SYNTHESIS
- `INDEX.md`: muda a contagem ("N agentes") e acrescenta **1 linha** na tabela (a coluna Report aponta `` `reports/owner__repo.md` ``).
- `SYNTHESIS.md`: muda a contagem, e vê se o agente novo **reforça um padrão** existente (acrescenta um bullet) ou **traz um padrão novo** (nova secção). Atualiza "Importar primeiro" se mover a agulha.

## 3. Importar para a DB do mem-vector

O script vive no **repo do mem-vector** (lê daqui, escreve na DB):
```bash
cd ~/src/mem-vector
DRY=1 npx tsx scripts/import-agent-study.ts   # pré-visualiza (não escreve)
      npx tsx scripts/import-agent-study.ts   # escreve na DB local
      npx tsx scripts/verify-agent-study.ts   # confere notas, chunks RAG, edges mortos
```
Requer Supabase local a correr + `.env.local` (autentica como `dev@mem-vector.local`). Escreve pelo fluxo normal (`escreverNotaEmPastaCom`, autor `agent`) → o indexer deriva chunks/edges.

**Cuidados que o script já trata (não reinventar):**
- **Destino = `AI/software/agents`** (não a raiz). Resolve/cria o caminho por segmento; nunca duplica. Override: `AGENT_STUDY_FOLDER=...`.
- **Títulos curtos.** A nota chama-se "Hermes Agent", não "Hermes Agent — estudo de source" (decisão do Carlos: mais legível). O script tira o sufixo do H1. **Não mudar para longo** — cria duplicados e o hub perde o link.
- **Paths:** as citações `clones/owner__repo/ficheiro:linha` ficam relativas ao repo; cada relatório ganha uma linha `git clone <url>` para se poderem seguir.
- **Wikilinks do vault** (`[[...]]`) são neutralizados para texto (não viram edges mortos). O **INDEX vira hub real**: a coluna Report passa a `[[Título]]` apontando às notas importadas.
- Idempotente: re-correr atualiza as notas no sítio (upsert por slug) e acrescenta as novas.

## 4. Pôr no GitHub
`clones/` e `logs/` ficam de fora (ver `.gitignore`). Os entregáveis são `reports/`, `INDEX.md`, `SYNTHESIS.md`, `contract.tmpl`, `run.sh`, este README.

---
Contexto: este estudo é research/scratch fora do vault; o que vale migra para a DB do mem-vector (o produto). O vault MythosEngine guarda só a anatomia + o pensamento à volta.
</content>
