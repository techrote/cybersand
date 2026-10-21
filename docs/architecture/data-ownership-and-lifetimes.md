---
title: Data ownership and lifetimes
document-kind: contract
canonical-for: [resource-ownership-and-lifetimes]
status: Current
scope: Current resource owners, mutation windows, publication retirement and allocation limits; proposed resources are explicitly separated
keywords: [ownership, lifetime, chunks, immutable lease, render handoff, body mask, queue]
related-documents: [simulation-tick-and-threading.md, rendering-and-gameplay-bridges.md, ../reference/interfaces-and-message-contracts.md, ../reference/invariants.md]
last-reviewed: 2026-10-20
---

# Data ownership and lifetimes

## Exploratory map actor installation

**Current desktop:** the simulation owner installs copied sampled actor definitions
only at the accepted exploratory scenario reset boundary. Main owns live Rapier
objects and rebuilds the selected physical assembly within the reset protocol.
The sandbox may create it while reset is pending; it cannot step until the
matching reset acknowledgement, actor epoch and initial terrain are ready.
Exploratory scenario installation also checks the accepted map hash.
Switching representations does not
transfer a mutable actor or World reference between threads. ACT-004/ACT-005 keep
`CyberPhysicalActorSession`, body/joint nodes, control state and the Rapier bridge
on the main thread. Copied effect requests cross to the cellular owner, which
validates and applies them; only copied receipts return. Reset/close retires the
old run, command leases, effects and joint graph. See the
[physical actor contract](../systems/physical-actor-rigs.md).

## Opt-in depth exhibition ownership

[Strata Theatre](../systems/depth-layers-and-parallax.md) and
[Deepworks](../operations/deepworks-exhibition.md) use a separate synchronous
depth owner that serializes native adapter calls into four independent worlds.
They do not borrow the ordinary sandbox's mutable World or attach another
simulation owner to it. The authored extent can be 8–1024 cells on each axis;
Deepworks selects 1024 × 1024 for every plane.

[`CyberDeepworksRuntime.install()`](../../godot/scripts/exhibition/deepworks_runtime.gd)
validates the complete programme and authoring candidate before replacement,
then retains copied event records. Successful reset advances the world
generation and retires old queued commands and source counters. Scheduled
writes run on the same owner immediately before their target native step.
Rendering receives copied RG8 packets; each surface validates all patches
before mutation and refuses a reset generation older than its accepted state.
The frozen background caches its publication and is never ticked. Private
viewports and camera transforms create no native cell or actor authority.

## Who may mutate each resource?

**Current:** each selected cellular world has one external owner. In the ordinary
desktop sandbox that is `CyberSimulationWorker`; on Web it is the main-thread controller.
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
| Delayed pair deadline | A phase-exclusive source activity block stores its earliest due tick; coordinator wakes it at healthy tick entry | One scalar per block; excluded blocks retain it, clear/replacement discards it |
| Native snapshot slots | One serialized producer writes only an unleased slot | Shared exchange state outlives its facade while leases exist; no-slot/capacity failure retains dirty state |
| Desktop world, sampled character and optional actor prototypes | Godot pacing Thread after startup handoff | Worker lifetime; stopped/joined before destruction; actor session reset invalidates old input epochs |
| Live body nodes, RIDs and physics state | Main-thread Rapier bridge and PhysicsServer2D | Scene/bridge lifetime; never passed to cellular workers |
| Physical actor rigs, joints and local controllers | Main-thread `CyberPhysicalActorSession`; at most eight rigs/eight total parts each | Run/actor/epoch-bound command leases; cancel discards future work, close retires bodies/joints |
| Physical usable effect requests | Copied by the physical owner; exclusively validated/consumed by the native-world owner | Epoch/sequence/source-bound, bounded per actor and batch; consumed refusals cannot replay after an obstacle disappears |
| Physical equipment chassis and mount | Main-thread `CyberPhysicalUsableEquipment` through its actor rig; the same part/body ID is held, released, fixed, deployed and picked up | At most one equipment part per actor within the eight-part limit; equipment epochs invalidate superseded use and deployment authority without deleting velocity |
| Physical usable frame, request and receipt mailbox | Main thread supplies copied physical poses/identity; the serialized cellular owner admits and applies usable work, then publishes copied results | Eight pending requests globally, one per actor including extracted work; run/actor/generation/equipment/body/request identity fences cancellation and recoil |
| Physical projectile and processor state | `CyberPhysicalUsableRuntime` on the exclusive native-world owner; no live body or scene object crosses the boundary | 64 projectiles, 16 active objects globally and four per actor; bounded per-actor/per-processor history retains stock, age, cycles and cooldown across physical pickup/redeployment |
| Body samples and observations | Adapter owns copied samples and native transient occupancy; results are copied into publication | Mask rebuilt at coupling preparation; sample IDs identify result application |
| Godot CPU image and textures | Main thread validates patches and updates resources | Application lifetime; upload never borrows mutable World bytes |
| Compiled procedural recipe, field graph and prepared modules | Immutable `generation::Generator`, independent of World | Jobs retain shared ownership; replacing the caller's recipe cannot mutate existing jobs |
| Typed spatial graph, geometry and prepared region assignment | Immutable `generation::SpatialGraph`; copied typed parameters, routes and bounded complete solver results | No per-cell context or mutable World access; transforms and derivatives resample absolute-coordinate functions |
| Semantic hierarchy, sockets, routes and constraint receipts | Immutable `generation::GrammarPlan`, prepared before rasterization for a finite world-anchored region window | Stable owner/rule/slot identities are separate from recipe revisions; chunks query complete plans without resident-neighbor negotiation |
| Hierarchy raster qualification and cell provenance | `generation::Generator` owns the complete final-cell route report; callers own copied inspection data | Hard overrides remain authoritative and may produce explicit blocked-route reports; no report changes World admission authority |
| Typed spatial sampling cache | One caller/job/worker owns bounded `SpatialScratch` | 256 entries keyed by transitive node identity, exact coordinate and sampling mode; cold/warm behavior has identical values |
| Procedural sample context | Copied initial candidate material, surface and route values | Captured before fields/modules/material changes; every mask for that cell sees the same values |
| Procedural chunk staging | One `GenerationJob` owns private material/optional diagnostic arrays and cursor | Allocated before incremental advance; pending bytes stay private, failure/cancel discards both payloads |
| World-generation workbench previews | One main-thread `CyberWorldGenerator` owner plus copied material/texture cache | Accepted recipe changes retire old preview work; cache eviction regenerates previews, never evicts simulation chunks |

Source: [World/Chunk](../../native/src/world.cpp),
[native exchange](../../native/src/render_snapshot.cpp),
[desktop worker](../../godot/scripts/simulation_worker.gd),
[Web controller](../../godot/scripts/web_demo_controller.gd) and
[Rapier bridge](../../godot/scripts/rapier_physics_bridge.gd).
Step order belongs in the [threading contract](simulation-tick-and-threading.md).

The [Blacksite Nine camera map](../operations/blacksite-nine-demo.md) is a
main-thread presentation consumer of one installed native world. Selecting any
of its nine tiles changes only the camera rectangle and follow state; it neither
installs a tile nor queries the desktop worker's mutable cells. Its backdrop and
exposure use the accepted current/previous textures. Initial launch and whole-map
reset retain the existing owner-local MicroScenario replacement boundary.

## How may generated content enter cell authority?

**Current GEN-001/GEN-002 source:** the generation job API and supplied module context
provide no mutable World, scene-tree or Rapier state. The
[generation contract](../systems/procedural-world-generation.md) separates
immutable recipe/revision receipts from the destination World's lifetime.
`Generator::accepts` validates the former; the caller must also establish the
current World/reset session and hold exclusive ownership before invoking
[`World::install_generated_chunk`](../../native/src/world.cpp).

Installation prevalidates one complete material span before allocating/writing,
requires an absent destination chunk and uses existing native mutation defaults.
Even a reserved empty or edited-then-cleared resident chunk is protected from
regeneration. Failed Worlds, in-tick calls, invalid payloads, capacity/coordinate
failure and overlapping transient occupancy are explicit refusals. This method
is a loading/setup boundary primitive; it supplies no background World owner,
automatic resident eviction or reset-session manager. The opt-in workbench only
previews copied proposals and never calls it on the sandbox World.

GEN-002 scalar context observes the initial procedural candidate, including its
old brushes and hard geometry controls, before any masked modifier or module.
It does not borrow live World material or infer player edits from empty preview
cells. Diagnostic floats are job-owned and receipt-bound, then copied into the
workbench cache; changing inspection channels retires that cache. The
[field/modifier contract](../systems/procedural-generation-fields-and-modifiers.md)
owns this immutable-context and diagnostic lifecycle.

GEN-003 schema-2 [`SpatialGraph`](../../native/include/cybersand/generation_typed_fields.hpp)
adds immutable typed functions beside that retained context graph. It never
resamples `FieldContext` as if it contained neighboring observations. Route and
feature geometry is copied; finite region assignments finish preparation before
publication. Each caller or job owns its bounded sampling scratch. Typed
diagnostics preserve signed values, vector components and exact categorical
identities; the chunk receipt binds both payload and type/unit metadata, and
failure/cancellation publishes neither materials nor diagnostics. The
[typed contract](../systems/procedural-typed-spatial-fields.md) owns these
lifetimes and cache identities. Future grammar, authoring and streaming owners
may consume the interfaces without gaining mutable cell access.

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

Native rectangle parsing considers at most 64 complete input records, accepts
exact IDs 1–64 from finite valid records, and preserves the first valid duplicate.
The ACT-004 physical effect queue and ACT-005 physical usable queue each admit a
whole incoming batch within eight pending requests or publish an explicit refusal.
ACT-005 also counts extracted in-flight requests against its one-per-actor and
global capacity until consumption or retirement; its copied physical frame and
body sample are latched at the same mutex boundary. These queues do not bound the
older generic emission queue described above. The occupancy field belongs
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

Sampled [granular support queries](../systems/granular-interaction-policy.md) read
current cells and copied body occupancy only under this exclusive owner, outside
native jobs. Their bounded neighbourhood adds no job view, cache or Rapier object.

## Optional actor prototype ownership

**Current, experimental:** the [actor session](../systems/actor-rigs.md)
owns a bounded set of sampled motors under `CyberSimulationWorker`. Human or
policy producers submit scalar/value commands through its mutex-protected
mailbox. Only the serialized simulation owner configures, advances or observes
the motors and calls World collision/ray queries or bounded local tool writes.
SetA retains its original motor; additional rig geometry, attachment, angular
state, charge and effect scratch storage belong to the same owner. Input producers
cannot provide callback code or arbitrary native writes. The public worker forwarding
methods do not grant producers a live actor, World or Rapier reference.

Publications copy state/capability values. A current actor observation and a
material render generation have distinct ticks; retaining one does not authorize
relabeling the other. Session pause/reset/clear boundaries invalidate prior
command epochs, and failed-world publication retains the previous successful
display contract. The actor-specific action/lease protocol does not bound the
separate general emission queues described above.

Cancellation clears armed charge, attachments and pending effects before neutral
input advances; a Pouncer release action must not fire because its lease expired.
Consumed action/sequence/edge fields and latest admitted sequences are distinct
copied values. Catalog dictionaries are deep-copied at configuration/publication
boundaries rather than used as mutable shared actor state. Sampled rig bodies and
drawn extremities are not scene-tree physics objects or new native job owners.

### Standalone Thunderbowl ownership

**Current, experimental ACT-003:** a separate
[`CyberThunderbowlArena`](../../godot/scripts/thunderbowl_arena.gd) instance owns
one native World and actor session on its serialized caller thread. Setup builds
and validates a candidate before replacement. All due policies receive copied
views from the same completed state; no callback runs while motors or materials
advance. The driver and optional scene consume values, and only the arena calls
live cell, collision or motor APIs. This standalone host does not take ownership
of the desktop worker's World or registered scientific fixtures.

Direct actuator helper state belongs to each sampled motor. Producer-side lane,
model, identity, sequence and lease validation reads mutex-protected slot values;
it never borrows owner-replaced actor arrays. `wire`/`metal` is fixed at session
configuration, preventing hidden held state from crossing an input-mode switch.

Local observation filtering occurs before controller dispatch. Global evaluator
snapshots remain separate, and local messages read the previous delivered
generation. These trusted in-process GDScript examples establish a data-access
contract, not isolation from malicious script code. Slow model decisions enter
through a copied one-request adapter; its bounded optional file I/O runs between
arena steps, never inside native jobs or motor updates. File latency can still
delay the caller. Exact capacities, cancellation and failure/terminal semantics
belong to the [Thunderbowl reference](../systems/thunderbowl-control-reference.md).

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


## Issue #13 experiment checkpoint

[Tower controls](../operations/experiment-tower.md) use a copied latest pending command on desktop. The existing exclusive worker constructs and installs the native candidate outside ticks. Web uses its synchronous owner. Copied lab context accompanies snapshots; no mutable tables are shared with jobs.


## Opt-in transport profiles

**Current:** the [profile contract](../systems/flow-transport-and-profiles.md)
owns schema, inheritance, units, immutable native tables and explicit owner restart.
The Tower applies validated profiles through restart. Actual powder falls and
lateral Water mass transport drive bounded optional mixing and grain pickup;
horizontal sampling and cadence are separate fixed experiments.
Ordinary gameplay keeps Baseline; chemistry cadence, compact cells and CYSD1
are unchanged. No unsynchronized live descriptor mutation is introduced.

## Desktop gameplay recording ownership

**Current REC-001:** the desktop gameplay recorder is a second consumer of
`CyberSimulationSnapshot`, not a second World owner. The main thread applies the
immutable render publication to a private fixed-ROI material-ID buffer and copies
due frames into an explicit bounded queue. Its dedicated writer thread owns only
those frame copies plus copied metadata; it performs encoding/file I/O without
calling World, Rapier or scene-tree APIs.

The worker publication also carries a small value-only evidence sample bound to
each render generation: completed tick/time, sampled-character values, copied
rigid-body input values and reduced scenario/profile context. Later worker
snapshots may share the same frozen render bytes, so the recorder keys admission
to the render serial and never relabels an older material generation with newer
tick/actor values. The body array is the same copied bridge sample already
consumed by native coupling, not a live physics object.

Recorder queue saturation drops capture attempts with timing/tick provenance and
never waits on or skips an authoritative simulation tick. Recorder/file failure
stops recording admission and produces an incomplete evidence disposition without
changing simulation ownership or recovery. See
[gameplay recording](../operations/gameplay-recording.md).

## MicroScenario owner-local values

**Current MS-000:** `CyberMicroScenarioHost` is a RefCounted value/lifecycle helper
owned by the same exclusive GDScript owner as its native World. Desktop never
passes the host or World to the main thread; synchronous Web keeps both on the
main thread. Existing native pool and Rapier restrictions are unchanged.

Definitions are validated and copied before candidate replacement. Desktop
`scenario_capture` creates a separate record at the owner boundary, recursively
freezes its dictionary/array values once, and publishes it under a monotonic capture
serial. Old retained captures survive reset without mutation. The main thread
serializes that record, not mutable World storage. Capacity, failure and reset
semantics live in the [MicroScenario contract](../operations/microscenarios.md).

## MS-001 inspection and definition comparisons

The [schema-2 workbench](../operations/microscenarios.md#schema-2-complete-apparatus-presentation-and-existing-field-inspection)
never reads a worker World. Point/state and work-statistic queries run on the same
serialized external owner as native ticks and return copied values. Desktop
summaries/captures remain recursively frozen before main-thread publication;
Rapier scene objects stay main-thread owned. A/B stores copied complete definitions,
then uses the existing acknowledged fresh-reset transaction. Rejected definitions
or stale adapters preserve the previous world and schedule. A bounded GUI run waits
for each single-step acknowledgement; timeout cancels without retry or catch-up.
Opening the definition modal or any successful owner reset cancels further scheduled
steps, including same-definition resets; at most one already-admitted step may finish.

## Standalone soliding successor contracts

The [soliding lifecycle](soliding-lifecycle.md) defines reviewed future owner
transitions and tests a synthetic bounded ledger. The [discovery substrate](../systems/settled-region-discovery.md)
owns copied observations only. Neither is connected to World/Godot/Rapier or
changes Current owners. Production hooks, barriers, queues and payload transitions
remain separately gated; the source reader must stay serialized and read-only.

The desktop [physical actor trial](../operations/physical-actor-programme.md) uses one main-thread Rapier rectangle and the existing immutable body-value publication. It disables the sampled owner, adds no worker-side Rapier access and does not attach the generation preview to live cell storage.
