-- York IE Hackathon: Post-ingest maintenance
-- Run after bulk PDF ingestion to keep query performance efficient

-- Update planner statistics for index usage
ANALYZE document_chunks;
ANALYZE documents;

-- Optional: for very large loads (10k+ chunks), run VACUUM to reclaim space
-- VACUUM ANALYZE document_chunks;
