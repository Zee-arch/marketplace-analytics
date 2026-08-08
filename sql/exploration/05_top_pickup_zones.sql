-- Question: Which 10 pickup zones generated the most trips in March 2025?
-- Source: fhvhv_2025-03.parquet joined to taxi_zone_lookup.csv (zones table)
-- Pre-check done separately: every trips.PULocationID has a matching
-- zones.LocationID (0 unmatched), so an inner join here is safe -- it
-- won't silently drop rows from the ranking.

select
    z.Zone as pickup_zone,
    z.Borough as borough,
    count(*) as trip_count,
    -- scalar subquery for the grand total -- evaluated once, not per group,
    -- avoids needing a window function or extra GROUP BY column for a
    -- single constant
    round(100.0 * count(*) / (select count(*) from trips), 2) as pct_of_all_trips
from trips t
join zones z on t.PULocationID = z.LocationID
group by 1, 2
order by trip_count desc
limit 10;

/*
Finding: the two airports lead individually -- LaGuardia (1.96%) and JFK
(1.79%) -- which makes sense given airports concentrate demand at fixed
pickup points instead of spreading across a neighborhood the way street
hails do. The rest of the top 10 is dense Manhattan/Brooklyn zones (East
Village, Times Sq, Union Sq, Bushwick South, Crown Heights North).

The more useful number is the sum: the top 10 zones out of 265 total only
account for ~13% of all trips combined. Demand is highly distributed
across the city rather than concentrated in a small number of hotspots --
useful context before building anything (driver positioning, marketing
spend) on a "top zones" list, since even #1 doesn't reach 2% share.
*/
