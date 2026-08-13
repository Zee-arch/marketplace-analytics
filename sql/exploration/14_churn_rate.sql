-- Question: When a user goes quiet for 30+ days, is that usually the
-- end of the relationship, or do most users come back at least once
-- more? A "churn rate" in the textbook sense (never returns, measured
-- against today) isn't computable here -- no calendar dates, and every
-- user's final captured order already happened (we're not watching
-- anyone in real time). What IS computable: of every 30+-day gap that
-- occurs anywhere in the data, how many turned out to be terminal (the
-- user's last observed order -- outcome unknown, dataset just ends
-- there) vs. recovered (the user placed at least one more order after
-- it -- proof they came back)?
-- Source: orders

with user_last_order as (
    select user_id, max(order_number) as last_order_number
    from orders
    group by 1
),
gaps_of_30_plus as (
    -- every row where the CAPPED gap hit exactly 30 -- i.e. every
    -- instance across the whole dataset of "this user had just gone
    -- 30+ days without ordering"
    select o.user_id, o.order_number, ulo.last_order_number
    from orders o
    join user_last_order ulo on o.user_id = ulo.user_id
    where o.days_since_prior_order = 30
)
select
    count(*) as total_30plus_day_gaps,
    sum(case when order_number = last_order_number then 1 else 0 end) as terminal_gaps,
    sum(case when order_number < last_order_number then 1 else 0 end) as recovered_gaps,
    round(100.0 * sum(case when order_number < last_order_number then 1 else 0 end) / count(*), 2) as pct_recovered
from gaps_of_30_plus;

/*
Finding: 369,323 instances of a 30+-day gap occur across the dataset.
Of those, 82.89% (306,137) were followed by at least one more order --
proof the user came back. Only 17.11% (63,186, exactly Q13's "at-risk"
tier, as it should be -- every user has exactly one last order) are
terminal, meaning the dataset simply ends before we can see whether
they returned.

Practical implication, worth stating plainly: a 30+ day gap is a weak
churn signal on its own -- the base rate says most users who go quiet
for a month come back. Q13's "at-risk" tier (30.6% of all users) is
better read as "currently in an open-ended gap of unknown length," not
"has churned" -- treating it as confirmed churn would overstate the
problem by roughly 5x relative to what actually predicts non-return
(63,186 confirmed-terminal vs. 369,323 total gap instances). A real
churn model for this business would need to look past a single gap
length and into pattern -- e.g. whether gaps are lengthening over a
user's own history, or whether a user has had multiple 30+ day gaps
before (repeat lapsers) rather than one -- which this query doesn't
build, but is the natural next question if this mattered operationally.
*/
