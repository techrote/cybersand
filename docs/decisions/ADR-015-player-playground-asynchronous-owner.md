---
title: ADR-015 Dedicated asynchronous cellular owner for the mechanical Player Playground
status: Approved design
document-kind: decision
scope: Windows/Linux desktop mechanical Player Playground; migration not implemented
canonical-for: [player-playground-async-decision]
keywords: [PLAY-ASYNC-001, dedicated player owner, Rapier, multicore, asynchronous, bounded handoff]
last-reviewed: 2026-10-26
related-documents: [../architecture/player-playground-asynchronous-contract.md, ../architecture/simulation-tick-and-threading.md, ../architecture/data-ownership-and-lifetimes.md, ADR-003-godot-bridge-and-immutable-snapshots.md, ../audits/2026-10-26-play-async-001-baseline.md]
---

# ADR-015: Dedicated asynchronous cellular owner for mechanical Player Playground

## Status, source and decision

**Approved design, NOT Current implementation.** Approved by the owner's
2026-10-26 multithread-first directive for Linux/Windows desktop; architectural
resolution for [#264](https://github.com/techrote/cybersand/issues/264), under
[epic #263](https://github.com/techrote/cybersand/issues/263). Source inspected:
main `9e53a5b1b501e0667037b8502d3c1d15089211f5`.
Runtime migration and acceptance remain #265–#270.

**Decision:** implement a narrowly scoped `CyberPlayerCellOwner` (a
non-Node, single-thread-exclusive cellular owner) and a main-thread
`CyberPlayerPlaygroundRuntime` facade. Borrow **conventions and small
value-only helpers**, not the whole `CyberSimulationWorker`: 60-Hz monotonic
deadline pacing, bounded mailbox, generation-fenced copied body samples,
copy-on-publication render packets with consumer ACK, pending-patch recovery,
failure quarantine and native World/worker-pool instrumentation.

The main thread retains `CyberPhysicalActorSession`, all five mechanical rigs,
their controllers, input/leases, Rapier RIDs/bridge and manual steps, terrain
collider installation, camera, UI, lap clock and render upload. A single Godot
Thread owns native World construction/reset/layout after an **exclusive
startup handoff**, ticks, native body-mask preparation, bounded native effects
and usable runtime, terrain extraction and render publication. Native phased
pool workers execute only within the owning World's tick; they never use Godot
APIs. The simulation thread may call the existing native GDExtension's
value-only methods, but never a Node, RID, scene or PhysicsServer API.
The mechanical authority for existing action/equipment `run_id` and
`session_epoch` is the **physical Session**, not the playground wrapper.
A separate monotonic **`owner_epoch`** fences worker generations because a
freshly allocated Arena can reuse Session epoch 1; the precise two-epoch
mapping is specified in the [protocol](../architecture/player-playground-asynchronous-contract.md).

Construction qualification: the main may **allocate an inert
`CyberNativeCellWorld` adapter** using `ClassDB.instantiate` before starting
the thread, as `CyberSimulationWorker._create_world` does today; it must not
configure/mutate the World after handoff. The worker performs
`diagnostic_reset`, layout, all subsequent World operations and final
retirement. The native adapter's last reference may be released only after
worker completion. If creating the adapter itself off-main proves safe in #265,
that is an optional narrower optimization, not an architecture dependency.

## Why this is smaller and safer

**Current:** `player_playground.gd::advance_frame` invokes
`player_playground_runtime.gd::step` on the physics callback. Its mechanical
`physical_actor_arena.gd::step` serially prepares body mask, actuation,
effects/usables, native tick, feedback, terrain collider rebuild and Rapier.
`physical_actor_arena.gd::configure` hard-codes
`diagnostic_reset({"workers":1,"telemetry":false})`.
The material swarms have their own independent synchronous, one-worker World.

The existing `simulation_worker.gd` already implements useful async patterns,
but couples them to ordinary sandbox paint, sampled character, generators,
scenario/LCB preparation, optional physical actors and many unrelated reset
paths. Subclassing or copying its approximately 2,200 lines would import
unneeded state and create merge risk with active LCB ownership. Factoring a
generic simulation-owner framework first would broaden scope and risk an
unqualified regression in the production sandbox. A small dedicated owner
can reuse the actual tested packet and physics interfaces without that work.

## Rejected approaches

| Approach | Disposition |
|---|---|
| Reuse the existing `CyberSimulationWorker` instance or clone the full class | **Rejected:** different World/course/lifecycle and high unrelated-state/LCB coupling |
| First extract a general-purpose scheduler/ownership framework | **Deferred:** unnecessary shared refactor before the narrow cutover proves its contracts |
| Add a second ad hoc native tick on the main thread and merely request >1 native workers | **Rejected:** multicore jobs do not prevent the main thread waiting on a tick |
| Move `CyberPhysicalActorSession`, scene nodes, RIDs or Rapier manual stepping to the worker | **Rejected:** unsafe thread affinity and lease/contact ownership |
| Lock a shared World so render/main can call into it | **Rejected:** mutable aliasing, contention and hidden stalls |
| Guaranteed synchronous lockstep or unbounded result queues | **Rejected:** defeats independent pacing or hides overflow |
| Force one worker in migrated desktop gameplay | **Rejected as default:** explicit controlled deterministic/diagnostic exception only |

## Approved default, exceptions and consequences

Desktop gameplay **defaults to independently paced asynchronous cellular
ownership and the existing Auto native pool policy once #270 promotes the
qualified path**. At source `9e53a5b1`, this is **Approved, not Current**:
mechanical playground remains synchronous/one-worker.
Native Auto is `2` when reported logical cores are below four, `4` for
four–eleven, `6` for twelve or more; explicit requests are resolved by
the existing adapter contract (not a novel heuristic). Pool eligibility and
actual phase parallelism are separately reported; creating several threads
does not prove several jobs ran.

Synchronous and explicit one-worker configurations are allowed only as
named compatibility, deterministic fixture or diagnostic controls, recorded
with their owner/purpose/source and readback. One native worker does **not**
change async owner placement. Existing Web, Thunderbowl, ordinary sandbox and
the `dryswarm`/`liquidswarm` field lane remain unchanged by this ADR;
the two swarms are **Deferred** to #271, must receive an explicit safe,
user-visible compatibility/unsupported disposition and are not a mechanical
promotion gate.

The selected schedule permits bounded native/Rapier skew, not numerical
lockstep or an automatic 60-FPS guarantee. Hard-terrain changes impose an
intentional **nonblocking terrain readiness barrier**. Input edge/equipment
receipts may never be lost to last-value coalescing. Reset, failure and
shutdown require generation fencing and retained resources until cooperative
worker exit. Exactly specified interfaces, queue policy and ordering live in
the [approved execution contract](../architecture/player-playground-asynchronous-contract.md).
The [dated baseline](../audits/2026-10-26-play-async-001-baseline.md)
separates code inspection and earlier runtime evidence from new measured data.

## Implementation ownership and admission

[#265](https://github.com/techrote/cybersand/issues/265) owns the dedicated
thread, mailbox, World, tick, terrain barriers and snapshot lifecycle.
[#266](https://github.com/techrote/cybersand/issues/266) independently owns
per-World requested/actual native worker resolution, parity/performance
instrumentation and explicit single-worker controls. The two workstreams
consume the same value schema; neither may redefine its concurrency
invariants. #267 couples main-thread physical sessions and #268 presentation,
#269 lifecycle/stress; #270 promotes the default only after both dependency
branches and Windows/Linux manual feel/CI qualifications succeed.
