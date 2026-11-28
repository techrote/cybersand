---
title: Rendering and gameplay bridges
document-kind: contract
canonical-for: [render-publication-and-gameplay-bridge-behavior]
status: Current
scope: Native publication outcomes, Godot render consumption and current gameplay commands; resource lifetime and wire layouts are linked
keywords: [RenderBridge, GameplayBridge, RG8, immutable snapshot, full texture upload, backpressure, emission queue]
related-documents: [data-ownership-and-lifetimes.md, rigid-body-and-cellular-coupling.md, ../reference/interfaces-and-message-contracts.md, ../systems/material-appearance-and-rendering.md]
last-reviewed: 2026-11-24
---

# Rendering and gameplay bridges

The opt-in [Strata Workbench adapter](../systems/strata-workbench.md) borrows the
ordinary play drawable/textures and camera while admitting copied decorative
publications into three private static surfaces. It adds no play publication,
ACK, scheduling or physical ownership path. The default renderer remains this
page's existing path; source-bound integration qualification is separate.

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

The [Completion candidate](../operations/pubpres-completion-001.md) also fences
material blending by the accepted World generation. A same-size replacement may
retain the old physical texture in the dual-history pair, but neither requested
nor measured timing may give it visual weight without a qualified same-World
predecessor. This does not change the accepted revision sequence, upload ACK or
history bytes. The focused production-intake regression is
[`test_workbench_material_world_blend.gd`](../../godot/tests/test_workbench_material_world_blend.gd).

The [desktop evaluation candidate](../operations/pubpres-integration-evaluation.md) adds opt-in tile staging and persistent drawable history. Large transitions that first copy the accepted history use dedicated bounded staging rings. The ordinary full-only path continues to submit the complete backing image.

**PUBPRES candidate:** `auto` and `blit` use the existing checked sparse
publisher on supported graphical backends, including Windows software ANGLE.
Explicit `full` retains the complete R8/RG8 ImageTexture pair, and structural
or capacity refusal still selects the verified full fallback. Engine Lab shows
requested and active modes. The temporary automatic WARP full-upload override
is Rejected: its detached transition benefit did not hold across matched actual
Wave and FreeMass gameplay. No replacement adapter or workload heuristic is
introduced. Retained compact re-entry, fresh whole storage and fresh sparse
staging comparisons are also negative; lower upload-call duration alone did not
remove the later stalls. See
[`supported_driver`](../../godot/scripts/blit_material_publisher.gd),
[`_create_material_texture_pair`](../../godot/scripts/main.gd), and the linked
evaluation for exact source/platform evidence and remaining acceptance gates.

**PUBPRES-PLAYABILITY-FINAL experiment, default off:** with explicit Full
publication and `CYBERSAND_DIAG_FULL_IMAGE_SLOTS=3`,
[`CyberFullImageRingPublisher`](../../godot/scripts/full_image_ring_publisher.gd)
owns exactly three persistent R8/RG8 ImageTextures. Main updates the spare that
was absent from its preceding current/previous pair, then rotates the exact
current and previous histories. A queued upload owns an immutable Image copy.
The selector does not change native ticks, physics admission, ACKs, material
timing, camera or World-generation blending. Missing or other selector values
retain the ordinary two-slot Full path; Blit remains separately selected.
Structural refusal rebuilds the exact two CPU histories before ACK.

The additional declared logical storage is one full plane (8 MiB for 2048-square
RG8). Three slots provide reuse distance, not a GPU fence or bounded driver wait.
Source identity, slot count, stable resource IDs, logical byte count and upload
destination are exposed in `material_publication_status()`. The distinct
[ring transition oracle](../../godot/tests/pubpres_full_image_ring_oracle.gd)
retains the 180-admission tape and first current/previous GPU read comparisons;
the original two-slot oracle stays unchanged. The
[queued publication fixture](../../godot/tests/test_full_image_ring_publication.gd)
also wraps and poisons caller Images, tests R8/RG8 and NPOT sizes, and rejects
foreign owners and invalid shape/format. These are correctness requirements;
the experiment remains Draft/HOLD until matched actual Rapier and ordinary
Workbench evidence establishes its end-to-end effect.

**PUBPRES-PLAYABILITY-FINAL presentation deadline, default off:**
[`MaterialPublicationDeadline`](../../godot/scripts/material_publication_deadline.gd)
lets Main retain one immutable, cumulative worker publication before any CPU
image mutation. The explicit 30/60 Hz diagnostic selector has its exact values
in the [configuration reference](../reference/configuration-reference.md#workbench-material-deadline-experiment).
Newer eligible packets replace the offer without postponing its first deadline.
Every ordinary process turn attempts to drain it, including a paused World with
no newer mailbox. This controls material consumption only; native sample and
Rapier admission remain independently authoritative.

Consumption calls the existing complete upload, history and acknowledgement
path. If uploaded material serials jump from 20 to 24, the histories are 20 and
24; deferred serials receive no ACK or pose authority. A pending offer is bound
to the live actor session, epoch and authoritative World generation. Owner
replacement, failure, texture recreation or rejected material cancels it. A new
World requires its complete frame and bypasses the prior deadline; transition
transactions retain their existing immediate path. Structural refusal requests
the existing full-refresh recovery. This experiment is source implemented,
but graphical correctness and comparative playability remain unqualified in the
[implementation checkpoint](../audits/2026-11-24-pubpres-playability-final/material-deadline-implementation.md).

**Separate completed-step experiment, default off:**
[`MaterialPublicationSteps`](../../godot/scripts/material_publication_steps.gd)
can hold one cumulative Full2 packet until two genuine completed session/Rapier
steps beyond the last accepted upload, or the first-offer scheduled hold
deadline. It is mutually exclusive with the time policy. Paused/ownerless
operation, new Worlds and admitted painting preserve immediate publication.
Exact owner/bridge identity and paired counter deltas gate the count; only the
unchanged accepted transaction grants an ACK. The 16,667us scheduled deadline
does not bound actual visible age during a Main stall. The
[configuration](../reference/configuration-reference.md#workbench-completed-step-material-experiment)
and [implementation/qualification record](../audits/2026-11-24-pubpres-playability-final/completion-count-architecture.md)
separate source correctness from still-unqualified graphical and physical gains.

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

### PUBPRES explicit Water composition clearance

**Current candidate, default OFF:** the closure keeps actual completed
native/physical pose authority separate from uploaded current/previous material
identity. With that authority, Main asks the Water-compatible swept-footprint
guard directly, avoiding an empty-only scan and refinement that necessarily
reject the same Water before composition can run. Unknown authority retains the
ordinary clearance path. Initial or actually withheld parts may use explicit
endpoint reentry; consecutive visible parts retain continuous swept clearance.

The guard may prove that its entire bounded swept AABB contains only material
IDs Empty(0)/Water(3) in both active uploaded images. Bounded Image copies and
R8 conversion/counting perform this stronger proof; RG8's second state byte
cannot impersonate a material. Hard or other material falls back to the existing
continuous geometry proof. The same shared 24,000-cell/2 ms budget, 12,000-cell
fine-pass cap, world/rigidity checks and post-copy deadline remain. A complete
Empty result keeps its ordinary certificate and draw layer. A Water result still
requires the actual native/physical dependency and Water-only shader clipping.
No solver, completion, actor ownership or production default changes.

The [closure evidence](../audits/2026-11-26-pubpres-closure/README.md) retains the
original 151-assertion replay with 214 omitted body-frames as a moving-visibility
HOLD; component assertions alone did not close this defect. Resulting-source
graphical, resource, progression and owner hardware gates remain separate.

## Which gameplay command path exists today?

**Current desktop:** main-thread methods replace frame state and copied body
samples or enqueue generic disc emissions under a mutex. The pacing owner
latches/drains them before stepping. Paint is one wrapper around emission;
material IDs cross the boundary, not UI slot numbers. Reset and camera-window
changes are handled by that owner too. Emissions remain allowed while paused.

**PUBPRES candidate scheduling:** after a long owner turn, an overdue timer
cannot authorize another native tick for a body sample that already completed.
Only in that unpaused sample-fenced case, the existing owner rebases its idle
deadline and polls for the next real sample or admitted work. Stop, reset,
pause/settings changes, queued commands and render ACK/resync interrupt the
same wait. No-body simulation and paused authoring keep their original timer
cadence. Native health checks and the physical sample/terrain admission gates
remain in the ordinary owner turn; no completion or simulation time is invented.
Source: [`_worker_loop` and `_workbench_owner_work_pending`](../../godot/scripts/simulation_worker.gd).

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
