-- Question: How many trips per day in March 2025, and which day had the most?
-- Source: fhvhv_2025-03.parquet (~20M rows)

select
    cast(pickup_datetime as date) as trip_date, -- truncate pickup_datetime to a calendar date, alias it
    dayname(pickup_datetime) as day_of_week,   -- truncate pickup_datetime to a calendar day, alias it
    count(*) as trip_count                        -- count the rows
from trips
group by 1, 2
order by trip_count desc;

 /* 
 We discovered that Friday and Saturday are main demanding days where increased rides are booked except an exception. 
 2nd Sunday of the Month came out to be an odd one out day in terms of trip count because the the time zone change 
 happening on that day. 
 */