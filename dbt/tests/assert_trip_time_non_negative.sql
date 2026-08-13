-- Singular test (as opposed to the generic not_null/unique/etc. tests in
-- _staging.yml): a plain SELECT that returns the offending rows.
--
-- Codifies the Q4 finding by hand: a trip can't have a duration <= 0.
-- stg_trips is deliberately unscoped (staging = full 1:1 with source, by
-- design -- see int_trips_enriched's header for why the mobility marts
-- ARE scoped), so this test runs against however many months are
-- currently loaded, not just March 2025.
--
-- Known, already-investigated baseline: 3 rows in March 2025 alone (see
-- sql/exploration/04_trip_duration_distribution.sql), 20 total across
-- all 6 months now loaded (Oct 2024-Mar 2025, added for the DiD
-- analysis) -- broken down by month: Oct 1, Nov 2, Dec 6, Jan 4, Feb 4,
-- Mar 3. Consistent with the same rare, already-understood pattern
-- across every month, not a new problem -- recalibrated the threshold
-- to match, rather than leaving it stale against data that's grown.
--
-- error_if/warn_if thresholds, not a plain pass/fail: this test SHOULD
-- show a warning for those known rows every run (visible, not hidden),
-- but shouldn't fail CI on a known, already-triaged issue -- a
-- permanently-red CI badge trains people to ignore it, which defeats the
-- point. It only escalates to a real error if the count grows past the
-- known baseline, i.e. an actual regression worth blocking on.
{{ config(severity='error', error_if='>20', warn_if='>0') }}

select *
from {{ ref('stg_trips') }}
where trip_time <= 0
