-- Question: What share of March 2025 trips incurred the CBD congestion
-- fee, and which pickup zones do those trips most commonly originate from?
-- Source: fhvhv_2025-03.parquet joined to taxi_zone_lookup.csv
-- Context: NYC's Congestion Relief Zone (Manhattan south of 60th St)
-- tolling started 2025-01-05. HVFHV trips (Uber/Lyft) to/from/within/
-- through the zone are charged $1.50/trip -- confirmed against the
-- data below (verified against nyc.gov TLC industry notice 24-10, not
-- assumed): 7,030,967 trips at exactly $1.50, 3 trips at $3.00 (an
-- apparent double-charge, immaterial at this volume).

-- Part 1: overall share of trips paying the fee
select
    count(*) as total_trips,
    sum(case when cbd_congestion_fee > 0 then 1 else 0 end) as fee_paying_trips,
    round(100.0 * sum(case when cbd_congestion_fee > 0 then 1 else 0 end) / count(*), 2) as pct_paying_fee
from trips
-- scoped to March 2025 (added 2026-08-13, trips now spans 6 months for
-- the DiD analysis -- see 01). Especially important here: pre-2025 rows
-- have cbd_congestion_fee = NULL, not 0 -- NULL > 0 is neither true nor
-- false, so an unfiltered version wouldn't error, it would just silently
-- dilute pct_paying_fee with rows that could never have paid it
where pickup_datetime >= '2025-03-01' and pickup_datetime < '2025-04-01';

-- Part 2: top 10 pickup zones specifically among fee-paying trips --
-- i.e. where do CRZ-bound trips most often start?
select
    z.Zone as pickup_zone,
    z.Borough as borough,
    count(*) as fee_paying_trip_count
from trips t
join zones z on t.PULocationID = z.LocationID
where t.cbd_congestion_fee > 0
  and t.pickup_datetime >= '2025-03-01' and t.pickup_datetime < '2025-04-01'
group by 1, 2
order by fee_paying_trip_count desc
limit 10;

/*
Finding: 34.24% of all March 2025 HVFHV trips (7,030,970 of 20,536,879)
incurred the CBD congestion fee -- roughly one in three trips touches the
Congestion Relief Zone in some way.

All 10 top originating zones for fee-paying trips are in Manhattan --
unlike Q5's overall top-pickup-zones list, which mixed in Queens
(airports) and Brooklyn. That's expected and a good internal consistency
check: the fee only applies to trips to/from/within/through the CRZ
(Manhattan south of 60th St), so fee-paying trips should concentrate
exactly where they do here. It's also a preview of the project's planned
congestion-pricing DiD centerpiece -- this establishes the raw share of
March 2025 volume that's CRZ-exposed before any causal analysis is run.
*/
