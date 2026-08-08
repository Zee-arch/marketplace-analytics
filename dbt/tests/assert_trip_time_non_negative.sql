-- Singular test (as opposed to the generic not_null/unique/etc. tests in
-- _staging.yml): a plain SELECT that returns the offending rows.
--
-- Codifies the Q4 finding by hand: a trip can't have a duration <= 0.
-- Known, already-investigated baseline as of March 2025: exactly 3 such
-- rows (see sql/exploration/04_trip_duration_distribution.sql).
--
-- error_if/warn_if thresholds, not a plain pass/fail: this test SHOULD
-- show a warning for those 3 known rows every run (visible, not hidden),
-- but shouldn't fail CI on a known, already-triaged issue -- a
-- permanently-red CI badge trains people to ignore it, which defeats the
-- point. It only escalates to a real error if the count grows past the
-- known baseline, i.e. an actual regression worth blocking on.
{{ config(severity='error', error_if='>3', warn_if='>0') }}

select *
from {{ ref('stg_trips') }}
where trip_time <= 0
