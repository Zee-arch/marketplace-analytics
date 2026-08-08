-- Question: What's the distribution of trip duration in March 2025 (median,
-- p90, p99), and what do outlier/impossible values reveal about data quality?
-- Source: fhvhv_2025-03.parquet (~20M rows)
-- Note: "trip duration" = dropoff_datetime - pickup_datetime (= trip_time,
-- in seconds). Deliberately NOT dropoff - request_datetime, which would
-- silently bake in rider wait time instead of measuring the trip itself.

select
    count(*) as total_trips,

    -- central tendency + tail shape, in both raw seconds (precise) and
    -- rounded minutes (readable) -- ride duration distributions are
    -- heavily right-skewed, so median alone hides the long tail p90/p99
    -- exist to expose
    median(trip_time) as median_sec,
    round(median(trip_time) / 60.0, 1) as median_min,
    quantile_cont(trip_time, 0.90) as p90_sec,
    round(quantile_cont(trip_time, 0.90) / 60.0, 1) as p90_min,
    quantile_cont(trip_time, 0.99) as p99_sec,
    round(quantile_cont(trip_time, 0.99) / 60.0, 1) as p99_min,

    -- the extremes -- where impossible values would show up first
    min(trip_time) as min_sec,
    max(trip_time) as max_sec,
    round(max(trip_time) / 3600.0, 1) as max_hours,

    -- impossible: a trip can't end at or before it started
    sum(case when trip_time <= 0 then 1 else 0 end) as zero_or_negative_trips,

    -- implausible: almost certainly meter/logging errors, not real rides
    sum(case when trip_time > 4 * 3600 then 1 else 0 end) as over_4_hour_trips,

    -- cross-check: trip_time is a precomputed column: does it actually
    -- agree with the raw timestamp gap it's supposed to represent?
    -- a >60s mismatch flags rows where the two disagree -- a pipeline
    -- quality signal independent of the duration values themselves
    sum(case
        when abs(trip_time - date_diff('second', pickup_datetime, dropoff_datetime)) > 60
        then 1 else 0
    end) as trip_time_mismatch_trips
from trips;

/*
Finding: median trip is 15.7 min (943s); p90 is 36.5 min; p99 is 66.9 min.
The gap between median and p99 (15.7 min vs. 66.9 min, a >4x spread) is a
normal, expected shape for trip-duration data -- right-skewed with a long
tail of genuinely long trips (airport runs, outer-borough crossings), not
evidence of bad data. Reporting only the mean or median here would hide
that tail; p90/p99 exist specifically to surface it.

Impossible/implausible values are reassuringly rare: 3 trips (out of
20,536,879) have trip_time <= 0, and 104 run over 4 hours (max recorded:
8.8 hours -- almost certainly a trip that was never properly closed out
rather than a real continuous ride). At this scale (<0.001% combined),
these don't materially distort the median/p90/p99 above and don't need
filtering before reporting them.

The more interesting finding is the cross-check: 8,827 trips (~0.043%)
have their trip_time column disagree with the raw dropoff-pickup gap by
more than 60 seconds. Small, but non-zero and systematic enough to name.
Working theory, not confirmed: trip_time and the pickup/dropoff
timestamps likely come from two different source systems (e.g. vehicle
telematics/GPS vs. the dispatch platform's own event log), so minor
disagreement between them is a plausible integration artifact rather than
random corruption -- but this is a hypothesis, not something this query
verified, and would need a follow-up join against dispatching_base_num or
similar to actually confirm a pattern.

Practical takeaway: trip_time is trustworthy enough to report on directly
without cleaning first, but any downstream analysis on duration should be
aware ~1 in 2,300 trips has a small discrepancy between the two possible
ways of measuring it.
*/
