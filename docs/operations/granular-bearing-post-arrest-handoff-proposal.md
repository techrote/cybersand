---
title: Granular bearing post-arrest handoff proposal
status: Current
document-kind: design
scope: Original finite-observation proposal and authorized successor disposition; no response change or production selection
canonical-for: [granular-bearing-post-arrest-follow-up-proposal]
last-reviewed: 2026-11-01
related-documents: [granular-bearing-pre-overlap-investigation.md, development-claims-remediation-programme.md, ../audits/2026-11-01-granular-bearing-candidate-discrimination.md]
---

# Granular bearing post-arrest handoff proposal

## Authorized successor checkpoint — 2026-11-01

**Measured on the isolated successor branch:** Stage A's literal copied-value
oracle closes exactly after float32 accounting over42 retained Y1 samples.
Separately preregistered Stage B passes all four exact600-sample prefix gates.
Y1 speed90 first reaches zero at640, has brief recurrences at641/643/693/705,
then begins60-sample sustained clearance at706, confirmed765, with no recurrence
through1799. Y1 speed30 prevents contact throughout1800. The
[successor audit](../audits/2026-11-01-y1-post-arrest-clearance.md) records source
custody, all controls and remaining velocity/correction activity. Y1 exchanges
deeper initial penetration for finite withdrawal latency in this fixture;
acceptable rest and production suitability are not established. The proposal
below is the preserved historical #341 rationale, before successor execution.

**Historical proposal at PR #341:** this was a proposed next question under REM-004 / issue #83, after the
[candidate audit](../audits/2026-11-01-granular-bearing-candidate-discrimination.md).
At that checkpoint it was not an executed experiment, an approved production model, or permission
to combine Y1 and A2. The measurement guide owns the programme and disposition;
this page specifies a possible finite follow-up that still needs registration.

## Question and measured trigger

Does stronger braking reach acceptable rest and clearance, or exchange short
deep intrusion for prolonged correction-associated withdrawal?

Frozen source `39d91671c1d0bb7978a29460f14419cd1b37a252` shows Y1 speed90
remaining overlapped at sample 599, despite smaller peak entry and overlap.
This is not an observed static equilibrium. Each 100-sample block from 100 through 599
has net centre translation `-0.4669189453125 px`. Across 300..599, actual Rapier
position increments total `+0.97503662109375 px`, while actual correction
translations total `-2.37579345703125 px`, closing the net `-1.4007568359375 px`.
Incoming vertical velocity alternates near `.006344288` and `1.528962493`;
outgoing velocity alternates near zero and `-1.528962493`. Pre-ejection overlap
is6 at sample 300 and1 at 599; it ranges from 1 to 7 and remains positive throughout.
These endpoint values do not imply monotonic clearance.

The existing application owner applies positional correction, zeroes the
opposing velocity component, and then applies the cellular impulse. See
[the bridge](../../godot/scripts/rapier_physics_bridge.gd) and the audit's copied
API-boundary channels. This order explains the recorded step-pair accounting;
it is not, by itself, proof of a defect. The correction currently contributes
to upward clearance. Removing or reordering it cannot be assumed beneficial.
The600-sample observation neither establishes eventual clearance nor permits a
clearing-time extrapolation.

## Smallest proposed finite experiment

1. Freeze the successor source and register all definitions before execution.
   First reproduce the recorded Y1 step-pair from copied input, correction,
   velocity-zeroing and impulse values. A literal accounting oracle must match
   the observed API boundaries within the already established float tolerances.
   It must not mutate a live World or pretend to replay the whole coupled scene.
2. Retain B0 and Y1 only, with the coefficients and all response/admission laws
   unchanged. Use speed90 as the unresolved-tail case and speed30 as the positive
   control. Preserve the current 32x48 Sand bank,8x14 mass-one body, `.08 rad`
   initial rotation, zero initial spin,2px clearance, one worker and fixed 1/60
   step. Set initial velocity once.
3. Preregister a fixed 1800-sample observation rather than running until a desired
   outcome. Require the initial 600-sample trajectory to reproduce the retained
   source-matched prefix before interpreting the extension. Register trace/event
   bounds explicitly; the current 600-sample runner must not silently accept a
   longer run. Preserve the per-segment pending/stream limits and require zero loss.
4. Register first sustained clearance as at least 60 consecutive samples with
   zero post-ejection endpoint overlap and zero post-tick overlap at packed pose.
   Separately report last300 centre span/drift and vertical-speed distribution,
   using the existing settling limits as proposed controls. Record first-clearance
   time, recurrence, residual overlap at 1800 and censoring. These proposed values
   must be confirmed in the future preregistration, before its results exist.
   Separate prevented contact from clearance after an observed overlap: a
   never-overlapped positive control is not a censored clearance failure.
5. Reuse existing support, correction eligibility, requested/applied correction,
   velocity-zeroing, accepted impulse, bearing limiter and before/after body-state
   channels. Close position and momentum accounting over each step-pair. Keep
   excavation release and the relevant unchanged source/control identities.
   No extra packing, Rapier step, support owner or runtime response is needed.

## Interpretation fixed before any future run

Clearance by the fixed horizon would quantify a latency tradeoff; it would not
erase the existing 600-sample contact failures or confer gameplay acceptance.
Continued motion with unresolved overlap is censored clearance, not a static
jam. A stable nonzero-overlap plateau would support a different account, provided
the registered drift/velocity criteria are actually met. Only after this account
is resolved should a separately registered correction/contact-geometry candidate
be considered.

No coefficient tuning, larger lookahead, Y1+A2 arm, wider ejection search, longer
push chains, raised global bearing cap or broad compaction belongs to this
proposal. No observed result here reverses PR #338's finite-family rearrangement
NO-GO. REM-004 still owns broader geometry/material coverage and explicit owner
gameplay acceptance; an AI technical review supplies no human approval.
