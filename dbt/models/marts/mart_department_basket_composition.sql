{{ config(tags=['delivery']) }}

-- Mart: one row per department -- purchase volume share and reorder
-- rate. Formalizes the department-level half of Q16.

select
    department,
    count(*) as total_items,
    round(100.0 * count(*) / (select count(*) from {{ ref('int_order_products_enriched') }}), 2) as pct_of_all_items,
    round(100.0 * sum(case when is_reordered then 1 else 0 end) / count(*), 2) as reorder_rate_pct
from {{ ref('int_order_products_enriched') }}
group by 1
order by total_items desc
