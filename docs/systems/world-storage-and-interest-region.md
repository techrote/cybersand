---
title: World storage and interest region
document-kind: contract
canonical-for: [world-storage, camera-interest-region]
status: Current
scope: Sparse native storage, finite adapters, bounded interest pause/resume, planned persistence/reconfiguration and deferred streaming
last-reviewed: 2026-09-19
related-documents: [activity-dirty-regions-and-waking.md, ../architecture/chunk-tile-and-buffer-model.md, ../reference/configuration-reference.md, ../reference/level-saves-and-replay.md, ../decisions/ADR-004-interest-region-and-reconfiguration.md]
---

# World storage and interest region

**Current:** native World supports sparse signed-coordinate storage and explicit
capacity limits. Desktop and Web use finite 1024×1024 adapters. Camera-interest
filtering in the phased backend pauses excluded work and wakes newly included
resident activity blocks once at tick entry, without elapsed-time catch-up. Safe live capacity expansion is
**Planned**; broad world streaming is **Deferred** until the local foundation is mature.
General sparse-world persistence is also **Planned**; the existing CYSD1 format
reconstructs only a finite demo level.

A “2×” workload is a validation target whose dimensions must be stated; it is
not a maximum world size or proof that storage streaming exists. Current finite
demo dimensions and reserved capacities do not define the future stored-world limit.

Source identity is recorded in the [checkpoint](../operations/source-checkpoint-and-recovery.md);
dated execution and artifact limits are in the [evidence ledger](../reference/validation-evidence.md).

## Storage and region vocabulary

[World](../../native/include/cybersand/world.hpp) and
[world.cpp](../../native/src/world.cpp) use signed 64-bit chunk coordinates,
floor division/positive modulo for negative coordinates, sparse chunk lookup,
compact cells, activity metadata, and an optional per-chunk temperature array.

| Term | Current meaning or future scope |
|---|---|
| Stored world | **Approved** concept: all persistent world content; no general sparse serializer exists |
| Resident/loaded chunks | Native chunks currently allocated in World |
| Interest region | Optional rectangle used to select phased scheduling cores |
| Active blocks/chunks | Resident work whose activity metadata requests scheduling |
| Rendered region | Camera-selected portion of a published finite texture |
| Reserved capacity | Explicit storage/work/field/snapshot limits; not the stored world's dimensions |

`reserve_region` prepares resident chunks and optionally temperature storage.
Lazy preparation can allocate during a tick; preallocation and allocation
observations are therefore meaningful. Reservation is not a streaming manager.
The [configuration reference](../reference/configuration-reference.md) owns
construction defaults and the [capacity guide](../operations/configuration-and-capacity-budgets.md)
owns failure/preparation procedures.

## Interest filtering and re-entry

**Current, phased native backend:** `gather_active_cores` includes a 64×64 core
when it intersects `simulation_region_`. It scans the selected core, with the
scheduler's declared write reach; exact per-cell clipping to the interest
rectangle is not implemented. Leaving the region retains cell contents.

**Current, serial native backend:** `tick_serial` does not consult
`simulation_region_`. It is not an interest-filtering reference equivalent to
the phased path.

**Current, issue #2:** `set_simulation_region` validates positive dimensions and
non-overflowing inclusive endpoints, and latches the requested rectangle in O(1).
It converts it to inclusive core coverage. At the next tick's existing activity
metadata reset pass, `begin_tick` compares requested coverage with the last applied
coverage. Resident blocks touching newly included cores become active with zero
quiet time, including previously sleeping blocks. Overlap that was already
included is not woken. Clearing the filter includes all resident cores.

Excluded active blocks retain pending activity and quiet time. Changed blocks
still reset quiet time; unchanged blocks age only when their entire core coverage
is selected. This is conservative for custom single-worker geometry where one
activity block spans multiple cores. Default aligned geometry has one containing
core per block. Existing active-chunk counts include retained offscreen work;
selected-core counts measure actually scheduled work.

### Unchanged regions and bounded work

Equivalent core coverage, unchanged requests and A-to-B-to-A requests coalesced
before a tick do not wake work repeatedly. Region handling adds no sparse-world
lookup pass, cell scan, transition queue or per-tick allocation: it reuses existing
resident activity metadata passes. Those pre-existing passes and epoch-wrap cell
clears are not removed. Work remains bounded by resident and candidate capacities;
core candidate entries still count before deduplication, so re-entry can explicitly
fail capacity even where several blocks touch the same core.

### Excluded rules and failed-world recovery

**Approved choice, Current:** the owner delegated activation policy to engineering
judgement on 2026-09-08. Exclusion pauses ordinary rules, not explicit external
writes/events or the bounded reach of selected neighbors. Contents, temperature,
compact material state and pending activity survive. Re-entry rechecks eligibility
once and resumes ordinary selected ticks, without advancing lifetimes or moving
material to compensate for wall time. This does not fix every material-specific
cadence/sleep interaction (roadmap F04). Serial deliberately retains whole-active-
chunk stepping and ignores the region; cross-mode equality is not promised.

**Current combined boundary:** failed Worlds latch region requests but reject tick
entry, so neither activity transition nor re-entry can revive partial state.
Clear/reset or validated replacement establishes fresh activity under the latest
request. A later expansion can fail again if its selected work exceeds capacity;
there is no automatic retry, live resize or event replay. See
[ADR-004](../decisions/ADR-004-interest-region-and-reconfiguration.md) and
[failed ticks](../architecture/simulation-tick-and-threading.md).

**Historical evidence:** the preserved F02 diagnostic showed excluded Sand at
(400,32) sleeping, remaining frozen on return, and waking after a neighboring write.
It reproduced against intake `bfac0bc`; serial advanced throughout exclusion.
The [foundation audit](../audits/2026-09-08-foundation-diagnostics.md) remains intact.
The [issue #2 acceptance record](../audits/2026-09-08-issue-2-interest-regions.md)
identifies new regressions, artifacts and remaining platform gaps separately.

## Finite Godot adapters

[CyberNativeCellWorld::set_simulation_window](../../godot/native_extension/cyber_native_cell_world.cpp)
clamps camera bounds/margins to the 1024² adapter and forwards the rectangle.
Disabling the window selects the entire finite area; it does not add streaming.

Desktop [main.gd](../../godot/scripts/main.gd) selects view and per-side pixel
margins independently. Web [web_demo_controller.gd](../../godot/scripts/web_demo_controller.gd)
pairs quality with view, margin, and publication choices. Exact presets belong
to [configuration](../reference/configuration-reference.md); controls belong to
[Material Lab](../MATERIAL_LAB.md). The GDScript fallback has separate activity,
frozen-wake retention, and optional sparse-flight sampling.

## Persistence boundary

**Current:** CYSD1 reconstructs a fixed demo level. It is neither a general
WorldStorage format nor exact continuation. Its cell layout, validation,
exclusive export ownership, state omissions, and body tolerance belong to the
[level-save contract](../reference/level-saves-and-replay.md).

**Planned:** sparse persistence, schema migration, general serialized
configuration, replay capture and I/O backpressure. **Deferred implementation:**
broad streamed loading/eviction until local material behavior is mature.

## Approved expansion and unresolved policy

**Current granular interaction state:** a source block's pending Mercury deadline
is retained while excluded. Due included blocks wake in the existing metadata
pass; re-entry evaluates the current global lane without accumulated motion.
Failed-world quarantine still blocks tick entry, and recovery discards old
deadlines. See [activity](activity-dirty-regions-and-waking.md) and the
[pair policy](granular-interaction-policy.md) for ownership and bounds.

[ADR-004](../decisions/ADR-004-interest-region-and-reconfiguration.md) approves
explicit serializable interest/capacity policy and a safe boundary for expansion.
The proposed 10% horizontal/20% vertical margins have no frozen per-side-versus-total
interpretation; current pixel presets do not implement a universal formula.

**Planned:** diagnose capacity need, pause at a safe boundary, drain workers and
leased views, reserve replacement resources, publish a complete valid state, and
resume. No live drain/resize/publish protocol exists.

Open decisions for future fields/streaming include field catch-up, prefetch/loading ownership, rapid camera
movement under insufficient capacity, multiple interest sources, and separate
render margins. **Rejected:** silently clipping a requested production region
to hide capacity failure, hidden hot allocation as expansion policy, or treating
the finite demo dimensions as the permanent world limit.

## Issue17 experimental carrier

The [precision experiment](../operations/state-precision-experiment.md) reuses
validated uint64 mask/shift storage with fixed size/stride/alignment8/8/8 and epoch8
for every arm. Its dedicated branch uses spare40-bit state capacity for mass10;
that dated experiment did not change its 4-byte production control. Later Current
source `de332ea` uses physical 8-byte `PrecisionStorage`; the
[source-qualified storage contract](../architecture/chunk-tile-and-buffer-model.md#what-is-stored-per-cell-and-per-chunk)
governs that accounting without selecting G-final or changing historical controls.
[G-P evidence](../audits/2026-09-11-issue-17-state-precision.md) selects no permanent
Cell layout, sidecar, larger ID catalogue or storage/scheduler geometry.
