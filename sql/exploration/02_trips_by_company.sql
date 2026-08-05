-- Question: How many trips made by each Provider in the Month of March 2025
-- Source: fhvhv_2025-03.parquet (~20M rows)

select
    case
        when hvfhs_license_num = 'HV0003' then 'Uber'
        when hvfhs_license_num = 'HV0005' then 'Lyft'
    end as provider_name,        -- the whole case...end block gets ONE alias
    count(*) as provider_count     -- count needs parens around the star
from trips                    -- always say where the rows come from
group by 1                      -- position 1 = the case expression above, not the words it outputs
order by provider_count desc;

/* Roughly 70.8% Uber / 29.2% Lyft — Uber running about 2.4x Lyft's volume in NYC for this month. */