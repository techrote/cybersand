---
title: Interfaces and message contracts
status: Approved design
scope: Current public surfaces and documentation-level contracts required between Godot, rigid bodies, scheduler, jobs, storage, transfers, publication, and reconfiguration
keywords: [interface, contract, rigid body sample, gameplay command, gameplay result, immutable dirty snapshot, TileJob, transfer, reconfiguration]
related-documents: [../architecture/module-boundaries.md, ../architecture/rendering-and-gameplay-bridges.md, ../architecture/rigid-body-and-cellular-coupling.md, invariants.md]
last-reviewed: 2026-08-27
implementation-state: Legacy and versioned native C APIs, reusable immutable render exchange/lease contracts, and a copied Godot dirty-RG8 adapter are Current surfaces; generalized GameplayBridge schemas remain Approved design or Planned.
---

# Interfaces and message contracts

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
- Exact field lists, numeric types, ABI, queue structures, and Godot methods remain undecided.

## Search anchors

public interface exists, message schema, gameplay command contract, TileJob input output, snapshot contract, boundary transfer contract, reconfiguration transition

## Current public surfaces

### Native C API

native/include/cybersand/c_api.h exposes functions for:

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

godot/scripts/simulation_worker.gd exposes GDScript methods for starting/stopping the worker, setting frame inputs, queueing simulation requests, resetting, and obtaining a current snapshot. Inputs use Godot containers and mutex protection.

`cybersand_world_resident_cell_bytes` reports hot Cell, activity metadata, and
optional temperature vector capacity. TickStats reports owned tick-time chunk
and temperature allocations. Neither is a process-wide memory profiler.

### Snapshot surface

CyberSimulationSnapshot in simulation_snapshot.gd contains public data fields
and is treated as immutable after publication. Render fields carry serial,
channel count, full-refresh flag, rectangle metadata, and copied patch bytes.
The language/type does not enforce deep immutability.

Native `RenderSnapshotExchange` preallocates uniform slots. `publish(World&)`
returns NoChanges, Published, Backpressure, or CapacityExceeded plus exact
requirements. `RenderSnapshotLease` exposes const patch and byte spans and keeps
its shared slot immutable until release. Both C++ and C leases retain shared
slot ownership even if the exchange facade/handle is destroyed.

### Current GDScript rigid-body sample/result surface

`CyberRigidBodyCoupling` defines a prototype-only packed layout. Each input
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

Status: **Current** for the rectangular GDScript proof; generalized native form
is **Approved design**.

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

Status: **Current** for the platform-neutral native publication layer;
**Planned** for Godot consumption.

| Property | Approved requirement |
|---|---|
| Producer | One serialized native coordinator after authoritative mutation/tick |
| Consumer | Concurrent lease holders now; future Godot RenderBridge |
| Data | Ordered world rectangles plus tightly packed material ID/`state_a` bytes |
| Lifetime | Stable until the final lease releases its slot |
| Capacity | Explicit slot count and patch/byte capacity per slot; patch/byte high-water observed |
| Dirty safety | Backpressure/capacity failure leaves World dirty bounds unacknowledged |
| Failure | Non-blocking NoChanges/Published/Backpressure/CapacityExceeded result |

Production defaults, Godot texture mapping, palette-change messages,
compression, and optional coalescing beyond chunk dirty rectangles remain undecided.

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

Status: **Planned**.

WorldStorage must eventually stage a versioned authoritative representation without exposing active mutable buffers to I/O. File format, compression, snapshot semantics, I/O threading, backpressure, migration, and durability are not specified.

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
