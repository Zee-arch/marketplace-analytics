-- Mart: one row per calendar date. Formalizes Q1 (trips/day, weekly
-- seasonality), Q2 (Uber/Lyft split), Q3 (shared-ride counts), Q6 (CBD
-- fee), Q7 (driver share of fare), and Q10 (7-day rolling average) into
-- one reusable, tested table -- what a BI dashboard would actually query
-- for a daily trends view, instead of hitting sql/exploration/*.sql
-- one-off files.

with daily as (
    select
        trip_date,
        day_of_week,
        day_type,
        count(*) as trip_count,
        sum(case when provider_name = 'Uber' then 1 else 0 end) as uber_trip_count,
        sum(case when provider_name = 'Lyft' then 1 else 0 end) as lyft_trip_count,
        sum(case when is_shared_request then 1 else 0 end) as shared_request_count,
        sum(case when is_shared_match then 1 else 0 end) as shared_match_count,
        sum(case when is_cbd_fee_trip then 1 else 0 end) as cbd_fee_trip_count,
        sum(driver_pay) as total_driver_pay,
        sum(base_passenger_fare) as total_base_fare
    from {{ ref('fct_trips') }}
    group by 1, 2, 3
)
select
    trip_date,
    day_of_week,
    day_type,
    trip_count,
    uber_trip_count,
    lyft_trip_count,
    shared_request_count,
    shared_match_count,
    cbd_fee_trip_count,
    total_driver_pay,
    total_base_fare,
    -- Q7's take-rate metric, computed on SUMMED values (not per-trip --
    -- see int_trips_enriched's comment on why that matters), guarded
    -- against a hypothetical $0 total_base_fare day
    round(100.0 * total_driver_pay / nullif(total_base_fare, 0), 2) as driver_share_of_fare_pct,
    -- Q10's rolling average, now a column instead of a one-off query --
    -- same caveat applies: the first 6 rows have a partial window
    round(avg(trip_count) over (
        order by trip_date
        rows between 6 preceding and current row
    )) as rolling_7d_avg_trips
from daily
order by trip_date
