---
title: Rendering and gameplay bridges
document-kind: contract
canonical-for: [render-publication-and-gameplay-bridge-behavior]
status: Current
scope: Native publication outcomes, Godot render consumption and current gameplay commands; resource lifetime and wire layouts are linked
keywords: [RenderBridge, GameplayBridge, RG8, immutable snapshot, full texture upload, backpressure, emission queue]
related-documents: [data-ownership-and-lifetimes.md, rigid-body-and-cellular-coupling.md, ../reference/interfaces-and-message-contracts.md, ../systems/material-appearance-and-rendering.md]
last-reviewed: 2026-11-16
---

# Rendering and gameplay bridges

## Coherent Workbench presentation frame

**Current unmerged candidate; physical acceptance FAIL/HOLD.** The owner rejected
the delivered `43f46c6e5ec9` application because of repeated physical/actor
freezes. Its pose-selection checks did not qualify physics cadence. Main resolves one
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
step. Session/epoch/World replacement resets the timeline; temporary stale
receipts do not erase an advanced selection. Picking uses the displayed actor.

Held-pose certificates identify actual texture contents, rather than upload
serials or ping-pong GPU resource IDs. Each upload compares exact immutable bytes
and image dimensions/format against at most the two retained texture contents.
New content receives a monotonic identity; creating textures never recycles an
old identity. A selected pose can retain its certificate only when every content
currently visible in the shader was already checked for that exact pose. This
allows a hold across a byte-identical refresh or the end of a crossfade, without
another scan. Changed content, an uncertified old texture or unknown active
previous-texture history still requires a successful check. The existing actor,
session, epoch and World fences remain separate and mandatory. Byte-comparison
cost is charged to the same presentation allowance; the allowance was not raised.

A validated, single, tightly packed full-World material patch replaces the CPU
image data directly after preserving the actual previous image. It avoids an
extra full payload slice, temporary patch image and whole-image blit. Validation,
GPU upload/swap and revision/ACK behavior are unchanged. Partial, padded,
offset and multi-patch payloads retain the ordinary patch path. Both R8 material
IDs and RG8 material/effect bytes remain exact and independently owned.

Near contact, a coarse sampled sweep can reject clear motion because its
continuous-coverage dilation reaches nearby terrain. The coherent policy may
refine that material veto once to 32 intervals, retaining the same rigorous
coverage bound and both visible textures. Both passes charge the same frame
cell allowance and original deadline; time, capacity, identity and unknown
previous-texture refusals never become permission to draw. Successful refinement
is recorded as `refined_swept_mask`. The original comparison retains coarse
sampling, so its conservative false refusals remain observable.

This is a monotonic presentation timeline, not physics interpolation or a visual
offset. It preserves native material and Rapier authority. Unknown sample time
stays unknown; a bounded sample-serial journal supplies provenance without
equating native ticks to physical steps. `CYBERSAND_DIAG_PRESENTATION=legacy`
retains the original independently followed guarded display for comparison.
The [Windows acceptance guide](../operations/camera-stack-coherence-acceptance.md)
and [trace runbook](../operations/engine-lab-pose-tracing.md) distinguish automated
contract checks from physical NVIDIA acceptance.

## Workbench physics progress and terrain installation

**PHYSICS-FREEZE-REMEDIATION-002 candidate:** the exclusive worker publishes a
bounded immutable physical completion after post-tick edits and required hard
geometry are ready, before render extraction and patch packing. Main's physics
callback consumes this separate slot. Both physical and graphical snapshots from
one owner turn share a single reserved serial; independent physical generation
and handoff fields never impersonate uploaded material identity. Failure
quarantines both slots and owner retirement clears the physical slot without
falling back to older graphical state. An older graphical terrain packet cannot
replace newer installed geometry. `CYBERSAND_DIAG_PHYSICS_PUBLICATION=combined`
retains the previous completion dependency for controlled comparison.

This overlaps graphical publication with the next eligible physical callback.
The native owner still completes graphical packing before its next tick; its
ordinary sample wake remains the existing bounded polling behavior. No thread
pool, native law, callback timestep, or feedback-age policy changes. All live
Rapier objects stay main-thread owned. Publication cost and main-thread renderer
waits can still limit callbacks. The
[remediation evidence](../audits/2026-11-16-physics-freeze-remediation-002.md)
separates proven overlap from end-to-end performance and physical acceptance.

**Current corrective candidate:** `Main._workbench_terrain_installed` services
pending terrain on each actual physics callback. The old once-per-render-frame
restriction made available physics callbacks idle during a slow render interval.
The existing 128 changed-chunk and 4,000 microsecond cooperative allowance still
applies to each call. A chunk operation can exceed that deadline; this is not a
hard maximum. Rapier does not step until the complete required native hard-surface
revision has been installed.

`CyberRapierPhysicsBridge._replace_hard_surface_chunk_shapes` preserves attached
shape RIDs for exact unchanged rectangles, including duplicate rectangles. It
removes only obsolete shapes and adds only new geometry. Packet order and actual
PhysicsServer body-shape index order are tracked separately, so removal cannot
mistake a retained rectangle for a changed one. Repeated identical owned packets
neither restart pending installation nor rebuild completed geometry. Caller
mutation cannot change the copied accepted packet or its equality certificate.

The normal native-sample handshake, fixed 1/60 physical step, one-step wrench-age
limit and geometry/owner/epoch checks remain unchanged. This removes unnecessary
collider work and a rendering-dependent wait; it does not make a native World
whose ticks exceed 16.7 ms sustain 60 coupled physical steps per second. The
uncoupled Engine Lab diagnostic remains an experiment, not a contact-qualified
default replacement. No new interpolation or pose extrapolation hides these waits.

The opt-in trace separates selected-pose holds from actual `rapier_hold` events
and consecutive physical completion gaps. Hold events identify the exact required,
packet and queued terrain revisions, pending chunks and native sample. Completed
steps also expose existing Rapier solver/flush timers. These are wall-clock CPU
call observations, potentially including OS descheduling, not GPU scanout.
See the [freeze investigation](../audits/2026-11-15-workbench-physics-freezes.md)
for the failed candidate, controlled regressions and remaining performance limits.

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
scanout. Workbench's normal Rapier/native sample handshake and one-step stale
response fence remain; independent callback controls do not by themselves
establish independent physical clocks. Use the [runbook](../operations/engine-lab-pose-tracing.md)
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

**Current unmerged remediation candidate:** [main `apply_render_patches_to_image`](../../godot/scripts/main.gd)
validates dimensions, channel count, offsets and exact byte sizes for the full
packet before constructing/blitting patches. It updates a persistent CPU Image.
On qualified desktop OpenGL/ANGLE backends, two linear RGBA8 drawable textures
retain the exact logical R8/RG8 current and previous material values. All six
appearance shaders retain ordinary 2D sampling. Changed tiles are packed into
one layer of a bounded R8/RG8 staging array; that layer is uploaded once before
GPU rectangle copies update the recycled history plane. A dense
publication uses one full staging upload and one whole-plane GPU copy. This
avoids CPU texture updates to the material planes sampled by the preceding draw.

At 2048²,128² tiles bound the dirty index to 256 entries. The recycled slot repairs
all accumulated changes from its retained contents; exact unchanged tile bytes
skip submission. One changed tile submits32 KiB of RG8 staging data instead of an
8 MiB World image. GPU copies also read staging pixels and write RGBA8 targets:
CPU upload bytes are not total GPU traffic. Each staging size class owns one
fixed Texture2DArray with two layers and rotates only after upload, copies and
retirement are submitted. A diagnostic one-layer control remains available through
`CYBERSAND_DIAG_MATERIAL_STAGING_SLOTS=1`; the experimental default is two.
The exact-size full source aliases the same pool/cursor; non-square or NPOT
sources retain a separate bounded full pool. Rejected and byte-identical
publications do not advance a cursor. This increases reuse distance without
asserting that GPU work has completed. The two histories, staging size
classes, 1×1 retirement target and separate 1-byte source dummy occupy
55,902,213 logical GPU texture bytes at
2048² RG8, excluding driver overhead. A final tiny blit prevents the engine's
persistent framebuffer attachment from retaining a released large history plane.

Only the copy shader samples an array. Its sampler is fixed once per pool;
ordinary World appearance still samples the original 2D history interface.
The Godot 4.7 GLES3 implementation updates an array layer with
`glTexSubImage3D`, while its ordinary `ImageTexture.update` path calls
`glTexImage2D`. The change avoids redefining staging storage on every upload;
it does not establish a nonblocking driver call. The separate ordinary source
dummy satisfies the blit API's source0 binding without binding an array as a
2D texture. Resource/layer identity and exact byte readback are qualification
requirements. The source implementation and rejected alternatives are linked
in the remediation audit below.

`CYBERSAND_MATERIAL_PUBLICATION=auto|full|blit` and Engine Lab select the path.
Unsupported platforms/backends/capacities and detectable resource validation
failures retain the whole-ImageTexture fallback; switching modes reconstructs
both exact retained histories. Godot's drawable-blit API returns no error result,
so latent device loss is not claimed to be synchronously detectable. The
fallback's `ImageTexture.update` still updates the full plane regardless of
patch area (8 MiB at 2048² RG8). Neither CPU patch size nor elapsed call timing
alone establishes measured GPU bandwidth or a driver-wait cause. The superseded
full-World array-sampling design and its negative performance evidence remain in the
[remediation audit](../audits/2026-11-16-physics-freeze-remediation-002.md).

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

**Planned:** finer subregion submission within a tile, palette-change records,
measured compression/coalescing and tuned production snapshot defaults. The
bounded layer implementation does not establish these separate features.

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
