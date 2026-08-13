# Event Study — NYC Congestion Pricing DiD

**Finding:** the effect isn't a single clean jump at the policy date — it
builds over roughly 7 weeks into a persistent, statistically significant
~9–12% reduction in CRZ trip volume that holds through the end of the
observed data (late March 2025). The chart also visually confirms the
holiday-season confound identified in the parallel trends memo, rather
than just asserting it happened.

## Why an event study, beyond the main regression

The main regression collapses the whole comparison into one number
(−7.37% primary estimate). That can't distinguish "the policy caused a
real change" from "this was already drifting before the policy" — an
event study estimates a separate treatment-control gap for every week,
which makes both readable directly off a chart.

## Design notes

- Same two-way fixed effects panel as the main regression
  (`log(trip_count) ~ zone FE + day FE + treatment×week dummies`),
  clustered SEs by zone.
- **Reference week is NOT the conventional "week right before
  treatment."** Checked directly: that week (Dec 29–Jan 4) sits inside
  the holiday-distorted window itself, so using it as the baseline would
  make every other coefficient relative to a genuinely unusual point.
  Used the earliest available clean week (13 weeks before the policy,
  early October) instead.
- Built the treatment×week dummy matrix explicitly with pandas rather
  than through `linearmodels`' formula-string categorical interaction —
  the formula approach ran without erroring, but produced identical
  standard errors across all 25 coefficients (checked and confirmed not
  a real result) and different point estimates than the explicit
  version. Trusting the version that's verifiable column-by-column.
- Two partial boundary weeks (5 of 7 days, and 2 of 7 days) dropped for
  the same reason as the sparse-zone filter in the main regression —
  not enough data to estimate cleanly.

## What the chart shows

**Clean pre-period (13 to 7 weeks before the policy):** coefficients
hover close to zero, small fluctuations, several confidence intervals
crossing zero. This is what parallel trends is supposed to look like —
directly visible now, not just implied by a summary statistic.

**Holiday window (shaded, 6 weeks before the policy through 1 week
before):** dramatic swings — down to −0.22, up to +0.09, crashing to
−0.36 the week of Christmas, partially recovering by the week before the
policy. This is the same confound from the parallel-trends memo, now
visible directly rather than described secondhand.

**Post-policy (week 0 onward):** an immediate dip at week 0 (−0.10),
then six noisier weeks through early February where the effect is
smaller and some confidence intervals cross zero, then **from week 7
onward (late February through March), a clear, consistent, statistically
significant effect of roughly −9% to −12% that holds for the rest of the
observed data.**

## Reading the dynamic honestly

This isn't the idealized "instant, constant jump" some textbook DiD
examples show, and that's worth reporting as-is rather than smoothing
over. A plausible read: an initial reaction at the policy's start, a
few weeks of noisier adjustment as riders and drivers work out new
habits, then a more decisive, settled behavioral shift by late
February. That's a substantively reasonable dynamic for a pricing policy
— habit change taking a few weeks rather than happening instantly — not
a sign the identification strategy failed.

**Independent cross-check worth naming:** the late-February/March window
where this event study finds a robust ~9-12% effect overlaps with Q10's
original finding (`sql/exploration/10_rolling_7day_average.sql`, from
early in this project, using only March 2025 data with no causal
framework at all) — a genuine ~7.9% decline in daily trip volume across
March, smoothed for weekly seasonality. Two completely different
analyses, different methods, different data scope, landing on a
similar-sized effect in the same window is a meaningfully stronger signal
than either alone.

## Reproducing this

```bash
python analysis/did_event_study.py
```
