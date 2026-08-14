"""
Top-level Dagster Definitions -- wires together ingestion, warehouse,
and dbt assets, plus a schedule for pulling newly-published TLC data.

Run the dev UI from the repo root:
    dagster dev -m orchestration.definitions
"""

import dagster as dg
from dagster_dbt import DbtCliResource

from .assets.dbt_assets import dbt_project, marketplace_analytics_dbt_assets
from .assets.ingestion import hvfhv_raw_data, instacart_raw_data
from .assets.warehouse import duckdb_warehouse

# TLC publishes HVFHV data with roughly a 2-month lag (per CLAUDE.md) --
# this schedule represents a realistic production pattern for this
# specific pipeline: check on the 2nd of each month whether a newly-
# published month's data is available and pull it. The DiD analysis
# itself uses a fixed historical window (Oct 2024-Mar 2025) and doesn't
# need this to run to stay correct -- this is about keeping the mobility
# vertical current for future exploration, not about the DiD result.
monthly_hvfhv_refresh = dg.ScheduleDefinition(
    name="monthly_hvfhv_refresh",
    cron_schedule="0 6 2 * *",  # 6am UTC, 2nd of every month
    target=dg.AssetSelection.assets(hvfhv_raw_data, duckdb_warehouse),
)

defs = dg.Definitions(
    assets=[hvfhv_raw_data, instacart_raw_data, duckdb_warehouse, marketplace_analytics_dbt_assets],
    schedules=[monthly_hvfhv_refresh],
    resources={"dbt": DbtCliResource(project_dir=dbt_project)},
)
