{{ config(tags=['delivery']) }}

-- Singular test: mart_user_rfm's monetary_proxy_items, summed across
-- every user, must equal order_products_prior's total row count exactly
-- -- every prior-order item belongs to exactly one user, counted
-- exactly once. Same sanity-check pattern as the mobility side's
-- assert_daily_summary_matches_raw_total.

select
    (select sum(monetary_proxy_items) from {{ ref('mart_user_rfm') }}) as rfm_total,
    (select count(*) from {{ ref('stg_order_products_prior') }}) as prior_total
where (select sum(monetary_proxy_items) from {{ ref('mart_user_rfm') }})
   != (select count(*) from {{ ref('stg_order_products_prior') }})
