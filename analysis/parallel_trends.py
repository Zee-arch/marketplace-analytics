"""
Parallel trends check for the NYC congestion pricing DiD analysis.

Core identifying assumption of any difference-in-differences: treatment
(CRZ zones) and control (outer boroughs) must move together BEFORE the
policy takes effect. If they were already diverging pre-policy for some
unrelated reason, any post-policy gap can't be cleanly attributed to the
policy -- it could just be the pre-existing trend continuing. This script
checks that assumption two ways, not one:

  1. Visual: daily trip volume, normalized per zone (treatment has 39
     zones, control has 193 -- raw sums aren't comparable) and indexed to
     the pre-period average, plotted with a line at the actual policy
     start date (2025-01-05, not a month boundary).
  2. Statistical: a regression using ONLY pre-period data (Oct 2024-Jan 4
     2025, strictly before the policy), testing whether treatment and
     control had different time trends before anything happened. The
     coefficient on the treatment*time interaction is the test -- if it's
     not statistically distinguishable from zero, there's no evidence of
     a differential pre-trend, which is what "parallel trends" requires.

Run from the repo root: python analysis/parallel_trends.py
"""

from pathlib import Path

import duckdb
import matplotlib.pyplot as plt
import pandas as pd
import statsmodels.formula.api as smf

REPO_ROOT = Path(__file__).resolve().parent.parent
WAREHOUSE = REPO_ROOT / "warehouse" / "dev.duckdb"
OUTPUT_DIR = Path(__file__).resolve().parent / "output"
OUTPUT_DIR.mkdir(exist_ok=True)

POLICY_START = pd.Timestamp("2025-01-05")
PRE_PERIOD_END = pd.Timestamp("2025-01-04")  # strictly before the policy


def load_panel() -> pd.DataFrame:
    """Daily trip totals by zone_group, primary comparison only
    (treatment vs. outer_borough_control -- the project's original
    design). manhattan_north_control is left out here on purpose; it's
    the robustness-check comparison, run separately."""
    con = duckdb.connect(str(WAREHOUSE), read_only=True)
    df = con.execute("""
        select
            trip_date,
            zone_group,
            sum(trip_count) as trip_count,
            count(distinct location_id) as n_zones
        from mart_did_zone_daily_panel
        where zone_group in ('treatment', 'outer_borough_control')
        group by 1, 2
        order by 1, 2
    """).df()
    con.close()
    df["trip_date"] = pd.to_datetime(df["trip_date"])
    # avg trips per zone per day -- normalizes for treatment (39 zones)
    # vs. control (193 zones) having very different zone counts, so the
    # two lines are on a comparable scale
    df["avg_trips_per_zone"] = df["trip_count"] / df["n_zones"]
    return df


def build_indexed_series(df: pd.DataFrame) -> pd.DataFrame:
    pivot = df.pivot(index="trip_date", columns="zone_group", values="avg_trips_per_zone").sort_index()
    pre_period_baseline = pivot.loc["2024-10-01":"2025-01-04"].mean()
    indexed = pivot / pre_period_baseline * 100
    return pivot, indexed


def plot_parallel_trends(pivot: pd.DataFrame, indexed: pd.DataFrame, out_path: Path) -> None:
    fig, axes = plt.subplots(2, 1, figsize=(12, 9), sharex=True)
    colors = {"treatment": "#d62728", "outer_borough_control": "#1f77b4"}
    labels = {"treatment": "Treatment (CRZ, 39 zones)", "outer_borough_control": "Control (outer boroughs, 193 zones)"}

    # 7-day rolling smooth on both panels -- same technique as Q10, for
    # the same reason: raw daily values are dominated by weekly
    # seasonality, which would make a real trend-divergence hard to see
    for ax, data, ylabel, title in [
        (axes[0], pivot, "Avg trips / zone / day (7-day smoothed)", "Raw levels"),
        (axes[1], indexed, "Index (pre-period avg = 100)", "Indexed to pre-period baseline"),
    ]:
        smoothed = data.rolling(7, center=True).mean()
        for group in ["treatment", "outer_borough_control"]:
            ax.plot(smoothed.index, smoothed[group], label=labels[group], color=colors[group], linewidth=1.8)
        ax.axvline(POLICY_START, color="gray", linestyle="--", linewidth=1.2, label="Policy start (2025-01-05)")
        ax.set_ylabel(ylabel)
        ax.set_title(title)
        ax.legend(loc="upper left", fontsize=9)
        ax.grid(alpha=0.3)

    axes[1].axhline(100, color="black", linewidth=0.6)
    fig.suptitle("Parallel Trends Check: NYC Congestion Pricing DiD", fontsize=14, fontweight="bold")
    fig.tight_layout()
    fig.savefig(out_path, dpi=150)
    print(f"saved chart to {out_path}")


def pre_period_trend_test(df: pd.DataFrame):
    """Formal test, not just eyeballing a chart: restrict to pre-period
    data ONLY (the policy hasn't happened yet in this subset, by
    construction) and regress avg_trips_per_zone on
    is_treatment * days_since_start. If treatment and control were
    already trending differently before the policy, the interaction
    coefficient will be significantly different from zero. HC1
    (heteroskedasticity-robust) standard errors, since daily trip counts
    are not homoskedastic across a 96-day window."""
    pre = df[df["trip_date"] <= PRE_PERIOD_END].copy()
    pre["days_since_start"] = (pre["trip_date"] - pre["trip_date"].min()).dt.days
    pre["is_treatment"] = (pre["zone_group"] == "treatment").astype(int)

    model = smf.ols("avg_trips_per_zone ~ is_treatment * days_since_start", data=pre).fit(cov_type="HC1")
    return model, pre


if __name__ == "__main__":
    panel = load_panel()
    pivot, indexed = build_indexed_series(panel)
    plot_parallel_trends(pivot, indexed, OUTPUT_DIR / "parallel_trends.png")

    model, pre = pre_period_trend_test(panel)
    print(f"\nPre-period window: {pre['trip_date'].min().date()} to {pre['trip_date'].max().date()} ({pre['days_since_start'].max() + 1} days)\n")
    print(model.summary())
