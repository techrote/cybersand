---
title: Module boundaries
document-kind: design
canonical-for: [module-responsibilities-and-dependencies]
status: Approved design
scope: Approved responsibility boundaries mapped to current source; no claim that every named module is a class
keywords: [SimulationCore, SimulationScheduler, WorldStorage, TileJob, MaterialRules, RenderBridge, GameplayBridge]
related-documents: [overview.md, data-ownership-and-lifetimes.md, rendering-and-gameplay-bridges.md]
last-reviewed: 2026-09-08
---

# Module boundaries

## Where should new code belong?

**Approved:** use the responsibility map below when extending or extracting
the native engine. **Current:** `cybersand::World` combines storage, scheduling,
rules, activity and dirty tracking; the table does not assert separate C++
classes. Sources are [World declarations](../../native/include/cybersand/world.hpp)
and [implementation](../../native/src/world.cpp).

| Boundary | Approved responsibility | Current implementation and remaining separation |
|---|---|---|
| SimulationCore | Authoritative cell/field semantics and invariants | World kernels and tick entry; extraction remains incomplete |
| SimulationScheduler | Work planning, pool, barriers, deterministic coordination and overload metrics | `World::tick_phased`, `ParallelState`; desktop wall-clock pacing is still GDScript and Web owns synchronous callbacks |
| WorldStorage | Chunk lifetime, optional fields, activity and capacity; future persistence | `World::Chunk`, `chunks_`, reservation/query methods; general streaming and live resize are absent |
| TileJob | Temporary bounded work assignment and local observations | Core indices, `JobEffects`, local `TickStats`; no public type-enforced bounded rule context |
| MaterialRules | Immutable descriptors, traits and kernel selection | Descriptor/pair-reaction APIs are separate; executable kernels remain inside World |
| RenderBridge | Consume immutable simulation publication and update presentation | Native `RenderSnapshotExchange`, copied Godot packets and CPU-image consumer; GPU subregion writes are absent |
| GameplayBridge | Translate intent into tick-boundary data and immutable results | Narrow emission/input/body methods; generalized typed queues and pressure policy are absent |
| Rigid-body adapter | Own backend calls and translate body value data | `CyberRapierPhysicsBridge` plus native rectangle projection; general shape and torque interfaces are absent |

Adding a native class is justified when it establishes a usable responsibility
or lifetime boundary. A cosmetic rename is not architectural progress.

## Which dependencies are permitted?

**Approved:** the simulation remains executable without Godot. Core/storage/rule
headers must not depend on scene nodes, rendering objects, audio, UI, camera
paths or Rapier types. Rules may depend on immutable descriptors and supplied
bounded state access. They do not own threads or perform structural container
growth while workers hold views.

The scheduler may coordinate storage and core operations; it must not decide
material behavior. WorldStorage owns bytes and capacities, not whether Water
flows. Rendering consumes immutable publication; gameplay consumes data-only
contracts. Backend-specific Rapier RIDs remain inside the Godot adapter.

**Current:** native jobs execute internal World methods with runtime domain
checks. A restricted `RuleContext` that enforces these limits by type is
**Planned**. Do not describe that proposed context as an existing safe API.
New dependency cycles or shared ownership need an explicit architecture
decision, with the affected lifetimes identified first.

## What is already reusable without Godot?

The [C API](../../native/include/cybersand/c_api.h) exposes World creation,
bulk/query operations and snapshot leases. Native tests and benchmarks invoke
the same World. [MaterialRules](../../native/include/cybersand/material_rules.hpp)
exposes immutable lookup, density exchange, hard-surface traits and compact
oriented pair reactions. [RenderSnapshotExchange](../../native/include/cybersand/render_snapshot.hpp)
owns reusable publication slots independently of Godot.

The [Godot adapter](../../godot/native_extension/cyber_native_cell_world.cpp)
contains finite-demo setup, packed rectangle coupling and Godot value conversion.
Its existence does not make those integration responsibilities part of the
Godot-free core. Fixed-demo encoding is a separate
[level save contract](../reference/level-saves-and-replay.md), not the planned
general WorldStorage persistence module.

## How should a new field or feature cross these boundaries?

Assign its authoritative bytes to storage, its update rule to core/material
semantics, and its cadence/work to scheduling. Declare radius, optional-field
requirements and overflow behavior before adding a kernel. Cross-thread or
backend interaction uses a copied command/sample/result with an explicit
lifetime. Presentation receives derived immutable data.

For example, a future heat field requires storage and conduction semantics;
a heat-haze shader can instead derive appearance without becoming authoritative.
The same distinction applies to body forces versus body rendering. Detailed
rules live in [ownership](data-ownership-and-lifetimes.md),
[bridges](rendering-and-gameplay-bridges.md) and
[coupling](rigid-body-and-cellular-coupling.md).

## What remains undecided?

**Planned:** final class/API extraction, production command/result schemas,
stable generalized entity IDs, bounded public rule views, generalized
serialization and safe live reconfiguration. Their names are architectural
concepts; no signature or failure policy is approved by this page.

The rationale is recorded in [ADR-001](../decisions/ADR-001-native-simulation-core.md),
[ADR-002](../decisions/ADR-002-double-buffered-tile-jobs.md) and
[ADR-003](../decisions/ADR-003-godot-bridge-and-immutable-snapshots.md).
Runtime confidence must come from the [evidence ledger](../reference/validation-evidence.md).
