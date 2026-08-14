-- Mart: one row per product -- reorder rate, floored to products with
-- >=1,000 total purchases to avoid small-sample noise (median product
-- has only 63 total purchases across the whole dataset; a product
-- bought twice with 2 reorders would otherwise show a meaningless 100%
-- reorder rate -- same threshold and reasoning as Q16's original
-- exploration).

select
    product_name,
    count(*) as total_purchases,
    round(100.0 * sum(case when is_reordered then 1 else 0 end) / count(*), 2) as reorder_rate_pct
from {{ ref('int_order_products_enriched') }}
group by 1
having count(*) >= 1000
order by reorder_rate_pct desc
