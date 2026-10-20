---
title: Map layer polish and visual validation
status: Current
document-kind: guide
scope: Recommended map composition and visual review; inspected main fc015a7 and separately pinned Deepworks 7590316 example, not universal runtime acceptance
canonical-for: [map-layer-polish, map-visual-validation]
last-reviewed: 2026-10-20
related-documents: [map-production-workflow.md, map-exhibition-design.md, ../systems/depth-layers-and-parallax.md, ../systems/material-appearance-and-rendering.md, testing-validation-and-replay.md, documentation-maintenance.md]
---

# Map layer polish and visual validation

**Current recommended workflow:** use this guide to turn authored districts and
working experiments into a coherent map whose layers, reactions and controls are
actually visible. It owns composition and visual verification. Start with
[map production](map-production-workflow.md) for source selection and delivery;
use [exhibition design](map-exhibition-design.md) for material rules, apparatus,
source schedules and native reaction evidence. The gates below are recommended
production steps, not new universal simulation or GPU acceptance requirements.

## Establish the source and host boundary

This guide was authored against main
`fc015a77d3b851fef4ea7734923bcdb3762a19a5`. The completed Deepworks example is
pinned to **`7590316e01f0b6efbcc11598fc454656f38f8558`** in PR #185, which was
unmerged when this guide was written. Links to its implementation and evidence
use that immutable revision. This documentation does not install its runtime.

| Subject | Current main baseline | Version-pinned Deepworks example |
|---|---|---|
| Depth host | Strata Theatre is an opt-in synchronous four-world comparison host. | A dedicated free-camera exhibition reuses that owner; it does not attach the ordinary actor session. |
| Authored dimensions | Runtime, compositor and material surfaces use a fixed 640 × 360 authored ROI over 1024 × 1024 native backing. | Parameterized depth components support its complete 1024 × 1024 map. The total map is one square, not one square per district or plane. |
| Layer semantics | `play`, `scripted`, `effects`, and an unticked, cached `background`. | Sixteen districts have foreground/rear experiments, local atmosphere and frozen distant architecture. |
| Timing and controls | Use the Strata host's own rates, explicit event routes and controls. | Its source programme, tour, reset behavior and F8 controls belong to the pinned host. |

The main [depth contract](../systems/depth-layers-and-parallax.md),
[`CyberDepthLayerRuntime.WORLD_SIZE`](../../godot/scripts/depth/depth_layer_runtime.gd)
and [material surface](../../godot/scripts/depth/depth_layer_surface.gd) establish
the baseline. The pinned
[Deepworks guide](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/docs/operations/deepworks-exhibition.md)
and [depth implementation](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/godot/scripts/depth/depth_compositor.gd)
establish the example. Reinspect the target checkout before using either API.
Native backing capacity alone does not prove that distant cells are authored,
ticked, uploaded, rendered, reachable by the camera or correctly paintable.

## Gate 1 — establish the composition at three scales

Write the map's visual premise and route before filling rooms with fixtures.
Choose shared construction language, a progression through adjacent areas and
one distinguishing silhouette per district. Connect neighbouring districts with
consistent doorway, floor and service treatments. Let damage, occupation,
temperature or function explain changes in palette and density.

| Viewing scale | What should read | Useful review question |
|---|---|---|
| Complete overview | Overall mass, circulation, district grouping and large light/dark changes. | Can the intended route and distinct regions be understood before reading labels? |
| District view | A recognisable architectural form, foreground/rear apparatus and local service paths. | Can the room be identified from its silhouette and machinery? |
| Close-up | Reagents, contact sites, transport, products, material finishes and small furnishings. | Can a viewer tell what changed and which fixture caused it? |

Build large forms first: a suspended reactor, split kiln, organ of pipes, broken
viaduct, habitation stack or flooded pump hall. Vary height, void placement and
orientation as well as surface material. A common shell can tie a laboratory
together, but changing only the wall colour makes neighbouring rooms difficult
to distinguish. Reserve the brightest local contrast for the apparatus and a
few orientation marks. Check the overview again after every dense detail pass.

Use references as a vocabulary of relationships. Main's
[Blacksite Nine](blacksite-nine-demo.md#district-map-and-the-exploration-route)
contrasts surface ruins, inhabited middle works and buried machinery around a
continuous route. [Neon Reliquary](neon-reliquary-demo.md) combines a suspended
central machine with stained glass, service buildings and a flooded nave.
The pinned [Deepworks architecture](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/godot/scripts/exhibition/deepworks_architecture.gd)
uses distinct crowns and distant forms while retaining a common gallery frame.
Copying those relationships is more useful than repeating every decorative mark.

### District composition worksheet

Use a task worksheet like the following before parallel authoring. This is
planning data, not an engine schema or a file the runtime knows how to load.

```yaml
district: <stable code and title>
purpose: <one sentence connecting place and experiment>
overview_shape: <dominant mass and major opening>
palette_roles: <structure / quiet recess / specimen contrast / guide light>
foreground_apparatus: <reserved rectangle and visible contact zone>
rear_apparatus: <reserved rectangle and opening through nearer geometry>
atmosphere: <source, motion path, visible witness and cleanup region>
far_architecture: <unique silhouette and its exposed viewing regions>
circulation: <shared ports, clear volume and final carve owner>
detail_niches: <furniture, tools, wiring, signs; outside reservations>
review_views: <overview, district, foreground contact, rear contact>
evidence_targets: <initial state, first pulse, useful reaction states>
```

Agree on coordinate conventions, rectangle end semantics, origin and layer names.
Name the final integration owner so architecture, apparatus and seam authors do
not independently overwrite each other's reservations.

## Gate 2 — give every district an intentional role on every plane

### Complete depth coverage and a visible map

Prove full multilayer coverage in every district through authored roles and
actual rendered visibility. Record foreground `play` apparatus, independent
`scripted` rear experiments, local `effects` atmosphere and frozen `background`
architecture. Verify the authored ROI, material-surface extent and camera/input
extent agree. Preserve real viewing apertures through nearer geometry, including
reagent arrival, contact and product regions; use the
[aperture gate](#gate-3--preserve-apertures-circulation-and-the-detail-hierarchy).

With native ticks, camera and material animation fixed, compare the actual
compositor with each layer hidden in turn. Measure visible pixel contributions
per district and require the original image to return when the layer is restored.
Inspect specimen readability alongside counts; allocated worlds or isolated
plane images cannot prove the finished composition. The
[pixel gate](#gate-4--prove-full-extent-and-visible-layer-contributions) specifies
these controlled comparisons.

For every automatic atmosphere source, witness its first native pulse in a
source-local region. Confirm application and the exact published tick, then mask
the visible/hidden comparison with native material cells, excluding Empty and
static containment walls. Keep other clocks fixed so unrelated reactions cannot
satisfy the [first-pulse gate](#gate-5--witness-each-automatic-atmosphere-source).

At normal window sizes, measure HUD bounds and actual map pixels behind the
controls; also review the clean overview, each district and foreground/rear
contact close-ups. Exercise resize, camera inverses, painting, pause, reset and
input boundaries through the real host. The
[HUD and control gate](#gate-6--review-the-real-hud-camera-and-control-path) keeps
a clean screenshot from concealing an unusable default view.

Bind those results to source, recipe, runtime, renderer, platform and capture
state. This is scoped visual evidence. Follow the
[source boundary](#establish-the-source-and-host-boundary): main Strata's authored
ROI is 640 × 360 over 1024-square native backing. That allocation does not supply
full-size authored surfaces, camera/input guards or an exhibition source scheduler.
Verify the checked-out APIs before using the pinned Deepworks additions.
Neither its pixel thresholds nor Linux software-renderer results establish
universal map, hardware-GPU, browser or actor acceptance.

### Plane roles and coverage matrix

Maintain a district-by-plane coverage matrix. Record both authored content and
the screen region where the viewer should see it. A nonempty rectangle stream,
four allocated worlds or an isolated image of each plane is incomplete evidence:
near geometry may hide everything that makes a rear plane useful.

| Plane | Recommended authoring role | Required visual question for that role |
|---|---|---|
| Foreground / `play` | Primary shell, local instruments, accessible edits and experiment vessel. | Are the reactants and their contact/transport region visible without removing the apparatus? |
| Rear / `scripted` | Independent experiment and machinery framed through nearer openings. | Can the viewer follow both the reagent arrival and its native result? |
| Atmosphere / `effects` | Local dust, droplets, sparks or vapour with bounded source and cleanup. | Does an actual moving material cell reach the final composition? |
| Distant / `background` | Authored far architecture, quieter silhouettes and recess contrast. | Does it add place and depth through openings throughout the map? |

For a request for interacting background material, identify the active rear plane
explicitly. Strata's fourth `background` plane remains frozen; making that plane
tick changes the host contract. Main's [four-plane ownership](../systems/depth-layers-and-parallax.md#four-material-planes)
and [explicit event routes](../systems/depth-layers-and-parallax.md#explicit-interlayer-routes)
do not infer cross-world chemistry from overlapping pixels. The pinned
[Deepworks clock explanation](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/docs/operations/deepworks-exhibition.md#four-full-size-worlds-and-independent-clocks)
shows how rear reactions and frozen distance satisfy separate roles.

Full coverage means complete intentional composition, not solid occupancy.
Empty openings, quiet recesses and sparse air are part of that composition.
Decorate the far plane in every district instead of placing one generic skyline
behind the entire map. Keep distant contrast below the specimen contrast where
their silhouettes overlap; use brighter distant elements where they help orient
the room without competing with a reaction.

A frozen plane still needs a valid first native publication and a completed
material-surface bake. Check that its initial art appears and that its native
tick remains unchanged while active planes run. Main's
[surface publication and bake contract](../systems/depth-layers-and-parallax.md#reconstructed-integration-checkpoint)
uses a separate canvas per plane and a one-shot bake on publication or pause.
After reset, verify the new recipe appears instead of accepting a stale cached
image as evidence of frozen coverage.

## Gate 3 — preserve apertures, circulation and the detail hierarchy

Reserve foreground apparatus space and rear viewing apertures before adding
architecture. A rear apparatus needs a clear opening through every nearer plane
that can obscure it. Check the reagent nozzle, flight or flow path, contact
surface and likely product accumulation, not only the initial vessel centre.
Camera parallax can move these relationships, so reservations also need rendered
checks at the views and depth modes the map actually exposes.

Compose in an explicit order: broad distant masses; district structure and
frames; apparatus; constrained furnishing; final shared circulation carve.
An architecture module should leave its agreed apparatus openings Empty when it
returns its stream. The integration pass then appends the apparatus and clears
reserved seams after every contributing author. Do not repair occlusion by
carving through a vessel's containment or erasing the reaction substrate.

The pinned [architecture aperture pass](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/godot/scripts/exhibition/deepworks_architecture.gd)
and [map integration](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/godot/scripts/exhibition/deepworks_map.gd)
demonstrate separate aperture and final seam ownership. Main already provides a
[shared seam pass in Blacksite Nine](blacksite-nine-demo.md#native-construction-and-the-shared-seam-pass).
Use the chosen host's limits; neither example's passage widths nor rectangle
budgets are universal map constants.

Rasterize the final ordered recipe for geometric checks. Prove that reciprocal
ports and their approach volumes remain Empty after the last write, not merely
that their metadata names both neighbours. Count overlapping writes and Empty
carves in authoring budgets. Use bounded chunky steps for diagonals and rings
when individual pixel strips would consume the record budget. Keep a room's
helpers inside its local bounds and the complete authored extent.

Separate route continuity from actor acceptance. A free-camera lab can prove
open seams without providing an actor session. A playable exploration map needs
an additional route check with its selected body, clearance and movement rules;
a flood fill or camera tour cannot establish those behaviors.

Add small details in clusters that explain use: a chair facing a console, a tool
beside a maintenance hatch, clamps along a pipe, a broken sign over a closed
shop, specimen niches, a small shrine or a discarded crate. Keep these in
reserved niches. Read the [material appearance contract](../systems/material-appearance-and-rendering.md)
and [building catalogue](../systems/building-material-catalogue.md) before choosing
fills: a dark material can still have a strong glazing pattern, and a decorative
metal name does not grant another material's electrical behavior. Keep exact
apparatus semantics in [exhibition design](map-exhibition-design.md).

## Gate 4 — prove full extent and visible layer contributions

Use the actual host, its material surfaces and final compositor. A palette-only
preview or synthetic map illustration cannot prove viewport sizing, UI overlap,
parallax, source publication or the resulting composition.

First verify the configured authored extent, each native publication, surface
dimensions, camera bounds and pointer inverse. Put recognisable temporary test
markers near the far edges in a focused fixture when extending dimensions.
Confirm that they appear in each plane and in the final composite, and that a
pointer maps back to the intended cell. The pinned
[depth dimension render test](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/godot/tests/test_depth_dimensions_render.gd)
tests pixels beyond main's older authored ROI; allocation checks alone would
miss a material surface that still crops to the old dimensions.

Then compare the complete composition with matched images hiding one layer at
a time. This measures final visible contribution rather than isolated content.
For each comparison:

1. Install the same complete recipe and fix native ticks, camera, view, depth
   mode, layer transforms and presentation time. Finish the initial frozen bake.
2. Capture all layers. Hide only the selected plane, allow the renderer to
   complete the update, and capture again without advancing any world.
3. Measure changed RGB pixels inside every district's screen region. Record the
   channel tolerance, region, count and image dimensions with the images.
4. Restore the layer and verify the original pixels return. Drift means the
   comparison changed more than visibility and needs diagnosis.
5. Inspect the images as well as the counts. A large dark frame or unrelated
   ornament can dominate a metric while the intended rear specimen stays hidden.

A useful metric counts pixels whose largest absolute RGB channel difference
exceeds a declared tolerance. Derive that tolerance and the minimum contribution
from the fixture's resolution, material alpha, intended visible shapes and
renderer variation. Freeze them before the accepted comparison. Do not lower a
threshold after failure simply to admit an occluded plane.

The pinned [Deepworks render regression](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/godot/tests/test_deepworks_render.gd)
uses a centred 1024-square overview with unit layer scale, frozen material
animation, and distinct per-district rear/far checks. Its numerical thresholds
and observed counts are evidence for that fixture. They are not defaults to
copy into unrelated maps. At other resolutions or transforms, map world-cell
witnesses through the actual compositor transform; do not assume one image pixel
equals one native cell.

## Gate 5 — witness each automatic atmosphere source

An effects plane can be populated and ticking while all moving material is
behind a foreground divider. An effects-visible image can also differ only
because the plane contains static walls. Test the actual source material.

Use a separate first-source-pulse witness for every district:

1. Pause foreground and rear simulation and freeze material animation. Keep
   their installed packets unchanged while explicitly stepping only effects.
2. Find the source's first scheduled native application. Advance through that
   application and its native step; derive the expected publication tick from
   the scheduler's before/after-step convention.
3. Require the source's application counter, successful publication and the
   exact corresponding surface tick before taking the witness image.
4. Capture effects visible and hidden at the same packet. Compare the source
   neighbourhood, allowing for native motion between injection and publication.
5. Mask the witness with native nonempty source-material cells. Exclude static
   containment and unrelated authored wisps; map that mask into screen space
   correctly. Require visible material pixels, not just a visible riser wall.
6. Confirm foreground, rear and frozen far clocks did not advance. Retain the
   source ID, material, tick, witness region and visible-pixel result.

The pinned [render test's atmosphere witness](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/godot/tests/test_deepworks_render.gd)
and [effects source recipe](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/godot/scripts/exhibition/deepworks_exhibits.gd)
provide a concrete implementation. First-pulse proof establishes visible
emission; also inspect later ordinary running footage or captures for distracting
accumulation, spillover and cleanup. Native reaction tests remain responsible
for chemical products and transport semantics.

## Gate 6 — review the real HUD, camera and control path

Capture the default entry with the HUD visible at ordinary window sizes before
making a clean atlas. Check actual header and side-panel bounds against the map
rectangle and compare map pixels with all layers hidden under the same HUD.
A correctly sized compositor can still be covered by an opaque control. Test
text wrapping, container minimum sizes and scrolling with the final labels.

Exercise the host's clean-view control and confirm the map gets the intended
viewport, not merely that a label became invisible. Capture a complete overview,
every district, selected foreground/rear contact close-ups, isolated planes and
useful evolved states. Distinguish an exact atlas crop from a district rerender:
the latter can have different parallax, framing and material sampling. Keep both
when they answer different review questions.

Test camera and painting at the overview, corners and close-ups after a resize
and a HUD toggle. Check the inverse for the selected layer, not just foreground.
The main [parallax contract](../systems/depth-layers-and-parallax.md#parallax-and-authoring-coordinates)
owns that relationship; the pinned
[Deepworks controller test](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/godot/tests/test_deepworks_controller.gd)
shows host-specific checks for input, pause, tour, reset and view preservation.

Verify that UI interaction, held inputs, modal close and focus loss do not leak
an edit into the scene. Review pause and reset with the sources enabled: the
status text, material animation and published state must agree with the outcome.
A visibility toggle need not pause a native clock. A camera tour need not reset
rooms on arrival. Explain the chosen behavior and capture time convention; a
manual tick of each plane is not a frame of independently paced normal play.

## Retained failure lessons

These are diagnoses from the pinned
[Deepworks audit](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/docs/audits/2026-10-20-deepworks-exhibition.md),
not assertions that main already contains every repair.

| Observed failure | Corrective workflow |
|---|---|
| Atmospheric risers were behind a foreground divider despite native coverage. | Inspect the final composite; move effects into a clear authored viewing region and repeat native-masked pulse checks. |
| Wrapped header text expanded its minimum height over the map. | Fix container/label sizing, then retain geometry and actual-map-pixel checks with the HUD visible. |
| Broad Dark Glass fills produced distracting diagonal glazing. | Use quieter matte far materials, preserve glass for actual windows, and compare both atlas and specimen close-ups. |
| Pale specimens merged with pale distant masonry. | Change the distant value/material relationship while preserving apparatus geometry and native behavior. |
| A headless inverse transform read a null shader default. | Keep explicit CPU transform state shared with shader configuration, and test pointer agreement in logic and actual rendered views. The repair is in the pinned compositor. |
| The initial renderer still had assumptions tied to the smaller authored ROI. | Test far-corner cells through publication, per-plane surfaces and the final composite when dimensions change. |
| Default user-data directories were unwritable; an audio backend emitted errors. | Use writable task-scoped XDG paths and the recorded supported audio setup; keep the failed attempts separate from accepted results. |
| Another validation process stopped the X server used for capture. | Give the display an explicit owner and lifetime covering the whole render command. Do not let another job's cleanup retire it. |

Do not solve a presentation failure by changing material rules or inserting
advertised products. A source that misses its settled reagent is an apparatus
problem; [exhibition design](map-exhibition-design.md) covers native witnesses
for that class of failure. Re-run the gate affected by a correction and any
dependent acceptance gate, retaining the original diagnosis.

## Run and retain the visual gate

Use the [local build guide](local-build-and-validation.md) to establish pinned
Godot and source-matched, materialized native libraries. Render tests require a
real rendering backend. Main's [Linux CI execution contract](testing-validation-and-replay.md#ci-execution-sharding)
discovers `test_*_render.gd`, supplies a display and the Compatibility renderer,
and rejects skips, timeouts, nonzero exits and engine/script errors. A headless
parse, an allocated viewport or exit zero without pixel assertions is insufficient.

On Linux software rendering, record the actual display, driver, renderer,
Godot/runtime hashes, audio configuration and writable data/cache paths. Record
shader compilation and steady-state frame costs separately, while retaining
startup inside the declared whole-test timeout. Avoid concurrent large
software-rendered capture sessions when contention would invalidate a timeout
comparison. Keep a focused regression within its declared test budget and give
the larger image-production helper its own explicit budget. Never erase timeout
or engine errors by increasing a number without diagnosing the cause.

Main's [material upload contract](../systems/material-appearance-and-rendering.md#dirty-bytes-versus-gpu-upload)
still uploads the full RG8 backing for a changed material texture. Sparse cells,
dirty patch counts and frozen far architecture do not imply a measured hardware
frame budget. The pinned [capture helper](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/godot/tools/capture_deepworks.gd)
and [evidence manifest](https://github.com/techrote/cybersand/blob/7590316e01f0b6efbcc11598fc454656f38f8558/docs/audits/2026-10-20-deepworks-exhibition-evidence.json)
show how Deepworks records actual images and scoped Linux evidence.

### Visual handoff template

Retain the following with the implementation checkpoint. Follow
[documentation maintenance](documentation-maintenance.md#documentation-update-checklist)
for canonical routes, source identities and historical evidence.

```text
Source: checkout / revision / dirty executable paths and hashes / recipe hash
Runtime: platform / Godot / native libraries / renderer and driver / workers
Capture: command / timeout / exit / errors / image dimensions and hashes
State: per-plane ticks / paused planes / source state / presentation phase
View: camera / extent / layer scale and parallax / depth mode / HUD state
Coverage: district × plane authored role / intended visible region
Pixels: per-district hide comparison / tolerances / restored-frame check
Atmosphere: source / application / published tick / native mask / visible count
Review: overview / all districts / contact close-ups / evolved state findings
Repairs: observed defect / targeted change / repeated gate / retained failure
Limits: platforms, actor traversal and performance not actually exercised
```

Keep screenshots, numerical visibility checks and native reaction evidence
distinct in the report. Together they can support a polished, working exhibition
on the tested host. They do not automatically establish browser behavior,
hardware-GPU performance, ordinary actor integration or broad physics acceptance.
