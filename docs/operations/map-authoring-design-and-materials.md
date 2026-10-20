---
title: Map authoring design, materials and visual polish
status: Current
document-kind: guide
scope: Recommended planning, district composition, material selection, apparatus framing and visual iteration for polished native CyberSand maps, using Deepworks as the inspected reference
canonical-for: [map-authoring-design, map-authoring-material-selection, map-authoring-visual-polish]
last-reviewed: 2026-10-20
related-documents: [map-authoring-walkthrough.md, map-authoring-native-layers-and-programmes.md, map-authoring-validation-and-acceptance.md, deepworks-exhibition.md, ../systems/building-material-catalogue.md, ../systems/depth-layers-and-parallax.md, ../systems/material-appearance-and-rendering.md]
---

# Map authoring design, materials and visual polish

Use this chapter to turn a map brief into purposeful geometry, readable native
apparatus and a coherent composition. Begin with the
[authoring walkthrough](map-authoring-walkthrough.md). The
[native layers and programmes chapter](map-authoring-native-layers-and-programmes.md)
owns implementation technique; the
[validation chapter](map-authoring-validation-and-acceptance.md) owns evidence
and acceptance.

**Status:** the design practices below are recommendations for authors.
**Current reference configuration** means inspected Deepworks source at merged
revision `4f3685b71366218e82e7c2188e4ecdf27553f4cf`. Its dimensions, district count,
palettes and helper functions are examples with specific contracts. A future
map does not acquire a generic authoring API merely by copying those files.

The relevant implementation is split between
[`CyberDeepworksMap.build()`](../../godot/scripts/exhibition/deepworks_map.gd),
[`CyberDeepworksArchitecture`](../../godot/scripts/exhibition/deepworks_architecture.gd)
and
[`CyberDeepworksExhibits.build()`](../../godot/scripts/exhibition/deepworks_exhibits.gd).
That separation is useful: overall composition, scenic geometry and functioning
apparatus can be reviewed independently, then checked together.

## Establish the brief and its coordinate system

**Recommended input:** the owner's requested total size, references, atmosphere,
important interactions and intended way of exploring the map. Convert these
into a short design record before drawing.

| Decision | Record explicitly |
|---|---|
| Native extent | Total width and height in simulation cells |
| Presentation | Overview, district inspection, actor exploration or another existing host |
| District structure | Origins, extents, names and intended connections |
| Layer purpose | What the visitor should see and what actually simulates in each plane |
| Main experiences | The changes, movements or discoveries the visitor should observe |
| Identity | Dominant construction, accent materials, age, damage and recurring fittings |

Keep image resolution separate from native extent. Deepworks contains one
1024 × 1024 map divided into sixteen 256 × 256 districts. Its retained
2048 × 2048 atlas presents that map at two image pixels per cell. Those values
describe the reference; image enlargement does not create more simulation
space. See the [exhibition guide](deepworks-exhibition.md#what-is-the-map).

For a new map, give each district a short purpose statement: what happened
here, what still operates, what attracts attention and how the visitor leaves.
Then describe its neighbors. An electrical hall adjoining a cold store might
share a service duct while changing from warm signal lights to pale insulation.
This provides a reason for both continuity and variation.

**Checkpoint:** produce a district table and a simple arrangement with entrances,
exits, principal apparatus and viewing openings. Confirm that the total extent
matches the request before multiplying detailed room variants.

Deepworks-specific dimensions occur in several places:
`CyberDeepworksMap.SIZE` and `DISTRICT_SIZE`,
`CyberDeepworksArchitecture.Canvas.rect()` clipping,
`CyberDeepworksExhibits.DISTRICT_SIZE`, and the exhibition runtime's
[`_validate_programme()`](../../godot/scripts/exhibition/deepworks_runtime.gd).
Changing only one constant does not resize that authoring system coherently.

## Reserve routes, seams and viewing openings first

**Recommended action:** assign every intended connection an explicit location
and clearance, then reserve it during room construction. Treat a seam as a
shared feature with two approaches: the exit from one district and the arrival
into the next.

For each connection, record the relevant plane, adjoining districts, a shared
world-space opening with its clearance, floor or shaft continuity, and nearby
landmark. A pipe can continue across a
boundary while its clamps, lighting and surrounding masonry change with the
district. An approach should give the visitor a reason to proceed and enough
space to understand the destination. Reuse a structural grammar while varying
major silhouettes and room functions. Place fine service fittings at readable
viewing scales and leave quiet surfaces around active apparatus. If adding
procedural variation, record seeds or stable district/world indices and retain
deterministic iteration; keep route and apparatus masks authoritative afterward.

**Current reference:** `CyberDeepworksMap.build()` composes architecture and
apparatus, then carves foreground circulation last.
[`passages()`](../../godot/scripts/exhibition/deepworks_map.gd) describes its
24 internal seam openings. The associated
[`_check_passages()`](../../godot/tests/test_deepworks.gd) reads native material
cells across those openings. A convincing painted doorway alone does not
establish an opening in native authority.

Reserve visual access with equal care.
[`_play()`](../../godot/scripts/exhibition/deepworks_architecture.gd) clears
`FOREGROUND_APERTURE` and `REAR_APERTURE` after its scenic work; apparatus is
composed afterward. Rear gantries wrap their reserved window rather than
filling it. This ordering protects important views from later decoration.

**Checkpoint:** inspect the combined geometry with simple materials before
adding small details. Verify seams in native cells and inspect both sides of
each transition in the renderer. Record actor traversal separately if the
chosen host supports actors: Deepworks itself is a free-camera exhibition
without an ordinary actor session, as its
[controls guide](deepworks-exhibition.md#open-inspect-and-replay-a-setup) explains.

## Choose materials by role and actual behavior

**Recommended action:** select a small architectural palette for each district,
then add materials needed by its working specimens. Record why each material
is present.

| Role | Design question |
|---|---|
| Main construction | What makes this room identifiable at overview scale? |
| Inset finish | Which surfaces reveal age, repair, ownership or use? |
| Accent | Which lights or markings direct attention? |
| Reactive specimen | What native behavior is being demonstrated? |
| Containment | What actually keeps the apparatus within its intended area? |
| Quiet backdrop | What makes moving cells and reaction products readable? |

**Current reference:** `CyberDeepworksArchitecture.PALETTES` assigns dominant
housing, accent and inset finish to each district. `SWATCHES` and `_swatches()`
provide small specimen niches. Deepworks uses all 51 MAT-002 building materials
because broad catalogue coverage is part of that map's composition. A future
map should choose coverage to match its own brief.

Read the [building catalogue](../systems/building-material-catalogue.md)
before substituting materials. The newer materials include combustible woods
and fibres, reactive mineral or manufactured specimens, and materials inert
apart from broad Acid corrosion. Their attractive names and finishes do not
guarantee the behavior implied by their real-world counterparts.

Several distinctions matter directly when drawing apparatus:

- `CyberDeepworksExhibits._charge()` uses actual Metal electrodes; Brass is
  decorative casing.
- `_growth()` gives Fungus its actual Wood/Oak Timber substrates. New timber
  finishes and Moss Wall do not automatically supply that substrate.
- `_vessel()` supplies actual Wall containment inside the visible shell.
  Decorative firebrick or metal panels are not a substitute for that boundary.
- `_ignition()` presents native Thermite/Magnesium conversions. The
  [catalogue limits](../systems/building-material-catalogue.md#limits) do not
  establish a heat field or pressure explosion.

These examples are in
[`deepworks_exhibits.gd`](../../godot/scripts/exhibition/deepworks_exhibits.gd).

**Checkpoint:** retain a material-role table and verify every advertised
interaction against the native rule owner. The desktop GDScript fallback
treats the newer building materials as static surfaces; its appearance cannot
qualify native combustion or pair reactions.

## Build visual detail at several scales

**Recommended action:** work from silhouette to structure to fittings.
Review each pass at the intended viewing scale before adding the next.

At overview scale, establish the room's largest recognizable forms: a furnace
crown, hanging tank, long gantry, cold-store facade or massive gate. Give
neighboring districts different proportions and voids. Repeated structural
language can tie a complex together while major machinery distinguishes its
rooms.

At district scale, make construction legible. Add supports, housings, platforms,
duct runs, vessel rims, recesses and connections between machines. Let
architectural elements explain where an apparatus belongs. Leave clear space
around its active chamber and its arrival route.

At close range, add small fittings with a local purpose: pipe clamps, valve
handles, access panels, numbered bays, specimen shelves, cable bundles, cups
or abandoned tools. Concentrate these details around service points, work areas
and viewing positions. Broad quiet surfaces give intricate areas contrast.

**Current reference:** the architecture file provides
`Canvas.rect()`, `panel()`, `beam()` and `octagon()`, together with
`_header()`, `_side_workshop()`, `_background_hero()`, `_pipe()`, `_valve()`,
`_vent()`, `_lamp()` and `_number()`. These
[source helpers](../../godot/scripts/exhibition/deepworks_architecture.gd)
build native-material rectangle records; several contain Deepworks-specific
clipping or layout assumptions.

Material shaders already contribute grain, courses, weave, joints and exposed
edge treatments. Inspect their actual appearance before duplicating those
patterns as hundreds of tiny authored rectangles. The
[appearance contract](../systems/material-appearance-and-rendering.md) owns
rendering behavior and cost semantics.

For any added procedural variation, use recorded seeds or stable district/world
indices and preserve the same iteration order. Keep route and apparatus masks
authoritative after decorative variation. This is recommended authoring practice:
a camera move or capture retry should not quietly redraw the scenery. If using
the existing [generation fields and modifiers](../systems/procedural-generation-fields-and-modifiers.md),
retain their initial-context and override ordering contracts instead of
inventing a competing mask pipeline. Deepworks' authored helpers are a separate
reference from that generation workbench.

**Checkpoint:** capture an overview, one district and a close-up. The room should
be recognizable at each scale, with the working specimen retaining priority.

## Design apparatus around a visible native witness

**Recommended action:** describe the observable outcome before decorating its
container. For each exhibit, record the initial specimen, supplied reactant,
path to contact, expected native change, observation region, and where products
should remain visible.

A useful physical arrangement gives each of these a clear place: feed above
the fall path, contact surface within view, space for movement, and a collection
region beyond the source. For a gas-producing reaction, leave visible headroom;
for a granular demonstration, ensure grains can actually leave the feed shelf.
Choose the arrangement from the implemented transport and contact behavior.

**Current reference:** `CyberDeepworksExhibits._exhibit()` records the title,
description, focus, observation rectangle and mechanism. `_feed()` describes
reactant sources; `_vessel()` establishes the chamber. These are
[Deepworks recipe helpers](../../godot/scripts/exhibition/deepworks_exhibits.gd),
not a general-purpose editor schema.

Keep the evidence region visually and materially unambiguous. If the demonstration
claims newly produced Salt, a decorative Salt patch inside that region weakens
the observation. If it claims downward transport, material still occupying the
source nozzle is insufficient. The native
[`_check_products()` and `_check_flow()`](../../godot/tests/test_deepworks_reactions.gd)
show how the reference separates these claims.

Develop foreground and rear apparatus as a pair with different mechanisms or
views. Check them within the complete composition: foreground borders, distant
glints and atmosphere can obscure an otherwise successful rear reaction.
The [depth contract](../systems/depth-layers-and-parallax.md) explains why
visibility does not imply interaction between worlds.

**Checkpoint:** demonstrate the mechanism in native execution before investing
in surrounding ornament, then repeat the observation after full composition.

## Worked example: Customs of Dust and its rear classifier

This example follows the current A1 source. Its values illustrate a completed
arrangement; they are not universal spacing or scheduling rules.

**Brief:** a worn industrial checkpoint measures incoming granular cargo.
Foreground hoppers show two powder streams; a separate rear rack compares
Stone descent with neighboring Sand. The architecture uses reinforced
construction, amber signals and Gabion finishes, with a gate, lifting arm and
service furniture supplying the setting.

**Blockout:** A1 is district index zero with origin `(0, 0)`. Keep its foreground
circulation and rear viewing aperture reserved. Compose the rear vessel through
`_vessel()` using `Rect2i(142, 72, 76, 118)`, then add the internal rack in
[`_aggregate()`](../../godot/scripts/exhibition/deepworks_exhibits.gd).

The rack places a Gabion tooth at `(175, 105)` with size `4 × 64`, and a left
grating at `(149, 141)` with size `20 × 3`. The corrected Stone feed occupies
`Rect2i(170, 88, 3, 3)`. It drops into the open chute between the grating, whose
last x cell is 168, and the Gabion beginning at x175. The adjacent Sand feed
occupies `Rect2i(195, 88, 3, 3)`.

This placement is consequential. The original Stone feed was above the shelf.
Stone's native behavior did not move it sideways off that shelf, leaving no
Stone in the intended lower witness. Moving the source into the chute repaired
the apparatus while preserving its material and timing. The
[completion audit](../audits/2026-10-20-deepworks-pr185-completion.md#corrections-and-independent-review)
records the failure and correction.

**Programme and witness:** the current Stone source starts at its rear world's
tick 20, repeats every 31 ticks and has 40 applications. The transport check
requires Stone below district-local y143, away from its y88 nozzle. Read the
[programme chapter](map-authoring-native-layers-and-programmes.md) before
adapting that schedule to another host.

**Polish:** preserve the working chute while adding the shell, signal strip,
feeder collar and neighboring machinery. Check the classifier through the
foreground opening, then in rear-focused view. Add fine fittings only after
both views expose the downward movement and collection bay.

## Review visual polish and rendered multilayer coverage

**Recommended review:** a polished multilayer map needs readable composition,
visible contributions from its intended planes and controls that preserve access
to the scene. Four allocated worlds still need visual review and rendered tests
to establish what the visitor can actually see and use.

Compare matched atlas, district and apparatus views, isolated planes, the final
composite and HUD-visible views. Record viewport, camera position/zoom, layer
visibility, each plane's native tick and material-animation state. Inspect the
paused initial arrangement and meaningful running or later states, including
edge camera positions. Review silhouettes, contrast, negative space and
purposeful close detail: the main machinery, active specimen and observation
region should remain legible at their intended scales.

**Current test example:** [`test_deepworks_render.gd`](../../godot/tests/test_deepworks_render.gd)
uses the production compositor, holds simulation state and freezes material
animation. It captures actual pixels with layers visible and hidden; restoring
rear/far visibility must reproduce the original pixels. These matched comparisons
isolate a plane's visible contribution from simulation or animation drift.

Require independent rear and far witnesses in every intended district, including
far edges and quiet regions. For atmosphere, the current fixture follows each
local source's first native pulse and compares visible/hidden effects at the
same published tick. Its witness masks use actual nonempty, non-Wall effects
cells near that source, so static riser walls and unrelated wisps cannot satisfy
the check. Define a new map's regions and thresholds from its own geometry before
accepting results.

Review interaction alongside the image. The current rendered fixture checks HUD
overlap and useful visible map area at two window sizes. The separate
[controller tests](../../godot/tests/test_deepworks_controller.gd) exercise
camera/paint transforms and input ownership. Preserve keyboard slider adjustment
while focused controls block world movement or painting; release held input on
focus changes and require a fresh pan press when returning. Include mid-drag
cancellation and a positive check that fresh input works afterward.

Headless structure, native-mechanism and controller checks cannot establish these
rendered pixels. The Deepworks render fixture requires an actual display;
record its renderer and platform, and keep target-GPU performance claims within
their separately measured scope.

Author atmosphere around these witnesses:
[`_effects()`](../../godot/scripts/exhibition/deepworks_architecture.gd) supplies
sparse initial wisps, while
[`_atmosphere()`](../../godot/scripts/exhibition/deepworks_exhibits.gd) adds local
sources and cleanup. Preserve quiet backgrounds and clear specimen sightlines.

After geometry or source changes, collect source-matched views. Retain older
captures under their original identity, as the
[Deepworks guide](deepworks-exhibition.md#districts-and-their-paired-exhibits)
does for images predating the Stone-feed repair. Follow
[validation and acceptance](map-authoring-validation-and-acceptance.md)
for graphical commands, evidence and final review.

## Resolve common polish failures and hand off the result

| Symptom | Recommended correction |
|---|---|
| Districts differ mainly in color | Change major silhouettes, voids and machine arrangements before adding more trim |
| A seamless-looking doorway is blocked | Inspect the final native cells and composition order |
| A rear exhibit works only in isolation | Reopen its foreground sightline and inspect the combined layers |
| Glazing overwhelms quiet background space | Reserve glass for intended windows and choose an appropriate quieter finish |
| The source fires but nothing reaches the specimen | Inspect the actual feed path and native movement/contact behavior |
| Detail crowds out the reaction | Move ornament toward supports and service margins |
| Late tour stops appear inactive | Explain completed specimens and provide an accessible reset/replay route |
| A screenshot disagrees with current source | Regenerate the appropriate capture and retain the older evidence separately |

**Recommended handoff output:** provide the district plan, connection list,
material-role choices, apparatus descriptions and witness regions, authored
source locations, and a small set of current overview/detail/layer captures.
Record which visual decisions remain subjective and which native behaviors
were actually verified.

The next agent should be able to identify what each room is for, where its
geometry is authored, what should happen when it runs, and how to recognize
success. Complete the
[validation and acceptance workflow](map-authoring-validation-and-acceptance.md)
before reporting the new map as finished.
