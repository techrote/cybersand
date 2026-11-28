---
title: Native import and layered construction in Strata Theatre
status: Current
document-kind: contract
scope: Optional Strata source contracts for local artwork, exact native modules, finite construction, preview approval and historical provenance
canonical-for: [strata-native-import, strata-native-parts, strata-construction-plan, strata-authoring-provenance]
last-reviewed: 2026-11-28
related-documents: [strata-workbench.md, strata-environments.md, ../operations/strata-workbench-evaluation.md, ../architecture/shared-workbench-authoring-data.md]
---

# Native import and layered construction in Strata Theatre

The complete STRATA-THEATRE-002 authoring functionality is retained in the
owner-accepted Strata 003 integration. The 28 November 2026 decision authorizes
adoption with RAMCACHE; the [combined delivery guide](../operations/ramcache-strata-integration.md)
records qualification of the resulting application. The original #769 and #776
receipts remain source-bound predecessor evidence. The ordinary
Workbench remains the sole Play, actor, Rapier, camera and simulation-worker
owner. The [foundation contract](strata-workbench.md) owns those boundaries and
the versioned save envelope. The [environment contract](strata-environments.md)
owns the shipped native examples and presentation-only effect library.

## One ordinary workflow

The existing Strata Theatre window contains **Layers**, **Import**, **Compose**,
**Atmosphere** and **Scenes**. Opening it creates no decorative World. Enabling
Strata or explicitly loading a composition prepares the existing three static
decorative owners. The new authoring mediator is created lazily and owns copied
observations and finite jobs, never a Play World or a second worker-result slot.

`workbench_strata_authoring_panel.gd` sends source inspection, preview, approval,
Stop and export requests through `workbench_strata_controller.gd` to
`workbench_strata_authoring.gd`. The last adapter supplies the typed host
interface consumed by `strata_construction_session.gd`:

| Operation | Actual authority and receipt |
|---|---|
| Plane state | Scene, owner, generation, material revision, observed authored serial, permissions, extent, existing history and capacity |
| Native observation | At most 4096 copied material IDs per capture; exact region and source fences |
| Decorative application | Existing layer owner and paint executor, with before-value preconditions and original native prefix receipt |
| Play application | Existing ordinary paint editor queue, its history recorder and its original worker ACK; a tokenized completion signal returns the copied result |
| Display flush | One changed decorative publication per completed stage; Play reads the existing host upload witness |
| Historical record | Strict bounded authored metadata, appended only after the terminal stage outcome is known |

The material revision and the authored serial are different facts. An ordinary
or legacy no-op material write can append a saved stamp without changing native
materials. The adapter compares the entire current copied Play Setup with its
previous copy and advances an observation serial when its value changes. A
ready approval is invalidated by that change. The native ACK's original material
revision remains intact; it is never replaced with a convenient later revision.

## Raster artwork is a proposal

`strata_import_codec.gd` accepts a local PNG, including alpha, and an optional
same-resolution PNG mask. Source inspection reports its dimensions and digest
and displays the actual decoded source. Conversion never alters the source
file. The owner chooses a plane, crop, origin, exact orthogonal transform,
integer scale, alpha threshold, palette and unknown-colour policy before
requesting a native preview.

The conversion order is crop, exact orthogonal transform, then nearest-neighbour
integer replication. A scale of two proposes four native cells per selected
source pixel. The exact resulting extent is bounded and shown before mutation.
Native material-ID imports are never resampled through this raster path.

| Pixel policy | Proposed native operation |
|---|---|
| Alpha zero or below the selected threshold, Overlay | No write; the existing destination cell remains unchanged |
| Alpha zero or below threshold, explicit Replace | An actual Empty-cell write, subject to the same target/protection checks |
| Mask-excluded pixel | No write under either alpha mode |
| Included opaque pixel within the selected colour distance | Palette row's admitted native material ID |
| No matching colour | Refuse the complete proposal, or explicitly Skip and report the count |

A mask includes a pixel only when alpha is nonzero and the RGB-byte sum is at
least 384. Palette distance is Euclidean distance in RGB bytes; equal-distance
ties choose the earlier palette row. The owner can specify at most 32 palette
colours and a distance from zero through 442. Roles are descriptive authored
metadata, not inferred collision, attachment, load capacity or depth authority.
Partly transparent pixels follow the selected threshold of 1–255; they do not
create a fractional native material or an automatic physical effect.

Preview retains mapped, unmapped, alpha-skipped, mask-skipped, no-write and
explicit-Empty counts. It binds source and mask SHA-256, source resolution,
selected crop, transform, sampling, palette, policy and proposed native geometry.
The original bytes are rechecked before conversion to refuse a changed source.
The first 32 unknown RGB values are reported for review; a skipped colour is
never silently counted as successful native placement.

The shipped synthetic alpha fixture has a central opening and deterministic
partial-alpha controls. Its strict sample policy succeeds with 1,315 mapped
cells and 1,757 no-write cells; the magenta control pixels are transparent or
below threshold. Separate adverse tests exercise unknown opaque colours and
explicit **Skip and report** behavior. The two source-pinned SANDMAPS examples
are originally opaque RGB artwork. Their separately authored masks express proposed regions. Dark artwork
is not claimed to be transparent or to encode authoritative rear planes.

## Exact native parts and explicit plane targets

`strata_native_module.gd` validates `cybersand-strata-module-v1`. It stores exact
uint16 little-endian material IDs separately from a write mask, with extent,
anchor, material roles, permitted transforms, protected regions, clearances and
source provenance. A zero mask bit defaults to transparent/no-write; explicit
native Replace/clear can request Empty at those cells. A one mask bit with
material zero already means an explicit Empty write. This native write-mask
contract is distinct from raster PNG selection masks, whose excluded pixels
always remain no-write. Modules may be mirrored or rotated by supported right angles without
interpolation of material IDs.

The compatible `cybersand-native-module-v1` reader is a read-only contract pinned
to #770 application `fe2395c7060dae736dc2e5dc8d1e4e050b2d2e52`. No moving
architecture branch or Gentek solver is installed. Unsupported required
attachments are refused. Optional descriptions are retained as metadata without
claiming an implemented structural solver.

**Compose** offers eight shipped native parts and three layered presets. A part
can repeat 1–16 times with an explicit integer step. **Harvest** copies an actual
visible, unlocked plane region, preserving exact IDs and mapping Empty to a
no-write mask by default. It creates no native writes. The harvested part is
available in that session; **Export selected part** writes its strict JSON and
provenance through the existing native atomic replacement service. Reimport that
file in a future session. Saving a composition retains placed geometry and its
historical source records; it does not silently turn an in-memory part catalogue
into a persistent external module library.

## Finite native construction and explicit approval

`strata_construction_plan.gd` validates a finite `cybersand-strata-plan-v1`.
Each stage names the scene, plane, exact region, expected revision, dependencies,
permitted materials, protected regions and placements. A layered composition
uses one shared anchor with explicit plane-local offsets. Previously projected
stages on the same plane become the next stage's preview context; actual target
material observations supply its initial state.

The session first captures actual native materials, checks clearances and
protection, projects each stage, and verifies native authored-layout and retained
provenance capacity. This phase writes no material cells. The window offers each
stage's copied Before and proposed After image in **Compose**, plus a composited
native-ID proposal. **Import** instead presents Source, Mask and Proposed layout
views, counts and the exact reviewed single-stage plane/region summary. A stale
top-level conversion alias cannot override the stage's admitted region. That
small Compose composite uses current copied material context, a fixed
plane order and captured visibility/opacity. It labels any sampling stride and
does not claim to be production shader, parallax, haze, glow or atmosphere output.
Those appearances are inspected in the actual Workbench after approval.

Only the current opaque review token can approve a prepared plan. A new preview
attempt, even one that fails, retires the previous approval. Approval rechecks
owner, scene, generation, material revision, authored serial and permissions.
Each native chunk then rechecks the same fences and exact before values. Counts
advance only from a matching actual native ACK. The stage's full native region
is read back afterward, including protected and no-write cells, and must match
the acknowledged result. A stage must request at least one explicit native write.
Requested writes whose materials are already equal still use the ordinary owner
acknowledgement and history path; changed-cell count is a distinct measure.
A dependency is complete only after that stage's verified original
acknowledgements, full native readback and publication; hiding it never completes it.

There is no cross-plane transaction or group rollback. Stop abandons the
unapplied suffix, waits for any already admitted chunk to acknowledge, and
retains the real prefix. Turning layered presentation off cannot strand a busy
job: its driver continues until a terminal refusal or prefix report. If the new
permissions prevent final readback, that limitation is explicit while the
acknowledged writes remain committed. Malformed mutation receipts produce an
unverified native outcome rather than an invented zero-write success.

## History, visual settings and retained provenance

Each acknowledged chunk uses the target's existing native history operation.
Decorative history retains 32 entries per plane. The preview reports proposed
entries and displaced history before approval. A large placement can outlive
that window; Undo then retains its newest chunks only. Play keeps ordinary
history and simulation invalidation. No operation promises to reverse evolved
physical continuation, and Flatten continues to affect the Play material
baseline alone.

Layered presets also propose opacity, relative depth, parallax, haze and
anchor-adjusted atmosphere settings. **Apply reviewed depth and atmosphere** is
a separate approval after every native stage completes. It replaces the current
atmosphere configuration as stated in the UI. The token is bound to the original
visual settings and scene; current permissions and completed native revisions
are checked again. The complete settings candidate is validated before adoption.
This changes no native layout, owner, revision or history. A later display
failure cannot turn a committed settings or material operation into an
uncommitted one.

`strata_authoring_provenance.gd` retains up to 64 strict terminal records and
256 KiB total. Each stage reserves its complete maximum terminal record before
writing; there is no silent oldest-record eviction. The record distinguishes
completed, partial, cancelled, refused, failed and committed-with-stale-pixels
outcomes, along with actual hashes, prefix counts and publication status.
Historical owner IDs identify the operation's original source. Reopening a
save never reuses them as a live approval, resumes a queue or asserts that the
new owner is the old physical continuation. Native layouts and source metadata/
digests persist; supplied original PNG bytes are not embedded in a scene save.
Keep those originals separately for future remapping.

## Explicit resource and integration limits

| Resource | Admitted bound |
|---|---|
| PNG input | 16 MiB; each source axis at most 2048 pixels |
| Raster crop and scale | Each crop axis at most 512; integer scale 1–4; at most 262144 output cells |
| Conversion work unit | At most 4096 source pixels |
| Native module | At most 262144 cells and 2 MiB strict JSON |
| Finite plan | At most 16 stages, 262144 requested writes, 1048576 inspected cells and 8 MiB typed data |
| Native chunk | At most 4096 cells; the inherited decorative operation cap remains 16384 |
| Historical metadata | At most 8 KiB per stage metadata, 64 records, 256 KiB total |

Equal-resolution native planes remain the conservative document contract. No
native ID scaling, independent-resolution continuation or area streaming is
introduced. Model-assisted Art remains Play-only under #773's own permissions
and lifecycle. Future Art or architecture callers may submit explicit offline
plans through this same selected-plane, zero-write-preview and owner-approval
interface; this mission does not broaden provider permissions or qualify a
provider integration. No paid inference is needed for any shipped workflow.
