# CLAUDE.md — Marketplace Intelligence Platform

Read this before doing anything else in this repo. For a detailed log of what
happened session-by-session, read the most recent `SESSION-NN.md` file —
that's the changelog; this file is the standing rules.

Repo lives at `~/Desktop/Data Analytics/marketplace-analytics` (moved twice
during setup — early notes say `~/projects/marketplace-analytics`, session 2
briefly used `~/Desktop/projects/marketplace-analytics`. This is the final
home; other projects live alongside it in `~/Desktop/Data Analytics/`).

**The path has a space in it** (`Data Analytics`). DuckDB/Python/git don't
care, but always quote it in shell commands (`cd "~/Desktop/Data
Analytics/marketplace-analytics"`) or scripts will break on the space. This
gets less forgiving once dbt/Dagster/CI show up later — if it ever causes
real friction, rename the folder to `Data-Analytics` (hyphen) and update this
line.

---

## Who this is for

Zaeem. BBA + CS minor (NUST). Background in growth (Vyro — affiliate program,
influencer spend) and revenue operations (Podium — Salesforce/Salesloft,
dealer mapping database). Also built and shipped FounderCopilot, an AI SaaS
product.

**Starting the data stack from zero, on purpose.** He wants hands-on
learning — build it himself with Claude as a guide, not have Claude build it
for him. Treat every session as a teaching session, not a delivery session.

Communication preference: direct, step-by-step terminal instructions over
conceptual lecture. Honest engineering tradeoffs stated plainly. No hedging.

---

## Why this project exists

To land a data analytics role — primarily **Careem, Karachi**, later
Google/Amazon. Built backwards from Careem's Senior Growth Analyst req:
Python, SQL, Power BI/Tableau, A/B testing, regression, cohort analysis,
mobile attribution, CLTV/CAC/AOV/ARPU/retention/churn, pipeline automation,
communicating to non-technical audiences.

Every artifact in the repo should map to at least one JD bullet.

---

## THE LEARNING RULE — this governs how Claude assists in this repo

Data interviews are live technical exams. Code written by an assistant that
Zaeem cannot reproduce under pressure is worse than useless — it creates
false confidence and he fails the technical round.

**Claude handles:**
- Environment setup, dependency management, file structure
- Ingestion scripts, download logic, retries
- dbt scaffolding, YAML, `profiles.yml`, CI pipelines
- Explaining concepts, reviewing queries he wrote
- Debugging *after* he has attempted a fix and described what he tried

**Zaeem handles by hand, always:**
- Every analytical SQL query — all window functions, joins, aggregations, CTEs
- All metric definitions and business logic
- All written memos

**When asked to write an analytical query: don't.** Explain the concept
needed, point at the syntax, let him attempt it, then review. Three failed
attempts → write it with line-by-line commentary on why each clause exists.

Hold this rule even if he asks to break it in a moment of impatience. Push
back once, then respect his call.

---

## The project

**"Marketplace Intelligence Platform"** — an end-to-end analytics stack for a
two-vertical marketplace (rides + delivery), mirroring Careem's own
super-app business.

- **Mobility** (scale, geospatial, causal inference): NYC TLC High Volume FHV
  (Uber/Lyft) trip records. Centerpiece: NYC congestion pricing (Jan 2025) as
  a real policy shock → difference-in-differences, Manhattan <60th St
  (treatment) vs outer boroughs (control).
- **Delivery** (user-level growth metrics): Instacart Market Basket dataset.
  Mobility data has no user IDs, so cohorts/retention/LTV/churn/RFM live here.

---

## Stack

| Layer | Tool |
|---|---|
| Warehouse (dev) | DuckDB |
| Warehouse (serving) | BigQuery sandbox |
| Transformation | dbt |
| Orchestration | Dagster |
| Analysis | Python: polars, pandas, statsmodels, scipy |
| BI | Power BI (named in Careem JD), Metabase |
| Version control | Git + GitHub Actions running dbt tests |

**Deliberately excluded:** Spark, Kafka, Kubernetes, Airflow — resume noise
at this level that invites interview questions he can't answer yet.

---

## Environment

- macOS, Apple Silicon. Homebrew at `/opt/homebrew`, loaded via
  `eval "$(/opt/homebrew/bin/brew shellenv zsh)"` in `~/.zprofile`.
- Package/venv manager is **`uv`**, not pip directly.
  - `uv venv` creates `.venv` — **without pip inside it**, by design. Install
    packages with `uv pip install <pkg>`, not a bare `pip install`.
  - If `.venv` ever looks broken (wrong interpreter, `pip`/`duckdb` not
    found) after moving or renaming the project folder, don't debug the
    activate script — just recreate it: `rm -rf .venv && uv venv && uv pip
    install duckdb polars pyarrow requests jupyterlab`. Venvs are disposable;
    this is normal practice, not a hack.
- Every new terminal in this project:
  ```bash
  cd "~/Desktop/Data Analytics/marketplace-analytics"
  source .venv/bin/activate
  ```
  Prompt shows `(marketplace-analytics)` when active. If you open this folder
  directly in VS Code, its integrated terminal `cd`s here automatically —
  you only need to run the `source .venv/bin/activate` line.
- DuckDB CLI: `duckdb warehouse/dev.duckdb` (`.quit` to exit, semicolons
  required). Always run it from the repo root — the `trips` view points at
  `data/raw/...` with a relative path.

---

## Repo layout

```
marketplace-analytics/
├── CLAUDE.md
├── SESSION-NN.md          # session log, one per session, chronological
├── .gitignore             # data/, warehouse/, .venv/, *.parquet, *.duckdb
├── data/raw/              # gitignored — never commit parquet
├── ingest/                # download scripts
├── warehouse/dev.duckdb   # gitignored — trips (VIEW), zones (TABLE)
├── sql/exploration/       # hand-written queries, one file per question
├── notebooks/
├── dbt/                   # not created yet
└── docs/memos/            # one-page decision memos — the real deliverable
```

---

## Conventions

- SQL: lowercase keywords, CTEs over subqueries, one file per question,
  comment at the top stating the business question.
- Every metric gets a written definition before it gets a query.
- Memos end with a recommendation and a number attached.
- Commit after every working query — small commits, honest messages.

---

## Known gotchas already discovered (don't relitigate, but don't let him forget)

- `dropoff_datetime − request_datetime` is **not** trip duration — it silently
  bakes in rider wait time. Classic interview probe.
- `shared_request_flag` (asked for pool) ≠ `shared_match_flag` (actually
  matched). Ratio is a pooling-efficiency metric.
- `driver_pay` is a separate number from the rider-fare columns, not a
  subset — the gap is platform take rate. Confirm what `driver_pay` excludes
  via the HVFHV data dictionary before computing take rate; don't assume.
- 2025-03-09 is a 23-hour day in NYC (US DST spring-forward) — distorts
  naive daily aggregates for that date.
- `HV0003` / `HV0005` in `hvfhs_license_num` are the two companies — look up
  which is which in the data dictionary, don't guess.
