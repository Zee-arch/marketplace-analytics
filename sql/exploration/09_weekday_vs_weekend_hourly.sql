-- Question: How does the hourly trip curve differ between weekdays and
-- weekends?
-- Source: fhvhv_2025-03.parquet
-- "Weekend" = Saturday/Sunday per dayname(pickup_datetime). Checked first
-- (not assumed): March 2025 has 21 weekday-dates vs. 10 weekend-dates, so
-- raw trip totals per hour aren't directly comparable between the two --
-- weekday totals would look inflated purely from having 2.1x more days,
-- not from different hourly behavior. Reporting AVERAGE trips per hour
-- per day-type instead, side by side in one result set.

with day_type_totals as (
    -- number of distinct calendar dates in each bucket -- the
    -- normalization denominator used below
    select
        case when dayname(pickup_datetime) in ('Saturday','Sunday') then 'weekend' else 'weekday' end as day_type,
        count(distinct cast(pickup_datetime as date)) as n_days
    from trips
    group by 1
)
select
    extract(hour from pickup_datetime) as hour_of_day,
    round(
        sum(case when dayname(pickup_datetime) not in ('Saturday','Sunday') then 1 else 0 end)
        / (select n_days from day_type_totals where day_type = 'weekday')
    ) as avg_weekday_trips,
    round(
        sum(case when dayname(pickup_datetime) in ('Saturday','Sunday') then 1 else 0 end)
        / (select n_days from day_type_totals where day_type = 'weekend')
    ) as avg_weekend_trips
from trips
group by 1
order by 1;

/*
Finding: the two curves have genuinely different shapes, not just
different levels.

Weekday: sharp double-peak commute pattern. Single highest value in the
whole table is 8am (42,031 avg trips/hour); a second, broader peak builds
through early evening; deep overnight trough at 3am (5,679) -- almost 7.4x
lower than the peak. This is the shape of people getting to and from
work.

Weekend: no morning peak -- instead, overnight hours (12am-3am) run 2.3x
to 3.2x higher than the same hours on a weekday (e.g. 3am: 17,897 weekend
vs. 5,679 weekday), consistent with nightlife rather than commuting. The
weekend's single highest hour is 8pm (38,692), not overnight or morning --
a broad evening peak rather than a sharp one.

The two curves nearly converge in the late afternoon (17:00: 36,484
weekday vs. 36,071 weekend, effectively equal) before diverging again into
very different evenings. Practical implication: any staffing/positioning
decision based on "typical hourly demand" needs the weekday/weekend split
-- a single blended curve would average away both peaks and misrepresent
both day types.
*/
