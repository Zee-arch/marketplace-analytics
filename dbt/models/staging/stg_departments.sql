{{ config(tags=['delivery']) }}

-- Staging model: 1:1 with the raw source.

select
    department_id,
    department
from {{ source('raw', 'departments') }}
