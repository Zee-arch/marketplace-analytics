-- Question: For each pickup zone, what are its top 3 dropoff zones by
-- trip count?
-- Source: fhvhv_2025-03.parquet joined twice to taxi_zone_lookup.csv (once
-- for pickup, once for dropoff -- same lookup table, two different roles)
-- Note: "do" is a reserved word in DuckDB's grammar (PL/pgSQL-style DO
-- blocks) -- using "dz" as the dropoff-zone alias instead to avoid a
-- parser error.

with pu_do_counts as (
    -- one row per (pickup zone, dropoff zone) pair, with how many trips
    -- made that exact journey
    select
        pu.Zone as pickup_zone,
        dz.Zone as dropoff_zone,
        count(*) as trip_count
    from trips t
    join zones pu on t.PULocationID = pu.LocationID
    join zones dz on t.DOLocationID = dz.LocationID
    group by 1, 2
),
ranked as (
    -- row_number() resets its count at 1 for every new pickup_zone
    -- (PARTITION BY), ordered by trip_count within that partition --
    -- this is what makes "top N per group" possible without a separate
    -- query per group
    select
        pickup_zone,
        dropoff_zone,
        trip_count,
        row_number() over (
            partition by pickup_zone
            order by trip_count desc
        ) as dropoff_rank
    from pu_do_counts
)
select pickup_zone, dropoff_zone, trip_count, dropoff_rank
from ranked
where dropoff_rank <= 3
order by pickup_zone, dropoff_rank;

/*
Finding: 781 rows cover 261 of 265 zones (a handful of very low-volume
zones have fewer than 3 distinct dropoff destinations to rank).

73 of those 261 zones (28%) have their own zone as the #1 dropoff --
e.g. Crown Heights North -> Crown Heights North is more than double its
#2 destination (34,567 vs. 15,241 trips). Zones cover a real neighborhood
footprint, not a single point, so this reflects genuine short local trips
within a zone rather than a data artifact.

For the highest-volume pickup zones specifically (from Q5): "Outside of
NYC" is the #1 dropoff for JFK, LaGuardia, East Village, and Times Sq --
expected for the two airports (travelers heading past the 5 boroughs to
Jersey/Westchester/Long Island), less obviously expected for East
Village/Times Sq, which suggests a meaningful volume of trips from
Manhattan's core out to the wider metro area, not just airport-bound
traffic. Also notable: JFK -> JFK ranks #3 for JFK Airport (7,718 trips)
-- plausible explanations include inter-terminal transfers or driver
repositioning, but this wasn't investigated further here; flagged as an
open curiosity, not a confirmed explanation.
*/
