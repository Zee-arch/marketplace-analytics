-- Singular test: fct_trips is supposed to be a pure pass-through of
-- int_trips_enriched (see fct_trips.sql's comment). If someone later adds
-- a filter or a join that accidentally drops/duplicates rows, this test
-- catches it by comparing row counts -- returns a row (failing the test)
-- only if the two counts disagree.

select
    (select count(*) from {{ ref('int_trips_enriched') }}) as intermediate_count,
    (select count(*) from {{ ref('fct_trips') }}) as fct_count
where (select count(*) from {{ ref('int_trips_enriched') }})
   != (select count(*) from {{ ref('fct_trips') }})
