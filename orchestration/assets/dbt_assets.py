"""
Wraps the existing dbt project (dbt/) as Dagster software-defined
assets -- one asset per dbt model/seed/snapshot, with dependencies
inferred directly from the dbt DAG itself via dagster-dbt, not
redefined by hand. Delivery-vertical models stay tagged 'delivery'
(same tags used to exclude them in CI, see .github/workflows/dbt_test.yml)
so they show up distinctly in the Dagster UI too.
"""

from pathlib import Path

import dagster as dg
from dagster_dbt import DbtCliResource, DbtProject, dbt_assets

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
DBT_PROJECT_DIR = REPO_ROOT / "dbt"

dbt_project = DbtProject(project_dir=DBT_PROJECT_DIR, profiles_dir=DBT_PROJECT_DIR)
# generates dbt/target/manifest.json on `dagster dev` startup so the
# asset graph reflects whatever's actually in the dbt project right now,
# not a stale committed manifest
dbt_project.prepare_if_dev()


@dbt_assets(manifest=dbt_project.manifest_path, project=dbt_project)
def marketplace_analytics_dbt_assets(context: dg.AssetExecutionContext, dbt: DbtCliResource):
    yield from dbt.cli(["build"], context=context).stream()
