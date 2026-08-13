-- Question: What share of trips were shared rides, by company — split into
-- request rate (rider asked for pooling), match rate (rider actually got
-- paired), and match efficiency (of those who asked, how many got paired)?
-- Source: fhvhv_2025-03.parquet (~20M rows)

select
    case
        when hvfhs_license_num = 'HV0003' then 'Uber'
        when hvfhs_license_num = 'HV0005' then 'Lyft'
    end as provider_name,
    sum(case when shared_request_flag = 'Y' then 1 else 0 end) as requested_count,
    sum(case when shared_match_flag = 'Y' then 1 else 0 end) as matched_count,
    count(*) as total_trips,
    cast(requested_count as double) / total_trips as request_rate,
    cast(matched_count as double) / total_trips as match_rate,
    cast(matched_count as double) / nullif(requested_count, 0) as match_efficiency
from trips
-- scoped to March 2025 (added 2026-08-13, trips now spans 6 months -- see 01)
where pickup_datetime >= '2025-03-01' and pickup_datetime < '2025-04-01'
group by 1;

/*
Finding:
  Uber — 3.9% of trips requested pooling, 2.1% were actually matched,
  52.3% match efficiency (of riders who asked to share, just over half
  actually got paired with another rider).
  Lyft — 0% requested, but 1,129 trips (0.02%) still show matched='Y'.
  match_efficiency is NULL for Lyft (nullif guards the 0/0 case) —
  correctly undefined, not zero.

Why the Lyft numbers look broken but aren't a bug: Lyft discontinued its
shared-ride product entirely in May 2023, while Uber kept running (and
later relaunched) theirs as UberX Share [Spokesman-Review, May 2023;
Human Transit, May 2023]. By March 2025, no Lyft rider could request
sharing because the feature didn't exist in the product — hence 0
requests. The 1,129 matched='Y' rows are very likely a legacy data
artifact (a field that predates the product's discontinuation and never
stopped being populated by the pipeline) rather than 1,129 real pooled
Lyft rides in a product that no longer offers pooling. Flagging this as
an open question rather than asserting it confidently — it would need a
follow-up check (e.g., are all 1,129 clustered in a specific
dispatching_base_num, suggesting a legacy code path) to confirm.

Business implication: any company-level comparison of "shared ride
adoption" for this period isn't actually comparing two companies' pooling
performance — it's comparing a company that has the product to one that
doesn't. Uber's numbers are the only ones meaningful here; Lyft's aren't
zero because pooling failed, they're zero because pooling wasn't offered.
*/