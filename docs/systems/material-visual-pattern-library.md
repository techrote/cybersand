---
title: Material visual pattern library
status: Current
document-kind: reference
scope: Design and algorithm reference for presentation-only material patterns — primitives, pipeline stages, recipes, per-material specifications, authoring and procedural-development workflow, and lessons learned
canonical-for: [material-visual-patterns, procedural-material-algorithms, material-pattern-authoring-workflow]
last-reviewed: 2026-10-18
related-documents: [material-appearance-and-rendering.md, themed-construction-materials.md, ../reference/material-effects-register.md, ../reference/product-intent-and-priorities.md, ../audits/2026-10-18-material-readability-pass.md]
---

# Material visual pattern library

**Current:** every material is drawn by the
[palette shader](../../godot/shaders/material_palette.gdshader) from the
immutable RG8 presentation stream (R = material ID, G = one material-selected
condition byte) plus world coordinates and presentation time. Nothing on this
page changes simulation state, wakes cells or adds per-cell objects or lights.
The [appearance contract](material-appearance-and-rendering.md) owns semantics
and cost; this page is the **design and algorithm reference** for authoring a
pattern for a specific material or developing a new procedural algorithm. The
[effects register](../reference/material-effects-register.md) tracks what is
implemented, planned and only considered.

Visual references are actual framebuffer readbacks from
[`capture_material_review.gd`](../../godot/tests/capture_material_review.gd),
retained under
[`material-readability-2026-10-18/`](../audits/material-readability-2026-10-18):

| Plate | What it shows |
|---|---|
| [All static materials, labelled](../audits/material-readability-2026-10-18/detail/statics_pass_annotated_t1.37_glow.png) | Every static material as a block, a 3-wide bar and a 3-tall strip |
| [Shape plate](../audits/material-readability-2026-10-18/detail/shapes_structured_pass_t1.37_glow.png) | Pipes, hazard, cables, planks, corrugation, neon and stained glass in several run shapes |
| [Contact plate](../audits/material-readability-2026-10-18/detail/reactions_volume_pass_t1.37_glow.png) | Depth shading, lava/water, acid on solids, burning timber, rim light, soft gas edges |
| [Emission/atmosphere plate](../audits/material-readability-2026-10-18/detail/emission_still_cam0-0_t1.37_glow_b1.00.png) | Fire, lava, spark, charge, neon, LED, smoke, steam, foam at several condition values |
| [Liquid trays](../audits/material-readability-2026-10-18/detail/liquids_still_cam0-0_t1.37_glow_b1.00.png) | Water, Oil, Paste, Slush, Brine, Cement, Mercury, Acid, Sludge, Lava |
| [Full inventory](../audits/material-readability-2026-10-18/detail/inventory_still_cam0-0_t1.37_glow_b1.00.png) | All 81 rows (labels: [labelled sheet](../audits/material-readability-2026-10-18/candidate/inventory_labelled.png), earlier pass) |

## Which inputs may a pattern use?

| Input | Meaning | Rule |
|---|---|---|
| `material_id` | Stable serialized ID | Selects the branch; never derive speed or style arithmetically from the ID value |
| `condition` (G / 255) | One material-selected byte; meaning per material in [`material_appearance.hpp`](../../native/include/cybersand/material_appearance.hpp) | Use only with its real meaning (lifetime, burn progress, charge, cure remaining, heat, Water mass). Zero-projected materials must not depend on it |
| World pixel | Cell coordinate in the world | All lattices anchor here, so texture never swims with the camera |
| Neighbour IDs | Four cardinal cells from the snapshot being shaded | Shared once per evaluation; drives edges, contact and relief |
| Run extent | Same-material run length in each direction, probed at 1, 2, 3, 5 and 8 cells | Only materials in `uses_structured_fill`; capped at 8 |
| `presentation_time()` | Engine `TIME` or the fixture override | Decorative phase only, never presented as physical flow or velocity |

Rendering is per output pixel. At the default 320×180 logical view in a
1920×1080 window, each cell is evaluated 36 times, so every texture read and hash
is multiplied accordingly. Budget reads before arithmetic.

## Pipeline stages

1. **Palette and program LUT**
   ([`material_appearance_lut.gd`](../../godot/scripts/material_appearance_lut.gd)):
   - the base colour variant is selected by a stable hash;
   - the condition curve scales value, tint and alpha;
   - HDR emission is added;
   - an integer flair ID is stored in program texel 3 alpha.
2. **Neighbour gather.** Four reads from the snapshot being shaded (previous or
   current), shared by the stages below.
3. **Finish:**
   - Most materials run their **flair** branch in `apply_material_flair`, keyed by flair ID.
   - Materials accepted by `uses_structured_fill` run **`apply_structured_fill`** instead, using `region_extent`.
4. **Volume and contact** (`apply_volume_and_contact`):
   - liquid depth (three upward reads, liquids only);
   - exposed surfaces;
   - soft gas edges;
   - neighbour reactions;
   - emitter rim light.
5. **Relief** (`apply_neighbour_relief`):
   - bevel light and shadow on solids;
   - liquid lips;
   - contact shadow and ambient occlusion in Empty cells.
6. **Temporal crossfade.** Only changed displayed IDs where either side is
   temporally smoothed. Each side uses its own snapshot.
7. **Ambient particles** (`apply_ambient_particles`), in Empty cells only:
   - embers above hot or burning cells;
   - fumes above Acid and Toxic Sludge;
   - steam leaking from pipe runs.
8. **Glow.** A separate half-resolution
   [emission pass](../../godot/shaders/material_emission.gdshader) plus the
   additive [composite](../../godot/shaders/glow_composite.gdshader), toggled by `G`.

## Primitive toolkit

| Primitive | Signature | Use | Cost |
|---|---|---|---|
| `cheap_hash` | `float(vec2)` | Stable per-cell or per-lattice randomness | ~10 ALU |
| `stable_pixel_hash` | `float(vec2, int)` | Per-material palette variant | 1 hash |
| `triangle_wave` | `float(float)` | Periodic ramps: courses, seams, ridges, stripes | trivial |
| `value_noise` | `float(vec2)` | Smooth organic fields | 4 hashes |
| `fbm3` | `float(vec2)` | Three-octave billows, crust plates, flames | 12 hashes |
| `heat_ramp` | `vec3(float)` | Black-body red → orange → yellow → white, never above 1 | trivial |
| `lattice_particle` | `vec2(vec2 p, cell, density, salt)` | One pixel particle per lattice cell; animate by offsetting `p` with velocity × time; returns hit and per-particle hash | 3 hashes |
| `manufactured_glint` | `float(vec2, speed)` | Rare travelling glint on approved smooth metals | 1 hash |
| `drip_streak` | `float(vec2, up, salt)` | Stain hanging from a top edge, hashed column and length | 2 hashes |
| `run_length` / `region_extent` | `vec4` up, down, left, right | Orientation, cross-section, edge distance | ≤16 reads |
| `is_open_cell`, `is_emitter`, `emitter_light`, `is_fuel`, `is_hot_source` | — | Neighbour classification for edges, contact and particles | trivial |
| `apply_burn` | `vec4(vec4, pixel, condition)` | Char and ember veins from burn progress | ~2 noise |
| `swirl_field` | `float(vec2 p, t, speed)` | Domain-warped flow for liquid bulk: pseudorandom eddies, never straight bands | 5 noise |
| `field_contours` | `float(field, count, width)` | Thin curved contour lines of a smooth field (marbling, veins, slick rainbow) | trivial |
| `corrosion_field` | `vec2(vec2, up_bias)` | Rust coverage and deep-pit mask: blotches, gravity-stretched spills, pits | 7 noise |
| `cell_field` | `vec3(vec2, size, seed)` | Jittered 3×3 cellular field: distance, border gap, owner hash (leaves, crystals, stones, chips) | 18 hashes |
| `wood_grain`, `wood_knot`, `board_layout` | — | Flowing late-wood bands, knots with ring swirl, staggered board lanes | 2 noise |
| `block_courses` | `vec2(vec2, size, seed)` | Running-bond seams and per-block hash | 1 hash |
| `BuildGeometry` / `default_build_geometry` | struct | Run geometry for the building catalogue, or a fixed panel without the probe | — |

## Recipe catalogue

Each recipe is a reusable algorithm with a canonical example in the shader.

### Periodic tilings (static)

- **Running bond (brick, ashlar):** row = floor(y / h). Offset x by half a unit on alternate rows. Mortar where the local x or y coordinate is under the joint width.
- **Offset courses (slate, roof tile):** shorter rows, with a lip gradient inside each tile.
- **Grids (plates, ceramic, LED diodes, grating):** `mod(pixel, size)` seams. Rivets are a disc at a fixed local position.
- **Diagonal bands (hazard):** `step(0.5, fract((x + y) / period))`.
- **Diamonds (chainlink):** the minimum of two `mod(x ± y)` distances.
- **Truchet arcs (Cloner):** pick one of two arc orientations per tile by hash. A trace is drawn where the distance to either quarter-circle is small. Pulses travel as `fract(diagonal - t)`.

### Noise fields

- **Billows (Smoke, Steam):** `fbm3` advected by `(drift.x · t, rise · t)`, a smoothstep threshold into alpha, and a rim band where the second noise sits between two thresholds.
- **Crust plates (Lava, Molten Glass):** the `fbm3` level picks crust or melt. Seams are `1 − smoothstep(|plates − 0.5|)`. Heat comes from a churn field plus the seams.
- **Caustics (Water):** `|noise_a − noise_b|`, with the two fields moving in different directions. Lines appear where they are near equal.
- **Hairline cracks (concrete, ice, asphalt):** `1 − smoothstep(0, w, |value_noise(p / s) − 0.5|)`.
- **Ember veins (burning fuels):** two summed noise distances give branching veins. They are coloured by `heat_ramp` with a slow pulse over a char base.

### Particle lattices

- **Rising embers and sparks:** offset `p` by `(sin sway, speed · t)`. A one-cell tail is checked at `p − (0, 1)`. Flicker with `sin(t · k + hash · 60)`.
- **Bubbles (Water, Acid fizz, Chemical tank):** slower and denser lattices inside the liquid. Brighten towards the tint.
- **Soot and condensation (Smoke, Steam):** sparse dark or bright particles that raise alpha locally.
- **Ambient particles in Empty cells:** run the arithmetic test first. Only a candidate pixel reads at most three cells below to find a source (hot, reactive or pipe). Most Empty pixels pay no read.

### Shape-aware fills (static unless noted)

- **Orientation:**
  - A run is horizontal when `long_x ≥ long_y`.
  - A direction that reached the 8-cell probe counts as "long" (99). Without this, large panels flip orientation near their edges.
  - Large panels in both directions use a per-material default.
- **Cross-section:** `across_u = (near-edge distance + 0.5) / across_span`. Use it for cylinder shading (`sqrt(1 − (2u − 1)²)`), a specular at u ≈ 0.3, and a neon core at u = 0.5.
- **Along features:** flanges, ties, joints and collars every N cells of the world-anchored along coordinate.
- **Thin strips (≤5 cells):** switch pattern families, for example hazard chevrons, balusters or conveyors.
- **Edges:**
  - `edge = min(extent)` gives trim, frames, bezels and rivet rows.
  - `top_open` and `bottom_open` (using `is_open_cell`) give caps, moss, grass, ridges, eaves, icicles and fringes.
- **Weathering:** `drip_streak(up)` hangs stains, patina, rust bleed or bloom from top edges.
- **Carving:** setting `alpha = 0` on edge cells makes ragged thatch fringes, icicle teeth and rust perforations. The background shows through; physics is unchanged.
- **Voronoi leading (stained glass):** a 3×3 neighbourhood of jittered sites. A lead line is drawn where `second − nearest` is small. Jitter is limited to keep panes large.

### Contact and volume effects

- **Depth:** sample three cells straight up for the same liquid; depth is the count ÷ 4. Water deepens towards navy. Molten material gets hotter with depth.
- **Exposed surfaces:** when the cell above is not liquid, liquids get animated froth and molten material gets a dark skin with bursts.
- **Soft boundaries:** for gases and foam, the number of matching neighbours reduces alpha at the edges. Fire cools at its edges.
- **Contact reactions:**
  - Molten material flashes against Water, Brine, Slush and Ice.
  - Water boils beside heat.
  - Acid and Sludge fizz against solids.
  - Fire flares against fuel.
- **Rim light:** solids and powders next to emitters add `emitter_light(id)` in the emitter's colour.

### Emissive colour

- **Never clip a structured emitter.** Rebuild the colour from its hue (`rgb / max(rgb)`) and apply structure on top: neon striations and core.
- **Drive flames from heat:** use `heat_ramp(heat)` instead of tint plus emission. Very bright LUT emission (LED) can drown a display in bloom; LED emission was halved for this reason.

## Per-material specifications

Material families and their current recipes. "Motion" lists only deliberate
animation. Static materials are time-independent and asserted by
[`test_material_presentation_render`](../../godot/tests/test_material_presentation_render.gd).

| IDs | Material | Recipe | Inputs | Motion |
|---|---|---|---|---|
| 3, 24 | Water, Brine | Ripple, glints, caustic net, micro-bubbles, depth, froth; Brine adds fixed salt motes; boils beside heat | condition = mass (coverage), neighbours, depth | yes |
| 16 | Oil | Smooth slick, `swirl_field` eddies phased by `OIL_WAVE_RATE`, contour-line iridescence, flames when burning | condition = burn | yes |
| 20, 30 | Paste, wet Cement | Heavy matte clumps, slow swell; Cement aggregate, swell ∝ cure remaining | Cement condition = cure remaining | slow |
| 21 | Slush | Icy granules, twinkling crystals, meltwater shimmer | — | slow |
| 12, 32 | Acid, Toxic Sludge | Swirling eddies, rising bubbles, fizz layer, froth, fumes above, etching fizz; sludge deep green with dark depths and filaments | neighbours | yes |
| 33 | Mercury | Swirled fake environment map, contour highlights, pin speculars | — | yes |
| 8, 36 | Lava, Molten Glass | Crust plates, glowing seams, pops, depth heat, surface skin, water flashes | Molten Glass condition = heat | yes |
| 6 | Fire | `fbm3` tongues on a heat ramp, edge cooling, sparks, flare on fuel, embers above | condition = lifetime | yes |
| 34 | Spark | Twinkle, crackling white core | condition = lifetime | yes |
| 4, 22, 37 | Smoke, Steam, Foam | Billows with rims and soot / plumes with glints / bubble rims, speculars and pops; soft edges | condition = lifetime | yes |
| 2, 14, 23, 25, 26, 27 | Powders | Clustered grains, facets, rare glints; burning Coal glows | Coal condition = burn | rare glint |
| 11 | Plant | Cellular leaves, midribs, stems, sway; grass/flowers above and vines below in Empty cells | condition = energy | sway |
| 18 | Fungus | Mycelium web, fruiting knots, pulses; mushrooms above and hyphae below in Empty cells | — | yes |
| 19 | Seed | Fibres and nodes | — | — |
| 15 | Mite | Iridescent glistening chitin | — | yes |
| 17 | Rocket | Striped casing; flying (condition ≥ 1) white-gold core, bloom, sparks around | condition = flight | yes |
| 28 | Metal | Charged arcs and arc sparks; seams and machined edges | condition = charge | when charged |
| 1, 31, 58 | Wall, Concrete, Reinforced Concrete | Block or formwork seams, lit caps, drips; tie holes and exposed rebar | run extent | — |
| 38–40 | Limestone, Sandstone, Granite | Ashlar with caps, quoins and drips; bedding / flecks | run extent | — |
| 41, 42 | Cobblestone, Mossy | Cobble relief, polished tops, moss on open tops and joints | run extent | — |
| 43, 57 | Red / Industrial Brick | Running bond, chips and grime, soldier course, quoins | run extent | — |
| 44, 45 | Lime Plaster, Wattle and Daub | Spalling reveals brick / half-timbered posts, rails and braces | run extent | — |
| 46, 7 | Oak Timber, Wood | Planks along the run, staggered joints, nails (Oak), burn veins | run extent, burn | when burning |
| 47 | Thatch | Course strokes, ridge binding, ragged fringe | run extent, burn | when burning |
| 48, 49 | Terracotta, Slate | Tile courses, ridge cap, eave shadow, lichen | run extent | — |
| 50 | Wrought Iron | Balusters with collars and finials (thin); hammered plate with rivets (wide) | run extent | — |
| 51 | Lead Sheet | Standing seams, white bloom, dressed edges | run extent | — |
| 52–54 | Bronze, Copper, Verdigris | Hammered metal, patina runs, polished or rubbed edges | run extent | — |
| 55 | Stained Glass | Voronoi leaded panes with lead border | run extent | — |
| 56 | Packed Earth | Strata, grassy top | run extent | — |
| 59–61 | Asphalt, Wet Asphalt, Wet Cobblestone | Grain and tar-sealed cracks / substrate under a fixed film and puddle sheen | run extent | — |
| 62, 63 | Steel Plate, Painted Steel | Seams, rivets, scratches, rivet rows, grime gradient; chips and rust runs | run extent | sparse glint |
| 64 | Corrugated Steel | Ridges along the sheet run, laps, rust streaks | run extent | sparse glint |
| 29, 65 | Rust, Rusted Steel | `corrosion_field` blotches, flaking scale, spill runs, clustered pits; steel spills from edges/seams | run extent | — |
| 81–131 | Building catalogue | Per-ID `apply_building_finish`; see the [building catalogue](building-material-catalogue.md) | run extent, burn | glints, glitter, phosphor |
| 66, 67 | Grating, Chainlink | Bars or diamonds with frame / posts | run extent | — |
| 68, 69 | Steel / Copper Pipe | Cylinder shading, flanges with bolts, couplings, patina; steam leaks | run extent | leaks |
| 70 | Ceramic Tile | Grout grid, glaze shine, bullnose trim | run extent | — |
| 35, 71, 72 | Glass, Chemical Glass, Dark Glass | Fixed sheen, frames, mullions / tank with fill line and bubbles / reflected lit windows | run extent | tank |
| 73 | Rubber | Conveyor belt with ribs and rollers (thin); tread plate (wide) | run extent | conveyor |
| 74 | Cable Bundle | Round cables, ties, fibre-optic pulses | run extent | pulses |
| 75 | Insulation | Quilted batts, stitched seams, foil on exposed faces | run extent | — |
| 76 | Hazard Stripe | Diagonal stripes with trim; chevrons on strips; worn paint | run extent | — |
| 77–79 | Neon | Hue-rebuilt tube, centred core, plasma flow, rare ballast fault | run extent | yes |
| 80 | LED White | Bezel, diode grid, generative scrolling display | run extent | yes |
| 5 | Cloner | Truchet circuit traces with pulses | run extent | yes |
| 9 | Ice | Facets, fixed sheen, fractures, frozen bubbles, frosted top, icicles | run extent | — |
| 10 | Invalid | Magenta, no finish (must stay visibly invalid) | — | — |

## How do I design a pattern for one specific material?

1. **Read its condition meaning.** Check
   [`material_appearance.hpp`](../../native/include/cybersand/material_appearance.hpp)
   and the owner preferences in
   [product intent](../reference/product-intent-and-priorities.md#which-material-behavior-should-changes-preserve).
2. **Decide motion.** Still scenery stays time-independent. Animate only fluids,
   gases, fire, molten or burning material, and deliberate manufactured effects.
3. **Compose from the recipes above.** Prefer the existing primitives.
   - Static detail: world-anchored hashes and noise, no time term.
   - Slow motion: use smooth low-amplitude modulation. Never move a thresholded
     edge at sub-pixel speed.
4. **If it depends on shape**, add it to `uses_structured_fill` and branch in
   `apply_structured_fill`, using `horizontal`, `across_u`, `along`, `edge`,
   `top_open` and `drip_streak`.
5. **Capture** the inventory, `statics`, `shapes`, `reactions` and a mixed scene
   with the fixture, using `--shader-root` to render the previous revision. Then
   review at 1080p, not only enlarged.
6. **Add or extend a pixel assertion** (stillness, orientation, condition
   response), and **measure** with
   [`measure_material_presentation_cost.gd`](../../godot/tests/measure_material_presentation_cost.gd).
7. **Record it** in the [effects register](../reference/material-effects-register.md)
   and update the [construction catalogue](themed-construction-materials.md)
   finish column if it is a construction ID.

## How do I develop a new procedural algorithm?

- **Start as a pure function** of (pixel, extent, neighbours, condition, time)
  that returns a mask or colour. Keep it world-anchored and deterministic per pixel.
- **Bound the reads.** Do the arithmetic gating first, and read texels only for
  candidate pixels; the ambient-particle stage is the model. Reuse the neighbour
  gather.
- **Prove shape behaviour on synthetic plates.** Try thin and thick runs in both
  orientations, open and buried edges, L-joints, and panels larger than the
  8-cell probe.
- **Prove motion** with the 90-frame, 1×, glow-off sequence in `temporal.json`
  (changing fraction per region), and check the heatmap for unintended crawl.
- **Prove cost** with matched interleaved blocks and a named metric (per-viewport
  GPU time). Expect each `fbm3` to cost about 12 hashes per output pixel.
- **Gate it.** Expensive shape-aware work should stay behind `structured_detail`
  (the quality-tier hook).

## Lessons learned and anti-patterns

**Second pass (2026-10-18):** straight travelling `triangle_wave` bands read as
hatching on large liquid areas; domain-warped fields read as fluid. Hash blocks
(`floor(pixel / 3)`) read as a chequerboard on corrosion; layered noise reads as
organic. A single-cell emitter can fall between half-resolution glow samples, so
the emission centre takes the 2×2 maximum. Luminous materials must not rim-light
their own interior or they saturate to white. Leaves on a fixed lattice read as a
grid; a jittered cell field reads as foliage.

- **Sub-pixel crawl:** a thresholded line moving at under one cell per second
  steps visibly. That was the original glass/ice sheens; make such features
  static or use smooth modulation.
- **ID-derived speed:** `id mod 5` produced arbitrary liquid speeds. Use named
  presentation constants (`OIL_WAVE_RATE`).
- **Shared finish hides identity:** Slush and Brine were indistinguishable under
  one "wet" flair. Give each family its own recipe.
- **HDR clipping:** emission added before structure clips hot cores to a flat
  block. Use a heat ramp or rebuild from hue.
- **Capped-extent orientation flip:** comparing capped spans directly makes
  concentric artefacts. Treat a capped direction as long.
- **Region-anchored coordinates:** `pixel − extent` is not a region origin once
  extents cap. Anchor to world coordinates and use extents only for edges and
  cross-section.
- **Decoration that reads as a glitch:** rare red valve wheels looked like errors
  and were removed. Thick Voronoi leading formed black voids; jitter and lead
  width must suit the cell size.
- **Noise as fire:** small-scale crack thresholds read as glitter. Larger veins
  over a char base read as burning wood.
- **Old-neighbourhood relief:** the old side of a crossfade must sample its own
  snapshot.
- **Claims of identity:** state pixel identity only for captured samples on the
  tested GPU.
