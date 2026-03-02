-- York IE Hackathon: Postgres-Native Document Intelligence Engine
-- Real-time indexing triggers (no manual REINDEX allowed)

-- Trigger: auto-update search_vec on document_chunks INSERT/UPDATE
CREATE OR REPLACE FUNCTION fn_update_search_vec()
RETURNS TRIGGER AS $$
BEGIN
  NEW.search_vec := to_tsvector('english', COALESCE(NEW.content, ''));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_chunks_search_vec
BEFORE INSERT OR UPDATE ON document_chunks
FOR EACH ROW EXECUTE FUNCTION fn_update_search_vec();

-- Trigger: auto-update updated_at on documents
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_docs_updated_at
BEFORE UPDATE ON documents
FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
