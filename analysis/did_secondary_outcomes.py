"""
Secondary DiD outcomes: did congestion pricing change price-per-trip,
driver-pay-per-trip, or the platform's take rate within the CRZ, on top
of the already-established ~7% volume reduction (docs/memos/02)?

Scope, stated up front: this runs the PRIMARY specification only (holiday
window excluded, outer-borough control) for each outcome, not the full
sensitivity + robustness suite the main volume regression got. That's a
deliberate scoping choice for what the project itself calls "optional
depth," not an oversight -- if any of these three turns up something
surprising, that's the trigger to go back and give it the same full
treatment (sensitivity check + manhattan-north robustness) the primary
outcome got.

Three outcomes, each isolating a different economic question:
  1. avg_base_fare_per_trip: did the average PRICE of a ride in the CRZ
     change? Using per-trip average, not total zone-day revenue --
     total revenue would conflate a price effect with the volume effect
     already measured separately, muddying what's being tested.
  2. avg_driver_pay_per_trip: did individual drivers earn more or less
     per ride? Same per-trip framing, same reasoning.
  3. driver_share_of_fare (driver_pay / base_fare, matching Q7's metric
     from the mobility vertical exploration): did the PLATFORM'S TAKE
     RATE change? If the fee gets passed fully to riders with driver pay
     unaffected, this ratio should barely move. If it doesn't, that's
     evidence about who actually absorbs a new cost -- riders, drivers,
     or the platform's own margin.

Outcomes 1-2 use log(...) (consistent with the volume regression --
percent-effect interpretation, prevents large zones from dominating).
Outcome 3 uses the raw level, since it's already a ratio/proportion --
logging a proportion is less standard and the coefficient is already
directly interpretable as a percentage-point shift.
"""

import warnings
from pathlib import Path

import duckdb
import numpy as np
import pandas as pd
from linearmodels.panel import PanelOLS

warnings.filterwarnings("ignore", category=RuntimeWarning, module="linearmodels")

REPO_ROOT = Path(__file__).resolve().parent.parent
WAREHOUSE = REPO_ROOT / "warehouse" / "dev.duckdb"

HOLIDAY_START = pd.Timestamp("2024-11-20")
HOLIDAY_END = pd.Timestamp("2025-01-02")
MIN_PRESENCE_FRACTION = 0.7


def load_panel() -> pd.DataFrame:
    con = duckdb.connect(str(WAREHOUSE), read_only=True)
    df = con.execute("""
        select trip_date, location_id, zone_group, trip_count,
               total_base_fare, total_driver_pay, is_treatment, is_post
        from mart_did_zone_daily_panel
        where zone_group in ('treatment', 'outer_borough_control')
    """).df()
    con.close()
    df["trip_date"] = pd.to_datetime(df["trip_date"])

    # 1 zone-day out of 41,735 has non-positive driver pay (a refund/
    # adjustment, checked directly) -- excluded, named rather than
    # silently dropped
    n_before = len(df)
    df = df[(df["total_base_fare"] > 0) & (df["total_driver_pay"] > 0)]
    if len(df) != n_before:
        print(f"(dropped {n_before - len(df)} zone-day row(s) with non-positive fare/pay)")

    df["avg_base_fare_per_trip"] = df["total_base_fare"] / df["trip_count"]
    df["avg_driver_pay_per_trip"] = df["total_driver_pay"] / df["trip_count"]
    df["driver_share_of_fare"] = df["total_driver_pay"] / df["total_base_fare"]
    df["log_avg_fare"] = np.log(df["avg_base_fare_per_trip"])
    df["log_avg_pay"] = np.log(df["avg_driver_pay_per_trip"])
    df["did"] = df["is_treatment"] * df["is_post"]
    return df


def drop_sparse_zones(sample: pd.DataFrame) -> pd.DataFrame:
    """Same filter, same reasoning as the main regression: a handful of
    near-singleton zones make their own fixed effect nearly degenerate."""
    n_days_available = sample["trip_date"].nunique()
    days_present = sample.groupby("location_id")["trip_date"].transform("nunique")
    n_before = sample["location_id"].nunique()
    sample = sample[days_present >= MIN_PRESENCE_FRACTION * n_days_available]
    n_after = sample["location_id"].nunique()
    if n_before != n_after:
        print(f"  (dropped {n_before - n_after} near-singleton zone(s))")
    return sample


def run_twfe(df: pd.DataFrame, outcome: str, label: str, is_log: bool):
    sample = df[~((df["trip_date"] >= HOLIDAY_START) & (df["trip_date"] <= HOLIDAY_END))].copy()
    sample = drop_sparse_zones(sample)

    panel = sample.set_index(["location_id", "trip_date"])
    model = PanelOLS.from_formula(f"{outcome} ~ did + EntityEffects + TimeEffects", data=panel, drop_absorbed=True)
    result = model.fit(cov_type="clustered", cluster_entity=True)

    coef = result.params["did"]
    pval = result.pvalues["did"]
    ci_low, ci_high = result.conf_int().loc["did", "lower"], result.conf_int().loc["did", "upper"]

    print(f"\n--- {label} ---")
    print(f"n_obs={result.nobs}, n_zones={sample['location_id'].nunique()}")
    if is_log:
        pct = 100 * (np.exp(coef) - 1)
        pct_low, pct_high = 100 * (np.exp(ci_low) - 1), 100 * (np.exp(ci_high) - 1)
        print(f"coefficient (log points): {coef:.4f}, p={pval:.4f}")
        print(f"implied effect: {pct:+.2f}% [{pct_low:+.2f}%, {pct_high:+.2f}%]")
    else:
        print(f"coefficient (percentage points): {100*coef:+.3f}, p={pval:.4f}")
        print(f"95% CI: [{100*ci_low:+.3f}, {100*ci_high:+.3f}] pp")
    return result


if __name__ == "__main__":
    df = load_panel()

    print("=" * 70)
    print("OUTCOME 1: Average fare per trip (price effect)")
    print("=" * 70)
    run_twfe(df, "log_avg_fare", "PRIMARY: avg base fare per trip", is_log=True)

    print("\n" + "=" * 70)
    print("OUTCOME 2: Average driver pay per trip (earnings effect)")
    print("=" * 70)
    run_twfe(df, "log_avg_pay", "PRIMARY: avg driver pay per trip", is_log=True)

    print("\n" + "=" * 70)
    print("OUTCOME 3: Driver share of fare (platform take-rate effect)")
    print("=" * 70)
    run_twfe(df, "driver_share_of_fare", "PRIMARY: driver share of fare", is_log=False)
