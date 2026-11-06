# Tectonic Archive — Archive of the Split Mountain

**World-design collection 013 · 2026-11-05 · DRAFT, design resources only.** Not a native map, valid CYSD world, imported editor resource, simulation fixture, screenshot or proven player traversal.

This is a subterranean library *formed from geological strata*: sedimentary books folded into anticlines, trilobite spine seals, geological core records, sheared basalt manuscript cliffs and open lithic reading terraces. No motors, power lines, clockwork, memorial tombs or observable astronomical instruments. It intentionally differs from earlier cavern, industrial, memorial and astronomical collections.

**Source custody:** `main` ba9cbc89029be88b812af59b19e5c59829bbcd90; tree 3af18f50e6094776263119623b64a1b2f4ca0ab2; native material header blob `dcf05895da3015a2e999e3d1cbbae0fdc7fe32b3`; shadow candidate catalogue blob `d7a47d60721598a16589daf177a6ff4401b84b43`. The authoritative runtime semantics remain `native/include/cybersand/material.hpp`; the JSON catalogue is shadow metadata and is not made authoritative by this design pack. Rectangles follow `godot/scripts/demo_worlds.gd::_rect` arguments.

## Modules

| ID | Local dimensions | Classification | Intent |
| --- | ---: | --- | --- |
| `fault-index-portal` | 138×122 | inert-static | Two displaced stratigraphic piers create a readable central crack and keyed entrance |
| `anticline-codex` | 146×100 | inert-static | Layered inverted-V anticline like a fan of open volumes |
| `trilobite-seal` | 122×104 | inert-static | Limestone relief medallion with a radial fossil spine and trilobite ribs |
| `core-logger` | 112×130 | inert-static | Tall laboratory core column with segmented colour-coded drilling records |
| `basalt-accordion` | 140×112 | inert-static | Repeated buckled basalt columns crossed by a diagonal quartz shear seam |
| `scriptorium-steps` | 150×96 | inert-static | Three low staggered platforms holding engraved lithic folios |
| `talus-catalogue` | 132×108 | dynamic-powder | Loose sediment inventory descending a stepped stone sorting slope |
| `aquifer-palimpsest` | 134×102 | dynamic-liquid-powder | Recessed geological language plates with a symbolic blue seep line |

**474 ordered native-cell rectangles; 25 source-matched material IDs; 16 named variants; three reusable assembly patterns; one 1360×316 dry composite.** See [preview.svg](preview.svg) for source-colour art (not native display). See [pack.json](pack.json) for each exact rectangle, ordering, placement and anchor.

## Design style and composition

Use an alternating **high/low/circular/vertical** silhouette grammar: split fault opening → folded low anticline → rounded fossil seal → tall core logger → accordion cliff → horizontal reading terrace. The final talus and aquifer pieces are clearly separated *experiments*, replacing mobile material in any default composition. Keep 20–28 cells between module bounding rectangles. Contrast charcoal BasaltColumns **100**, Slate **49**, Obsidian **101** and GraniteBlock **40** with LimestoneBlock **38**, SandstoneBlock **39**, Marble **98**, ChalkBlock **99**, RammedEarth **109**, Terrazzo **111** and small BrassPanel **119** / QuartzCrystal **122** glyphs. This distribution is a style target, not an area histogram.

Repeating patterns `strata-gateway`, `fossil-reading-hall`, and `unbound-appendix` are defined in the JSON as ordered feature sequences and bounded gaps. Alter narrative scale by choosing a single tallest piece per three-piece group; use a low terrace or circular seal as negative-space reset. One-axis unscaled, 0-degree orientations only; do not rotate/flip/rescale without new bounds and collision review. Every module has two explicit controlled palette variants with source IDs. No alpha layering, erase masks, stencil layers, cinematic lights, 3D depth, or physics constraints are implied by SVG paint order.

## Refined flagship — the fractured index vault (6 November 2026)

The **stratigraphic vault** is now an integrated dry staged environment. An asymmetric overhanging left mountain archive and a slumped eastern cliff terminate at an unfilled central shear. Two interrupted stone archivolts stop at the chasm. Limestone, granite, basalt, slate, sandstone and rammed-earth laminae suggest successive deposits; a fossil outcrop, embedded archive ledgers, worn lithic marks and detached manuscript shards supply narrative close-detail without covering every cavity. Two foundations join the eight existing modules but stop at the central fracture.

**Representation:** `combined_scene.backdrop_rectangles` is stamped **before** the eight original placements and `combined_scene.foreground_rectangles` **after** them, using later-rectangle-overwrites-earlier semantics. These are ordered fixed source-cell stamps, **not** native render layers, erase operations, collision fixtures or a new importer. All new stamps use existing nonmoving, kernel-zero materials in the source-verified palette. The 1360×316 composition adds **756 backdrop** and **498 foreground** rectangles. All 474 original module rectangles, eight modules, 16 variants and three assembly patterns remain unchanged.

`preview.svg` provides two deterministic source-colour approximately 2× detail crops. Flat SVG is **not Godot/native output**; the void assumes a pre-cleared host and cannot clear terrain. The dynamic Stone/Dust and Water/Salt originals remain unqualified, as do traversal, lighting, performance, physical stability and source-renderer fidelity. Next: compose an alternate arrangement with the same modules, and seek genuine source-matched Godot captures plus independent same-scale human comparison against all five gallery references.

## Placement contract

A `rectangles` entry is `[x,y,width,height,material_id]` in **integer native cells**. Origin is top-left, +x right, +y down, bounds half-open. **Later entries overwrite earlier material**; replace source IDs after selecting the variant, before stamping. Bottom-centre `anchor.point` is calculated from width and height, and `combined_scene.placements[].origin` gives exact scene offsets. Combined baseline is **y=282**. The preview background is never stamped. Neither holes nor missing rectangles clear any host terrain; future importers require explicit authority for carving, overlap handling, rollback and source-pinned material IDs.

**Specific neighbour rules:** Keep 20–28-cell gaps; avoid putting two dominant cliffs together; keep core logger separate from fault index opening; place active sediment or aquifer variants only in physically isolated scratch fixtures. Default scene builds `talus-catalogue/lithified-slide` and `aquifer-palimpsest/entombed-aquifer`, preserving a motionless visual cross-section. No accepted map/player route exists yet.

## Material behaviour and test admission

| Construction | Native/source classification | Risk and necessary later qualification |
| --- | --- | --- |
| First six originals | All rectangles source nonmoving and kernel 0 | **Static *candidates***; geometric arches, thin bands, unsupported visual rods, world-edge collision and actor clearance are not proven |
| `talus-catalogue` original | Stone **13** + Dust **14** are gravity powders, moving under active kernels | Sediment rolls, settles and alters art; t=0/60/600 fixture with quantity, bounds, motion and CPU evidence needed |
| `aquifer-palimpsest` original | Water **3** has FreeMass flow; Salt **23** is movable powder | Fluid migration, sediment contact, dissolved/thermal side effects and shell containment not proven; native test needed |
| Combined dry scene | Stone **13**→GraniteBlock **40**; Dust **14**→ChalkBlock **99**; Water **3**→GlassBlock **120**; Salt **23**→RockSaltBlock **106** | Material metadata says nonmoving/kernel-zero after substitution, but native stepping, Godot rendering, world ownership, collision and performance are **not** tested |

No mechanism is claimed for geological folding, fossil production, mineral lighting, real glass optical effects, aquifer pressure, water-tightness, or falling debris containment. No native physics or player/Rapier outcomes are inferred from a source-colour SVG. A dense 1360-cell wide stamp is a substantial authoring-scale layout, not a frame-time measurement.

## Reproduction and integration conditions

From a complete checkout at the pinned source:

```sh
node docs/world-design/tectonic-archive/validate_pack.mjs --negative --source
node docs/world-design/tectonic-archive/render_pack.mjs --check
node docs/world-design/tectonic-archive/render_pack.mjs --write
```

The generated source-colour SVG and structural/source checks were evaluated during design authoring; **execution of these checked-in scripts from an actual cloned checkout, native ticks, Godot rendering and hosted CI were not performed**. Before integration, independently review a versioned map/editor resource schema, source identity and host erase permissions; load/clear/undo behavior; actor/player clearance; native-tick exact-head settlement or fluid tests for originals; and performance. Do not couple this to PLAY, SOL, MAT-AUTH, IN-TOOLS or solver work.

**Other design collections inspected:** #408, #410, #412, #414, #420, #425, #430, #434, #437, #439, #443, #445. Next possible themes: Coral Telegraph (marine cable/analogue communication relics), Fallow Carnival (windswept suspended fairground skeletons) and Saltwind Viaduct (evaporite rail crossings).

## Alternate diorama — The Synclinal Rebinding (6 November 2026)

The original Split-Mountain flagship is retained, alongside a distinct **1360×420-cell two-level** dry lithic library. Four upper modules stand on interrupted colonnades, and four original modules occupy lower reading halls beneath a monumental **severed synclinal manuscript** and an unfilled central index shaft. Asymmetric fossil folio-ribs, a hanging engraved spine, ruined ledger crossings, folded writing walls, stratified overburden, chipped buttresses and tiny brass indexing marks make this a separately authored architectural narrative.

The `alternate_scene` adds **923 fixed backdrop rectangles** and **138 fixed foreground rectangles**, preserving all eight original modules, their 16 variants, three reusable combination patterns, primary flagship placements and source material palette. Upper baseline is y=187, lower y=375. Dry variants of the original talus and aquifer are used. The deterministic SVG displays both panoramas, all eight module studies and two close-detail crops of each diorama. The empty shaft cannot erase host terrain, and apparent hanging spans do not assert real collision or structural stability.

Full-checkout commands: `node docs/world-design/tectonic-archive/validate_pack.mjs --negative --source`; `node docs/world-design/tectonic-archive/render_pack.mjs --check`. Source-colour SVG is not Godot output. Native runtime, dynamic settling/seepage, actor clearance, stability, performance and independent all-five-gallery comparison remain untested.

## C11 visual refinement — Hinged Folios over the Synclinal Rebinding (6 November 2026)

The alternate dry 1360×420 *Synclinal Rebinding* now reads as a broken geological library rather than two detached registers. Opposed, sloping stratigraphic folio-roofs descend towards the central shear, leaving the interruption and dark shaft legible. Paired cracked bearing seats and offset lithic columns visually tether the unfinished central archivolt to lower reading courts; broken page terraces, separated cataloguing niches, inscribed ledger slats and sparse quartz/chalk edge wear provide meso- and close-detail. The outer modules and lower fissure retain clear separation. This is a **design illustration of rock and masonry**, not a real structural, geological or physical-load simulation.

The change adds **427** ordered fixed-material backdrop stamps and **738** controlled foreground detail stamps to the alternate, preserving all original eight module geometries, their sixteen variants, three patterns, first flagship composition, eight alternate placements and dry material substitutions. The final alternative source-colour raster differs in **31,321 / 571,200** native cells, retains **60.48% unwritten background** and contains **zero** moving/kernel-active final scene cells. The background never requests host terrain erasure. Palette entries use the pinned material enum and shadow catalogue; textural lines are source-colour stamps, not lighting, translucency, mechanical access or real shader effects.

**Qualification at this checkpoint:** the exact checked-in renderer code, evaluated as a JavaScript function in a connector V8 runtime with Node-only I/O shims removed, reproduced both old and revised previews **byte-for-byte**; the checked-in validator function passed and rejected **24/24** negative mutations. The Git source material header and catalogue blobs matched their pinned SHAs, and all 25 palette entries matched native enum names and shadow material metadata. A 680×210 nearest-sampled source-RGBA image was reconstructed and visually inspected; its V-shaped silhouette is stronger but the outer horizontal foundations and strong diagonal ribs still require further deliberate variation. This is **not** Node CLI subprocess qualification: no local checkout was available (GitHub DNS lookup failure, `git ls-remote` exit 128). It is also **not** a Godot render, native test, terrain carving, clearance, Water/Salt validation, performance assessment or independent reference-gallery acceptance. The five benchmark PNGs were not available to the local visual check.

**Next:** verify `node docs/world-design/tectonic-archive/validate_pack.mjs --negative --source` and `node docs/world-design/tectonic-archive/render_pack.mjs --check` with real subprocess exits on a complete checkout, then compare both full-size and detail crops against engine captures and the five actual gallery images. Artistically refine and interrupt the long lower parapets before further micro-detail additions.

## Worker C — The Four Unshelved Undercrypts (6 November 2026)

The lower foundation of the Synclinal Rebinding alternate is no longer two uninterrupted, mechanically repeated geological ledgers. Four stepped, asymmetrical, **genuinely unwritten** excavations now expose a crushed stone-folio press and lost slips; a broken fossil audit relief; three incomplete stratigraphic core registers; and an erased colophon wall with fallen inscription plates. Irregular bearing piers and shoulder courses connect to the upper library modules while the central split remains unbridged. The excavation works by **resectioning existing fixed rectangles** rather than painting black rectangles; it makes no request to clear host terrain.

The update preserves all **eight modules, sixteen variants, three assembly patterns, both existing placement sequences, the first flagship and dry substitutions**. The source-colour alternate changes **26,302** final cells; **15,087** previously painted cells become unwritten, and **66** blank cells gain authored fixed-material work. The lower floor y≥375 accounts for **26,302** changed cells. The deterministic SVG retains the earlier atlas, original module cards and detail crops, adding two enlarged undercroft studies.

**Qualification limits:** Checked-in JavaScript validator/renderer function bodies executed in a connector V8 runtime; geometry and inactive-material checks passed; **24/24** checked-in invalid-data mutations were rejected; all 25 palette records matched pinned native enum and shadow metadata. The original preview was independently regenerated to its exact Git blob SHA. The revised SVG is a deterministic **source-colour illustration**, not a real Godot capture. Full-checkout Node subprocess exit codes remain unavailable because local GitHub DNS lookup failed (git ls-remote exit 128); real native physics, structural stability, actor clearance, rendering, performance and all-five-gallery independent human acceptance are untested. **Next:** execute the full Node source/negative validator and render --check, then obtain matched-scale Godot captures before more ornamental embellishment.


## Four Interleaved Unconformities — original flagship roof vaults (6 November 2026)

The original Split-Mountain panorama now contains four **genuinely unstamped stepped excavations**, distinct from the lower undercrypts of the alternate. They comprise a fossilised palaeochannel and trilobite ledger; an interrupted tilted folio index; six dislocated sediment cores; and a fractured lithic-leaf audit court. Broken supports, surviving bearing masonry, unequal cap-rock sediment bands, quartz samples and sparing accession marks give the mountain shoulders their own readable geological archival history rather than unrelated surface ornament.

**Construction:** 20 intentional geometric cuts resect original fixed backdrop/foreground rectangles, then 399 controlled fixed native-material details create structural and specimen-specific narratives. Final native-cell comparison changes **39,493 / 429,760** pixels, opens **30,444** previously painted cells into genuine unwritten background and paints **898** previously unwritten cells. Neither SVG darkness nor unstamped areas clear host terrain. All eight original modules, 16 variants, three patterns, first flagship placements, alternate placements and alternate scene remain preserved.

**Evidence:** exact checked-in JavaScript validator function in isolated V8 accepted revised geometry, rejected **24/24** bad mutations, and all 25 palette entries matched pinned source enum/catalogue. Checked-in renderer function generated the old SVG matching its Git blob SHA and generated the new deterministic preview, with exact serialized re-render match. This is **not** local Node subprocess qualification: the Linux `git ls-remote` network call failed DNS (exit 128); `node docs/world-design/tectonic-archive/validate_pack.mjs --negative --source` and `node docs/world-design/tectonic-archive/render_pack.mjs --check` were not run as local CLI commands. Native Godot render, host clearing, actor clearance, load stability, dynamic liquid/sediment, performance and independent five-gallery human acceptance remain untested. Next obtain source-matched engine captures and same-scale close crops, then refine only demonstrable legibility deficiencies.

## The Unbound Aeon Gate — opposed palaeographic strata (6 November 2026)

The existing 1360×316 *Split-Mountain* flagship now uses its open upper central fault as an architectural event. Opposing **geological folio fans** extend from unequal mountain shoulders: ten western sediment leaves and nine eastern strata contain deliberately broken bed joints, offset fossil accession windows and separate core-index records. Misaligned quartz samples, snapped short ledger strips and unequal masonry bearing piers imply a failed effort to reconcile geological eras. The central seam remains unstamped, not painted dark; the earlier undercrypts and peripheral mountain archive remain. Apparent cantilevers do not establish load-bearing stability.

**Geometry:** 251 source-fixed native-material rectangles, grouped within one flagship intervention. Ordered material-ID comparison changes **18,070 / 429,760** cells, including 17,946 above y=158 and 18,061 within x520–874/y34–174; 14,614 formerly unstamped cells gain material, **0** painted cells cleared, and **57.85%** of the panorama remains unstamped. These are geometric measurements, not quality scores. First deterministic source-colour close study now shows the fault-facing folios. All eight original modules, sixteen variants, three patterns, eight original placements, eight alternate placements and complete alternate remain unchanged.

**Qualification:** The checked-in validator and SVG generator function bodies executed in connected V8: 24/24 existing and 3/3 additional negative mutations rejected, all 25 palette entries verified against native enum/pinned shadow catalogue, and revised SVG was reproduced exactly. The previous deterministic SVG's Git blob SHA was independently verified before this change. These are **not** local Node CLI exit receipts (GitHub DNS failure: `git ls-remote` exit **128**), Godot/native rendering, Water/Salt behavior, host-terrain clearing, geological stability, actor traversal, performance or human five-gallery comparison. Full-checkout checks: `node docs/world-design/tectonic-archive/validate_pack.mjs --negative --source`; `node docs/world-design/tectonic-archive/render_pack.mjs --check`. Next obtain equivalent-scale genuine Godot captures and assess central seam legibility.
