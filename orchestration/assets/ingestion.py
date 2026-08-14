"""
Dagster assets for pulling raw data into data/raw/. Wraps the existing
ingest/ scripts' functions directly rather than reimplementing their
logic or shelling out to them -- these are the exact same functions used
when running the scripts by hand from the command line, so behavior
(idempotent skip-if-exists, retries) stays identical either way.
"""

import sys
from pathlib import Path

import dagster as dg

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(REPO_ROOT))

from ingest.download_hvfhv import download_month, download_zone_lookup  # noqa: E402

# The exact 6 months this project's DiD analysis needs: Oct 2024 (start
# of the clean pre-period) through Mar 2025 (most recent post-period
# month). Configured here explicitly, not inferred, so the monthly
# schedule (definitions.py) has one clear place to extend later.
HVFHV_MONTHS = ["2024-10", "2024-11", "2024-12", "2025-01", "2025-02", "2025-03"]


@dg.asset(
    group_name="ingestion",
    description="NYC TLC HVFHV trip data + zone lookup for every month this project needs.",
)
def hvfhv_raw_data(context: dg.AssetExecutionContext) -> dg.MaterializeResult:
    download_zone_lookup()
    for month in HVFHV_MONTHS:
        download_month(month)
    context.log.info(f"HVFHV data present for: {HVFHV_MONTHS}")
    return dg.MaterializeResult(metadata={"months": HVFHV_MONTHS})


@dg.asset(
    group_name="ingestion",
    description=(
        "Instacart delivery-vertical raw data. Checks for the expected "
        "files rather than attempting an automated Kaggle download -- the "
        "credential (see CLAUDE.md) is a personal one that shouldn't be "
        "assumed present or silently re-fetched by an orchestrator. Not a "
        "hard dependency of duckdb_warehouse (see warehouse.py) -- the "
        "mobility vertical should materialize fine without it, same as "
        "ingest/init_warehouse.py's own graceful-skip behavior when run "
        "by hand."
    ),
)
def instacart_raw_data(context: dg.AssetExecutionContext) -> dg.MaterializeResult:
    instacart_dir = REPO_ROOT / "data" / "raw" / "instacart"
    expected_files = [
        "orders.csv", "order_products__prior.csv", "order_products__train.csv",
        "products.csv", "aisles.csv", "departments.csv",
    ]
    missing = [f for f in expected_files if not (instacart_dir / f).exists()]
    if missing:
        raise dg.Failure(
            description=(
                f"Missing Instacart files: {missing}. Download manually first: "
                "kaggle datasets download -d yasserh/instacart-online-grocery-basket-analysis-dataset "
                "-p data/raw/instacart --unzip "
                "(needs ~/.kaggle/kaggle.json -- see CLAUDE.md for setup)"
            )
        )
    context.log.info("Instacart data present.")
    return dg.MaterializeResult(metadata={"files": expected_files})
