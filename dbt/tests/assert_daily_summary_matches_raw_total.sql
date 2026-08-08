-- Singular test: mart_daily_trip_summary's trip_count column, summed
-- across all days, must equal the raw trip count straight from the
-- source. This is the same sanity check done by hand throughout
-- sql/exploration/ (e.g. Q2's "the two counts must sum to the Q1 total")
-- turned into something that runs automatically instead of being
-- eyeballed once and forgotten.

select
    (select sum(trip_count) from {{ ref('mart_daily_trip_summary') }}) as mart_total,
    (select count(*) from {{ source('raw', 'trips') }}) as raw_total
where (select sum(trip_count) from {{ ref('mart_daily_trip_summary') }})
   != (select count(*) from {{ source('raw', 'trips') }})
