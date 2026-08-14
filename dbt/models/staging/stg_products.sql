-- Staging model: 1:1 with the raw source.

select
    product_id,
    product_name,
    aisle_id,
    department_id
from {{ source('raw', 'products') }}
