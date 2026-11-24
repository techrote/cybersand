---
title: Evaluate Strata Theatre in the ordinary Workbench
status: Current
document-kind: guide
scope: Draft STRATA-THEATRE-002 owner workflow, native import and construction, atmosphere, authored Save and platform acceptance
canonical-for: [strata-workbench-owner-evaluation]
last-reviewed: 2026-11-24
related-documents: [../systems/strata-workbench.md, ../systems/strata-authoring.md, ../systems/strata-environments.md, github-development-and-release.md]
---

# Evaluate Strata Theatre in the ordinary Workbench

**STRATA-THEATRE-002 — Draft/HOLD, PR #776.** This guide describes the successor
candidate's ordinary interactive workflow. The [decision packet](../audits/2026-11-24-strata-theatre-002/decision-packet.md)
records the exact qualified source, original platform receipts, package checksum
and remaining physical owner gate. Until that packet records a verified package,
a development checkpoint is not an owner-ready platform qualification.

The [ownership contract](../systems/strata-workbench.md),
[native authoring contract](../systems/strata-authoring.md) and
[environment catalogue](../systems/strata-environments.md) define implemented
scope. The immutable [#769 acceptance package](../audits/2026-11-24-strata-theatre-workbench/decision-packet.md)
remains historical predecessor evidence and does not qualify this successor.

## Launch and choose an environment

Extract the complete verified Windows evaluator into a writable directory and
run **Open Workbench.cmd**. It opens ordinary Workbench with Strata initially off;
Godot and source-matched native/Rapier dependencies are included. Keep all files
together. **Gallery.html** offers actual Windows Godot captures, isolated planes,
matched atmosphere comparisons, native-pixel details and original receipt links.
Those images document the packaged source; they are not concept-art substitutes.

1. Open **Strata Theatre…** from the ordinary toolbar, then **Scenes**.
2. Choose a complete environment and load it. Loading replaces the authored
   scene through the existing Workbench admission; save existing work first.
3. Wait for admission feedback. The old valid composition remains available
   while the replacement is prepared. Refusal is not a successful load.
4. Begin in Overview, then use the ordinary zoom and middle-mouse pan controls.
   Close or move the floating panel to inspect or paint; reopening it retains
   the current composition.

| Environment | Native extent | What to inspect |
|---|---:|---|
| Orbital Fabrication Terminal | 2048 × 1024 | Long open flight corridor, suspended gantries, rear megatrusses, distant dock arms and restrained signals |
| Rain over the Arcology | 2048 × 1024 | Uneven inhabited blocks, roof routes, central voids, distant towers and regional rain |
| Underworks / Reactor Service | 1024 × 1024 | Service bridges, pipes, pressure columns and machinery/vent motifs |
| Abyss Foundry | 1024 × 1024 | Irregular cavern boundaries, inset infrastructure, dark voids and localized mist |
| Vertical Transfer Spine | 1024 × 1536 | Repeated shaft architecture, transfer bays and bounded distant hoist motifs |

These are true straight-on side elevations made of editable native materials.
The four planes have different roles. Background silhouettes do not acquire
collision merely because they appear behind the player. A geometric route probe
is narrower evidence than an owner-tested flight course; inspect real movement.

## Inspect layers, edit and pilot

In **Layers**, compare **Stack** and **Flat active plane**. Select a plane, Solo
it, toggle visibility, lock it and adjust opacity/depth/parallax/haze. The ordinary
paint toolbar's **EDIT: PLAY / SCRIPTED / EFFECTS / BACKGROUND** identifies the
current target. Hidden, zero-opacity, locked or excluded planes refuse edits.
Play depth remains zero so actor and collision coordinates stay aligned.

Use ordinary Brush, Eraser, Line, Rectangle, Outline and Select/Copy/Paste on
static decoration; right mouse erases. The existing decorative gesture limit is
16,384 cells. Fill, actors and physical tools remain Play-only. Ctrl+C copies
native cells including Empty; Ctrl+V selects Paste. Ctrl+Z/Ctrl+Y and the panel's
Undo/Redo affect the selected plane. A visible locked plane can be copied by the
ordinary selection tool. Native import/harvest requires an editable target.

Select and pilot the ordinary actor using the usual Workbench controls. Toggle
Strata and atmosphere while moving, and observe whether identity, movement and
input persist. Play imports require Pause; decorative editing does not acquire
actor or Rapier ownership. **Reset presentation** restores visual settings
without resetting Play or native layouts; authored atmosphere settings are kept.
Closing the panel also preserves them.

## Import an alpha-bearing image or native part

The **Import** tab accepts a local PNG or supported native module JSON. The
shipped examples include a deliberately synthetic alpha-cutout fixture and two
source-pinned SANDMAPS reference crops with explicit authored masks. The original
reference images were opaque RGB; their masks are user-authored interpretation,
not observed depth or recovered alpha. Original source art remains unmodified.

1. Choose **Load sample** or **Browse…**, then **Inspect**. Inspect the source
   checkerboard and optional mask. Select the actual target plane explicitly.
2. Set crop, placement, exact grid transform and integer scale. Native module
   IDs disable raster sampling controls and preserve their exact grid.
3. Keep **Overlay · no write into cutouts** for transparent openings. Choose
   **Replace · explicitly write Empty** only when actual erasure is intended.
   The threshold deterministically decides partial alpha. Mask-excluded pixels
   always remain no-write in both modes. To expose a rear plane through an
   Overlay cutout, choose an empty destination region or separately approve
   explicit Empty writes; transparent source pixels preserve existing cells.
4. Configure colour-to-native-material rows, maximum RGB distance and the
   unmapped policy. Strict refusal is the default. The synthetic sample has one
   intentionally unknown colour: add a mapping or explicitly select **Skip and
   report** to continue. Approximate palette matching never infers depth.
5. Press **Preview proposed native placement**. Inspect extent, mapped/no-write/
   explicit-Empty/unmapped counts, source and geometry digests, actual before
   materials and the resulting proposal. Nothing has been written yet.
6. Press **Approve reviewed placement**. The target is observed again and applied
   through bounded native requests. Read the actual final status and readback;
   **Stop · keep applied prefix** retains the acknowledged cells. It is not an
   automatic rollback.
7. Solo the target and inspect the placed material pixels. Compare the opening
   with the rear plane, then use the target's ordinary Undo/Redo.

A crop is at most 512 × 512 source pixels; integer replication is 1–4 and the
result is at most 262,144 cells. The preview reports the exact sampled extent.
Each native write request contains at most 4096 cells. Large imports can exceed
the 32-entry history window; the displayed warning tells how many older entries
will be displaced. Do not expect one Undo to erase a multi-chunk import.

## Reuse and compose architecture

The **Compose** tab offers eight native parts and three finite layered presets.
Choose a target, exact transform, origin, repeat count and step for a single part,
then **Preview selected native part**. A part's origin is its transformed grid's
top-left; a composition's origin is its shared design anchor. Extents, material
permissions, declared clearances and actual target materials are checked.

For a complete preset, select **Factory service bay**, **Reactor service arch** or
**Inhabited skybridge**, then **Preview layered composition**. Review every
plane-local stage using the stage picker and before/after material views. The
small composite is a native-ID proposal with current opacity and fixed order;
it is explicitly not a prediction of haze, depth, glow or animated appearance.

**Approve reviewed construction** executes the declared stages in order. Each
dependency requires an actual native acknowledgement and readback; hiding it
cannot mark it complete. Scene replacement, stale revisions or changed
permissions invalidate approval. Partial/Stop outcomes retain their actual
prefix and identify the unexecuted stages. No cross-plane atomic transaction or
structural attachment/load-bearing solver is claimed.

After full native completion, **Apply reviewed depth and atmosphere** is a
separate optional approval. It applies the displayed settings and replaces the
existing atmosphere configuration. Changes to geometry, revisions or relevant
settings invalidate that token, including native Undo that restores the same
pixels with a newer revision. This settings operation adds no material history.

To make your own reusable part, select an editable plane, set a region/name,
then **Harvest native part**. The copied native observation becomes a part with
Empty as no-write. **Export selected part…** writes a validated local module for
later import. Harvested catalogue entries are session-local until exported;
placed cells and historical provenance belong to the scene save.

## Configure atmosphere and compare motion

The **Atmosphere** tab offers haze, steam, rain, dust, beacon and machinery
profiles. Choose a decorative plane, region and deterministic seed, then add a
profile. Select an existing regional effect to change motif count, speed,
strength, direction and colour, then **Apply effect settings**. Beacons use speed
as a pulse multiplier; their direction control is disabled.

**Enable atmosphere**, **Pause animation** and **Reset motion** are visual
controls. Reset motion zeros transient visual phase and keeps the authored
configuration. Hidden, Solo-excluded, zero-opacity or otherwise inactive planes stop
their motif processing. Lock prevents authoring; it does not freeze an already
visible animation. All effects share twelve-region/384-motif limits. The controls
are live authored settings and do not change native geometry or Undo history.

Compare OFF and ON with the same scene, camera, zoom and actor state. Prefer
restrained local accents that leave routes and material edges legible. These are
presentation-only motifs: animated steam is not native Steam mass, rain is not
water accumulation, and a beacon is not physical illumination or a hazard.
Decorative native Worlds remain paused at zero Hz in this candidate.

## Save, exit and reopen

Use ordinary **Save start / Ctrl+S**, including while Strata is disabled. Save
records all four authored layouts, validated effect settings and seeds, layer
settings and retained operation provenance. It preserves this session's history
but does not serialize Undo stacks. Exit completely, relaunch the shipped
launcher, and use **Load start** to open the named scene in a fresh process.
Inspect each plane, imported openings, preset geometry and effect settings.

New extensions use strict `CYSSTRAT` v2; v1 remains compatible. Invalid versions,
unknown fields, bad native IDs, corrupt data or budget overflow are refused.
Save is an authored-layout operation, not exact evolved physics continuation.
Visual animation phase restarts from the saved configuration. Evolved Play
occupancy can become an authored baseline through explicit **Flatten / Bake
History**; Flatten never merges visual planes. Select editable Play before
Flatten or model-assisted Art, which keep their existing Play-only authority.

## Record the physical owner decision

Use **OWNER-EVALUATION.md** in the package to record source/package identity,
Windows version, GPU/driver, display resolution/scaling and observations. Inspect
all five environments, actual flight, panning/zooming, import cutouts, native
part reuse, Stop/history and fresh-process reopening. Note occlusion, unclear
collision silhouettes, visibility leakage, input stalls and pacing with
atmosphere OFF/ON under matched conditions.

Hosted Linux/Windows graphics and pristine extracted execution establish their
specific engineering witnesses. They do not establish physical NVIDIA FPS,
subjective playfeel, aesthetic acceptance or broad dense-simulation performance.
Keep **HOLD**, request changes, or record acceptance for later merge review.
Nothing in the evaluator automatically promotes, merges or changes the ordinary
default presentation.
