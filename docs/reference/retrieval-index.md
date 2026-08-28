---
title: Retrieval index
status: Current
scope: Question-to-document and query-to-anchor map for human and agentic retrieval, safe ingestion routes, source evidence, and change preparation
keywords: [RAG, retrieval index, question map, search anchor, agent context, safe change]
related-documents: [../README.md, glossary.md, status-and-roadmap.md]
last-reviewed: 2026-08-28
implementation-state: Maps the m9 GPU-flair checkpoint, including 42 material effects, neighbour relief, dual-radius bloom, F3 stats visibility, 1920x1080 output, and retained m8 temporal fidelity.
---

# Retrieval index

## At a glance

- Purpose: answer a project question with the smallest useful document set.
- Start with one mapped document, then follow only its related links.
- Consult status-and-roadmap before assuming a named module exists.
- Consult source paths cited by a Current claim before editing code.
- Approved contracts describe constraints, not final C++ APIs.
- Use invariants and ADRs before changing ownership or scheduling.
- Use troubleshooting for symptoms and testing for acceptance evidence.

## Search anchors

question to document, rapid context, RAG route, which file explains, safe agent ingestion, minimal reading set

## Required question map

| Question/query | Primary document | Supporting document | Short answer |
|---|---|---|---|
| Which thread owns authoritative cell state? | [Data ownership](../architecture/data-ownership-and-lifetimes.md) | [Overview](../architecture/overview.md) | **Current**: Godot worker owns CyberCellWorld; native World separately owns native chunks. **Approved design**: SimulationCore/WorldStorage authority, coordinated by SimulationScheduler. |
| Can Godot access simulation memory directly? | [Rendering and gameplay bridges](../architecture/rendering-and-gameplay-bridges.md) | [ADR-003](../decisions/ADR-003-godot-bridge-and-immutable-snapshots.md) | No. The **Current** Godot adapter consumes copied immutable dirty RG8 patches; mutable World memory never crosses the bridge. |
| How are cross-tile transfers ordered? | [Determinism and transfers](../architecture/determinism-and-boundary-transfers.md) | [ADR-002](../decisions/ADR-002-double-buffered-tile-jobs.md) | Canonical deterministic order is required; the exact ordering tuple is not approved. |
| What happens when capacity is exceeded? | [Configuration and capacity](../operations/configuration-and-capacity-budgets.md) | [ADR-004](../decisions/ADR-004-interest-region-and-reconfiguration.md) | Explosion enqueue rejects full/invalid input; snapshots retain dirty state and report pressure/exact requirements. General live resize remains Planned; never clip or allocate secretly. |
| How do I change the interest-region size? | [World storage and interest region](../systems/world-storage-and-interest-region.md) | [Configuration reference](configuration-reference.md) | Native callers can reserve explicit regions before ticking; persistent dimensions and safe live reconfiguration remain Planned. |
| Why is GPU compute deferred? | [ADR-006](../decisions/ADR-006-gpu-compute-deferral.md) | [Smoke/heat/pressure roadmap](../systems/smoke-heat-pressure-roadmap.md) | Terrain/collision authority, readback, replay, and synchronization are not ready; non-authoritative GPU fields may be benchmarked later. |
| How do I debug water shimmer? | [Water design](../systems/water-design.md) | [Troubleshooting](../operations/troubleshooting.md) | Determine whether state/hash changes. Fix authoritative flux/rest in the reference; adjust rendering only if state is stable. |
| Where may material rules allocate memory? | [Materials and rule kernels](../systems/materials-and-rule-kernels.md) | [Principles](../architecture/principles-and-non-goals.md) | Not in hot kernels. Preparation/reconfiguration may allocate explicitly; exact allocator API is undecided. |
| How is deterministic replay tested? | [Testing and replay](../operations/testing-validation-and-replay.md) | [Determinism](../architecture/determinism-and-boundary-transfers.md) | Repeated and one/four-worker phased fixtures compare exact state hashes; a stored/versioned replay format remains Planned. |
| Why is Sandspiel fast? | [Sandspiel performance study](../research/sandspiel-performance-and-material-port.md) | [Profiling and observability](../operations/profiling-observability-and-performance.md) | Compact native cells, bounded rules, aggressive release optimization, and packed texture input; its 300×300 dense serial world is not our scaling architecture. |
| Are the Sandspiel materials playable? | [Sandspiel material port ledger](../research/sandspiel-performance-and-material-port.md) | [Material lab](../MATERIAL_LAB.md) | All valid catalogue IDs and the extended reaction-lab families have adapted executable native kernels in bundled Linux/Windows x86_64 builds; exact Sandspiel evolution is not claimed. |
| Can equipment define unique particle behavior visually? | [Item-authored material programs](../architecture/item-authored-material-programs.md) | [Materials and rule kernels](../systems/materials-and-rule-kernels.md) | **Planned**: an item-owned recipe graph compiles to a statically bounded native program; arbitrary per-cell JavaScript is rejected. |
| How does physics drive material colour and glow? | [Material appearance and rendering](../systems/material-appearance-and-rendering.md) | [Rendering and gameplay bridges](../architecture/rendering-and-gameplay-bridges.md) | **Current**: RG8 dirty patches carry material plus a read-only condition projection; palette/program LUTs, stable coordinate variation, temporal smoothing, and bounded glow execute in presentation only. |
| Which materials build a castle, village, factory, or alley? | [Themed construction materials](../systems/themed-construction-materials.md) | [Material lab](../MATERIAL_LAB.md) | IDs 38–80 provide 43 hard-surface construction materials; 41 are inert radius-zero solids, Oak/Thatch burn, and bounded GPU flair supplies architectural texture and neon/LED effects. |
| How are explosions and collapsing terrain handled? | [Determinism and transfers](../architecture/determinism-and-boundary-transfers.md) | [Materials and rule kernels](../systems/materials-and-rule-kernels.md) | A bounded tick-boundary queue removes the core and tags eligible Wall as granular Stone; generalized fracture bodies remain Planned, while a separate rectangular RigidBody2D coupling proof is Current. |
| Can cellular material pass through a rigid body while its transform changes? | [Rigid-body coupling](../architecture/rigid-body-and-cellular-coupling.md) | [ADR-007](../decisions/ADR-007-rigid-body-cellular-coupling.md) | The Current Godot proof rasterizes a separate start-of-sample obstacle mask; it does not erase/restore body pixels in the material grid. |
| Which rigid-body backend is selected? | [ADR-009](../decisions/ADR-009-rapier-2d-rigid-body-backend.md) | [Rapier migration runbook](../operations/rapier-2d-migration-runbook.md) | Rapier2D v0.35.2 is the sole runtime backend. It is pinned, vendored, selected, manually stepped, and focused fixtures pass on Godot 4.7 Linux x86_64. |
| How will Rapier and cellular physics share a tick? | [Rapier migration runbook](../operations/rapier-2d-migration-runbook.md) | [Rigid-body coupling](../architecture/rigid-body-and-cellular-coupling.md) | Establish a drop-in baseline, then explicitly apply cell impulses, step Rapier, fetch transforms in bulk, reconcile swept occupancy, flush once, and publish. |
| How does pixel material push a rigid body? | [Rigid-body coupling](../architecture/rigid-body-and-cellular-coupling.md) | [Interfaces](interfaces-and-message-contracts.md) | Attempted impacts, density-derived boundary pressure, and displacement reaction accumulate capped packed impulses; Wall overlap returns positional correction. |
| What happens when a body overlaps pixels after movement? | [Rigid-body coupling](../architecture/rigid-body-and-cellular-coupling.md) | [ADR-007](../decisions/ADR-007-rigid-body-cellular-coupling.md) | Movable cells use a bounded ordered outward/tangent ejection search; unresolved cells remain and are counted, while particles remain Planned. |

## Architecture and ownership queries

| Likely query | Read |
|---|---|
| What modules are approved? | [Module boundaries](../architecture/module-boundaries.md) |
| Does SimulationCore exist? | [Status and roadmap](status-and-roadmap.md) |
| Why are there two worlds? | [Architecture overview](../architecture/overview.md) |
| Who owns optional fields? | [Data ownership](../architecture/data-ownership-and-lifetimes.md) |
| Can a TileJob write a neighbor? | [Chunk/tile/buffer model](../architecture/chunk-tile-and-buffer-model.md) |
| What is explicitly rejected? | [Principles and non-goals](../architecture/principles-and-non-goals.md) |
| What crosses the Godot/native boundary? | [Interfaces and contracts](interfaces-and-message-contracts.md) |
| What code is actually Current? | [Status and roadmap](status-and-roadmap.md) |

## Threading and performance queries

| Likely query | Read |
|---|---|
| Why does the current build use one core? | [Troubleshooting](../operations/troubleshooting.md) |
| What is the approved tick sequence? | [Simulation tick and threading](../architecture/simulation-tick-and-threading.md) |
| Which buffers are read/write per stage? | [Data ownership](../architecture/data-ownership-and-lifetimes.md) |
| How is worker completion order isolated? | [Determinism and transfers](../architecture/determinism-and-boundary-transfers.md) |
| What metrics must be exposed? | [Profiling and observability](../operations/profiling-observability-and-performance.md) |
| How is Rapier2D installed and activated? | [Rapier migration runbook](../operations/rapier-2d-migration-runbook.md) |
| What does high-water mean? | [Glossary](glossary.md) |
| Why not use per-cell locks? | [Principles](../architecture/principles-and-non-goals.md) |
| Is the 2× target a permanent limit? | [ADR-004](../decisions/ADR-004-interest-region-and-reconfiguration.md) |
| Can rendering run independently from cellular physics? | [Simulation tick and threading](../architecture/simulation-tick-and-threading.md) |
| How does the proof avoid a wake-up frame spike? | [Profiling and observability](../operations/profiling-observability-and-performance.md) and [ADR-008](../decisions/ADR-008-bounded-approximate-fidelity.md) |
| Why not merge visible cells into 2×2 voxels? | [ADR-008](../decisions/ADR-008-bounded-approximate-fidelity.md) |
| Where may probabilistic rules be used? | [ADR-008](../decisions/ADR-008-bounded-approximate-fidelity.md) and [Principles](../architecture/principles-and-non-goals.md) |

## Water and material queries

| Likely query | Read |
|---|---|
| How does current Water prevent piles while paste may retain them? | [Water design](../systems/water-design.md) |
| Where is liquid viscosity/flow speed configured? | [Configuration reference](configuration-reference.md) and [Water design](../systems/water-design.md) |
| How do normal spray and coherent/calm material emission differ? | [Water design](../systems/water-design.md) and [Interfaces](interfaces-and-message-contracts.md) |
| How can a liquid opt out of slope adhesion? | [Water design](../systems/water-design.md) and [Configuration reference](configuration-reference.md) |
| How does Smoke pass through Water or Sand? | [Smoke/heat/pressure roadmap](../systems/smoke-heat-pressure-roadmap.md) |
| How is dither preserved without shimmer? | [Water design](../systems/water-design.md) |
| Is fixed-point width decided? | [Water design](../systems/water-design.md) |
| What must water conserve? | [Invariants](invariants.md) |
| Why not use a general fluid solver first? | [ADR-005](../decisions/ADR-005-water-model.md) |
| How do I add a complex material? | [Materials and rule kernels](../systems/materials-and-rule-kernels.md) |
| How would a visual item-material editor work? | [Item-authored material programs](../architecture/item-authored-material-programs.md) |
| What exists for smoke/heat/pressure? | [Smoke/heat/pressure roadmap](../systems/smoke-heat-pressure-roadmap.md) |
| Can liquids use a separate world grid? | [ADR-005](../decisions/ADR-005-water-model.md) |
| Where is the Lava/Oil/Fungus/Rocket interaction inventory? | [Sandspiel material port ledger](../research/sandspiel-performance-and-material-port.md) |
| Why was Sandspiel Water not copied literally? | [Sandspiel performance study](../research/sandspiel-performance-and-material-port.md) |

## Storage, activity, and rendering queries

| Likely query | Read |
|---|---|
| Are buried volumes slept? | [Activity and waking](../systems/activity-dirty-regions-and-waking.md) |
| What wakes a neighbor? | [Activity and waking](../systems/activity-dirty-regions-and-waking.md) |
| What is 128×128 versus 32×32? | [Chunk/tile/buffer model](../architecture/chunk-tile-and-buffer-model.md) |
| How does camera panning affect simulation? | [World storage and interest region](../systems/world-storage-and-interest-region.md) |
| Why are dirty and active different? | [Activity and waking](../systems/activity-dirty-regions-and-waking.md) |
| Why is full texture upload still expensive? | [Material appearance and rendering](../systems/material-appearance-and-rendering.md) and [Troubleshooting](../operations/troubleshooting.md) |
| How long does a snapshot live? | [Interfaces and contracts](interfaces-and-message-contracts.md) |
| What happens when all snapshot slots are leased? | [Rendering and gameplay bridges](../architecture/rendering-and-gameplay-bridges.md) |
| Is world serialization implemented? | [Status and roadmap](status-and-roadmap.md) |

## Testing and change-safety queries

| Likely query | Read |
|---|---|
| What tests currently exist? | [Testing and replay](../operations/testing-validation-and-replay.md) |
| What blocks native Water integration into Godot? | [ADR-005](../decisions/ADR-005-water-model.md) |
| What remains after native multithreading? | [ADR-002](../decisions/ADR-002-double-buffered-tile-jobs.md) |
| How do I test capacity expansion? | [Testing and replay](../operations/testing-validation-and-replay.md) |
| What must every checkpoint document? | [Status and roadmap](status-and-roadmap.md) |
| Which invariants does this change touch? | [Invariants](invariants.md) |
| Which decisions require an ADR to reverse? | [Decisions directory](../decisions/) |
| What unresolved design choices remain? | [Status and roadmap](status-and-roadmap.md) |

## Minimal ingestion routes

### Before any implementation change

1. [Status and roadmap](status-and-roadmap.md)
2. the primary subsystem document
3. [Invariants](invariants.md)
4. related ADR
5. cited Current source file

### Before scheduler/threading work

1. [Simulation tick and threading](../architecture/simulation-tick-and-threading.md)
2. [Data ownership](../architecture/data-ownership-and-lifetimes.md)
3. [Determinism and transfers](../architecture/determinism-and-boundary-transfers.md)
4. [ADR-002](../decisions/ADR-002-double-buffered-tile-jobs.md)
5. [Testing and replay](../operations/testing-validation-and-replay.md)

### Before water work

1. [Water design](../systems/water-design.md)
2. [ADR-005](../decisions/ADR-005-water-model.md)
3. [Materials and rule kernels](../systems/materials-and-rule-kernels.md)
4. [Determinism and transfers](../architecture/determinism-and-boundary-transfers.md)
5. [Testing and replay](../operations/testing-validation-and-replay.md)

### Before Godot bridge work

1. [Rendering and gameplay bridges](../architecture/rendering-and-gameplay-bridges.md)
2. [Interfaces and contracts](interfaces-and-message-contracts.md)
3. [ADR-003](../decisions/ADR-003-godot-bridge-and-immutable-snapshots.md)
4. [Data ownership](../architecture/data-ownership-and-lifetimes.md)

### Before rigid-body coupling work

1. [Rigid-body and cellular coupling](../architecture/rigid-body-and-cellular-coupling.md)
2. [ADR-007](../decisions/ADR-007-rigid-body-cellular-coupling.md)
3. [Data ownership](../architecture/data-ownership-and-lifetimes.md)
4. [Interfaces and contracts](interfaces-and-message-contracts.md)
5. [ADR-008](../decisions/ADR-008-bounded-approximate-fidelity.md)

## Agent safety checklist

- Do not turn an Approved design statement into a Current claim without source and validation.
- Do not invent missing C++ signatures, serialized keys, metric names, numeric thresholds, or pressure policies.
- Do not infer native fixed-point semantics from the separate discrete Godot Water model.
- Do not refactor unrelated Godot gameplay/render code during backend checkpoints.
- Do not combine deferred scheduler or GPU experiments with the approved first backend.
- Report unresolved assumptions instead of silently selecting them.

## Related decisions

- [Documentation index](../README.md)
- [Glossary](glossary.md)
- [Status and roadmap](status-and-roadmap.md)
