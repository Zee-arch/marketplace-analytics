#!/usr/bin/env python3
"""
(Re)build warehouse/dev.duckdb from the raw files in data/raw/.

Creates:
  - trips: a VIEW over the HVFHV parquet file(s) -- not copied into the
    database, DuckDB reads the parquet directly at query time
  - zones: a TABLE loaded from the taxi zone lookup CSV

Safe to re-run any time (CREATE OR REPLACE on both objects). This is the
canonical way to build the warehouse now -- previously done by hand via
ad-hoc `duckdb` CLI commands in an early session, which meant a fresh
checkout (or CI, which never has data/warehouse/ -- both gitignored) had
no way to reconstruct it. Run this after ingest/download_hvfhv.py.

Uses an absolute path for the parquet glob, not a relative one -- same
reasoning as the trips view fix documented in CLAUDE.md: a relative path
resolves against whatever directory a command happens to be run from,
which breaks under dbt's normal working directory. An absolute path
avoids that whole category of bug, at the cost of needing to be rebuilt
if the project folder moves (documented tradeoff, not an oversight).
"""
from pathlib import Path

import duckdb

REPO_ROOT = Path(__file__).resolve().parent.parent
DATA_RAW = REPO_ROOT / "data" / "raw"
WAREHOUSE = REPO_ROOT / "warehouse" / "dev.duckdb"


def main():
    WAREHOUSE.parent.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect(str(WAREHOUSE))

    parquet_files = sorted(DATA_RAW.glob("fhvhv_*.parquet"))
    if not parquet_files:
        raise SystemExit(
            f"No fhvhv_*.parquet files found in {DATA_RAW} -- "
            f"run ingest/download_hvfhv.py first"
        )

    # a glob, not a single hardcoded filename -- the view automatically
    # covers every month's file that's actually present, so downloading
    # more months later (e.g. for the congestion-pricing DiD analysis)
    # doesn't require touching this script or recreating the view by hand
    parquet_glob = str(DATA_RAW / "fhvhv_*.parquet")
    con.execute(f"create or replace view trips as select * from read_parquet('{parquet_glob}')")
    print(f"trips view -> {len(parquet_files)} file(s): {[f.name for f in parquet_files]}")

    zone_csv = DATA_RAW / "taxi_zone_lookup.csv"
    if not zone_csv.exists():
        raise SystemExit(f"{zone_csv} not found -- run ingest/download_hvfhv.py first")
    con.execute(f"create or replace table zones as select * from read_csv_auto('{zone_csv}')")
    print("zones table loaded")

    trip_count = con.execute("select count(*) from trips").fetchone()[0]
    zone_count = con.execute("select count(*) from zones").fetchone()[0]
    print(f"trips: {trip_count:,} rows, zones: {zone_count:,} rows")

    con.close()


if __name__ == "__main__":
    main()
