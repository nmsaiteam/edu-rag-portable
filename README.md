# EDU RAG — Portable Educational Assistant

> Hybrid (online + **offline**) RAG system for school textbooks, designed to run on an ordinary Intel Core i5 laptop with **8 GB RAM and no GPU**.

[![CPU-only](https://img.shields.io/badge/inference-CPU--only-blue)]()
[![Offline-capable](https://img.shields.io/badge/mode-offline%20%2B%20online-green)]()
[![Docker](https://img.shields.io/badge/deploy-docker--compose-2496ed)]()
[![Languages](https://img.shields.io/badge/languages-RO%20%2F%20RU%20%2F%20EN-orange)]()

---

## TL;DR

EDU RAG answers questions from school textbooks (Romanian / Russian / English) using semantic search over **11 520 pre-indexed chunks** stored in PostgreSQL + pgvector. It runs in two interchangeable modes:

| Mode | LLM | Internet | Latency | Where it runs |
|---|---|---|---|---|
| **OFFLINE** | `deepseek-r1:8b` (with reasoning) | not required | 15–30 s | Local CPU via Ollama |
| **ONLINE** | `gpt-5-nano` | required | 2–5 s | OpenAI API |

The whole stack is three Docker containers (`pgvector`, `ollama`, `n8n`) wired together by an n8n workflow. **No GPU, no cloud dependency for the offline path.**

---

## Why this is interesting for the Intel competition

- **Edge AI on consumer CPU** — an 8 B-parameter reasoning LLM (`deepseek-r1:8b`) and a 137 M embedding model (`nomic-embed-text`) both run **entirely on an Intel Core i5 with 8 GB RAM**, with no discrete GPU and no model quantization tricks beyond what Ollama ships by default.
- **Genuine offline capability** — once the models are pulled, the offline mode works with the network cable unplugged. Useful for schools with poor connectivity.
- **Hybrid graceful fallback** — the same workflow can switch to `gpt-5-nano` over the OpenAI API at request time (`"llm": "gpt"`) when speed matters more than privacy.
- **Privacy by default** — student questions and textbook content never leave the laptop in offline mode.
- **Reproducible & portable** — one `docker compose up` recreates the entire stack on any Windows/Linux/macOS host.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                  Laptop — Intel Core i5, 8 GB RAM                    │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   PostgreSQL + pgvector ──────────────┐                              │
│        (11 520 textbook chunks)       │                              │
│                                       ▼                              │
│   Ollama ──┬─ nomic-embed-text ──→ Embeddings (768-dim)              │
│            │                                                         │
│            └─ deepseek-r1:8b   ──→ OFFLINE generation (with reasoning)│
│                                                                      │
│   n8n workflow ──────────────► routes request to local or remote LLM │
│            │                                                         │
│            └─ OpenAI API ─────► ONLINE generation (gpt-5-nano)       │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

**Request flow** (`workflow_portable.json`):
1. `POST /webhook/edu-rag-query` — accepts `{question, subject?, grade?, top_k?, llm?}`
2. Question is embedded with `nomic-embed-text` via Ollama
3. pgvector cosine similarity search returns top-k chunks
4. Language is auto-detected (RO / RU / EN)
5. Switch node picks `gpt-5-nano` (online) or `deepseek-r1:8b` (offline)
6. Response is returned with `answer`, `sources`, `llm` used, and reasoning trace if available

---

## Repository layout

```
edu-rag-portable/
├── README.md                       # this file
├── DEMO_SETUP.md                   # step-by-step bilingual setup notes
├── docker-compose-portable.yml     # 3-container stack (pgvector + ollama + n8n)
├── .env.example                    # template for secrets — copy to .env
├── .gitignore
├── workflow_portable.json          # n8n workflow (current)
├── EDU_RAG_Portable.json           # n8n workflow (alternate / production export)
├── setup.sql                       # pgvector search function (PowerShell heredoc)
├── setup_search_function.sql       # same function as plain SQL
├── start_demo.ps1                  # one-shot startup script (Windows / PowerShell)
├── edu_rag_demo.html               # standalone demo UI
└── EDU_RAG_Quick_Start.html        # quick-start guide as HTML
```

> **Not included in the repo:** `ragdb_backup.sql` (~232 MB, exceeds GitHub's per-file limit). See **[Database](#database)** below.

---

## Quick start

### 1. Prerequisites

- Docker Desktop (Memory ≥ 6 GB in Settings → Resources)
- ~7 GB free disk space (models + database)
- Windows / macOS / Linux

### 2. Clone and configure

```bash
git clone https://github.com/<your-user>/edu-rag-portable.git
cd edu-rag-portable
cp .env.example .env
# Edit .env: set POSTGRES_PASSWORD and N8N_ENCRYPTION_KEY to strong random values
```

### 3. Start the stack

**Windows / PowerShell:**
```powershell
.\start_demo.ps1
```

**macOS / Linux:**
```bash
docker compose -f docker-compose-portable.yml up -d
docker exec ollama ollama pull nomic-embed-text:latest
docker exec ollama ollama pull deepseek-r1:8b
```

The first run downloads ~5.5 GB of model weights — expect 10–15 minutes on a typical connection.

### 4. Database

The corpus (~11 520 pre-embedded chunks of school textbooks) is **221 MB** — too large for GitHub's per-file limit, so it is hosted on Google Drive.

**Download:** <https://drive.google.com/file/d/1uv4WI7K5nWnMUJ9GlWGcsAk8L2sBW-fl/view?usp=sharing>

| Property | Value |
|---|---|
| Filename | `ragdb_backup.sql` |
| Size | 232 215 440 bytes (≈ 221 MB) |
| SHA-256 | `98c4ad56179f1f48d8c6f7c5efc013d069ad87f05312d0fac7fb69de552311d2` |

#### Option A — browser

Open the link above, click **Download**, save the file as `ragdb_backup.sql` in the project root.

#### Option B — command line

The simplest cross-platform tool for Drive files >100 MB is `gdown` (handles the virus-scan confirmation token automatically):

```bash
pip install gdown
gdown 1uv4WI7K5nWnMUJ9GlWGcsAk8L2sBW-fl -O ragdb_backup.sql
```

#### Verify integrity

**Linux / macOS:**
```bash
sha256sum ragdb_backup.sql
# Expected: 98c4ad56179f1f48d8c6f7c5efc013d069ad87f05312d0fac7fb69de552311d2
```

**Windows / PowerShell:**
```powershell
(Get-FileHash ragdb_backup.sql -Algorithm SHA256).Hash.ToLower()
# Expected: 98c4ad56179f1f48d8c6f7c5efc013d069ad87f05312d0fac7fb69de552311d2
```

#### Restore into Postgres

```bash
docker exec -i pg-rag psql -U rag -d ragdb < ragdb_backup.sql
```

Then create the search function:

```bash
docker exec -i pg-rag psql -U rag -d ragdb < setup_search_function.sql
```

### 5. Configure n8n

1. Open <http://localhost:5678> and create the local admin account
2. **Settings → Credentials**:
   - **Postgres**: `Host=pg-rag`, `Port=5432`, `Database=ragdb`, `User=rag`, `Password=<your .env value>`
   - **OpenAI API** (only for online mode): paste your `sk-...` key
3. **Workflows → Import** → `workflow_portable.json`
4. Bind the credentials to the `Postgres` and `GPT-5-nano` nodes
5. **Activate** the workflow

---

## Usage

### Offline mode (no internet)

```powershell
$body = '{"question": "Ce este metafora?"}'
Invoke-RestMethod -Uri "http://localhost:5678/webhook/edu-rag-query" `
                  -Method POST -Body $body -ContentType "application/json"
```

```bash
curl -X POST http://localhost:5678/webhook/edu-rag-query \
     -H "Content-Type: application/json" \
     -d '{"question": "Ce este metafora?"}'
```

Response includes `"llm": "deepseek-r1:8b"` and a `thinking` field with the reasoning trace.

### Online mode (GPT-5-nano)

```bash
curl -X POST http://localhost:5678/webhook/edu-rag-query \
     -H "Content-Type: application/json" \
     -d '{"question": "Ce este metafora?", "llm": "gpt"}'
```

### With filters

```json
{ "question": "Ce este celula?", "subject": "biology", "grade": 10 }
```

Supported parameters:
- `question` (required) — string
- `subject` — optional filter (e.g. `biology`, `history`, `romanian`)
- `grade` — optional integer
- `top_k` — number of chunks to retrieve (default 5)
- `llm` — `"local"` (default) or `"gpt"`

---

## Resource footprint

| Component | RAM | Disk |
|---|---|---|
| PostgreSQL + pgvector | ~500 MB | ~500 MB |
| Ollama + 2 models | 5–6 GB | 5.5 GB |
| n8n | ~200 MB | 200 MB |
| **Total** | **~6–7 GB** | **~6.5 GB** |

Cold-start latency for the first offline question after boot is ~30 s (model load into RAM); subsequent questions: 15–30 s on a typical Core i5 mobile CPU.

---

## Multi-language demo

The system auto-detects the language of the question and instructs the LLM to answer in the same language:

| Language | Example question |
|---|---|
| Romanian | `Ce este fotosinteza?` |
| Russian | `Что такое метафора?` |
| English | `What is photosynthesis?` |

---

## Security notes

- Secrets live in `.env` (git-ignored). Never commit a real `.env`.
- The OpenAI API key is stored only inside n8n's encrypted credential store — it is **not** referenced anywhere in `workflow_portable.json` or `EDU_RAG_Portable.json`.
- The default Postgres port (5432) is exposed on `localhost` only by docker-compose. Do not expose it publicly without changing `POSTGRES_PASSWORD` in `.env`.

---

## Troubleshooting

- **Ollama slow on first call** — the model is loaded into RAM on the first request (~30 s). Subsequent calls reuse the loaded weights.
- **n8n timeout on offline mode** — bump the timeout on the `8b. Ollama Local` HTTP node to `300000` (5 min) for very long answers.
- **Out-of-memory** — close the browser and other apps; the offline LLM needs ~6 GB free RAM.
- **Models not found** — `docker exec ollama ollama list` should show both `nomic-embed-text:latest` and `deepseek-r1:8b`.

---

## Stop / clean up

```bash
docker compose -f docker-compose-portable.yml down        # stop containers
docker compose -f docker-compose-portable.yml down -v     # also wipe volumes (DELETES DATA)
```

---

## License

TBD — please add a `LICENSE` file before distributing.

---

## Документация (RU)

Подробное руководство по установке и сценарии демо для жюри — в файле [`DEMO_SETUP.md`](./DEMO_SETUP.md).

Краткая суть проекта по-русски:
- Образовательный RAG-ассистент на школьных учебниках (RO / RU / EN, 11 520 фрагментов).
- Работает на ноутбуке Intel Core i5, 8 GB RAM, **без GPU**.
- Два режима: **OFFLINE** (`deepseek-r1:8b` через Ollama, локально) и **ONLINE** (`gpt-5-nano` через OpenAI API).
- Развёртывание — `docker compose up` + `start_demo.ps1`.
- Все секреты — в `.env` (см. `.env.example`).
