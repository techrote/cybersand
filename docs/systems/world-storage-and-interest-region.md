---
title: World storage and interest region
document-kind: contract
canonical-for: [world-storage, camera-interest-region]
status: Current
scope: Sparse native storage, finite adapters, interest pause/resume and fresh generated-chunk admission; general persistence/reconfiguration/streaming remain separate
last-reviewed: 2026-11-25
related-documents: [activity-dirty-regions-and-waking.md, ../architecture/chunk-tile-and-buffer-model.md, ../reference/configuration-reference.md, ../reference/level-saves-and-replay.md, ../decisions/ADR-004-interest-region-and-reconfiguration.md]
---

# World storage and interest region

## World size, capacity and camera interest

**Current:** native World supports sparse signed-coordinate storage and explicit
capacity limits. Ordinary demo/Web level exchange uses a1024×1024 backing;
Shared Workbench has its own finite512–2048-per-axis authoring schema and fresh
2048×2048 setup. These host bounds do not limit native signed sparse coordinates.
See [`workbench_setup.gd`](../../godot/scripts/workbench_setup.gd). Camera-interest
filtering in the phased backend pauses excluded work and wakes newly included
resident activity blocks once at tick entry, without elapsed-time catch-up. Safe live capacity expansion is
**Planned**. Persistent areas with bounded game-time catch-up are approved owner
direction and have separate unmerged GEN-006 candidates; this accepted baseline
does not include their residency/cache manager. General sparse-world persistence
and continuous streaming remain separate. CYSD1 reconstructs a finite demo level;
Workbench authored starts and native CYPS have their own narrower contracts in
[save and replay](../reference/level-saves-and-replay.md).

**Current GEN-001/GEN-002 source:** opt-in native procedural generators can prepare
complete deterministic chunks on demand, and `World::install_generated_chunk`
can admit one absent chunk through the exclusive owner. The workbench generates
copied previews in its own bounded cache. These additions do not supply the
Deferred manager for loading/evicting simulation residents or the Planned
serializer for modified sparse worlds. See
[procedural generation](procedural-world-generation.md) for that implemented
candidate scope, [field/mask controls](procedural-generation-fields-and-modifiers.md)
for the extension, and the dated
[GEN-001](../audits/2026-10-18-gen001-procedural-generation.md)/[GEN-002](../audits/2026-10-18-gen002-fields-and-aggregates.md)
evidence for validation limits.

A world-size target described as “twice the camera” or “2×” is a validation
workload whose dimensions must be stated. It does not impose a native World
limit. Camera view, selected simulation interest, resident storage capacity and
the host's finite canvas are separately owned bounds. Current finite demo
dimensions and reserved capacities do not define the future stored-world limit
or prove that storage streaming exists.

Source identity is recorded in the [checkpoint](../operations/source-checkpoint-and-recovery.md);
dated execution and artifact limits are in the [evidence ledger](../reference/validation-evidence.md).

## Approved area intent and accepted behavior

The [14 November owner record](../decisions/2026-11-14-owner-authoring-intent.md#world-extent-persistence-and-time)
asks for one fixed canvas plus persistent areas, with useful approximation and
bounded catch-up measured in **game time**, not real offline wall time. Existing
interest-region re-entry only restores current eligibility; it does not implement
that catch-up. Do not turn a source limitation into a permanent rejection of the
owner's desired feature, or describe an unmerged RAMCACHE evaluator as accepted.
The [roadmap](../reference/status-and-roadmap.md) is the current programme route.

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

## What does fresh generated-chunk admission protect?

**Current:** [`World::install_generated_chunk`](../../native/src/world.cpp)
accepts exactly one row-major material span whose dimensions match the native
storage chunk. It checks the whole payload, coordinate arithmetic, capacity,
transient occupancy and current World/tick state before mutation. Every resident
chunk is refused, including empty reservations and chunks whose edits were later
cleared. Accepted cells use ordinary native initialization, activity and dirty
tracking; generation is not an alternate material simulation.

The caller owns recipe/receipt validation and the destination World/reset-session
check. The material-only admission method is not proof that a stale job still
belongs to a newly reset World. Use the
[ownership contract](../architecture/data-ownership-and-lifetimes.md) before
connecting it to a future streaming controller. The current generation workbench
preview cache evicts only copied previews. Ordinary Shared Workbench can adopt a
complete generated start through its prepared native/physical transaction; that
finite replacement is not streaming admission/eviction of a continuing World.
Context-aware sculpting reads immutable initial generator context; aggregate
recipes produce existing material IDs. Neither observes resident player changes,
changes the installer guard nor adds optional simulation field storage.

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
core candidates count distinct cores per chunk (several blocks touching one core
count once since the 2026-11-06 #406
[stress-canvas correction](../audits/2026-11-06-stress-canvas.md)), so re-entry can
explicitly fail capacity when it wakes more distinct cores than the budget.

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
retains camera bounds/margins and `refresh_simulation_region` clamps their
result to the adapter's actual `extent_` before forwarding the rectangle.
The legacy demo defaults to 1024²; an authored Workbench extent may differ.
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
configuration, replay capture and I/O backpressure. Accepted main has no general
streamed loading/eviction manager. Later owner direction and the separately
unmerged GEN-006 work are routed above; an older deferral does not cancel that
owner intent or establish that a candidate has landed.

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
