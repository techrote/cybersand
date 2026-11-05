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
