-- Intermediate model: one row per trip, same grain as stg_trips, but with
-- every reusable per-row derivation computed ONCE here instead of
-- re-derived in every downstream mart or exploration query. This is the
-- CASE statement from Q2/Q3, the zone joins from Q5/Q6/Q8, and the
-- date/hour bucketing from Q1/Q9 -- all written exactly once.
--
-- Deliberately NOT included here: money ratios like driver-pay-share-of-
-- fare. Q7 found that ~64k trips have a $0 base_passenger_fare -- dividing
-- per-row here would produce a wave of NULLs/divide-by-zero noise at the
-- trip grain. The correct place to compute that ratio is on top of
-- SUMMED values in a mart (numerator and denominator both aggregated
-- first, then divided once) -- exactly how Q7 avoided the same problem.

select
    t.hvfhs_license_num,
    t.dispatching_base_num,
    t.request_datetime,
    t.on_scene_datetime,
    t.pickup_datetime,
    t.dropoff_datetime,
    t.pickup_location_id,
    t.dropoff_location_id,
    t.trip_miles,
    t.trip_time,
    t.base_passenger_fare,
    t.tolls,
    t.bcf,
    t.sales_tax,
    t.congestion_surcharge,
    t.airport_fee,
    t.tips,
    t.driver_pay,
    t.cbd_congestion_fee,

    -- company label (Q2's CASE, written once)
    case
        when t.hvfhs_license_num = 'HV0003' then 'Uber'
        when t.hvfhs_license_num = 'HV0005' then 'Lyft'
    end as provider_name,

    -- zone names (Q5/Q6/Q8's joins, written once)
    pu.zone as pickup_zone,
    pu.borough as pickup_borough,
    dz.zone as dropoff_zone,
    dz.borough as dropoff_borough,

    -- date/time buckets (Q1/Q9's derivations, written once)
    cast(t.pickup_datetime as date) as trip_date,
    dayname(t.pickup_datetime) as day_of_week,
    case
        when dayname(t.pickup_datetime) in ('Saturday', 'Sunday') then 'weekend'
        else 'weekday'
    end as day_type,
    extract(hour from t.pickup_datetime) as hour_of_day,

    -- the three derived intervals from the four-timestamp schema (not
    -- trip duration itself -- trip_time above already covers that, and
    -- Q4 confirmed it's reliable enough to use directly)
    date_diff('second', t.request_datetime, t.pickup_datetime) as wait_time_sec,
    date_diff('second', t.request_datetime, t.on_scene_datetime) as approach_time_sec,
    date_diff('second', t.on_scene_datetime, t.pickup_datetime) as dwell_time_sec,

    -- boolean versions of the Y/N flags -- cleaner for downstream
    -- filtering than repeating = 'Y' everywhere; raw flags still passed
    -- through above in case anything needs the original representation
    (t.shared_request_flag = 'Y') as is_shared_request,
    (t.shared_match_flag = 'Y') as is_shared_match,
    (t.cbd_congestion_fee > 0) as is_cbd_fee_trip

from {{ ref('stg_trips') }} t
join {{ ref('stg_zones') }} pu on t.pickup_location_id = pu.location_id
join {{ ref('stg_zones') }} dz on t.dropoff_location_id = dz.location_id
