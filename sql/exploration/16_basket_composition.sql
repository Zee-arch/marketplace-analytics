-- Question: Which departments dominate purchase volume, and which
-- specific products have the highest reorder rate (a repeat-purchase /
-- "product-market-fit" signal)?
-- Source: order_products_prior + order_products_train, joined to
-- products/departments. Using both is safe here -- same reasoning as
-- Q12 (a rate, not a per-user total, so the train/test asymmetry
-- doesn't bias anything).

with all_order_products as (
    select order_id, product_id, reordered from order_products_prior
    union all
    select order_id, product_id, reordered from order_products_train
)

-- Part 1: department-level volume + reorder rate
select
    d.department,
    count(*) as total_items,
    round(100.0 * count(*) / (select count(*) from all_order_products), 2) as pct_of_all_items,
    round(100.0 * sum(op.reordered) / count(*), 2) as reorder_rate_pct
from all_order_products op
join products p on op.product_id = p.product_id
join departments d on p.department_id = d.department_id
group by 1
order by total_items desc
limit 10;

-- Part 2: highest reorder-rate PRODUCTS specifically -- a
-- product-market-fit / habit-formation signal at the SKU level. Floor
-- of >=1,000 total purchases avoids small-sample noise (median product
-- has only 63 total purchases across the whole dataset; a product
-- bought twice with 2 reorders would otherwise show a meaningless 100%).
with all_order_products_2 as (
    select order_id, product_id, reordered from order_products_prior
    union all
    select order_id, product_id, reordered from order_products_train
)
select
    p.product_name,
    count(*) as total_purchases,
    round(100.0 * sum(op.reordered) / count(*), 2) as reorder_rate_pct
from all_order_products_2 op
join products p on op.product_id = p.product_id
group by 1
having count(*) >= 1000
order by reorder_rate_pct desc
limit 10;

/*
Finding: produce (29.24%) and dairy eggs (16.65%) together account for
~46% of every item ever purchased, and both carry high reorder rates
(65.05%, 67.02%) -- consistent with perishable staples people restock on
a routine cycle. pantry breaks the pattern worth naming explicitly: 5th
by volume, but reorder rate drops to 34.74%, well below its
volume-neighbors -- suggests pantry purchases skew toward one-off/
exploratory items rather than a fixed routine list, a different shopping
behavior than the produce/dairy staples above it.

The product-level leaderboard (>=1,000 purchases, avoiding small-sample
noise) is dominated by milk variants -- 8 of the top 10 are milk SKUs,
reorder rates 84-86%. Banana is the single most-purchased product in the
entire dataset (491,291 purchases, confirmed against the raw purchase-
count distribution separately) and still carries an 84.51% reorder
rate -- both extremely high volume AND extremely high repeat-purchase
loyalty at the same time, not a tradeoff between the two. For a growth
team, staples like these are the products worth protecting availability/
pricing on above all else -- they're both the highest-volume traffic
drivers and the strongest repeat-purchase anchors in the same SKUs.
*/
