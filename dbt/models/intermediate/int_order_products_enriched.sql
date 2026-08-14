{{ config(tags=['delivery']) }}

-- Intermediate model: item-level detail across BOTH order_products
-- tables, joined to product/aisle/department names and order context.
-- Written once, reused by every downstream delivery-vertical mart that
-- needs product-level detail instead of each one re-deriving the same
-- union + joins (the same reasoning as int_trips_enriched on the
-- mobility side).
--
-- source_eval_set preserves which table each row came from ('prior' or
-- 'train') rather than silently blending them -- downstream models that
-- need the volume/monetary-proxy symmetry rule (order_products_prior
-- only -- see CLAUDE.md's eval_set gotcha) can filter on it explicitly;
-- rate-based models (reorder rate, department composition) that are
-- safe with both sources can use everything.

with prior as (
    select order_id, product_id, add_to_cart_order, is_reordered, 'prior' as source_eval_set
    from {{ ref('stg_order_products_prior') }}
),
train as (
    select order_id, product_id, add_to_cart_order, is_reordered, 'train' as source_eval_set
    from {{ ref('stg_order_products_train') }}
),
combined as (
    select * from prior
    union all
    select * from train
)
select
    c.order_id,
    c.product_id,
    c.add_to_cart_order,
    c.is_reordered,
    c.source_eval_set,
    p.product_name,
    p.aisle_id,
    a.aisle,
    p.department_id,
    d.department,
    o.user_id,
    o.order_number,
    o.order_dow,
    o.order_hour_of_day,
    o.days_since_prior_order
from combined c
join {{ ref('stg_products') }} p on c.product_id = p.product_id
join {{ ref('stg_aisles') }} a on p.aisle_id = a.aisle_id
join {{ ref('stg_departments') }} d on p.department_id = d.department_id
join {{ ref('stg_orders') }} o on c.order_id = o.order_id
