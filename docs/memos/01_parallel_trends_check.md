# Parallel Trends Check — NYC Congestion Pricing DiD

**Status:** Pre-trend assumption supported, conditional on excluding an
identified holiday-season confound. Proceeding to the main DiD regression.

## The question

Difference-in-differences identifies a policy's effect by comparing how
treatment and control groups change from before to after the policy —
but that's only valid if the two groups would have moved *together* in
the absence of the policy. This memo checks whether that holds for
treatment (39 CRZ zones, ≥95% congestion-fee incidence) vs. control (193
outer-borough zones), using Oct 1, 2024 – Jan 4, 2025 as the strictly
pre-policy window.

## First pass: a naive linear trend test fails

Regressing `avg_trips_per_zone ~ is_treatment * days_since_start` on the
full pre-period found a statistically significant interaction term
(coefficient −7.93 trips/zone/day, p=0.019) — on its face, evidence that
treatment zones were already declining relative to control *before* the
policy, which would undermine attributing any post-policy gap to the
policy itself.

## Why the naive test is misleading here

The chart (`analysis/output/parallel_trends.png`) makes the reason
obvious: the pre-period spans Thanksgiving through New Year's, and
treatment zones (Manhattan's commercial core — offices, tourists,
holiday retail) swing far more dramatically across that window than
residential outer-borough zones do. Treatment dips to ~65% of its own
pre-period baseline around Christmas and peaks near 123% in mid-December;
control's swing over the same window is much shallower (~92%–110%). A
straight line fit through a window containing one extreme, one-off
seasonal event will read differential *sensitivity to that event* as a
differential *trend* — a different and much less damaging problem, since
it doesn't imply the two groups were on diverging long-run paths.

## Second pass: confirms the holiday-swing explanation, on two independent controls

Re-ran the same test excluding the holiday window (Nov 20 – Jan 2), and
separately against a second, independent control group
(`manhattan_north_control` — same borough, outside the CRZ) as a
robustness check:

| Control group | Full pre-period | Holidays excluded |
|---|---|---|
| Outer boroughs (primary) | coef −7.93, **p=0.019** | coef −1.25, p=0.80 |
| Manhattan-north (robustness) | coef −6.95, **p=0.042** | coef −1.43, p=0.77 |

Both comparisons tell the same story: the apparent pre-trend disappears
almost entirely once the holiday window is removed, and it disappears
against *two different control groups independently*. That consistency
is the actual evidence here — a single non-significant result could be
underpowered noise; two, from otherwise-unrelated comparisons, agreeing
after the same adjustment is a much stronger signal that the holiday
explanation is correct, not a post-hoc rationalization.

## Conclusion and what it means for the main regression

Parallel trends is reasonably supported for the Oct–Dec 2024 pre-period,
**conditional on the holiday season being treated as a known confound**,
not ignored. Practical implications for the DiD regression that follows:

- The main specification should include controls that absorb the
  holiday swing (e.g., week fixed effects, or an explicit holiday-period
  indicator) rather than relying on a bare linear time trend.
- This isn't a reason to abandon the outer-borough comparison — it's a
  reason to specify the regression correctly. Reporting a result from a
  design known to have this confound, without addressing it, would be
  the actual methodological error.
- Keeping `manhattan_north_control` as a standing robustness check
  throughout the rest of this analysis, not just here, given how
  cleanly it corroborated the primary control's finding.

## Reproducing this

```bash
python analysis/parallel_trends.py              # chart + naive test
python analysis/parallel_trends_robustness.py    # holiday-excluded + robustness checks
```
