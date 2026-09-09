---
title: Configuration and capacity budgets
document-kind: runbook
canonical-for: [capacity-preparation-and-failure, safe-reconfiguration-requirements]
status: Current
scope: Existing construction/reservation and capacity outcomes; approved preparation discipline and unimplemented live resize
last-reviewed: 2026-09-09
related-documents: [../reference/configuration-reference.md, ../systems/world-storage-and-interest-region.md, ../architecture/data-ownership-and-lifetimes.md, profiling-observability-and-performance.md]
---

# Configuration and capacity budgets

**Current:** native World construction, region/temperature reservation, event
capacity, and snapshot slot/patch/byte limits exist. **Planned:** general saved
configuration and safe live pause/drain/resize/publish. Explicit capacity failure
does not mean a failed tick is rolled back atomically.

This page owns preparation and failure semantics. Exact values belong to the
[configuration reference](../reference/configuration-reference.md); identity and
executed checks belong to the [checkpoint](source-checkpoint-and-recovery.md)
and [evidence ledger](../reference/validation-evidence.md).

## What can be configured now?

[WorldConfig](../../native/include/cybersand/world.hpp) is a construction-time
value mirrored by versioned `cybersand_config_v2` in the
[C ABI](../../native/include/cybersand/c_api.h). It controls geometry, workers,
quiet thresholds, resident/active/planning capacities, and accepted explosions.
Godot's finite adapter overrides several standalone defaults. Auto chooses
workers when constructing a world; it does not resize a running pool.

[RenderSnapshotExchange](../../native/include/cybersand/render_snapshot.hpp)
has separate mandatory slot, patch-per-slot, and byte-per-slot capacities.
The finite adapter chooses concrete values, but the general API supplies no
production defaults.

Capacity bounds allocated work/storage; it is not a permanent stored-world
dimension. Native lazy preparation can allocate chunks/temperature during a tick.
The Approved goal of allocation-free prepared ticks is narrower than a claim
that all current ticks and callers allocate nothing.

## Current preparation procedure

1. Identify backend, geometry, worker count, resident/active capacities and
   intended loaded/interest extents. Account for movement/write reach beyond
   scheduled cores, not only visible pixels.
2. Construct World with explicit limits. `initial_chunk_reserve` is a
   reservation hint, not the hard resident limit.
3. Call `reserve_region` for required chunks and
   `reserve_temperature_region` where temperature will be needed.
4. Construct snapshot storage for the intended publication policy, then
   populate/load before the normal tick loop.
5. Exercise boundary crossings and observe `TickStats::chunk_allocations`
   and `temperature_field_allocations`. Zero counts cover those World-owned
   allocations only.
6. Observe resident payload bytes, planned work, event acceptance, snapshot
   required bytes/patches and high-water, and explicit failures. Retain command,
   input, source/artifact, and platform evidence.

[Native fixtures](../../native/tests/test_world.cpp) test bounded construction,
preallocated movement, event queue limits, and snapshot pressure. They do not
implement or validate a live resize protocol.

## Explosion queue rejection and exhausted simulation space

**Current:** enqueueing too many explosions returns false; accepted events apply
at tick entry. Running out of resident or active simulation capacity throws and
may leave a partially advanced tick. Such a World is latched failed: subsequent
ticks, writes, reservation and publication are rejected until explicit clear or
replacement. Accepted events are never automatically replayed. Reserved space reduces allocation pressure;
lazy preparation may still allocate chunks or temperature fields. Adapter limits
differ from standalone WorldConfig defaults, and live resizing is **Planned**.
Avoiding hot tick allocation is an **Approved** requirement; the **Current**
zero-allocation evidence is limited to prepared fixtures and their World-owned
chunk/temperature counters, not every caller or allocation category.
The API-specific outcomes are:

| Boundary | Current outcome | Limitation |
|---|---|---|
| Invalid World construction | Throws before a usable World is returned | Constructor constraints are in `World::World` |
| Resident/active chunk or core capacity | Explicit exception | Work may already have mutated this tick; no atomic rollback guarantee |
| Explosion queue full/invalid request | Enqueue returns false | Caller must inspect acceptance |
| Snapshot slots unavailable | `Backpressure` | Dirty state retained |
| Snapshot patch/byte capacity insufficient | `CapacityExceeded`, exact requirements | Dirty state retained |
| Native Godot tick exception | Adapter reports false/error once and latches failure | Desktop/Web stop and retain last valid publication; reset/replacement required |
| Generalized command/transfer queue | **Planned** | No complete shared queue-pressure contract |

Sources: [World](../../native/src/world.cpp),
[snapshot publication](../../native/src/world.cpp), and
[native adapter](../../godot/native_extension/cyber_native_cell_world.cpp).
Core candidates are capacity-checked before deduplication, so the bound is not
simply the number of unique output jobs. The
[threading contract](../architecture/simulation-tick-and-threading.md) owns
desktop/Web tick-failure handling.

**Rejected as a future policy:** silently clipping requested regions, dropping
accepted commands/dirty state, or hiding hot growth as safe expansion.
These prohibitions are requirements, not a promise that every current failure
preserves a pre-tick snapshot.

## Approved reconfiguration requirements

[ADR-004](../decisions/ADR-004-interest-region-and-reconfiguration.md) approves
explicit serializable capacity and interest policy. **Planned implementation:**
diagnose requested/available capacity, reach a safe boundary, drain affected
workers and leased views, prepare replacement resources, preserve committed
state and pending commands, publish a complete valid state, then resume.

The API, pause/rejection behavior, failure recovery, serialization keys/migration,
and production memory/high-water thresholds remain open. Proposed 10%/20%
margins have unresolved per-side/total semantics; current presets are explicit
pixel pairs. Current region changes follow the separate
[pause/re-entry contract](../systems/world-storage-and-interest-region.md#interest-filtering-and-re-entry);
waking new coverage can exhaust existing candidate capacity (counted before
deduplication). That produces an explicit quarantined failure, not automatic
capacity growth or retry. Offscreen retained activity still counts toward active
chunk capacity. Region pause/resume does not implement live resize.

CYSD1 stores a fixed level and selected metadata, not complete WorldConfig or
replay state. Follow the [level-save contract](../reference/level-saves-and-replay.md).

## Future acceptance gate

A live-resize change needs near-capacity and over-capacity fixtures, current and
2× dimensions, explicit failed-transition behavior, preserved state and
unacknowledged dirtiness, no invalid worker/lease views, and measured allocation/
memory consequences. Declare whether “2×” means each dimension or total area.
Do not promote design requirements to Current on source presence alone.

## How are physics diagnostics bounded?

**Current:** the [measurement runbook](physics-characterisation.md) defines 256
histogram slots per scheduled-core scratch slot and 8,192 merged slots, allocated
only on opt-in World construction. Counter overflow is explicit and drops
observations. Body metrics use the existing 16-body bound, with fixed scalar and
4-by-81 face/material counters. Copied cell observations are limited to 512 by
768 cells; fixture runs are bounded to 7,200 ticks and 512 cases per invocation.
Rapier application observations use six scalars per body.

Native tick and coupling timings, used slots, core/chunk high-water marks and
overflow are retained in the [dated baseline](../audits/2026-09-09-physics-characterisation.md).
Offline snapshots, retained traces and postprocessing costs are outside hot-loop
budgets. These measurements do not establish a production performance target.

## Sampled support query budget

[Granular policy](../systems/granular-interaction-policy.md) bounds native queries
to 32 by 32 boxes, at most 20 stable-material samples per contact and 128
enclosure candidates. Native queries allocate no storage; no worker read/write
domain or Rapier shape is added.
