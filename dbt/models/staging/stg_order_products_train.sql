{{ config(tags=['delivery']) }}

-- Staging model: 1:1 with the raw source. See stg_order_products_prior
-- for the reordered -> is_reordered cast reasoning.

select
    order_id,
    product_id,
    add_to_cart_order,
    (reordered = 1) as is_reordered
from {{ source('raw', 'order_products_train') }}
