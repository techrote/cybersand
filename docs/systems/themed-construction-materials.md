---
title: Themed construction material palette
document-kind: reference
canonical-for: [construction-material-ids, construction-material-physics-and-finish]
status: Current
scope: Complete stable IDs 38–80, authored roles, native hard-surface and combustion behavior, and visual limitations
last-reviewed: 2026-09-08
related-documents: [materials-and-rule-kernels.md, material-appearance-and-rendering.md, ../MATERIAL_LAB.md]
---

# Themed construction material palette

**Current:** all 43 project-authored materials at IDs 38–80 are immovable hard
surfaces. Forty-one are inert; Oak Timber and Thatch can burn through the existing
combustible kernel. Their names and finishes do not imply distinct calibrated
mechanics, chemistry, or real holes.

This is the authoritative ID/role/finish reference for the
[secured checkpoint](../operations/source-checkpoint-and-recovery.md).
Sources are [MaterialRules descriptors](../../native/include/cybersand/material.hpp),
[World kernels](../../native/src/world.cpp), and
[appearance LUTs](../../godot/scripts/material_appearance_lut.gd).
Dated tests and visual limitations are in the [evidence ledger](../reference/validation-evidence.md).

## Stable material catalogue

### Medieval, village, and castle materials

| ID | Stable name | Primary role | Physics | Flair |
|---:|---|---|---|---|
| 38 | Limestone Block | Keeps, curtain walls, pale dressed stone | Inert hard surface | Masonry courses |
| 39 | Sandstone Block | Warm walls, arches, carved trim | Inert hard surface | Masonry courses |
| 40 | Granite Block | Foundations, towers, dark heavy masonry | Inert hard surface | Masonry courses |
| 41 | Cobblestone | Roads, courtyards, rough walls | Inert hard surface | Rounded irregular cobbles |
| 42 | Mossy Cobblestone | Damp walls, drains, shaded paths | Inert hard surface | Cobble pattern plus moss-toned variation |
| 43 | Red Brick | Chimneys, kilns, later-period walls | Inert hard surface | Staggered brick courses |
| 44 | Lime Plaster | Rendered walls and interior surfaces | Inert hard surface | Broad mottling and sparse chips |
| 45 | Wattle and Daub | Cottage infill and patched walls | Inert hard surface | Plaster/daub mottling |
| 46 | Oak Timber | Frames, beams, doors, palisades | Hard surface; combustible | Grain, knots, condition-driven embers |
| 47 | Thatch | Cottage roofing and stacked straw | Hard surface; combustible | Diagonal fibres, condition-driven embers |
| 48 | Terracotta Tile | Roofs, floors, kiln surfaces | Inert hard surface | Overlapping tile courses |
| 49 | Slate | Roofs, damp paving, dark trim | Inert hard surface | Offset slate courses |
| 50 | Wrought Iron | Gates, bars, hinges, braces | Inert hard surface | Hammered matte metal; no sparkle |
| 51 | Lead Sheet | Flashing, gutters, roof details | Inert hard surface | Plate seams and rivets |
| 52 | Bronze | Statues, bells, decorated fittings | Inert hard surface | Hammered matte metal; no sparkle |
| 53 | Copper | Roofing, vessels, bright fittings | Inert hard surface | Hammered matte metal; no sparkle |
| 54 | Verdigris Copper | Aged roofing, drains, statues | Inert hard surface | Weathered hammered metal |
| 55 | Stained Glass | Chapel and great-hall windows | Inert hard surface | Coloured panes and dark leading |
| 56 | Packed Earth | Village paths, floors, embankments | Inert hard surface | Clods, grit, and low-frequency variation |

### Chemical factory, industrial, and alley materials

| ID | Stable name | Primary role | Physics | Flair |
|---:|---|---|---|---|
| 57 | Industrial Brick | Factory shells, alleys, furnaces | Inert hard surface | Dark staggered courses |
| 58 | Reinforced Concrete | Foundations, bunkers, loading bays | Inert hard surface | Clouding and aggregate flecks |
| 59 | Asphalt | Roads, roofs, dry alley floor | Inert hard surface | Fine aggregate |
| 60 | Wet Asphalt | Rain-dark road and reflective patches | Inert hard surface | Moving sparse wet glints |
| 61 | Wet Cobblestone | Old-city alley and drain surround | Inert hard surface | Cobble relief plus wet glints |
| 62 | Steel Plate | Tanks, walls, bulkheads, machinery | Inert hard surface | Plate seams, brushing, and rivets |
| 63 | Painted Steel | Doors, casings, coloured machinery | Inert hard surface | Plate seams, rivets, and paint chips |
| 64 | Corrugated Steel | Sheds, fences, ducting, cladding | Inert hard surface | Repeating ridges and joints |
| 65 | Rusted Steel | Abandoned machinery and decayed walls | Inert hard surface | Rust scale and pits |
| 66 | Steel Grating | Catwalks, drains, platforms | Inert hard surface | Dark openings and bright rails |
| 67 | Chainlink | Fences, cages, security screens | Inert hard surface | Diamond wire pattern |
| 68 | Steel Pipe | Process pipework and conduits | Inert hard surface | Cylindrical highlight and coupling bands |
| 69 | Copper Pipe | Chemical lines, cooling, utilities | Inert hard surface | Cylindrical highlight and coupling bands |
| 70 | Ceramic Tile | Wash-down walls, laboratory surfaces | Inert hard surface | Grout grid and glazed corner shine |
| 71 | Chemical Glass | Tanks, tubes, observation windows | Inert hard surface | Glass sheen plus low cyan edge emission |
| 72 | Dark Glass | Windows, screens, vehicle/factory glazing | Inert hard surface | Slow diagonal sheen |
| 73 | Rubber | Mats, seals, bumpers, hoses | Inert hard surface | Matte stipple |
| 74 | Cable Bundle | Exposed services and cyberpunk clutter | Inert hard surface | Colour-coded lanes and jacket highlight |
| 75 | Insulation | Pipe lagging and damaged wall fill | Inert hard surface | Diagonal fibres and sparse voids |
| 76 | Hazard Stripe | Guarding, floor edges, machine panels | Inert hard surface | Analytic black/yellow diagonals |
| 77 | Neon Cyan | Signs, tube lights, machine accents | Inert hard surface | HDR glow, subtle pulse, rare ballast fault |
| 78 | Neon Magenta | Signs, windows, nightlife accents | Inert hard surface | HDR glow, subtle pulse, rare ballast fault |
| 79 | Neon Amber | Warning lamps, industrial signs | Inert hard surface | HDR glow, subtle pulse, rare ballast fault |
| 80 | LED White | Panels, strips, laboratory lighting | Inert hard surface | Diode separators, quiet scan, HDR glow |

## Native physics and scheduling

All rows above are `MaterialState::Solid`, valid byte IDs, exposed through the
C API, and included by `MaterialRules::is_hard_surface`. That common predicate
connects native character queries, geometry extraction, and Rapier terrain.

The 41 inert descriptors select `RuleKernel::None`, zero state, and write
radius zero. They have no scheduled rule progression. This does not mean an
active mixed core cannot scan their cells or that painting/rendering/collider
preparation is free.

Oak Timber and Thatch select the existing radius-one `Combustible` family.
Unlit burn state is inactive; ignition can activate burn progression. Fungus and
Mite recognize Oak as timber in their existing bounded substrate/feeding rules.
The desktop fallback treats these IDs as static surfaces and lacks that native
combustion behavior.

Changes to hard-versus-non-hard occupancy update hard-surface revisions. Replacing
one inert hard material with another changes appearance but not collision
classification. Rapier rectangle count follows fragmented occupancy, not the
number of decorative material names in a contiguous wall.

The [material contract](materials-and-rule-kernels.md) owns cell layout, kernel
rules, and extension procedure. The [rigid-body contract](../architecture/rigid-body-and-cellular-coupling.md)
owns body/terrain coupling.

## Appearance boundaries

The finishes in the tables are presentation-only programs, with world-anchored
courses, seams, and grain. Timber/pipes currently read most clearly horizontally;
corrugation is vertical. Rough/hammered metals stay matte; smooth manufactured
surfaces can use restrained moving glints. Wet, glass, neon, and LED effects use
render time without changing physics or waking cells.

Selected finish arithmetic is separate from the common four-neighbor relief
stage. Neither creates a second world image or per-cell light. Exact LUT,
projection, shader, glow, and full GPU upload semantics belong to the
[appearance contract](material-appearance-and-rendering.md).

## Limits and authoring

- Chainlink and Steel Grating are visually perforated but collide as solid cells.
  Author actual holes as Empty at useful scale.
- “Wet,” “rusted,” “chemical,” “metal,” and “glass” names often describe authored
  appearance. The reactive base materials and the decorative catalogue do not
  share every chemical rule.
- A cell stores one material identity. Substrate plus independent paint, moss,
  grime, or decal layers are **Planned**, not represented by these rows.
- Orientation/variant state and generalized authoring tools remain **Planned**.
  Do not add per-cell CPU state solely for visual variation without a measured
  need and an approved representation.
- Shader compilation and scene/browser observations do not replace representative
  GPU profiling or manual approval of every finish.

Castle, village, factory, and alley composition recipes belong to
[Material Lab](../MATERIAL_LAB.md#construction-recipes). These are suggested
arrangements of Current materials, not prebuilt production content or guarantees
of realistic material science.
