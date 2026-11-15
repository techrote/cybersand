---
title: Rendering and gameplay bridges
document-kind: contract
canonical-for: [render-publication-and-gameplay-bridge-behavior]
status: Current
scope: Native publication outcomes, Godot render consumption and current gameplay commands; resource lifetime and wire layouts are linked
keywords: [RenderBridge, GameplayBridge, RG8, immutable snapshot, full texture upload, backpressure, emission queue]
related-documents: [data-ownership-and-lifetimes.md, rigid-body-and-cellular-coupling.md, ../reference/interfaces-and-message-contracts.md, ../systems/material-appearance-and-rendering.md]
last-reviewed: 2026-11-15
---

# Rendering and gameplay bridges

## Coherent Workbench presentation frame

**Current unmerged candidate; owner acceptance pending.** Main resolves one
`workbench_presentation_frame` before camera Follow. It binds the uploaded
material generation/revision/serial and current/previous texture identities to
selected actor poses, actual sampled Rapier steps, explicit holds/withholds,
the selected Follow target, frozen blend and final pixel camera mapping.
The terrain shader and physical overlay consume that same submission mapping;
snapping never writes back into the continuous requested camera origin.

Each actor advances from its last selected pose only after conservative swept
clearance against both genuinely visible material textures. Rejection retains
a previously certified stationary pose only while its certificate remains valid
or after revalidation; otherwise the actor is withheld. The strict render receipt
excludes withheld actors, preventing implicit fallback to an older material-bound
pose. A newer native receipt may rejoin only with a later actual sampled Rapier
step and a clear sweep from the previous visible pose. Its safe endpoint alone
cannot authorize a forward source-switch jump across material. Session/epoch/
World replacement resets the timeline; temporary stale receipts do not erase
an advanced selection. Picking uses the displayed actor.

**PRESENTATION-TIME-001 continuation:** a separate value-only history retains at
most 128 physical observations for each of the eight admitted actors. Each
observation identifies the physical step, transform, linear/angular velocity,
completed-step timestamp when known, observation time and native sample serial.
The existing 2048-entry serial-to-step join remains separate from the bridge's
two-record wrench authority fence. On a material or motion-capacity refusal,
at most three chronological observed candidates can be swept from the last
selected pose. These queries spend the original shared cell allowance and
cooperative deadline. There is no expanding pose search or unchecked lerp.

After a visible selection has lagged, recovery replays actual retained physical
observations. Each graphical frame can advance by the number of newly completed
physical steps since the previous graphical frame, plus at most one additional
retained step to catch up. This bounds recovery speed using the observed clocks,
without imposing latency on ordinary live motion. Recovery observations older
than 100 ms are withheld instead of stretching visual delay indefinitely.

A continuously refused pose may remain visible only while its material
certificate is valid and for at most 100 ms. Thereafter the actor is explicitly
withheld; Follow retains the last selected target. A current live or later native endpoint can
re-enter after a withheld submission only after footprint clearance and a
nondecreasing known physical step. A missing or expired native receipt cannot
trap a safe stopped actor indefinitely; explicit live re-entry still checks
both visible material textures. Such reacquisition is explicitly labelled,
not reported as continuous motion. No generic smoothing or fixed display delay
is imposed on clear live motion. Hold age, sampled-pose age, recovery attempts
and suppressed reacquisition remain measurable in the frame trace.

Near contact, a coarse sampled sweep can reject clear motion because its
continuous-coverage dilation reaches nearby terrain. The coherent policy may
refine that material veto once to 32 intervals, retaining the same rigorous
coverage bound and both visible textures. Both passes charge the same frame
cell allowance and original deadline; time, capacity, identity and unknown
previous-texture refusals never become permission to draw. Successful refinement
is recorded as `refined_swept_mask`. The original comparison retains coarse
sampling, so its conservative false refusals remain observable.

The selected timeline is monotonic; no presentation observation owns physics. It preserves native material and Rapier authority. Unknown sample time
stays unknown; a bounded sample-serial journal supplies provenance without
equating native ticks to physical steps. `CYBERSAND_DIAG_PRESENTATION=legacy`
retains the original independently followed guarded display for comparison.
Material blending is also part of that frozen frame. The two accepted upload
records retain generation, revision, serial, native tick/completion, generation
time and CPU upload time. The duration uses the smaller positive interval of
actual publication and upload delivery, clamped to 1–100 ms. Missing producer
time falls back to measured upload intervals. A first upload or new World has
no previous state to blend. Changing requested render Hz does not alter an
in-progress measured fade. At 2 Hz the cap deliberately leaves discrete terrain
updates; it does not invent intermediate native states. The guard checks both
textures for exactly the same active-blend interval used by the shader.
`CYBERSAND_DIAG_MATERIAL_TIMING=legacy` independently restores the old requested-
Hz fade; the original-presentation launcher selects both diagnostic policies.

The [Windows acceptance guide](../operations/camera-stack-coherence-acceptance.md)
and [trace runbook](../operations/engine-lab-pose-tracing.md) distinguish automated
contract checks from physical NVIDIA acceptance.

## Experimental cadence continuation of #609

The [RENDER-CADENCE-001 branch](../audits/2026-11-15-render-cadence-001.md)
retains an exact CPU copy of the preceding Workbench GPU material image for
bounded local swept clearance. It replaces a global unknown-history response
to large patches; it does not interpolate native motion. Delayed upload ACKs
use fixed frame deadlines. The optional diagnostic publication gate is off by
default, holds only material extraction, and permits resync/World replacement
without acknowledging an invalid upload. Native simulation authority and
ordinary publication policy remain unchanged.

Actual completion events distinguish native steps, immutable snapshot handoff,
Main receipt, upload return, ACK and Godot post-draw. None measures hardware
scanout. The existing physical sample handshake remains the ordinary default in both
presentation policies. A development attempt to disable it globally exposed
scheduler-sensitive Scooper material loss in both old and new renderers; it was
rejected rather than treating a physics regression as a display repair.
**Uncouple Pixel + Rapier** in Engine Lab independently disables sample waiting
and early native sample wake; the corrected coordinator is qualified at 2 Hz
native and 120 Hz Rapier through those existing controls, without adding any
coupling or slowing physics to pass presentation tests.

Installed-terrain, failed-World, epoch, duplicate-result and one-step/0.5-cell
stale-response fences remain authoritative. A slow native worker can reject
late impulses; the presentation coordinator never makes them fresh. Native
coupling still consumes each unique body sample once. Asynchronous material
custody is a separate physical limitation, not solved by this display timeline.
Use the [runbook](../operations/engine-lab-pose-tracing.md)
for clock semantics and exact-source acceptance boundaries.

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

## How are RG8 regions copied?

**Current candidate:** `World::copy_render_cells` resolves one chunk per
contiguous row run and projects each stored material/state pair through the
unchanged `project_visual_state`. Absent chunks remain Empty. Signed regions,
stride padding and inclusive `INT64_MAX` endpoints retain their defined
semantics; an unrepresentable final coordinate is refused before any write.
The World remains unbounded and sparse: native extraction introduces no clipping.
The finite desktop full snapshot explicitly selects the 1024-square window;
Main rejects patches crossing its image bounds. The handoff regression accepts
the final RG8 pixel and verifies that refused edge crossings leave the image
unchanged.

The production function comes from corrected #290/#301. A test-only literal
per-cell oracle checks bytes, persistence, dirty metadata and subsequent
simulation; ordinary runtime has no alternative copy mode. The
[current-main qualification](../audits/2026-11-01-render-copy-production-reconciliation.md)
separates historical evidence from new source-matched execution. This copy
change leaves retention, overflow, publication and ACK policy unchanged.

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
