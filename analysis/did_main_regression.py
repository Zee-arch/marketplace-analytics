"""
Main difference-in-differences regression: did NYC's congestion pricing
policy (effective 2025-01-05) reduce HVFHV trip volume in the Congestion
Relief Zone, relative to control?

Specification: two-way fixed effects panel regression --

    log(trip_count)_zt = a_z + a_t + B * (is_treatment_z * is_post_t) + e_zt

  - a_z (zone fixed effects): absorbs every time-invariant zone
    characteristic (baseline demand level, being an airport, whatever
    makes one zone busier than another on average) -- the DiD coefficient
    is NOT confounded by zones simply being different sizes.
  - a_t (day fixed effects): absorbs every common day-level shock that
    hits all zones equally (a snowstorm, a citywide event).
  - B, the coefficient on the treatment*post interaction, is the DiD
    estimate itself: the CHANGE in the treatment-control gap from before
    to after the policy, net of both fixed effects.
  - log(trip_count), not raw counts: turns B into an approximate percent
    effect (100*B for small B; exact percent change is 100*(exp(B)-1)),
    and is standard practice here since zones vary enormously in size --
    a level regression would be dominated by the largest zones.
  - Clustered standard errors by zone: daily trip counts within the same
    zone are serially correlated (today's volume predicts tomorrow's) --
    treating each zone-day as an independent observation would understate
    the true uncertainty.

Two specifications are run, not one, because of what the parallel-trends
check (docs/memos/01_parallel_trends_check.md) found:
  - PRIMARY: holiday window (2024-11-20 to 2025-01-02) excluded from the
    sample entirely -- the same window whose removal made the pre-trend
    test pass. Keeps the main regression's pre-period consistent with the
    pre-period that was actually validated.
  - SENSITIVITY: full sample, holidays included -- reported alongside the
    primary result specifically to show whether the substantive
    conclusion depends on that choice, not just asserted that it doesn't.

A third specification reruns the PRIMARY spec against
manhattan_north_control instead of outer_borough_control -- the same
robustness check used in the parallel-trends memo, carried through here.
"""

import warnings
from pathlib import Path

import duckdb
import numpy as np
import pandas as pd
from linearmodels.panel import PanelOLS

# linearmodels raises RuntimeWarning (divide by zero / overflow in matmul)
# from internal intermediate computations with this data shape -- checked
# directly (not assumed): the actual reported coefficient, standard
# error, p-value, confidence interval, and the auxiliary poolability
# F-test are all well-defined finite numbers regardless. Traced the
# warnings to linearmodels/panel/covariance.py:313, part of the clustered
# covariance machinery, not the point estimate itself. Suppressing the
# noise here because it's been verified benign, not because it was
# ignored.
warnings.filterwarnings("ignore", category=RuntimeWarning, module="linearmodels")

REPO_ROOT = Path(__file__).resolve().parent.parent
WAREHOUSE = REPO_ROOT / "warehouse" / "dev.duckdb"

HOLIDAY_START = pd.Timestamp("2024-11-20")
HOLIDAY_END = pd.Timestamp("2025-01-02")


# fraction of the sample's own available days a zone must be present for
# to stay in the regression -- applied per-sample (not a fixed day count),
# since the holiday-excluded sample (138 possible days) and full sample
# (182 possible days) have different denominators
MIN_PRESENCE_FRACTION = 0.7


def load_panel(control_group: str) -> pd.DataFrame:
    con = duckdb.connect(str(WAREHOUSE), read_only=True)
    df = con.execute(f"""
        select trip_date, location_id, zone_group, trip_count, is_treatment, is_post
        from mart_did_zone_daily_panel
        where zone_group in ('treatment', '{control_group}')
    """).df()
    con.close()
    df["trip_date"] = pd.to_datetime(df["trip_date"])
    df["log_trip_count"] = np.log(df["trip_count"])
    df["did"] = df["is_treatment"] * df["is_post"]
    return df


def drop_sparse_zones(sample: pd.DataFrame) -> pd.DataFrame:
    """Drop near-singleton zones: a handful of extremely sparse zones
    (Governor's Island, Rikers Island, Great Kills Park, Jamaica Bay --
    checked directly: a clean gap between these and everyone else, who
    sit at ~95-100% presence) make their own entity fixed effect nearly
    degenerate under two-way FE, producing divide-by-zero/overflow
    warnings in the variance decomposition. These zones (a park, a
    prison island, mostly-water areas) also aren't substantively part of
    the ride-hail marketplace this analysis is about -- excluding them
    is defensible on both numerical and substantive grounds, not just to
    make a warning disappear."""
    n_days_available = sample["trip_date"].nunique()
    days_present = sample.groupby("location_id")["trip_date"].transform("nunique")
    n_before = sample["location_id"].nunique()
    sample = sample[days_present >= MIN_PRESENCE_FRACTION * n_days_available]
    n_after = sample["location_id"].nunique()
    if n_before != n_after:
        print(f"  (dropped {n_before - n_after} near-singleton zone(s), <{MIN_PRESENCE_FRACTION:.0%} of {n_days_available} days present)")
    return sample


def run_twfe(df: pd.DataFrame, exclude_holidays: bool, label: str):
    sample = df.copy()
    if exclude_holidays:
        sample = sample[~((sample["trip_date"] >= HOLIDAY_START) & (sample["trip_date"] <= HOLIDAY_END))]
    sample = drop_sparse_zones(sample)

    # linearmodels' PanelOLS needs a (entity, time) MultiIndex -- entity
    # = zone (for entity_effects), time = date (for time_effects)
    panel = sample.set_index(["location_id", "trip_date"])

    model = PanelOLS.from_formula(
        "log_trip_count ~ did + EntityEffects + TimeEffects",
        data=panel,
        drop_absorbed=True,
    )
    result = model.fit(cov_type="clustered", cluster_entity=True)

    coef = result.params["did"]
    pval = result.pvalues["did"]
    se = result.std_errors["did"]
    pct_effect = 100 * (np.exp(coef) - 1)

    n_zones = sample["location_id"].nunique()
    n_days = sample["trip_date"].nunique()
    print(f"\n--- {label} ---")
    print(f"n_obs={result.nobs}, n_zones={n_zones}, n_days={n_days}")
    print(f"DiD coefficient (log points): {coef:.4f} (se={se:.4f}), p={pval:.4f}")
    print(f"Implied effect on trip volume: {pct_effect:+.2f}%")
    print(f"95% CI on log coef: [{result.conf_int().loc['did', 'lower']:.4f}, {result.conf_int().loc['did', 'upper']:.4f}]")
    ci_low_pct = 100 * (np.exp(result.conf_int().loc["did", "lower"]) - 1)
    ci_high_pct = 100 * (np.exp(result.conf_int().loc["did", "upper"]) - 1)
    print(f"95% CI on % effect: [{ci_low_pct:+.2f}%, {ci_high_pct:+.2f}%]")
    return result


if __name__ == "__main__":
    print("=" * 70)
    print("PRIMARY COMPARISON: treatment vs. outer_borough_control")
    print("=" * 70)
    df_outer = load_panel("outer_borough_control")
    run_twfe(df_outer, exclude_holidays=True, label="PRIMARY: holidays excluded")
    run_twfe(df_outer, exclude_holidays=False, label="SENSITIVITY: full sample, holidays included")

    print("\n" + "=" * 70)
    print("ROBUSTNESS: treatment vs. manhattan_north_control")
    print("=" * 70)
    df_manhattan = load_panel("manhattan_north_control")
    run_twfe(df_manhattan, exclude_holidays=True, label="ROBUSTNESS: holidays excluded")
