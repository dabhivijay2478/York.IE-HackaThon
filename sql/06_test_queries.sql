-- York IE Hackathon: Test Queries
-- Tailored to Financial Reports PDFs: TCS, Infosys, Tech Mahindra
-- Run in psql or DB client. Data from pdfs/ only.

-- ============================================================
-- 1. SCHEMA & EXTENSION CHECKS (Unit Tests)
-- ============================================================

-- 1.1 Verify tables exist
SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename IN ('documents', 'document_chunks');

-- 1.2 Verify extensions enabled
SELECT extname, extversion FROM pg_extension WHERE extname IN ('pg_trgm', 'unaccent', 'uuid-ossp');

-- 1.3 Verify indexes exist
SELECT indexname, tablename FROM pg_indexes WHERE schemaname = 'public' AND tablename IN ('documents', 'document_chunks');

-- 1.4 Verify triggers exist
SELECT tgname, tgrelid::regclass FROM pg_trigger WHERE tgname IN ('trg_chunks_search_vec', 'trg_docs_updated_at');

-- ============================================================
-- 2. DATA INTEGRITY (Unit Tests)
-- ============================================================

-- 2.1 Count documents and chunks
SELECT COUNT(*) AS doc_count FROM documents;
SELECT COUNT(*) AS chunk_count FROM document_chunks;

-- 2.2 All chunks must have valid document_id
SELECT COUNT(*) AS orphan_chunks FROM document_chunks c WHERE NOT EXISTS (SELECT 1 FROM documents d WHERE d.id = c.document_id);

-- 2.3 All chunks must have search_vec populated (trigger check)
SELECT COUNT(*) AS null_search_vec FROM document_chunks WHERE search_vec IS NULL AND content IS NOT NULL;

-- ============================================================
-- 3. FULL-TEXT SEARCH (search_documents) - TCS Content
-- ============================================================

-- 3.1 TCS revenue
SELECT * FROM search_documents('revenue from operations') LIMIT 5;

-- 3.2 TCS consolidated financial results
SELECT * FROM search_documents('consolidated interim statement') LIMIT 5;

-- 3.3 TCS segment revenue
SELECT * FROM search_documents('Banking Financial Services Insurance') LIMIT 5;

-- 3.4 TCS dividend
SELECT * FROM search_documents('interim dividend') LIMIT 5;

-- 3.5 TCS Krithivasan CEO
SELECT * FROM search_documents('Krithivasan CEO Managing Director') LIMIT 5;

-- ============================================================
-- 4. FULL-TEXT SEARCH - Infosys Content
-- ============================================================

-- 4.1 Infosys IFRS
SELECT * FROM search_documents('IFRS constant currency') LIMIT 5;

-- 4.2 Infosys Salil Parekh
SELECT * FROM search_documents('Salil Parekh CEO') LIMIT 5;

-- 4.3 Infosys large deal TCV
SELECT * FROM search_documents('large deal TCV') LIMIT 5;

-- 4.4 Infosys FCF free cash flow
SELECT * FROM search_documents('FCF free cash flow') LIMIT 5;

-- 4.5 Infosys share buyback
SELECT * FROM search_documents('share buyback dividend') LIMIT 5;

-- ============================================================
-- 5. FULL-TEXT SEARCH - Tech Mahindra Content
-- ============================================================

-- 5.1 Tech Mahindra EBIT
SELECT * FROM search_documents('EBIT margin') LIMIT 5;

-- 5.2 Tech Mahindra Mohit Joshi
SELECT * FROM search_documents('Mohit Joshi CEO') LIMIT 5;

-- 5.3 Tech Mahindra deal wins
SELECT * FROM search_documents('deal wins TCV') LIMIT 5;

-- 5.4 Tech Mahindra Gemini AWS
SELECT * FROM search_documents('Gemini Enterprise AWS') LIMIT 5;

-- 5.5 Tech Mahindra i.GreenFinance
SELECT * FROM search_documents('i.GreenFinance sustainable lending') LIMIT 5;

-- ============================================================
-- 6. FUZZY SEARCH (fuzzy_search) - Misspelling tolerance
-- Uses word_similarity: finds best-matching word in chunk
-- Single-word misspellings work best (e.g. "reveneu" -> "revenue")
-- ============================================================

-- 6.1 Misspelling: "revenue" -> "reveneu"
SELECT * FROM fuzzy_search('reveneu', 0.3) LIMIT 5;

-- 6.2 Misspelling: "consolidated" -> "consolodated"
SELECT * FROM fuzzy_search('consolodated', 0.2) LIMIT 5;

-- 6.3 Misspelling: "dividend" -> "dividant"
SELECT * FROM fuzzy_search('dividant', 0.2) LIMIT 5;

-- 6.4 Misspelling: "financial" -> "finansial"
SELECT * FROM fuzzy_search('finansial', 0.15) LIMIT 5;

-- 6.5 Misspelling: "Infosys" -> "Infossys"
SELECT * FROM fuzzy_search('Infossys', 0.2) LIMIT 5;

-- 6.6 Misspelling: "operations" -> "operatons"
SELECT * FROM fuzzy_search('operatons', 0.2) LIMIT 5;

-- ============================================================
-- 7. HYBRID SEARCH (hybrid_search) - FTS + Fuzzy combined
-- ============================================================

-- 7.1 TCS Q1 FY26
SELECT * FROM hybrid_search('TCS Q1 FY26 revenue') LIMIT 5;

-- 7.2 Infosys Q2 FY26
SELECT * FROM hybrid_search('Infosys Q2 FY26') LIMIT 5;

-- 7.3 Tech Mahindra Q3 FY26
SELECT * FROM hybrid_search('Tech Mahindra Q3 FY26 EBIT') LIMIT 5;

-- 7.4 Cross-doc: revenue growth
SELECT * FROM hybrid_search('revenue growth crore') LIMIT 5;

-- 7.5 With misspelling
SELECT * FROM hybrid_search('reveneu profit tax') LIMIT 5;

-- 7.6 Dividend across all reports
SELECT * FROM hybrid_search('dividend per share') LIMIT 5;

-- 7.7 Segment information
SELECT * FROM hybrid_search('segment revenue Manufacturing') LIMIT 5;

-- ============================================================
-- 8. EDGE CASES
-- ============================================================

-- 8.1 Empty result (no match)
SELECT * FROM search_documents('xyznonexistent123') LIMIT 5;

-- 8.2 Special characters
SELECT * FROM hybrid_search('revenue & profit') LIMIT 5;

-- 8.3 Numbers in query
SELECT * FROM hybrid_search('63437 crore') LIMIT 5;

-- 8.4 Fuzzy high threshold (strict, exact-ish match)
SELECT * FROM fuzzy_search('revenue', 0.8) LIMIT 5;

-- 8.5 Fuzzy low threshold (permissive, short query)
SELECT * FROM fuzzy_search('rev', 0.1) LIMIT 5;

-- ============================================================
-- 9. PERFORMANCE VERIFICATION (must be < 150ms)
-- ============================================================

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) SELECT * FROM hybrid_search('revenue operations');

-- Optional: timing in psql
-- \timing on
-- SELECT * FROM hybrid_search('revenue operations') LIMIT 10;
-- \timing off

-- ============================================================
-- 10. DOCUMENT-SPECIFIC QUERIES
-- ============================================================

-- 10.1 List all documents (TCS, Infosys, Tech Mahindra)
SELECT id, title, source_file, created_at FROM documents ORDER BY created_at;

-- 10.2 Chunks per document
SELECT d.title, COUNT(c.id) AS chunk_count FROM documents d LEFT JOIN document_chunks c ON c.document_id = d.id GROUP BY d.id, d.title;

-- 10.3 Search only TCS docs (by title pattern)
SELECT * FROM hybrid_search('consolidated standalone') LIMIT 5;

-- 10.4 Search Infosys-specific terms
SELECT * FROM hybrid_search('Bengaluru October 2025') LIMIT 5;

-- 10.5 Search Tech Mahindra-specific terms
SELECT * FROM hybrid_search('Mumbai January 2026') LIMIT 5;
