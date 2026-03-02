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
