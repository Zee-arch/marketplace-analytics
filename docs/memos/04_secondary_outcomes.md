# Secondary DiD Outcomes — Fare, Driver Pay, Take Rate

**Scope note:** this runs the primary specification only (holiday
window excluded, outer-borough control) for each outcome — the full
sensitivity + robustness suite the volume regression got would be
disproportionate for what the project's own roadmap calls "optional
depth." If any result here looked surprising or load-bearing for a
decision, that's the trigger to go back and give it the same full
treatment.

## Results

| Outcome | Effect | 95% CI | p-value |
|---|---|---|---|
| Avg. base fare per trip | **−2.92%** | [−3.64%, −2.21%] | <0.0001 |
| Avg. driver pay per trip | **−4.43%** | [−5.13%, −3.72%] | <0.0001 |
| Driver share of fare | **−0.73 pp** | [−0.99, −0.47] | <0.0001 |

All three are on top of the already-established ~7% volume reduction
(`docs/memos/02_did_main_regression.md`) — this isn't "instead of," it's
"in addition to."

## Reading these together, not in isolation

The three numbers aren't independent facts — they're mechanically
related, and reading them together tells a more specific story than any
one alone:

**Base fare fell, which is not the same as "rides got cheaper."**
`base_passenger_fare` is specifically the fare *before* tolls, taxes, and
fees — the new CBD congestion charge is a separate line item entirely,
added on top, not netted into this number. A falling base fare alongside
a falling trip count is consistent with a specific, plausible mechanism:
fewer trips means less demand pressure on the dispatch platforms' dynamic
pricing, which would show up as *less surge pricing* and therefore a
lower average base fare — without the ride actually costing the rider
less once the congestion fee is added back in. This is a plausible
explanation, not a confirmed one — this analysis didn't directly test
trip-distance composition or surge-pricing frequency, and either could
independently move the average fare.

**Driver pay fell by more than the fare did — so the driver's share of
that (declining) fare also fell.** −4.43% vs. −2.92% isn't noise; it's
exactly the same relationship the −0.73 percentage-point take-rate shift
describes directly. In the CRZ specifically, relative to control, drivers
kept a slightly smaller slice of a shrinking fare after the policy.

**What this doesn't establish:** *why* the split moved is a platform
pricing-algorithm question this analysis has no visibility into — it
could reflect how dispatch platforms adjust driver compensation formulas
differently than fare-setting algorithms when demand drops, or something
else entirely internal to Uber/Lyft's pricing systems. The DiD design
identifies that the shift happened and roughly how large it is; it
doesn't identify the mechanism, and asserting one without evidence would
overclaim past what the data actually shows.

## Practical read

Congestion pricing is associated with a smaller marketplace in the CRZ
on every dimension measured here — fewer trips, lower average fares, and
lower driver earnings per trip — with drivers absorbing a
disproportionate share of that contraction relative to the platform's
own margin. For a growth/marketplace-economics audience, the driver-pay
finding is arguably the more decision-relevant one of the three: a ~4.4%
per-trip earnings decline, compounding on a ~7% volume decline, is a
meaningfully larger hit to total driver earnings in the zone than either
number suggests on its own (a further multiplicative effect worth a
follow-up calculation if this mattered for a real decision).

## Reproducing this

```bash
python analysis/did_secondary_outcomes.py
```
