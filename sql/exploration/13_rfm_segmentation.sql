-- Question: How do users segment on Recency/Frequency/Monetary-proxy,
-- and what does the "at-risk" (worst recency) segment actually look like
-- on the other two dimensions?
-- Source: orders + order_products_prior
--
-- Definitions, adapted for this dataset's real constraints (see
-- CLAUDE.md for the full reasoning):
--   Recency  = days_since_prior_order on each user's most recent order.
--              NOT "days since today" (no calendar dates exist here) --
--              it's "how long was the gap leading into their last known
--              order." Bucketed into hand-defined tiers, NOT ntile(5),
--              because ~63k users (30.6%) are tied at exactly 30 (the
--              censoring cap) -- ntile() would arbitrarily split an
--              identically-valued group across quintiles, which is
--              actively misleading, not just imprecise.
--   Frequency = total order count per user. ntile(5) is fine here --
--              no comparable tie concentration.
--   Monetary  = total items purchased via order_products_prior ONLY
--              (not _train) -- keeps every user's number computed the
--              same way regardless of whether their held-out final
--              order landed in the train or test split.

with user_last_order as (
    select user_id, max(order_number) as last_order_number
    from orders
    group by 1
),
recency as (
    select o.user_id, o.days_since_prior_order as recency_days
    from orders o
    join user_last_order ulo
        on o.user_id = ulo.user_id and o.order_number = ulo.last_order_number
),
frequency as (
    select user_id, count(*) as total_orders
    from orders
    group by 1
),
monetary as (
    select o.user_id, count(*) as total_items_prior
    from order_products_prior op
    join orders o on op.order_id = o.order_id
    group by 1
),
rfm_base as (
    select
        f.user_id,
        r.recency_days,
        f.total_orders,
        m.total_items_prior
    from frequency f
    join recency r on f.user_id = r.user_id
    join monetary m on f.user_id = m.user_id
),
rfm_scored as (
    select
        *,
        case
            when recency_days = 30 then 'E: 30+ days (censored, at-risk)'
            when recency_days >= 22 then 'D: 22-29 days'
            when recency_days >= 15 then 'C: 15-21 days'
            when recency_days >= 8  then 'B: 8-14 days'
            else 'A: 0-7 days (very recent)'
        end as recency_tier,
        ntile(5) over (order by total_orders) as frequency_score,
        ntile(5) over (order by total_items_prior) as monetary_score
    from rfm_base
)
select
    recency_tier,
    count(*) as n_users,
    round(100.0 * count(*) / 206209, 2) as pct_of_users,
    round(avg(total_orders), 1) as avg_orders,
    round(avg(frequency_score), 2) as avg_frequency_score,
    round(avg(total_items_prior), 1) as avg_items_prior,
    round(avg(monetary_score), 2) as avg_monetary_score
from rfm_scored
group by 1
order by 1;

/*
Finding: recency, frequency, and monetary-proxy all move together, in
the same direction, at every tier -- this is NOT guaranteed by RFM
methodology in general (real businesses often find a "high-value but
lapsed" segment worth a targeted win-back campaign), but empirically
doesn't show up strongly here. The most-recent tier (A) averages 26.1
orders and 252.6 items; the most-lapsed tier (E) averages 9.5 orders and
82.6 items -- roughly a 3x gap on both dimensions, moving in lockstep
with recency. Practical read: users who go quiet were, on average,
already lower-engagement users beforehand, not previously-high-value
users who suddenly stopped -- which matters for how a win-back campaign
should be prioritized (there may not be a large pool of high-value
dormant users waiting to be re-activated).

The at-risk tier (E, 30+ days/censored) is also the single largest
segment at 30.64% of all 206,209 users -- nearly a third of the base
shows a 30+ day gap since their last captured order. Worth flagging
prominently rather than burying: this is the biggest addressable segment
by size, even if its average value is the lowest of the five.

Methodology note: because ~30% of users are tied at the exact same
censored recency value, a standard ntile(5) split on recency would have
been actively misleading (arbitrarily scattering an identical value
across quintiles). Hand-defined tiers avoid that -- worth remembering as
a general principle: don't reach for a quantile function without first
checking whether the underlying data has a censoring/capping issue that
breaks the assumption of continuous, mostly-distinct values.
*/
