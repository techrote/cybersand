---
title: Rosework Gatehouse showcase and qualification
status: Current
document-kind: runbook
scope: Isolated GENTEK-SHOWCASE-ROSEWORK-001 v1 source, controls and exact-source native evidence on its Draft branch
canonical-for: [gentek-rosework-showcase]
last-reviewed: 2026-11-16
related-documents: [../systems/architectural-generator.md, ../reference/status-and-roadmap.md]
---

# Rosework Gatehouse — Draft / HOLD

This branch adds `rosework_gatehouse` v1 and the **Rosework Gatehouse** preset to
the existing schema-4 CLASSIC path. Its base is the frozen 72-Gentek parent
`615828b28337f85e4663e03ba479616db4ddf764` in PR #624. It contains one showcase,
not the sibling experiments or a new composition engine. No merge or Ready
promotion is authorised. The live PR conversation and retained manifests own
the exact tested source and observed platform results.

## Architecture and source study

The complete 72-sampler corpus was inspected. Pointed Arcade supplies the useful
distinction between a structural opening and applied colour; Drum Vault and
Barrel Arcade demonstrate explicit soffit shells; Basilica separates a dominant
central space from lateral support. Ring Pier's diamond metric is a useful
contrast to this sampler's actual squared-distance circles. None of those
implementations is changed. Existing v1/v2 Viaduct geometry is also preserved.

[`RoseworkGatehouse`](../../native/src/generation_architecture_rosework.inc)
uses a four-bay-wide, six-floor-high supercell. Two stepped towers carry a large
radial field through short transverse ties. The bottom of its outer ring touches
the crown of the monumental lower gate. That gate stays open independently of
the optional small side portals.

Three closed bands establish the hub, main tracery ring and outer masonry ring.
A supercell hash chooses six, eight or twelve spokes and a bounded crown/glazing
programme. Integer Q10 directions define rays; a pair of intersecting circles
defines each pointed petal. Petal outlines attach to the hub and main ring.
The lenses are real native material apertures. Alternating selected interiors
receive Stained Glass when windows are enabled. Turning windows off changes
only glass to Empty; it cannot remove a spoke or ring.

All geometry is relative to the immutable module origin, with floor division
and positive modulo at supercell boundaries. Moving the whole module preserves
its local composition, including at a negative origin. Chunk request order and
work slicing do not affect any cell. Existing style-zone masks can still clip
the resulting architecture; this experiment does not negotiate zone boundaries.

## Existing controls

| Existing control | Rosework meaning |
| --- | --- |
| Room size | Base bay; four bays form the gatehouse width. It also sizes the rose, subject to vertical clearance. |
| Floor height | Tower cadence and rose elevation; six floors form a vertical repeat. Very short settings reduce rose radius to retain clearance. |
| Wall thickness | Outer masonry, ring and spoke mass; normal range remains 1–5 cells. |
| Automatic windows | Alternating petal glazing; off preserves open petals and every structural member. |
| Automatic doors | The small side-tower passages; the monumental central gate is always open. |
| Shaft width | Existing explicit central exclusion. Nonzero values intentionally cut the rose and gatehouse. |

Visible tracery requires room size at least 40 and floor height at least 32.
Smaller requests fail native admission with an actionable message. The default
is 128 / 80 / 3, Basalt Columns masonry, Brass Panel rings/decks and Stained Glass.
The standalone [style JSON](../../examples/worldgen/architectural/rosework-gatehouse.style.json)
is accepted by the ordinary Architectural Generator importer. There is no new UI.

## Native evidence and reproduction

```sh
make -j2 worldgen-test
python3 tools/architecture/qualify_rosework.py --compiler g++ --output build/rosework-qualification
python3 tools/architecture/render_rosework_gatehouse.py --compiler g++ --require-clean-source --output build/rosework-gatehouse-gallery
```

The [specific native test](../../native/tests/test_rosework_gatehouse.cpp) checks
32 seeds, closed radial bands, all three spoke programmes, ray continuity,
petal void area, eight-connected tracery, shared tower/gate roots, deterministic signed chunks, partition
and work-slice invariance, parallel requests, cancellation, controlled refusal,
parameter response and exact glazing/door toggle scope. A 256-cell chunk uses
an explicitly enlarged public work budget for the partition test; low-budget
refusal remains independently tested. Ordinary previews use 64/128-cell chunks.

The [qualification runner](../../tools/architecture/qualify_rosework.py)
independently extracts and compiles the exact parent. It compares 3,538,944 cells
from all 72 existing CLASSIC modules across three configurations, including
their native fingerprints and receipts. A separate 98,304-cell witness covers
Viaduct v1 and v2. It measures 512² and 1024² native generation against Pointed
Arcade, Drum Vault and Viaduct using rotating trial order and seven warm trials.

The [render runner](../../tools/architecture/render_rosework_gatehouse.py)
retains 23 full native material PNGs: three heroes, six seed variants, small/large
diameters, short/tall towers, thin/heavy structure, both aperture toggle states,
signed origin and three CLASSIC comparisons. Rose and gate detail crops use only
nearest-neighbour enlargement. Labelled comparison/contact sheets are separate
derived views; raw one-pixel-per-cell PNGs and material bytes remain available.

Every image comes from the ordinary C++ Generator/chunk API. The converter uses
the exact `BASE_RGBA8` palette from the existing native preview path, with no
geometry painting, bitmap stamps, AI images or shader modifications. The
manifest includes source commit/tree, all source-input hashes, compiler and
binary identity, commands, raw-cell/PNG hashes, chunk receipts and timings.
The runner refuses stale cached exporters and source changes during rendering.

The branch-scoped [Draft workflow](../../.github/workflows/gentek-rosework-draft.yml)
runs all generation gates, independent parent comparison, the complete gallery,
and a separately source-built pinned Godot 4.7 extension. Its final job requires
exact source identity and byte-identical hero materials from the ordinary preset
and standalone native campaign. It never changes #624 or publishes runtimes to
the retained application paths.

## Design choices and remaining boundaries

The rose uses circular rings and lens-shaped petals, with fixed integer direction
tables for three approved spoke orders. This provides legible radial geometry
while keeping arithmetic bounded: at most twelve spoke/lens iterations and no
heap allocation, mutable cache, neighbour search or trigonometry in `sample()`.
An arbitrary polygon/tracery editor would need a separate design and interface.

The geometry remains planar native cells and makes no structural-engineering,
physics, traversability certification or physical Windows/GPU acceptance claim.
The square preset remains the existing owner workflow; landscape outputs use
the native API's rectangular extent. Very small or heavy tracery becomes coarse
at cell scale, so the default hero deliberately retains broad radial clearance.
Owner aesthetic acceptance and integration/merge remain outstanding gates.
