#!/usr/bin/env python3
"""
York IE Hackathon: PDF ingestion script.
Parses PDFs and loads content into Postgres (documents + document_chunks).
Triggers auto-populate search_vec on INSERT.
"""

import os
import sys
from pathlib import Path

import pdfplumber
import psycopg2
from psycopg2.extras import execute_values

# Default connection (override via env)
DB_CONFIG = {
    "host": os.environ.get("PGHOST", "localhost"),
    "port": int(os.environ.get("PGPORT", "5433")),
    "dbname": os.environ.get("PGDATABASE", "doc_engine"),
    "user": os.environ.get("PGUSER", "hackathon"),
    "password": os.environ.get("PGPASSWORD", "hackathon"),
}

CHUNK_SIZE = 500  # characters per chunk


def extract_text_from_pdf(pdf_path: Path) -> str:
    """Extract all text from a PDF file."""
    text_parts = []
    with pdfplumber.open(pdf_path) as pdf:
        for page in pdf.pages:
            page_text = page.extract_text()
            if page_text:
                text_parts.append(page_text)
    return "\n\n".join(text_parts)


def chunk_text(text: str, size: int = CHUNK_SIZE) -> list[str]:
    """Split text into chunks of approximately `size` characters."""
    if not text or not text.strip():
        return []
    chunks = []
    start = 0
    idx = 0
    while start < len(text):
        end = min(start + size, len(text))
        # Try to break at word boundary
        if end < len(text):
            last_space = text.rfind(" ", start, end + 1)
            if last_space > start:
                end = last_space + 1
        chunk = text[start:end].strip()
        if chunk:
            chunks.append((idx, chunk))
            idx += 1
        start = end
    return chunks


def ingest_pdf(conn, pdf_path: Path) -> None:
    """Ingest a single PDF into documents and document_chunks."""
    pdf_path = Path(pdf_path)
    if not pdf_path.exists():
        raise FileNotFoundError(f"PDF not found: {pdf_path}")

    raw_text = extract_text_from_pdf(pdf_path)
    if not raw_text.strip():
        print(f"Warning: No text extracted from {pdf_path.name}")
        return

    chunks = chunk_text(raw_text)
    if not chunks:
        print(f"Warning: No chunks from {pdf_path.name}")
        return

    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO documents (title, source_file, raw_content)
            VALUES (%s, %s, %s)
            RETURNING id
            """,
            (pdf_path.stem, pdf_path.name, raw_text),
        )
        doc_id = cur.fetchone()[0]

        rows = [(doc_id, idx, content) for idx, content in chunks]
        execute_values(
            cur,
            """
            INSERT INTO document_chunks (document_id, chunk_index, content)
            VALUES %s
            """,
            rows,
        )

    conn.commit()
    print(f"Ingested {pdf_path.name}: {len(chunks)} chunks")


def main():
    pdfs_dir = Path(__file__).parent.parent / "pdfs"
    if not pdfs_dir.exists():
        pdfs_dir.mkdir(parents=True)
        print(f"Created {pdfs_dir}. Place PDF files there and re-run.")
        sys.exit(0)

    pdf_files = list(pdfs_dir.glob("*.pdf"))
    if not pdf_files:
        print(f"No PDF files in {pdfs_dir}")
        sys.exit(1)

    try:
        conn = psycopg2.connect(**DB_CONFIG)
    except psycopg2.OperationalError as e:
        print(f"Database connection failed: {e}")
        print("Ensure PostgreSQL is running (e.g. docker-compose up -d)")
        sys.exit(1)

    try:
        for pdf_path in sorted(pdf_files):
            ingest_pdf(conn, pdf_path)
    finally:
        conn.close()


if __name__ == "__main__":
    main()
