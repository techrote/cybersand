---
title: Activity, dirty regions, and waking
status: Current
scope: Current prototype activity behavior and adaptive cadence, approved tile sleep/wake semantics, consumer-specific dirty state, interest filtering, and diagnostics
keywords: [active tile, sleeping, wake neighbor, dirty region, buried volume, quiet ticks, active growth]
related-documents: [../architecture/chunk-tile-and-buffer-model.md, world-storage-and-interest-region.md, ../operations/troubleshooting.md]
last-reviewed: 2026-09-08
implementation-state: Native World has 32×32 activity blocks, local quiet/sleep state, cross-block wake, and per-chunk dirty rectangles; the GDScript fallback alone uses 16×16 adaptive activity. Native secondary interactions already use fixed spatial cadence lanes.
---

# Activity, dirty regions, and waking

Current source anchors are [World activity and JobEffects](../../native/src/world.cpp),
[WorldConfig](../../native/include/cybersand/world.hpp), and the
[GDScript fallback](../../godot/scripts/cell_world.gd). Native fixtures are in
[test_world.cpp](../../native/tests/test_world.cpp). Source review is distinct
from a passing run; the [2026-09-08 audit](../audits/2026-09-08-documentation-audit.md)
records the local identity and dated validation scope.

## At a glance

- Purpose: avoid processing stable buried volumes while preserving correct wake propagation.
- **Current**, GDScript fallback: 16×16 active blocks plus per-cell quiet and movable counts; this is not the native/Web activity geometry.
- **Current**: native World uses 32×32 activity blocks independently of 64×64 scheduling cores and 128×128 chunks.
- **Current**: each block has active, changed-this-tick, and quiet-tick state.
- **Current**: crossings and writes wake affected local and edge-neighbor blocks.
- **Current**: settled Water and buried stable material blocks stop scheduling.
- **Current**: bounded explosion edits wake affected blocks, and failed snapshot publication preserves dirty state.
- **Current**, fallback only: adaptive stride derives from eligible blocks, keeps the immediate interest neighbourhood full-rate, and preserves deferred wake flags.
- **Current**: native secondary interactions use 2/4/8/120-tick spatial lanes; primary eligible transport remains full-rate. **Planned**: optional-field scheduling and a generalized delayed-rule wake contract.

## Search anchors

buried volumes frozen, nearby cells changed, wake boundary, active tile count, dirty versus active, water never sleeps, active-region explosion

## Current GDScript fallback behavior

godot/scripts/cell_world.gd contains:

- ACTIVITY_BLOCK_SIZE set to 16;
- active_blocks and next_active_blocks;
- updated_at and quiet_ticks arrays;
- block_movable_counts;
- CELL_SLEEP_TICKS set to 8;
- mark_current_area, mark_next_area, and _wake_cell_area;
- simulation-window and cadence filtering.
- a soft target of 12 active blocks per worker tick under overload, with full-rate radius one in block space.

CyberCellWorld scans active blocks serially. Material moves mark local areas, update per-cell epochs, and affect block scheduling.

Long lateral moves now wake and schedule bounded regions at their source and
destination instead of every intervening column. A vertical move into Empty
leaves the vacated source eligible for a later cell in the bottom-up pass; this
removes the previous every-other-row stepping mechanism while retaining a
write-once destination.

## Current native behavior

native/src/world.cpp stores per-chunk:

- active;
- changed_this_tick;
- quiet_ticks;
- dirty bounds;
- a grid of ActivityBlock records containing active, changed_this_tick, and quiet_ticks.

World::tick gathers scheduling cores only from active blocks, increments each
block's quiet counter, sleeps it at the configured threshold, and wakes local
edge neighbors after relevant changes. Dirty rendering remains a per-chunk
rectangle and can now be published into reusable immutable snapshot slots.

## Current native activity concepts

| Concept | Owner | Meaning |
|---|---|---|
| active storage chunk | WorldStorage | At least one tile/field requires scheduled or wake-boundary work. |
| active activity block | World metadata consumed by phased planning | The 32×32 block has eligible work this tick. |
| sleeping tile | WorldStorage | No currently eligible work, while committed state remains authoritative and queryable. |
| wake observation | JobEffects merged by World | A crossing or state change makes a block or neighbor eligible. |
| simulation dirty | SimulationCore/WorldStorage | Authoritative state changed. |
| render dirty | Snapshot planning state | Presentation data derived from authoritative state changed. |
| serialization dirty | **Planned** WorldStorage responsibility | Persisted representation is older than committed state. |

These concepts may share compact metadata only if ownership and acknowledgement remain distinct.

## Sleep eligibility

### Approved requirements for generalized sleep

A tile or finer activity block may sleep only when:

- no relevant nearby authoritative cell or field has changed during the configured recent-tick window;
- no pending transfer targets it;
- no queued command requires it;
- no rule-specific delayed state requires continued work;
- its required boundary layer remains able to detect incoming change;
- sleeping does not change conservation or deterministic replay.

These are constraints for future extensions, not evidence that generic transfer,
streaming, or delayed-field queues already exist. Current native sleep is
implemented by activity-block changes/keep-awake observations and
`WorldConfig::sleep_after_quiet_ticks` (default 3); fallback cell sleep uses 8.

### Unresolved production details

- exact recent-tick timeout;
- whether activity uses per-cell epochs, sub-tile masks, lists, or multiple levels;
- boundary-layer thickness;
- whether different fields use different quiet cadences;
- how distant lower-frequency fields interact with deterministic tick identity.

Current values such as CELL_SLEEP_TICKS are prototype evidence, not approved defaults.

## Wake propagation

**Approved design**: wake state is derived during a tick and becomes authoritative through the deterministic commit path.

Wake causes include:

- material crossing a worker-tile or storage-chunk boundary;
- local material identity or phase changing;
- conserved mass/flux entering or leaving a region;
- a command modifying the region;
- a loaded neighbor becoming available;
- a field interaction changing rule eligibility.

A crossing wakes the destination and any source/neighborhood regions required by the affected rules. Exact neighborhood extent follows approved rule reach and halo requirements; it is not yet specified.

## Boundary-layer principle

Sleeping interiors must not require periodic full scans solely to discover outside interaction.

The approved design retains an active or observable outer boundary around sleeping groups so that:

- incoming material or field changes are noticed;
- a transfer cannot enter a permanently frozen region;
- waking propagates inward as change advances;
- large buried stable volumes remain unscheduled.

The current implementation wakes adjacent blocks only when a changed cell lies
on the local block boundary. External explosions apply explicit cell writes at
the tick boundary, so each affected block is marked/woken without scanning
static Wall. General field radii and worker-produced long-range events remain
**Planned**.

## Interest-region interaction

- Tiles outside the camera-centred interest region and margin are not normally simulated.
- Moving the region makes newly included loaded tiles eligible according to an approved activation transition.
- Pausing an out-of-region tile must preserve its authoritative committed state.
- Re-entry cannot discard pending serialized state or create material.
- Capacity limits cannot silently reduce the requested interest region.

The exact catch-up policy for time-dependent fields outside the interest region is **Ambiguous**.

The GDScript proof's Current catch-up policy is simpler: deferred active blocks
remain active and a coordinate/tick phase selects them on later worker ticks.
This is temporal approximation, not loss of state or spatial cell merging.

## Dirty-state lifecycle

1. **Current** phased jobs mutate cells within exclusive write domains and collect local `JobEffects` observations.
2. The coordinator merges activity/dirty observations in deterministic job order after each completed phase; this is not a buffered cell-transfer commit.
3. `RenderSnapshotExchange` copies dirty chunk bounds in sorted chunk order into an unleased preallocated slot.
4. Dirty state is cleared only after all patch bytes are captured; `Backpressure` and `CapacityExceeded` leave it intact.

**Planned**: buffered output/transfer commits and serialization-specific dirty
acknowledgements. Desktop's copied snapshot retention and renderer acknowledgement
are a separate layer; Web consumes synchronously. See
[rendering bridges](../architecture/rendering-and-gameplay-bridges.md).

Snapshot pressure must not cause dirty information to disappear.

## Required observations

The approved profiler must expose:

- active storage chunk count;
- active worker tile count;
- active/scanned cell count where available;
- dirty upload bytes through the rendering observations.

Exact metric field names are not approved.

The current Godot overlay also reports dormant, frozen, and deferred work counts. Those are **Current** prototype counters, not approved production metric names.

## Validation requirements

The list below is a regression checklist, not an assertion that every combination
has a current passing run. Existing native test functions cover sleep, edge wake,
conserved Water, capacity, and snapshot lease/pressure behavior; generalized
streaming/transfer cases remain future acceptance work.

- buried stable solid and water volumes eventually stop scheduling interior work;
- a crossing wakes the correct neighbor across every tile and chunk edge;
- an external change propagates into a sleeping volume;
- no wake is lost under full transfer/snapshot pressure;
- moving the interest region activates newly included tiles deterministically;
- a settled water fixture remains authoritative-state stable;
- active counts do not grow indefinitely after all external activity stops.

## Related decisions

- [ADR-002](../decisions/ADR-002-double-buffered-tile-jobs.md)
- [ADR-004](../decisions/ADR-004-interest-region-and-reconfiguration.md)
- [Water design](water-design.md)
- [ADR-008](../decisions/ADR-008-bounded-approximate-fidelity.md)
