-- Staging model: 1:1 with the raw zone lookup, just renamed to
-- snake_case for consistency with the rest of the project.

select
    "LocationID" as location_id,
    "Borough" as borough,
    "Zone" as zone,
    service_zone
from {{ source('raw', 'zones') }}
