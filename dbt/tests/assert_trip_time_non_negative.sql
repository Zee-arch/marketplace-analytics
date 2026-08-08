-- Singular test (as opposed to the generic not_null/unique/etc. tests in
-- _staging.yml): a plain SELECT that should return zero rows if the data
-- is healthy. dbt fails this test if it returns anything.
--
-- Codifies the Q4 finding by hand: a trip can't have a duration <= 0.
-- Known baseline as of March 2025: 3 such rows exist in the raw data
-- (see sql/exploration/04_trip_duration_distribution.sql) -- meaning
-- this test is EXPECTED to fail right now, on purpose, until stg_trips
-- gets a filter or those rows get explicitly excluded downstream. A
-- red test here is more honest than silently ignoring 3 known-bad rows.

select *
from {{ ref('stg_trips') }}
where trip_time <= 0
