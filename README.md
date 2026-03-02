# Postgres-Native Document Intelligence Engine

York IE Internal Hackathon — fully Postgres-native document search with fuzzy matching, full-text search, and hybrid ranking.

**Data source:** Only PDFs from `pdfs/` folder. No sample or demo data.

---

## Quick Start

### 1. Start PostgreSQL 18

```bash
docker-compose up -d
```

### 2. Run SQL Setup (schema, extensions, triggers, functions)

**Do NOT run 04_seed.sql** — use only your PDFs.

```bash
psql -U hackathon -d doc_engine -h localhost -p 5433 -f sql/00_extensions.sql
psql -U hackathon -d doc_engine -h localhost -p 5433 -f sql/01_schema.sql
psql -U hackathon -d doc_engine -h localhost -p 5433 -f sql/02_triggers.sql
psql -U hackathon -d doc_engine -h localhost -p 5433 -f sql/03_functions.sql
```

Or via Docker:

```bash
for f in sql/00_extensions.sql sql/01_schema.sql sql/02_triggers.sql sql/03_functions.sql; do docker exec -i pg18_hackathon psql -U hackathon -d doc_engine < "$f"; done
```

### 3. Truncate tables (clear all data)

Run before ingesting so only your PDFs are loaded:

```bash
psql -U hackathon -d doc_engine -h localhost -p 5433 -f sql/05_truncate.sql
```

Or via Docker:

```bash
docker exec -i pg18_hackathon psql -U hackathon -d doc_engine < sql/05_truncate.sql
```

### 4. Ingest PDFs from `pdfs/`

Place your PDFs in `pdfs/` and run:

```bash
pip install -r requirements.txt
python3 scripts/ingest_pdfs.py
```

### 5. Verify Performance

```bash
python3 scripts/verify_performance.py
```

---

## Test Queries (run in psql or DB client)

All queries in `sql/06_test_queries.sql`. Run the whole file:

```bash
psql -U hackathon -d doc_engine -h localhost -p 5433 -f sql/06_test_queries.sql
```

Or via Docker:

```bash
docker exec -i pg18_hackathon psql -U hackathon -d doc_engine < sql/06_test_queries.sql
```

### Unit Tests (schema & extensions)

```sql
-- Verify tables
SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename IN ('documents', 'document_chunks');

-- Verify extensions
SELECT extname, extversion FROM pg_extension WHERE extname IN ('pg_trgm', 'unaccent', 'uuid-ossp');

-- Verify indexes
SELECT indexname, tablename FROM pg_indexes WHERE schemaname = 'public' AND tablename IN ('documents', 'document_chunks');
```

### Full-Text Search

```sql
SELECT * FROM search_documents('revenue') LIMIT 5;
SELECT * FROM search_documents('annual report') LIMIT 5;
SELECT * FROM search_documents('financial results') LIMIT 5;
```

### Fuzzy Search (misspelling tolerance, uses word_similarity)

```sql
SELECT * FROM fuzzy_search('reveneu', 0.3) LIMIT 5;      -- finds "revenue"
SELECT * FROM fuzzy_search('consolodated', 0.2) LIMIT 5; -- finds "consolidated"
SELECT * FROM fuzzy_search('dividant', 0.2) LIMIT 5;     -- finds "dividend"
SELECT * FROM fuzzy_search('finansial', 0.15) LIMIT 5;  -- finds "financial"
```

### Hybrid Search (FTS + fuzzy)

```sql
SELECT * FROM hybrid_search('revenue operations') LIMIT 5;
SELECT * FROM hybrid_search('reveneu profit') LIMIT 5;   -- fuzzy finds "revenue"
SELECT * FROM hybrid_search('IFRS press release') LIMIT 5;
SELECT * FROM hybrid_search('Q3 FY26 EBIT') LIMIT 5;
```

### Edge Cases

```sql
-- Empty result
SELECT * FROM search_documents('xyznonexistent123') LIMIT 5;

-- Special characters
SELECT * FROM hybrid_search('revenue & growth') LIMIT 5;

-- Fuzzy high threshold (strict)
SELECT * FROM fuzzy_search('revenue', 0.8) LIMIT 5;

-- Fuzzy low threshold (permissive)
SELECT * FROM fuzzy_search('rev', 0.1) LIMIT 5;
```

### Performance (must be < 150ms)

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) SELECT * FROM hybrid_search('annual report');
```

### Document listing

```sql
SELECT id, title, source_file, created_at FROM documents ORDER BY created_at;
SELECT d.title, COUNT(c.id) AS chunk_count FROM documents d LEFT JOIN document_chunks c ON c.document_id = d.id GROUP BY d.id, d.title;
```

---

## Search Functions

| Function | Usage |
|----------|-------|
| `search_documents(query)` | Full-text search with ts_rank |
| `fuzzy_search(query, threshold)` | word_similarity for misspellings (default 0.3) |
| `hybrid_search(query)` | FTS + trigram combined |

---

## How It Works

### Architecture Overview

```
PDFs (pdfs/) → ingest_pdfs.py → documents + document_chunks
                                        ↓
                              Triggers auto-fill search_vec
                                        ↓
                    GIN indexes (tsvector + trigram) enable fast search
                                        ↓
              search_documents | fuzzy_search | hybrid_search
```

### Schema

- **documents** — One row per PDF: `id`, `title`, `source_file`, `raw_content`, `created_at`, `updated_at`
- **document_chunks** — Text chunks (~500 chars) from each PDF: `id`, `document_id`, `chunk_index`, `content`, `search_vec`, `created_at`
- **search_vec** — tsvector column for full-text search; populated by trigger on INSERT/UPDATE

### Triggers (Real-Time Indexing)

| Trigger | Table | When | What |
|---------|-------|------|------|
| `trg_chunks_search_vec` | document_chunks | BEFORE INSERT/UPDATE | Sets `search_vec := to_tsvector('english', content)` |
| `trg_docs_updated_at` | documents | BEFORE UPDATE | Sets `updated_at := NOW()` |

No manual REINDEX. Triggers keep indices in sync.

### Function 1: `search_documents(query)`

**Purpose:** Full-text search with relevance ranking.

**How it works:**
1. Converts query to tsquery via `websearch_to_tsquery('english', query)` — handles natural phrases like "revenue growth"
2. Filters chunks where `search_vec @@ tsquery` (matches)
3. Ranks with `ts_rank(search_vec, tsquery)` — higher = more relevant
4. Returns top 20 chunks ordered by rank

**Use when:** Exact or near-exact word matches; no misspellings.

### Function 2: `fuzzy_search(query, threshold)`

**Purpose:** Find chunks containing words similar to the query (tolerates misspellings).

**How it works:**
1. Uses `word_similarity(query, content)` from pg_trgm — finds the best-matching word in each chunk
2. `word_similarity` compares the query to each word in the chunk and returns the max similarity (0–1)
3. Filters chunks where similarity ≥ threshold (default 0.3)
4. Returns top 20 chunks ordered by similarity

**Why word_similarity?** `similarity(content, query)` fails on long chunks (low scores). `word_similarity(query, content)` finds the best word match (e.g. "reveneu" → "revenue").

**Use when:** User may misspell; single-word queries work best.

### Function 3: `hybrid_search(query)`

**Purpose:** Combine full-text and fuzzy search for best recall and ranking.

**How it works:**
1. Includes chunks that match FTS **or** have `word_similarity(query, content) >= 0.2`
2. Score = `ts_rank * 0.7 + word_similarity * 0.3` (FTS weighted higher)
3. Returns top 20 chunks ordered by score

**Use when:** General-purpose search; handles both exact and misspelled queries.

### Verify Performance Script

**File:** `scripts/verify_performance.py`

**What it does:**
1. Connects to Postgres (localhost:5433, doc_engine, hackathon)
2. Runs `hybrid_search('document intelligence')` as a warm-up
3. Runs `EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM hybrid_search(...)` to measure execution
4. Parses "Execution Time: X.XXX ms" from the output
5. Passes if < 150ms, fails otherwise

**Run:** `python3 scripts/verify_performance.py`

**Override connection:** Set `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD` env vars.

**Override test query:** Edit `TEST_QUERY` in the script (default: `"document intelligence"`).

### PDF Ingestion Script

**File:** `scripts/ingest_pdfs.py`

**What it does:**
1. Scans `pdfs/` for `*.pdf` files
2. Extracts text with pdfplumber (page by page)
3. Splits text into ~500-character chunks at word boundaries
4. Inserts one row into `documents` (metadata + raw text)
5. Inserts chunk rows into `document_chunks` (content only; trigger fills `search_vec`)

**Run:** `python3 scripts/ingest_pdfs.py` (after SQL setup and truncate)

---

## Connection

| Setting | Value |
|---------|-------|
| Host | localhost |
| Port | 5433 |
| Database | doc_engine |
| User | hackathon |
| Password | hackathon |

---

## Re-ingest PDFs (fresh load)

To clear all data and load only your PDFs again:

```bash
docker exec -i pg18_hackathon psql -U hackathon -d doc_engine < sql/05_truncate.sql
python3 scripts/ingest_pdfs.py
```

---

## Troubleshooting

**Password authentication failed** — Reset volume and recreate:

```bash
docker-compose down -v
docker-compose up -d
sleep 5
```

Then re-run SQL setup (step 2) and truncate (step 3).
