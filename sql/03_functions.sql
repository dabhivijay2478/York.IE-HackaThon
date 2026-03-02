-- York IE Hackathon: Postgres-Native Document Intelligence Engine
-- Custom SQL functions (minimum 3 required)

-- Function 1: Full-text search with ranking
-- Uses websearch_to_tsquery for natural language (handles multi-word queries)
CREATE OR REPLACE FUNCTION search_documents(query TEXT)
RETURNS TABLE(
  document_id  UUID,
  title        TEXT,
  chunk        TEXT,
  rank         FLOAT4
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    d.id,
    d.title,
    c.content,
    ts_rank(c.search_vec, websearch_to_tsquery('english', query)) AS rank
  FROM document_chunks c
  JOIN documents d ON d.id = c.document_id
  WHERE c.search_vec @@ websearch_to_tsquery('english', query)
  ORDER BY rank DESC
  LIMIT 20;
END;
$$ LANGUAGE plpgsql;

-- Function 2: Fuzzy search (trigram-based, tolerates misspellings)
-- Uses word_similarity: finds best-matching word in chunk (works for long content)
-- similarity(content, query) fails on long chunks; word_similarity(query, content) works
CREATE OR REPLACE FUNCTION fuzzy_search(query TEXT, threshold FLOAT DEFAULT 0.3)
RETURNS TABLE(
  document_id  UUID,
  title        TEXT,
  chunk        TEXT,
  similarity   FLOAT4
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    d.id,
    d.title,
    c.content,
    word_similarity(query, c.content) AS sim
  FROM document_chunks c
  JOIN documents d ON d.id = c.document_id
  WHERE word_similarity(query, c.content) >= threshold
  ORDER BY sim DESC
  LIMIT 20;
END;
$$ LANGUAGE plpgsql;

-- Function 3: Hybrid ranked search (FTS + trigram)
CREATE OR REPLACE FUNCTION hybrid_search(query TEXT)
RETURNS TABLE(
  document_id  UUID,
  title        TEXT,
  chunk        TEXT,
  score        FLOAT4
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    d.id,
    d.title,
    c.content,
    (
      COALESCE(ts_rank(c.search_vec, websearch_to_tsquery('english', query)), 0) * 0.7
      + COALESCE(word_similarity(query, c.content), 0) * 0.3
    )::FLOAT4 AS score
  FROM document_chunks c
  JOIN documents d ON d.id = c.document_id
  WHERE
    c.search_vec @@ websearch_to_tsquery('english', query)
    OR word_similarity(query, c.content) >= 0.2
  ORDER BY score DESC
  LIMIT 20;
END;
$$ LANGUAGE plpgsql;
