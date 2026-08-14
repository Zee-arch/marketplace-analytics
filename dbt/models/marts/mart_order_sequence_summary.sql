{{ config(tags=['delivery']) }}

-- Mart: one row per order_number -- retention (Q11), reorder rate (Q12),
-- and cumulative LTV-proxy tenure (Q15) all share this grain, so this
-- mart combines all three instead of three separate one-off queries.
--
-- Caveats carried over from the original exploration, still true here:
--   - order_number 1-4 sit at 100% retention by dataset construction
--     (every user has 4-100 orders) -- not real loyalty.
--   - avg_cumulative_items_prior only goes up to order_number 99, not
--     100 -- order_products_prior excludes each user's final order by
--     construction, so no user's 100th order appears in it.

with retention as (
    select order_number, count(distinct user_id) as n_users_reaching
    from {{ ref('stg_orders') }}
    group by 1
),
reorder as (
    select
        order_number,
        count(*) as total_items,
        sum(case when is_reordered then 1 else 0 end) as reordered_items
    from {{ ref('int_order_products_enriched') }}
    group by 1
),
per_user_items as (
    -- order_products_prior only (see mart_user_rfm's header) --
    -- excludes each user's final order, hence the 1-99 range noted above
    select user_id, order_number, count(*) as item_count
    from {{ ref('int_order_products_enriched') }}
    where source_eval_set = 'prior'
    group by 1, 2
),
per_user_cumulative as (
    select
        user_id,
        order_number,
        sum(item_count) over (partition by user_id order by order_number) as cumulative_items
    from per_user_items
),
avg_cumulative as (
    select order_number, avg(cumulative_items) as avg_cumulative_items_prior
    from per_user_cumulative
    group by 1
)
select
    r.order_number,
    r.n_users_reaching,
    round(100.0 * r.n_users_reaching / (select count(distinct user_id) from {{ ref('stg_orders') }}), 2) as pct_of_all_users,
    ro.total_items,
    round(100.0 * ro.reordered_items / nullif(ro.total_items, 0), 2) as reorder_rate_pct,
    round(ac.avg_cumulative_items_prior, 1) as avg_cumulative_items_prior
from retention r
left join reorder ro on r.order_number = ro.order_number
left join avg_cumulative ac on r.order_number = ac.order_number
order by r.order_number
