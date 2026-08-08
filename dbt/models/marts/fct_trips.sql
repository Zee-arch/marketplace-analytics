-- Mart: the trip-grain fact table -- the actual query surface for BI
-- tools and future ad-hoc questions, as opposed to int_trips_enriched
-- (intermediate, plumbing, not meant to be queried directly).
--
-- This is a deliberate pass-through, not a shortcut: the enrichment
-- already happened once in int_trips_enriched, so there's nothing left
-- to add here except promoting it to the mart layer and materializing
-- it as a TABLE (see dbt_project.yml) instead of a view, so BI queries
-- against 20M+ rows don't recompute the zone joins and CASE statements
-- on every single query.

select * from {{ ref('int_trips_enriched') }}
