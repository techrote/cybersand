---
title: Architectural principles and non-goals
status: Approved design
scope: Hard rules, reasons, prohibited shortcuts, and deliberately postponed scope
keywords: [technical debt, coupling, allocation, mutex, Godot threads, GPU authority, non-goals]
related-documents: [overview.md, module-boundaries.md, ../reference/invariants.md]
last-reviewed: 2026-08-27
implementation-state: These rules govern future implementation; strict native replay and partial bounded-approximation behavior are Current, while production fidelity controls remain incomplete.
---

# Architectural principles and non-goals

## At a glance

- Purpose: prevent performance work from creating hidden ownership or long-term coupling.
- **Approved design**: native C++ owns authoritative simulation state.
- **Approved design**: fixed simulation quanta, race-free ownership, bounded work/buffers, and explicit failure behavior are mandatory.
- **Approved design**: bit-exact replay is a strict validation mode, not a universal gameplay-fidelity requirement.
- **Explicitly rejected**: per-cell locks, one class or thread per material, full-world double buffers, and mutable render reads.
- **Approved design**: phased in-place and buffered scheduler candidates remain isolated during their benchmark gate.
- **Deferred / experimental**: GPU compute remains an isolated experiment.
- Non-goal: perfect physical simulation of every visible pixel.
- Non-goal: refactoring unrelated Godot gameplay while replacing the backend.

## Search anchors

no Godot API on workers, no per-cell mutex, no hot allocation, no full-world copy, no material subclasses, no premature GPU, technical debt rules

## Hard architectural rules

| Rule | Status | Why it exists | Failure prevented |
|---|---|---|---|
| SimulationCore is native C++ and has no Godot API dependency. | **Approved design** | Keeps simulation independently testable and portable. | Scene/runtime coupling and untestable worker code. |
| Godot scene-tree, rendering, audio, and gameplay-object access stays off simulation workers. | **Approved design** | Godot object access has thread and lifetime constraints. | Races, invalid object access, and frame-dependent behavior. |
| Simulation state changes only on fixed ticks. | **Approved design** | Decouples physics from render rate. | Variable-rate physics and replay divergence. |
| Worker completion timing never decides write ownership or conflict resolution. | **Approved design** | Approximate gameplay may sample work, but thread races must not become a hidden rule. | Race-dependent corruption and irreproducible ownership. |
| Strict validation mode preserves deterministic phase, job, transfer, and deferred-event results. | **Current**, native tested scope; broader mode **Approved design** | Exact replay remains a powerful regression oracle without constraining every gameplay approximation. | Losing the ability to localize solver regressions. |
| Gameplay fidelity may reduce distant/slow work through explicit bounded policies while preserving local collision and conservation invariants. | **Approved design** | Frame-rate stability is a gameplay requirement. | Single-digit FPS when large regions wake. |
| Godot reads immutable snapshots only. | **Current** native publication and copied Godot adapter | Presentation must never race simulation writes. | Tearing, locks around the renderer, and undefined reads. |
| Buffering, where selected, is restricted to active regions and required fields. | **Approved design** | World scale must not imply full-world copy cost. | Memory growth proportional to all stored cells. |
| Hot-path task and snapshot buffers are bounded and reused; transfer buffers follow when implemented. | **Current** task/snapshot scope; transfer **Planned** | Makes latency and memory pressure observable. | Allocator stalls and unbounded memory growth. |
| Capacity overflow is diagnosed explicitly. | **Approved design** | Requested scale must fail or reconfigure visibly. | Silent clipping, hidden allocation, or corrupted output. |
| Material behavior uses descriptors and compact rule kernels. | **Approved design** | Keeps behavior data-oriented and schedulable. | Deep inheritance, virtual-call hot paths, and material-specific orchestration. |
| Work is introduced through reversible checkpoints. | **Approved design** | Limits regression scope. | Large migrations with no valid rollback state. |

## Explicitly rejected approaches

### Per-cell mutexes

Status: **Explicitly rejected**. Lock storage and contention would dominate cell work. Phased exclusive ownership or buffered output isolation provides the synchronization boundary instead.

### One thread or class hierarchy per material

Status: **Explicitly rejected**. Materials share scheduler infrastructure. A new material may select descriptor data and a compact kernel family, but does not own a worker or an expanding inheritance tree.

### Full-world double buffering

Status: **Explicitly rejected**. Stored but inactive regions may be much larger than the interest region. Buffering the entire world would convert an activity-scaled design into a world-size-scaled design.

### Mutable rendering reads

Status: **Explicitly rejected**. RenderBridge may not expose pointers or references into mutable SimulationCore or WorldStorage memory.

### Hidden hot-path allocation

Status: **Explicitly rejected**. Buffer exhaustion must produce diagnostics and follow an approved failure or tick-boundary reconfiguration path. It must not silently allocate, clip, or drop authoritative work.

### Unbounded mixed scheduler ownership

Status: **Explicitly rejected**. The phased and buffered candidates may coexist only at an explicit backend or field boundary. One cell field cannot be mutated in place and through a next buffer in the same stage without a separately approved ownership contract.

### Current GPU terrain authority

Status: **Explicitly rejected**. GPU compute is not presently the authority for terrain, gameplay collision, or deterministic world state.

## Current prototype exceptions

| Exception | Status | Evidence |
|---|---|---|
| CyberCellWorld mutates a finite cell array in place. | **Current** | godot/scripts/cell_world.gd |
| The native World also updates chunks in place and can allocate chunks during movement. | **Current** | native/src/world.cpp, World::tick and ensure_chunk |
| Simulation executes on one Godot worker, not a native pool. | **Current** | godot/scripts/simulation_worker.gd |
| Changed Godot revisions duplicate and upload the whole finite cell array. | **Current** | simulation_worker.gd and main.gd |
| Material behavior is implemented through switches. | **Current** | native/src/world.cpp and cell_world.gd |
| The GDScript proof temporally distributes excess active blocks and sparsely samples broad liquid pressure searches. | **Current** | godot/scripts/cell_world.gd |
| The Godot renderer consumes immutable worker snapshots independently of worker tick completion. | **Current** | godot/scripts/simulation_worker.gd and main.gd |

These are evidence about the prototype, not approved precedents for the production backend.

## Non-goals

- **Approved design**: perfect per-pixel physics is not required; conservation, stability, visual plausibility, and gameplay consistency take priority.
- **Planned**: vehicles, computers, atmosphere, chemistry, and world-generation features should consume stable simulation interfaces rather than delay core architecture.
- **Approved design**: temporal fidelity scaling and lower-resolution optional/distant fields may protect gameplay frame rate under explicit metrics and invariants.
- **Explicitly rejected**: naive 2×2 or larger coarsening of the local visible material occupancy grid.
- **Deferred / experimental**: hexagonal grouping may be evaluated as a work/coarse-field topology, but the approved storage hierarchy remains rectilinear 128×128 chunks and 32×32 tiles.
- **Deferred / experimental**: a general fluid solver is not the first liquid implementation.
- **Explicitly rejected**: unrelated gameplay or render refactors during backend checkpoints.

## Review questions for every change

1. Which module owns the modified data?
2. Which stage may write it?
3. Can a worker observe mutable state owned elsewhere?
4. Does ownership or conflict resolution depend on thread timing?
5. Can the hot path allocate?
6. What happens when capacity is exceeded?
7. Which metric exposes the cost?
8. Which strict replay, conservation, collision, or visual-plausibility fixture detects regression?
9. Which fidelity tier does the change affect, and is that policy observable?
10. Can the checkpoint be rolled back without undoing unrelated work?

## Related decisions

- [ADR-001](../decisions/ADR-001-native-simulation-core.md)
- [ADR-002](../decisions/ADR-002-double-buffered-tile-jobs.md)
- [ADR-003](../decisions/ADR-003-godot-bridge-and-immutable-snapshots.md)
- [ADR-006](../decisions/ADR-006-gpu-compute-deferral.md)
- [ADR-007](../decisions/ADR-007-rigid-body-cellular-coupling.md)
- [ADR-008](../decisions/ADR-008-bounded-approximate-fidelity.md)
