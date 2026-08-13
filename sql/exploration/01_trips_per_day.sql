-- Question: How many trips per day in March 2025, and which day had the most?
-- Source: fhvhv_2025-03.parquet (~20M rows)

select
    cast(pickup_datetime as date) as trip_date, -- truncate pickup_datetime to a calendar date, alias it
    dayname(pickup_datetime) as day_of_week,   -- truncate pickup_datetime to a calendar day, alias it
    count(*) as trip_count                        -- count the rows
from trips
-- explicit filter added 2026-08-13: trips now spans 6 months (Oct 2024-
-- Mar 2025, downloaded for the congestion-pricing DiD analysis) instead
-- of just this file's original single month -- without this, re-running
-- the file would silently produce different numbers than the finding
-- already written below
where pickup_datetime >= '2025-03-01' and pickup_datetime < '2025-04-01'
group by 1, 2
order by trip_count desc;

/*
Finding: Friday and Saturday are the peak-demand days all month — weekly
seasonality dominates day-to-day variation, so week-over-week comparisons
are meaningful while day-over-day ones are mostly noise.

Exception: 2025-03-09 (the 2nd Sunday) undercounts relative to its neighbor
Sundays (03-16, 03-23) by ~1.5%, breaking what's otherwise a flat ~645k
band. Cause: 2025-03-09 is the date U.S. Daylight Saving Time begins —
clocks skip 2:00am straight to 3:00am, so that calendar day has only 23
wall-clock hours. Since pickup_datetime is a naive local timestamp with no
timezone offset, the 2-3am hour is structurally absent from the clock, not
just from demand — any trips that would've picked up in that window can't
be timestamped into it. This is a silent data-quality artifact, not an
error: the query runs clean and the number looks like a plausible quiet
Sunday unless you separately know the date is DST. (2025-03-30 is also
below its neighbors, for a still-unexplained reason unrelated to DST —
flagged as open, not force-fit into this explanation.)
*/