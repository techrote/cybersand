---
title: Troubleshooting guide
status: Current
scope: Symptom-to-subsystem routing, wake-up overload, scanline artifacts, rigid-body coupling, current and planned diagnostics, safe corrective actions, and escalation conditions
keywords: [low FPS, wake spike, alternating lines, rigid body overlap, one core, water shimmer, water heap, boundary seam, dirty upload, capacity exhaustion]
related-documents: [profiling-observability-and-performance.md, testing-validation-and-replay.md, ../architecture/rigid-body-and-cellular-coupling.md, ../systems/water-design.md]
last-reviewed: 2026-08-28
implementation-state: Current guidance distinguishes the preferred native phased runtime from the adaptive GDScript fallback; Rapier is manually stepped and focused Godot 4.7 Linux checks pass.
---

# Troubleshooting guide

## At a glance

- Purpose: route a symptom to the likely subsystem before changing algorithms.
- **Current**: the preferred Linux runtime coordinates on one Godot worker and dispatches cellular phase jobs through a persistent native pool.
- **Current**: preferred Water uses native conserved mass; directed discrete Water remains in the GDScript fallback.
- **Current**: full changed snapshots and texture uploads can amplify presentation cost.
- **Current**, fallback only: adaptive block stride bounds wake-up work; preferred native jobs remain full cadence in the selected region.
- **Current** source: three rectangle body masks/results expose contacts, displaced cells, and unresolved overlaps.
- **Current**, partial: native work/phase/allocation/memory/hash metrics exist; per-stage timing and per-worker utilization remain planned.
- **Current**: native snapshot pressure reports exact required patches/bytes and retains dirty state; Godot does not consume it yet.
- Safe rule: reproduce correctness failures in the single-thread reference before optimizing parallel execution.
- Safe rule: never hide capacity or correctness failures with clipping, dropped work, or hot allocation.

## Search anchors

FPS low, only one CPU core, water flickers, water piles like sand, seam at chunk edge, replay mismatch, texture upload too large, queue full, unsafe Godot thread

## Symptom routing table

| Symptom | Likely subsystem | Inspect | Safe corrective action |
|---|---|---|---|
| Low FPS and high simulation time | Native phase/rule stages or fallback CyberCellWorld | worker/simulation time, visited/moved cells, jobs and active blocks | Reduce false activity or optimize a proven hot kernel without changing semantics |
| FPS collapses when entering paused material | Wake-up burst, job planning, or expensive broad rules | native active jobs/visited cells; fallback eligible/run/deferred blocks | Preserve full-rate local semantics; remove false wakes and bound broad sampling rather than erasing state |
| Every other falling line is Empty | Source update stamp in bottom-up movement | `try_move` source/destination epochs | Leave a vertically vacated Empty source fillable; keep written destination protected |
| Low FPS but low simulation time | Snapshot copy/upload, Godot rendering, unrelated gameplay | Snapshot copy, upload time/bytes, render frame | Correct dirty publication/upload path; do not alter physics |
| One CPU core saturated in Godot | Native adapter unavailable, undersubscribed phases, or non-cellular main/worker work | backend name, native worker count, jobs per phase, worker/simulation time | Confirm Native/worker count in HUD; then profile job availability and remaining serial stages |
| Native workers show little benefit | Current phased planning or memory access | phase jobs, parallel threshold, active cores, tick time | Do not dispatch undersubscribed phases; profile job availability and lookup cost |
| Water shimmers and state changes | Water rest/flux/conversion | replay hash, dirty state, net flux/mass, active tiles | Fix single-thread liquid reference; reject equivalent-state swaps |
| Water looks dithered but state is stable | Render-only presentation | snapshot/render output only | Adjust dither accessibility/pattern, not authoritative water |
| Water forms a static heap | Flow mode, pressure look-ahead/flux, or premature sleep | Godot flow_budget/flow_direction and look-ahead; native column mass/activity | Confirm Water uses free-flow mode; retain finite budget/yield only for paste/slush |
| Smoke remains below Water/Sand | Density direction or target permission | source/target descriptor traits, vertical delta, update epoch, wake state | Enable upward exchange on Smoke and acceptance on the intended medium; do not make Wall universally permeable |
| Boundary seam | Halo, transfer, merge, or wake | edge fixture, transfer totals, neighbor activity | Fix shared boundary contract; never special-case world coordinates |
| Replay differs by worker count | Job input, transfer ordering, hash coverage, race | first divergent tick/stage, transfers, state hash | Stop performance work; restore deterministic stage isolation |
| Dirty uploads approach full region | False authoritative changes or coarse dirty bounds | dirty cells/tiles, native required snapshot bytes, future Godot upload bytes | Separate render animation from authority; inspect which chunk bounds coalesced under pressure |
| Capacity exhausted | Task/transfer/snapshot/active-chunk reservation | use/capacity/high-water and request size | Enter explicit safe reconfiguration or approved failure path |
| Material passes through a body | Missing/stale mask, high-speed unswept motion, or illegal direct cell read | body sample ID/age, occupancy mask, target read path | Restore start-of-stage mask reads; for high speed use bounded sweep/substeps rather than per-cell physics objects |
| Body tunnels through thin Wall | Asynchronous unswept sample or stale correction | worker step age, body velocity, contact/correction counts | Reduce body speed for the proof; implement bounded swept/substep coupling before production |
| Body deletes or traps pixels | Ejection search exhausted or overlap ordering defect | displaced/unresolved counts and local empty capacity | Retain/report unresolved material; do not silently delete it; later route explicit overflow to particles |
| Memory grows during stable run | Hidden allocation or retained storage/snapshots | allocation count, memory categories, chunk/snapshot lifetime | Find owner/lifetime leak; do not raise budget blindly |
| Unsafe Godot thread warning/crash | Worker accessing scene/render/gameplay object | thread/context and call site | Move access behind RenderBridge or GameplayBridge on permitted thread |

## Low FPS decision path

1. Compare render FPS with current worker/simulation and upload timings.
2. If simulation dominates, inspect backend name, native jobs/visited/moved cells, or fallback eligible/run/deferred blocks.
3. If activity stays high after visible motion stops, diagnose wake/quiet/water churn.
4. If simulation is low but snapshot/upload dominates, inspect full-array copy/update behavior.
5. For the future backend, split tick time by planning, TileJob, merge, commit, and snapshot stages.
6. Check worker utilization before increasing thread count.
7. Compare current and 2× fixtures with identical correctness hashes.

Do not infer a thread bottleneck from total CPU percentage alone.

## Wake-up spikes and scanline stepping

The GDScript fallback keeps the exact 1024×1024 grid. When many blocks wake, it
targets 12 non-local active blocks per worker tick and keeps the 3×3 block area
around gameplay interest full cadence. Deferred blocks stay active and are
selected by later coordinate/tick phases. `K` disables distance cadence, not
this overload safety policy.

If the stride remains one during a large spike, confirm `eligible_blocks_last_tick`
is published and the current cell_world.gd is running. If FPS is still low at a
high stride, isolate a single active block and profile its material family;
liquid pressure work should use eight deep band probes, not one for every column.

Alternating horizontal gaps are not a reason to coarsen the grid. The corrected
bottom-up rule stamps a written destination but permits a vertically vacated
Empty source to be filled from above in the same pass. Lateral vacancies and
density-swap replacements remain stamped to prevent double updates.

## One-core utilization

### Current Godot

CyberSimulationWorker uses one Godot Thread to coordinate inputs, character work,
native ticks, and publication. On bundled Linux and Windows x86_64 builds, CyberNativeCellWorld owns World,
which dispatches eligible phase jobs to a configured persistent C++ worker pool.
If the HUD reports `GDScript/1 thread`, the fallback is active.

### Current native diagnosis

The dense checkpoint exposed about 19 jobs per phase. In the final hosted run,
eight workers beat four, while an earlier run showed the opposite; treat worker
selection as hardware/fixture tuning, not an architectural constant. The sparse
fixture exposed four jobs per phase, below the threshold of eight, so it
intentionally ran sequentially. Diagnose:

- too few active tiles may limit available parallelism;
- uneven water/smoke occupancy may imbalance jobs;
- transfer merge may dominate serial time;
- memory bandwidth may limit scaling;
- false sharing may keep cores busy without useful throughput.

One/four-worker deterministic equivalence and TSan currently pass; preserve them
while tuning.

## Water shimmer

### Determine whether it is authoritative

- If material/mass state, dirty counts, or replay hash changes: simulation issue.
- If only final color/pattern changes: render issue.

### Current Godot likely causes

- in-place lateral swapping;
- incorrect flow_direction transfer/reset;
- pressure look-ahead or depth bound regression;
- quiet/wake feedback;
- a material accidentally assigned the yielding flow mode.

### Safe action

Create a minimal settled-Water fixture. Use native content hashes, total mass,
and the Current pairwise reference as the oracle. Do not stop shimmer merely by
preventing all lateral leveling, because that reproduces static heaps.

## Water heaps

Current Water should not exhaust its lateral budget: Water uses the free-flow
sentinel, while finite travel is reserved for yielding liquids. If a heap
appears, inspect:

- available empty/lower neighbors;
- source and target flow_budget plus flow_direction;
- material viscosity and derived lateral flow rate;
- sampled pressure depth and 256-cell surface look-ahead result;
- active/quiet state;
- block_movable_counts.

The Current native correction is conserved pairwise mass transfer. The Godot
reference remains discrete, but its Water path is now intentionally different
from the retained finite-budget/high-viscosity paste/slush path. The wide
regression requires a two-cell maximum height difference by tick 360. Run
`godot --headless --path godot --script res://tests/test_cell_world.gd` when a
Godot binary is available.

## Boundary seams

Run the same fixture:

- centered within one worker tile;
- shifted across a worker-tile edge;
- shifted across a storage-chunk edge;
- shifted into negative coordinates.

Compare state and conserved totals after corresponding ticks. A special edge-only material rule is unsafe; phase ownership or buffered transfer semantics and wake behavior must remain coordinate-independent.

## Rigid-body coupling

The Current sandbox uses vendored Rapier2D v0.35.2 through ordinary Godot
RigidBody2D nodes. `CyberRapierPhysicsBridge` deactivates automatic stepping,
owns the main-thread space step, and sends only packed rectangle samples to the
worker. Dependency and coupling checks are documented in the dedicated runbook.

For a body/material failure, inspect:

- whether the body sample ID advances and the result is applied once;
- mask contacts versus displaced and unresolved cell counts;
- whether the material rule reads `material_at`/`try_move` rather than bypassing the mask;
- worker age relative to body speed;
- whether Wall produces correction while movable material produces bounded ejection/reaction;
- whether symmetric pressure contacts should cancel or support the body.

The Current proof is asynchronous. Translation up to 32 pixels is reconciled
through at most 24 intermediate rectangle intervals before the endpoint mask is
installed. Larger jumps are teleports and rotational-only coverage remains
approximate; use selective CCD or bounded substeps for demonstrated remaining
failures, not thousands of PhysicsServer cell colliders.

Separate dependency faults from coupling faults:

- missing `RapierPhysicsServer2D` means addon registration/version/architecture failure;
- a project setting other than `Rapier2D` means activation or restart is incomplete;
- a valid backend with poor body/material behavior remains a coupling-order or mask/reconciliation problem;
- SceneTree state can lag authoritative server state, so inspect direct server observations during manual-step work.

## Nondeterminism

1. Find the first divergent tick.
2. Compare latched inputs/configuration.
3. Compare selected jobs and their read views.
4. Compare produced transfers before merge.
5. Compare canonical merge output.
6. Compare commit and activity/wake state.
7. Confirm the hash covers all future-affecting state.
8. Vary completion timing while keeping inputs unchanged.

Do not fix divergence by sorting only final cells if earlier semantics remain timing-dependent.

## Excessive dirty uploads

Current main.gd consumes copied native RG8 dirty patches and updates the retained
CPU image before ping-ponging two complete GPU textures. Before changing shaders:

- determine whether authoritative cells are genuinely changing;
- separate water dither/presentation animation from authoritative state;
- measure snapshot and upload bytes;
- confirm dirty state survives snapshot pressure;
- distinguish compact worker-to-main patch bytes from the final full texture update.

If Godot reports that `Image.create_from_data` expected nonzero RG8 bytes but
received zero, the patch metadata and payload have violated their publication
contract. Record the render serial, metadata count, payload byte count, rectangle,
offset, and stride. Do not acknowledge that serial and do not call Image or
`blit_rect` with the rejected payload. The Current consumer validates those
fields, requests a full refresh, and acknowledges only after successful upload.
Repeated rejection after a full refresh indicates producer corruption rather
than ordinary render pressure.

If native publication returns Backpressure, release stale consumer leases or
increase capacity during explicit setup; do not clear World dirty state. If it
returns CapacityExceeded, use the exact required patch/byte result to
reconfigure outside active publication.

## Capacity exhaustion

Required diagnostic:

- requested region/work;
- exhausted capacity category;
- current use, capacity, and high-water;
- memory use;
- tick/reconfiguration boundary;
- explicit outcome.

Unsafe reactions include clipping the region, dropping transfers, silently allocating, or continuing with incomplete halos.

## Worker imbalance

Current safe investigations:

- correlate per-worker work with active cells/transfers, not just job count;
- inspect whether 32×32 tiles are too coarse for uneven activity;
- distinguish merge bottleneck from worker imbalance;
- avoid material-specific queues that become hidden scheduler coupling;
- preserve deterministic job and merge semantics while testing work distribution.

## Unsafe Godot-thread interaction

Simulation workers must not touch:

- scene tree;
- Nodes or gameplay objects;
- rendering resources;
- audio objects;
- Godot physics objects.

RenderBridge and GameplayBridge perform allowed translation/consumption. If a diagnostic requires Godot data, copy it into an approved immutable command/snapshot contract at the boundary.

## Escalation conditions

Stop the checkpoint and roll back or redesign when:

- liquid mass is not conserved;
- one-worker and multiworker hashes differ;
- a capacity overflow loses authoritative work;
- a worker reads mutable Godot or simulation state without ownership;
- normal hot stages allocate unexpectedly;
- settled water remains authoritatively active;
- a known rigid-body occupancy cell is ignored or overlap material disappears silently;
- gameplay approximation creates collision pass-through, conservation loss, or systematic scanlines;
- larger-region handling clips or corrupts state.

## Related decisions

- [ADR-002](../decisions/ADR-002-double-buffered-tile-jobs.md)
- [ADR-003](../decisions/ADR-003-godot-bridge-and-immutable-snapshots.md)
- [ADR-005](../decisions/ADR-005-water-model.md)
- [ADR-007](../decisions/ADR-007-rigid-body-cellular-coupling.md)
- [ADR-008](../decisions/ADR-008-bounded-approximate-fidelity.md)
- [ADR-009](../decisions/ADR-009-rapier-2d-rigid-body-backend.md)
