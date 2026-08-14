"""
Dagster asset for building warehouse/dev.duckdb. Wraps
ingest/init_warehouse.py's own main() function -- same logic whether
triggered by Dagster or run by hand.

Defined as a multi_asset with one output per dbt source table (see
dbt/models/staging/_sources.yml), using the exact asset keys dagster-dbt
assigns those sources by default -- checked directly
(AssetKey(["raw", "trips"]) etc.), not assumed. @dbt_assets has no plain
`deps` parameter for an external upstream asset (checked the function
signature directly, see dbt_assets.py's comment); the documented
dagster-dbt pattern for "a non-dbt asset feeds dbt's sources" is to have
that asset's own output keys match what dbt's source nodes already
resolve to, so the dependency wires up automatically instead of needing
a custom translator.
"""

import sys
from pathlib import Path

import dagster as dg

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(REPO_ROOT))

from ingest.init_warehouse import main as build_warehouse  # noqa: E402

from .ingestion import hvfhv_raw_data

# every table dbt's `raw` source declares (dbt/models/staging/_sources.yml)
WAREHOUSE_TABLES = [
    "trips", "zones",
    "orders", "products", "aisles", "departments",
    "order_products_prior", "order_products_train",
]


@dg.multi_asset(
    outs={
        table: dg.AssetOut(key=dg.AssetKey(["raw", table]), is_required=False)
        for table in WAREHOUSE_TABLES
    },
    deps=[hvfhv_raw_data],
    can_subset=False,
    group_name="warehouse",
    name="duckdb_warehouse",
    description=(
        "warehouse/dev.duckdb -- trips view + zones table (mobility), "
        "orders/products/etc tables (delivery, if present). Deliberately "
        "NOT hard-dependent on instacart_raw_data (see ingestion.py) -- "
        "init_warehouse.py's own logic already skips the delivery vertical "
        "gracefully when its raw files aren't there. To build both "
        "verticals, materialize instacart_raw_data first, then this asset."
    ),
)
def duckdb_warehouse(context: dg.AssetExecutionContext):
    import duckdb

    build_warehouse()
    context.log.info("Warehouse built from whichever raw data is present.")

    # only report the outputs that actually exist -- build_warehouse()
    # skips the delivery-vertical tables gracefully when Instacart data
    # isn't present, and is_required=False on those AssetOuts means
    # Dagster expects that possibility rather than treating it as a
    # failure to yield a declared output
    con = duckdb.connect(str(REPO_ROOT / "warehouse" / "dev.duckdb"), read_only=True)
    existing_tables = {row[0] for row in con.execute("show tables").fetchall()}
    con.close()

    for table in WAREHOUSE_TABLES:
        if table in existing_tables:
            yield dg.MaterializeResult(asset_key=dg.AssetKey(["raw", table]))
        else:
            context.log.info(f"'{table}' not built (source data not present) -- skipping its output")
