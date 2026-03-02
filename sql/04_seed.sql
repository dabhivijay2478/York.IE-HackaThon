-- York IE Hackathon: Postgres-Native Document Intelligence Engine
-- Seed 5,000+ records for performance testing

-- 500 documents x 10 chunks = 5,000 chunks
INSERT INTO documents (title, source_file, raw_content)
SELECT
  'Document ' || i,
  'file_' || i || '.pdf',
  'Sample raw content for document number ' || i || '. PostgreSQL full-text search ranking and indexing techniques. Document intelligence engine with fuzzy matching.'
FROM generate_series(1, 500) AS s(i);

INSERT INTO document_chunks (document_id, chunk_index, content)
SELECT
  d.id,
  s.chunk,
  'Chunk ' || s.chunk || ' of document: ' || d.title ||
  '. PostgreSQL full-text search ranking and indexing techniques. Document intelligence engine with fuzzy matching and trigram similarity.'
FROM documents d
CROSS JOIN generate_series(1, 10) AS s(chunk);
