-- Question: What share of rider cost goes to the driver, by hour of day?
-- (Marketplace take-rate economics -- flagged in project notes as the
-- important question here, not a syntax exercise.)
-- Source: fhvhv_2025-03.parquet
--
-- Critical definitional check, verified against the TLC HVFHV data
-- dictionary rather than assumed: driver_pay = "total driver pay, not
-- including tolls or tips, net of commission, surcharges, or taxes"
-- [nyc.gov TLC data dictionary]. That means driver_pay already excludes
-- pass-through amounts (tolls, tips) and is already net of the platform's
-- commission -- it is NOT safe to divide by a sum of every rider payment
-- column without distorting the result. Two metrics reported instead:
--
--   naive_driver_share_pct = driver_pay / (every rider payment column
--     summed) -- what "share of total rider cost" reads as literally,
--     but the denominator includes government pass-throughs (sales tax,
--     BCF, congestion fees) and driver pass-throughs (tolls, tips) that
--     were never actually split between platform and driver. Inflates
--     the denominator and artificially depresses this number -- not real
--     take-rate economics, included only because it's the literal
--     reading of the question.
--
--   driver_share_of_fare_pct = driver_pay / base_passenger_fare -- the
--     actual amount that gets split between platform and driver, with
--     third-party pass-throughs (taxes, tolls, tips, government fees)
--     excluded entirely. This is the metric that actually answers "how
--     much of the marketplace's own money goes to the driver."
--
-- Data quality note (checked, not filtered -- immaterial at this scale):
-- 47 trips have negative driver_pay, 382 have negative base_passenger_fare,
-- ~64k (0.31%) have a $0 fare. None of this affects group-level sums
-- meaningfully at 20.5M rows, but worth naming rather than silently
-- ignoring.

select
    extract(hour from pickup_datetime) as hour_of_day,
    count(*) as trip_count,
    round(sum(driver_pay), 2) as total_driver_pay,
    round(sum(base_passenger_fare), 2) as total_base_fare,
    round(sum(
        base_passenger_fare + tolls + bcf + sales_tax +
        congestion_surcharge + airport_fee + tips + cbd_congestion_fee
    ), 2) as total_rider_cost,
    round(100.0 * sum(driver_pay) / sum(
        base_passenger_fare + tolls + bcf + sales_tax +
        congestion_surcharge + airport_fee + tips + cbd_congestion_fee
    ), 2) as naive_driver_share_pct,
    round(100.0 * sum(driver_pay) / sum(base_passenger_fare), 2) as driver_share_of_fare_pct
from trips
group by 1
order by 1;

/*
Finding: driver_share_of_fare_pct (the metric that actually matters) sits
in a fairly tight band across the day, 69.83% (4am) to 75.26% (11pm) --
roughly a 5.4-point swing. The platform's cut of the base fare doesn't
change dramatically by hour; there's a real but modest dip in the 3am-5am
window specifically, recovering by 6-7am. Worth investigating further
(promotional activity, minimum-fare floors, or driver supply/demand
imbalance overnight are plausible mechanisms) but not confirmed by this
query alone -- flagging the pattern, not claiming the cause.

naive_driver_share_pct tracks about 15 points below driver_share_of_fare_pct
at every hour, and that gap isn't constant across hours -- which is the
real point of running both. The naive metric's denominator includes tips,
and tipping behavior isn't flat across the day (late-night/bar-adjacent
hours plausibly tip more generously). That means the naive metric would
make it look like drivers get a *smaller* cut during exactly the hours
they're likely receiving *more* money overall (fare split unchanged, plus
larger tips on top). This is a concrete example of why driver_pay's
definition (excludes tolls/tips, net of commission) has to be checked
before dividing by anything -- confirms the caution already flagged in
CLAUDE.md's gotchas rather than just restating it abstractly.

Bottom line for a take-rate conversation: report driver_share_of_fare_pct,
not naive_driver_share_pct -- the latter systematically understates driver
earnings and does so unevenly across hours, which would bias any
hour-of-day comparison built on it.
*/
