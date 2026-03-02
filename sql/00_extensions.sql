-- York IE Hackathon: Postgres-Native Document Intelligence Engine
-- Required extensions (minimum 3)

-- Trigram fuzzy search and similarity matching
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Accent-insensitive search normalization
CREATE EXTENSION IF NOT EXISTS unaccent;

-- UUID generation for primary keys
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Levenshtein / Soundex matching (optional)
CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;

-- Query performance monitoring
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
