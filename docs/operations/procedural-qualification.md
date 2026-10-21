---
title: Procedural Deepworks qualification and visual review
status: Current
document-kind: guide
scope: GEN-007 compact 1024-square recipe, reusable architecture, final-material routes, native exhibit mechanisms and actual rendered qualification
canonical-for: [procedural-qualification-scene, procedural-quality-evidence]
keywords: [GEN-007, Deepworks, procedural qualification, 1024, regions, galleries, exhibits, seeds, visual review]
last-reviewed: 2026-10-21
related-documents: [../systems/generation-workbench-2.md, ../systems/procedural-semantic-planes.md, ../systems/procedural-hierarchical-generation.md, ../systems/building-material-catalogue.md, deepworks-exhibition.md, semantic-depth-authoring.md, local-build-and-validation.md, ../audits/2026-10-21-gen007-workbench-qualification.md]
---

# Procedural Deepworks qualification and visual review

## What is being qualified?

**Current implementation candidate:**
[gen007-deepworks.json](../../examples/worldgen/gen007-deepworks.json) describes
one 1024 × 1024 total map, projected into play, scripted/rear, effects/atmosphere
and frozen background/far. Its native hierarchy owns the districts, galleries,
apparatus and architectural details. Reusable rules and plane templates expand
that hierarchy. No authored bitmap or per-material-cell listing supplies the map.

The [qualification viewer](../../godot/scripts/worldgen_qualification.gd) uses the
existing semantic-plane runtime and material compositor. Launch it directly:

```sh
godot --path godot res://gen007_qualification.tscn
```

The Workbench 2 graph/tools page can load the same recipe for editing. Its
generation preview and the material-rendered scene are distinct views of the
same native proposal. The viewer starts from a complete validated bundle; sources
and reactions are independently owned by the established dynamic-plane clocks.

The [acceptance ledger](../audits/2026-10-21-gen007-workbench-qualification.md)
records actual measured counts, all declared seeds, source/runtime identities,
timings, memory, retained captures and unresolved requirements. Availability of
the recipe or a passing structural count is not visual acceptance.

## How is deliberate composition kept procedural?

Author the major district silhouettes and routes first, then reuse gallery,
cabinet and apparatus rules inside those places. Named features and stable IDs
make the composition inspectable. Candidate layouts and seeded details supply
variation while structural material roles and passage clearance remain explicit.
Keep the reference seed and all variant seeds declared in the fixture.

Material choices follow the [MAT-002 catalogue](../systems/building-material-catalogue.md):
stable structural walls and containment, local metal/glass/service accents,
bounded reactive contents and thematic background treatment. A random palette
swap does not establish coherent regional identity. Empty air, sightlines and
rear windows are intentional composition choices; four-plane treatment does not
mean every cell must be nonempty.

The recipe report must retain its UTF-8 byte size, reusable rule/template counts,
expanded feature counts and manually fixed placements. Authored region bounds,
routes and shared apparatus proportions are legitimate declarative design;
listing every output material cell is not. Inspect the hierarchy/plane rules in
the workbench to determine which choices are fixed and which depend on seed.

## How are routes checked after all material decisions?

The structural table in issue #193 requires one primary route reaching all major
regions, two optional loops and secondary passages. The qualification oracle
must sample the **final projected play material**, after all plane projections
and final hard overrides. A semantic route record alone cannot prove clearance.

The scene's independent clearance check uses a declared finite footprint and
connected walkable centers. It checks region/gallery reachability and optional
loop paths in that raster. A deliberate blocking hard override is a negative
control. The graph describes a floating clearance profile; it does not certify
that a particular walking, flying or articulated actor can traverse the map.
Actor/controller acceptance remains separately scoped.

Whole-map and tiled generation must agree on every material plane and the union
of canonical fixture/link/actor registrations. Alternate request order, slice
budget and independently configured owners may not change those records. Keep
the tested source/seed/bounds and exact comparison scope in the evidence. Native
worker comparisons qualify scheduling independently of a Godot UI preview.

## How do the paired native exhibits prove their mechanisms?

Each major region contains a corresponding play/rear apparatus. The feed
fixtures provide ordinary native reagents; expected-product metadata is never
used as painting instructions. Run all eight plane-specific setups and record
each helper's completion, actual applications, transport and produced material.

The declared recipe pairs Salt/Water, Snow/Fire, Clay/Lava and Lava/Water roles.
Each mechanism must be checked against its actual native rule and observed
output. An authored expected product is a hypothesis until the executed check
confirms it. Missing-reagent and disabled/no-op helper controls must invalidate
the mechanism receipt. A helper abort or script error invalidates the run even
when the process exits zero or other sections report passing assertions.

Rear-only execution must leave play and frozen far data unchanged; effects have
their own owner and clock. Complete fixture application accounting prevents an
unvisited or silently aborted setup from being labelled passed. Finite feeds
expire, and explicit reset creates new Worlds and fresh lifecycle identities.

## What graphical evidence is required?

Use a display-backed Godot compatibility renderer. Linux Xvfb plus Mesa is a
valid software-rendered execution environment when named as such. Headless
no-frame shortcuts do not satisfy graphical acceptance. New required tests use
the `_render.gd` suffix so the existing regression dispatcher supplies a display.

Retain the full composition, each isolated plane, semantic route/socket overlay,
chunk-boundary and theme-transition crops, close-ups and all seed comparisons.
Captures must identify the exact source commit/tree, recipe bytes and hash,
native runtime hash, Godot version, renderer/environment and image hashes.
Post-tick captures additionally identify the clock/tick/fixture state.

Inspect these images against the actual
[Deepworks atlas](../images/deepworks/deepworks-atlas.png), its retained detail
captures and [exhibition guide](deepworks-exhibition.md). Record the visual
judgment separately for composition, regional coherence, route readability,
layer correspondence, detail density, material roles and visible seams.
Passing feature counts is not evidence of equal polish. A deficient pass requires
an explicit fix and a fresh capture, or an honest open gate.

## How are cost and performance claims reported?

GEN-007's bounded candidate indices accelerate sampling by identifying nearby
grammar features, routes and projections. They preserve canonical record order
and still use the original geometry/mask tests. Index creation is charged to
preparation work and memory. Conservative logical charges remain explicit and
must fit declared recipe limits; the indices do not authorize unbounded output.

Report actual local generation, validation and preview durations separately from
logical units. Include compiler/runtime, OS/CPU, renderer, resolution, seed,
worker/slice settings and peak-memory measurement method. A charged-operation
heatmap is an estimate; a measured-chunk-time heatmap is local timing at chunk
resolution. Neither establishes target-PC performance or per-cell timing.

The final completion gate also needs source-matched Linux/Windows runtime
publication and all applicable exact-head Documentation, Native, Godot and
scoped apparatus checks. See the
[repository acceptance policy](github-development-and-release.md#current-ci-provider-and-draft-gating).
The visual review, platform execution and issue closure remain distinct claims.
