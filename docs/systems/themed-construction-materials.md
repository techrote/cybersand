---
title: Themed construction material palette
status: Current
scope: Stable IDs 38–80, medieval and industrial construction roles, collision/combustion behavior, procedural appearance classes, performance boundaries, and scene recipes
keywords: [medieval village, castle, cyberpunk, chemical factory, alley, static solid, masonry, timber, neon, material ID, flair]
related-documents: [materials-and-rule-kernels.md, material-appearance-and-rendering.md, ../MATERIAL_LAB.md]
last-reviewed: 2026-08-28
implementation-state: Forty-three themed construction materials are compiled into the byte catalogue at IDs 38–80; all are static hard surfaces, Oak Timber and Thatch reuse the bounded combustible kernel, and GPU flair classes add deterministic texture plus bounded presentation-only animation.
---

# Themed construction material palette

## At a glance

- **Current**: IDs 38–56 provide 19 medieval/village/castle construction materials.
- **Current**: IDs 57–80 provide 24 factory/alley/cyberpunk construction materials.
- **Current**: all 43 are immovable hard surfaces and participate in character and Rapier terrain collision.
- **Current**: 41 inert materials use `RuleKernel::None`, remain asleep, and declare write radius zero.
- **Current**: Oak Timber and Thatch reuse `RuleKernel::Combustible`, project burn progress through the existing RG8 condition byte, and declare write radius one.
- **Current**: material identity remains one byte and authoritative cells remain four bytes.
- **Current**: appearance remains a 64×256 palette atlas plus four RGBA16F program texels per material.
- **Current**: procedural flair uses the previously reserved alpha component of program texel 3; it adds no texture sample, material field, light node, particle, or simulation rule.

## Search anchors

castle material IDs, medieval palette, village wall recipe, cyberpunk factory palette, alley material IDs, static solid cost, neon material, procedural flair class

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

## Physics and scheduling cost

Static construction material does not imply one scheduled rule per cell. For
the 41 inert materials:

- the immutable descriptor selects `RuleKernel::None`;
- `rule_is_active` rejects the cell before dispatch;
- maximum write radius is zero;
- no state byte is advanced;
- no optional field is allocated;
- the cell can sleep with its containing activity block;
- painting or destruction still marks ordinary dirty, wake, and hard-surface geometry revisions.

Oak Timber and Thatch are the only new active-capable descriptors. An unlit cell
also remains inactive because its projected/authoritative burn byte is zero.
Once ignited, both use the existing radius-one combustible state machine; no new
kernel family or scheduler phase was introduced.

The palette therefore expands scene vocabulary without making a settled castle
or factory proportional to the number of decorative material types it contains.
Rapier collider cost remains geometry-dependent: a highly fragmented mosaic may
produce more merged rectangles than a large continuous wall even though both
are asleep in the cellular scheduler.

## Appearance grammar

The material program stores a small integer flair class in texel 3 alpha. The
palette shader already fetched this texel for emission colour, so selecting a
finish adds no sampler access. Each finish is a bounded analytic branch using
world coordinates, material ID, and simple arithmetic. Most use `fract`,
`step`, `smoothstep`, and an arithmetic hash; there are no loops or neighbour
samples.

Stable variation and all architectural seams remain anchored in world space, so
camera motion does not cause texture swimming. Wet glints, glass sheen, smooth
manufactured-metal glints, liquid/fire/molten flow, neon ballast variation, and
LED scan use render time. Rough and hammered metals intentionally remain matte.
Those animations are presentation-only and never enter replay hashes, dirty
tracking, activity, collision, or material reactions.

m9 adds a common four-neighbour relief stage after the selected finish. Exposed
top/left structural edges receive a restrained highlight, bottom/right edges a
shadow, liquids receive a surface lip, and empty cells immediately beneath hard
material receive a one-cell contact shadow. The stage reads the same immutable
RG8 world texture already displayed; it does not infer physics, allocate a
normal map, or change collider geometry. This makes masonry courses, castle
silhouettes, pipes, panels, grating, glass tanks, and alley structures read with
more depth while preserving their authored pixel edges.

The current directional assumptions are deliberately simple:

- timber grain and pipes read most clearly when authored horizontally;
- corrugated ridges are vertical;
- roof courses, slate, masonry, ceramic, and plate seams are world-aligned;
- a future orientation/variant projection may replace these assumptions only
  if real authored scenes demonstrate that the existing world-space grammar is
  insufficient.

## Scene recipes

### Castle wall and gate

- Granite Block foundation and lower courses.
- Limestone or Sandstone Block wall faces.
- Cobblestone or Packed Earth yard.
- Oak Timber doors and Wrought Iron hinges/gatework.
- Lead Sheet flashing, Slate roof, and Stained Glass highlights.
- Mossy Cobblestone only near drains, shaded bases, and damaged sections to
  avoid uniform green noise.

### Timber village house

- Oak Timber structural frame.
- Wattle and Daub or Lime Plaster infill.
- Thatch or Terracotta Tile roof.
- Cobblestone threshold and Packed Earth path.
- Red Brick chimney around existing Fire/Smoke materials.

### Chemical processing bay

- Reinforced Concrete shell and Ceramic Tile wash-down zone.
- Steel Plate tanks with Painted Steel access panels.
- Steel/Copper Pipe networks, Cable Bundle services, Rubber seals, and
  Insulation runs.
- Chemical Glass inspection sections beside existing Acid, Toxic Sludge,
  Mercury, Oil, Steam, Foam, and Water materials.
- Steel Grating catwalks, Hazard Stripe edges, and amber/white task lighting.

### Rainy cyberpunk alley

- Industrial Brick walls over Wet Asphalt or Wet Cobblestone.
- Rusted Steel doors, Corrugated Steel shutters, Chainlink fencing, exposed
  pipes, cable bundles, and intermittent insulation.
- Cyan/magenta neon used as narrow accents rather than large filled areas; the
  half-resolution bounded glow pass supplies the halo.
- Existing Smoke, Steam, Water, Oil, Toxic Sludge, Spark, and Fire provide the
  moving/reactive layer without inventing decorative duplicates.

## Known limits

- The cellular world stores one material identity per cell; paint, grime,
  decals, moss overlays, and substrate cannot yet coexist in one cell.
- Chainlink and grating are visually perforated but remain solid collision
  cells. True holes must be authored as Empty cells at useful scale.
- The current chemical interactions were not broadened for every decorative
  alloy, glass, ceramic, or polymer. Visual identity must not be mistaken for a
  complete corrosion/material-science model.
- Procedural flair cost has shader-compile and scene-smoke coverage, but manual
  GPU profiling on target hardware is still required before freezing quality
  presets.

## Related documents

- [Materials and rule kernels](materials-and-rule-kernels.md)
- [Material appearance and rendering](material-appearance-and-rendering.md)
- [Material lab](../MATERIAL_LAB.md)
