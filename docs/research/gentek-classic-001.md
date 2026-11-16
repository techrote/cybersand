---
title: GENTEK-CLASSIC-001 compact architectural sampler batch
status: Draft
document-kind: research
scope: Seventy-two compact schema-4 native Genteks using the existing Architectural Generator pipeline
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
| Fan Truss | `fan_truss` | Central high node with fan braces to a lower deck |
| Pratt Truss | `pratt_truss` | Twin chords, posts and alternating inward diagonals |
| Vierendeel Frame | `vierendeel_frame` | Heavy rectangular bays without diagonal bracing |
| Suspension Pylon | `suspension_pylon` | Paired pylons, low deck and sloping carrier stays |
| Harp Bridge | `harp_bridge` | Single mast with straight harp stays to the deck |
| Double Cantilever | `double_cantilever` | Twin piers carrying three inward shelf levels |
| Stepped Buttress | `stepped_buttress` | Edge masses step inward as they rise |
| Colonnade | `colonnade` | Entablature over dense slender columns and plinth |
| Basilica | `basilica` | Tall nave roof with lower side aisles and columns |
| Crenellated Bridge | `crenellated_bridge` | High deck with merlons and deep supporting piers |
| Pointed Arcade | `pointed_arcade` | Gothic pointed openings under a continuous deck |
| Inverted Arch | `inverted_arch` | Hanging quadratic rib below an upper carrier deck |
| Hourglass Pier | `hourglass_pier` | Central support flaring at top and bottom |
| Tripod Frame | `tripod_frame` | Three splayed legs converging below a crown deck |
| Chevron Hall | `chevron_hall` | Peaked roof over sparse load-bearing side columns |
| Hanging Arcade | `hanging_arcade` | Shallow hanging arches descending from a top deck |
| Shelf Stack | `shelf_stack` | Central spine with alternating shelf widths |
| Staggered Balcony | `staggered_balcony` | Alternating side balconies between edge towers |
| Monopod Tower | `monopod_tower` | Central mast with periodic diamond observation pods |
| Wedge Gallery | `wedge_gallery` | Paired sloping shelves forming an asymmetric passage |
| Crown Bridge | `crown_bridge` | Triangular crown ribs above a heavy mid-level deck |
| Zigzag Pier | `zigzag_pier` | Single load path switching left/right by vertical quarter |
| Drum Vault | `drum_vault` | Rounded barrel shell with straight side walls |
| Pyramidal Frame | `pyramidal_frame` | Triangular outer frame with internal horizontal ties |
| Warren Truss | `warren_truss` | Triangular diagonals repeat between two long chords |
| Kingpost Frame | `kingpost_frame` | Central post with two rafters forming a triangular frame |
| Queenpost Frame | `queenpost_frame` | Paired posts support a tie and sloping outer rafters |
| Lenticular Bridge | `lenticular_bridge` | Upper and lower quadratic chords form a lens |
| Radial Stay Bridge | `radial_stay_bridge` | Central hub radiates stays to both sides of a deck |
| Twin Mast Bridge | `twin_mast_bridge` | Paired masts and crossed stays frame the central span |
| A-Frame Hall | `a_frame_hall` | Steep A-frame roof continues into side supports |
| Butterfly Hall | `butterfly_hall` | Inverted-V roof drains toward the centre |
| Ziggurat Arcade | `ziggurat_arcade` | Stepped outer mass contains a tall central slot |
| Corbel Arcade | `corbel_arcade` | Opening narrows upward in discrete corbel steps |
| Chain Vault | `chain_vault` | Alternating hanging curves form a chain-like roof |
| Ring Pier | `ring_pier` | Thick diamond-ring support around an empty core |
| Folded Plate Hall | `folded_plate_hall` | Continuous folded roof alternates high and low ridges |
| Space Frame | `space_frame` | Twin chords linked by dense alternating X members |
| Crossbeam Stack | `crossbeam_stack` | Central spine carrying four alternating long crossbeams |
| Yoke Bridge | `yoke_bridge` | Paired piers support a high yoke and lower deck |
| Lantern Tower | `lantern_tower` | Narrow shaft expands into a glazed upper lantern |
| Spine Arcade | `spine_arcade` | Central spine sprouts alternating half-arches |
| Cascade Terrace | `cascade_terrace` | Four offset decks cascade downward across each bay |
| Inverted Trestle | `inverted_trestle` | High carrier deck sends V-braces downward |
| Cranked Beam | `cranked_beam` | Thick beam follows a four-segment angular path |
| Barrel Arcade | `barrel_arcade` | Rounded barrel roof over repeated open wall bays |
| Buttress Crown | `buttress_crown` | Stepped outer buttresses rise into a narrow crown |
| Triptych Arcade | `triptych_arcade` | Three pointed openings of unequal widths share one bay |

All are version 1 and reuse the existing project/preset compiler, five style
cards, native preview/install and saved-start path. They do not self-assemble,
negotiate zone boundaries or inspect live World cells. Viaduct v1/v2 and the
other accepted algorithms remain unchanged.

## Independently stacked Cathedral showcase

The [Cathedral Megaframe showcase](gentek-showcase-cathedral-001.md) adds one
larger teaching sampler on its own Draft/HOLD branch, making the catalogue
**73 in that branch**. The frozen CLASSIC parent remains the 72-module batch.
Cathedral coordinates a four-bay frame, primary void, subsidiary arcades and
clerestory detail through the same schema-4 contract; it does not change any
existing module/version or grant merge authority.
