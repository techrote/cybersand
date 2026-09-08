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
4. On success publish copied character/cellular results and eligible render updates.
   On failure publish stopped status with the previous valid payload; see below.
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
4. Finalize activity/sleep and statistics. Mark completed tick identity only on success. Render publication is an explicit
   caller operation after serialized mutation, outside `World::tick`; failed Worlds
   reject publication.

Geometry and write restrictions are defined in
[chunk/tile model](chunk-tile-and-buffer-model.md); scan/random/merge semantics
and hash limits belong in [determinism](determinism-and-boundary-transfers.md).
`SerialInPlace` is executable. `Buffered` throws as unimplemented.

## What happens when a tick fails or overloads?

**Current, chosen for issue #1:** a thrown tick latches `World::has_failed()`.
There is no transactional rollback. Tick/epoch, accepted explosion edits, dirty
metadata, chunk preparation and even earlier completed phases may already have
changed. `tick_index()` identifies the attempted tick; `completed_tick_index()`
advances only after successful execution and activity finalization. No partial
`TickStats` is returned as success. See [ADR-010](../decisions/ADR-010-failed-tick-quarantine.md).

Failure clears the in-progress guard after any dispatched phase has drained.
Further ticks, gameplay writes, reservations and snapshot publication are rejected.
Serialized reads remain diagnostic access to partial state, not a valid save or
playable continuation. The last successful immutable lease remains usable.

Accepted explosions apply in enqueue order at tick entry. A completed batch drains;
if application itself throws, the retained batch may include applied or partial
events. Neither batch is ever automatically replayed: the world cannot be retried.
An explicit `clear()` discards cells, activity, pending events, masks and tick
identity, retains construction options/latest requested region, and permits fresh
setup. Destruction/reconstruction is the other native recovery path. No allocation
failure, capacity change or camera move implicitly recovers a world.

**Current desktop:** the exclusive GDScript owner checks native false, latches
failure and publishes a fresh status wrapper around its previous valid publication.
It withholds partial character, cell, terrain and body results, rejects new
emissions and clears pending prototype emissions. The pacing thread stays alive
to receive reset; main-thread Rapier stops when the failure status is observed.
This is asynchronous notification, not rollback of Rapier or character work that
preceded the fault. The fallback's void successful tick path is unchanged.

**Current Web:** the synchronous owner pauses, opens the menu, reports restart/load
recovery, and suppresses painting, ticks, terrain/render publication and further
Rapier stepping while failed. Closing the menu or toggling pause cannot retry.
Rapier's preceding step is not rolled back. Reset/restart or a validated saved-level
replacement creates fresh activity and clears the fault; invalid import preserves it.

The adapter returns `false` with first-error telemetry, zeroes unsuccessful tick
statistics, exposes attempted/completed identity separately, and does not count
rejected repeat calls as new failures. Its reset prepares a candidate before swap.
Godot level export rejects failed state; CYSD1 replacement is level recovery, not
exact replay. Region/configuration requests may be latched while failed, but cannot
wake or advance that world. Fresh setup uses the latest requested region.

**Rejected for this fix:** rollback, automatic retry, resuming partial state and
silent event replay. **Planned separately:** state-preserving live capacity growth
and complete replay. [Dated regression evidence](../audits/2026-09-08-issue-1-failed-ticks.md)
separates source tests, Windows owners and browser coverage.

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
