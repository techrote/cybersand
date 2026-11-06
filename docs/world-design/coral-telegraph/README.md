# Coral Telegraph — The Silent Cable Transept

**CyberSand world-design collection 014 · 2026-11-05 · design-only draft.** Proposed marine analogue-telegraph archaeology. Not a native scene, player-approved level, editor resource or simulation fixture.

A submerged network of basalt exchange stations, ceramic repeater fans, suspended cable loops, bronze listening bells, exposed conductor strata and artificial coral antennas. The structures look like a once-functional communications system; **no electricity, signalling, sound, pressure, buoyancy or actual coral growth is implemented**. This collection is architecturally distinct from the sunward mechanical trees of Signal Orchard, the astronomical Drowned Observatory and the industrial Ironroot Necropolis.

## Eight modules

| Feature | Cell size | Physical class | Purpose |
| --- | ---: | --- | --- |
| `landing-relay` | 150×130 | inert-static | Two-chamber landing-house, cable spur and faded optical register |
| `repeater-fan` | 132×128 | inert-static | Seven diverging ceramic-terminated conductors |
| `loop-reef` | 150×98 | inert-static | Three conductor arcs spanning paired mineral reefs |
| `bell-terminus` | 126×138 | inert-static | Bronze listening bell and segmented acoustic register |
| `fossil-cable-bed` | 148×94 | inert-static | A conductor cutaway in pale folded geological strata |
| `brass-polyp` | 132×128 | inert-static | Engineered branching conductor grown in silhouette, not biology |
| `tidal-checksum` | 148×112 | dynamic-liquid | Paired analytical basins with distinct Water and Brine grids |
| `sediment-semaphore` | 144×112 | dynamic-powder | Stepped separation trays carrying loose sand and salt signal codes |

**1424 ordered material rectangles, 25 source-verified materials, 16 variants and three repeatable assembly patterns; 1370×324 dry combined scene.** Preview: [preview.svg](preview.svg) (source-colour vector art only; not a Godot/physics screenshot). Each feature has two palette variants, exact bounds, a ground anchor, clearance notes and per-module risk notes in [pack.json](pack.json).

## Style and composition

Silhouettes progress from tall monolith → branching ceramic mast → low hanging cable choir → rounded bell → horizontal mineral cutaway → branching polyp → analytical pools → descending classifier. Use BasaltColumns `100`, Obsidian `101`, Slate `49` for dark silhouette, LimestoneBlock `38`, SandstoneBlock `39`, GraniteBlock `40`, RockSaltBlock `106` for stratigraphy, VerdigrisCopper `54`, CopperPipe `69`, BrassPanel `119`, CeramicTile `70`, CableBundle `74` and QuartzCrystal `122` for devices. Tiny NeonCyan `77` elements are **coloured materials**, not an assurance of luminous effects.

Baseline **Y=290** in the combined **1370×324** environment. Left-to-right exact origins are in `combined_scene.placements`; gaps are approximately **20–30 cells**. Only 0° orientation and native 1× scale have authored geometry. Three patterns in the JSON:
- `seafloor-splice`: landing relay → looping reef → buried conductor
- `relay-garden`: ceramic mast → artificial coral → listening bell
- `salinity-protocol`: sealed dry cells → petrified classifier → geological substrate

Keep the largest mast/bell from dominating the same immediate region; alternate silhouette heights and preserve negative space.

## Coordinates and layering

Every rectangle is `[x, y, width, height, material_id]`, integer cells, top-left origin, positive X right, positive Y down, half-open bounds. **Later rectangles overwrite earlier rectangles** just as `godot/scripts/demo_worlds.gd::_rect` construction commands; no renderer layers, erase masks, transparencies, carve commands or alpha paint are implied. Every piece anchors at bottom centre. Importers must obtain explicit host clearing and rollback/undo authority; blank zones **do not remove** existing matter. Spacing, support geometry, Rapier collision and traversal require actual native/world tests.

## Physics/admission table

| Structure(s) | Source-level classification | Required qualification |
| --- | --- | --- |
| First six original modules | Source materials all `movable=false`, `kernel=0` | Static *candidates* only: thin hanging cable lines, spires and bells may block actors or intersect terrain. |
| `tidal-checksum` original | Water **3**: FreeMass active liquid; Brine **24**: active liquid | Physical settling, volume conservation, possible shell leakage, liquid exchange, actual colour/surface behavior and CPU cost. |
| `sediment-semaphore` original | Sand **2** and Salt **23**: gravity powders | Settling, falling from trays, particle quantity, spill into neighbours, possible conversion to Brine in Water contact. |
| Dry combined scene | Water 3→GlassBlock 120; Brine 24→FrostedGlass 121; Sand 2→SandstoneBlock 39; Salt 23→RockSaltBlock 106 | Source-marked nonmoving/kernel-zero after substitutions; still no native tick, world-edge, collision or performance proof. |

No heat, curing, underwater oxygen, corrosion or signal interactions are assumed from the artwork. These are authored rectangles, not structural constraints. Dense cable strokes can increase staging/paint count; native memory, CPU, cell budgets and GPU draw calls have **not** been measured. Experimental active versions must stay in isolated native proof fixtures.

## Source custody, validation and regeneration

Pinned **main `ba9cbc89029be88b812af59b19e5c59829bbcd90`**, tree `3af18f50e6094776263119623b64a1b2f4ca0ab2`; native header blob `dcf05895da3015a2e999e3d1cbbae0fdc7fe32b3`; shadow catalogue blob `d7a47d60721598a16589daf177a6ff4401b84b43`. Native `material.hpp` defines runtime semantics; the JSON catalogue is **shadow metadata**, not a source-of-truth replacement. No production material files changed.

From a real checkout of the pinned source:

```sh
node docs/world-design/coral-telegraph/validate_pack.mjs --negative --source
node docs/world-design/coral-telegraph/render_pack.mjs --check
node docs/world-design/coral-telegraph/render_pack.mjs --write
```

**Generation-side evidence:** 1424 rectangles within bounds; 25 exact enum/catalogue ID and metadata comparisons passed; 16 variants, eight dry placements, explicit anchor geometry and nonmoving/kernel-zero dry scene passed; 14/14 negative mutations rejected; reproducible vector preview generated. **Not executed:** these checked-in Node utilities on an actual cloned checkout, Godot/native stepping at t=0/60/600, Water/Brine containment, powder settlement, actor clearance, CI or performance measurement. No claims of feasibility from the SVG.

Future integration needs an independently admitted importer/schema, native initial-state assignment, host erase/undo contract, source checks, actor/collision clearance and measured sim/paint costs. Keep separate from PLAY, SOL, MAT-AUTH, IN-TOOLS and solver integrations.

Prior collections inspected: #408, #410, #412, #414, #420, #425, #430, #434, #437, #439, #443, #445, #447. Next candidates: **Fallow Carnival**, **Saltwind Viaduct**, **Glassroot Labyrinth**.

## C3 flagship refinement — Abyssal Splice Basilica (6 November 2026)

The formerly separated eight dry modules now occupy a connected **abyssal cable-exchange basilica**. Unequal stratified escarpments enclose a broken copper-ceramic calibration crown, collapsed roof ribs, taut and torn catenary wires, damaged elevated route piers, the salt ledger transept, and an interrupted buried conductor. A failed centre splice is the narrative focus. The **`combined_scene.terrain_rectangles`** array adds **1619 ordered source-material inert rectangles behind the placed features**. Four original dry modules receive masonry abrasion, fastening and maintenance etching. All **8 modules, 16 variants, 3 patterns, 8 dry placements** and anchors remain; no active materials were added to the flagship.

The deterministic **`preview.svg`** now includes two enlarged 2.15× dry-source-colour close studies beneath the atlas and original reusable-module gallery. Ordered-cell comparison: **121,849/443,880 scene cells changed**, **59,170 above y=190**, **60.1% unwritten air retained**. These measures are geometry evidence, not artistic certification.

The exact fetched checked-in `validatePack` and `makeSvg` JavaScript function bodies passed isolated V8 execution using source-pinned native enum and catalogue, with **10/10 invalid test mutations rejected** and original SVG reproduced byte-exactly. Genuine full-checkout Node CLI process exits, Godot renders and all physics/clearance/performance tests are unexecuted; none are implied by a flat SVG. Underwater appearance, electrical operation, optics, buoyancy and fluid reaction are entirely illustrative. Next: an alternate descending cable-crypt arrangement reusing the same eight motifs, followed by native graphical comparison and independent human review.
