---
title: Issue 26 Water leveling experiment
status: Current
document-kind: runbook
scope: Preregistered characterization and bounded candidate campaign for sluggish deep-Water leveling, free-surface cliffs, terraces, hillnipple and contact gaps
canonical-for: [issue-26-water-leveling-experiment]
last-reviewed: 2026-09-19
related-documents: [architecture-programme.md, architecture-programme-water-feel-addendum.md, water-feel-lab-experiment.md, ../systems/water-design.md, ../systems/material-appearance-and-rendering.md, ../reference/validation-evidence.md]
---

# Issue 26 Water leveling experiment

## Registration boundary

Recorded September 19, 2026 before any issue #26 Water candidate semantics.

The frozen source control is `781a2d7cb5d5a66bf1cff8fc6654e0ab708e419c`
on `main`. The isolated research branch is
`codex/issue-26-water-leveling`. PR #33 at
`f8f7dec652f0659b20a127d0a7002c09f1ebf795` is H-gate evidence only and is
not assumed merged. PR #25 is independent H capture/apparatus work and is not
modified here. Issue #18 remains open and implementation-held.

Primary Water policy is exactly mass8/coherence12,
`WaterExperimentPolicy{8, 12}`, current normalized rest policy, Baseline
transport profile, current adhesion, phased in-place backend, rule radius 2,
chunk/activity/core geometry 128/32/64 and the current source ordering. No
precision campaign is admitted by this registration.

This document freezes fixtures, observations, reductions, horizons and rejection
rules before candidate A or B is written. Baseline evidence must be retained and
reviewed first. A later correction to an invalid harness is a new explicitly
versioned registration; failed data are retained and never silently replaced.

## Source mechanism under test

Current `World::update_water()` applies gravity/down-diagonal work first and,
after coherence/adhesion/cadence gates, attempts same-row leveling against the
immediate left/right neighbour. The request is approximately three quarters of
the positive local mass imbalance, followed by Water lateral-viscosity policy.

There is no explicit column-depth/head term and no bounded free-surface lookahead.

A more restrictive mechanism fact matters for this campaign: the current transfer
destination is capped by destination capacity. Two adjacent full Water cells have
zero destination capacity, so multiplying the existing same-row request alone
cannot propagate differential head through a saturated chain. This is a source
inspection hypothesis to test, not permission to add a general pressure solver.

## Experimental invariants

Every semantic arm keeps these fixed unless this document names the change:

- exact integer Water accounting; all registered fixtures have Water source=sink=0;
- current material/reaction/granular policy, including #10/#13 protected behavior;
- current gravity/down/diagonal ordering and coherence/adhesion semantics;
- no persistent direction/strength/age state and no #18 compact history;
- no #20 sparse ballistic transfer;
- no general pressure field, Navier-Stokes solver or universal velocity field;
- bounded reads/writes compatible with declared scheduler geometry;
- immutable snapshot ownership, failed-world quarantine and pause/re-entry rules;
- fixed four-level Water presentation for rendered comparisons;
- one candidate family changed at a time.

The observer must be neutral. For each canonical control fixture, diagnostics-off
and diagnostics-on runs must have identical tick-indexed authoritative state
fingerprints. Worker-1 and worker-4 runs must match where the existing phased
contract expects parity.

## Deterministic placements and run identity

The native World has no separate simulation RNG seed; coordinate and tick identity
feed deterministic ordering. The registered external seed is therefore `0`.
Coordinate sensitivity is exercised by five placements inherited from the state
precision campaign:

| placement | x shift | y shift | mirror |
|---|---:|---:|---:|
| P0 | 0 | 0 | no |
| P1 | -129 | 0 | no |
| P2 | 127 | 1 | yes |
| P3 | -257 | 1 | yes |
| P4 | 65 | 0 | no |

P0 is the canonical metric/render placement. P0-P4 are conservation,
repeatability, seam-sensitivity and worker-parity placements. Mirroring is around
the fixture's declared local x extent before translation.

All runs record source SHA, executable SHA-256, compiler identity, platform,
fixture/version, placement, worker count, policy identity, observer state, tick
horizon, exit status, raw-output SHA-256 and reduction-tool SHA-256.

## Common quantity and surface definitions

Let `M=255` for the registered mass8 control. A Water cell contributes its exact
integer `liquid_mass`. Empty and non-Water cells contribute zero.

For a fixture-defined column ROI, exact column quantity is

`Q_x(t) = sum_y mass(x,y,t)`.

Two ROI roles are distinct. A **leveling ROI** includes every registered basin
column, with a dry column contributing `Q_x=0`; this prevents an initially
compact rectangular mound from being misclassified as flat merely because all
currently wet columns have the same depth. A **surface-defect ROI** follows only
the currently wet contour and is used for hill/terrace morphology.

For a flat-bed ROI whose registered bed datum is `b_x`, authoritative
cell-equivalent free-surface elevation is

`H_x(t) = b_x - Q_x(t)/M`

with screen y increasing downwards. In a leveling ROI this formula also defines
the dry-column zero-depth datum `H_x=b_x`. Reducers retain integer `Q_x`;
division is only for reporting. Fixtures with non-flat geometry define separate
same-datum surface ROIs rather than pretending a wall/ledge is a continuous bed.

A column is wet when `Q_x>0`. Lateral range is rightmost wet x minus leftmost
wet x. Exact lateral centre-of-mass numerator is
`sum_x x*Q_x`; reducers report that numerator and the rational value over total
Water quantity.

### Global and local slope

For each registered surface ROI, global slope is the ordinary least-squares line
fit of `H_x` against x over all wet columns in that ROI. Report signed slope,
absolute slope and angle `atan(abs(slope))`.

Local slope uses every contiguous 9-column window in a leveling ROI and the same
OLS fit; surface-defect diagnostics additionally report wet-only local windows.
Report maximum absolute local slope. This prevents a symmetric mound from
disappearing behind a near-zero whole-pool slope.

The primary slope half-life uses the maximum absolute 9-column leveling slope:
it is the first tick at which that value is at most half its tick-0 value and
remains at or below that bound for 60 consecutive ticks. Global OLS slope and,
where its tick-0 magnitude is nonzero, global-slope half-life are retained as
secondary diagnostics. If a half-life is not reached, report it right-censored
at the horizon.

### Communicating level difference

Each communicating fixture declares equal-width left/right arm ROIs. Arm level is
mean `Q_x/M`. Level difference is the absolute difference between the two means.
Half-life uses the same 60-tick persistence rule. Equilibrium target is the exact
quantity-conserving mean implied by the registered geometry.

### Time-to-flat and equilibrium

A flat-bed leveling ROI is *registered flat* when all of these hold for 120
consecutive ticks:

1. max-min `Q_x <= M` across every registered leveling column, including dry
   columns as zero quantity;
2. maximum 9-column local absolute slope over the leveling ROI <= 1/16 cell per
   column;
3. no leveling edge, including a wet/dry edge inside that ROI, exceeds one
   cell-equivalent between adjacent columns;
4. total Water quantity equals initial quantity exactly.

Time-to-flat is the first tick of that 120-tick window. A communicating fixture
uses its explicit level-difference threshold of <= 1/2 cell-equivalent in
addition to the above local-surface conditions.

The H statement that calm-settling feels roughly 2-4 times too slow is retained
as a human target band. Once baseline `T_flat` is measured, a candidate ratio
of about 0.25-0.50 is the intended H speed band, not an automatic numerical
winner.

### Cliff lifetime

Two cliff ledgers are retained. An **internal surface cliff** exists at edge
x/x+1 when both columns are wet and `abs(Q_x-Q_(x+1)) > M`. A **leveling
cliff** applies the same threshold to every adjacent pair in the registered
leveling ROI, including a wet/dry boundary. Lifetime is the longest consecutive
run of each edge condition. Report maxima and total edge-ticks separately.

### Hillnipple

For each eligible x, fit an affine baseline to wet support columns in
`[x-12,x-3] U [x+3,x+12]`, clipping to the ROI and requiring at least eight
support columns with at least three on each available side when both sides
exist. The fitted value at x is the local baseline. Positive residual is
`R_x = H_baseline(x)-H_x` in upward cell-equivalents.

Hill amplitude is max positive residual. Hill width is the contiguous run around
the peak with residual >= 1/4 cell. Hill lifetime counts consecutive ticks with
amplitude >= 1/2 cell. This side-band fit deliberately excludes the central
five columns so a narrow mound does not define its own baseline; edge cases use
the clipped support rule rather than a fixed centered smoothing window.

### Terraces and shimmer

Quantize only wet surface-defect columns for terrace classification, never for
Water accounting. Quarter-cell classification is deterministic nearest-half-up:
`T_x = floor(4*H_x + 1/2)/4`.

A terrace is a maximal contiguous run of at least three wet columns with equal
`T_x`. Record count, total horizontal extent, largest extent and the largest
quarter-cell step to an adjacent terrace. A severe terrace has extent >= 6 cells
and adjacent step >= 1/2 cell.

Terrace lifetime is the longest consecutive severe-terrace run. Contour shimmer
is the symmetric-difference count of terrace edge positions between consecutive
ticks, divided by simulated seconds at 60 completed ticks/s. Report both total
turnover and turnover while total authoritative quantity is unchanged.

### Wall-contact gap

Each applicable fixture registers a wall-contact column and vertical interval.
After Water has first touched that wall-contact interval, find the topmost Water
row in the fixture-defined local neighbourhood. A gap cell is an Empty cell in
the contact column between that top row and the registered bed that is vertically
inside the wetted envelope. Report gap area, maximum contiguous vertical extent
and lifetime. Air above the wetted envelope is not a gap.

Rendered contact gap is measured separately from fixed-presentation captures.

## Fixture version WL26-v1

All coordinates below are local before placement/mirroring. Walls are
`Material::Wall`; Water is full mass M with state-b 0 unless a fixture says
otherwise. Construction is completed before tick 0. World reservation/simulation
region includes the entire fixture plus a 64-cell margin.

### R8 / R24 / R40 — identical-outlet reservoirs

Local extent x=0..159, y=0..79. Floor y=72, side walls x=0 and x=159.
Divider wall x=48, y=24..71 except outlet y=68..71. Left reservoir interior is
x=4..47. Right measurement basin is x=49..155.

Fill left reservoir from y=71 upward to depths 8, 24 or 40 cells respectively.
The outlet geometry is bit-identical across all three fixtures.

Primary measurements: downstream quantity x=49..155; early discharge at ticks
30,60,120,240; discharge-rate ratios versus registered initial depth; COM/range;
upstream surface slope; work/events; exact quantity.

### CP16 — communicating pools

Extent x=0..127, floor y=72, side walls x=0/127. Divider x=64, y=24..71 except
connection y=68..71. Equal arm ROIs are x=8..55 and x=72..119.

Fill the left arm to depth 32 and right arm to depth 16. The initial mean level
difference is exactly 16 cells. Primary measurements are arm level difference,
half-life, local/global surface slope and time-to-equilibrium.

### UT96-48 — true unequal-head U-tube

Extent x=0..127, y=0..119. Bottom wall y=116, x=35..92.
Left arm interior x=36..43; right arm interior x=84..91.
Arm side walls are x=35/44 and x=83/92 above the connector. The connector
interior is x=36..91, y=108..115. Wall y=107, x=44..83 closes the space between
arms above the connector while leaving both arms open.

Fill connector x=36..91,y=108..115. Fill left arm x=36..43,y=20..107 and right
arm x=84..91,y=68..107. Initial column heads are exactly 96 and 48 full cells;
the exact equal-head target is 72.

All connector cells begin full. Thus the current immediate same-row rule cannot
create destination capacity merely by multiplying its request. Any change in
head difference is retained as mechanism evidence. This fixture is not the
uniformly-filled H `u-vessel`.

### CN — constriction/nozzle

Extent x=0..143, floor y=72, side walls x=0/143. Left chamber x=4..63, right
chamber x=80..139. A short nozzle occupies x=64..79 with walls y=66 and y=72,
leaving interior y=67..71; divider cells outside that opening remain wall.

Fill left chamber to depth 32. Measure upstream free-surface slope/cliffs,
discharge through the nozzle, downstream spread, terrace/hill metrics and work.

### FD — fast dump

Extent x=0..127, floor y=88, side walls x=0/127. A gate wall at x=32,y=24..87
separates source x=8..31 from receiving basin x=33..123. Fill source to depth 56.
At the start of tick 1, remove gate cells y=40..87; this material edit is part of
the registered input schedule and does not add/remove Water.

The terminal contact wall is x=127; authoritative wall-gap column is x=126 with
neighbourhood x=122..126. Measure surge front, COM/range, contact time, contact
gap, terraces, work and quantity.

### CS — calm settling

Extent x=0..127, floor y=88, side walls x=0/127. Fill block x=40..79,y=40..87
(40x48 full cells). No later inputs.

This is the primary convergence fixture. Its leveling ROI is x=1..126; its
surface-defect ROI is the wet subset of x=1..126. Measure time-to-flat,
local/global leveling slope, internal/leveling cliffs, hillnipple,
terraces/shimmer, activity tail and work. Canonical P0 is run
to 7,200 ticks if 1,800 ticks censor the registered equilibrium measurement.

### LS — ledge sheet positive control

Extent x=0..127, bottom floor y=104, side walls x=0/127. Ledge wall y=56,
x=0..63. Fill x=40..63,y=32..55 (24x24 full cells). The ledge ends at x=63;
downstream is x=64..123.

Measure discharge below y=56, downstream front/range, occupied Water count,
partial-cell fraction, connected Water component count, small-component count,
activity/work and quantity. This is quantitative context for preserving rapid
dribble, serpentine/splashy fronts and local breakup; final acceptance also
requires the focused H regression.

## Horizons and sampling

Baseline/candidate semantic trace:

- all fixtures: ticks 0..1,800 at P0, worker 1, observer on;
- CP16 and UT96-48: extend to 7,200 if half-life/equilibrium is censored;
- CS: extend to 7,200 if time-to-flat is censored;
- P0-P4 verification: ticks 0..1,800, workers 1 and 4, observer off, repeat twice;
- observer neutrality: P0 worker 1, observer off/on, 1,800 ticks;
- retained trace checkpoints: 0, 1, 10, 30, 60, 120, 240, 480, 900, 1,200,
  1,800 and final extended tick; scalar metrics remain every-tick.

No semantic run reads wall-clock time.

## Performance design

Performance is a separate stage after semantic equivalence for that arm.

Each measured fixture uses 1,920 ticks: first 120 are warm-up and retained
separately; the following 1,800 are steady measurement. Run seven alternating
baseline/candidate process pairs, AB/BA order alternating by pair. Do not overlap
timing processes on one host.

Report startup separately, per-tick p50/p95/p99/max, steady total, visited cells,
moved cells, active-block ticks, scheduled cores, successful Water transfer
events, transfer units where available, wakes/sleeps and ns/visited-cell. Retain
all samples and outliers. A paired p95 or steady-total regression >15% is a review
flag; >30% without a proportionate behavior/work explanation rejects the
candidate for this bounded campaign.

## Rendered-surface gate

Simulation comparison keeps presentation fixed. Candidate acceptance requires
tick-indexed captures for P0 CS, CP16, CN, FD and LS using the existing intended
four-visible-level Water presentation.

For each registered tick, extract the visible Water contour over the same ROIs and
report rendered hill amplitude/width, terrace count/severity, contour turnover and
wall gap. Authority and render are interpreted separately:

- bad authority + bad render: simulation defect;
- good authority + bad render: presentation defect;
- bad authority + visually good render: simulation still fails;
- good authority + good render: pass for that dimension.

The issue #26 branch may add measurement/export plumbing required to obtain these
numbers, but it does not broaden into a renderer rewrite.

## Candidate hypotheses

### A — head-scaled local drive

Hypothesis: a bounded local depth/head proxy can make deep Water redistribute
laterally faster without changing shallow positive-control character.

Candidate A may alter only Water leveling drive/cadence using bounded local state.
It must not add persistent history or a general pressure field. Because a full
neighbour has zero capacity, A must explicitly state how the registered head proxy
can affect useful local redistribution in saturated regions; multiplying the
existing same-row request alone is considered a mechanism-null implementation and
is not an admissible A result.

A is compared only with the frozen baseline.

### B — bounded leveling horizon

Hypothesis: bounded horizontal awareness of nearby lower free-surface potential
can reduce persistent cliffs/terraces where adjacent-only relaxation is too local.

B is implemented and compared independently from the same baseline, not on top of
A. Read/write radius, scheduler-domain consequences and maximum work are explicit.
Unbounded search is forbidden.

### C — combined arm

No combined arm exists by default. It is preregistered only after A and B each
produce independently useful evidence and a specific interaction hypothesis.

## Candidate rejection and admission rules

Correctness failures reject immediately:

- any unaccounted Water unit;
- repeat or expected worker-count divergence;
- observer-dependent authoritative state;
- out-of-domain or unbounded access;
- permanent oscillation/activity created by the candidate;
- protected non-Water regression attributable to the candidate.

A/B behavior is not selected by one scalar. A candidate is worth focused H only
if all are true:

1. CP16/UT96-48 head/level convergence materially improves or the candidate
   produces a clearly diagnosed negative result explaining why that mechanism
   cannot affect saturated head;
2. CS time-to-flat and slope/cliff tails improve materially, with the 0.25-0.50
   baseline time ratio retained as the owner H target band rather than a sole
   pass/fail threshold;
3. authoritative hill amplitude/lifetime, severe terraces/turnover and contact
   gaps do not worsen, and at least one currently failing surface dimension
   materially improves;
4. R8/R24/R40 preserve monotonic useful depth/head response rather than flattening
   all reservoir behavior to one globally fast rate;
5. LS does not lose more than 50% simultaneously in early discharge, downstream
   front extent and peak small-component count, and does not acquire a severe
   persistent terrace/hill/contact defect;
6. work/performance stays within the bounded review rules above.

A candidate that makes deep Water faster by making every Water case uniformly
hyper-fluid, smooth, inert or permanently active is rejected even if
`time-to-flat` improves.

Negative and ambiguous results are retained. Failure of both bounded candidate
families is a valid issue #26 research result and must state the larger architecture
question rather than being tuned away.

## Required review sequence

1. Commit this preregistration and measurement-only tooling.
2. Run baseline; retain raw/reduced evidence and hashes.
3. Review baseline against PR #33 H findings and the source mechanism above.
4. Only then implement candidate A.
5. Retain/reduce A and decide whether A justifies H.
6. Implement candidate B independently from baseline.
7. Retain/reduce B.
8. Admit C only if both isolated candidates justify a named interaction test.
9. Run fixed-presentation metrics and focused desktop H regression on finalists.
10. Synchronize dated audit, Water design/programme/RAG/evidence routes.
11. Open/finish the #26 PR with CI green and stop for owner merge approval.

Do not close #18. Do not close #26 until its acceptance criteria are genuinely
satisfied. Do not merge the #26 PR without owner approval.
