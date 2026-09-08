---
title: Interfaces and message contracts
status: Approved design
scope: Current public surfaces and documentation-level contracts required between Godot, rigid bodies, scheduler, jobs, storage, transfers, publication, and reconfiguration
keywords: [interface, contract, rigid body sample, gameplay command, gameplay result, immutable dirty snapshot, TileJob, transfer, reconfiguration]
related-documents: [../architecture/module-boundaries.md, ../architecture/rendering-and-gameplay-bridges.md, ../architecture/rigid-body-and-cellular-coupling.md, invariants.md]
last-reviewed: 2026-09-08
implementation-state: Legacy and versioned native C APIs, reusable immutable render exchange/lease contracts, and a copied Godot dirty-RG8 adapter are Current surfaces; generalized GameplayBridge schemas remain Approved design or Planned.
---

# Interfaces and message contracts

Evidence scope (2026-09-08): **Current** below describes inspected source in the
reconstructed local snapshot, not a verified Git HEAD or an all-platform test pass.
See the [documentation audit](../audits/2026-09-08-documentation-audit.md) for
source identity and dated validation; [M11 audit records](../audits/m11/README.md)
retain historical scope. **Approved design** means Approved direction; Planned,
Deferred, and Rejected statements do not claim implementation.

## At a glance

- Purpose: name every cross-module interaction without inventing C++ signatures or serialized fields.
- **Current**: the repository exposes backwards-compatible and versioned C APIs plus GDScript worker/snapshot methods.
- **Current**: native render exchange/lease APIs publish immutable deterministic dirty patches with explicit pressure and capacity outcomes.
- **Current**: CyberNativeCellWorld copies dirty material/condition patches into Godot value arrays and never exposes mutable native storage.
- **Current**: the Godot rectangle proof exchanges packed body samples and sample-keyed coupling results without passing live physics objects.
- **Approved design**: eight semantic contracts define the target data flow.
- Contract names here are documentation anchors, not implemented type names.
- Every payload becomes immutable before crossing its ownership boundary.
- Failure/pressure behavior must be explicit before implementation.
- Current C ABI and private adapter layouts are defined in source; final generalized gameplay/job/reconfiguration layouts remain undecided.

## Search anchors

public interface exists, message schema, gameplay command contract, TileJob input output, snapshot contract, boundary transfer contract, reconfiguration transition

## Current public surfaces

### Native C API

[native/include/cybersand/c_api.h](../../native/include/cybersand/c_api.h) exposes functions for:

- world creation/destruction;
- cell get/set;
- tick;
- state/content hashes and tick/chunk queries;
- RGBA copy and Water mass query;
- complete versioned construction configuration, including backend, geometry, workers, and capacities;
- explicit material/temperature region reservation;
- extended scheduler/allocation TickStats;
- descriptor queries including compact kernel state, write radius, directional density exchange, lateral-flow mode, and normalized viscosity;
- bounded external explosion enqueue and committed-event TickStats;
- reusable render exchange construction, publication, lease acquisition/release, patch/payload reads, and pressure/high-water observations.

The functions use the `cybersand_` naming family. Version 2 validates structure
size and ABI version, returns checked success/failure, and catches C++ exceptions
at the boundary. ABI version 2 includes event capacity/radius and committed-event
metrics. The additive material-info v3 query exposes density direction, target
exchange permission, and free-mass versus cellular-yield flow without changing
the earlier descriptor layouts. Material-info v4 adds normalized viscosity.
The snapshot exchange and Godot GDExtension patch adapter are Current immutable
publication contracts, but there is still no generalized GameplayBridge.

### Godot worker surface

[godot/scripts/simulation_worker.gd](../../godot/scripts/simulation_worker.gd) exposes desktop GDScript methods for starting/stopping
the worker, setting frame inputs, queueing simulation requests, resetting,
obtaining a current snapshot, acknowledging a successfully uploaded render
serial, and requesting a full render refresh. Retrieval alone never acknowledges
or retires render data. Inputs and acknowledgement state use Godot containers
and mutex protection. The [Web controller](../../godot/scripts/web_demo_controller.gd)
uses synchronous main-thread native calls and does not instantiate this worker
queue/snapshot protocol.

`cybersand_world_resident_cell_bytes` reports hot Cell, activity metadata, and
optional temperature vector capacity. TickStats reports owned tick-time chunk
and temperature allocations. Neither is a process-wide memory profiler.

### Snapshot surface

[CyberSimulationSnapshot](../../godot/scripts/simulation_snapshot.gd) contains public data fields
and is treated as immutable after publication. Render fields carry serial,
channel count, full-refresh flag, rectangle metadata, and copied patch bytes.
The language/type does not enforce deep immutability, so the worker duplicates
pending packed metadata and bytes at each changed publication generation and
does not subsequently mutate those published arrays. The main consumer checks
metadata stride, dimensions, world bounds, channels, row stride, offsets, and
required byte extent before any Image creation or blit. A failed validation is
not acknowledged and triggers the explicit full-refresh request path.

Native `RenderSnapshotExchange` preallocates uniform slots. `publish(World&)`
returns NoChanges, Published, Backpressure, or CapacityExceeded plus exact
requirements. `RenderSnapshotLease` exposes const patch and byte spans and keeps
its shared slot immutable until release. Both C++ and C leases retain shared
slot ownership even if the exchange facade/handle is destroyed.

### Current GDScript rigid-body sample/result surface

[CyberRigidBodyCoupling](../../godot/scripts/rigid_body_coupling.gd) defines a
prototype-only packed float32 layout (`INPUT_STRIDE = 11`, `RESULT_STRIDE = 9`,
at most 16 accepted bodies). Each input
contains body/sample identity, rectangle transform/size, velocity, angular
velocity, and mass. Each result echoes body/sample identity with impulse,
positional correction, contact count, displaced-cell count, and unresolved-cell
count. `CyberSimulationWorker` duplicates the input under its mutex and publishes
results through `CyberSimulationSnapshot`.

This is **Current** source evidence, not an approved native ABI. Its ownership
rule is approved: Node, RID, and live direct-body state remain on an allowed
Godot thread; workers receive immutable value data only.

## Contract status rule

The contracts below are **Approved design** semantic boundaries. They do not approve:

- a class, struct, enum, or function name;
- field names or binary layout;
- queue implementation;
- ABI ownership method;
- error code;
- serialized key;
- timeout or blocking policy.

Those details require later interface review and tests.

## Gameplay command contract

| Property | Approved requirement |
|---|---|
| Producer | GameplayBridge on a permitted Godot thread |
| Consumer | SimulationScheduler tick-latch stage |
| Timing | Applied only at an identified whole tick boundary |
| Data | Value data sufficient to express gameplay intent without Godot object references |
| Ownership | Immutable after enqueue; storage ownership must be explicit |
| Ordering | Deterministic for identical accepted command input |
| Capacity | Bounded and observable in production |
| Failure | No silent drop; exact reject/defer/block policy is unresolved |

Current material emission, reset, movement, and simulation-window inputs are
examples of intent categories, not a final command schema. The GDScript proof's
generic disc-emission queue packs an 8-bit material ID and emission flags into
one `Vector4i` member; `EMISSION_FLAG_COHERENT_LIQUID` is the only defined flag.
The retained paint method is a wrapper over that queue. `main.gd` owns an explicit
prototype paint-slot-to-material-ID mapping, and the slot never enters the
simulation command. Equipment, enemy actions, and fixed/dynamic spawners can
later produce the same bounded semantic emission without depending on painting.
The global surface-adhesion comparison value travels with mutex-latched frame
state and is applied by the worker before its tick. These are Current prototype
encodings, not approved native ABI fields.

## Gameplay result contract

| Property | Approved requirement |
|---|---|
| Producer | SimulationCore/Scheduler publication after commit |
| Consumer | GameplayBridge |
| Timing | Describes completed authoritative state |
| Mutability | Immutable after publication |
| Identity | Cannot depend on raw Godot object pointers |
| Capacity/lifetime | Bounded and explicit |
| Failure | No mutable fallback; retention/pressure behavior unresolved |

No result categories or identifier format are approved.

## Interest-region update contract

| Property | Approved requirement |
|---|---|
| Producer | Camera/gameplay policy through GameplayBridge or equivalent approved boundary |
| Consumer | SimulationScheduler |
| Timing | Tick boundary; may trigger safe reconfiguration |
| Meaning | Requested interest region and policy, distinct from capacity |
| Failure | No clipping; required versus available capacity is reported |

Exact coordinates, dimensions, margin representation, and multi-camera policy are unresolved.

## Rigid-body coupling contract

Status: **Current** for the native rectangle adapter and alternative GDScript
proof; generalized shape/queue interfaces are **Approved design**. Native
projection iterates accepted IDs in ascending order; fallback projection uses
input order. See [coupling](../architecture/rigid-body-and-cellular-coupling.md).

| Property | Requirement |
|---|---|
| Producer | Allowed Godot physics context or future backend-neutral bridge |
| Consumer | Cellular coupling stage, then immutable result consumer |
| Input timing | Stable start-of-stage transform sample with body/sample identity |
| Collision view | Separate occupancy mask; material identity is not erased/restored to transform a body |
| Output | Bounded impact, pressure, displacement, correction, torque when implemented, and unresolved-overlap observations |
| Ownership | Packed immutable value data only; no Node/RID/direct physics state on simulation workers |
| Overlap order | Explicit body and cell order, independent of worker completion timing |
| Failure | Stale sample, overflow, and unresolved overlap are reported; no silent material deletion |

Final numeric layout, shape representation, sample-age policy, substep/sweep
threshold, torque units, particle fallback, and native queue capacity are
**Planned**.

## TileJob contract

| Property | Approved requirement |
|---|---|
| Producer | SimulationScheduler work-planning stage |
| Consumer | One native worker for the job lifetime |
| Spatial scope | **Current** 64×64 phased scheduling core with configured radius-two write domain; buffered geometry undecided |
| Reads | Supplied bounded state/neighbourhood, immutable MaterialRules, tick-local inputs |
| Writes | Phased exclusive domain, or buffered isolated output/transfers; local observations and bounded deferred events |
| Lifetime | Ends at the applicable phase/stage barrier; no retained views |
| Failure | Invalid ownership/view/capacity cannot be ignored; exact scheduler response unresolved |

Current phase geometry/rule radius are source-backed. A type-enforced bounded
rule view, buffered halo, public job identifier, and standalone observation
schema remain undecided.

## Boundary-transfer contract

| Property | Approved requirement |
|---|---|
| Producer | TileJob |
| Consumer | Deterministic transfer-merge stage |
| Meaning | Cross-output-region effect for the buffered backend; ordinary phased local movement does not use this contract |
| Ownership | Written only within assigned bounded transfer storage, then immutable to producer |
| Ordering | Canonical and independent of completion order |
| Overflow | Diagnosed/asserted; no hidden allocation, clipping, or silent loss |

Exact fields, categories, sort tuple, conflict priority, and arithmetic representation are undecided.

## Immutable dirty snapshot contract

Status: **Current** for native publication and copied Godot consumption.
Direct Godot consumption of the C lease API is not implemented; the adapter
copies native leases into Godot value arrays.

| Property | Approved requirement |
|---|---|
| Producer | One serialized native coordinator after authoritative mutation/tick |
| Consumer | Concurrent native lease holders and the Current copied Godot adapter |
| Data | Ordered world rectangles plus two-byte material ID/condition projection; condition is material-selected state_a, state_b or zero |
| Lifetime | Stable until the final lease releases its slot |
| Capacity | Explicit slot count and patch/byte capacity per slot; patch/byte high-water observed |
| Dirty safety | Backpressure/capacity failure leaves World dirty bounds unacknowledged |
| Failure | Non-blocking NoChanges/Published/Backpressure/CapacityExceeded result |

The Current finite Godot adapter selects three slots, 64 patches per slot,
and 2,097,152 bytes per slot; these are prototype defaults in
[create_world](../../godot/native_extension/cyber_native_cell_world.cpp).
Godot maps material/condition to RG8 and uploads the full texture after CPU
patching. General production defaults, palette messages, compression and
coalescing beyond Current accumulation/full-refresh recovery remain Planned.

## Capacity reconfiguration transition

| Property | Approved requirement |
|---|---|
| Initiator | Explicit configuration/interest request |
| Coordinator | SimulationScheduler with WorldStorage |
| Entry | Whole tick boundary or loading transition |
| Precondition | Affected TileJobs/views are drained |
| Mutation | Explicit capacity/storage changes only |
| Exit | Valid committed state and whole-tick resume, or explicit failure retaining valid prior state |
| Diagnostics | Required, available, resulting capacity, memory, duration, and outcome |

The state-machine names, synchronous/asynchronous API, and caller response are unresolved.

## World serialization contract

**Current, finite level scope:** [CYSD1 codec](../../godot/scripts/demo_save_codec.gd)
encodes a 1024×1024 level with a 56-byte versioned header, bounded JSON metadata,
DEFLATE world payload, SHA-256 integrity and Base64 text. Each native cell stores
material/state_a/state_b/LE16 temperature (five bytes). Metadata stores the demo,
player, selected material/options and up to three Physics Pit body records
(position, rotation, velocity, angular velocity, sleeping).

[CyberDemoBridge](../../godot/native_extension/cyber_demo_bridge.hpp) validates
and reconstructs a fresh World before swapping it into the adapter. Calls
require exclusive ownership at a safe boundary. Export is not const: it clears
the transient obstacle projection while copying stored-cell temperatures, so
the owner must rebuild body occupancy before the next cellular tick.

**Planned:** generalized sparse-world persistence, streamed I/O/backpressure,
migrations and exact replay checkpointing. CYSD1 omits tick/epoch, activity/sleep
state, pending events, capacities, transient masks, scheduler/controller state
and Rapier internal solver state. An exact re-export proves level payload
restoration only. No durable exact-replay format or general strict-mode switch
exists; [hash coverage limits](../architecture/determinism-and-boundary-transfers.md#replay-state-coverage)
apply even when native fixture hashes match.

## Contract review checklist

- Is producer, consumer, owner, and lifetime explicit?
- Is the payload immutable at the boundary?
- Is tick/stage timing explicit?
- Can a Godot object or mutable pointer cross?
- Is ordering deterministic?
- Is capacity bounded and observable?
- Is failure behavior approved rather than inferred?
- Is every future-affecting value covered by replay?
- Does the contract work on one thread and multiple workers?

## Related decisions

- [ADR-001](../decisions/ADR-001-native-simulation-core.md)
- [ADR-002](../decisions/ADR-002-double-buffered-tile-jobs.md)
- [ADR-003](../decisions/ADR-003-godot-bridge-and-immutable-snapshots.md)
- [ADR-004](../decisions/ADR-004-interest-region-and-reconfiguration.md)
- [ADR-007](../decisions/ADR-007-rigid-body-cellular-coupling.md)
- [ADR-008](../decisions/ADR-008-bounded-approximate-fidelity.md)
