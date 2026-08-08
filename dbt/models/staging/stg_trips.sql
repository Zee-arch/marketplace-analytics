-- Staging model: 1:1 with the raw source, just renamed/typed. No business
-- logic, no joins, no filtering -- that discipline is what keeps this
-- layer trustworthy as a single source every downstream model can build
-- on without re-deriving column meanings.

select
    hvfhs_license_num,
    dispatching_base_num,
    originating_base_num,
    request_datetime,
    on_scene_datetime,
    pickup_datetime,
    dropoff_datetime,
    "PULocationID" as pickup_location_id,
    "DOLocationID" as dropoff_location_id,
    trip_miles,
    trip_time,
    base_passenger_fare,
    tolls,
    bcf,
    sales_tax,
    congestion_surcharge,
    airport_fee,
    tips,
    driver_pay,
    shared_request_flag,
    shared_match_flag,
    access_a_ride_flag,
    wav_request_flag,
    wav_match_flag,
    cbd_congestion_fee
from {{ source('raw', 'trips') }}
