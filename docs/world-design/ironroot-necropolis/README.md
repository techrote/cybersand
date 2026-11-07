# Ironroot Necropolis — Avenue of Silent Forges

**Collection 012 · draft world feature art pack · 2026-11-05.** Design-only: not simulation-tested or a production map. Pinned main `ba9cbc89029be88b812af59b19e5c59829bbcd90` (tree `3af18f50e6094776263119623b64a1b2f4ca0ab2`), native header blob `dcf05895da3015a2e999e3d1cbbae0fdc7fe32b3`, shadow catalogue blob `d7a47d60721598a16589daf177a6ff4401b84b43`.

This is a solemn industrial funerary precinct. Long-dead ironworks have been transformed into ossuaries: steel archways, riveted caskets, iron-root devotional trees, silent foundry bells, graven serial markers and wreath-shaped transmission mechanisms. No glowing factory, active communications infrastructure, or functioning machinery is implied. This silhouette language is distinct from electrical Cathedral of Capacitors, tidal Silt Clockworks and astronomical Drowned Observatory.

## Contents

| Module | Cell size | Classification | Key aesthetic |
| --- | ---: | --- | --- |
| `processional-gate` | 146×124 | inert-static | Twin heavy piers and a torn arch framing a dark, uninterrupted avenue |
| `gearshrine-sarcophagus` | 138×108 | inert-static | Coffin shrine with stepped cog teeth and serial graveside registry |
| `ironroot-crucible` | 132×128 | inert-static | A radial black iron-root lattice with a copper ceremonial heart |
| `foundry-bell-chapel` | 126×120 | inert-static | Bell-shaped steel memorial nested in a broken blast-furnace facade |
| `grave-ledger-terrace` | 134×96 | inert-static | Rhythmic grave markers and inscription rails to reset the skyline |
| `coil-wreath-cenotaph` | 126×122 | inert-static | Circular funerary iron wreath suspended within a masonry A-frame |
| `rustfall-ossuary` | 130×112 | dynamic-powder | Experimental rust powder descending through slotted industrial funerary filters |
| `black-oil-votive` | 132×104 | dynamic-liquid | Experimentally liquid dark votive basin framed by thick stone and brass markers |

**8 modules; 905 ordered rectangles; 16 variants; 26 pinned material IDs.** [Preview](preview.svg) · [JSON pack](pack.json). The gallery *Avenue of Silent Forges* is **1270×310** native cells with all eight modules, bottom-aligned at y=263. The first six originals are all source-metadata inert; the last two use dry substitutions in the gallery.

## Art direction and combinatorics

- **Shape hierarchy:** A very tall portal, a low register of caskets, an intermediate branching ironroot, then another monumental ring or bell. Avoid uninterrupted towers. Represent remembrance by small pale/gold glyphs arranged in rhythmic multiples of 3 or 7.
- **Proportions:** Target 60% black basalt/slate/rusted iron, 20% worn stone, 15% warm bronze/verdigris, 5% small gold inscriptions. This is an artistic target, not measured final pixel coverage.
- **Material vocabulary:** BasaltColumns **100**, Obsidian **101**, IndustrialBrick **57**, RustedSteel **65**, SteelPlate **62**, WroughtIron **50**, BareIron **117**, Slate **49**, GraniteBlock **40**, VerdigrisCopper **54**, BrassPanel **119**, GoldLeaf **118**. Rust **29**, Coal **27** and Oil **16** appear *only* in standalone experimental modules unless their static substitutions are selected.
- **Assemblies:** `funerary-portal` links gate → casket → grave ledger; `ironroot-chapel` uses rooted tree → foundry bell → wreath; `oxidation-endpoint` uses rustfall → oil votive → ledger, defaulting to its fossilised and sealed variants. Each has explicit separation in `pack.json`.
- **Neighbouring:** Maintain **18–28 native cells** between feature footprints unless a future qualified importer permits joints. Place high silhouettes on separate beats of the procession, with graves acting as negative-space resets. No two tall rounded features should abut.
- **Alternates:** Every module has two explicit palette-swap variants. Root/arch colour variants stay fixed; `rustfall-ossuary/fossilised-leak` maps Rust **29**→RustedSteel **65**, Coal **27**→Obsidian **101**; `black-oil-votive/sealed-black-mirror` maps Oil **16**→DarkGlass **72**. Dry substitutions deliberately change material behaviour and imagery.

## Exact authoring semantics

All `rectangles` are **[x,y,width,height,material_id]** in native integer cells, half-open bounds, local origin top-left and +y down. They are applied **in array order**, with later rectangles overwriting earlier ones; no alpha blending/layers, real 3D depth, rotation, rescale, carving, simulated force or negative stamp is encoded. `anchor.point` is the bottom-centre of the module; scene placement is local origin plus `combined_scene.placements[].origin`. The preview background is *not stamped material*. A future map importer must explicitly clear host space and define overwrite rules before it can produce the silhouette.

## Physics qualification and admission

| Scope | Source-level properties | Risks / necessary experiments |
| --- | --- | --- |
| Gate, casket, ironroot, foundry bell, ledger, wreath | Current catalogue: all nonmoving, kernel-zero | Static scenery **candidates**, not native-tick qualified: suspended disjoint appearance, occlusion, portal/passage clearance and collision remain untested |
| Rustfall Ossuary, original | Rust **29** and Coal **27**: movable powders, gravity kernels | Falling piles and loss of designed silhouette; test repeated settling, neighbouring cells, bounds, frame cost, and dry substitution parity |
| Black-Oil Votive, original | Oil **16**: movable CellularYield liquid (viscosity index from catalogue) | Leak/outflow, oil combustion near flames, and interactions with metals cannot be inferred from schematic; test isolated, source-pinned native fixture |
| Combined dry scene | All material IDs in **post-substitution** geometry are nonmoving and kernel-zero | Authoring-only classification. No native stepping, actor envelope check, Godot rendering, thermal test or performance study performed |

The original oil basin is **not accepted as sealed**: its front wall is only an ordered rectangle prototype, not a measured containment vessel. Real Rust and Coal are not permanently suspended. No active flame, moving bell, thermal engine or light source is supplied.

## Reproduction and scope

From a repository checkout containing the pinned catalogue/header:

```sh
node docs/world-design/ironroot-necropolis/validate_pack.mjs --negative --source
node docs/world-design/ironroot-necropolis/render_pack.mjs --check
node docs/world-design/ironroot-necropolis/render_pack.mjs --write
```

Review source identity and renderer drift after any upstream material-catalogue changes. These checks cover structural design data and deterministic illustration, **not** native simulation qualification, Godot display, collision safety, gameplay or map loadability. Generation-side checks ran through the GitHub connector with a separately evaluated 10-case negative mutation suite; a local clone was unavailable because the container could not resolve github.com.

**Proposed future integration:** versioned editor palette with source identity checks; copy-stamp explicit host clearing and source-pinned material enums; opt-in active variants in separate qualification fixtures; no automatic injection into production maps. This pack does **not** touch PLAY, SOL, MAT-AUTH, IN-TOOLS, solver implementations or the canonical catalogue.

## Differentiation and next design candidates

Previously inspected: #408, #410, #412, #414, #420, #425, #430, #434, #437, #439 and #443. The distinguishing subject is **industrial funerary ritual and memorial architecture**, not functional electricity, hydraulic systems or celestial navigation. Candidate future collections: **Tectonic Archive** (fossilised geological libraries), **Coral Telegraph** (submerged analog signal ruins) and **Fallow Carnival** (weathered amusement skeletons).

## Flagship refinement — The Last Register (2026-11-06)

The authored **dry necropolis** now joins the eight preserved funerary monuments into a ruined place. An incomplete bell-crown frames a suspended inventory slab; broken coffin-conveyor sections, hanging weights, asymmetrical foundry escarpments and load-bearing counterforts evoke its final abandoned procession. Seven unequal archivolts, interrupted memorial parapets, root-veined foundations, a layered ossuary undercroft and deliberately sparse inscriptions establish construction logic at atlas and 2× detail scales. Three original reusable modules gain worn joins, abrasions and damaged registries. The theme remains funerary ironworking rather than an energized factory.

**Local scene-stamp extension:** `combined_scene.terrain_rectangles` is an ordered set of absolute-coordinate fixed source-material rectangles painted **before** the eight original module placements. Added validation checks integer format, bounds and nonmoving/kernel-zero metadata. Dark painted crypt openings use solid Obsidian 101: **no host cells are erased**. This design field is not an admitted native World importer/schema. Original 8 modules, 16 variants, 8 placements and 3 assembly patterns remain. The deterministic SVG shows an atlas, eight individual modules and two 2× crops; all are **flat source-colour illustrations**, not Godot/native physics, reflections, functional cables, clearance, pressure or acoustic proof.

Reproduction: `node docs/world-design/ironroot-necropolis/validate_pack.mjs --negative --source` and `node docs/world-design/ironroot-necropolis/render_pack.mjs --check`. Full local Node checks and comparative engine captures remain distinct qualification gates; next visual iteration should create an alternate descending cryptway and independent before/after gallery comparison.

## Alternate dry diorama — The Unmarked Descent (6 November 2026)

The second **1270×310 native-cell** authored environment replaces the first flagship's horizontal public avenue with a broken subterranean funeral route. Opposing escarpments, descending and ascending collapsed memorial stairs, a fractured registrar crown, severed counterweight chains, carved cinerary offices, six unequally braced piers and sparse sevenfold epitaphs create a distinct architectural sequence. The dark-looking crypt openings paint solid Obsidian 101: no host terrain is cleared.

The original **eight reusable modules, sixteen variants, three patterns and first flagship** remain. `combined_scene.alternates[0]` supplies **937** new fixed native-material rectangles and eight relocated modules in dry variants. Both native-cell-scale panoramas and four 2× cropped studies are present in `preview.svg`. Original dynamic Rust/Coal and Oil are *not* included: `fossilised-leak` and `sealed-black-mirror` are inert aesthetic substitutes, not a physical result.

Reproduction: `node docs/world-design/ironroot-necropolis/validate_pack.mjs --negative --source` and `node docs/world-design/ironroot-necropolis/render_pack.mjs --check` on a source-matched checkout. No Godot/native rendering, motion/clearance/performance or comparative human acceptance is implied by this flat-colour SVG.


## The Six Unrecorded Crypts — authored stone-and-iron resection (6 November 2026)

The eastern escarpment in *The Unmarked Descent* is genuinely opened into three unequally elevated memorial crypts: worn registrar tablets, a stranded iron plumb cradle, and tiered cinerary registers. Broken inspection galleries, masonry quoins, damaged stepped voussoirs, restrained bronze identifiers and concentrated verdigris/corrosion marks give the cliff a functional architectural history. Three further subterranean rooms divide the formerly solid lower apron into distinct ledger shelves, bell-reckoning apparatus and incomplete cinerary name-slabs. Deliberate gaps interrupt ties and thresholds; the carvings are legible at atlas and 2× source-colour crop scales. The voids were formed by **geometrically resectioning old ordered material stamps into non-overlapping remnants**: they are genuinely unwritten cells, not black painted proxy apertures. This does NOT automatically clear any host map.

After the 620 new source-fixed hand-directed material stamps were added, last-write-wins native-cell comparison of the 1270×310 alternate finds 33,756 changed cells, including 21,795 formerly painted now unwritten; 50.87% of final cells remain unstamped. This is not an art quality score. All eight original reusable modules, 16 variants, three patterns, original flagship and both eight-module placement sequences are preserved.

The checked-in JavaScript validator core was executed in isolated V8, all 20 negative mutations rejected, all 26 material entries source-verified against pinned header and catalogue, and the checked-in deterministic SVG renderer reproduced the original SVG byte-for-byte before rendering the revision. Full local Node CLI, Godot/native captures, structural support, dynamics, clearance, performance and independent comparison with all five gallery captures remain untested. On a full source checkout run `node docs/world-design/ironroot-necropolis/validate_pack.mjs --negative --source` and `node docs/world-design/ironroot-necropolis/render_pack.mjs --check`.

## Five Chambers of the Unfinished Roll — Last Register flagship (6 November 2026)

The **1270×310 native-cell flagship** now has five distinct genuinely unstamped archive chambers in its previously uninterrupted lower bedrock: a worn seven-name press, a seized four-weight funerary scale, a captive iron-root casket, an immobile bell-reckoning niche and five mismatched cinerary drawers. Their unequal vaulted shoulders, deliberately fractured stone voussoirs, bearing piers, intermittent steel access rail, scratched registers, sparse brass sigils and corroded fasteners connect the undercroft to the monumental processional architecture above. They describe a dead iron foundry converted into a place of record and mourning, not functioning machinery.

**Art source changes:** geometric native-cell resection affected 492 prior foundation stamps and produced 2926 preserved ordered fragments, followed by 666 carefully grouped fixed-material detail stamps. Last-write-wins source raster changed **35,732 cells**, including **22,739 formerly painted now genuinely unwritten** and **494 newly detailed**. Empty cells are not host-map erasure. All original eight reusable modules, sixteen variants, three assembly patterns, both eight-module placements, and the alternate environment are preserved unchanged. This is a flat source-colour visual design, not Godot/native output or a human quality acceptance claim.

The exact checked-in JavaScript validator and SVG renderer cores were run in isolated V8 against this pack, with pinned native enum blob `dcf05895da3015a2e999e3d1cbbae0fdc7fe32b3` and shadow catalogue blob `d7a47d60721598a16589daf177a6ff4401b84b43`. The baseline SVG reproduced byte-identically; regenerated revised SVG is deterministic; the 20 existing negative mutations were rejected. Full repository Node CLI, engine captures, geometry clearance, physical loads, reactive Oil/Rust variants and performance have **not** been qualified. Obtain real Godot captures and independent matched-scale review against all five source galleries before any superiority assertion.

## The Melted Names Foundry — elevated casting vaults and ruined hoist (6 November 2026)

This pass corrects the flagship's formerly bulky western basalt skyline by *genuinely resectioning* two unequal high-level foundry apertures into the source terrain (ten nonrectangular, stepped cut runs), not painting black rectangles over solid rock. The upper furnace has a suspended bronze bell mould and locally chipped stone voussoirs; the lower name-register gallery contains stranded tally leaves, cracked iron lintels and a broken cinerary shelf. Their discontinuous stair/rail remains lead toward a new, conspicuously asymmetric high casting-hoist frame between the cliffs and central necropolis. The hoist includes unequal three-point supports, diagonal damaged lattice, an interrupted horizontal carrying rail, severed crane arm, a partly hollow bronze memorial casting, five hanging name tablets and an isolated lead counterweight. Dry rust, verdigris, sparse GoldLeaf registration marks and stratified spalls identify the failed practice of melting old bells into memorial tablets; neither the machinery nor the hanging masses are claimed to work physically.

**Evidence:** from the preceding Draft #454 head `4c8ed330edba`, 3592 ordered flagship terrain stamps were resectioned to 3587 non-overwriting remnants and supplemented by 754 precisely positioned source-fixed details. Native material-ID last-write-wins raster changed **10,367** of 1270×310 cells: **3,302** previously painted cells genuinely became unstamped and **3,869** previously unstamped cells gained material. Unstamped does **not** clear any existing host World. The original eight modules, sixteen variants, three combinations, both eight-module placement sets and complete alternate diorama are unchanged. The first 2× deterministic SVG study now frames the actually modified western foundry rather than the central bell-crown; the second flagship study and both alternate studies remain.

**Qualification:** the exact previous checked-in SVG was reproduced byte-for-byte by a source-equivalent renderer in isolated connected V8, then the revised SVG was independently generated twice identically; a source-equivalent structural/dry-scene validation and **20/20** negative mutations passed, and all **26/26** palette entries matched the pinned native enum and shadow catalogue at their recorded Git blobs. This is *not* a full Node CLI process exit or Godot image. Obtain a full checkout for `node docs/world-design/ironroot-necropolis/validate_pack.mjs --negative --source` and `node docs/world-design/ironroot-necropolis/render_pack.mjs --check`, then separate exact-head native Godot captures/clearance/performance and human matched-gallery comparison. Design-only wet/metal wear, suspension and furnace imagery assert no live physics, sound, heat, mechanical operation or host erosion.

## The Thirteen Uncast Bells — ruptured high mourning route (7 November 2026)

The **Unmarked Descent** alternate gains two asymmetrical interrupted upper processions. The western five-fragment stepped viaduct climbs from the damaged foundry escarpment toward the central wheel; four battered bearing piers support two incomplete bronze/iron archivolts, seven hanging *unstruck* cinerary votives and a raised five-line register. Its final tie breaks off short of the monumental wheel. The eastern five fragments slump in the opposite direction, with four offset piers, two different damaged arches, a stranded register tablet and six individually varied dead votive weights. Architectural continuity is intentionally interrupted; the existing central silhouette, original eight motifs and lower archive crypts remain.

**Geometry:** 681 additional ordered fixed/kernel-zero [x,y,width,height,material_id] rectangles, in the existing alternate-scene terrain (x141–1074, y43–178), using verified RustedSteel, slate, wrought iron, bronze, basalt, iron, brass and verdigris palette IDs. Subtle damaged joints, missing bridge runs and dislocated threshold stones carry the history. Both 2× alternate source-colour studies now focus on the upper spans. All original modules, variants, patterns, main diorama and the eight original placements in each scene remain intact. Missing cells **do not erase a host World**.

These are illustrated, inoperative archaeological relics: there is no proven bridge loading, hanging-body gravity, bell sound, functioning registries, passage clearance, corrosion dynamics or engine material rendering. Full-checkout commands remain `node docs/world-design/ironroot-necropolis/validate_pack.mjs --negative --source` and `node docs/world-design/ironroot-necropolis/render_pack.mjs --check`. Neither replaces source-matched native/Godot captures or independent five-gallery human acceptance.
