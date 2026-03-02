#!/usr/bin/env python3
"""
York IE Hackathon: Performance verification script.
Runs EXPLAIN ANALYZE on hybrid_search and asserts latency < 150ms.
"""

import os
import re
import sys

import psycopg2

DB_CONFIG = {
    "host": os.environ.get("PGHOST", "localhost"),
    "port": int(os.environ.get("PGPORT", "5433")),
    "dbname": os.environ.get("PGDATABASE", "doc_engine"),
    "user": os.environ.get("PGUSER", "hackathon"),
    "password": os.environ.get("PGPASSWORD", "hackathon"),
}

TARGET_MS = 150
TEST_QUERY = "document intelligence"


def parse_execution_time(explain_output: str) -> float | None:
    """Extract Execution Time (ms) from EXPLAIN ANALYZE output."""
    match = re.search(r"Execution Time:\s*([\d.]+)\s*ms", explain_output)
    return float(match.group(1)) if match else None


def main():
    try:
        conn = psycopg2.connect(**DB_CONFIG)
    except psycopg2.OperationalError as e:
        print(f"Database connection failed: {e}")
        sys.exit(1)

    with conn.cursor() as cur:
        # Run search (warm-up)
        cur.execute("SELECT * FROM hybrid_search(%s)", (TEST_QUERY,))
        rows = cur.fetchall()
        print(f"Search results: {len(rows)} rows for query '{TEST_QUERY}'")

        # EXPLAIN ANALYZE
        cur.execute(
            "EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) SELECT * FROM hybrid_search(%s)",
            (TEST_QUERY,),
        )
        explain = "\n".join(row[0] for row in cur.fetchall())
        print("\nEXPLAIN ANALYZE output:")
        print(explain)

        ms = parse_execution_time(explain)
        if ms is None:
            print("\nCould not parse Execution Time from output")
            sys.exit(1)

        print(f"\nExecution Time: {ms:.2f} ms (target: < {TARGET_MS} ms)")
        if ms <= TARGET_MS:
            print("PASS: Query meets latency requirement")
        else:
            print("FAIL: Query exceeds 150ms target")
            sys.exit(1)

    conn.close()


if __name__ == "__main__":
    main()
