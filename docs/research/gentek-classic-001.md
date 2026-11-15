---
title: GENTEK-CLASSIC-001 compact architectural sampler batch
status: Draft
document-kind: research
scope: Eight compact schema-4 native Genteks using the existing Architectural Generator pipeline
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

All are version 1 and reuse the existing project/preset compiler, five style
cards, native preview/install and saved-start path. They do not self-assemble,
negotiate zone boundaries or inspect live World cells. Viaduct v1/v2 and the
other accepted algorithms remain unchanged.
