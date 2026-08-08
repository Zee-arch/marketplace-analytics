-- Question: What's the 7-day rolling average of daily trips across March
-- 2025, and what trend does it reveal once weekly seasonality (Q1) is
-- smoothed out?
-- Source: fhvhv_2025-03.parquet
-- Caveat worth stating up front: the first 6 days of the window (Mar 1-6)
-- don't have 6 prior days available, so their "rolling average" is based
-- on fewer than 7 real days -- less smoothed, less comparable to the rest
-- of the series. Not filtered out here, just flagged.

with daily as (
    select
        cast(pickup_datetime as date) as trip_date,
        count(*) as trip_count
    from trips
    group by 1
)
select
    trip_date,
    trip_count,
    -- window frame: the current row plus the 6 rows before it, ordered by
    -- date -- a sliding 7-day window that moves forward one day at a time,
    -- averaging away day-of-week noise (weekday/weekend swings from Q1/Q9)
    -- to expose the underlying trend
    round(avg(trip_count) over (
        order by trip_date
        rows between 6 preceding and current row
    )) as rolling_7d_avg
from daily
order by trip_date;

/*
Finding: once weekly seasonality is smoothed out, there's a real,
gradual downward trend across the month -- not just weekly noise. The
rolling average holds fairly flat around 660k-688k through the first
three weeks, then declines through the last third of March, ending at
633,034 on 3/31 -- down ~7.9% from the first fully-windowed value
(687,373 on 3/7, the earliest date with 6 full prior days).

This is a genuine finding, but the cause isn't established by this query
and shouldn't be guessed at here -- plausible explanations include
seasonal effects (NYC weather improving through March pulls some trips
to walking/biking/transit) or continued behavioral adjustment to
congestion pricing (in effect since 2025-01-05, so March is 2+ months
into the policy, not the shock itself). Distinguishing between these
needs data outside a single month -- this is exactly the kind of pattern
the project's planned difference-in-differences analysis (Manhattan CRZ
vs. outer-borough control, pre/post Jan 2025) is built to actually test,
rather than eyeballing one month's trend line.
*/
