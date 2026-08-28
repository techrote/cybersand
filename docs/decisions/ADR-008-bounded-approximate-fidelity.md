---
title: ADR-008 - Bounded approximate fidelity under load
status: Approved design
scope: Gameplay fidelity tiers, temporal sampling, probabilistic rules, strict replay mode, render decoupling, and spatial coarsening limits
keywords: [ADR, approximation, probabilistic simulation, temporal LOD, dynamic resolution, async rendering, frame budget]
related-documents: [../operations/profiling-observability-and-performance.md, ../systems/activity-dirty-regions-and-waking.md, ../architecture/simulation-tick-and-threading.md]
last-reviewed: 2026-08-27
implementation-state: The preferred Godot runtime now uses full-rate native active cells, activity sleeping, interest filtering, and optional temporal snapshot interpolation; generalized secondary-field/distant-world fidelity controls remain Planned.
---

# ADR-008: Bounded approximate fidelity under load

## At a glance

- Decision: 60 FPS gameplay and bounded simulation work take priority over universal bit-exact replay.
- Decision: keep full-resolution material occupancy around gameplay interest while reducing update frequency elsewhere.
- Decision: probabilistic and sampled rules use explicit rates and preferably stateless seeded choices.
- Decision: strict replay remains a selectable validation/debug contract for the Current native solver.
- **Current**: the renderer and GDScript simulation worker already advance independently.
- **Current**: native active material runs at full cadence; quiet blocks sleep and scheduling cores outside the interest window are rejected.
- **Current**: presentation may blend immutable snapshots, but authoritative collision and material interactions are not interpolated or delegated to Rapier fluids.
- **Planned**: coarse secondary fields, distant macro-state, fidelity hysteresis, and backend-specific quality controls.
- **Explicitly rejected**: visible checkerboard holes or naive 2×2 merging in the local gameplay material grid.

## Search anchors

probabilistic falling sand, maintain 60 FPS, paused pixels wake spike, dynamic physics resolution, async renderer, strict replay mode, voxel grouping

## Status

**Approved design**, with a partial **Current** native proof.

## Context

Activating a large previously paused region can make thousands of cells become
eligible simultaneously. Complex liquid probes amplify that cost, and a worker
that misses its fixed interval publishes visual state less often. Exact replay
does not compensate for single-digit gameplay frame rates or obvious artifacts.

Naively grouping every 2×2 set of visible material pixels would reduce element
count, but it also changes narrow gaps, thin films, collision silhouettes,
reaction boundaries, liquid volume, and rigid-body contact. Sleeping static
material already costs almost no rule work, so spatial merging is least useful
where it is safest.

## Decision

The engine supports explicit fidelity tiers rather than one universal accuracy
contract.

| Tier | Intended scope | Permitted approximation |
|---|---|---|
| Local interaction | Player, enemies, rigid bodies, active hazards, visible material boundaries | Full cell occupancy and collision; bounded temporal deferral only outside the immediate interest neighbourhood |
| Active surroundings | Visible or near-visible material without immediate gameplay contact | Interest-weighted block cadence, sampled broad searches, rate-limited slow reactions |
| Secondary fields | Heat, pressure, wind, composition, lighting-derived effects | Lower spatial resolution and lower cadence when conservation/transfer boundaries are explicit |
| Distant world | Stored regions outside gameplay relevance | Sleep, event summaries, analytic catch-up, or coarse conserved macro-state |
| Strict validation | Tests, regression capture, debugging, selected replay | Fixed policy, stable seeds/order, and exact hashes where the backend supports them |

Approximation policies must be visible in configuration/metrics, bounded, and
reversible. They may alter fine outcomes, but cannot silently delete conserved
material, permit cells through solid occupancy, cross closed barriers, or create
systematic empty scanlines.

## Current Godot policy

The Linux x86_64 proof retains the exact material grid and executes eligible
native activity at 60 Hz. A 128×128 storage chunk contains 32×32 activity
blocks; 64×64 scheduling cores are dispatched in four non-overlapping parity
phases. Quiet activity sleeps, and cores outside the camera plus configured
margin remain unscheduled until the region returns.

The `K` toggle controls only temporal blending between immutable R8 snapshots.
It does not lower the cellular rate, merge visible cells, relax solid occupancy,
or substitute Rapier/Salva fluids. The older GDScript fallback retains a bounded
sparse ballistic mode, but it is not the production performance path.

## Probabilistic rules

Good candidates include:

- slow ignition attempts, fungus/grass spread, corrosion, freezing, and decomposition;
- distant gas diffusion and secondary pressure relaxation;
- visual spray/particle conversion and non-critical debris;
- selecting a subset of equivalent boundary contacts for expensive aggregate force estimates.

Poor candidates include:

- solid occupancy and collision near gameplay;
- material conservation at closed boundaries;
- ownership, buffer capacity, and cross-thread synchronization;
- explosion command acceptance and other discrete gameplay transactions;
- resolving an already-detected rigid-body/terrain penetration.

Stateless hashes of coordinates, material state, rule stream, and tick are
preferred when their cost is small. They provide stochastic-looking behavior
without thread timing becoming a hidden input. Gameplay mode may relax exact
replay further, but data races and completion-order ownership remain forbidden.

## Renderer and simulation rate

The renderer may show the newest immutable snapshot repeatedly while cellular
work continues asynchronously. Simulation still advances in fixed quanta; it
does not use render delta as material-rule time. Presentation may interpolate
entities and shader fields, but must not invent authoritative collision.

If a future controller reduces a subsystem's rate, it should skip scheduled
fixed updates or select a documented cadence, retain local gameplay priority,
use hysteresis to prevent rapid quality oscillation, and expose snapshot age.
Rigid-body coupling may use additional bounded substeps when motion demands it
without forcing the entire cellular world to the same rate.

## Spatial coarsening boundary

Full-resolution cells should not be merged merely because a block is dense.
Future macro aggregation is suitable when it preserves a full-resolution active
boundary shell and a conserved interior summary. It must expand before a player,
body, destructive command, or incompatible field reaches that boundary. Heat,
pressure, and distant atmosphere are stronger first candidates than primary
material occupancy.

## Consequences

Benefits:

- wake-up bursts have a bounded, graceful degradation path;
- the local interaction area retains collision fidelity;
- expensive slow or long-range rules need not run for every cell every tick;
- strict regression tools remain available without constraining every gameplay build.

Costs:

- distant material can visibly advance at a lower cadence;
- exact gameplay replay may differ between fidelity policies;
- metrics and tests must distinguish strict and approximate modes;
- quality transitions require tuning and artifact-focused acceptance tests.

## Alternatives

### Require bit-exact authoritative replay at every fidelity level

**Explicitly rejected** as a universal gameplay gate. Strict replay remains
valuable, but it cannot prohibit bounded approximations that materially protect
frame rate and preserve gameplay invariants.

### Merge all active material into 2×2 or larger voxels

**Explicitly rejected** for the local material grid. It causes topology and
surface artifacts and does not help already sleeping static volumes. Coarse
optional fields and distant macro interiors remain **Planned**.

### Tie simulation ticks to rendered frames

**Explicitly rejected**. Rendering and simulation remain independently paced;
render delta never becomes the material solver's time step.

## Reversal or migration

Any approximation can be disabled in strict mode. If a policy causes gameplay
artifacts, retain the metrics and fixture, revert that policy independently,
and choose a different tier or rule-specific approximation.

## Validation

- entering a large awake region does not create alternating empty scanlines;
- the immediate interaction neighbourhood remains full cadence under load;
- deferred blocks eventually run and retain wake state;
- sparse broad probes never cross an occupied path cell;
- closed-fixture material totals remain valid where conservation is required;
- strict native fixtures continue to reproduce their recorded hashes;
- gameplay acceptance measures render FPS, simulation age, and visible behavior separately.

## Related decisions

- [ADR-002: Benchmark-gated cellular schedulers](ADR-002-double-buffered-tile-jobs.md)
- [ADR-007: Separate rigid-body occupancy coupling](ADR-007-rigid-body-cellular-coupling.md)
- [Profiling and performance](../operations/profiling-observability-and-performance.md)
