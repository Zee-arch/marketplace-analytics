-- Singular test: mart_daily_trip_summary's trip_count column, summed
-- across all days, must equal the raw trip count straight from the
-- source. This is the same sanity check done by hand throughout
-- sql/exploration/ (e.g. Q2's "the two counts must sum to the Q1 total")
-- turned into something that runs automatically instead of being
-- eyeballed once and forgotten.
--
-- raw_total is scoped to March 2025, matching int_trips_enriched's own
-- scope (see its header comment): the source now spans 6 months (Oct
-- 2024-Mar 2025, added for the DiD analysis), but this mart is still
-- March-only by design. Comparing against the unscoped source would
-- compare a 1-month mart against a 6-month raw count and fail for a
-- reason that has nothing to do with a real data problem.

select
    (select sum(trip_count) from {{ ref('mart_daily_trip_summary') }}) as mart_total,
    (select count(*) from {{ source('raw', 'trips') }}
        where pickup_datetime >= '2025-03-01' and pickup_datetime < '2025-04-01') as raw_total
where (select sum(trip_count) from {{ ref('mart_daily_trip_summary') }})
   != (select count(*) from {{ source('raw', 'trips') }}
        where pickup_datetime >= '2025-03-01' and pickup_datetime < '2025-04-01')
