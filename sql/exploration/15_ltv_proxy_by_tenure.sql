-- Question: How does cumulative "lifetime value" (item-volume proxy)
-- grow as a user's tenure (order count) increases?
-- Source: order_products_prior only -- deliberately excludes
-- order_products_train, so every user's number is built the same way
-- regardless of whether their held-out final order landed in the train
-- or test split (see CLAUDE.md / Q13's monetary-proxy note).
--
-- Consequence worth stating up front: since order_products_prior
-- excludes each user's final order by construction, its highest
-- order_number is 99, not 100, even though users can have up to 100
-- total orders (verified separately) -- checkpoints below stop at 99.

with item_counts_per_order as (
    select
        o.user_id,
        o.order_number,
        count(op.product_id) as items_in_this_order
    from orders o
    join order_products_prior op on o.order_id = op.order_id
    group by 1, 2
),
cumulative as (
    select
        user_id,
        order_number,
        sum(items_in_this_order) over (
            partition by user_id order by order_number
        ) as cumulative_items
    from item_counts_per_order
)
select
    order_number,
    count(distinct user_id) as n_users_at_this_point,
    round(avg(cumulative_items), 1) as avg_cumulative_items
from cumulative
where order_number in (1, 5, 10, 15, 20, 30, 50, 75, 99)
group by 1
order by 1;

/*
Finding: cumulative item-volume ("LTV" proxy) grows almost linearly for
a long stretch, not the sharply-decelerating curve a lot of real-dollar
LTV curves show. Per-order pace (computed from the deltas between
checkpoints): ~10.0-10.3 items/order consistently from order 1 through
order 30, then a real but gradual taper -- ~9.4 items/order between
orders 30-50, dropping to ~7.2-7.4 items/order among the highest-tenure
users (order 50-99).

Two reads on the taper, stated as competing hypotheses rather than a
single confident claim (this query alone can't distinguish them): (1)
genuine basket-size shrinkage as extremely high-tenure users shift
toward smaller, more frequent top-up orders rather than large stock-up
trips, or (2) a survivorship effect -- the ~1,374 users who reach order
99 are a different population than the 206,209 who reach order 1, and
whatever makes someone order 99 times might correlate with smaller
per-trip baskets (e.g. very frequent light restocking vs. occasional
bulk shopping). Distinguishing these would need within-user trends over
their own history, not the population-level averages this query
computes.

Practical takeaway: unlike LTV curves that front-load most of their
value in the first few transactions, this one keeps accumulating value
steadily well past the point most retention analyses would call a user
"mature" -- a real signal that this business's highest-tenure users stay
meaningfully valuable rather than plateauing early.
*/
