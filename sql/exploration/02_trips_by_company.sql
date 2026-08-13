-- Question: How many trips made by each Provider in the Month of March 2025
-- Source: fhvhv_2025-03.parquet (~20M rows)

select
    case
        when hvfhs_license_num = 'HV0003' then 'Uber'
        when hvfhs_license_num = 'HV0005' then 'Lyft'
    end as provider_name,        -- the whole case...end block gets ONE alias
    count(*) as provider_count     -- count needs parens around the star
from trips                    -- always say where the rows come from
-- scoped to March 2025 (added 2026-08-13, trips now spans 6 months -- see 01)
where pickup_datetime >= '2025-03-01' and pickup_datetime < '2025-04-01'
group by 1                      -- position 1 = the case expression above, not the words it outputs
order by provider_count desc;

/*
Finding: 14,547,181 Uber trips vs. 5,989,698 Lyft trips in March 2025 —
roughly a 70.8% / 29.2% split, Uber running ~2.4x Lyft's volume. Sanity
check: the two counts sum to 20,536,879, exactly matching the total trip
count from Q1 — confirms the CASE expression isn't dropping or
double-counting any hvfhs_license_num values.

This is a snapshot of NYC HVFHV volume specifically, not Uber/Lyft's full
US or global footprint — NYC's ratio shouldn't be assumed to generalize.
Worth revisiting alongside Q3 (shared-ride behavior): if the two companies
differ this much in whether/how they report ride-pooling, it's worth
checking whether their overall product mix (e.g., premium tiers, WAV
availability) differs enough in this market to be a confound in any
company-level comparison built later in this project.
*/