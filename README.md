# Marketplace Intelligence Platform

An end-to-end analytics project built on NYC's public High-Volume For-Hire
Vehicle (Uber/Lyft) trip records — SQL-first exploration now, with a dbt
transformation layer, a delivery/growth-metrics vertical, and a causal
inference study on NYC's 2025 congestion pricing policy planned next.

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

## Stack

| Layer | Tool |
|---|---|
| Warehouse (dev) | DuckDB |
| Warehouse (serving) | BigQuery (planned) |
| Transformation | dbt (planned) |
| Orchestration | Dagster (planned) |
| Analysis | Python: polars, pandas, statsmodels, scipy |
| BI | Power BI, Metabase (planned) |

## Repository structure

```
sql/exploration/     -- one .sql file per question, header comment states
                         the business question, ends with a written finding
docs/memos/           -- one-page decision memos (planned)
ingest/               -- data download scripts
notebooks/            -- exploratory notebooks
```

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

## What's next

- **dbt project**: staging → intermediate → marts layers, dbt tests, CI
- **Delivery vertical**: Instacart Market Basket data — cohorts,
  retention, LTV, RFM segmentation (mobility data has no user IDs, so
  user-level growth metrics live here instead)
- **Centerpiece**: difference-in-differences on NYC's January 2025
  congestion pricing policy — Manhattan south of 60th St as treatment,
  outer boroughs as control
- Power BI dashboard + decision memos

## Running this locally

```bash
git clone https://github.com/Zee-arch/marketplace-analytics.git
cd marketplace-analytics
uv venv && source .venv/bin/activate
uv pip install duckdb polars pyarrow requests jupyterlab
# download fhvhv_2025-03.parquet and taxi_zone_lookup.csv into data/raw/
# (see ingest/ once download scripts land)
duckdb warehouse/dev.duckdb < sql/exploration/01_trips_per_day.sql
```
