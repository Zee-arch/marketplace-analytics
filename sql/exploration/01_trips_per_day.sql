-- Question: How many trips per day in March 2025, and which day had the most?
-- Source: fhvhv_2025-03.parquet (~20M rows)

select
    cast(pickup_datetime as date) as trip_date,   -- truncate pickup_datetime to a calendar date, alias it
    count(*) as trip_count                        -- count the rows
from trips
group by 1
order by trip_count desc;