-- Staging model: 1:1 with the raw source, explicit column list (already
-- snake_case in the source CSV, unlike the TLC data -- still listed
-- explicitly rather than select * for the same reason as everywhere
-- else: a staging model should be a stable, documented contract, not
-- whatever happens to be in the source today).

select
    order_id,
    user_id,
    eval_set,
    order_number,
    order_dow,
    order_hour_of_day,
    days_since_prior_order
from {{ source('raw', 'orders') }}
