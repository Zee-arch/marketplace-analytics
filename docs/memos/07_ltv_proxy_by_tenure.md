# LTV Proxy by Tenure — Instacart Delivery Vertical

**Headline finding:** cumulative item-volume — the closest proxy this
dataset supports for lifetime value — grows almost linearly at
~10 items/order through order 30, then tapers gradually to
~7.2–7.4 items/order among the highest-tenure users (orders 50–99). That's
a much flatter decay than the sharply front-loaded curve typical of
real-dollar LTV, meaning this platform's highest-tenure users keep
contributing meaningful value rather than plateauing early.

## The question

How does a user's cumulative "lifetime value" grow as their tenure
(order count) increases?

## Why this is a proxy, not real LTV, and why `order_products_prior` only

Instacart's public release has **no dollar amounts anywhere in the
schema** — no column in any of the six files prices a single item. Real
LTV can't be computed from this dataset; the adapted metric in use is
**cumulative item count**, stated explicitly as a volume proxy, not
presented as revenue.

The query deliberately excludes `order_products_train` and uses
`order_products_prior` only, for the same reason as the RFM monetary
component (see [06_rfm_and_churn.md](06_rfm_and_churn.md)): keeping
every user's number built the same way regardless of which split their
held-out final order landed in. One direct consequence worth stating up
front: since `order_products_prior` excludes each user's final order by
construction, its highest `order_number` present is 99, not 100, even
though a user can have up to 100 total orders — the checkpoints below
stop at 99, not 100.

## The growth curve

| Order number | Avg. cumulative items | Users reaching this point |
|---|---|---|
| 1 | 10.1 | 206,209 |
| 10 | 101.5 | 101,696 |
| 20 | 204.3 | 50,731 |
| 30 | 306.4 | 29,183 |
| 50 | 494.5 | 10,910 |
| 75 | 679.8 | 3,453 |
| 99 | 853.2 | 1,374 |

Per-order pace, computed from the deltas between checkpoints, tells the
more precise story than the cumulative total alone:

- **~10.0–10.3 items/order**, consistently, from order 1 through order 30
- **~9.4 items/order** between orders 30–50 — a real but gradual taper
- **~7.2–7.4 items/order** among the highest-tenure users (orders 50–99)

## Two competing explanations for the taper — stated honestly, not resolved

This query, run at the population level, can't distinguish between two
plausible mechanisms, so both are named rather than picking one to sound
more confident than the data supports:

1. **Genuine basket-size shrinkage** — extremely high-tenure users shift
   toward smaller, more frequent top-up orders rather than large
   stock-up trips.
2. **A survivorship effect** — the ~1,374 users who reach order 99 are a
   different population than the 206,209 who reach order 1, and
   whatever makes someone order 99 times might independently correlate
   with smaller per-trip baskets (frequent light restocking vs.
   occasional bulk shopping), rather than any individual user's basket
   actually shrinking over time.

Distinguishing these would require tracking within-user trends over
their own order history, not the population-level averages this query
computes — a natural extension if this mattered for a real product
decision.

## What this proxy can and can't tell a real business

Item count is not spend — a basket of 10 cheap items and a basket of 10
premium items look identical here. If this were feeding a real go-to-
market or retention-investment decision, actual order value would be
required, not this proxy. What the proxy *can* support: unlike LTV
curves that front-load nearly all their value in the first few
transactions, this one keeps accumulating steadily well past the point a
coarser cohort analysis would call a user "mature" — a real signal that
retention investment on this platform's highest-tenure users continues
to pay off, rather than plateauing early.

## Reproducing this

```bash
duckdb warehouse/dev.duckdb < sql/exploration/15_ltv_proxy_by_tenure.sql

# formalized version -- avg_cumulative_items_prior column, one row per order_number:
cd dbt && dbt run --select mart_order_sequence_summary --profiles-dir . && cd ..
```
