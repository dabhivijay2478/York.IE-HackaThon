-- York IE Hackathon: Truncate all data (use only your PDFs from pdfs/)
-- Run this before re-ingesting PDFs to remove all existing data

TRUNCATE document_chunks, documents CASCADE;
