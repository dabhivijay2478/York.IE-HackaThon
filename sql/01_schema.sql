-- York IE Hackathon: Postgres-Native Document Intelligence Engine
-- Raw SQL DDL - no ORM-generated schema

-- Documents: metadata and raw content
CREATE TABLE documents (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title        TEXT NOT NULL,
  source_file  TEXT NOT NULL,
  raw_content  TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Document chunks: parsed content with search vectors
CREATE TABLE document_chunks (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  document_id  UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
  chunk_index  INT NOT NULL,
  content      TEXT NOT NULL,
  search_vec   TSVECTOR,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Full-text search: GIN on tsvector
CREATE INDEX idx_chunks_fts ON document_chunks USING GIN (search_vec);

-- Fuzzy search: GIN trigram on content
CREATE INDEX idx_chunks_trgm ON document_chunks USING GIN (content gin_trgm_ops);

-- Fast lookup by document
CREATE INDEX idx_chunks_doc_id ON document_chunks (document_id);

-- Fuzzy lookup by document title
CREATE INDEX idx_docs_title_trgm ON documents USING GIN (title gin_trgm_ops);
