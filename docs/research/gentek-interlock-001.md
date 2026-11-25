---
retrieval: explicit-only
title: Interlock Brutalism classic Gentek showcase
status: Current
document-kind: research
scope: Isolated Draft/HOLD Interlock Brutalism v1 geometry, existing controls and exact-source qualification; owner acceptance remains open
canonical-for: [gentek-interlock-showcase-experiment]
last-reviewed: 2026-11-16
related-documents: [../systems/architectural-generator.md, gentek-classic-001.md]
---

# Interlock Brutalism — GENTEK-SHOWCASE-INTERLOCK-001

This branch adds `interlock_brutalism` version **1** and the **Interlock Brutalism** preset through the
existing GEN-007 schema-4 Architectural Generator. Its exact parent is
`615828b28337f85e4663e03ba479616db4ddf764`, PR #624. Keep the stacked PR
**Draft / HOLD**. No merge or Ready promotion is authorized.

## Architectural programme

A broad recessed concrete core and a narrower skeletal core oppose one another across a four-bay void. Six-floor programmes group the heavy left fingers and offset right beams, reserve missing levels, and admit at most one shared bridge. Seed can reverse the asymmetry, shift the grouped cadence, adjust core mass and choose a bridge level. Root haunches and suspended returns distinguish the two structural languages. The void opens, narrows and branches as their reaches overlap at different elevations.

The source is `native/src/generation_interlock_brutalism.inc`. Its sampler uses only
bounded integer arithmetic and immutable parameters. It has no heap allocation,
search, neighbour reads or mutable cache. Supercells use absolute signed world
coordinates; clipping the module bounds does not move the architecture.
The original 72 CLASSIC samplers and accepted Viaduct v1/v2 stay unchanged.

The corpus study used the existing immutable `ArchitectureForm` contract,
material roles and signed floor/modulo helpers. Its comparative controls are
Cantilever Spine, Double Cantilever, Buttress Wall and Shelf Stack.
Their small structural vocabulary informed this new programme; no original
sampler is renamed or edited into the new form. The existing Workbench still
applies ordinary style masks, preview/install and saved project behavior.

## Existing controls

| Control | Geometric response |
| --- | --- |
| Room size | Base bay; multiplies the macro span and projection or district width |
| Floor height | Vertical cadence, separation and architectural depth |
| Wall thickness | Core, carrier, slab, frame and member mass |
| Automatic windows | Actual glass fills selected enclosed apertures; disabling preserves structural members |
| Automatic doors | Local service openings; disabling closes those openings |
| Shaft width | Existing global exclusion; disabled in the qualified hero because it can cut supports |

The built-in and standalone style both use room **80**, floor **72**, wall **3**,
door width **10**, windows/doors enabled, no shaft and no deterioration. The
style file is `examples/worldgen/architectural/interlock-brutalism.style.json`.
Both room and floor must be at least **32 cells**. Invalid smaller dimensions
are refused in the project compiler and native sampler with a clear reason.

## Native qualification and reproduction

```sh
make -j2 worldgen-test interlock-test CXX=g++
python3 tools/architecture/qualify_interlock.py --compiler g++ --output build/interlock-qualification
python3 tools/architecture/render_interlock_brutalism.py --compiler g++ --require-clean-source --output build/interlock-brutalism-gallery
```

The full existing native generation suite remains intact and its catalogue
uniqueness gate grows from **72 to 73**. Focused native checks exercise **32
consecutive seeds**, schema/version refusal, negative and distant signed
coordinates, changed chunk sizes, reverse request order, zero-budget/sliced
jobs, concurrent requests, cancellation and real control effects. Black-box
flood fills inspect actual emitted material cells, not a second geometry
implementation. They require all structural cells to reach a side core, more than half of the central region to remain empty at thin/heavy settings, no more than one narrow full bridge per supercell, and a substantial connected chamber spanning at least two floors.

The qualifier independently extracts and compiles the exact parent, then compares
**74 versioned cases × 3 configurations × 4 chunks**: all 72 original CLASSIC
samplers and both accepted Viaduct versions. The retained comparison covers
**3,637,248 material cells**, native fingerprints and chunk receipts. Input
ledgers and HEAD are checked before and after the complete qualification.
Timing uses seven measured warm trials after one warm-up, rotating module order,
at both 512² and 1024²; results include the native chunk allocation/hash cost.

The renderer produces 63 original native PNGs: four hero extents, eight named seed
variants, ten controls, a negative-origin case, four comparative styles,
four original-pixel detail crops, including an overlapping central-void sequence, and every seed 0–31. Labelled hero,
control, full-survey and matched-scale comparative sheets accompany them.
Geometry comes exclusively from the ordinary C++ Generator/chunk API. The
unchanged `BASE_RGBA8` preview palette maps those material IDs to opaque pixels.
Raw cells, recipes/configuration, per-chunk receipts, compiler/binary identity,
source-input hashes and a source archive are retained with the PNGs.

The branch-scoped workflow builds the exact Linux GDExtension with the pinned
Godot 4.7 dependencies, exercises the ordinary preset, requires **73** distinct
CLASSIC maps and checks that its showcase material SHA-256 equals the standalone
hero. Every completed pass or failure is recorded in the PR conversation and
CI artifacts; this document does not claim a future run has already passed.

## Design choices and limitations

The two sides share a single immutable programme so fingers can pass at different elevations and bridge deliberately. A full bridge partitions the 2D chamber; the connectivity gate proves a large connected open region, not a top-to-bottom player route through every bridge. One bridge per six floors preserves broad gaps and grouped levels avoid a uniform alternating shelf pattern.

These are geometric support relationships, not structural-engineering or
simulation-stability claims. PNGs are exact native material previews, not
framebuffer screenshots or physical Windows acceptance. Native rectangular
capture extents are supported; the ordinary project extent controls remain
unchanged. Style/map boundaries can clip the architecture, and existing shaft,
mask or deterioration controls can intentionally cut its supports. The finite
seed survey does not prove every possible 64-bit seed or parameter combination.
Owner aesthetic acceptance and any later merge/integration remain separate.
