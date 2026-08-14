-- Mart: one row per user -- Recency/Frequency/Monetary-proxy summary,
-- ready for segmentation or a BI tool. Formalizes Q13.
--
-- Definitions (see CLAUDE.md for the full reasoning, and Q13 for the
-- original exploration):
--   Recency  = days_since_prior_order on the user's most recent order.
--              Hand-defined tiers, not ntile(5) -- ~30% of users are
--              tied at the censored 30-day cap, and ntile() would
--              arbitrarily scatter that group across quintiles.
--   Frequency = total order count.
--   Monetary  = total items purchased via order_products_prior ONLY --
--              keeps every user's number computed the same way
--              regardless of whether their held-out final order landed
--              in the train or test split.

with user_last_order as (
    select user_id, max(order_number) as last_order_number
    from {{ ref('stg_orders') }}
    group by 1
),
recency as (
    select o.user_id, o.days_since_prior_order as recency_days
    from {{ ref('stg_orders') }} o
    join user_last_order ulo
        on o.user_id = ulo.user_id and o.order_number = ulo.last_order_number
),
frequency as (
    select user_id, count(*) as total_orders
    from {{ ref('stg_orders') }}
    group by 1
),
monetary as (
    select user_id, count(*) as total_items_prior
    from {{ ref('int_order_products_enriched') }}
    where source_eval_set = 'prior'
    group by 1
)
select
    f.user_id,
    f.total_orders as frequency,
    r.recency_days,
    case
        when r.recency_days = 30 then 'E: 30+ days (censored, at-risk)'
        when r.recency_days >= 22 then 'D: 22-29 days'
        when r.recency_days >= 15 then 'C: 15-21 days'
        when r.recency_days >= 8  then 'B: 8-14 days'
        else 'A: 0-7 days (very recent)'
    end as recency_tier,
    coalesce(m.total_items_prior, 0) as monetary_proxy_items
from frequency f
join recency r on f.user_id = r.user_id
left join monetary m on f.user_id = m.user_id
