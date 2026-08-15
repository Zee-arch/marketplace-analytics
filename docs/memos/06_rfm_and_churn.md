# RFM Segmentation & the Churn Reality Check — Instacart Delivery Vertical

**Headline finding:** Recency, Frequency, and Monetary-proxy all move
together, not independently — the most-lapsed user tier averages roughly
a third of the orders and items of the most-recent tier. The "at-risk"
tier (30+ day gap since last order) is the single largest segment at
30.64% of all users — but a follow-up check on what a 30+ day gap
actually predicts shows **82.89% of those gaps get recovered from**.
Treating "at-risk" as "churned" would overstate real non-return by
roughly 5x.

## The question

Two questions, deliberately run together because the second one is a
direct check on how much to trust the first: how do users segment on
Recency/Frequency/Monetary-proxy (Q13), and separately — when a user
goes quiet for 30+ days, is that usually the end of the relationship, or
do most people come back (Q14)?

## RFM definitions, adapted to this dataset's real constraints

- **Recency** = `days_since_prior_order` on each user's most recent
  order — not "days since today," since no calendar dates exist here.
  It's "how long was the gap leading into their last known order."
  **Hand-defined tiers, not `ntile(5)`** — `days_since_prior_order` is
  capped at exactly 30 (Instacart censors it there), and ~63,000 users
  (30.6%) are tied at that exact value. A quantile split would
  arbitrarily scatter an identically-valued group across five buckets,
  which is actively misleading, not just imprecise.
- **Frequency** = total order count per user. `ntile(5)` is fine here —
  no comparable tie concentration.
- **Monetary** = total items purchased, computed from
  `order_products_prior` only (never `_train`) — keeps every user's
  number built the same way regardless of which split their held-out
  final order landed in.

## R, F, and M move together — not guaranteed, but true here

| Recency tier | % of users | Avg. orders | Avg. items (prior) |
|---|---|---|---|
| A: 0–7 days (very recent) | — | 26.1 | 252.6 |
| E: 30+ days (censored, at-risk) | 30.64% | 9.5 | 82.6 |

Roughly a 3x gap on both Frequency and Monetary between the most-recent
and most-lapsed tiers, moving in lockstep with Recency. This is worth
stating as a real empirical finding, not an assumption baked into RFM
methodology — plenty of real businesses find a "high-value but lapsed"
segment worth a dedicated win-back push, and this data doesn't show a
large one. The practical read: users who go quiet were, on average,
**already lower-engagement users beforehand**, not previously-high-value
users who suddenly stopped.

## Is "at-risk" the same as "churned"? The check says no.

The RFM segmentation on its own invites a natural next move — treat the
30.64%-of-users "at-risk" tier as churn and build a win-back campaign
around it. Before doing that, Q14 asks a more precise question: across
**every instance** in the dataset where a user hit a 30+ day gap (not
just their current one), how often did that gap turn out to be terminal
versus recovered?

| | Count | % |
|---|---|---|
| Total 30+-day gap instances | 369,323 | 100% |
| Recovered (user ordered again) | 306,137 | **82.89%** |
| Terminal (dataset just ends there) | 63,186 | 17.11% |

That terminal count — 63,186 — is exactly Q13's at-risk population,
as it should be (every user has exactly one last order). But the base
rate across *all* 30+-day gaps says most of them are not the end of the
relationship: **a single 30+ day gap is a weak churn signal on its
own.** Reading the at-risk tier as confirmed churn overstates the real
non-return rate by roughly 5x relative to what the data actually shows
predicts non-return.

## What this means operationally

The at-risk segment is still the right place to prioritize a win-back
push by sheer size (30.64% of the base) — but the messaging and urgency
should assume most of these users are still reachable, not lost. A real
churn *model*, if this mattered for a live decision, would need to look
past a single gap's length and into pattern — whether a user's gaps are
lengthening over their own history, or whether they've had multiple
30+ day gaps before (repeat lapsers, a much stronger signal than one
instance). That's a natural next question this project doesn't build,
flagged rather than silently left out.

## Reproducing this

```bash
duckdb warehouse/dev.duckdb < sql/exploration/13_rfm_segmentation.sql
duckdb warehouse/dev.duckdb < sql/exploration/14_churn_rate.sql

# formalized RFM mart (one row per user):
cd dbt && dbt run --select mart_user_rfm --profiles-dir . && cd ..
# Q14 has no dedicated mart -- a one-off diagnostic stat, not naturally
# a one-row-per-entity table, a deliberate scoping choice (see CLAUDE.md)
```
