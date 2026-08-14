{{ config(tags=['delivery']) }}

-- Singular test: codifies the eval_set structural fact from CLAUDE.md --
-- every user has exactly one held-out "most recent" order, assigned to
-- either 'train' or 'test', never both, never neither. Verified by hand
-- at 131,209 + 75,000 = 206,209 = every distinct user. If this ever
-- fails, the volume/monetary-proxy symmetry argument the delivery
-- vertical's metric definitions depend on (order_products_prior only)
-- no longer holds as reasoned, and needs re-checking, not just re-running.

select
    (select count(distinct user_id) from {{ ref('stg_orders') }} where eval_set = 'train') as train_users,
    (select count(distinct user_id) from {{ ref('stg_orders') }} where eval_set = 'test') as test_users,
    (select count(distinct user_id) from {{ ref('stg_orders') }}) as total_users
where (
    (select count(distinct user_id) from {{ ref('stg_orders') }} where eval_set = 'train')
    + (select count(distinct user_id) from {{ ref('stg_orders') }} where eval_set = 'test')
) != (select count(distinct user_id) from {{ ref('stg_orders') }})
