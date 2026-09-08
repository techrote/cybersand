---
title: Simulation tick and threading
document-kind: contract
canonical-for: [simulation-step-order-and-threading]
status: Current
scope: Desktop, Web and native stage ordering, fixed quanta, failure behavior and permitted thread access
keywords: [fixed tick, desktop worker, Web synchronous, Rapier order, character order, tick failure, backlog]
related-documents: [data-ownership-and-lifetimes.md, determinism-and-boundary-transfers.md, rigid-body-and-cellular-coupling.md, ../operations/web-threading.md]
last-reviewed: 2026-09-08
---

# Simulation tick and threading

## Who advances simulation on each platform?

**Current:** desktop has a dedicated Godot pacing Thread. Web advances native
cells synchronously from the main-thread `_physics_process`. Native World's
persistent pool is a separate layer: it parallelizes eligible cellular jobs
inside either owner's tick, without calling Godot APIs. Compatibility Web
forces one cellular worker; threaded Web and native Auto select 2/4/6 at
reported logical-processor thresholds 4 and 12. This is startup selection,
not a live adaptive policy. See [Web profiles](../operations/web-threading.md).

## Current desktop worker loop

Source: [CyberSimulationWorker `_worker_loop`](../../godot/scripts/simulation_worker.gd).

1. Latch frame state, copied body samples, reset and drained emissions under
   the mutex; apply selected window and Water options on the exclusive owner.
2. Reset if requested. Prepare body coupling, including overlap response when
   unpaused. Apply material emissions even while paused.
3. If unpaused, advance the sampled character by `1/60` second, then call the
   selected world's `simulation_tick`.
4. Publish copied character/cellular results and eligible render updates.
5. Advance the wall-clock deadline by `TICK_INTERVAL_USEC = 16667`. When lateness
   exceeds `MAX_BACKLOG_TICKS = 3` intervals, increment the overrun counter and
   reset the deadline to now. This discards wall-clock backlog, not World tick
   indices through an explicit skip operation.

The main thread renders the newest immutable snapshot while this work runs.
Separately, its physics callback applies the newest unapplied cellular response,
steps Rapier once, batch-reads transforms/flushes queries and sends copied body
state to the worker. Body and cellular timelines may lag by multiple samples;
serial checks prevent duplicate application. See
[main `_physics_process`](../../godot/scripts/main.gd) and
[Rapier `step`](../../godot/scripts/rapier_physics_bridge.gd).

<a id="current-web-owner"></a>

## Current Web owner: body, player and cellular update order

Source: [web_demo_controller `_physics_process`](../../godot/scripts/web_demo_controller.gd).

1. Return when unavailable, the menu is open or focus is lost. Set the current
   simulation window and allow armed painting before the pause guard.
2. Return if paused. If Rapier is active, also return while hard-terrain packets
   remain pending; this gates both solvers and the character.
3. Apply preceding cellular results, step Rapier, pack body state and prepare
   the native body mask. Without Rapier, prepare an empty mask.
4. Complete one native cellular tick. On success advance the sampled character
   by `1/60` second. On failure pause, open the menu and report the error.

Web's callback waits for all native jobs. `_process` consumes terrain work and
publishes display data at a separate cadence; a slow cellular tick can still
block rendering. **Deferred:** fully asynchronous Web ownership.

Desktop advances the character **before** cells; Web advances it **after**
cells. Desktop does not share Web's pending-terrain gate. These schedules are
not an equivalence guarantee; a common production order remains undecided.

## Current native scheduler

Source: [World `begin_tick`, `tick_phased`, `finish_tick`, `tick`](../../native/src/world.cpp).

1. Increment tick and compact update epoch; clear all cell epochs at wrap.
   Reset change observations and apply queued external explosions in enqueue
   order before gathering active work. Event-written cells carry this epoch
   and begin ordinary material rules on the following tick.
2. Gather eligible cores. For each of four phases, starting at `tick_index % 4`,
   prepare write-domain storage and job-local results before dispatch.
3. Execute same-phase exclusive jobs, using the persistent pool only when the
   configured job threshold is met. Wait for completion, then merge local
   effects in deterministic core order before the next phase.
4. Finalize activity/sleep and statistics. Render publication is an explicit
   caller operation after serialized mutation, outside `World::tick`.

Geometry and write restrictions are defined in
[chunk/tile model](chunk-tile-and-buffer-model.md); scan/random/merge semantics
and hash limits belong in [determinism](determinism-and-boundary-transfers.md).
`SerialInPlace` is executable. `Buffered` throws as unimplemented.

## What happens when a tick fails or overloads?

**Current:** native `tick` throws on reentrancy, unavailable capacity or an
unsupported backend. Its exception cleanup clears `tick_in_progress_`; it does
not roll back prior mutations. `begin_tick` can already have incremented time
and committed explosions before a later capacity failure. A failed tick is
therefore not a promised atomic no-op. A [dated source-built diagnostic](../audits/2026-09-08-foundation-diagnostics.md) confirms tick advancement, retained explosion mutations and drained events after planning failure.

The [adapter `simulation_tick`](../../godot/native_extension/cyber_native_cell_world.cpp)
catches errors and returns false with telemetry. Desktop currently ignores
that return and continues publication/pacing; Web pauses as described above.
**Unresolved:** production failure recovery, atomicity expectations and common
controller behavior. Do not invent retry or rollback guarantees.

Eligible native transport runs each tick; fixed staggered secondary lanes,
sleeping and interest rejection reduce work. Region rejection has a known
re-entry wake defect; SerialInPlace ignores the region. The exact limitation
and probe are in [interest-region behavior](../systems/world-storage-and-interest-region.md).
No general strict/gameplay switch, fidelity hysteresis or command-pressure
policy exists. **Approved:** future adaptation must preserve explicit ownership,
local collision and conservation, and report its policy.
[ADR-008](../decisions/ADR-008-bounded-approximate-fidelity.md) records that intent.
Actual platform execution evidence is in the
[validation ledger](../reference/validation-evidence.md).
