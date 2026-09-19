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

## Post-completion status

This document is the immutable preregistration for apparatus v1 and the historical
#26 experiment. Post-merge review did not invalidate the two candidate rejections,
but found defects that make v1 unsuitable for future successor acceptance without
correction.

See [the post-merge review](2026-09-19-issue-26-post-merge-review.md) and
[#49](https://github.com/techrote/cybersand/issues/49).

Where this registration says `not-reached` should be censored, note that the
implemented v1 reducer instead used numeric zero; where it specifies empty columns
are excluded only when permitted, the implemented surface extractor excluded all
dry columns. Those are implementation deviations retained as historical findings,
not silently corrected in this registration.

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


## Baseline addendum — frozen 2026-09-19

The baseline-only campaign ran successfully before any #26 semantic candidate was
introduced.

Identity and retained evidence:

- branch head: \`332fac20f726f67c487f7b25b001ced5c8259e0f\`;
- current-main base: \`de332eaf8f4e70b25b097bed0c2e2a7b2aac0173\`;
- Actions checkout/merge head recorded by the runner:
  \`bf3b6d53a0f534df5edd66d264c6f3bf1a4378e3\`;
- source-set SHA-256:
  \`7762db47cbbce9e890d50e218e656953dfc18e1ef43127f2cf5b90ae1c4d13d4\`;
- workflow run: \`35412803078\`;
- artifact ID: \`10574760981\`;
- artifact ZIP SHA-256:
  \`0466c6057b45dcdeb28e87a81682307fc2d8e23fc5932b747ab1dea2343a77c7\`;
- raw \`results.json\` SHA-256:
  \`9a2871f983d99daedadc19bc5e1f355caa739bc670eb72e16a2c3344c2f0a0e5\`;
- \`summary.json\` SHA-256:
  \`0fac3399154a6ebac692fe33e48eb2e604083baca6663783d011591ba5f98a4f\`;
- machine-readable frozen thresholds:
  \`issue-26-2026-09-19/baseline-reference.json\`.

All 108 cases passed exact sampled closed-Water accounting, exact authoritative
1/4-worker sample parity and zero post-setup owned allocations.

### Baseline findings

The baseline makes the missing head response concrete rather than merely visual:

| Fixture | Registered baseline result |
|---|---:|
| head-shallow receive mass @300 | 21,104 median |
| head-medium receive mass @300 | 27,223 median |
| head-deep receive mass @300 | 27,223 median |
| communicating-pools final level difference | 16.000 cells median |
| unequal-head U-tube final level difference | 24.000 cells median |
| constriction receive mass @300 | 15,454.5 median |
| calm-settling sustained half-life | 480 ticks |
| calm-settling sustained <=1-cell spread | 2,670 ticks |
| fast-dump final surface spread | 3.392 cells median |
| ledge-sheet receive mass @300 | 9,453.5 median |

The medium and deep outlet fixtures producing the same early discharge is direct
evidence that greater column depth stops contributing useful drive once the local
outlet state is otherwise similar. More importantly, both communicating fixtures
perform only a tiny initial rearrangement and then become quiescent while retaining
approximately 16- and 24-cell surface-height differences for the full 4,800-tick
horizon. This is a simulation-state failure, not a presentation artifact.

Calm settling does eventually become flat under the registered metric, but requires
a median 2,670 ticks for a sustained <=1-cell spread, consistent with the H report
that the final mass8 state is acceptable but arrives much too slowly.

### Frozen automated survival screen

These are **pre-candidate** engineering screens. Passing them does not replace the
required focused H review.

Hard requirements for every arm:

- sampled closed-Water accounting remains exact;
- 1/4-worker authoritative traces remain exact;
- post-setup owned allocations remain zero;
- no unregistered semantic/presentation/profile change is introduced.

An isolated candidate must:

1. reduce calm-settling sustained half-life to <=360 ticks;
2. reduce calm-settling sustained <=1-cell time to <=1,980 ticks;
3. pass at least two additional primary benefit gates:
   - head-deep receive mass @300 >=34,029 **and** deep/medium ratio >=1.10;
   - communicating-pools final level difference <=12.000 cells;
   - unequal-head U-tube final level difference <=18.000 cells;
   - constriction receive mass @300 >=19,319;
4. preserve the ledge-sheet control:
   - receive mass @300 between 6,617 and 14,180;
   - surface-classification turnover >=8 sample transitions;
5. keep fast-dump final spread <=3.731 cells and maximum registered wall-gap count
   <=1.

A median p95 tick-cost ratio above 1.15 versus the frozen control is a mandatory
performance review flag, not an automatic semantic rejection.

The values above were derived only from the frozen baseline and the pre-existing H
target before candidate results existed. They must not be loosened after seeing a
candidate.


## Bounded-horizon arm registration — before implementation

The second isolated candidate is a **radius-2 same-row lookahead**, not a pressure
field and not a persistent flow/history carrier.

For each otherwise eligible Water lateral update:

- the existing adjacent baseline target remains the only write destination;
- the candidate may inspect the next cell in the same direction, exactly two
  cells from the source, which is within the already declared maximum rule radius;
- both the adjacent target and lookahead cell must be Empty/Water, so the probe
  cannot see through or jump a hard barrier;
- when the lookahead Water mass is lower than the source by more than the existing
  tolerance, the requested adjacent transfer may be strengthened from the same
  bounded imbalance formula;
- no direct radius-2 write, upward transfer, recursive push, new state, new queue,
  column scan, pressure prepass or unbounded search is admitted;
- baseline semantics, candidate thresholds and all fixture geometry remain frozen.

This arm answers a deliberately narrow question: is the main deficit substantially
a one-cell spatial-horizon problem? If it cannot materially improve the registered
deep/communicating cases, that negative result argues against continuing to tune
pure same-row local equalization and for an explicitly scoped larger head/pressure
carrier question instead.
