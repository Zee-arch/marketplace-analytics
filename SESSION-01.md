# Session 01 — Project Setup & First Query

**Date:** 2026-08-04
**Status at end of session:** Environment working, one month of data loaded, question 1 complete.

---

## 1. Who this is for

Zaeem. BBA + CS minor (NUST). Background in growth (Vyro — affiliate program,
influencer spend) and revenue operations (Podium — Salesforce/Salesloft, dealer
mapping database). Also built and shipped FounderCopilot, an AI SaaS product.

**Rookie at the data stack.** Learning it by building this project.

Communication preference: direct, step-by-step terminal instructions over
conceptual explanation. Honest engineering tradeoffs stated plainly. No hedging.

---

## 2. Why this project exists

To land a data analytics role — primarily **Careem, Karachi**, later Google/Amazon.

The project is built backwards from a real, live job posting. Careem's
**Senior Growth Analyst** req (Karachi/Lahore, Greenhouse) asks for:

- Python, SQL, Power BI/Tableau
- A/B testing, regression analysis, user segmentation, cohort analysis
- Mobile app attribution and incrementality
- Growth metrics: CLTV, CAC, AOV, ARPU, retention, churn
- Automating data pipelines, maintaining data quality
- Communicating results to non-technical audiences
- 4–5 years experience, Tier-1 Engineering/Maths/Stats degree

Honest read on positioning: he is applying slightly under-spec (BBA not
engineering, ~2 years of adjacent rather than titled experience). His edge is
that he already has real growth/revops experience — most data candidates have
SQL but no idea what CAC payback means. The project supplies the missing
technical proof. **Job applications run in parallel, not after.**

Every artifact in the repo should map to at least one JD bullet above.

---

## 3. THE LEARNING RULE (carry this into every session)

Data interviews are live technical exams. Code written by an assistant that
Zaeem cannot reproduce under pressure is worse than useless — it creates false
confidence and he fails the technical round.

**Assistant handles:**
- Environment setup, dependency management, file structure
- Ingestion scripts, download logic, retries
- dbt scaffolding, YAML, `profiles.yml`, CI pipelines
- Explaining concepts, reviewing queries he wrote
- Debugging *after* he has attempted a fix and described what he tried

**Zaeem handles by hand, always:**
- Every analytical SQL query
- All window functions, joins, aggregations, CTEs
- All metric definitions and business logic
- All written memos

**When asked to write an analytical query:** don't. Explain the concept needed,
point at the syntax, let him attempt it, then review. Three failed attempts →
write it with line-by-line commentary on why each clause exists.

Hold this rule even if he asks to break it in a moment of impatience. Push back
once, then respect his call.

---

## 4. The project

**"Marketplace Intelligence Platform"** — an end-to-end analytics stack for a
two-vertical marketplace (rides + delivery), mirroring Careem's own super-app
business.

### Vertical 1 — Mobility (scale, geospatial, causal inference)
- NYC TLC High Volume FHV (Uber/Lyft) trip records
  - `https://d37ci6vzurychx.cloudfront.net/trip-data/fhvhv_tripdata_YYYY-MM.parquet`
  - ~20M rows/month, ~478MB/file, published with ~2 month lag
  - 2025+ files include `cbd_congestion_fee` — the congestion pricing marker
- Zone lookup: `https://d37ci6vzurychx.cloudfront.net/misc/taxi_zone_lookup.csv`
- Zone shapefiles from the TLC site (for maps)
- Weather: Open-Meteo archive API (free, no key)

### Vertical 2 — Delivery (user-level growth metrics)
- Instacart Market Basket dataset (~3M orders, 200k users)
- This is where cohorts, retention, LTV, churn, and basket analysis live —
  mobility data has no user IDs.

### The centerpiece
NYC introduced congestion pricing in **January 2025**. That's a real policy shock
sitting in public data. Run a **difference-in-differences**: Manhattan zones below
60th St as treatment, outer boroughs as control. Measure effect on trip volume,
fares, driver earnings. Almost no portfolio contains real causal inference on a
real policy change — this is the differentiator.

---

## 5. Stack

| Layer | Tool |
|---|---|
| Warehouse (dev) | DuckDB |
| Warehouse (serving) | BigQuery sandbox |
| Transformation | dbt |
| Orchestration | Dagster |
| Analysis | Python: polars, pandas, statsmodels, scipy |
| BI | Power BI (named in Careem JD), Metabase |
| Version control | Git + GitHub Actions running dbt tests |

**Deliberately excluded:** Spark, Kafka, Kubernetes, Airflow. Resume noise at this
level, and they invite interview questions he can't answer yet.

---

## 6. Environment (macOS, Apple Silicon)

Installed this session:
- Homebrew → `/opt/homebrew`, PATH set via `~/.zprofile`
- `duckdb` v1.5.5 (Variegata), `uv`
- Python venv at `.venv`, packages: duckdb, polars, pyarrow, requests, jupyterlab
- `setopt interactive_comments` added to `~/.zshrc` so pasted `#` comments don't error

**Every new terminal session in this project needs:**
```bash
cd ~/projects/marketplace-analytics
source .venv/bin/activate
```
Prompt shows `(marketplace-analytics)` when active.

### Repo layout
```
~/projects/marketplace-analytics/
├── CLAUDE.md
├── .gitignore             # data/, warehouse/, .venv/, *.parquet, *.duckdb
├── data/raw/              # gitignored — never commit parquet
│   ├── fhvhv_2025-03.parquet   (478MB)
│   └── taxi_zone_lookup.csv    (12KB)
├── ingest/                # empty — download scripts go here
├── warehouse/dev.duckdb   # gitignored
├── sql/exploration/       # his hand-written queries, one file per question
│   └── 01_trips_per_day.sql
├── notebooks/
├── dbt/                   # not created yet — week 3
└── docs/memos/            # one-page decision memos — the real deliverable
```

### Working commands
```bash
# interactive SQL
duckdb warehouse/dev.duckdb        # .quit to exit, semicolons required

# run a saved query file
duckdb warehouse/dev.duckdb < sql/exploration/01_trips_per_day.sql
```

### Objects in dev.duckdb (persist between sessions)
- `trips` — a **VIEW** over the Parquet (file stays on disk, not copied in)
- `zones` — a **TABLE** loaded from the CSV

---

## 7. Schema notes for `trips` (HVFHV)

```
hvfhs_license_num      varchar     dispatching_base_num   varchar
originating_base_num   varchar     request_datetime       timestamp
on_scene_datetime      timestamp   pickup_datetime        timestamp
dropoff_datetime       timestamp   PULocationID           integer
DOLocationID           integer     trip_miles             double
trip_time              bigint      base_passenger_fare    double
tolls                  double      bcf                    double
sales_tax              double      congestion_surcharge   double
airport_fee            double      tips                   double
driver_pay             double      shared_request_flag    varchar
shared_match_flag      varchar     access_a_ride_flag     varchar
wav_request_flag       varchar     wav_match_flag         varchar
cbd_congestion_fee     double
```

### The four timestamps — the highest-value thing in this schema
| Column | Marks |
|---|---|
| `request_datetime` | rider taps request |
| `on_scene_datetime` | driver arrives at pickup |
| `pickup_datetime` | rider gets in, trip starts |
| `dropoff_datetime` | trip ends |

Derived intervals, each a different business question:
- `pickup − request` = **rider wait time** (marketplace health)
- `on_scene − request` = driver approach time (supply density)
- `pickup − on_scene` = dwell time (curb friction)
- `dropoff − pickup` = trip duration (should match `trip_time`, in **seconds**)

Using `dropoff − request` as "trip duration" silently bakes wait time into the
number. This is a classic interview probe.

### Money columns
Rider pays: `base_passenger_fare`, `tolls`, `bcf`, `sales_tax`,
`congestion_surcharge`, `airport_fee`, `tips`, `cbd_congestion_fee`.
`driver_pay` is what the driver receives — a **separate** number, not a subset.
The gap is platform take rate, the most interesting metric in the dataset.

⚠️ Before computing take rate, read the HVFHV data dictionary PDF to confirm what
`driver_pay` excludes. Do not assume.

### Flags
`shared_request_flag` (rider *asked* for pool) ≠ `shared_match_flag` (actually
*got matched*). The ratio is a pooling efficiency metric.

### `hvfhs_license_num`
`HV0003` and `HV0005` are the two companies. Look up which is which in the data
dictionary rather than guessing.

---

## 8. Work completed

### Q1 — Trips per day, March 2025 ✅
```sql
-- Question: How many trips per day in March 2025, and which day had the most?
-- Source: fhvhv_2025-03.parquet (~20M rows)

select
    cast(pickup_datetime as date) as trip_date,
    count(*) as trip_count
from trips
group by 1
order by trip_count desc;
```

**Result:** 31 rows. Peak 2025-03-01 at 789,707 trips. Floor 2025-03-31 at
557,248. Range ~40%.

**Findings:**
- Data quality: all 31 dates fall inside March 2025. No stray adjacent-month or
  garbage-year rows. (Worth recording as a checked negative.)
- The top days (1, 15, 8, 22, 14, 29, 7, 21, 28) are spaced 7 days apart in two
  interleaved runs → **weekly seasonality dominates**. Fri/Sat carry demand,
  Mon/Tue are the floor.
- Implication: "trips grew 8% week-over-week" is meaningful; day-over-day is
  usually noise. Dashboards must respect this.

---

## 9. Immediate next steps

**Still open from Q1:**
1. Add `dayname(pickup_datetime)` to the query and confirm the weekly pattern
   empirically rather than by inference.
2. Compare Sunday 2025-03-09 against the other Sundays. Something non-behavioural
   happened that day. *(Hint if needed: US daylight saving time began 2025-03-09 —
   the clocks skipped an hour, so that day is only 23 hours long. This bites
   analysts every single year and is a genuine data-quality gotcha worth writing
   up.)*

**Then Q2:** volume split between the two companies in `hvfhs_license_num`.
Requires looking up the codes in the HVFHV data dictionary.

**Remaining week 1–2 questions (he writes all of these himself):**
3. Share of shared rides, by company (careful: two different shared flags)
4. Trip duration distribution — median, p90, p99. What do impossible values say
   about data quality?
5. Top 10 pickup zones by trips — join to `zones` for names
6. % of trips paying `cbd_congestion_fee`, and their originating zones
7. Driver pay as a share of total rider cost, by hour of day — *the important
   one; it's marketplace economics, not a SQL exercise*
8. Top 3 dropoff destinations per pickup zone (`ROW_NUMBER()` over a partition)
9. Weekday vs weekend hourly trip curve, side by side in one result set
10. 7-day rolling average of daily trips (`AVG() OVER` with a frame clause)

---

## 10. Roadmap

| Weeks | Focus |
|---|---|
| 1–2 | SQL fluency. Raw DuckDB on TLC data. No dbt yet. |
| 3–4 | Ingestion pipeline + dbt project (staging/intermediate/marts) + dbt tests |
| 5–6 | Delivery vertical: cohorts, retention curves, LTV, RFM segmentation |
| 7–8 | Congestion pricing DiD: parallel trends, event study plot, robustness |
| 9–10 | Dagster orchestration + GitHub Actions CI |
| 11–12 | Power BI dashboard + three decision memos |

~12 weeks at 15–20 hrs/week.

---

## 11. Conventions

- SQL: lowercase keywords, CTEs over subqueries, one file per question, comment
  at the top stating the business question
- Every metric gets a written definition before it gets a query
- Memos end with a recommendation and a number attached
- Commit after every working query — small commits, honest messages

---

## 12. Parallel tracks (not part of the repo, but part of the plan)

- **Certifications:** PL-300 (Power BI Data Analyst, ~$165, real proctored exam)
  and dbt Fundamentals (free). Skip finishing the Google cert — low signal.
- **Job search:** rewrite CV now to lead with quantified analytics framing of
  Vyro and Podium. Apply to Careem reqs immediately despite being under-spec.
  Take contract/junior analyst work to convert adjacent experience into titled
  experience.
- **Satellite projects (one weekend each):** a SQL case-study repo built on the
  existing `layoffs` cleaning work; a marketing attribution / MMM analysis that
  connects to the Vyro affiliate experience.

---

## 13. Housekeeping

Git identity was unset on the first commit. Fix with:
```bash
git config --global user.name "Zaeem"
git config --global user.email "your@email.com"
git commit --amend --reset-author --no-edit
```
Use the email tied to his GitHub account — contribution history is part of the
portfolio artifact.
