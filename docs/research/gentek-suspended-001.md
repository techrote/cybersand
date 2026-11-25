---
retrieval: explicit-only
title: Suspended Arcology classic Gentek showcase
status: Current
document-kind: research
scope: Isolated Draft/HOLD Suspended Arcology v1 geometry, existing controls and exact-source qualification; owner acceptance remains open
canonical-for: [gentek-suspended-showcase-experiment]
last-reviewed: 2026-11-16
related-documents: [../systems/architectural-generator.md, gentek-classic-001.md]
---

# Suspended Arcology — GENTEK-SHOWCASE-SUSPENDED-001

This branch adds `suspended_arcology` version **1** and the **Suspended Arcology** preset through the
existing GEN-007 schema-4 Architectural Generator. Its exact parent is
`615828b28337f85e4663e03ba479616db4ddf764`, PR #624. Keep the stacked PR
**Draft / HOLD**. No merge or Ready promotion is authorized.

## Architectural programme

A six-panel, seven-floor supercell begins with a deep carrier: paired heavy chords, vertical nodes and alternating diagonal webs. A bounded seeded district programme supplies five private families: stepped habitat, multi-level habitat, open braced chamber, shallow open gallery and narrow service strip. One broad service core and its occupied neighbour share a gallery bridge. Every occupied district has two hanger roots, while a guaranteed empty panel has none. Upper plant structures remain secondary and the lowest quarter stays empty.

The source is `native/src/generation_suspended_arcology.inc`. Its sampler uses only
bounded integer arithmetic and immutable parameters. It has no heap allocation,
search, neighbour reads or mutable cache. Supercells use absolute signed world
coordinates; clipping the module bounds does not move the architecture.
The original 72 CLASSIC samplers and accepted Viaduct v1/v2 stay unchanged.

The corpus study used the existing immutable `ArchitectureForm` contract,
material roles and signed floor/modulo helpers. Its comparative controls are
Suspended Deck, Cable Gallery, Yoke Bridge and Space Frame.
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
style file is `examples/worldgen/architectural/suspended-arcology.style.json`.
Both room and floor must be at least **32 cells**. Invalid smaller dimensions
are refused in the project compiler and native sampler with a clear reason.

## Native qualification and reproduction

```sh
make -j2 worldgen-test suspended-test CXX=g++
python3 tools/architecture/qualify_suspended.py --compiler g++ --output build/suspended-qualification
python3 tools/architecture/render_suspended_arcology.py --compiler g++ --require-clean-source --output build/suspended-arcology-gallery
```

The full existing native generation suite remains intact and its catalogue
uniqueness gate grows from **72 to 73**. Focused native checks exercise **32
consecutive seeds**, schema/version refusal, negative and distant signed
coordinates, changed chunk sizes, reverse request order, zero-budget/sliced
jobs, concurrent requests, cancellation and real control effects. Black-box
flood fills inspect actual emitted material cells, not a second geometry
implementation. They require every structural cell, hanger, crown and bridge to reach the carrier, continuous carrier chords, two or more occupied districts, at least one empty slot, heterogeneous silhouettes and a completely clear lower quarter.

The qualifier independently extracts and compiles the exact parent, then compares
**74 versioned cases × 3 configurations × 4 chunks**: all 72 original CLASSIC
samplers and both accepted Viaduct versions. The retained comparison covers
**3,637,248 material cells**, native fingerprints and chunk receipts. Input
ledgers and HEAD are checked before and after the complete qualification.
Timing uses seven measured warm trials after one warm-up, rotating module order,
at both 512² and 1024²; results include the native chunk allocation/hash cost.

The renderer produces 62 original native PNGs: four hero extents, eight named seed
variants, ten controls, a negative-origin case, four comparative styles,
three original-pixel detail crops, and every seed 0–31. Labelled hero,
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

A common lower gallery datum allows one sparse bridge with known occupied endpoints, while roof depth varies the hanging silhouette. At least one panel remains empty. Absolute supercells keep carrier and hanger phase stable across chunk boundaries and signed crop origins.

These are geometric support relationships, not structural-engineering or
simulation-stability claims. PNGs are exact native material previews, not
framebuffer screenshots or physical Windows acceptance. Native rectangular
capture extents are supported; the ordinary project extent controls remain
unchanged. Style/map boundaries can clip the architecture, and existing shaft,
mask or deterioration controls can intentionally cut its supports. The finite
seed survey does not prove every possible 64-bit seed or parameter combination.
Owner aesthetic acceptance and any later merge/integration remain separate.
