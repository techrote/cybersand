---
title: Data ownership and lifetimes
status: Approved design
scope: Current and approved owners, readers, writers, mutation phases, allocation policy, lifetime, and overflow behavior for buffers and queues
keywords: [ownership, lifetime, buffer, queue, rigid body mask, current buffer, next buffer, halo, transfer, snapshot]
related-documents: [module-boundaries.md, simulation-tick-and-threading.md, rigid-body-and-cellular-coupling.md, ../reference/invariants.md]
last-reviewed: 2026-08-27
implementation-state: Current tables describe inspected code; approved tables define constraints but leave unapproved schemas and pressure policies unresolved.
---

# Data ownership and lifetimes

## At a glance

- Purpose: make shared-state assumptions explicit before multithreading.
- **Current**: the Godot worker exclusively advances the selected world—native on bundled Linux and Windows x86_64 builds, GDScript fallback on unsupported architectures—while the main thread receives copied snapshots.
- **Current**: native World owns sparse chunks and coordinates serial or phase-exclusive writes through a persistent pool.
- **Current**: RenderSnapshotExchange owns preallocated publication slots; leased bytes are immutable and independent of mutable World storage.
- **Current**: Godot owns RigidBody2D nodes while the selected world owns only copied body samples, its transient obstacle mask, and packed coupling observations.
- **Approved design**: WorldStorage remains the single owner of authoritative cells.
- **Approved design**: phased jobs may mutate only their exclusive write domains; buffered jobs write only isolated next/output regions.
- **Approved design**: Godot receives immutable dirty snapshots, never mutable simulation memory.
- Unresolved: exact gameplay queue schemas and general overload policies; native snapshot pressure behavior is Current.

## Search anchors

which job may write, authoritative cell owner, phase write domain, snapshot lifetime, buffered halo, transfer overflow, hidden mutable state

## Current ownership evidence

| Data | Owner | Readers | Writers | Lifetime | Mutation phase | Allocation/overflow evidence |
|---|---|---|---|---|---|---|
| World::chunks_ | native cybersand::World | Coordinator and bounded job operations | World coordinator/setup only structurally; job writes never grow it | World lifetime | setup/reservation and pre-phase domain preparation | explicit maximum_chunk_count; reserve_region prepares storage; tick allocation reported |
| Four-byte Chunk cells | World::Chunk | queries, jobs, hashing, render copy | set/move and phase-owned jobs | Chunk lifetime | serial or exclusive phased operations | vector allocated with chunk; material + two states + update epoch |
| Optional Chunk temperatures | World::Chunk | hashing, queries, rules | setup/set and movement | Chunk lifetime while allocated | field preparation or move | absent by default; reserve_temperature_region prepares it; tick allocation reported |
| Activity blocks/job effects | Chunk / World::ParallelState | coordinator and owning job result | owning job then deterministic coordinator merge | World lifetime / one job pass | phase execution then barrier merge | fixed vectors/arrays bounded by active capacities and per-job touched-chunk limit |
| Native dirty metadata | World::Chunk | dirty count/extraction and render caller | serial or merged job effects | Until capacity-safe extraction acknowledges it | authoritative writes then publication | extraction vector allocates outside tick; C API queries required count before clearing |
| Native render snapshot slots | Shared exchange state retained by RenderSnapshotExchange/leases | concurrent lease holders through const spans/C pointers | single serialized producer only when a slot is unleased | Shared state survives the exchange facade; each payload remains through all leases | after authoritative work and before dirty acknowledgement | uniform preallocated patch/byte buffers; non-blocking pressure/capacity results retain dirty state |
| Selected cellular world | CyberSimulationWorker through CyberNativeCellWorld or fallback CyberCellWorld | Worker simulation; snapshot copying | Worker simulation and emission/reset | Worker/world lifetime | Worker thread coordinates ticks; native phase jobs use exclusive domains | sparse bounded native chunks on Linux; fixed-size GDScript arrays in fallback |
| Godot test RigidBody2D nodes | Godot scene/PhysicsServer2D | Main/physics callbacks and shader-parameter copy | PhysicsServer2D plus main-thread coupling application/reset | Scene lifetime | Allowed Godot physics/main context only | Three fixed test nodes; no per-cell objects |
| Packed rigid-body input samples | CyberSimulationWorker input boundary | Worker after mutex latch | Godot physics callback under mutex replacement | Until replaced by a newer complete sample | Between worker steps | Dynamic packed array; current rectangle proof caps accepted body IDs at 16 |
| Rigid-body occupancy mask | CyberNativeCellWorld preferred; CyberCellWorld fallback | Cellular rules and sampled character on worker | Worker rasterization stage only | Worker/world lifetime; contents rebuilt per sample | Before overlap/emission/character/cell work | Native transient body-ID field is separate from authoritative material; fallback uses one byte per finite proof cell |
| Packed rigid-body coupling results | CyberSimulationSnapshot | Godot physics callback | Worker before immutable publication | Snapshot lifetime | After overlap/cellular observations | Current result is bounded by accepted body count; sample IDs prevent duplicate application |
| Worker frame inputs | CyberSimulationWorker | Worker | Godot main thread under mutex | Replaced as input changes | Between worker steps | Dictionary-based; no bounded schema |
| Worker material-emission queue | CyberSimulationWorker | Worker | Main thread under mutex; paint is one wrapper/producer | Until drained | Before simulation step | Dynamic Array; no reported capacity; commands contain material IDs, never UI slots |
| CyberSimulationSnapshot cell bytes | Published snapshot object | Godot main thread | Constructed by worker, then not intentionally mutated | Until consumer releases references | Snapshot publication | Full PackedByteArray duplicate on changed revision |
| Godot R8 image/texture | Godot main thread | Renderer | main.gd | Application lifetime/update cycle | Render/main thread | Full finite-world upload after changed revision |

The GDScript snapshot wrapper is immutable by convention. The preferred runtime
copies display bytes from native World into that wrapper; native leased dirty
snapshot data is type-exposed as const and slot-stable but is not yet the path
used for Godot texture updates.

## Approved authoritative buffers

The names below are documentation concepts, not approved C++ types.

| Buffer/state | Owner | Allowed readers | Allowed writers | Lifetime | Mutation phase | Allocation policy | Overflow behavior |
|---|---|---|---|---|---|---|---|
| Authoritative cell state | WorldStorage under SimulationCore authority | Coordinator, permitted native queries, and jobs through bounded views | Phase-owned jobs; or buffered commit/load/reconfiguration stages | While storage chunk is loaded | Exclusive phased writes or explicit coordinator transition | Persistent per loaded chunk | Capacity excess requires diagnosed safe reconfiguration; no clipping |
| Active next state | WorldStorage under SimulationCore authority | Owning buffered job and coordinator | Assigned buffered output and deterministic merge stage | One buffered tick for active regions | Buffered execution and merge | Preallocated for selected active regions only | Must assert/report exhaustion; exact pause/failure policy is undecided |
| Optional fields | WorldStorage | Jobs whose rules declare the field | Exclusive phased jobs or assigned buffered jobs/merge, according to field policy | Only while field/chunk policy requires it | Declared field backend only | Allocate during safe setup/reconfiguration, not hidden in hot path | Diagnosed reconfiguration or explicit failure; no silent default |
| Buffered neighbourhood/halo view | SimulationScheduler work preparation | Assigned buffered job only | Preparation stage only | One buffered job execution | Built or exposed before workers run | Reused bounded storage or non-owning view | Job cannot run with incomplete view; exact recovery policy undecided |
| TileJob task storage | SimulationScheduler | Worker receiving the job | Scheduler plan stage | One tick, then reused | Plan stage | Bounded and reusable | High-water reported; exhaustion asserted/diagnosed |
| Transfer storage | SimulationScheduler | Producing TileJob; deterministic merge stage | TileJob in its assigned portion, then merge stage | One tick, then reused | Tile execution followed by merge | Bounded and reusable | High-water reported; no hidden allocation, clipping, or silent loss |
| Activity and wake state | WorldStorage | Scheduler and SimulationCore | Commit/wake stage | Loaded chunk lifetime | After merged outputs are known | Persistent metadata with bounded active lists | Active-capacity excess follows safe reconfiguration |
| Dirty state | WorldStorage/SimulationCore | Snapshot preparation | Commit stage; cleared only after successful Current native capture | Until safely represented in a snapshot or retained for later publication | Commit and snapshot accounting | Persistent compact metadata | Backpressure/capacity failure leaves chunk dirty bounds intact |
| Immutable dirty snapshot storage | **Current** RenderSnapshotExchange; future RenderBridge consumes it | Lease holders / RenderBridge after publication | Single native producer before publication only | Publication until the final lease releases | After authoritative commit | Bounded reusable slots/bytes | **Current** non-blocking Backpressure/CapacityExceeded retains dirty state; required use and high-water reported |
| Queued gameplay-command storage | SimulationScheduler-facing boundary | Tick-latch stage | GameplayBridge before latch | Until accepted/rejected and latched | Between tick boundaries | Must be bounded for production | Exact full-queue behavior is unresolved and must be explicit |
| Immutable gameplay-result storage | Native publication facility | GameplayBridge | Result construction before publication | Until consumed/retired | After commit | Bounded production policy required | Exact pressure behavior unresolved |
| Serialization staging storage | WorldStorage | Serializer/I/O path at safe boundary | Snapshot/staging phase | Until durable handoff completes | Outside conflicting mutation phases | Capacity must be explicit | Exact I/O backpressure behavior unresolved |

## Phase access matrix

| Stage | Current state | Next state | Halo | Transfers | Activity/dirty | Snapshots |
|---|---|---|---|---|---|---|
| Input latch | Read only if command validation requires it | No access | No access | Reset/reuse only | No mutation | Consumer may retain older immutable snapshot |
| Work planning | Read metadata | Reserve buffered outputs if selected | Prepare buffered views if selected | Assign bounded transfer/event portions | Read activity | No construction |
| Phased execution | Write only current phase-owned domain | No access | No access | Append deferred events only | Produce local observations only | No access |
| Buffered execution | Read only | Write assigned output only | Read only | Append buffered transfers/events | Produce local observations only | No access |
| Merge/deferred resolution | Read/write only under approved coordinator semantics | Deterministic writes | No mutation | Read in canonical order | Accumulate wake/dirty effects | No access |
| Authoritative completion | Finalize tick state | Becomes authoritative if selected | Retired | Reset after safe completion | Authoritative update | No mutable snapshot reads |
| Publication | Read committed state/dirty metadata | Not mutated | None | None | Dirty acknowledgement according to final policy | Construct, freeze, publish |
| Godot consumption | No access | No access | None | None | No direct access | Read immutable snapshot only |

## Thread ownership rules

- A TileJob may not retain a storage view after its stage barrier.
- A worker may not publish directly to Godot.
- WorldStorage containers may not be structurally modified while workers hold views into them.
- Reconfiguration drains or prevents affected work before buffers or storage mappings change.
- Snapshot consumers never extend the lifetime of mutable storage.
- MaterialRules data is immutable for the duration of a tick; rule-set replacement requires a defined safe transition.
- Godot body Nodes/RIDs never cross to the worker; only packed value samples and immutable results cross that boundary.
- The entity occupancy mask is a separate collision view and never changes material identity merely to represent a transformed body.

## Safe reconfiguration lifetime

**Approved design**: when requested interest-region or active capacity exceeds reserved capacity:

1. Detect and report the required versus available capacity.
2. Defer structural change to a simulation tick boundary or loading transition.
3. Ensure no TileJob or merge stage holds affected views.
4. Resize/rebuild the bounded resources intentionally.
5. Re-establish valid current/next mappings and snapshot storage.
6. Resume at a whole tick.

Whether the simulation pauses, rejects the request, or enters a loading state while this occurs is **Ambiguous** and must be approved before implementation.

## Hidden shared mutable state audit

A proposed field fails review if:

- its owner cannot be named;
- two same-phase jobs can write overlapping memory, or a buffered job can write outside its output;
- it can be mutated during snapshot consumption;
- a pointer survives the stage that issued it;
- container growth can invalidate active views;
- worker completion timing changes access order;
- overflow behavior relies on allocator success;
- Godot object lifetime affects native worker correctness.

## Related decisions

- [ADR-001](../decisions/ADR-001-native-simulation-core.md)
- [ADR-002](../decisions/ADR-002-double-buffered-tile-jobs.md)
- [ADR-003](../decisions/ADR-003-godot-bridge-and-immutable-snapshots.md)
- [ADR-004](../decisions/ADR-004-interest-region-and-reconfiguration.md)
- [ADR-007](../decisions/ADR-007-rigid-body-cellular-coupling.md)
- [ADR-008](../decisions/ADR-008-bounded-approximate-fidelity.md)
