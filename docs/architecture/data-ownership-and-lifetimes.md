---
title: Data ownership and lifetimes
document-kind: contract
canonical-for: [resource-ownership-and-lifetimes]
status: Current
scope: Current resource owners, mutation windows, publication retirement and allocation limits; proposed resources are explicitly separated
keywords: [ownership, lifetime, chunks, immutable lease, render handoff, body mask, queue]
related-documents: [simulation-tick-and-threading.md, rendering-and-gameplay-bridges.md, ../reference/interfaces-and-message-contracts.md, ../reference/invariants.md]
last-reviewed: 2026-09-09
---

# Data ownership and lifetimes

## Who may mutate each resource?

**Current:** each selected cellular world has one external owner. On desktop
that is `CyberSimulationWorker`; on Web it is the main-thread controller.
Native World coordinates its internal jobs. Queries, export, publication and
mutation require serialization by that owner; calling a method through
GDExtension does not make World generally thread-safe. Native pool workers call
no Godot APIs. The desktop Godot owner may call exclusive adapter/value APIs,
but must not touch live scene-tree or Rapier objects.

| Resource | Owner and permitted mutation | Lifetime and pressure |
|---|---|---|
| `World::chunks_` and chunk cell arrays | World coordinator creates/reserves chunks; serial work or phase-exclusive jobs mutate cells | Until World/chunk destruction; construction capacity bounds growth |
| Optional temperatures | Chunk owns optional SoA; owner prepares it, permitted rules/movement use it | Allocated on demand or reservation; counted tick allocations |
| Activity/dirty metadata and job effects | Job-local observations, then coordinator merge after the phase barrier | Persistent chunk metadata and reusable bounded scratch; dirty bounds survive unsuccessful publication |
| Native snapshot slots | One serialized producer writes only an unleased slot | Shared exchange state outlives its facade while leases exist; no-slot/capacity failure retains dirty state |
| Desktop world and sampled character | Godot pacing Thread after startup handoff | Worker lifetime; stopped/joined before destruction |
| Live body nodes, RIDs and physics state | Main-thread Rapier bridge and PhysicsServer2D | Scene/bridge lifetime; never passed to cellular workers |
| Body samples and observations | Adapter owns copied samples and native transient occupancy; results are copied into publication | Mask rebuilt at coupling preparation; sample IDs identify result application |
| Godot CPU image and textures | Main thread validates patches and updates resources | Application lifetime; upload never borrows mutable World bytes |

Source: [World/Chunk](../../native/src/world.cpp),
[native exchange](../../native/src/render_snapshot.cpp),
[desktop worker](../../godot/scripts/simulation_worker.gd),
[Web controller](../../godot/scripts/web_demo_controller.gd) and
[Rapier bridge](../../godot/scripts/rapier_physics_bridge.gd).
Step order belongs in the [threading contract](simulation-tick-and-threading.md).

## When can a render payload be reused?

**Current native lease:** `RenderSnapshotLease` exposes const payload spans;
the final lease release permits slot reuse. Consumers may acquire/release
concurrently with serialized publication. A lease retains shared slot state
even after the exchange facade or C exchange handle is destroyed. A lease does
not extend the lifetime of mutable World storage because its bytes are copies.

**Current desktop handoff:** the worker owns dynamic pending patch arrays.
`_refresh_published_render_payload` deep-copies a changed pending generation
once, then shares that frozen generation through `CyberSimulationSnapshot`.
The GDScript type is writable; immutability is enforced by publication
convention and copied backing arrays, not the language type system.

`take_latest_snapshot` does not retire render data. Main-thread consumption
validates the whole payload, patches the CPU image and updates the texture
before `acknowledge_render_snapshot`. Rejection requests a full refresh and
does not acknowledge success. The worker clears accumulated patches only when
the acknowledged serial covers the pending publication. Acquiring an older
snapshot never authorizes clearing bytes it can still observe.

**Current Web:** copied packets are consumed synchronously on the main thread;
the desktop mutex/accumulation/acknowledgement protocol is not instantiated.
The [bridge contract](rendering-and-gameplay-bridges.md) owns format and failure
outcomes; these two lifetimes must not be conflated.

## Is every queue and allocation already bounded?

No. **Current:** native task/snapshot/explosion capacities are explicit and
reused. Lazy coordinator preparation may allocate chunks during a tick;
preallocation prevents the tracked chunk/temperature allocation classes for
covered regions. This is not proof that every adapter allocation is absent.

Desktop frame inputs and body arrays are replaced under a mutex. Emissions use
a dynamic `Array[Vector4i]` with no production capacity/full-queue result.
Pending render arrays also grow dynamically, then switch to a finite full
refresh when byte or patch thresholds are exceeded. This recovery bounds the
retained display representation; it does not implement generalized bounded
GameplayBridge queues.

Native rectangle parsing considers at most 16 complete input records, accepts
IDs 1–16, and preserves the first parsed duplicate. The occupancy field belongs
to World; it is separate from material identity. See
[coupling](rigid-body-and-cellular-coupling.md) for displacement and overflow.

## Which transitions require exclusive ownership?

Setup, reset, reservation, rule/configuration replacement, level export/import
and World destruction must not overlap job views or producer access. Jobs may
not retain a view beyond their barrier. Native pool workers never call Godot;
the desktop owner only calls its exclusive adapter/value APIs.

Level export clears transient obstacles; coupling must be rebuilt before the
next cellular tick. Import builds a validated candidate before replacing World.
See [level saves](../reference/level-saves-and-replay.md) for the exact scope.

**Approved:** future reconfiguration drains affected work before replacing
storage, then resumes on a whole tick. **Planned:** active-only next buffers,
buffered halos/transfers, bounded general gameplay results and serialization
staging. Their sizes, retirement/full-queue policy and live-resize failure API
are not implemented. Do not infer them from Current snapshot backpressure.

Lifetime fixtures are linked in the [validation ledger](../reference/validation-evidence.md);
the rationale remains [ADR-003](../decisions/ADR-003-godot-bridge-and-immutable-snapshots.md).

## Failed-world ownership and recovery

**Current:** failure quarantines the existing World under its same exclusive owner.
Workers drain before exception propagation; no background retry is spawned.
Raw serialized queries see partial diagnostic state. Successful snapshot leases
retain their bytes; failure cannot publish new cell/terrain/body payloads.
Desktop retains the last valid snapshot in a new failure-status wrapper and keeps
its owner thread available for reset. Web gates directly on its adapter fault.
Main-thread Rapier stops on observed failure, without rewinding an earlier step.
`clear()` or validated replacement abandons the failed world's events and state.
Replacement candidates allocate/validate before ownership swap; see
[failure contract](simulation-tick-and-threading.md#what-happens-when-a-tick-fails-or-overloads).

Region setters are serialized owner operations that latch requested coverage,
including while failed. Healthy tick entry applies transition wakes in the existing
metadata pass; native pool jobs consume the resulting selection. No Godot or
Rapier API is introduced in native workers. Failed ticks cannot apply a later
region request; recovery abandons old activity before fresh setup.

## Who owns opt-in physics observations?

**Current:** [physics diagnostics](../operations/physics-characterisation.md)
allocate fixed per-job histograms when constructing the World. Each job writes
its exclusive counter table; the coordinator merges after existing barriers.
Counters cannot mutate authoritative cells or alter random streams. Adapter
snapshots copy stored cells and aggregates at the serialized owner boundary;
they expose no mutable World storage. Overflow drops observations, never work.

The test-only asynchronous worker records a fixed trace from its exclusive
adapter. The main thread reads that trace only after joining the worker, and
continues to own Rapier. Diagnostic variants require fresh fixture construction;
they are not live unsynchronized descriptor edits or representation handoffs.
