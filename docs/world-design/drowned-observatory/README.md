# Drowned Observatory — Night of the Submerged Equator

**Collection 011 — draft, authoring-stage only.** Created 2026-11-05; pinned native `main` commit `ba9cbc89029be88b812af59b19e5c59829bbcd90` and tree `3af18f50e6094776263119623b64a1b2f4ca0ab2`. [View preview](preview.svg) · [Machine-readable pack](pack.json).

An extinct offshore observatory, flooded after its celestial navigation network went silent. The design combines interrupted marble domes, patinated bronze orbital instruments, needle-like tide survey markers, broken optical causeways, unreadable star charts and two optional active experiments. The imagery should evoke a precise astronomical institution whose measurements have become archaeology—not a generic industrial ruin or vegetation set.

## Contents

| Module | Cell size | Classification | Visual role |
| --- | --- | --- | --- |
| `broken-star-dome` | 148×126 | inert-static | High-contrast ruined observatory dome with inner negative-space opening |
| `meridian-needle` | 108×142 | inert-static | Vertical alignment reference and pale pinnacle |
| `siltbound-orrery` | 150×124 | inert-static | Concentric orbiting instruments and detached celestial nodes |
| `refraction-scriptorium` | 138×108 | inert-static | Low nave of segmented chart windows and optical ledger shelves |
| `abyssal-star-tablet` | 122×104 | inert-static | Low dark register connecting seven gilded star glyphs |
| `eclipse-transit-bridge` | 154×118 | inert-static | Long, low celestial viaduct above an uncut apparent aperture |
| `pressure-bell-pool` | 136×104 | dynamic-liquid | Optional experimental liquid basin beneath a false bell dome |
| `sediment-almanac` | 130×114 | dynamic-powder | Experimental suspended Salt and Dust above mineral sorting trays |

Eight reusable modules have **553 ordered native-material rectangles**, **16 palette-swap variants**, a **26-ID exact-source palette**, three composition recipes, and a **1320×280-cell** combined dry scene.

## Layout and art direction

Use dark Slate `49`, BasaltColumns `100` and Obsidian `101` for approximately 55% of visible mass; pale Marble `98`, LimestoneBlock `38` and GraniteBlock `40` for about 20%; Bronze `52`, BrassPanel `119`, GoldLeaf `118`, CopperPipe `69` and VerdigrisCopper `54` for 15% warm measuring hardware; and DarkGlass `72`, StainedGlass `55`, GlassBlock `120`, QuartzCrystal `122` and UraniumGlass `123` for 10% optical accents. Proportions are visual targets, not measured area statistics.

A composition should have one high silhouette (dome or needle), one rounded technical object (orrery), and one low sightline-resetting object (scriptorium or tablet). Place high features far enough apart to keep each reading independently. The three pack patterns—`broken-planetarium`, `meridian-corridor`, `underwater-records`—specify 18–30-cell nominal separations and designed sequencing; expand/contract these only after independent clearances. The 1320×280-cell gallery puts all modules bottom-aligned to baseline y=244 with 19-cell nominal gaps.

The combined scene chooses two inert variants: `pressure-bell-pool/dry-lens` and `sediment-almanac/fossilised-record`. The gallery is colour-stable in catalogue terms; its appearance is *not* a physical or Godot-rendered acceptance result. All original active materials remain in standalone prototypes.

## Flagship refinement — the fractured equator (6 November 2026)

The original eight stand-alone astronomical modules are now staged in a *single ruined longitude transept* rather than a flat row of unconnected specimens. Four separated dark masonry foundations give the building a deep lower register and distinct gaps; broken surveying lintels, seven scarred piers and disjoint clerestory windows connect observatory functions across the composition. A chipped, two-bezel **meridian calibration wheel** crowns the centre, with radial instrument rules and a subordinate western azimuth ring. Asymmetric submerged-looking limestone escarpments, failing survey stations, engraved serial markers, survey steles and mineral deposition provide authored intermediate and close-scale detail. Diminished-gold calibration ticks are sparse physical colour accents, not lamps.

The `combined_scene.backdrop_rectangles` (1207 ordered fixed stamps) are drawn **before** the eight unchanged dry module placements, and `combined_scene.foreground_rectangles` (81 fixed stamps) **after** them. This is authored material-cell paint order, **not** an importer, erase mask, real lighting, physical support, pressure, sea water, depth, or runtime performance evidence. All added IDs appear in the pinned source-verified palette with `movable=false` and `kernel=0`; the original two potentially active modules and their dry variants remain preserved. The existing eight standalone modules, all sixteen variants, three assembly recipes and anchors are unchanged.

The deterministic SVG now includes two separately labelled native-cell **2× source-colour crops**, one showing the central calibration rings and one the eastern survey ruin; neither is a Godot screenshot. The original preview remains recoverable from the parent commit. The enhanced real-source validator checks new stamp arrays, integer bounds and source-fixed material identity, with three additional negative mutations targeting the new fields.

**Open gates:** Compare all five existing gallery reference captures at comparable scales with independent human assessment; capture true Godot/native render; qualify host clearing, support and collision/actor clearance, Water/Brine/Salt/Dust originals at t=0/60/600, and measured stamp/native performance. The artistic superiority target is **not accepted**. Next useful C iteration: a meaningfully alternate processional-observatory arrangement, not another layer of scattered ornament.

## Flagship lower register — The Five Forgotten Astral Instruments (6 November 2026)

The first, 1320×280-cell *Night of the Submerged Equator* flagship now has five different genuinely **unstamped** stepped chambers excavated from its four former near-continuous basalt plinths. They form a navigational archaeology below, rather than a repeated row of dark window stickers: (I) a shattered eclipse camera with incomplete iris, (II) a jammed twin-weight gimbal calibration gauge, (III) a broken astronomical manuscript bindery, (IV) two incomplete optician's test lenses, and (V) a fractured tide chronometer and witness rule. Irregular stepped vault crowns, differing chamber widths, retained lintels, bearing piers, isolated optical registers, detached metal traces and granular foundation scars express age and structural load. Broken gold marks remain **material colour, not light**.

To create genuinely unpainted source cells rather than faux holes, fifteen staged excavation bands clipped both old backdrop and foreground stamps; the five chamber relics add **359** source-fixed native material rectangles. The backdrop goes **1207→1229** clipped pieces; the foreground becomes **431** shapes. A last-write-wins 1320×280 native-ID reconstruction finds **21,655** changed final cells, of which **16,223** previously painted cells are now blank; **0** previously blank cells receive new paint. The underlying eight reusable features, sixteen variants, three patterns, both placement sequences, and the previous eight-chamber alternate are retained unchanged.

The deterministic source-colour `preview.svg` now has **two additional 2× flagship undercroft crops** (west eclipse camera and east tide clock) beside the four existing alternate close studies. These pictures are dry, fixed-material proposal art only. Neither genuine host excavation nor structural stability, Water/Brine operation, optics, light, Godot presentation, actor clearance, performance, or visual superiority to the five reference galleries has been demonstrated. Independent matched-scale graphical and human comparison remains a HOLD gate.

## Native stamp contract

Coordinates are integer native cell positions, with (0,0) at top-left. `[x,y,width,height,material_id]` rectangles are half-open and ordered: **later rectangles overwrite earlier ones**, with no intermediate empty-pixel carving. Feature local origins are top-left; `anchor.point=[floor(width/2),height]` is the ground-alignment reference. Combined world placement is `origin` plus local stamp coordinates. No rotations, mirrors, scaling, negative shapes, semantic depth or per-feature native layers are supplied. The background of the SVG is framing only and stamps **no** cells. An importer must explicitly define cleared host terrain and destructive overwrite rules before use.

## Physics and interaction qualification matrix

| Scope | Relevant materials | Admissibility and open questions |
| --- | --- | --- |
| First six static modules | Fixed kernel-zero masonry, metal, glass | Catalogue-level static scenery candidates; apparent masonry support, actor passage through dome/bridge, occlusion and native/Godot performance **not tested** |
| Pressure Bell Pool (original) | Water `3` / Brine `24` | Water uses FreeMass; Brine uses CellularYield. Different conservation/flow behaviour. No sealed pressure, containment, buoyancy or volume claims. Tick in isolated fixtures before map admission |
| Sediment Almanac (original) | Salt `23` / Dust `14` | Mobile powders can fall, rearrange and leak; **not** stable suspended geometry. Require settlement/replay/performance measurements |
| Combined dry scene | Nonmoving, kernel-zero only after variants | Source-metadata classification only; native tick, collisions and rendering not observed |

No temperature source, controlled thermal process, growth, actual moving machinery, light emitter or functional celestial dial is contained in the designs. A gold glyph is a visible cell, not a powered light. Glass colour is not evidence of reflection/refraction.

## Reproduction / prospective future use

With a source checkout whose material header and shadow catalogue are pinned to the pack's source identities:

```sh
node docs/world-design/drowned-observatory/validate_pack.mjs --negative
node docs/world-design/drowned-observatory/render_pack.mjs --check
node docs/world-design/drowned-observatory/render_pack.mjs --write # intentional regeneration
```

Only authoring-side geometry/source identity and source-colour SVG were generated here; checked-in Node execution in a cloned checkout, native tick runs, Godot shader presentation, actor collision envelopes, CI and map-scale cost were **not** run. The execution container could not resolve github.com to clone a local workspace; this pack was authored against source read through the connected GitHub repository.

The next integration gate is a separately reviewed map stamp importer or editor palette with explicit host clearing, source compatibility, exact placement semantics and independent actor/physics validation. Reactive variants should become opt-in experiments, not default level decorations. No production map, gameplay, materials, solver or procedural generation integration is requested. Independent from PLAY, SOL, MAT-AUTH and IN-TOOLS.

## Prior work and differentiation

Other collections inspected: Lumen Fault #408, Chalkbone Coast #410, Carved Ice Choir #412, Ashroot Nursery #414, Emberglass Fumaroles #420, Silt Clockworks #425, Signal Orchard #430, Dust Meridian #434, Cathedral of Capacitors #437, Mirror Marsh #439. The distinguishing vocabulary here is *astronomical surveying and ruined planetary apparatus*, rather than wetland optics, electrical hardware or tidal controls. This remains a distinct Draft contribution.

## Alternate composition — The Broken Processional Meridian (6 November 2026)

The second 1320×280 native-cell *dry, fixed-material* study reconstructs a failed astronomical procession, rather than repeating the original longitude transept. Eight original modules are **reordered** around a central, deliberately interrupted double azimuth wheel; the former low-register sediment register now begins the approach, the shattered dome occupies the middle, and the worn meridian needle becomes a late eastern datum. Asymmetric cliff shoulders and stratified geological ledger courts flank a deliberately open central upper nave. Two separated stone datum-towers bear the wheel, interrupted high causeways cross from the flanks, and failed radial links, worn calibration ticks, cracked survey piers, graduated drop gauges and sparse damaged bronze registers locate the story at 1× and close-crop scales.

The alternate adds **1004 backdrop** and **77 foreground** ordered source-material rectangles; comparison with the original flagship's last-write-wins dry cell raster gives **172,929 of 369,600 cells different** and **62.4% unstamped air**. These are topology/coverage metrics, not subjective quality scores or physical performance results. All eight original modules, their sixteen variants, original first flagship and pattern recipes are preserved byte-for-byte within JSON values. Original dynamic Water/Brine and Dust/Salt modules are kept for isolated prototypes; the alternate uses existing fixed `dry-lens` and `fossilised-record` variants. The second scene is a *new design-only pack field*, not an engine importer contract.

Updated `render_pack.mjs` draws both 1× source-colour panoramas and two 2× alternate exact-cell crops in `preview.svg`; `validate_pack.mjs` source-checks the alternate placements, anchors, fixed materials and both rectangle layers, including eight new negative mutations. These renderings are *not* actual Godot images. Observed apparent supports, traversal, submerged ruins, glass/metal optical behaviour and performance remain untested. Full local Node subprocess execution, native/Godot captures, equal-scale comparison with the five existing PNG references and independent human acceptance remain required.

## Lower-register refinement — Eight chambers of the erased equator (6 November 2026)

The **alternate** *Broken Processional Meridian* now has eight unique genuinely **unstamped** stepped-arch chambers cut through the four formerly near-continuous basalt plinths, not simulated black voids. Their distinct functions are a six-gauge flood index, a broken theodolite store, a lettered ledger vault, a fractured transit stair, a recessional gate, an equinox cabinet, an interrupted witness register and a lost-star ledger. Asymmetrical voussoirs, chipped load-bearing jambs, interrupted datum traces, patinated joints and restrained gold inscriptions connect the buried rooms to the upper astronomical apparatus. Chamber-specific microdetails replace mechanically repeated ornament; the upper azimuth apparatus and first flagship are unchanged.

The edit adds **262** source-fixed foreground details and replaces the former **1004** backdrop rectangles with **1126** source-equivalent carved segments, leaving **10,190** previously painted cells genuinely unstamped. **13,356** final alternate material cells change; **100** previously blank cells receive deliberate work. These are geometry and native-ID colour-raster measurements, **not** aesthetic or performance acceptance. All **8 reusable modules, 16 variants, 3 recipes, first flagship** and dynamic original prototypes remain unmodified. The existing deterministic source-colour SVG shows both panoramas and its two original 2× alternate crops, but a future dedicated vault crop is desirable.

**Execution provenance:** The exact checked-in JavaScript validation and deterministic render functions, including the negative-mutation suite, were executed in an isolated V8 environment against the pinned source catalogue and enum. They were **not executed through the Node CLI**. No actual Godot shader output, fluid/physics behaviour, collision clearance or reference-gallery superiority is claimed. Next priority: matched-scale vault inspection, local Node qualification and source-matched Godot captures.

## The Last Alignment Tramway — ruined transit viaduct (6 November 2026)

The original *Night of the Submerged Equator* skyline now carries a ruined, asymmetric astronomical transit bridge: a silt-scoured western survey dock, four unequally elevated rail sections with **three missing spans**, load-braced stone bearings, fractured double-rim meridian instrument, a stranded optical carriage with severed counterweight lines, and an eastern calibration gate. Sparse brass datum marks, corroded rail joints, missing suspension members, damaged memorial tablets and different masonry courses are deliberately concentrated around this failed alignment apparatus. This is an integrated place, not a new collection or additional stand-alone stamp.

**Geometry custody:** 1567 source-fixed ordered backdrop rectangles; last-write-wins source-material comparison measures 16,103 changed visible cells, 13,305 newly painted, 0 formerly painted now unstamped, 9,761 changes above y=120. All eight original modules, sixteen variants, three composition patterns, both eight-module placement sequences, five flagship vaults and eight alternate vaults are retained. The deterministic SVG gains two 2× high-transit studies alongside the six existing studies. Prior preview recoverable at the parent commit. These are native-ID **source-colour geometry schematics, not Godot captures**. A broken cable is an illustration, not a tested cable; neither movement, optic reflection, structural support, host clearing, actor clearance nor water pressure is established.

**Actual source-bound V8 checks:** the checked-in parser/geometry/material validator, the original byte-exact renderer and amended deterministic renderer executed against the pinned native header and shadow catalogue: PASS (8 modules, 26 materials, 16 variants, 27/27 invalid mutations rejected; committed SVG generated deterministically). **Node CLI subprocess exit codes: not obtained** because the shell cannot resolve GitHub for a full checkout. Run `node docs/world-design/drowned-observatory/validate_pack.mjs --negative` and `node docs/world-design/drowned-observatory/render_pack.mjs --check` in a complete checkout. Real Godot/native, optical, physics, clearance, runtime performance and five-gallery matched-scale human acceptance remain untested.
