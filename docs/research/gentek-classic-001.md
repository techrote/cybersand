---
title: GENTEK-CLASSIC-001 compact architectural sampler batch
status: Draft
document-kind: research
scope: Twenty-four compact schema-4 native Genteks using the existing Architectural Generator pipeline
last-reviewed: 2026-11-15
related-documents: [../systems/architectural-generator.md, ../systems/procedural-world-generation.md]
---

# GENTEK-CLASSIC-001

This Draft batch explores the existing GEN-007 module model while the separate
self-assembling Gentek programme investigates future composition. Each sampler is
kept deliberately compact in `native/src/generation_architecture_classic.inc`.

| Preset | Module | Geometry |
| --- | --- | --- |
| Steel Trestle | `trestle` | Edge posts, chords and crossed braces |
| Stacked Arcade | `stacked_arcade` | Broad lower arch under two smaller upper arches |
| Flying Buttress | `flying_buttress` | Outer piers with fan braces |
| Sawtooth Gallery | `sawtooth_gallery` | Sloped roof teeth, columns and glazing |
| Cantilever Spine | `cantilever_spine` | Seeded alternating platforms around a central mast |
| Rib Vault | `rib_vault` | Pointed ribs around vaulted negative space |
| Nested Arcade | `nested_arcade` | Large upper opening above paired lower arches |
| Suspended Deck | `suspended_deck` | Carrier deck, hangers and lower service deck |
| Bowstring Truss | `bowstring_truss` | Curved upper chord, deck and vertical hangers |
| Diamond Truss | `diamond_truss` | Central spine inside a large diamond truss |
| Portal Frame | `portal_frame` | Repeated high portal beams on paired legs |
| Ladder Bridge | `ladder_bridge` | Twin long chords connected by repeated rungs |
| Stepped Aqueduct | `stepped_aqueduct` | Narrowing terraces carried by paired piers |
| Split Pier | `split_pier` | Single pier splitting into two upper branches |
| Cable Gallery | `cable_gallery` | Parabolic carrier cable, hangers and lower deck |
| Clerestory Hall | `clerestory_hall` | Tall hall shell with high glazing and central column |
| Mushroom Deck | `mushroom_deck` | Broad deck on tapered mushroom-cap columns |
| Zigzag Bridge | `zigzag_bridge` | Folded zigzag deck with periodic vertical supports |
| Scalloped Vault | `scalloped_vault` | Three small vault lobes within each bay |
| Lattice Tower | `lattice_tower` | Narrow tower frame with floors and crossed braces |
| Offset Arcade | `offset_arcade` | Arch centres alternate left/right by level |
| Bridgehouse | `bridgehouse` | Mid-level bridge carrying repeated gabled rooms |
| Forked Gantry | `forked_gantry` | Central lower stem forks beneath the upper deck |
| Buttress Wall | `buttress_wall` | Heavy wall piers with deep buttresses and light slot |

All are version 1 and reuse the existing project/preset compiler, five style
cards, native preview/install and saved-start path. They do not self-assemble,
negotiate zone boundaries or inspect live World cells. Viaduct v1/v2 and the
other accepted algorithms remain unchanged.
