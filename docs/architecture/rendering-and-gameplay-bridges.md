---
title: Rendering and gameplay bridges
document-kind: contract
canonical-for: [render-publication-and-gameplay-bridge-behavior]
status: Current
scope: Native publication outcomes, Godot render consumption and current gameplay commands; resource lifetime and wire layouts are linked
keywords: [RenderBridge, GameplayBridge, RG8, immutable snapshot, full texture upload, backpressure, emission queue]
related-documents: [data-ownership-and-lifetimes.md, rigid-body-and-cellular-coupling.md, ../reference/interfaces-and-message-contracts.md, ../systems/material-appearance-and-rendering.md]
last-reviewed: 2026-10-19
---

# Rendering and gameplay bridges

## Can rendering read native cells directly?

**Current:** display consumers receive copied immutable data. They never retain
mutable World/chunk pointers. `RenderSnapshotExchange` provides native leases;
`CyberNativeCellWorld::take_render_snapshot` copies their data into Godot value
arrays. Desktop accumulates/publishes these through `CyberSimulationSnapshot`;
Web consumes copied packets synchronously on the main thread.

Source: [native exchange](../../native/src/render_snapshot.cpp),
[Godot adapter](../../godot/native_extension/cyber_native_cell_world.cpp),
[desktop publication](../../godot/scripts/simulation_worker.gd) and
[Web publication](../../godot/scripts/web_demo_controller.gd).
Lease and acknowledgement lifetimes are canonical in
[data ownership](data-ownership-and-lifetimes.md); exact field layouts belong in
[interfaces](../reference/interfaces-and-message-contracts.md).

## What does native publication return under pressure?

**Current:** the single producer serializes publication with World mutation.
It copies dirty rectangles in deterministic chunk-coordinate order into
preallocated slots, with tightly packed two-byte material/condition rows.
The condition byte is a material-selected projection of compact state, not a
second authoritative simulation field.

| `RenderPublishStatus` | Meaning | Dirty state |
|---|---|---|
| `Published` | A complete payload fits an unleased slot | Acknowledged after successful capture |
| `NoChanges` | Nothing dirty to publish | No lost pending changes |
| `Backpressure` | All slots are leased | Retained for later publication |
| `CapacityExceeded` | Required patch or byte capacity exceeds a slot | Retained; required counts reported |

Slot selection reuses the oldest unleased slot. Publication does not block
waiting for consumers. Required counts, high-water use and failure totals are
observable. Snapshot capacities are explicit caller choices, not universal
production defaults. Native ordinary dirty extraction likewise checks capacity
before clearing dirty metadata.

## Does a small dirty patch mean a small GPU upload?

No. **Current:** [main `apply_render_patches_to_image`](../../godot/scripts/main.gd)
validates dimensions, channel count, offsets and exact byte sizes for the full
packet before constructing/blitting patches. It updates a persistent CPU Image.
`upload_texture_patches` then calls `ImageTexture.update` on the **full** backing
image. A 1024×1024 RG8 upload is 2,097,152 bytes regardless of a tiny edit.

Desktop acknowledges a render serial only after successful consumption.
Malformed/empty/stale or unacceptable full-refresh data is rejected and requests
resynchronization. The worker retains unacknowledged changes and substitutes an
explicit full refresh when accumulation exceeds its patch/byte thresholds.
The historical handoff race is guarded by
[test_render_patch_handoff_regression](../../godot/tests/test_render_patch_handoff_regression.gd).
Do not reuse pending buffers while a published generation remains observable.

**Current desktop reset identity:** the exclusive GDScript owner advances a
World generation only after an accepted World reset or scenario replacement.
It retains `render_world_generation` with the exact render publication, forcing
a complete replacement payload even when a new World reuses the old revision
or paused tick index. The main thread invalidates vapour history only after it
successfully uploads that generation. A newer physics/status snapshot carrying
an older render publication cannot advance the displayed reset identity.

`render_full_refresh` describes transport coverage, not World lifetime. Native
resynchronization and ordinary R8 fallback publications can be full images of
the same World; they preserve presentation history. Rejected reset requests do
not advance the World generation. The
[owner regression](../../godot/tests/test_render_world_generation.gd) checks
native and fallback paints, resyncs, accepted/rejected resets and repeated
identical paused scenario replacements; the
[actual-pixel pipeline regression](../../godot/tests/test_material_vapour_pipeline_render.gd)
checks the corresponding visible history behavior. Evidence is in the
[2026-10-19 review](../audits/2026-10-19-mat002-review-and-validation.md).

Temporal smoothing ping-pongs presentation textures. Palette/program LUTs,
Water dither, liquid motion, material flair, relief and glow derive appearance
without changing cell state. `K` controls presentation smoothing; `H` controls
publication cadence. Neither is a strict simulation-accuracy switch.
[Appearance](../systems/material-appearance-and-rendering.md) owns shader details.

**Planned:** true GPU subregion submission, palette-change records, measured
compression/coalescing and tuned production snapshot defaults. Lower native
copy volume does not establish any of those features.

## Which gameplay command path exists today?

**Current desktop:** main-thread methods replace frame state and copied body
samples or enqueue generic disc emissions under a mutex. The pacing owner
latches/drains them before stepping. Paint is one wrapper around emission;
material IDs cross the boundary, not UI slot numbers. Reset and camera-window
changes are handled by that owner too. Emissions remain allowed while paused.

**Current Web:** the main-thread controller applies window changes and armed
painting synchronously before its pause guard; it does not use the desktop
command queue. Rapier exchanges packed samples/results, described by the
[coupling contract](rigid-body-and-cellular-coupling.md).

**Approved:** the production GameplayBridge should accept bounded data-only
commands at identified tick boundaries and publish immutable results. **Planned:**
its generalized schema, stable IDs, queue capacity, acceptance/rejection result,
target-tick semantics and retention policy. The existing dynamic emission array
has no production full-queue policy. Snapshot backpressure does not define
command backpressure.

## What must a bridge change verify?

Preserve immutable lifetime, complete-payload validation, dirty retention on
failure and the no-native-worker-Godot boundary. Test full/delta publication,
delayed consumption, malformed data, pressure recovery and command ordering
for the affected controller. Fixture source alone is not execution evidence;
use the [validation ledger](../reference/validation-evidence.md).
[ADR-003](../decisions/ADR-003-godot-bridge-and-immutable-snapshots.md) records
why mutable reads and renderer locks are Rejected.

## Publication after a failed tick

**Current:** `RenderSnapshotExchange::publish` throws for a failed World before
touching slots or dirty state. Existing leases remain immutable. Godot
`take_render_snapshot` returns `{failed: true, error: ...}` without payload;
controllers retain their previous valid display and withhold partial terrain/body
results. This is distinct from snapshot Backpressure/CapacityExceeded, which do
not fail the World. Recovery is defined by the [tick contract](simulation-tick-and-threading.md).
