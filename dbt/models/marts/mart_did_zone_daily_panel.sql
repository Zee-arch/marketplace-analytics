-- Mart: zone x day panel for the congestion-pricing difference-in-
-- differences analysis. Deliberately NOT scoped to March 2025 like the
-- other marts -- this is the one model that needs the full pre/post
-- range to be usable at all. Built from stg_trips directly (unscoped,
-- full 1:1 with source), not int_trips_enriched (March-only by design).
--
-- Grain: one row per (pickup zone, calendar date). Excludes border_exclude
-- and exclude_other zones from crz_zone_classification -- border zones
-- genuinely straddle the 60th St line (30-95% fee incidence, neither
-- clearly in nor out) and forcing them into treatment or control would
-- bias the estimate; exclude_other is non-NYC geography (Newark Airport,
-- "Outside of NYC"). treatment / outer_borough_control /
-- manhattan_north_control all kept in, so the analysis stage can run the
-- primary comparison (treatment vs. outer_borough_control, per the
-- project's original design) and a robustness check (treatment vs.
-- manhattan_north_control) from the same panel.

with daily_zone_trips as (
    select
        cast(t.pickup_datetime as date) as trip_date,
        t.pickup_location_id as location_id,
        count(*) as trip_count,
        sum(t.base_passenger_fare) as total_base_fare,
        sum(t.driver_pay) as total_driver_pay
    from {{ ref('stg_trips') }} t
    group by 1, 2
)
select
    dzt.trip_date,
    dzt.location_id,
    z.Zone as zone_name,
    z.Borough as borough,
    z.zone_group,
    dzt.trip_count,
    dzt.total_base_fare,
    dzt.total_driver_pay,

    -- treatment assignment: fixed by geography, same value in every
    -- period for a given zone (never changes based on trip_date)
    case when z.zone_group = 'treatment' then 1 else 0 end as is_treatment,

    -- post assignment: fixed by time, same value across every zone for
    -- a given date. Cutoff is the policy's actual start (2025-01-05),
    -- not a month boundary
    case when dzt.trip_date >= date '2025-01-05' then 1 else 0 end as is_post,

    -- January 2025 is a mixed month (pre-policy Jan 1-4, post-policy
    -- Jan 5-31) -- flagged so the analysis stage can decide whether to
    -- include or exclude it, rather than baking that choice in here
    case
        when dzt.trip_date >= date '2025-01-01' and dzt.trip_date < date '2025-02-01'
        then 1 else 0
    end as is_transition_month

from daily_zone_trips dzt
join {{ ref('crz_zone_classification') }} z on dzt.location_id = z.LocationID
where z.zone_group in ('treatment', 'outer_borough_control', 'manhattan_north_control')
