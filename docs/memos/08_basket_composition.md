# Basket Composition & Product-Level Loyalty — Instacart Delivery Vertical

**Headline finding:** produce (29.24% of all items) and dairy & eggs
(16.65%) together account for ~46% of everything ever purchased, both
with high reorder rates — consistent with perishable staples restocked
on a routine cycle. Pantry breaks that pattern: 5th by volume, but only
34.74% reorder rate, well below its volume-neighbors. At the product
level, Banana is both the single most-purchased item in the entire
dataset (491,291 purchases) **and** carries an 84.51% reorder rate —
volume leadership and loyalty aren't a tradeoff in this SKU, they
reinforce each other.

## The question

Which departments dominate purchase volume, and which specific products
show the strongest repeat-purchase signal — a proxy for product-market
fit at the SKU level?

## Department-level: volume and loyalty mostly move together — pantry is the exception

| Department | % of all items | Reorder rate |
|---|---|---|
| Produce | 29.24% | 65.05% |
| Dairy & eggs | 16.65% | 67.02% |
| Pantry | (top 5 by volume) | **34.74%** |

Produce and dairy together make up nearly half of every item purchased
in the dataset, and both carry reorder rates well above 60% — the
signature of routine, habitual restocking rather than one-off
purchases. Pantry is the department worth calling out explicitly: it's
still top-5 by volume, but its reorder rate sits far below its
volume-neighbors, at roughly half of produce's. That gap suggests pantry
purchases skew toward exploratory or occasion-driven buying rather than
a fixed shopping list — a materially different customer behavior than
the staples above it, and one that would call for a different
merchandising strategy (discovery and variety, not availability
protection).

## Product-level leaderboard: why the ≥1,000-purchase floor matters

The median product in this dataset has only **63 total purchases**
across the entire dataset. Without a volume floor, a product bought
twice with both purchases marked as reorders would show a meaningless
100% reorder rate — noise, not signal. Restricting to products with
≥1,000 total purchases before ranking by reorder rate avoids that:

- **8 of the top 10** products by reorder rate are milk variants,
  84–86% reorder rate each.
- **Banana** is the single most-purchased product in the entire
  dataset — 491,291 purchases — and still carries an **84.51%** reorder
  rate. That combination matters: extremely high volume and extremely
  high repeat-purchase loyalty showing up in the same SKU, not one
  trading off against the other.

## What this means for a growth/ops team

Staples like produce, dairy, milk, and bananas are simultaneously the
biggest traffic drivers *and* the strongest retention anchors in the
dataset — the products worth protecting on availability and pricing
above everything else, since a stockout or price hike there risks both
volume and loyalty at once. Pantry's lower reorder rate marks a
different kind of opportunity: it's a discovery/merchandising problem
(surfacing the right items to try), not an availability-protection one,
since users aren't yet locking into a routine there the way they do with
the produce and dairy staples.

## What this doesn't establish

Reorder rate at the product level says a customer bought the *same
product* again — it doesn't distinguish "this is a true staple this
household needs weekly" from "this happened to be convenient across
several orders in a row for other reasons." Distinguishing genuine habit
from correlated convenience would need purchase-interval data at the
product level (not just a binary reordered flag), which this query
doesn't build.

## Reproducing this

```bash
duckdb warehouse/dev.duckdb < sql/exploration/16_basket_composition.sql

# formalized, tested versions:
cd dbt && dbt run --select mart_department_basket_composition mart_product_reorder_leaderboard --profiles-dir . && cd ..
```
