---
title: Architecture overview
status: Approved design
scope: Top-level module ownership, data flow, and separation of current prototype code from the approved backend
keywords: [SimulationCore, SimulationScheduler, WorldStorage, TileJob, MaterialRules, RenderBridge, GameplayBridge, rigid body mask, fidelity]
related-documents: [module-boundaries.md, data-ownership-and-lifetimes.md, rigid-body-and-cellular-coupling.md, ../reference/status-and-roadmap.md]
last-reviewed: 2026-08-27
implementation-state: Native World is the preferred Linux and Windows x86_64 Godot cellular authority through CyberNativeCellWorld; the bridge publishes dirty RG8 material/condition patches, while Rapier2D remains manually stepped through packed samples/results and a separate native transient obstacle field.
---

# Architecture overview

## At a glance

- Purpose: define the intended ownership boundaries without claiming they already exist.
- **Current**: a dedicated Godot pacing thread invokes native World, whose four-phase scheduler uses a persistent worker pool; CyberCellWorld is the unsupported-platform fallback.
- **Current**: Godot rendering repeats the newest immutable snapshot independently while excess non-local activity is temporally distributed.
- **Current**: three RigidBody2D rectangles project a separate worker-owned collision mask and receive packed coupling observations.
- **Current**: cybersand::World has sparse storage, four-phase scheduling, a persistent worker pool, executable compact rules, and a bulk `godot-cpp` adapter.
- **Current**: World is authoritative for standalone native tests, benchmarks, and C API consumers.
- **Current**: native render publication has bounded reusable leases and a Godot adapter that consumes dirty RG8 material/condition patches.
- **Current**: the GPU derives material variation, bounded condition response, 42 material flair programs, neighbour relief, HDR emission, and dual-radius glow from immutable presentation data.
- **Current**, platform partial: native binaries are bundled for Linux and Windows x86_64; Linux runtime fixtures pass and the Windows DLL is cross-built and PE-validated but not launched here.
- **Approved design**: Godot communicates only through RenderBridge and GameplayBridge.
- **Current**: Rapier2D owns sandbox rigid-body physics and is explicitly stepped by the main-thread coupling bridge.
- Non-goal: this document does not define final C++ signatures or serialized schemas.

## Search anchors

authoritative cell state, native backend, Godot bridge, module data flow, which implementation exists, current versus target

## Approved module and data flow

~~~mermaid
flowchart LR
    G["Godot main thread<br/>scenes, input, UI, rendering"] --> GB["GameplayBridge<br/>queued commands"]
    GB --> SS["SimulationScheduler<br/>fixed tick + worker pool"]
    SS --> TJ["Bounded jobs<br/>phased ownership or isolated outputs"]
    TJ --> SS
    SS --> SC["SimulationCore<br/>authoritative rules and commit"]
    SC <--> WS["WorldStorage<br/>chunks, activation, serialization"]
    SC --> MR["MaterialRules<br/>immutable descriptors + kernels"]
    SS --> RB["RenderBridge<br/>immutable dirty snapshots"]
    RB --> G
    SS --> GB
~~~

The arrows identify permitted information flow, not implemented C++ APIs.

## Current repository architecture

| Area | Status | Repository evidence | What exists |
|---|---|---|---|
| Runnable simulation | **Current** | godot/native_extension and native/src/world.cpp | CyberNativeCellWorld owns native World for bundled Linux and Windows x86_64 builds; CyberCellWorld is an unsupported-architecture fallback. |
| Worker boundary | **Current** | godot/scripts/simulation_worker.gd | CyberSimulationWorker owns the selected world and character on one pacing Thread; native World owns its internal workers. |
| Godot rigid-body coupling | **Current** | rigid_body_coupling.gd, rapier_physics_bridge.gd, cell_world.gd, main.gd, and main.tscn | Three rectangles use direct Rapier state, bounded swept displacement, an endpoint mask, and packed impact/pressure/ejection/correction results. |
| Rapier2D backend | **Current**, export validation partial | godot/addons/godot-rapier2d, third_party/rapier2d.lock.json, project.godot, and focused tests | Official v0.35.2 2D add-on is vendored and selected; Linux x86_64 preflight, automatic-step, manual-step, and scene smoke fixtures pass. |
| Godot bounded fidelity | **Current** | simulation_worker.gd, native World, and material_palette.gdshader | Native activity sleeping/interest filtering keep material full-rate; renderer can temporally blend immutable snapshots. |
| Published frame state | **Current** | godot/scripts/simulation_snapshot.gd | Copied dirty RG8 patch arrays and character state are published by convention as immutable. |
| Rendering | **Current** | godot/scripts/main.gd, material_appearance_lut.gd, and Godot shaders | Godot patches a persistent RG8 image from dirty native payloads, uploads the full backing texture, and derives palette variation, condition, 42 flair classes, neighbour relief, and HDR bloom on the GPU. |
| Native simulation | **Current** | native/include/cybersand/world.hpp and native/src/world.cpp | World owns sparse chunks, 32×32 activity blocks, serial/phased backends, a persistent pool, conserved Water, and optional temperature storage. |
| Native material catalogue boundary | **Current** | native/include/cybersand/material_rules.hpp and native/src/world.cpp | MaterialRules exposes immutable descriptors; World dispatches bounded deterministic kernels for every valid catalogue ID. |
| Native render publication | **Current** | native/include/cybersand/render_snapshot.hpp and native/src/render_snapshot.cpp | Reusable slots publish deterministic dirty material/condition patches; immutable leases survive producer progress and report pressure/high-water. |
| Godot/native adapter | **Current**, partial | godot/native_extension and addons/cybersand_native | Copied dirty render patches, emissions, queries, metrics, and packed body coupling exist; true GPU subregion writes, generalized queues, and other architectures remain planned. |
| Remaining production module boundaries | **Approved design** | Current responsibilities are combined inside World | RenderBridge, GameplayBridge, persistence, and safe reconfiguration remain separate planned modules; extraction from World must preserve tested behavior. |

## Authority model

### Current

For bundled Linux and Windows x86_64 builds, CyberNativeCellWorld owns
cybersand::World as the authoritative cellular state. CyberCellWorld is selected
only when the native class is unavailable. The two solvers are alternatives,
not synchronized copies, so fallback results and performance are not claimed to
match the native runtime.

Rapier-backed RigidBody2D objects are authoritative only for external body
transforms in the Current Godot proof. Their endpoint mask is a copied collision
view, not a second material grid; a temporary swept mask exists only during
overlap reconciliation.

### Approved design

SimulationCore owns authoritative cell and optional-field state through WorldStorage. SimulationScheduler controls when that state may change. TileJob workers receive only the tick inputs and storage views permitted for their stage.

RenderBridge and GameplayBridge do not own simulation truth:

- RenderBridge consumes an immutable dirty snapshot.
- GameplayBridge queues commands for a tick boundary and consumes immutable results.
- Godot objects, scene nodes, audio objects, physics objects, and rendering resources never become worker-owned simulation data.

## Storage and work hierarchy

| Concept | Status | Definition |
|---|---|---|
| storage chunk | **Current** native default | 128×128 allocation and metadata unit; serialization/streaming are not implemented. |
| activity block | **Current** native default | 32×32 work-elimination, sleep, and local wake unit. |
| scheduling core | **Current** native default | 64×64 parity-colored core evaluated in four phased passes. |
| owned write domain | **Current** | Core rectangle expanded by the configured maximum rule radius; same-phase overlap is rejected by geometry tests. |
| buffered output/transfer | **Planned** retained candidate | Enum is reserved; no buffered tick implementation exists. |

## Tick-level flow

The approved flow is:

1. SimulationScheduler reaches a fixed-tick boundary.
2. Queued gameplay commands and any permitted interest-region change are latched.
3. Active work and the selected backend's jobs are constructed deterministically.
4. The leading backend executes four phases of non-overlapping in-place jobs with a barrier after each.
5. Buffered fields/backends execute isolated outputs and merge transfers deterministically when selected.
6. Bounded long-range/structural events resolve before authoritative activity, wake, and dirty state is finalized; explosion events are **Current**.
7. Immutable gameplay results and immutable dirty snapshots are published; native render snapshots and copied Godot consumption are **Current**, while generalized gameplay results remain **Planned**.
8. Godot consumes published data on permitted Godot threads.

When rigid-body coupling is selected, a stable start-of-stage body sample and
separate occupancy view precede local cellular execution; packed observations
return after completion. See [Rigid-body and cellular coupling](rigid-body-and-cellular-coupling.md).

Current phase assignment is global core-coordinate parity, phase order rotates by tick,
rows scan bottom-up, and horizontal direction alternates deterministically. The
Current explosion queue commits in enqueue order and is included in state hashes.
General deferred-event schemas, buffered transfer ordering, and command overload
behavior remain unresolved. Native snapshot pressure is non-blocking: publication
retains dirty state and reports Backpressure or CapacityExceeded.

## Extensibility seams

- **Current**: Smoke and the attributed material catalogue run through compact bounded RuleKernel families.
- **Current** minimal storage: temperature is optional per chunk; conduction is **Planned**.
- **Planned**: pressure/composition use optional active-chunk fields rather than permanent arrays for every stored cell.
- **Deferred / experimental**: GPU compute may host suitable non-authoritative fields once synchronization cost and determinism are measured.
- **Deferred / experimental**: alternative work topologies, including hexagonal grouping, require isolated benchmarks and cannot alter storage authority without an ADR.

## Related decisions

- [ADR-001](../decisions/ADR-001-native-simulation-core.md)
- [ADR-002](../decisions/ADR-002-double-buffered-tile-jobs.md)
- [ADR-003](../decisions/ADR-003-godot-bridge-and-immutable-snapshots.md)
- [ADR-004](../decisions/ADR-004-interest-region-and-reconfiguration.md)
- [ADR-007](../decisions/ADR-007-rigid-body-cellular-coupling.md)
- [ADR-008](../decisions/ADR-008-bounded-approximate-fidelity.md)
- [ADR-009](../decisions/ADR-009-rapier-2d-rigid-body-backend.md)
