-- Question: What share of items in an order are repeat purchases
-- (reordered=1) vs. new products, and does that share change as a
-- user's order history grows?
-- Source: order_products_prior + order_products_train, joined to orders
-- for order_number. Using both (not just _prior) is safe here, unlike a
-- volume/monetary metric -- this measures a RATE, not a per-user total,
-- so the train/test asymmetry doesn't bias anything; test users' held-out
-- order simply isn't part of the rate either way, symmetrically.

with all_order_products as (
    select order_id, reordered from order_products_prior
    union all
    select order_id, reordered from order_products_train
),
joined as (
    select aop.reordered, o.order_number
    from all_order_products aop
    join orders o on aop.order_id = o.order_id
)

-- Part 1: two summary rates -- one honest quirk to flag first: a user's
-- very first order can never contain a reorder (nothing to reorder yet),
-- so blending it into "overall" mechanically drags the rate down.
select
    'all orders (1st order included -- reorder=0 there by definition)' as scope,
    count(*) as total_items,
    sum(reordered) as reordered_items,
    round(100.0 * sum(reordered) / count(*), 2) as reorder_rate_pct
from joined
union all
select
    'excluding each user''s 1st order' as scope,
    count(*) as total_items,
    sum(reordered) as reordered_items,
    round(100.0 * sum(reordered) / count(*), 2) as reorder_rate_pct
from joined
where order_number > 1;

-- Part 2: does the reorder share change as a user's history grows?
-- Different grain (one row per order_number) than Part 1's two summary
-- rows, so it's a separate statement rather than another UNION branch.
with all_order_products_2 as (
    select order_id, reordered from order_products_prior
    union all
    select order_id, reordered from order_products_train
),
joined_2 as (
    select aop.reordered, o.order_number
    from all_order_products_2 aop
    join orders o on aop.order_id = o.order_id
)
select
    order_number,
    count(*) as total_items,
    round(100.0 * sum(reordered) / count(*), 2) as reorder_rate_pct
from joined_2
group by 1
order by 1;

/*
Finding: overall reorder rate is 59.01% (62.87% excluding each user's
1st order, where a reorder is structurally impossible -- the honest
number to lead with).

Part 2 is the real story: reorder rate climbs monotonically and
substantially with tenure -- 27.24% at order 2, 50.33% by order 5,
63.35% by order 10, all the way to 85.99% by order 100. This isn't a
noisy trend, it's a clean, consistent climb at every single point
checked. Read together with Q11's retention curve: the users who stick
around long enough to reach high order numbers are also the users whose
baskets become dominated by repeat purchases -- i.e. survivorship and
habit-formation are moving together, not independently. A grocery
delivery business's real lever isn't just getting someone to order once
more; it's getting them from the "still mostly new products" zone (first
~5 orders) to the "shopping list on autopilot" zone (~order 20+, 70%+
reorder rate), where retention risk drops sharply once someone's there.
*/
