-- Staging model: 1:1 with the raw source.

select
    aisle_id,
    aisle
from {{ source('raw', 'aisles') }}
