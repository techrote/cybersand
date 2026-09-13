---
title: Water Feel Lab experiment registration
status: Current
document-kind: runbook
scope: Preregistered Issue 19 V1 presentation and V2 H-preparation experiments
canonical-for: [water-feel-lab-experiment, water-presentation-experiment]
last-reviewed: 2026-09-12
related-documents: [architecture-programme.md, architecture-programme-water-feel-addendum.md, architecture-programme-prompts/fractional-presentation.md, experiment-tower.md, state-precision-experiment.md, ../systems/water-design.md, ../architecture/rendering-and-gameplay-bridges.md, ../audits/2026-09-12-issue-19-water-feel-lab.md]
---

# Water Feel Lab experiment

## Registration before candidate code

Recorded September 12, 2026 before Issue 19 candidate implementation. The
dedicated worktree is `C:/kybersand/worktrees/issue-19-water-feel-lab` on
`codex/issue-19-water-feel-lab`, based on synchronized planning commit
`d39e31f03f2e39b0022d507b79fbee5c2439436d`. The source checkout and retained
Issue 12, 15, 16, 17 and 18 worktrees are not implementation workspaces for this
issue. Mass8 is the numerical oracle. Issue 17's fixed wider carrier and
compile-time arms are evidence, not a production layout decision. Issue 19 does
not choose Water precision, packing, spare-state use or a perceptual winner.

The experiment separates nine dimensions: authoritative mass semantics;
coherence duration; four-level presentation; interface reconstruction;
deterministic scenario identity; policy selection and provenance; transactional
Apply + Reset; blind candidate identity; and observation/export metadata. V1
changes presentation only. V2 semantic comparisons hold presentation fixed.

## Current implementation outcome

**Current, 2026-09-12:** the preregistration below was implemented without changing
its experimental dimensions. V1 and V2 pass their available acceptance gates and
the lab is H-ready. The [dated completion record](../audits/2026-09-12-issue-19-water-feel-lab.md)
owns source/artifact identity, platform results, failures, independent review and
the later-human-evaluation boundary. The frozen sections remain here so current
behavior can be checked against the pre-code contract.

## Frozen normalized policy

One version-1 `WaterExperimentPolicy` is the only normalized representation
consumed by World construction and every selection surface. Its fields are:

| Field | Domain and default | Authority |
|---|---|---|
| `version` | exactly 1 | schema |
| `mass_bits` | integer 3..8; default 8 | simulation |
| `coherence_ticks` | integer 0..12; default 12; named `current`, `three-bit`, `short`, `none` map to 12, 7, 3, 0 | simulation |
| `rest_policy` | exactly `current-normalized-v1` | simulation |
| `render_fill_levels` | exactly 4 for this experiment | presentation |
| `interface_mode` | `coverage` or `oriented`; default `coverage` | presentation |
| `scenario_id` | registered Water Feel scenario | recipe |
| `seed` | unsigned 31-bit integer; default 0 | recipe |
| `source` | `default`, `profile`, `launch` or `panel` | provenance |

The canonical serialization uses those keys in that order and a SHA-256 over
compact UTF-8 JSON. Derived simulation values are computed once during
validation: `maximum=(1<<mass_bits)-1`, `film=Q(48/255)`, and
`tolerance=Q(1/255)`, where `Q(n/d)=floor((2*n*maximum+d)/(2*d))`. Runtime mass
is an integer in the candidate lattice stored in the existing superset lane.
Transfer subtracts and adds the same integer. Zero is Empty. Coherence is the
existing pre-decrement countdown and max-on-merge rule with the configured
emission/reset maximum. The policy is immutable after World construction.

Profile JSON, launch arguments and the panel all call the same parser,
validator, canonicalizer and resolver. Precedence is panel draft over launch
over profile over defaults, with field origins retained in effective
provenance. A complete candidate is validated before construction. The owner
constructs and populates a fresh World, then atomically replaces the current
World only after success. Invalid input or candidate construction leaves the
old World, render exchange and effective-policy identity intact. Render-only
mode changes may hot-switch because they cannot mutate authoritative state.

## V1 preregistration: four-level presentation

The reference mode is the current stable per-cell coverage dither. The new
`four-level` mode first quantizes normalized authoritative Water mass `m` to
coverage `c` in `{0.25, 0.50, 0.75, 1.00}` for positive cells by
`ceil(clamp(m,0,1)*4)/4`; Empty remains zero. This positive-cell rule retains a
visible trace for the smallest nonzero candidate mass. Four fixed 2x2 ordered
subcell masks provide exactly 1, 2, 3 or 4 covered samples, anchored in world
coordinates so camera motion, scale and snapshot interpolation cannot randomize
the mask.

`coverage` uses the fixed order bottom-left, bottom-right, top-left, top-right.
`oriented` inspects the frozen 3x3 normalized Water-condition neighborhood and
forms a central difference `(right-left, down-up)`. A dominant component must
exceed the other by at least 1/255 and magnitude must exceed 2/255. The occupied
subcells are then ordered from the locally fuller side toward the emptier side;
ties use horizontal before vertical and then world-coordinate parity. Diagonal
gradients use the corresponding corner-first order. Weak, symmetric, isolated,
or otherwise ambiguous gradients deterministically fall back to `coverage`.
Only immutable RG8 snapshot samples are read. No material, mass, activity,
collision, epoch, dirty-region or worker state may be written.

Frozen positive cases are top surfaces, undersides, left/right vertical edges,
diagonals, concave/U boundaries, adjacent-cell continuity, and supported films.
Frozen negative/fallback cases are isolated droplets, uniform pools, symmetric
crosses, equal diagonals and gradients below the thresholds. One-cell streams,
ledge sheets, storage/chunk/activity/core seams, and captured moving sequences
are mixed cases. Evaluate at native 1x plus 2x, 4x and the application's 480x270
Tower view. A failure is incorrect four-sample count, a seam discontinuity not
explained by authoritative input, orientation opposite the registered gradient,
or display changes on an identical frozen frame.

Coverage error is the absolute difference between `c` and normalized mass,
reported by input level and aggregate; it is not a desirability score. Temporal
flicker is changed subcell samples between consecutive frozen-sequence frames,
reported separately when authoritative mass/neighborhood changed and when it
did not. Snapshot/copy bytes and timings, full GPU upload bytes, and render
timing are measured where the platform exposes them; no unmeasured saving is
inferred. Authoritative equality is demonstrated by identical content hash,
state hash, Water integer ledger, activity counters and subsequent tick results
before and after switching presentation modes, including a delayed immutable
snapshot consumer.

## V2 preregistration: deterministic scenario catalogue

The Water Feel Lab is an annex mode of the existing Experiment Tower, not a
sixth always-simulating floor. Each registered scenario builds a fresh
deterministic recipe with seed, camera, player start, paused state, release
schedule and preserved Issue 13 Baseline transport identity. Scenario IDs are
stable v1 strings:

| Family | Scenario IDs |
|---|---|
| Pools and settling | `shallow-pool`, `deep-pool`, `calm-settling`, `connected-pools`, `tiny-quantities`, `residual-pockets` |
| Feeds | `drips`, `trickle`, `fast-dump`, `slow-release`, `fall`, `thin-stream`, `shower-drizzle`, `ledge-sheet` |
| Geometry | `narrow-channel`, `broad-channel`, `steps`, `u-vessel`, `constriction`, `irregular-bed` |
| Direction references | `direction-vertical`, `direction-horizontal`, `direction-diagonal` |
| Mutation and drainage | `excavation-refill`, `support-removal`, `cavity-fill-drain` |
| Contracts and seams | `real-void-barrier`, `film-boundaries`, `storage-seam`, `activity-seam`, `core-seam`, `long-tail-settling` |
| Preserved references | `water-sand-baseline`, `mercury-reference`, `supported-body-water` |

Recipes contain no random choice in v1; seed is still part of identity so a
future seeded revision cannot be confused with v1. Each recipe has bounded
ordered rectangles and bounded tick-relative actions. Reset or candidate switch
recreates the same geometry, quantities, camera/player position, paused state
and pending actions in one owner action. No state, action queue or observation
history survives a successful reset. Failed reset preserves the previous valid
run. The body scenario uses only the existing supported body path; all others
exclude bodies. `water-sand-baseline` fixes the #13 Baseline transport policy and
`mercury-reference` never applies Water semantics to Mercury.

Semantic A/B holds `interface_mode=four-level oriented`, fill levels, scenario,
seed, camera, viewport, start state, action schedule, worker/geometry settings,
transport/interaction policies and unrelated materials fixed. Presentation A/B
holds the entire authoritative policy and run fixed. Candidate labels are
randomized from a supplied seed independently of simulation and map to complete
canonical policies. The visible observation record contains only label,
scenario and run controls until reveal. Export always includes a reconstructible
hidden mapping, effective-policy hash, recipe version, source/artifact/platform,
worker count, action history, exact initial/current Water integers, explicit
source/sink/outflow, initial physical quantization error, presentation mode and
available activity/timing diagnostics.

## Correspondence and validation oracles

Mass8/coherence12 must match current authoritative fixtures exactly. Runtime
mass4/6/8 must match applicable Issue 17 quantization, film, tolerance,
conservation and common-scenario results. Mass3/5/7 cover zero, one, half,
maximum-minus-one, maximum, capacity, low-quantity, lateral rounding and merge
boundaries. Every mass arm has exact integer conservation. Coherence 0..12
covers creation, pre-decrement, movement, max merge, repeated transfer and
refusal above 12. One- and four-worker runs and repeats must match wherever the
existing native contract requires parity. Observer/debug/UI presence is neutral.
Initial physical quantization error and subsequent integer drift are separate.

Application validation exercises every scenario on native desktop and both
available real Web exports, including reset, Apply + Reset, pause, single-step,
candidate switching, blind labels, export, camera/player/action preservation,
ordinary-UI cleanliness and absence of cross-scenario contamination. Missing
platform access is a named gap, never inferred acceptance. This issue prepares
the later H study and records no perceptual winner.

## Implementation package DAG

| ID | Objective | Frozen inputs/interfaces | Output and bounded write set | Depends on | Spark tier | Oracle | Independent review | Parallel |
|---|---|---|---|---|---|---|---|---|
| P0 | Freeze this registration and shared interface | Live #19, programme, #13/#15/#16/#17/#18 evidence | This document only | none | master | docs checks; commit predates candidate code | master | no |
| A | Runtime semantic policy and exact Water arithmetic | Schema/math/lifecycle above; existing uint64 carrier | `native/include/cybersand/water_experiment_policy.hpp`, `world.hpp`, `material_appearance.hpp`; `native/src/world.cpp`; focused native tests only | P0 | xHigh | #17 correspondence, conservation, boundary, parity tests | Terra Max | eligible with B |
| B | Four-level and oriented presentation | RG8 Water condition is normalized 0..255; V1 rules above | `godot/shaders/material_palette.gdshader`; new presentation model and focused Godot tests only | P0 | High | synthetic masks, positive/negative cases, authoritative equality fixture | Terra xHigh | eligible with A |
| I1 | Integrate A/B at adapters and renderer controls | Stable A policy API and B shader uniforms | bridge/extension bindings, desktop/Web controllers and shared integration tests; master-owned central files | A, B | master | combined native/Godot focused tests | Terra Max | no |
| C | Deterministic scenario registry and recipes | v1 IDs and reset contract above; integrated policy API | new Water scenario registry plus focused recipe/reset tests; no controller/panel edits | I1 | High | catalogue completeness, recipe hashes, bounded actions, repeat | Terra xHigh | eligible with D only if sets remain disjoint |
| D | One resolver, config/CLI/panel, blind/export model | Frozen policy schema, precedence and metadata above | new resolver/panel/blind-model files and focused tests; no scenario registry or controller edits | I1 | xHigh | surface equivalence, invalid refusal, blind reconstruction | Terra Max | eligible with C |
| I2 | Extend Tower owners and bind C/D | Stable C registry and D resolver APIs | master-owned `main.gd`, `web_demo_controller.gd`, `simulation_worker.gd`, `tower_panel.gd`, native bridge touchpoints and integration fixtures | C, D | master | owner-boundary reset, deterministic A/B, desktop/Web behavior | Terra Max | no |
| E | Evidence, manual matrix and current documentation | Stable integrated implementation | audit/evidence docs, programme/routes/contracts; raw logs outside source | I2 | master | required repository/docs/retrieval/platform checks | Terra Max final | no |

### Parallelism proof

A and B may run together only after P0. A owns native semantic storage/math and
tests; B owns only shader/pure presentation logic and presentation tests. Their
shared contract is already frozen here: the immutable RG8 condition byte is
normalized authoritative Water mass in 0..255, and B cannot change its producer.
Neither package needs the other's result. Neither may edit adapters, controllers,
build manifests, shared registries, central Tower fixtures, generated files or
documentation. Master performs those changes in I1. If either needs such a
change, it stops and reports the missing interface; the work is serialized.

C and D may run together only after I1. C owns scenario data/recipe tests; D owns
policy resolution, blind mapping and their pure UI-model tests. Scenario lookup
accepts only the frozen ID string and seed; policy resolution treats them as
validated opaque registered values. Neither may edit the other's registry,
controllers, Tower panel, worker, bridge, build manifests, generated files or
documentation. Master binds them in I2. Any discovered shared edit stops one
path and forces serialization. At most two write-capable workers run at once.
