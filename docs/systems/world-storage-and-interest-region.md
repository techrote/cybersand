---
title: World storage and interest region
document-kind: contract
canonical-for: [world-storage, camera-interest-region]
status: Current
scope: Sparse native storage, finite adapters, interest re-entry defect, planned persistence/reconfiguration and deferred streaming
last-reviewed: 2026-09-08
related-documents: [activity-dirty-regions-and-waking.md, ../architecture/chunk-tile-and-buffer-model.md, ../reference/configuration-reference.md, ../reference/level-saves-and-replay.md, ../decisions/ADR-004-interest-region-and-reconfiguration.md]
---

# World storage and interest region

**Current:** native World supports sparse signed-coordinate storage and explicit
capacity limits. Desktop and Web use finite 1024×1024 adapters. Camera-interest
filtering exists in the phased backend, but **moving the region back does not
wake excluded blocks that have slept**. Safe live capacity expansion is
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

**Confirmed defect, phased native backend:** `finish_tick` ages excluded active
blocks along with other unchanged blocks. `set_simulation_region` only assigns
the rectangle. Consequently an excluded block may sleep and remain unscheduled
when the region returns, until a later explicit write or neighbor wake activates it.

A standalone Windows x64 diagnostic on 2026-09-08, built from checkpoint
`126175cfc4dd1fb8659212f62b9b517bac54d8c2`, placed Sand at (400,32), excluded
its core for four ticks, then restored the region. Active chunks fell to zero;
re-entry scheduled zero cores and left Sand unmoved. A neighboring write woke
it and it fell. The serial comparison moved Sand despite the same exclusion.
The [evidence ledger](../reference/validation-evidence.md) links this diagnostic
to `C:/kybersand/validation/local/20260908-rag-interest-probe/`: `interest_probe.cpp`
and `result.json` retain compiler, inputs, command, and timeouts. This confirms
a defect; it is not a passing re-entry acceptance test.

**Approved requirement:** panning must eventually reactivate newly included
eligible work deterministically without erasing state or inventing catch-up.
That requirement is not satisfied by the current setter. The narrow next
implementation step needs a wake/resume policy and regression covering exclusion,
re-entry, sleeping material, and the backend distinction.

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

[ADR-004](../decisions/ADR-004-interest-region-and-reconfiguration.md) approves
explicit serializable interest/capacity policy and a safe boundary for expansion.
The proposed 10% horizontal/20% vertical margins have no frozen per-side-versus-total
interpretation; current pixel presets do not implement a universal formula.

**Planned:** diagnose capacity need, pause at a safe boundary, drain workers and
leased views, reserve replacement resources, publish a complete valid state, and
resume. No live drain/resize/publish protocol exists.

Open decisions include field catch-up, prefetch/loading ownership, rapid camera
movement under insufficient capacity, multiple interest sources, and separate
render margins. **Rejected:** silently clipping a requested production region
to hide capacity failure, hidden hot allocation as expansion policy, or treating
the finite demo dimensions as the permanent world limit.
