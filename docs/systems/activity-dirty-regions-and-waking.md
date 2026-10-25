---
title: Activity, dirty regions, and waking
document-kind: contract
canonical-for: [cell-activity-sleep-wake, simulation-render-dirty-state]
status: Current
scope: Native activity and dirty-state lifecycle; separate fallback behavior and future wake requirements
last-reviewed: 2026-10-25
related-documents: [world-storage-and-interest-region.md, materials-and-rule-kernels.md, ../architecture/chunk-tile-and-buffer-model.md, ../architecture/rendering-and-gameplay-bridges.md]
---

# Activity, dirty regions, and waking

**Current:** native World schedules potentially changing material through activity
blocks and preserves render dirtiness until publication succeeds. Activity and
render dirtiness are different state: a rule waiting for its next cadence can
stay awake without creating a render patch. Phased interest exclusion preserves
pending activity; newly included blocks receive one eligibility wake at tick entry.

This contract covers inspected source at the
[secured checkpoint](../operations/source-checkpoint-and-recovery.md). Executed
checks and platform limits belong to the [evidence ledger](../reference/validation-evidence.md).

## Native activity lifecycle

[World](../../native/src/world.cpp) owns `Chunk::ActivityBlock` metadata:
`active`, `changed_this_tick`, `quiet_ticks`, and `next_interaction_tick`. The default 32×32 activity
block is independent of the 64×64 scheduling core and 128×128 storage chunk;
[configuration](../reference/configuration-reference.md) owns exact defaults.

1. `begin_tick` resets change observations, wakes newly included phased blocks
   in the same metadata pass, and applies accepted explosions at
   the tick boundary. Event-written cells receive the current epoch and start
   ordinary material updates on the following tick.
2. `gather_active_cores` selects cores from active blocks for the phased backend.
   Selection includes an interest-region intersection test; it does not clip
   every write to the exact camera rectangle.
3. Each phase mutates its exclusive cell domains. Jobs collect bounded
   `JobEffects`; the coordinator merges them in deterministic job order.
   Workers read phase-stable activity/chunk flags and deadlines. Keepalive and
   earliest-deadline requests go to preallocated job-owned grids; shared flags,
   quiet counters, deadlines and actual `BlockWake` transitions are published
   only at the phase barrier. Disjoint cell halos can share a chunk or activity
   block, so those metadata stores are not worker-exclusive.
4. `finish_tick` resets quiet time for changed blocks. Unchanged active blocks
   age toward `sleep_after_quiet_ticks` only when their whole core coverage is
   selected; excluded/straddling blocks retain quiet/activity state. Serial ages
   all active blocks. Chunk activity includes retained offscreen work.

This is in-place cell mutation with merged observations, not a buffered transfer
commit. Some delayed secondary rules use `keep_cell_active` to set activity/change
metadata without changing cell bytes or render dirtiness. Persistent compact-pair
and Ice contacts instead retain their next opportunity through the existing block
deadline. Their cadence belongs to [material kernels](materials-and-rule-kernels.md).

The authoritative grids cover the complete scheduled core plus its configured
write-radius halo, including the IN operator's final actual carrier. Their
capacity does not depend on the optional discovery observer's 64-record report
arrays. Metadata reduction runs before the discovery-disabled, overflowed or
halted observer paths; lost observer coverage cannot discard scheduling work.
An authoritative grid-bound failure throws and quarantines the World. Serial
work without `JobEffects` retains its direct metadata path. The grids use two
contiguous `ParallelState` buffers with fixed disjoint spans for each job;
construction checks the complete capacity product before binding those spans,
and neither owner resizes during ticks. The
[configuration reference](../reference/configuration-reference.md#native-worldconfig-defaults)
records setup storage and clear/reduction work; the
[dated native evidence](../audits/2026-10-25-water-inertial-native.md#worker-activity-publication-repair--2026-10-25)
preserves the Linux TSan failure and the repair's exact local scope.

## What wakes a region?

Direct `set`/`write_cell` operations mark their cells dirty and active.
`wake_cell_neighborhood` wakes resident nonempty neighbors when the changed
coordinate lies at an activity-block edge or corner. Movement marks both source
and destination. The phased `merge_job_effects` path additionally wakes through
the corners of touched block bounds, so its wake can be broader than one direct
cell write.

Explosion edits and transient-obstacle changes use explicit wake paths. A mask
insertion or removal explicitly wakes its own resident block without a render
write, then applies the ordinary boundary-neighbor wake. The neighbor helper
alone excludes the center block because ordinary material writes already wake it.
Mask changes must not depend on a neighboring material write to resume contact.
The current body-coupling path rebuilds masks, so it can wake touched interior body
blocks even for stationary bodies; this is confined to that existing footprint.
Settled Water can become inactive; render dithering does not wake it.

**Current:** a denied slow Mercury pair records the earliest due tick in its
source block. The existing `begin_tick` metadata pass wakes due included blocks
and clears their deadline. Sleeping blocks therefore progress without a periodic
cell scan. Excluded deadlines remain pending; re-entry evaluates only the current
modulo lane, with no missed-move catch-up. Clear/replacement discards these
deadlines and failed-world quarantine prevents their processing. The
[versioned pair policy](granular-interaction-policy.md) owns rate and endpoint rules.

**Current, MAT-001 / #158:** `World::schedule_pending_reaction_wake` uses that same
earliest block deadline for an eligible compact-pair contact or an Ice thermal
contact. It runs after an admitted kernel when the source itself was not written
in the current epoch, including successful neighbor-only work. Eligibility uses
the existing pair resolver and mask-aware neighbors, independent of the current
probability roll. The deadline is strictly in the future, so a missed sample can
receive another scheduled opportunity. Waiting does not alter cell content,
movement counts or render dirtiness; an inert contact acquires no new deadline.

The deadline is shared by all work in a block. Removing one partner does not
cancel a deadline that may belong to another source or a transport lane; one
already scheduled wake can retire normally after re-evaluation. Interest exclusion,
re-entry, clear and failed-world handling use the existing lifecycle above.
The [dated regression record](../audits/2026-10-18-mat001-material-reaction-progress.md)
scopes the executed evidence. Other specialized kernels retain their own waiting
behavior; this is not a guarantee for every future material rule.

**Current:** newly included cores wake their resident blocks once, including
sleeping blocks. Existing overlap and unchanged/equivalent regions stay asleep.
The [pause/resume contract and backend distinction](world-storage-and-interest-region.md#interest-filtering-and-re-entry)
own retained state, coalescing, custom geometry, bounded work and failure/recovery.
No catch-up is performed. Explicit writes and neighbor reach can still affect
excluded cells; this is core scheduling, not an immutable per-cell freeze.

## Render-dirty lifecycle

[RenderSnapshotExchange::publish](../../native/src/world.cpp) captures
dirty rectangles in deterministic chunk order into an available preallocated
snapshot slot. Capture clears native dirty state only after every patch is
copied. `Backpressure` and `CapacityExceeded` preserve it.

A published immutable lease, desktop copied-patch retention, and successful
renderer acknowledgement are separate lifetimes. Desktop retains copied
unacknowledged patches; Web consumes snapshots synchronously. Their exact
ownership is defined by the [render bridge](../architecture/rendering-and-gameplay-bridges.md).
An unconsumed snapshot must never be made safe by dropping dirtiness.

| State | Meaning |
|---|---|
| Active block | Eligible for scheduling; it need not produce a write this tick |
| Sleeping block | Stored cells remain authoritative and queryable; ordinary scheduling stops |
| Render dirty | Committed presentation projection must be captured |
| Serialization dirty | **Planned**; no general persistence acknowledgement exists |

## Desktop fallback difference

[CyberCellWorld](../../godot/scripts/cell_world.gd) uses 16×16 blocks,
per-cell quiet state, movable counts, and serial scans by default. Out-of-interest
blocks retain their wake flags. The old load-derived adaptive block stride was
removed: current counters report stride one and zero deferred blocks. Optional
sparse free flight advances isolated eligible cells two positions on alternate
ticks above its active-block threshold; it is not broad block deferral. These
fallback semantics do not describe native/Web geometry or native re-entry.

Fallback stores one deadline per fixed block. A due included block is woken and
its per-cell quiet counters reset within that block; excluded blocks retain the
deadline. This bounded local cell reset differs from native block-only quiet state.

## Approved requirements and open work

**Approved:** new fields/events must declare wake reach, quiet eligibility,
delayed work, conservation, and interaction with interest filtering. Sleeping
interiors should not require a periodic full-cell scan to discover outside change.

**Current:** native re-entry follows the explicit pause/wake policy. **Planned:**
future field/streaming time semantics and separate persistence dirtiness once
storage serialization exists. No generalized field catch-up API is implemented.

[Native fixtures](../../native/tests/test_world.cpp) cover quiet sleep, local edge
wake, Water rest, capacity, and snapshot pressure. Their presence does not prove
every field/boundary combination. Extend shifted/mirrored edge tests when rule
reach changes. Issue #2 regressions cover exclusion, sleep, overlapping/disjoint
re-entry, core/chunk boundaries, unchanged/coalesced regions, neighbors, retained
temperature, conservation, worker parity and failed-world recovery. These are
bounded fixtures, not every future field or material combination.

## How does optional lateral cadence wake work?

**Current:** [transport profiles](flow-transport-and-profiles.md) gate lateral
liquid attempts with coordinate-stable phases and the existing earliest
per-block interaction deadline. Cadence 1 adds no delay; 2..60 can wake a blocked
liquid again even when no transport results. There is no separate queue, elapsed
excluded-work catch-up or motion inferred from wake flags. The new CLI resident
active-block count includes excluded blocks; scheduled-core/visited-cell counters
remain separate measures of tick work. Fixed-profile tests retain failed-world
quarantine, exclusion and one-step re-entry under extreme sampling/cadence.

## Characterized sleep versus liquid mobility

The [completed quiet3/4096 study](../operations/liquid-characterization.md#does-keeping-water-awake-fix-residual-leveling-or-films)
separates scheduler-censored deterministic mobility from material cadence and
stable Water rest. Four tested whole-cell trajectories differ, while all tested
Water trajectories match. This scoped observation does not change default sleep,
Mercury deadlines, pause/re-entry or production instrumentation.
