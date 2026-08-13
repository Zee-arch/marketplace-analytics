#!/usr/bin/env python3
"""
(Re)build warehouse/dev.duckdb from the raw files in data/raw/.

Mobility vertical (NYC TLC HVFHV):
  - trips: a VIEW over the HVFHV parquet file(s) -- not copied into the
    database, DuckDB reads the parquet directly at query time
  - zones: a TABLE loaded from the taxi zone lookup CSV

Delivery vertical (Instacart Market Basket):
  - orders, order_products_prior, order_products_train, products, aisles,
    departments: TABLES loaded from data/raw/instacart/*.csv. Tables, not
    views like `trips` -- these are row-based CSVs (order_products_prior
    alone is 577MB/32M rows), not columnar parquet, so materializing once
    beats re-parsing CSV on every query downstream.

Safe to re-run any time (CREATE OR REPLACE on every object). This is the
canonical way to build the warehouse now -- previously done by hand via
ad-hoc `duckdb` CLI commands in an early session, which meant a fresh
checkout (or CI, which never has data/warehouse/ -- both gitignored) had
no way to reconstruct it. Run this after ingest/download_hvfhv.py (and,
for the delivery vertical, after the Instacart CSVs are downloaded from
Kaggle -- see CLAUDE.md for the manual auth step that requires).

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
INSTACART_RAW = DATA_RAW / "instacart"
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
    #
    # union_by_name := true matters as soon as more than one month is
    # present: cbd_congestion_fee doesn't exist in files before 2025
    # (verified -- Dec 2024's schema is missing that column entirely).
    # Without this flag, read_parquet either errors on the schema
    # mismatch or silently aligns columns by POSITION instead of name,
    # which would misassign every column after the missing one. With it,
    # pre-2025 rows correctly get NULL for cbd_congestion_fee instead.
    parquet_glob = str(DATA_RAW / "fhvhv_*.parquet")
    con.execute(f"""
        create or replace view trips as
        select * from read_parquet('{parquet_glob}', union_by_name := true)
    """)
    print(f"trips view -> {len(parquet_files)} file(s): {[f.name for f in parquet_files]}")

    zone_csv = DATA_RAW / "taxi_zone_lookup.csv"
    if not zone_csv.exists():
        raise SystemExit(f"{zone_csv} not found -- run ingest/download_hvfhv.py first")
    con.execute(f"create or replace table zones as select * from read_csv_auto('{zone_csv}')")
    print("zones table loaded")

    trip_count = con.execute("select count(*) from trips").fetchone()[0]
    zone_count = con.execute("select count(*) from zones").fetchone()[0]
    print(f"trips: {trip_count:,} rows, zones: {zone_count:,} rows")

    # -- delivery vertical (Instacart) --
    if INSTACART_RAW.exists():
        instacart_tables = {
            "orders": "orders.csv",
            "order_products_prior": "order_products__prior.csv",
            "order_products_train": "order_products__train.csv",
            "products": "products.csv",
            "aisles": "aisles.csv",
            "departments": "departments.csv",
        }
        missing = [f for f in instacart_tables.values() if not (INSTACART_RAW / f).exists()]
        if missing:
            print(f"Instacart CSVs incomplete, skipping delivery vertical -- missing: {missing}")
        else:
            for table_name, filename in instacart_tables.items():
                csv_path = INSTACART_RAW / filename
                if table_name == "orders":
                    # order_hour_of_day arrives as a zero-padded string
                    # ("08") in the raw CSV, not an integer -- cast it here,
                    # once, instead of every downstream query needing to
                    # remember to cast it
                    con.execute(f"""
                        create or replace table {table_name} as
                        select
                            order_id, user_id, eval_set, order_number,
                            order_dow, cast(order_hour_of_day as integer) as order_hour_of_day,
                            days_since_prior_order
                        from read_csv_auto('{csv_path}')
                    """)
                else:
                    con.execute(
                        f"create or replace table {table_name} as select * from read_csv_auto('{csv_path}')"
                    )
                row_count = con.execute(f"select count(*) from {table_name}").fetchone()[0]
                print(f"{table_name}: {row_count:,} rows")
    else:
        print(f"No {INSTACART_RAW} found -- skipping delivery vertical (mobility-only warehouse)")

    con.close()


if __name__ == "__main__":
    main()
