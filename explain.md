
# Extensions Used and Their Purpose

## Summary Table

| Extension | Install Command | Purpose | Where Used |
|-----------|----------------|---------|------------|
| **pg_trgm** | `CREATE EXTENSION pg_trgm;` | Trigram-based fuzzy search | `fuzzy_search`, `hybrid_search`, GIN trigram indexes |
| **unaccent** | `CREATE EXTENSION unaccent;` | Accent-insensitive search | Enabled for future use |
| **uuid-ossp** | `CREATE EXTENSION "uuid-ossp";` | UUID generation | Primary keys in `documents`, `document_chunks` |
| **fuzzystrmatch** | `CREATE EXTENSION fuzzystrmatch;` | Levenshtein / Soundex | Enabled for future use |
| **pg_stat_statements** | `CREATE EXTENSION pg_stat_statements;` | Query performance monitoring | Latency checks, slow query analysis |

---

## 1. pg_trgm

**Purpose:** Trigram-based fuzzy text search and similarity.

**Provides:**
- `similarity(text1, text2)` – similarity score (0–1)
- `word_similarity(query, content)` – best word match in content
- `gin_trgm_ops` – GIN index operator class for trigrams
- Operators: `%` (similarity), `%>` (word similarity)

**Used in:**
- `fuzzy_search()` – `word_similarity(query, content)`
- `hybrid_search()` – `word_similarity(query, content)`
- `idx_chunks_trgm` – `GIN (content gin_trgm_ops)`
- `idx_docs_title_trgm` – `GIN (title gin_trgm_ops)`

**Example:**
```sql
SELECT word_similarity('reveneu', 'Revenue from operations');  -- 0.625
```

---

## 2. unaccent

**Purpose:** Remove accents for accent-insensitive search.

**Provides:**
- `unaccent(text)` – e.g. `'café'` → `'cafe'`, `'Zürich'` → `'Zurich'`

**Used in:** Not used in current code; enabled for future use.

**Possible use:**
```sql
-- In trigger: to_tsvector('english', unaccent(content))
-- So "café" and "cafe" match
```

---

## 3. uuid-ossp

**Purpose:** Generate UUIDs for primary keys.

**Provides:**
- `uuid_generate_v4()` – random UUIDs

**Used in:**
- `documents.id` – `DEFAULT uuid_generate_v4()`
- `document_chunks.id` – `DEFAULT uuid_generate_v4()`


---

## 4. fuzzystrmatch

**Purpose:** String distance and phonetic matching.

**Provides:**
- `levenshtein(text1, text2)` – edit distance
- `soundex(text)` – phonetic code
- `metaphone(text)` – phonetic representation

**Used in:** Not used in current code; enabled for hackathon and future use.

**Possible use:**
```sql
SELECT levenshtein('reveneu', 'revenue');  -- 1
```

---

## 5. pg_stat_statements

**Purpose:** Track query execution statistics.

**Provides:**
- `pg_stat_statements` view with `query`, `calls`, `mean_exec_time`, etc.

**Used in:**
- Performance checks (e.g. &lt; 150 ms)
- Slow query analysis

**Example:**
```sql
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;
```

---

## Quick Reference

| Extension | Main use in this project |
|-----------|---------------------------|
| **pg_trgm** | Fuzzy search, trigram indexes |
| **unaccent** | Accent normalization (optional) |
| **uuid-ossp** | UUID primary keys |
| **fuzzystrmatch** | Levenshtein / phonetic (optional) |
| **pg_stat_statements** | Query performance monitoring |

---

## Verify Extensions

```sql
SELECT extname, extversion FROM pg_extension ORDER BY extname;
```