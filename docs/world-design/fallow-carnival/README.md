# Fallow Carnival — The Last Lights of the Midway

**CyberSand world-design collection 015 · 2026-11-05 · DRAFT art-authoring proposal.** A deserted fairground rendered from real CyberSand source-defined materials, not a gameplay level, ride simulation or engine feature.

This is an abandoned after-hours amusement strip: a grand arch with fractured festoons, frozen Ferris wheel, empty carousel, ticket shutter, prize gallery, mirror maze, powder-filled ring-toss station and two abandoned reflective pools. It contrasts Coral Telegraph's submerged infrastructure and the industrial and geological world packs through its zigzag signage, circular silhouette, cheerful residual colours and explicit empty spaces.

## Eight modules

| ID | Size (native cells) | Class | Visual/physical intent |
| --- | ---: | --- | --- |
| `midway-portal` | 156×130 | inert-static | Festooned monumental entrance with missing signage and asymmetric ribbons |
| `starlight-wheel` | 168×152 | inert-static | Broken Ferris-wheel skeleton with eleven stationary empty gondolas |
| `carousel-chapel` | 152×124 | inert-static | Star-tipped striped carousel canopy, bronze horseshoe rail and deserted poles |
| `ticket-crypt` | 130×109 | inert-static | Three-shutter entrance booth with broken ticket window and faded paper-colour tile symbols |
| `prize-wall` | 148×105 | inert-static | Boarded arcade gallery with bright awning, empty peg grid and six inert glass prizes |
| `mirror-breach` | 147×116 | inert-static | Zigzag fractured mirror columns, offset corridors and kaleidoscopic colour markers |
| `silt-game` | 132×97 | dynamic-powder | Stacked open trays of loose Sand and Dust beneath a fixed ring-toss scaffold |
| `rain-arcade` | 140×102 | dynamic-liquid | Paired enclosed test bowls with Water and Brine below a fractured neon rain-sign |

The original experimental `silt-game` contains mobile **Sand 2** and **Dust 14**; `rain-arcade` contains mobile **Water 3** and **Brine 24**. The combined scene uses the **`petrified-game`** and **`dry-reflections`** variants to replace these with inert fixed sandstone/chalk and glass; the originals are not stable-scene claims. Each module provides two controlled variants.

**Source identity:** main `ba9cbc89029be88b812af59b19e5c59829bbcd90`, tree `3af18f50e6094776263119623b64a1b2f4ca0ab2`; runtime enum `native/include/cybersand/material.hpp` blob `dcf05895da3015a2e999e3d1cbbae0fdc7fe32b3`, shadow catalogue `materials/catalogue/catalogue.json` blob `d7a47d60721598a16589daf177a6ff4401b84b43`. Runtime native material definition remains authoritative; the catalogue is shadow metadata, not an editable production dependency. `30` exact IDs are listed in the pack. Avoid Wood and AcrylicSheet even as apparently static props here: their nonzero combustible kernels do not qualify as inert scenery.

## Styling, composition and concrete placement

Use dark **Asphalt 59**, **WroughtIron 50**, **RustedSteel 65**, **Slate 49** for the structural night skyline. Use **PaintedSteel 63** and **RedBrick 43** for derelict booths, then small **NeonMagenta 78**, **NeonAmber 79**, **NeonCyan 77** and **LedWhite 80** pinpoints for identity. Neon IDs are only material colours; no emitted light, electricity or live signage is asserted. The wheel must be the largest circle; canopy a lower roof; ticket/prize a dense middle section; maze a sawtooth end-cap.

The dry scene **1420×226 cells** is `combined_scene` in [pack.json](pack.json), baseline Y=200. Module origins (top-left) and ground-anchor coordinates are explicit; components are laid out left-to-right with **22-cell blank corridors**, beginning at X=29. Use only 0-degree, native 1× placement until other transforms receive independent review. A good repeatable layout is **entrance → ticket booth → prize gallery**; for a mechanical skyline use **carousel → starwheel → mirror maze**; for a weathered fairground tail use **dry** silt-game/rain-arcade before a booth. Avoid back-to-back tall circular silhouettes without extra clearance.

All rectangle stamps are integer tuples `[x,y,width,height,material_id]` with top-left origin, positive X right/positive Y down, half-open bounds, and later stamps overwriting earlier ones; see `godot/scripts/demo_worlds.gd::_rect`. There is **no true transparency, negative stamp/erase, geometric attachment, layering or automatic excavation**. Host clearing, placement preview, undo, occupancy and ownership of existing cells must be separately designed. Place modules on known supported ground; do not assume invisible arches are safely traversable. Minimum neighbour separation is a suggestion, not an actor-clearance result.

## Simulation/admission risks

- **First six modules:** Source-marked `movable=false`, `kernel=0` materials at their original geometry. They are *fixed candidates*, not gameplay-collision-approved assets. Overhangs, narrow spokes, windows, wheel rim/gondolas and open pedestrian paths may intersect solid terrain or actors; no physical attachment constraints are generated. No actual ride motion, score, mirror reflection or light emission.
- **Silt Game, active original:** Sand 2 / Dust 14 are gravity powders. Quantify settling, spill over open ring-toss trays, potential host contamination, cell counts and frame cost at t=0/60/600. Dry substitution: Sand 2→SandstoneBlock 39, Dust 14→ChalkBlock 99. Alternative: 2→RockSaltBlock 106, 14→FrostedGlass 121.
- **Rain Arcade, active original:** Water 3 is a conserved FreeMass liquid; Brine 24 is a separate yielding-liquid flow. The rectangles do not prove watertightness or stable menisci. Check contacts, mass conservation, leakage, and possible interactions at 0/60/600+ ticks. Dry substitution: Water 3→GlassBlock 120, Brine 24→FrostedGlass 121. Alternative: 3→DarkGlass 72, 24→StainedGlass 55.
- **Performance:** The geometry uses many tiny ring/spoke/festoon and prize rectangles; authoring stamp count is *not* equivalent to native incremental cell/solver cost. Record material counts, paint commands, applied cell area, occupancy, native replay timings, actor/Rapier clearance and rendering at 1× before admission. Avoid broad stamping into unrelated active material.

## Reproduction and evidence limits

From checkout of the **pinned source** with Node:

```sh
node docs/world-design/fallow-carnival/validate_pack.mjs --source --negative
node docs/world-design/fallow-carnival/render_pack.mjs --check
node docs/world-design/fallow-carnival/render_pack.mjs --write
```

[preview.svg](preview.svg) is a deterministic source-colour illustration of the original modules plus the dry combined scene. It is not a Godot screenshot or native physics capture. Generation-side evidence: 976 bounded ordered geometry stamps, 30 checked ID/properties, 16 variants, 3 patterns, 2 explicit dynamic originals, 14/14 deliberately invalid mutations rejected, and matching deterministic SVG construction. **Not performed**: executing these checked-in scripts from a cloned working tree (GitHub checkout host DNS unavailable), Godot/native simulation, actual wet/powder stability, actor clearance, hosted CI, stress/performance benchmarks or production map import. No production code or maps changed.

## Future integration gate

Admit a versioned staging schema independently; map authoring requires explicit clear-and-undo semantics, native initial-state assignment, material-source identity checks, blend/overlap detection, collision/traversal approval, measured performance and isolated active-material fixtures. Do not merge or adopt into canonical maps until independently reviewed; keep independent from PLAY, SOL, MAT-AUTH, IN-TOOLS and solver integrations.

Prior collections inspected: #408, #410, #412, #414, #420, #425, #430, #434, #437, #439, #443, #445, #447, #451. Next candidates: **Saltwind Viaduct**, **Glassroot Labyrinth**, **Fossil Kitefields**.

## Worker C — The Broken Skyway (6 November 2026)

The original carnival modules now sit inside a dry interconnected abandoned aerial-midway composition: interrupted twin-track skyway, six independently braced trestles, skeletal big-top roof, damaged hanging admission ledger, riveted walkway connections, weathered signboards, a fallen trolley and undercroft of jointed brick, asphalt and abandoned relics. It retains a wheel-led focal silhouette and a deliberately dark/bright hierarchy. Carousel and ticket modules receive small inert wear scars; live Water/Brine/Sand/Dust versions remain experimental and excluded from the combined dry scene.

**New data:** `combined_scene.backdrop_rectangles` adds **2178** bounded, source-palette inert construction rectangles (stamped before the eight reusable features). The eight feature IDs, 16 variants, 8 placements and 3 patterns are preserved, with 997 feature rectangles. A source-colour ordered-cell comparison against the original panorama identifies **38823** changed cells; **67.4%** are unwritten. `preview.svg` now includes two enlarged study crops, still *only flat material-colour illustration*, not engine rendering. Backdrop validation includes integer/bounds/material non-mobility checks and four negative cases.

**Limits:** geometry alone does not certify skyway support, passage clearance, simulated ride motion, neon emission, wet containment, native performance or acceptance relative to five real CyberSand gallery references. Blank preview canvas never clears native terrain. Reproduce from a source-matched checkout with `node docs/world-design/fallow-carnival/validate_pack.mjs --source --negative` and `node docs/world-design/fallow-carnival/render_pack.mjs --check`, inspect actual process exit codes and seek a real Godot capture before artistic admission.

## Alternate flagship — The Unclaimed Procession (6 November 2026)

**Second, spatially distinct dry composition**, `alternate_scene`, is **1420×356** native-material cells. This ruin stages a once-raised carnival mechanical court above a collapsed two-level procession: the original wheel is displaced to a high central terrace above a failed empty maintenance lift, while the arch, ticket chamber, carousel, prize gallery, mirror maze and two petrified games step down across fractured boarding decks. Eight unequally supported foundations, voided wheel supports, a snapped overhead inspection viaduct, intermittent pennants, a severed cable run, a damaged registrar's gantry, stripped prize sockets, fallen slates and small corrosion/fastening groups tell a single abandoned-fairground story. Some gaps are deliberately *unstamped air*; they do not erase host matter.

The alternate contains **892 ordered inert terrain/structure stamps** and **138 foreground wear stamps**, painted respectively before and after eight reused module placements. The original 1420×226 panorama, eight original features, all 16 variants and three assembly patterns are preserved byte-identically in source JSON. The alternate repositions those eight reusable features vertically as well as horizontally; each remains at its original 1× scale and 0° orientation. Their source-defined dry variants substitute Sand/Dust/Water/Brine only for this illustration. Earlier source claims and risk notes still apply.

`preview.svg` now includes the original panorama, all module cards, and a second full panorama plus two close studies. It is **deterministic source-colour SVG, never a Godot screenshot**. Enhanced validation checks alternate stamp bounds, exact palette inertness, placement anchors, unique features, no module bounding overlap and substituted variant inactivity. No ride movement, electrical illumination, reflection, fluid containment, actor clearance, native performance, or production import has been qualified. Comparison to the five original graphical gallery references remains unaccepted until comparable actual captures and independent human review.

To validate in a real full checkout with matching pinned source identities:

```sh
node docs/world-design/fallow-carnival/validate_pack.mjs --source --negative
node docs/world-design/fallow-carnival/render_pack.mjs --check
node docs/world-design/fallow-carnival/render_pack.mjs --write
```

## Worker C — The Dead Letter Skyrail (6 November 2026)

A further authored pass enriches the **second** dry panorama, `The Unclaimed Procession`, with a broken overhead fairground railway. Three interrupted twin-rail runs create a distinct western lift, a gap over the monumental stationary wheel, and a falling eastern return. Seven varied riveted lattice trestles connect the elevated track down to stone piers and the ruined midway; the wheel acquires background A-frame bearing legs and damaged footing plates. The western carousel is framed by a torn, open-rib big-top roof, with a scuffed **LAST FARE** ledger panel, five abandoned hanging baskets, broken festoons, masonry undercroft courses and local register abrasions. Material-colour pennants represent **unpowered, non-emissive** decoration. Track discontinuities, roof holes and the central wheel aperture preserve authored black negative space rather than flood-filling the skyline.

The exact `alternate_scene` ordered stamp arrays change from **892 to 4592 terrain/backdrop rectangles** and **138 to 271 foreground wear rectangles**, still within 1420×356 integer bounds, all using previously pinned fixed/zero-kernel IDs. The existing main panorama, **eight original modules, sixteen variants, three patterns, eight alternate placements and dry substitutions** are unchanged. The deterministic `preview.svg` shows updated alternate atlas and close studies; it is a flat source-colour image, **not a Godot, engine-lighting or physics result**. The newly articulated elevated railway remains an illustrative architecture, not a functioning ride or proof of statics, clearance or engine performance.

At source-pinned authoring review, a source-colour material raster at **1:2 native-cell scale** was visually examined before and after, specifically to assess skyline continuity, broken-span separation, the wheel focal point and micro-signage. The exact checked-in renderer's algorithm was independently transcribed into the isolated V8 runner; it reproduced the pre-change SVG **byte-for-byte**, then regenerated the new SVG deterministically from the changed pack. The checked-in validator's rules and mutation cases were likewise reproduced in V8 against the unchanged native header/shadow catalogue: **26/26 negative cases rejected**. This is **not** a local `node` subprocess or its exit 0. On this host `git ls-remote https://github.com/techrote/cybersand.git HEAD` failed with DNS exit 128; full checkout Node CLI, Godot/native visual captures, t=0/60/600 active-material tests, clearance and performance remain untested. All-five-reference artistic superiority remains **unaccepted**, pending comparable pixels and independent human review.

Reproduction from a source-matched checkout: `node docs/world-design/fallow-carnival/validate_pack.mjs --source --negative` and `node docs/world-design/fallow-carnival/render_pack.mjs --check`. Next art priority: replace the eastern lower foundation's long repetitive ledger with fractured, irregular inset courtyards without eroding module legibility.

## Worker C — The Last Fare Reliquary (6 November 2026)

The 1420×356 alternate *Unclaimed Procession* has a new, deliberately incomplete **Last Fare** atrium terminating the original elevated midway. Its unequal pylons, interrupted roof cornices, exposed damaged ribs, three open inspection galleries, torn hanging tickets and chipped physical fare register integrate a distinct eastern landmark; fractured diagonal trestles return to the old lower pierwork. Seven irregular lower-floor cuts remove painted cell geometry to create real unpainted niches containing separate ticket, claim and measurement relics. Materials remain source-pinned and fixed in the dry diorama; amber/brass represents colouring, not actual electrical light.

All eight reusable module shapes, sixteen variants, three motifs, original flagship and both placement arrangements remain unchanged. The deterministic SVG eastern close study is re-framed around the new terminus. This is static source-colour authoring, not Godot rendering. No ride motion, electrical output, Water/Brine/Sand/Dust physics, collision clearance, performance or independently accepted five-gallery superiority is claimed. Full-checkout Node CLI and real engine captures remain outstanding.

## Four Houses of the Unclaimed — excavated claim undercroft (6 November 2026)

The 1420×356 dry *Unclaimed Procession* alternate now contains four architecturally distinct, genuinely unwritten lower chambers: a seven-slip lost-fare exchequer at x74–179, a five-mask abandoned carousel atelier at x351–514, a seized double-gear wheel governor with separated counterweights at x681–896, and four fractured glass panes in a lost-property reliquary at x944–1082. Jagged brick/ashlar shoulders, worn bearing jambs, interrupted inspection rails, broken cornices, damaged inscriptions and restrained brass fastening groups connect the excavations to the upper ruined fair. Void construction resects old ordered source-material geometry; **unstamped cells do not erase existing host material**.

Source-preserving resection transformed the original 5509 alternate terrain and 279 foreground stamps into 5378 terrain and 670 foreground stamps, the latter including **422** new fixed-material details. A last-write-wins native-ID raster comparison gives **25,826** changed final cells, **12,277** formerly painted now unwritten, and **8,376** previously unwritten now authored. These are geometry evidence, not art scores. Two deterministic enlarged alternate studies now show the edited vaults at source-colour scale. The flagship, all eight reusable modules, 16 variants, three patterns, both eight-module placement inventories and the original mobile-material experiments are unchanged.

The checked-in JS validator/renderer functions were executed in connected V8 against the pinned native header and shadow catalogue. Validation passed, 23/23 existing deliberately invalid mutations and 4/4 focused additional cases were rejected, and SVG output reproduced twice byte-identically. The baseline committed SVG's Git blob was also reproduced exactly. **These are real function executions, not local Node CLI exit codes**; a local Git checkout is not available due DNS failure. No Godot/native capture, Water/Brine/Sand/Dust simulation, ride behavior, lighting, reflection, collision clearance, structural loads, performance or independent human gallery acceptance is claimed.
