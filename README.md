# Marketplace Intelligence Platform

[![dbt tests](https://github.com/Zee-arch/marketplace-analytics/actions/workflows/dbt_test.yml/badge.svg)](https://github.com/Zee-arch/marketplace-analytics/actions/workflows/dbt_test.yml)

An end-to-end analytics project across two verticals: NYC's public
High-Volume For-Hire Vehicle (Uber/Lyft) trip records — exploratory SQL,
a tested dbt transformation pipeline with CI — and Instacart's public
Market Basket dataset, covering the user-level growth metrics (cohorts,
retention, churn, RFM, LTV) the mobility data can't support on its own,
since it has no user IDs. A causal inference study on NYC's 2025
congestion pricing policy is planned next.

Built to demonstrate the skill set a data analytics role actually tests:
SQL fluency under real messy data, correct metric definitions, data
quality judgment, and marketplace/growth economics — not just syntax.

## The dataset

[NYC TLC High Volume For-Hire Vehicle trip records](https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page)
— every Uber and Lyft trip dispatched in NYC, published monthly by the
Taxi & Limousine Commission. This project currently covers **March 2025**:
20,536,879 individual trips.

Each row is one trip, with four separate timestamps (request, driver
on-scene, pickup, dropoff), pickup/dropoff zone, a detailed fare
breakdown, driver pay, and ride-pooling flags — rich enough to support
wait-time analysis, marketplace take-rate economics, and geographic
demand patterns without needing a second dataset.

## The delivery vertical dataset

[Instacart Market Basket Analysis](https://www.kaggle.com/datasets/yasserh/instacart-online-grocery-basket-analysis-dataset)
— 3,421,083 orders from 206,209 users, 49,688 products across 21
departments. No dollar amounts anywhere in the schema, and no calendar
dates either (order timing is relative — day-of-week, hour, and days
since the previous order only) — both are real constraints of this
public dataset, not omissions, and the metric definitions below are
explicitly adapted around them rather than pretending they don't exist.



## Stack

| Layer | Tool |
|---|---|
| Warehouse (dev) | DuckDB |
| Warehouse (serving) | BigQuery (planned) |
| Transformation | dbt |
| Orchestration | Dagster (planned) |
| CI | GitHub Actions (real data, real warehouse build, on every push) |
| Analysis | Python: polars, pandas, statsmodels, scipy |
| BI | Power BI, Metabase (planned) |

## Repository structure

```
sql/exploration/         -- one .sql file per question, header comment states
                             the business question, ends with a written finding
dbt/
  models/staging/         -- stg_trips, stg_zones -- thin, 1:1 with the source
  models/intermediate/    -- int_trips_enriched -- zone joins, date/hour
                             buckets, provider label, computed once
  models/marts/           -- fct_trips, mart_daily_trip_summary,
                             mart_hourly_demand -- the analysis-ready layer
  tests/                  -- singular tests (regression checks, thresholds)
ingest/
  download_hvfhv.py        -- idempotent, retried data download
  init_warehouse.py        -- builds warehouse/dev.duckdb from data/raw/
.github/workflows/        -- CI: downloads real data, runs dbt test on every push
docs/memos/                -- one-page decision memos (planned)
notebooks/                 -- exploratory notebooks
```

## The dbt pipeline

Three layers, each with a specific job: **staging** models are thin
1:1 copies of the raw source (no logic); **intermediate** computes every
reusable derivation exactly once (zone names, Uber/Lyft label, day-of-week/
hour buckets, the wait/approach/dwell time intervals); **marts** are the
analysis-ready tables a BI tool would actually query.

26 automated tests cover both layers — not_null/unique/accepted_values on
raw columns, referential integrity between trips and zones, composite-key
grain checks on the hourly mart, and regression tests that check a mart's
totals against the raw source directly (the same sanity checks done by
hand in `sql/exploration/`, now running on every push instead of once).

One test is a deliberate, visible warning rather than a hard failure: 3
trips have an impossible (`<=0`) duration (see Q4). That's a known,
already-investigated data quality fact, not a bug to silently hide — the
test uses `error_if`/`warn_if` thresholds so it stays visible on every run
without failing CI on an issue that's already been triaged, and would
only turn into a real failure if that count grew.

## Approach

Every query follows the same discipline: decide what's being measured and
what it's being grouped by before writing SQL, verify column definitions
against the actual data dictionary rather than assuming them, and build in
a sanity check (a sum that should match a known total, a guard against
divide-by-zero, a cross-validation against a second source of truth)
before treating a number as final. Several findings below exist *because*
of that verification step, not despite it.

## Findings

### Q1 — Trips per day
20,536,879 trips across 31 days in March. Peak day: 2025-03-01 (Saturday),
789,707 trips. Clear weekly seasonality — Friday/Saturday are consistently
the busiest days.

**Data quality finding:** 2025-03-09 undercounts relative to its neighbor
Sundays by ~1.5%. Cause: that's the date U.S. Daylight Saving Time begins
— clocks skip 2:00–3:00am, so the calendar day has only 23 wall-clock
hours available for a naive local timestamp to fall into. The query runs
clean and the number looks plausible without independently knowing the
date is DST — a good example of a silent data artifact.

### Q2 — Uber vs. Lyft trip volume
**70.8% Uber (14,547,181 trips) / 29.2% Lyft (5,989,698 trips)** — Uber
runs roughly 2.4x Lyft's NYC volume in this dataset. The two counts sum
exactly to Q1's total, confirming no rows were dropped or double-counted.

### Q3 — Shared-ride adoption, by company
Uber: 3.9% of trips requested pooling, 2.0% were matched, 52.3% match
efficiency. **Lyft: 0% requested, but 1,129 trips still show as
matched** — not a bug. Lyft discontinued shared rides entirely in May
2023, while Uber kept running theirs (relaunched as UberX Share); Lyft's
handful of "matched" rows are most likely a legacy data artifact from a
feature that no longer exists in the product.

### Q4 — Trip duration distribution
Median 15.7 min, p90 36.5 min, p99 66.9 min — a normal right-skewed
shape. Impossible values (≤0 or >4hr duration) affect under 0.001% of
trips. A cross-check against the raw timestamp gap flags 0.04% of trips
where the precomputed `trip_time` column disagrees by more than a
minute — small, but named rather than ignored.

### Q5 — Top pickup zones
LaGuardia and JFK lead individually (1.96% / 1.79% of all trips), but the
top 10 zones out of 265 total only account for **~13% of all trips
combined** — demand is highly distributed across the city, not
concentrated in a handful of hotspots.

### Q6 — CBD congestion fee
34.24% of March 2025 trips incurred NYC's congestion pricing fee
(verified: $1.50/trip, matches the actual policy rate rather than an
assumed number). All 10 top originating zones for fee-paying trips are in
Manhattan — a clean internal consistency check against the policy's
actual geographic scope.

### Q7 — Driver pay as a share of fare, by hour
The metric that matters — `driver_pay ÷ base_passenger_fare` — holds in a
69.8%–75.3% band across all 24 hours, with a real but modest dip from
3–5am. A naive version of this metric (dividing by *every* rider payment
column, including tips) runs ~15 points lower and shifts unevenly by
hour, because tipping behavior isn't flat across the day — reported both
specifically to demonstrate why the naive version is the wrong one to
use for take-rate analysis.

### Q8 — Top 3 dropoff zones per pickup zone
28% of zones have themselves as the #1 dropoff — genuine short local
trips, not a data artifact. "Outside of NYC" is the top dropoff for both
airports and, less obviously, for East Village and Times Sq — suggesting
meaningful trip volume from Manhattan's core out to the wider metro area.

### Q9 — Weekday vs. weekend hourly demand curve
Genuinely different shapes, not just different levels. Weekday: sharp
double-peak commute pattern (8am high, 3am trough). Weekend: no morning
peak at all — overnight hours run 2.3x–3.2x higher than the same weekday
hours (nightlife), with a single broad evening peak at 8pm. The two
curves nearly converge around 5–6pm before diverging into very different
evenings.

### Q10 — 7-day rolling average
Smoothing out weekly seasonality reveals a real ~7.9% decline in daily
trip volume across March (687,373 on 3/7 → 633,034 on 3/31) — not just
weekly noise. Cause isn't established by this query; distinguishing
seasonal effects from continued adjustment to congestion pricing is
exactly what the planned difference-in-differences analysis is for.

### Q11 — Order-sequence retention curve (delivery)
100% "retention" through order 4 is a dataset-construction floor
(Instacart only released users with 4–100 total orders), not real
loyalty — the genuine signal starts at order 5 (88.37% of users reach
it), declining to 53.7% by order 10, 26.15% by order 20. The top end
(order 100) is likely also a collection ceiling, not a true behavioral
stop — skepticism applied to both tails of the curve, not just one.

### Q12 — Reorder rate (delivery)
62.87% of items (excluding each user's structurally-reorder-free first
order) are repeat purchases — and that rate climbs monotonically with
tenure, from 27.24% at order 2 to 85.99% by order 100. Survivorship and
habit formation move together: users who stick around also see their
baskets shift toward repeat items.

### Q13 — RFM segmentation (delivery)
Recency, frequency, and the item-volume "monetary" proxy all move in the
same direction rather than diverging — the most-recent-order tier
averages 3x the orders and items of the most-lapsed tier. Practical
read: lapsed users were mostly already lower-engagement beforehand, not
high-value users who suddenly stopped. The "at-risk" tier (30+ day gap,
censored) is also the single largest segment at 30.64% of all users.

### Q14 — Churn rate (delivery)
82.89% of all 30+-day gaps in the data are recovered from — the user
placed at least one more order afterward. Only 17.11% are truly terminal
(the gap coincides with a user's last observed order). A single long gap
is a weak churn signal on its own; treating Q13's "at-risk" tier as
confirmed churn would overstate the real non-return rate roughly 5x.

### Q15 — LTV proxy by tenure (delivery)
Cumulative item volume grows almost linearly (~10 items/order) through
order 30, then tapers gradually to ~7.2–7.4 items/order among the
highest-tenure users (50–99 orders) — a much flatter decay than typical
real-dollar LTV curves, meaning high-tenure users keep contributing
meaningful value rather than plateauing early.

### Q16 — Basket composition (delivery)
Produce (29.24%) and dairy (16.65%) together account for ~46% of every
item purchased, both with high reorder rates. Pantry breaks that
pattern — top-5 by volume but only 34.74% reorder rate, suggesting more
exploratory purchasing. The product-level reorder leaderboard is
dominated by milk variants (84–86%) and Banana — the single
most-purchased product in the dataset (491,291 times) at 84.51% reorder
rate, both a volume leader and a loyalty leader in the same SKU.

## What's next

- **Centerpiece**: difference-in-differences on NYC's January 2025
  congestion pricing policy — Manhattan south of 60th St as treatment,
  outer boroughs as control. Needs additional pre/post months downloaded
  beyond the current March-2025-only dataset
- dbt models for the delivery vertical (currently `sql/exploration/`
  only, same as mobility was before its dbt pipeline landed)
- Dagster orchestration, Power BI dashboard, decision memos

## Running this locally

```bash
git clone https://github.com/Zee-arch/marketplace-analytics.git
cd marketplace-analytics
uv venv && source .venv/bin/activate
uv pip install duckdb polars pyarrow requests dbt-core dbt-duckdb kaggle jupyterlab

# mobility vertical -- no auth needed, fully public
python ingest/download_hvfhv.py 2025-03

# delivery vertical -- needs a Kaggle account + API credential first.
# Generate one at kaggle.com/settings/api under "Legacy API Credentials"
# (not the newer token flow -- the kaggle package doesn't support it yet
# as of 1.7.4.5) and save it to ~/.kaggle/kaggle.json
mkdir -p data/raw/instacart
kaggle datasets download -d yasserh/instacart-online-grocery-basket-analysis-dataset \
  -p data/raw/instacart --unzip

# build warehouse/dev.duckdb from whichever raw data is present --
# skips a vertical gracefully if its source files aren't downloaded
python ingest/init_warehouse.py

# run a hand-written exploration query
duckdb warehouse/dev.duckdb < sql/exploration/01_trips_per_day.sql

# or run the dbt pipeline (mobility vertical: staging -> intermediate ->
# marts) + all tests
cd dbt
dbt run --profiles-dir .
dbt test --profiles-dir .
```
