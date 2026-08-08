-- Mart: one row per (hour_of_day, day_type) -- formalizes Q7 (driver
-- share of fare by hour) and Q9 (weekday vs weekend curve) into a single
-- flexible table that can be sliced either way, instead of two separate
-- one-off queries with duplicated normalization logic.

select
    hour_of_day,
    day_type,
    count(*) as trip_count,
    -- Q9's normalization: how many distinct calendar dates fall into this
    -- day_type, so trip_count can be turned into a fair per-day average
    -- instead of a raw total skewed by March having 21 weekdays vs. 10
    -- weekend days
    count(distinct trip_date) as n_days,
    round(count(*) * 1.0 / count(distinct trip_date)) as avg_trips_per_hour,
    sum(driver_pay) as total_driver_pay,
    sum(base_passenger_fare) as total_base_fare,
    round(100.0 * sum(driver_pay) / nullif(sum(base_passenger_fare), 0), 2) as driver_share_of_fare_pct
from {{ ref('fct_trips') }}
group by 1, 2
order by 1, 2
