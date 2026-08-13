"""
Event study for the NYC congestion pricing DiD.

The main regression (docs/memos/02_did_main_regression.md) collapses the
whole pre/post comparison into one coefficient. That hides two things
worth seeing directly: (1) does the effect appear sharply at the actual
policy date, or was it already drifting beforehand -- the single-
coefficient DiD can't distinguish "the policy caused this" from "this
was already happening"; (2) the holiday-season confound from the
parallel-trends memo, which was described in that memo but never
actually shown week-by-week.

Specification: same two-way FE panel as the main regression, but instead
of one is_treatment*is_post term, a separate coefficient for
is_treatment interacted with EACH WEEK relative to the policy date
(2025-01-05 = week 0), with the week immediately before the policy
(week -1) as the omitted reference category -- standard event-study
practice. Each coefficient is "how different was treatment from control
in that week, relative to how different they were in week -1."

Implementation note: the dummy columns are built explicitly with pandas
(one column per non-reference week, is_treatment * (week==k)), not via
linearmodels' formula string with a patsy C(...) categorical interaction.
Tried the formula approach first -- it ran without error, but produced
standard errors that were IDENTICAL across all 25 coefficients (a red
flag, checked and confirmed not a real result), and point estimates that
differed from the explicit version. Patsy's automatic full/reduced-rank
contrast coding behaves differently when a categorical interaction is
the only term in a formula (no accompanying main effects) versus when
build the design matrix by hand and can verify column-by-column that it
does exactly what's intended.

Run from the repo root: python analysis/did_event_study.py
"""

import warnings
from pathlib import Path

import duckdb
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from linearmodels.panel import PanelOLS

warnings.filterwarnings("ignore", category=RuntimeWarning, module="linearmodels")

REPO_ROOT = Path(__file__).resolve().parent.parent
WAREHOUSE = REPO_ROOT / "warehouse" / "dev.duckdb"
OUTPUT_DIR = Path(__file__).resolve().parent / "output"
OUTPUT_DIR.mkdir(exist_ok=True)

POLICY_START = pd.Timestamp("2025-01-05")
# Reference week: NOT week -1 (the conventional "period right before
# treatment" choice) -- checked directly and week -1 (Dec 29-Jan 4) sits
# inside the holiday-distorted window itself (the parallel-trends chart
# showed treatment still depressed/recovering through early January), so
# every other coefficient would be relative to a genuinely unusual
# point, not a clean baseline. Using the earliest available clean week
# instead -- the eventual chart's "0" then means "vs. a normal October
# week," which is what the reader actually wants to see.
REFERENCE_WEEK = -13
HOLIDAY_START = pd.Timestamp("2024-11-20")
HOLIDAY_END = pd.Timestamp("2025-01-02")
MIN_PRESENCE_FRACTION = 0.7  # same sparse-zone filter as the main regression, same reasoning


def load_panel() -> pd.DataFrame:
    con = duckdb.connect(str(WAREHOUSE), read_only=True)
    df = con.execute("""
        select trip_date, location_id, zone_group, trip_count, is_treatment
        from mart_did_zone_daily_panel
        where zone_group in ('treatment', 'outer_borough_control')
    """).df()
    con.close()
    df["trip_date"] = pd.to_datetime(df["trip_date"])
    df["log_trip_count"] = np.log(df["trip_count"])

    # week bins anchored to the policy date itself, not calendar month
    # boundaries -- week 0 = the 7 days starting on the policy date,
    # week -1 = the 7 days immediately before it, etc.
    days_from_policy = (df["trip_date"] - POLICY_START).dt.days
    df["week_relative"] = days_from_policy // 7

    # drop the two partial boundary weeks (checked directly: week -14 has
    # only 5 of 7 days present since the data starts mid-week, week 12
    # has only 2). Keeping only full 7-day weeks avoids noisy/inestimable
    # edge points.
    week_day_counts = df.groupby("week_relative")["trip_date"].transform("nunique")
    df = df[week_day_counts == 7]

    days_present = df.groupby("location_id")["trip_date"].transform("nunique")
    n_days = df["trip_date"].nunique()
    n_before = df["location_id"].nunique()
    df = df[days_present >= MIN_PRESENCE_FRACTION * n_days]
    n_after = df["location_id"].nunique()
    print(f"(dropped {n_before - n_after} near-singleton zone(s), same filter as the main regression)")
    return df


def run_event_study(df: pd.DataFrame):
    df = df.copy()
    weeks = sorted(w for w in df["week_relative"].unique() if w != REFERENCE_WEEK)
    dummy_cols = []
    for w in weeks:
        col = f"week_{w}"
        df[col] = df["is_treatment"] * (df["week_relative"] == w).astype(int)
        dummy_cols.append(col)

    panel = df.set_index(["location_id", "trip_date"])
    model = PanelOLS(
        panel["log_trip_count"], panel[dummy_cols],
        entity_effects=True, time_effects=True, drop_absorbed=True,
    )
    result = model.fit(cov_type="clustered", cluster_entity=True)
    return result, weeks


def extract_coefficients(result, weeks) -> pd.DataFrame:
    ci = result.conf_int()
    rows = [{
        "week_relative": w,
        "coef": result.params[f"week_{w}"],
        "se": result.std_errors[f"week_{w}"],
        "ci_low": ci.loc[f"week_{w}", "lower"],
        "ci_high": ci.loc[f"week_{w}", "upper"],
    } for w in weeks]
    # the reference week itself has coefficient 0 by construction --
    # add it explicitly so the plot shows a continuous line through it
    rows.append({"week_relative": REFERENCE_WEEK, "coef": 0.0, "se": 0.0, "ci_low": 0.0, "ci_high": 0.0})
    return pd.DataFrame(rows).sort_values("week_relative").reset_index(drop=True)


def plot_event_study(coefs: pd.DataFrame, out_path: Path) -> None:
    fig, ax = plt.subplots(figsize=(13, 7))

    holiday_week_start = (HOLIDAY_START - POLICY_START).days // 7
    holiday_week_end = (HOLIDAY_END - POLICY_START).days // 7
    ax.axvspan(holiday_week_start - 0.5, holiday_week_end + 0.5, color="orange", alpha=0.15,
               label="Holiday window (Thanksgiving-New Year's)")

    ax.errorbar(
        coefs["week_relative"], coefs["coef"],
        yerr=[coefs["coef"] - coefs["ci_low"], coefs["ci_high"] - coefs["coef"]],
        fmt="o-", color="#d62728", ecolor="#d62728", elinewidth=1, capsize=3, markersize=4,
        label=f"Treatment effect vs. week {REFERENCE_WEEK} (95% CI)",
    )
    ax.axhline(0, color="black", linewidth=0.8)
    ax.axvline(-0.5, color="gray", linestyle="--", linewidth=1.2, label="Policy start (week 0 begins)")

    ax.set_xlabel("Weeks relative to policy start (2025-01-05)")
    ax.set_ylabel(f"Treatment effect (log points, relative to week {REFERENCE_WEEK})")
    ax.set_title("Event Study: NYC Congestion Pricing — Weekly Treatment Effect on Trip Volume", fontweight="bold")
    ax.legend(loc="lower left", fontsize=9)
    ax.grid(alpha=0.3)
    fig.tight_layout()
    fig.savefig(out_path, dpi=150)
    print(f"saved chart to {out_path}")


if __name__ == "__main__":
    df = load_panel()
    result, weeks = run_event_study(df)
    coefs = extract_coefficients(result, weeks)
    print(coefs.to_string(index=False))
    plot_event_study(coefs, OUTPUT_DIR / "event_study.png")
