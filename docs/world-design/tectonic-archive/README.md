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
