# Dust Meridian — World-feature collection 008

**DRAFT; design-only. Do not merge.** A ruined desert-navigation system: cardinal obelisk, half-buried gateway, silent wind harp, star cairn, crystallized compass, terraced windbreak, sand clock and dust archive. Unlike Signal Orchard's electrical groves or Silt Clockworks' tidal machinery, this collection uses geology, spatial bearings and long, empty desert horizons.

![Eight modules and one assembled dry environment](preview.svg)

## Exact source and staging contract

Accepted `main`: `ba9cbc89029be88b812af59b19e5c59829bbcd90`, tree `3af18f50e6094776263119623b64a1b2f4ca0ab2`. Native material enum blob `dcf05895da3015a2e999e3d1cbbae0fdc7fe32b3`; material catalogue shadow blob `d7a47d60721598a16589daf177a6ff4401b84b43`; interaction header blob `b70fc9dc2599f648e5374f06e4cc0ae9cb868d79`. The current catalogue's material IDs, source RGBA, kernel, mobility and initial state are included in `pack.json`. **The shadow is metadata, not a replacement for the native runtime authority.**

Integer native cells; top-left origin, +x right / +y down; ordered half-open `[x,y,width,height,material_id]` rectangles with later paint over earlier paint. Matches the *primitive arguments* of `godot/scripts/demo_worlds.gd::_rect`, but this is **not** a CYSD save, admitted importer or engine/editor scene. Each stamp anchors at bottom-centre; combined scene seam y=244. No layers, scaling, automatic rotation, mirroring or permission to clear host cells. Clear all intended negative-space cavities only after authoring import/ownership design is accepted.

## Visual identity and combination rules

Ocher SandstoneBlock **39**, RammedEarth **109** and PackedEarth **56** dominate, with TerracottaTile **48** on wind-cut edges. Slate **49**/Obsidian **101** provide recessed openings; Bronze **52**/BrassPanel **119**, QuartzCrystal **122**, Marble **98** and GoldLeaf **118** mark sightlines. Fixed RockSaltBlock **106** is *not* loose Salt **23**. Target ~70% warm stone/earth, 20% dark structural patterning, 10% white/quartz/gilt details. Alternate one tall silhouette with at least one low marker; preserve gaps between wind strings and gateway posts. Do not imply actual sound, power, shadow-based timekeeping or aerodynamic shielding.

| Module | Size (native cells) | Function | Runtime hypothesis |
|---|---:|---|---|
| `meridian-needle` | 116×120 | dominant cardinal zero | fixed-kernel dry candidate |
| `half-buried-waygate` | 136×108 | broken pedestrian-looking arch | fixed-kernel candidate; collision NOT measured |
| `wind-harp-pylons` | 122×122 | five graduated string towers | fixed-kernel candidate; no audio/wind |
| `starfall-cairn` | 108×86 | low wayfinding rest | fixed-kernel dry candidate |
| `salt-compass-register` | 126×96 | circular mineral survey register | fixed-kernel candidate; wet contact untested |
| `dune-weir` | 142×84 | low serrated barrier | fixed-kernel candidate; no wind effect |
| `sand-clock` | 116×120 | granular hourglass | dynamic Sand **2**, kernel **1** |
| `dust-scriptorium` | 126×98 | dispersing dust inscriptions | dynamic Dust **14**, kernel **12** |

**Variants and scene:** Each module has two substitution variants (16 total), with precisely ordered geometry, anchors, clearance guidance and neighbour rules. The single **1320×280-cell** `Latitude of Broken North` composition places all eight at explicit coordinates, using `petrified-hour` (Sand **2** → SandstoneBlock **39**) and `chalk-inscription` (Dust **14** → fixed ChalkBlock **99**); its other six modules are source-fixed. `ChalkBlock` can still respond to Water; "fixed" is not a claim of global chemical inertness. `dune-weir:adobe-rampart` uses water-reactive AdobeBrick **102**. Dry scene substitutions are visually representational, not recorded granular volumes.

**Repeatable patterns:** `broken-survey-line` (Needle → Cairn → Salt Compass, >=20 cell gaps), `pilgrim-threshold` (Waygate → Harp → Weir, >=22), and `sediment-archive` (Weir → Sand Clock → Scriptorium, >=24; fixed variants mandatory). Do not stamp active source versions into general maps.

## Physical limitations and integration requirements

- **Static scenery candidates:** all combined-scene materials have source `movable=false`, `kernel=0`, but can still participate in pair reactions. Avoid claiming permanent static behavior in thermal, acidic or wet hosts. The broad dry scene floor is a staging sketch only.
- **Evolving modules:** Sand and Dust are movable powders; source alone cannot establish retained shape, mass conservation in cavities, settlement duration, oscillation, erosion or dispersal. Isolate each in a native fixture and record exact source, cell counts and tick timing.
- **Performance risk:** the pack contains 194 local material rectangles and 12 terrain rectangles; dense repeats plus mobile particles may increase kernel and contact costs. No frame/tick measurement performed.
- **Authoring admission gates:** specify negative-space clearing authority, material-ID compatibility, persistence format, rotation policy, collision/player clearance, actor spawn exclusion, tile-edge stitching, thermal and wet interactions, runtime fixtures, shader captures and a deterministic import/export receipt. Avoid importing production maps directly from this draft.
- **Presentation:** `preview.svg` is source-colour vector geometry; it is NOT a native or Godot screenshot.

## Reproduction

```sh
node docs/world-design/dust-meridian/validate_pack.mjs docs/world-design/dust-meridian/pack.json materials/catalogue/catalogue.json --negative
node docs/world-design/dust-meridian/render_pack.mjs docs/world-design/dust-meridian/pack.json docs/world-design/dust-meridian/preview.svg --check
```

The generation-side V8 validation executed successfully with **18** exact catalogue materials, **194** rectangles, **16** variants, **8** fixed scene placements and 12/12 invalid-input mutations rejected. Checked-in Node scripts, native simulation, Godot renderer, collision tests, performance and hosted CI have **not** been executed.

**Open questions:** should a future importer clear entire bounds or a separately versioned negative-space mask? Should visual-only powder substitutions be marked explicitly in map palettes? What wet-host exclusion/rule evaluation is appropriate for Chalk and Adobe?

Next candidate themes: **Cathedral of Capacitors**, **Mirror Marsh**, **Drowned Observatory**. No gameplay, native code, materials or canonical map modified.
