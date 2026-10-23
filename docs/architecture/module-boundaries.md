---
title: Module boundaries
document-kind: design
canonical-for: [module-responsibilities-and-dependencies]
status: Approved design
scope: Approved responsibility boundaries mapped to current source; no claim that every named module is a class
keywords: [SimulationCore, SimulationScheduler, WorldStorage, TileJob, MaterialRules, RenderBridge, GameplayBridge]
related-documents: [overview.md, data-ownership-and-lifetimes.md, rendering-and-gameplay-bridges.md]
last-reviewed: 2026-10-21
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
| WorldStorage | Chunk lifetime, optional fields, activity and capacity; future persistence | `World::Chunk`, `chunks_`, reservation/query methods and explicit fresh generated-chunk admission; general streaming and live resize are absent |
| Procedural generator | Compile generation guidance and prepare complete deterministic material proposals | Opt-in `generation::Generator`/`GenerationJob`, immutable scalar/typed graphs, canonical semantic plans, aggregates and prepared modules; no mutable World access; [generation contract](../systems/procedural-world-generation.md) |
| TileJob | Temporary bounded work assignment and local observations | Core indices, `JobEffects`, local `TickStats`; no public type-enforced bounded rule context |
| MaterialRules | Immutable descriptors, traits and kernel selection | Descriptor/pair-reaction APIs are separate; executable kernels remain inside World |
| RenderBridge | Consume immutable simulation publication and update presentation | Native `RenderSnapshotExchange`, copied Godot packets and CPU-image consumer; GPU subregion writes are absent |
| GameplayBridge | Translate intent into tick-boundary data and immutable results | Narrow emission/input/body methods; generalized typed queues and pressure policy are absent |
| Rigid-body adapter | Own backend calls and translate body value data | `CyberRapierPhysicsBridge` plus native rectangle projection; general shape and torque interfaces are absent |

Adding a native class is justified when it establishes a usable responsibility
or lifetime boundary. A cosmetic rename is not architectural progress.

### How do advanced generation modules extend the engine?

**Current GEN-001/GEN-002 source:** the native
[`ModuleRegistry`](../../native/include/cybersand/world_generation.hpp) resolves
versioned factories before generation. Factories prepare immutable samplers
outside simulation ticks; a sampler receives the current coordinate, immutable
effective parameters/palette and previous proposed material. It returns at most
one material for that cell. The generator clips the module's declared rectangle,
orders dependencies and validates the result before publishing a chunk.

The independent [`FieldGraph`](../../native/include/cybersand/generation_fields.hpp)
evaluates a bounded scalar DAG from coordinates and copied initial context.
It has no custom callback or simulation dependency. The generator uses those
values to mask modules and guide themes, parameters or discrete aggregate output.
Aggregate definitions resolve existing material IDs; they do not define new
MaterialRules. The [field/modifier contract](../systems/procedural-generation-fields-and-modifiers.md)
owns fixed observation order, finite curve scope and graph budgets.

GEN-003 adds a separate immutable
[`SpatialGraph`](../../native/include/cybersand/generation_typed_fields.hpp)
for signed scalars, distances, vectors, exact categories and booleans. Typed
transforms and derivatives resample only immutable absolute-coordinate inputs;
they cannot read the scalar graph's per-cell context or mutable World storage.
[`generation_spatial`](../../native/include/cybersand/generation_spatial.hpp)
owns bounded Peano/lattice/Poisson primitives, copied geometry and the single
finite region-assignment solver. Explicit normalized outputs feed
the existing mask interface; the [typed contract](../systems/procedural-typed-spatial-fields.md)
and [operator inventory](../reference/procedural-spatial-operators.md) own the
spatial computation boundary.

**Current GEN-004 source:** the separate immutable
[`GrammarPlan`](../../native/include/cybersand/generation_grammar.hpp) prepares a
bounded hierarchy, canonical boundary ports, explicit routes and constraint
receipts before rasterization. It uses the shared region-assignment solver and
exports selected immutable geometry to typed fields without a reverse
field-to-grammar dependency. The generator applies feature proposals, modules
and modifiers, restores required passages, then retains final hard overrides.
It qualifies that complete material stack against a declared geometric route
profile and separate static-solid-contact profile before publishing the recipe. This planning and inspection boundary
does not own simulation admission or actor navigation; the
[hierarchy contract](../systems/procedural-hierarchical-generation.md) owns its
finite scope, deterministic identities and limits.

Modules are trusted cooperative C++ code: declared logical cost bounds admission,
while the host cannot sandbox an arbitrary callback or enforce its execution
time. The workbench selects registered modules through recipes; it does not load
arbitrary executable libraries from a recipe. Native World remains the sole cell
authority and accepts a completed material span only through its separate
exclusive-owner admission method. See the [generation contract](../systems/procedural-world-generation.md)
and [lifetimes](data-ownership-and-lifetimes.md).

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
