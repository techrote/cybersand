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
