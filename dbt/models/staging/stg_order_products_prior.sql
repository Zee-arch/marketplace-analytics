{{ config(tags=['delivery']) }}

-- Staging model: 1:1 with the raw source. `reordered` arrives as bigint
-- (0/1) -- cast to boolean here, once, matching the pattern set by
-- int_trips_enriched's is_shared_request/is_shared_match booleans.

select
    order_id,
    product_id,
    add_to_cart_order,
    (reordered = 1) as is_reordered
from {{ source('raw', 'order_products_prior') }}
