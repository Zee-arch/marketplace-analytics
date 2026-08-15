# Order-Sequence Retention & Reorder Rate — Instacart Delivery Vertical

**Headline finding:** the real retention story doesn't start until order
5 — the first four orders are a 100% floor built into how this dataset
was collected, not user loyalty. From order 5 onward, retention declines
steadily (88.37% → 53.7% by order 10 → 26.15% by order 20) while
**reorder rate climbs in the opposite direction** (27.24% at order 2 →
85.99% by order 100) — the users who stick around are also the users
whose baskets fill up with repeat items. Those two curves moving in
opposite directions, together, are the actual growth signal here.

## The question

Two related questions about how users behave over their lifecycle with
the platform: what share reach a 2nd order, a 5th, a 10th (Q11)? And
does the *mix* of new vs. repeat items in a basket change as tenure
grows (Q12)?

## Adapting "retention" to this dataset's real constraints

A textbook retention curve is calendar-based — "of users who signed up
in January, what % ordered again in February." This dataset has **no
calendar dates anywhere** (order timing is relative: day-of-week, hour,
and days-since-previous-order only), so retention here is redefined as
**order-sequence-based**: "of all 206,209 users, what % placed at least
N orders" — a real, meaningful metric, just not directly comparable to a
month-over-month cohort curve.

## The retention curve, read with skepticism at both ends

Instacart's public release only includes users with 4–100 total orders
(verified: `min(order count) = 4`, `max = 100`). That single fact
explains the first four rows of the curve on its own — 100.0% of users
"retain" through order 4, by construction, before any real behavior is
measured:

| Order reached | % of all users |
|---|---|
| 1–4 (construction floor) | 100.00% |
| 5 | 88.37% |
| 10 | 53.70% |
| 15 | 36.41% |
| 20 | 26.15% |
| 30 | 14.88% |
| 100 | 0.67% (1,374 users) |

The top end deserves the same skepticism as the bottom, for the mirror
reason: order count is capped at exactly 100, so the tail is likely
another collection ceiling, not proof that loyalty behaviorally stops
there — those 1,374 users may well have kept ordering beyond what this
public release captured. The genuinely informative range, where the
curve reflects real declining engagement rather than a sampling
boundary, is roughly **orders 5–50**.

## Reorder rate climbs with tenure — and it doesn't move independently of retention

Overall reorder rate is 59.01% (62.87% excluding each user's first
order, where a reorder is structurally impossible — the honest number
to lead with, since blending the first order in mechanically drags the
rate down). The more informative view is by order number:

| Order number | Reorder rate |
|---|---|
| 2 | 27.24% |
| 5 | 50.33% |
| 10 | 63.35% |
| 100 | 85.99% |

This is a clean, monotonic climb at every checkpoint, not a noisy
trend. Read together with the retention curve above, it says something
specific: **survivorship and habit-formation move together, not
independently.** The users who stick around long enough to reach high
order numbers are the same users whose baskets shift from "still mostly
new products" toward "shopping list on autopilot." Practically, that
reframes where a growth team's retention lever actually is — not just
"get one more order out of someone," but getting a user from the first
~5 orders (still exploring) to ~order 20+ (70%+ reorder rate), where the
data suggests retention risk drops sharply once someone's there.

## What this doesn't establish

No calendar dates means this can't say *how long, in real days or weeks*,
it typically takes a user to move from order 5 to order 20 — only that
the ones who do show this reorder pattern. A real retention program
would want that time dimension (e.g. "average 45 days to reach order
10") to know how long to sustain an engagement campaign, which this
dataset structurally can't supply.

## Reproducing this

```bash
duckdb warehouse/dev.duckdb < sql/exploration/11_order_sequence_retention.sql
duckdb warehouse/dev.duckdb < sql/exploration/12_reorder_rate.sql

# or the formalized, tested version (one row per order_number):
cd dbt && dbt run --select mart_order_sequence_summary --profiles-dir . && cd ..
```
