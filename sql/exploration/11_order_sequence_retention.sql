-- Question: What share of users reach a 2nd order? A 3rd? A 10th? --
-- an order-sequence-based retention curve.
-- Source: orders.csv (Instacart Market Basket dataset, delivery vertical)
--
-- Adaptation from a textbook retention curve: this dataset has no
-- calendar dates anywhere, so "cohort" here means order-sequence, not a
-- signup month. "Retention at order N" = the share of all 206,209 users
-- who placed at least N orders.
--
-- Read the first 4 rows with real skepticism: Instacart pre-filtered
-- this public release to only include users with 4-100 total orders
-- (verified: min order count per user = 4, max = 100). That means 100%
-- of users "retain" through order 4 by construction of the dataset, not
-- because of real loyalty -- the meaningful part of this curve starts
-- at order 5.

select
    order_number,
    count(distinct user_id) as n_users_reaching,
    round(100.0 * count(distinct user_id) / (select count(distinct user_id) from orders), 2) as pct_of_all_users
from orders
group by 1
order by 1;

/*
Finding: exactly as expected, order_number 1-4 all sit at 100.0% (the
dataset's own construction floor). The real signal starts immediately
after: 88.37% of users reach a 5th order -- an 11.6-point drop the
moment the artificial floor ends, which is the first real retention
number in this dataset. From there: 53.7% reach order 10, 36.41% reach
order 15, 26.15% reach order 20, 14.88% reach order 30, down to 0.67%
(1,374 users) at order 100.

That top end is worth the same skepticism as the bottom: max order count
per user in this dataset is capped at exactly 100 (verified separately),
so the tail is likely also a collection ceiling, not proof that loyalty
behaviorally stops at 100 -- those 1,374 users may well have kept
ordering beyond what this public release captured. Read both ends of
this curve as dataset-construction artifacts; the genuinely informative
range is roughly orders 5-50, where the curve reflects real declining
engagement rather than a sampling boundary.
*/
