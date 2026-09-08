---
title: Smoke, heat, and pressure roadmap
status: Current
scope: Current evidence, ordering constraints, optional-field ownership, validation needs, interaction seams, and GPU limits for future systems
keywords: [smoke, heat, temperature, pressure, gas composition, optional field, GPU field]
related-documents: [materials-and-rule-kernels.md, water-design.md, ../decisions/ADR-006-gpu-compute-deferral.md]
last-reviewed: 2026-09-08
implementation-state: Native discrete Smoke rises, exchanges through denser opted-in movable materials, carries a bounded lifetime, thins faster in crowded clouds, and cannot ignite; temperature storage exists without heat simulation, while pressure and composition are absent.
---

# Smoke, heat, and pressure roadmap

Source review anchors: [native kernels and optional temperature](../../native/src/world.cpp),
[Smoke/temperature fixtures](../../native/tests/test_world.cpp), and
[fallback Smoke](../../godot/scripts/cell_world.gd). The
[2026-09-08 audit](../audits/2026-09-08-documentation-audit.md) records current
local identity and dated test evidence; historical M11 passes do not certify
all later platform builds.

## At a glance

- Purpose: preserve extension seams without pretending future field solvers exist.
- **Current**: Smoke is a discrete rising material that buoyantly exchanges through denser Water and Sand, slowly dissipates, and cannot become Fire.
- **Current**: directional density motion and target-side exchange permission preserve an opt-out for future trapped gases, foams, gels, or load-bearing media.
- **Current**: native Chunk stores temperature values, but no heat-field evolution exists; compact-state/material-ID phase-change rules are separate Current behavior.
- **Planned**: future smoke fields, heat, and pressure adopt shared storage, scheduling, activity, and snapshot boundaries; current discrete Smoke already uses World.
- **Approved design**: optional fields are allocated only where active/needed, not across the full stored world.
- **Deferred / experimental**: suitable non-authoritative fields may later be GPU-resident.
- Non-goal: choose final gas, heat, pressure, chemistry, or GPU algorithms here.

## Search anchors

current smoke implementation, temperature field exists, pressure roadmap, gas composition, heat solver, GPU-resident field, future material interaction

## Current evidence

| System | Status | Evidence | Limitation |
|---|---|---|---|
| Smoke material | **Current** | native/src/world.cpp and godot/scripts/cell_world.gd | Full discrete cell; upward density exchange, bounded lifetime, and crowd-sensitive thinning. Native state is exact; fallback culling is an approximate stateless hazard. |
| Temperature storage | **Current** storage and limited rule input | World::Chunk temperatures and Rocket kernel in native/src/world.cpp | Moves with cells; explicit setters and Rocket threshold exist. No conduction or temperature-driven field evolution. |
| Heat simulation | **Planned** | Legacy architecture prose only | No authoritative update. |
| Pressure field | **Planned** | No general field in World storage | Local liquid comparisons and body boundary-pressure impulses exist; they are not a gas/pressure field solver. |
| Gas composition | **Planned** | No source symbol | No representation or conservation tests. |
| GPU compute | **Deferred / experimental** | No compute code; GL Compatibility renderer configured | Not authoritative for terrain/collision. |

## Dependency order

The following retained ordering is **Approved design** where it restates the
water-first constraint. Native phased Water, Sand, and discrete Smoke already
share World; steps 2–4 are established source foundations, not new port requests:

1. Define and validate ownership, buffers, tick phases, and replay coverage.
2. Implement the deterministic single-thread fixed-point water reference.
3. Validate tile/chunk transfers and multithread equivalence.
4. Migrate Sand and current Smoke only through the shared MaterialRules/TileJob model.
5. Introduce heat as an optional authoritative field with independent reference tests.
6. Design pressure/composition only after conservation, cadence, wake, and interest-region behavior are specified.
7. Add cross-system interactions one bounded rule family at a time.

Exact phase boundaries and algorithms remain **Planned**.

## Common ownership rules

Future systems must not create competing world authorities:

- WorldStorage owns committed optional-field data.
- SimulationCore owns authoritative update/commit semantics.
- MaterialRules supplies immutable descriptors and compact kernels.
- SimulationScheduler schedules field work at defined tick stages/cadences.
- Each field declares phased-exclusive or active-only buffered update semantics; jobs obey that field's ownership and bounded-neighbourhood contract.
- RenderBridge sees immutable derived snapshots only.
- GameplayBridge receives explicit immutable results, not mutable field pointers.

## Smoke

### Current

Smoke occupies a full material cell. It first attempts upward and upward-diagonal
movement. Empty destinations are ordinary moves; an opted-in denser movable
destination is exchanged downward. The target-side permission is deliberately
separate from density so a future gel or foam can remain movable while refusing
gas passage. Static Wall and the movable Mite/Rocket agents are current opt-out
examples.

Native Smoke starts with lifetime 240 in `state_a`. On an eight-tick spatially
staggered lane it loses one lifetime unit, or two when at least five of its eight
neighbours are also Smoke. This slowly hollows dense accumulations in the style
of Foam collapse while keeping ordinary trails substantially longer lived.
Trapped Smoke explicitly keeps its activity block awake until the next lifetime
sample. Ignition excludes Smoke, so neither direct hot contact nor a Fire cell
can turn Smoke into additional Fire.

The compatibility GDScript path has no spare authoritative age byte. It uses a
64-tick newborn warm-up and a much slower spatial hazard instead of allocating a
second 1024² age array. It preserves the visual intent, not exact native timing.

Native tests cover single-pair Smoke/Water and Smoke/Sand exchange, conserved
Water mass during exchange, nine-cell displacement, long lifetime, eventual
culling, and Fire exclusion. The equivalent fallback displacement groups and
the wide-Water leveling assertion were reported passing in historical M11.
Current-platform executions must be attributed separately through the audit.

### Planned questions

- Should a future composition field replace the current intentionally non-conserved lifetime model?
- Does it remain a material-grid occupant or use an optional density field?
- What wake and sleep criteria apply?
- How does it interact with liquid, heat, pressure, vacuum, and collision?
- What representation supports visually dense smoke without permanent full-resolution activity?

Pressure, composition, and field-based volumetric smoke remain unapproved. The
current discrete lifetime model is the implemented reference, not the final gas solver.

## Heat

### Current

Native storage has an optional int16 temperature array initialized from
`WorldConfig::ambient_temperature`. Existing movement copies temperature with
cells, and explicit setters can alter it. The Rocket kernel reads temperature
above ambient + 400 as a launch trigger. No conduction or rule evolves the
temperature field itself. Material-ID and compact-state "thermal" reactions
(melting, boiling, cooling) already exist without a conserved heat solver.

### Planned requirements

- deterministic numeric representation;
- explicit conserved/non-conserved source semantics;
- active-only optional buffering;
- bounded tile/chunk transfer or stencil behavior;
- sleep/wake based on meaningful temperature change;
- phase-change integration through MaterialRules;
- replay-hash coverage;
- no hidden full-world conduction scan.

Numeric units, range, conduction model, cadence, and phase thresholds are undecided.

## Pressure and gas composition

Status: **Planned**.

Pressure/composition must eventually support sealed rooms, breaches, airlocks, smoke, fire, and vacuum without requiring full-resolution active gas simulation everywhere.

Possible coarse or hierarchical representations have been discussed, but none is approved. Any future design must specify:

- authority and conservation;
- relation to the existing material grid;
- resolution and coordinate mapping;
- tile/chunk boundary exchange;
- room/volume summary interaction;
- interest-region and sleeping behavior;
- gameplay collision/query semantics;
- replay and serialization;
- rendering derivation.

## Interaction ordering

The relative order of liquid, smoke, heat, phase change, pressure, chemistry, and electricity can change results. No production interaction sequence is approved.

Before adding a field, its ADR/specification must define:

- tick stage;
- read set and write set;
- transfer type or local stencil;
- conflict behavior;
- conservation invariant;
- wake/dirty effect;
- serialization/versioning;
- tests and profiling fixture.

## GPU extension seam

### Deferred / experimental

GPU compute may later suit:

- lighting or occlusion fields;
- non-authoritative visual diffusion;
- coarse derived previews;
- other GPU-resident fields whose CPU readback is not required every tick.

### Explicitly rejected for the current architecture

- GPU-only authoritative terrain state;
- Godot collision reading unsynchronized GPU state;
- per-tick GPU readback required for core gameplay authority;
- nondeterministic GPU results entering authoritative replay without an approved decision.

## Required validation per future field

- single-thread reference;
- deterministic replay;
- tile/chunk edge equivalence;
- field-specific conservation or bounded-error invariant;
- stable sleeping and wake propagation;
- current and 2× interest-region fixtures;
- worker utilization and stage timing;
- memory and allocation observations;
- serialization round trip once persistence exists;
- bridge snapshots that never expose mutable state.

## Related decisions

- [ADR-001](../decisions/ADR-001-native-simulation-core.md)
- [ADR-002](../decisions/ADR-002-double-buffered-tile-jobs.md)
- [ADR-006](../decisions/ADR-006-gpu-compute-deferral.md)
