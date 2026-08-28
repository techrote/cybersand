---
title: Architectural and simulation invariants
status: Approved design
scope: Stable identifiers for required ownership, timing, storage, transfer, rigid-body coupling, fidelity, bridge, water, capacity, testing, and GPU constraints
keywords: [invariant, authority, determinism, ownership, rigid body mask, fidelity, conservation, snapshot, capacity, thread safety]
related-documents: [../architecture/principles-and-non-goals.md, ../architecture/rigid-body-and-cellular-coupling.md, ../operations/rapier-2d-migration-runbook.md, interfaces-and-message-contracts.md]
last-reviewed: 2026-08-28
implementation-state: These are approved target invariants unless labelled Current; they are not claims that production enforcement exists.
---

# Architectural and simulation invariants

## At a glance

- Purpose: provide stable review and test anchors for safe changes.
- Every invariant carries an explicit status.
- **Current** invariants are limited to inspected behavior.
- **Approved design** invariants require implementation and validation before becoming Current.
- Violating an approved invariant requires an ADR, not an undocumented workaround.
- Numerical thresholds and final interfaces are intentionally absent.
- Use the validation column to locate the future evidence needed.

## Search anchors

authoritative owner invariant, worker thread invariant, transfer determinism, no allocation, water conservation, snapshot immutable, capacity expansion

## Current baseline invariants

| ID | Status | Invariant | Evidence/validation |
|---|---|---|---|
| CUR-001 | **Current** | CyberSimulationWorker exclusively advances the selected native CyberNativeCellWorld or unsupported-platform CyberCellWorld fallback plus sampled character on one Godot coordination thread. | godot/scripts/simulation_worker.gd |
| CUR-002 | **Current** | Current Godot main-thread rendering consumes copied snapshot bytes rather than reading CyberCellWorld directly. | simulation_worker.gd, simulation_snapshot.gd, main.gd |
| CUR-003 | **Current** | Native phased World sorts active cores, uses four parity phases, and merges job effects in sorted core order. | native/src/world.cpp, World::tick_phased |
| CUR-004 | **Current** | Native World defaults chunk_size to 128 but permits a configured size. | native/include/cybersand/world.hpp, WorldConfig |
| CUR-005 | **Current** | Bundled Linux/Windows x86_64 builds select native World as cellular authority through the GDExtension; the GDScript world is an alternative unsupported-platform fallback, never a synchronized second authority. | simulation_worker.gd, cyber_native_cell_world.cpp |
| CUR-006 | **Current** | Every valid native catalogue ID has an adapted executable RuleKernel with a declared maximum radius no greater than two. | material.hpp, world.cpp, catalogue test |
| CUR-007 | **Current** | Accepted external explosion commands commit at the next tick boundary in enqueue order and are included in state_hash until committed. | world.cpp, deferred explosion and worker-parity tests |
| CUR-008 | **Current** | A leased native render snapshot remains immutable; pressure/capacity failure cannot acknowledge or lose unpublished dirty state. | render_snapshot.cpp, immutable/concurrent/C lifetime tests |
| CUR-009 | **Current**, focused runtime validation passing | Three Rapier-backed RigidBody2D rectangle samples produce bounded swept reconciliation, a separate endpoint obstacle mask, and packed sample-keyed results; no live physics object crosses threads. | main.tscn, rapier_physics_bridge.gd, rigid_body_coupling.gd, simulation_worker.gd, cell_world.gd |
| CUR-010 | **Current** Godot source; runtime validation pending | Excess eligible 16×16 blocks are temporally distributed while the 3×3 interest neighbourhood remains full cadence and deferred blocks retain wake state. | cell_world.gd adaptive stride and block scheduling |
| CUR-011 | **Current**, focused runtime validation passing | A vertical move into Empty does not stamp the vacated source, allowing bottom-up chains to fill it instead of manufacturing alternate empty rows. | cell_world.gd, try_move, test_cell_world.gd |
| CUR-012 | **Current** | Themed IDs 38–80 are hard surfaces; inert entries have radius zero, Oak/Thatch alone reuse the radius-one combustible kernel, and all remain byte-sized identities. | material.hpp, material_rules.cpp, themed catalogue tests |
| CUR-013 | **Current** | Procedural flair consumes only immutable LUT data, world coordinates, and presentation time; it has no write path to authoritative Cell state. | material_appearance_lut.gd, material_palette.gdshader |
| CUR-014 | **Current** | Neighbour relief samples an alias of the already-uploaded immutable RG8 texture; it adds no authoritative state, world image, render publication byte, or CPU readback. | material_palette.gdshader, main.gd, RenderBridge regression |

These current facts are not all desired production invariants.

## Authority and module invariants

| ID | Status | Invariant | Required validation |
|---|---|---|---|
| AUTH-001 | **Approved design** | SimulationCore is the sole production authority for cell and simulation state through WorldStorage. | No duplicate production state; bridge integration test |
| AUTH-002 | **Approved design** | SimulationCore and native workers have no Godot API dependency. | Build/dependency audit; thread tests |
| MOD-001 | **Approved design** | SimulationScheduler coordinates time/work and does not own material policy. | Module/dependency review |
| MOD-002 | **Approved design** | MaterialRules owns immutable descriptors/rule data, not threads or per-cell containers. | API/dependency and allocation audit |
| MOD-003 | **Approved design** | WorldStorage owns chunk lifetime, activation, optional fields, capacities, and serialization. | Ownership tests and interface audit |

## Timing and threading invariants

| ID | Status | Invariant | Required validation |
|---|---|---|---|
| TIME-001 | **Approved design** | Authoritative state changes only on whole fixed simulation ticks or defined loading transitions. | Replay and command-boundary tests |
| THREAD-001 | **Current** standalone native | Native workers have no Godot dependency or object access. | Native dependency inspection and TSan suite |
| THREAD-002 | **Current**, tested scope | One/four-worker phased fixtures produce identical authoritative hashes. | Water, base, and complete-material replay tests |
| THREAD-003 | **Current** | Worker threads persist across ticks; there is no material-specific or per-tick thread creation. | PersistentWorkerPool source and tests |

## Spatial, buffer, and transfer invariants

| ID | Status | Invariant | Required validation |
|---|---|---|---|
| SPACE-001 | **Current** native defaults | Storage uses 128×128 chunks; activity and scheduling granularities default to 32×32 and 64×64. | Configuration, mapping tests, benchmark |
| PHASE-001 | **Current** | Same-phase in-place jobs have non-overlapping complete write domains. | Mechanical geometry and TSan tests |
| PHASE-002 | **Current**, runtime-declared | Phase order, scan order, deterministic streams, and descriptor radius are explicit; a type-enforced RuleContext remains Planned. | Replay, construction validation, radius metadata tests |
| BUF-001 | **Approved design** | buffering, where selected, is limited to active regions and required optional fields. | Memory/fixture inspection |
| BUF-002 | **Approved design** | a buffered job reads supplied state/views and writes only assigned output and transfer storage. | Isolation/edge tests |
| XFER-001 | **Approved design** | cross-output effects in the buffered backend are staged; phased local operations require ownership of every touched cell. | Boundary tests |
| XFER-002 | **Approved design** | transfer merge order is canonical and independent of worker timing. | Completion-order perturbation replay |

## Activity and interest invariants

| ID | Status | Invariant | Required validation |
|---|---|---|---|
| ACT-001 | **Current** native | Sleeping blocks retain committed authoritative state. | Sand/Water sleep and wake tests |
| ACT-002 | **Current**, bounded local scope | Writes and crossings wake local/edge-neighbor activity blocks. | Core/chunk crossing and wake tests |
| ACT-003 | **Approved design** | sleeping groups retain an observable/active boundary capable of receiving change. | Buried-volume wake fixture |
| INT-001 | **Approved design** | the initial interest region follows the camera-visible region plus 10% horizontal and 20% vertical margins. | Configuration/geometry test after semantics freeze |
| INT-002 | **Approved design** | leaving the interest region does not erase or alter committed state. | Pan-out/pan-in replay |

## Fidelity invariants

| ID | Status | Invariant | Required validation |
|---|---|---|---|
| FID-001 | **Approved design** | Approximation policies are explicit, bounded, observable, reversible, and assigned to a fidelity tier. | Configuration/metric and mode-switch fixtures |
| FID-002 | **Approved design** | Local known solid occupancy, ownership, closed-boundary conservation, and capacity failure cannot be probabilistically ignored. | Collision, conservation, race, and overflow fixtures |
| FID-003 | **Current** native tested scope | Strict validation mode can compare exact hashes for the Current phased fixtures even when gameplay permits approximate policies elsewhere. | Existing one/four-worker replay fixtures |
| FID-004 | **Explicitly rejected** | Naive spatial coarsening cannot create visible checkerboard holes or change the local interaction grid merely to meet a frame target. | Visual/topology fixtures before any spatial LOD |

## Bridge invariants

| ID | Status | Invariant | Required validation |
|---|---|---|---|
| BRIDGE-001 | **Approved design** | Godot never reads mutable SimulationCore or WorldStorage memory. | Binding/interface and concurrency tests |
| BRIDGE-002 | **Current** native publication and copied Godot adapter | Native consumers lease immutable dirty snapshots corresponding to a serialized post-mutation state; Godot receives copied RG8 patches and never mutable World memory. | Snapshot lifetime/dirty/pressure/concurrency tests plus focused Godot patch regression |
| BRIDGE-003 | **Approved design** | GameplayBridge commands enter at tick boundaries and results are immutable after publication. | Command/result contract tests |
| BRIDGE-004 | **Approved design** | render-only state cannot affect authoritative replay or wake behavior. | Hash isolation tests |
| BRIDGE-005 | **Current** Godot rectangle proof | Rigid-body Nodes/RIDs remain on Godot threads; only complete packed samples and immutable packed results cross the worker boundary. | Source audit; focused runtime coupling proof pending |
| BRIDGE-006 | **Current** source contract | Coordinate-hashed variation, LUT response, temporal blending, and glow are presentation-only; no derived colour, frame noise, or update epoch is written into authoritative cells. | Source audit and replay/hash isolation fixture |

## Rigid-body coupling invariants

| ID | Status | Invariant | Required validation |
|---|---|---|---|
| BODY-001 | **Current** Godot rectangle proof | Material identity and rigid-body occupancy are separate arrays; a body is never represented by temporarily erasing/restoring material cells. | Source audit and stationary-body flow fixture |
| BODY-002 | **Current** Godot rectangle proof | Material movement and painting cannot target an occupied body-mask cell. | Sand/liquid/gas and emission fixture |
| BODY-003 | **Current** Godot rectangle proof | Moved-body overlap resolution uses body/input order, cell order, and a bounded outward/tangential search; unresolved material is retained and counted. | Repeated overlap fixture; runtime pending |
| BODY-004 | **Approved design** | Impact, pressure, displacement, correction, and later torque observations are bounded and applied through immutable body identity, never worker access to live physics state. | Bridge/capacity/force-direction fixtures |
| BODY-005 | **Planned** | Motion capable of crossing a thin cellular obstacle between samples uses bounded substeps or a conservative swept representation with explicit overflow recovery. | High-speed translation/rotation fixtures |
| BODY-006 | **Approved design** | Rapier2D is the sole shipped rigid-body backend; the project has no production runtime backend toggle. | Dependency, project-setting, and export audit |
| BODY-007 | **Approved design** | A Rapier space is advanced by automatic stepping or explicit coupling-owned stepping, never both in one tick. | Step-count instrumentation and fixed-tick fixture |
| BODY-008 | **Approved design** | Explicit coupling reads authoritative Rapier server state; cached SceneTree transforms/callback timing cannot own the post-step result. | Manual-step, batch-transform, and delayed-callback fixtures |

## Capacity and allocation invariants

| ID | Status | Invariant | Required validation |
|---|---|---|---|
| CAP-001 | **Approved design** | interest dimensions and capacity budgets are explicit, serializable, and observable. | Configuration round trip |
| CAP-002 | **Approved design** | capacity budgets are reservations, not permanent architectural limits. | Larger safe-reconfiguration fixture |
| CAP-003 | **Current** for native task/snapshot storage; transfer storage **Planned** | Active job results and render snapshot slots are bounded/reused; future transfer storage must follow the same rule. | Preallocated tick plus snapshot pressure/high-water tests |
| CAP-004 | **Current**, native owned capacities | Chunk/active/job-effect overflow fails explicitly; no clipping or silent loss. | Capacity and preallocated tick tests |
| CAP-005 | **Approved design** | structural capacity changes occur only after affected workers/views are drained at a tick/loading boundary. | Reconfiguration concurrency test |

## Water invariants

| ID | Status | Invariant | Required validation |
|---|---|---|---|
| WATER-001 | **Current** for pure closed fixtures | Closed fixtures conserve 8-bit liquid mass exactly, including a storage boundary. | Per-tick mass assertions |
| WATER-002 | **Current** | Water mass occupies compact state in the material grid and creates no second authority. | Cell layout and transfer source |
| WATER-003 | **Current** | A source cannot emit more mass than available and a destination cannot exceed 255. | Transfer arithmetic and conservation tests |
| WATER-004 | **Current** | Adjacent mass within one unit does not transfer; settled hashes stabilize. | Settled-state observation fixture |
| WATER-005 | **Current** tested fixture | Connected Water levels across its container rather than retaining a history-limited heap. | Leveling fixture |
| WATER-006 | **Current** native rendering | Spatial/mass dither derives during RGBA copy and never mutates authority. | Stable content/mass tests and source audit |
| WATER-007 | **Current** Godot source; runtime validation pending | Coherent/calm emission survives gravity and density exchange, carries no free lateral budget, cannot spread while its vertical run is airborne, and pressure-levels by at most one lateral cell per update after support. Normal emission retains ordinary spray/edge behavior. | Manual falling-column and supported-leveling comparison |
| WATER-008 | **Current** Godot source; runtime validation pending | Surface adhesion is independent of viscosity/yield; disabling it stops unsupported lateral dispersion and look-ahead without disabling gravity/density. | Manual connected-slope comparison |

## GPU and rejected-approach invariants

| ID | Status | Invariant | Required validation |
|---|---|---|---|
| GPU-001 | **Approved design** | current planned terrain/collision authority remains CPU-native. | Architecture/dependency audit |
| GPU-002 | **Deferred / experimental** | a future GPU field begins non-authoritative unless superseded by an ADR. | Experiment-specific validation |
| REJ-001 | **Explicitly rejected** | no per-cell mutex scheme. | Code review |
| REJ-002 | **Explicitly rejected** | no material-specific threads or growing material inheritance hierarchy. | Code/module review |
| REJ-003 | **Explicitly rejected** | no full-stored-world double buffering. | Memory/storage review |
| REJ-004 | **Explicitly rejected** | no unbounded mixing of in-place and buffered writes to one field/stage without an explicit ownership contract. | Scheduler architecture review |

## Related decisions

- [ADR-001](../decisions/ADR-001-native-simulation-core.md)
- [ADR-002](../decisions/ADR-002-double-buffered-tile-jobs.md)
- [ADR-003](../decisions/ADR-003-godot-bridge-and-immutable-snapshots.md)
- [ADR-004](../decisions/ADR-004-interest-region-and-reconfiguration.md)
- [ADR-005](../decisions/ADR-005-water-model.md)
- [ADR-006](../decisions/ADR-006-gpu-compute-deferral.md)
- [ADR-007](../decisions/ADR-007-rigid-body-cellular-coupling.md)
- [ADR-008](../decisions/ADR-008-bounded-approximate-fidelity.md)
- [ADR-009](../decisions/ADR-009-rapier-2d-rigid-body-backend.md)
