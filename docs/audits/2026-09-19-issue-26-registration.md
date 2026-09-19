---
title: Issue #26 Water head/leveling experiment registration
status: Current
document-kind: evidence
scope: Pre-candidate registration for automated Water head response, leveling, surface stability and positive-control measurements
canonical-for: [issue-26-water-leveling-registration]
last-reviewed: 2026-09-19
related-documents: [2026-09-10-water-leveling.md, ../systems/water-design.md, ../operations/architecture-programme.md, ../operations/architecture-programme-water-feel-addendum.md]
---

# Issue #26 Water head/leveling experiment registration

## Status

**Registration phase only. No #26 semantic candidate is admitted by this
checkpoint.**

Issue #26 was started from current `main`
`de332eaf8f4e70b25b097bed0c2e2a7b2aac0173` on
`codex/issue-26-water-leveling-2026-09-19`.

The 2026-09-18 H synthesis remains in draft PR #33 at
`f8f7dec652f0659b20a127d0a7002c09f1ebf795`. That branch is documentation/evidence
only and diverges from current main; its H conclusions are inputs to this
registration, not the implementation base. Before #26 can merge, the relevant
#33 evidence must either land on main or be reconciled without rewriting the
historical H record.

#18 compact directional history remains held. #20 sparse ballistic transfer and
#14/G-final are outside this work item.

## Experimental question

Can a bounded no-history Water mechanism materially improve deep/extended lateral
head response and settling while preserving exact mass, deterministic worker
semantics, bounded local work and the useful shallow/ledge behavior already seen
in H?

The two admitted candidate families remain separate:

1. head-scaled local drive;
2. bounded leveling horizon.

They may not be combined until each isolated candidate has been measured against
the same registered baseline and both results justify a combined arm.

## Fixed control

The initial control is the current main Water implementation:

- mass precision: current mass8 control;
- coherence: 12 ticks;
- lateral local request: floor(3 * imbalance / 4) followed by existing Water
  viscosity and transfer limits;
- same gravity/diagonal-before-lateral ordering;
- same lateral tolerance, film, adhesion, transport profile and scheduler policy;
- no compact flow history, sparse ballistic carrier, global pressure field or new
  persistent Water state;
- current presentation is held fixed for simulation A/B; authoritative metrics
  are primary.

The existing `native/bench/water_leveling.cpp` and
`tools/physics/water_leveling.py` are the starting apparatus. They already test
closed-basin conservation, signed translations, mirroring and 1/4-worker parity.
#26 extends that focused path instead of replacing it with a second solver loop.

## Deterministic run matrix

Unless a fixture-specific reason below requires a longer horizon, automated
native runs use:

- translations: `-65`, `0`, `63` applied to both axes;
- orientation: normal + mirrored;
- worker counts: 1 and 4;
- observer/debug features: off except registered counters;
- prepared capacity sufficient for the complete fixture, with post-setup
  allocations required to remain zero;
- control/candidate geometry and tick schedule byte-for-byte identical;
- timing measured around `World::tick()` only; setup, metric scans and export are
  outside timed intervals.

Coordinates serve as deterministic hash variation in the native harness. No new
random seed mechanism is introduced merely for this experiment.

Registered horizons:

| Fixture | Horizon |
|---|---:|
| shallow / medium / deep outlet family | 1,800 ticks |
| communicating pools | 4,800 ticks |
| unequal-head U-tube / communicating columns | 4,800 ticks |
| constriction / nozzle | 1,800 ticks |
| fast dump | 1,800 ticks |
| calm settling | 3,600 ticks |
| ledge sheet / shallow dribble | 1,800 ticks |

If a baseline does not cross a registered half-life/equilibrium threshold within
its horizon, record it as censored/not-reached. Do not extend only a candidate run
after seeing its result.

## Required fixture semantics

### Head-response family

Three otherwise identical closed reservoirs feed the same outlet geometry.
Only initial Water depth changes: shallow, medium and deep. Initial Water mass,
outlet width, wall geometry and measurement ROI are explicit in the harness
output. The fixture measures whether discharge responds sensibly to greater head
without changing the solver between depths.

### Communicating pools

Two basins begin connected through a fixed channel with a declared initial level
difference. Record left/right quantity, surface-height difference and its decay.

### True unequal-head U-tube

Use two vertical communicating columns with unequal initial Water heights and a
shared lower passage. Do **not** reuse the historical uniformly filled `u-vessel`
as hydrostatic evidence. The starting height difference, passage dimensions and
column ROIs are fixed in the fixture definition.

### Constriction / nozzle

A deep source drains through a fixed narrowing. Measure discharge, retained
surface slope/cliff behavior and downstream range without changing transport or
presentation policy.

### Fast dump

A bounded release creates a large transient collapse against declared wall/outlet
geometry. This is the primary authoritative wall-contact-gap and terrace stress
case.

### Calm settling

A deterministic uneven Water body settles in a closed basin. This is the primary
time-to-flat, hillnipple and terrace/shimmer case. The H target remains that the
current mass8 final state is acceptable but takes roughly 2–4 times too long;
the automated baseline must quantify the corresponding metric before a candidate
is written.

### Ledge sheet / shallow dribble

A thin Water sheet crosses a ledge into a shallow receiving region. This is a
positive control. A candidate may not claim success by simply making Water
globally smooth, inert or uniformly faster.

## Metric definitions to implement before baseline capture

The baseline harness extension must emit enough raw per-tick/per-sample data to
derive the following without changing the metric implementation between control
and candidates.

### Quantity and bulk response

- exact total Water integer mass and explicit scheduled source/sink delta;
- discharge across a fixed measurement plane per tick and cumulative discharge;
- Water centre of mass in the declared ROI;
- furthest occupied lateral range at a fixed minimum mass threshold;
- left/right communicating-pool quantity;
- free-surface height profile in a fixed ROI;
- best-fit free-surface slope versus tick;
- initial-to-current level difference for communicating fixtures;
- slope and level-difference half-life;
- time-to-flat / time-to-equilibrium;
- cliff lifetime.

A threshold crossing is latched on the first tick and never back-filled after the
fact. If later oscillation invalidates a stable-equilibrium criterion, report both
first crossing and sustained crossing.

### Authoritative surface defects

Surface extraction is derived from Water authority, not rendered pixels. For each
registered column, use the topmost Water-bearing cell plus its normalized
fractional fill to form a sub-cell surface coordinate. Empty columns are excluded
only where the fixture definition explicitly permits no Water.

From that frozen contour derive:

- hillnipple amplitude above a fixed local low-pass reference;
- hillnipple width and lifetime;
- terrace count, horizontal extent and vertical step severity;
- classification turnover per simulated second for hill/terrace shimmer;
- wall-contact gap extent/area and lifetime in geometry that requires contact.

The exact low-pass window, persistence duration, Water-presence threshold and
wall-contact ROI are part of the harness constants and must be printed in its
manifest before baseline execution. Candidate code is prohibited until those
constants and the resulting baseline are committed.

Rendered metrics remain a separate later/H layer; an authoritative pass may not
be inferred from a visually smoother frame.

### Work and timing

Record:

- visited cells;
- active blocks;
- Water transfer/probe counters where already available;
- wake/activity work where available;
- post-setup allocations;
- p50/p95/p99/max tick time;
- total tick time.

Timing is descriptive unless run on the registered source-matched host. A paired
p95 regression greater than 15% is a review flag, not by itself evidence that a
physics candidate is wrong.

## Hard rejection conditions

Any candidate is rejected for this experiment if it:

- loses or duplicates closed Water mass outside declared source/sink deltas;
- changes deterministic authoritative samples between expected 1- and 4-worker
  runs;
- performs writes outside the existing admitted bounded neighborhood without a
  separately reviewed architecture change;
- introduces permanent oscillation/crawling to satisfy a first-crossing metric;
- depends on #18 flow memory, #20 sparse transfer or a global/unbounded search;
- silently changes mass precision, coherence, presentation, transport profile,
  granular policy or fixture geometry;
- destroys the ledge/shallow control by making the flow inert or removing its
  useful local breakup solely to improve smoothness;
- hides an authoritative hill, terrace or contact gap only in presentation.

## Benefit screen before candidate acceptance

Candidate acceptance remains multi-dimensional.

At minimum:

- calm-settling and/or the deep/extended fixtures must show a material reduction
  in registered time-to-flat or slope/level-difference half-life consistent with
  the H observation that the current control is roughly 2–4 times too slow;
- communicating fixtures must improve equalization rather than merely moving the
  same error elsewhere;
- authoritative persistent hill/terrace/contact metrics must improve or remain
  within registered baseline variability;
- shallow/ledge bulk range, discharge character and activity must remain within
  the registered control envelope pending focused H review;
- exact mass, deterministic worker parity, stable equilibrium and bounded work
  must pass;
- performance/work deltas and any negative side effect must be retained.

The exact numeric control envelope and sustained-equilibrium thresholds are
frozen from the baseline-only run **before** semantic candidate code. They must be
added to this registration as a dated baseline addendum; they may not be tuned
after candidate results are visible.

## Execution order

1. Extend the focused native harness and driver with the registered fixtures,
   manifest constants and raw metrics.
2. Run and retain the current-main baseline only.
3. Add the baseline-derived numeric thresholds/control envelopes to this record.
4. Only then implement the head-scaled-local-drive arm.
5. Restore the same control and independently implement the bounded-horizon arm.
6. Run a combined arm only if both isolated results justify it and preregister
   that arm first.
7. Run focused H regression on `calm-settling`, `connected-pools`,
   `constriction` and `ledge-sheet` for any automated survivor.
8. Only after #26 disposition, repeat horizontal/diagonal directional references
   for #18 admission/no-go.

A sound negative result completes the relevant arm successfully. Historical H and
2026-09-10 Water evidence are never rewritten as if they were run on this source.
