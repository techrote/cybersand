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

## C10 alternate diorama — The Broken Return (6 November 2026)

The source flagship **Abyssal Splice Basilica** remains intact. The new **1370×420** two-level dry cable crypt reuses eight original modules without changing any feature rectangle or variant (all sixteen preserved). Four upper ruins anchor at **y=182**; four lower ledger structures anchor at **y=378**. The original moving Water/Brine/Sand/Salt examples are not placed: the exact existing `sealed-dry-checksum` and `petrified-grading` substitutions are used.

A fractured monumental copper-ceramic **double return crown** is the primary focal silhouette. Asymmetric basalt escarpments, severed suspended catenaries, interrupted inspection platforms, two bearing-seat buttresses, broken stairways, lower fossil record courts and a deliberately unstamped central shaft connect the eight modules into a common abandoned underwater-message network. Macro-scale voids and unequal height rhythm are complemented by masonry joints, insulated conductor ferrules, copper ledger marks, fractured registers and concentrated inert mineral accretion. The latter suggests erosion/corrosion as an artistic narrative only.

The alternate uses **1286 ordered fixed-material backdrop rectangles** and **164 foreground marks**. The deterministic flat palette SVG now includes two full panoramas, eight reusable module panels and four enlarged source-colour crops. No SVG can erase pre-existing world cells; the apparent shaft requires independently authorised world clearing. The artwork does not establish pressure, optical reflection, signalling, sound, buoyancy, structural stability, fluid containment, active material behaviour or actor clearance.

Reproduce in a full source checkout with `node docs/world-design/coral-telegraph/validate_pack.mjs --negative --source` and `node docs/world-design/coral-telegraph/render_pack.mjs --check`. During this run the exact checked-in functions were exercised in isolated V8 with the matching source header/catalogue, not a Node CLI checkout. Godot rendering, native simulation, performance and all-five-gallery independent human acceptance remain untested.

## The Severed Listening Choir — central return-shaft craftsmanship (6 November 2026)

The 1370×420 dry *Broken Return* alternate now joins its upper and lower ruins through two deliberately unequal receiver shoulders, fractured twin service galleries, ceramic-studded cable ferrules, a broken double listening hoop and a missing central transmission bridge. An incomplete tuner, four small register inscriptions, locally concentrated iron corrosion and mineral encrustation add a legible failed-message history without scattering random noise. The hoop aperture and most of the deep lower shaft remain empty. This is authored source-colour geometry, **not** an actual underwater, electrical or acoustic system.

The change adds **433** fixed native-material foreground rectangles to the alternate only. Ordered final-cell comparison with the preceding published head changes **10,213 / 575,400** material cells, 10,209 within x610–820, y190–370; 7,791 previously unwritten cells gain paint and 70.35% remain unwritten. These counts measure geometry, not aesthetic superiority. The deterministic `preview.svg` now focuses its first alternate 2.15× study on the broken listening assembly, retaining the other crop, both full vistas and eight module portraits. All eight reusable modules, sixteen variants, existing recipes and original/alternate placements are unchanged.

The exact material IDs are shadow-catalogue/native-enum pinned, and the static/dry classification is authoring-only. The SVG proves neither Godot graphics, collision clearance, Water/Brine/Sand/Salt behavior, structure, pressure, signaling nor performance. Run `node docs/world-design/coral-telegraph/validate_pack.mjs --negative --source` and `node docs/world-design/coral-telegraph/render_pack.mjs --check` on a complete source checkout for actual process-exit qualification; human reference-comparison acceptance remains outstanding.


## C4 flagship craft — The Four Silent Cable Registers (6 November 2026)

The previously massive uninterrupted lower seafloor of the 1370×324 **Abyssal Splice Basilica** is now an architecturally joined burial of four failed communication records. Unequal, deliberately stepped and **genuinely unstamped** apertures replace portions of the original ordered basalt/geological foundation; they do not fake an empty chamber with dark paint. The west **tidal lexicon** contains seven mismatched suspended ceramic records. A seized seven-socket repeater and split conductor trunk occupy the central **bus register**. The eastern **witness codex** hangs disconnected ceramic leaves beside a failed small spool. A broken **salinity protocol** holds six unequal rock-salt scales and a dry cracked measurement ampoule. Damaged quoin piers, diagonal fracture-bond masonry, selective brass witness ticks and three deliberately interrupted cable paths connect these to the eight modules above. The unequal apertures remain partially open and the upper failed-splice crown remains the visual centre.

Source geometry: **26** stepped cuts geometrically resection earlier ordered rectangles (1619 original terrain stamps → 1510 retained stamp fragments), then **288** deliberate inert/native-source material details (1798 total terrain stamps). A final ordered material-ID grid changes **21,346 of 443880** displayed cells, **13,376 previously painted cells become genuinely unwritten**, and **628 previously unwritten cells acquire details**. The former are prospective illustration gaps, **not** runtime host-terrain erase operations; the counts establish source-cell changes, not aesthetic certification. All eight original modules, sixteen variants, three composition patterns and flagship/alternate placements remain unchanged; the entire existing alternate is unchanged.

The deterministic flat source-colour SVG includes two additional 2.15× lower-register studies. This is *not* Godot shading or a playable seafloor. No Water/Brine/Sand/Salt simulation, structural loading, marine signalling, electrical behavior, collision clearance, material pattern rendering, performance or comparative human gallery acceptance was tested. Reproduce with `node docs/world-design/coral-telegraph/validate_pack.mjs --negative --source` and `node docs/world-design/coral-telegraph/render_pack.mjs --check` on a real, source-matched checkout. Isolated V8 validation is documented in the PR handover; it is not evidence of Node CLI process exits.

## The Undelivered Reply — four lower exchange vaults (7 November 2026)

The 1370×420 dry Broken Return alternate now has four materially distinct genuinely unstamped stepped rooms in the lower escarpments: seven ceramic shore-departure message slips; a seized return-spool and disconnected hand-crank; opposed ceramic differential listeners; and five mismatched dead-letter drawers. Unequal load-bearing stepped stone shoulders, chipped quoins, damaged conduits, sparse mineral/verdigris wear and short interrupted lower return rails connect the ruins to the old broken listening hoop while reserving the central shaft's negative space. No dynamic module content changed.

Twelve stepped geometric resection cuts transform the alternate backdrop from 1286 to 1284 source-fixed ordered fragments; 420 crafted foreground stamps extend the alternate foreground from 597 to 1017. Last-write-wins native material raster changed 20,301 cells; 9,754 formerly painted are genuinely unstamped and 2,990 formerly blank gain material. 71.53% remains unwritten. The deterministic 2950px source-colour SVG adds two exact 2.15x detail studies; all earlier panoramas/crops remain. All eight original modules, 16 variants, three recipes, two placement sets, and the entire flagship remain unchanged. This is authored geometry rather than a real Godot frame or host erasure. Water/Brine/Sand/Salt dynamics, sound, electricity, pressure, clearance, lighting, performance and five-reference independent artistic acceptance are untested.
