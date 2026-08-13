"""
Follow-up to parallel_trends.py: the naive pre-period linear-trend test
found a statistically significant treatment*time interaction (p=0.019).
But the chart it produced shows why that's likely misleading -- the
pre-period contains an extreme, one-off holiday-season swing
(Thanksgiving dip, December peak, a severe Christmas/New Year's crash)
that hits treatment (Manhattan CBD -- offices, tourists, holiday retail)
far harder than control (residential outer boroughs). A straight line
fit through that swing can easily read as "differential trend" when it's
really "differential sensitivity to one seasonal event," which is a
different (and less damaging) problem.

This script re-runs the pre-trend test two ways to find out which
explanation holds:
  1. Same test, holiday window (2024-11-20 to 2025-01-02, Thanksgiving
     through just after New Year's) excluded -- does the interaction
     term stay significant once the swing is removed?
  2. Same test against the alternate control group
     (manhattan_north_control -- same borough, outside the CRZ) as a
     robustness check independent of the outer-borough comparison.
"""

from pathlib import Path

import duckdb
import pandas as pd
import statsmodels.formula.api as smf

REPO_ROOT = Path(__file__).resolve().parent.parent
WAREHOUSE = REPO_ROOT / "warehouse" / "dev.duckdb"

PRE_PERIOD_END = pd.Timestamp("2025-01-04")
HOLIDAY_START = pd.Timestamp("2024-11-20")
HOLIDAY_END = pd.Timestamp("2025-01-02")


def load_panel(control_group: str) -> pd.DataFrame:
    con = duckdb.connect(str(WAREHOUSE), read_only=True)
    df = con.execute(f"""
        select
            trip_date, zone_group,
            sum(trip_count) as trip_count,
            count(distinct location_id) as n_zones
        from mart_did_zone_daily_panel
        where zone_group in ('treatment', '{control_group}')
        group by 1, 2
        order by 1, 2
    """).df()
    con.close()
    df["trip_date"] = pd.to_datetime(df["trip_date"])
    df["avg_trips_per_zone"] = df["trip_count"] / df["n_zones"]
    return df


def run_trend_test(df: pd.DataFrame, exclude_holidays: bool, label: str):
    pre = df[df["trip_date"] <= PRE_PERIOD_END].copy()
    if exclude_holidays:
        pre = pre[~((pre["trip_date"] >= HOLIDAY_START) & (pre["trip_date"] <= HOLIDAY_END))]
    pre["days_since_start"] = (pre["trip_date"] - pre["trip_date"].min()).dt.days
    pre["is_treatment"] = (pre["zone_group"] == "treatment").astype(int)

    model = smf.ols("avg_trips_per_zone ~ is_treatment * days_since_start", data=pre).fit(cov_type="HC1")
    coef = model.params["is_treatment:days_since_start"]
    pval = model.pvalues["is_treatment:days_since_start"]
    se = model.bse["is_treatment:days_since_start"]
    print(f"{label}: n={len(pre)}, interaction coef={coef:.3f} (se={se:.3f}), p={pval:.4f}")
    return model


if __name__ == "__main__":
    print("=== Primary control: outer boroughs ===")
    df_outer = load_panel("outer_borough_control")
    run_trend_test(df_outer, exclude_holidays=False, label="Full pre-period (incl. holidays)")
    run_trend_test(df_outer, exclude_holidays=True, label="Holiday window excluded  ")

    print("\n=== Robustness check: Manhattan-north control ===")
    df_manhattan = load_panel("manhattan_north_control")
    run_trend_test(df_manhattan, exclude_holidays=False, label="Full pre-period (incl. holidays)")
    run_trend_test(df_manhattan, exclude_holidays=True, label="Holiday window excluded  ")
