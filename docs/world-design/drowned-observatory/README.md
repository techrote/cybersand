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
