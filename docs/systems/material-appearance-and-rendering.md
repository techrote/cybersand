---
title: Material appearance and rendering
status: Current
scope: Presentation-only visual-state projection, palette/program LUTs, procedural flair classes, deterministic variation, bounded animation, dirty render patches, temporal smoothing, and glow
keywords: [material appearance, RG8, LUT atlas, flair, procedural texture, medieval, cyberpunk, HDR, glow]
related-documents: [themed-construction-materials.md, ../architecture/rendering-and-gameplay-bridges.md, materials-and-rule-kernels.md, ../operations/profiling-observability-and-performance.md]
last-reviewed: 2026-09-08
implementation-state: Dirty RG8 material/condition patches drive a 64×256 palette, unchanged four-texel program rows, 42 bounded procedural flair classes, four-neighbour relief, temporal smoothing, and dual-radius HDR glow; authoritative cells remain four bytes.
---

# Material appearance and rendering

Source anchors: [appearance projection](../../native/include/cybersand/material_appearance.hpp),
[native snapshot adapter](../../godot/native_extension/cyber_native_cell_world.cpp),
[desktop worker](../../godot/scripts/simulation_worker.gd),
[renderer](../../godot/scripts/main.gd), and
[Web controller](../../godot/scripts/web_demo_controller.gd). The
[2026-09-08 audit](../audits/2026-09-08-documentation-audit.md) records source
identity and dated validation; m9 cost comparisons below remain historical.

## At a glance

- **Current**: native cells remain four authoritative bytes; no visual seed or final RGB value was added to simulation state.
- **Current**: RenderBridge projects each material to `material_id` plus one read-only condition byte.
- **Current**: a 64-column palette LUT uses stable world-coordinate hashing for deterministic material variation.
- **Current**: a four-texel-per-material RGBA16F program LUT controls tint, response range, value, alpha, HDR emission, and one integer flair class in the previously reserved channel.
- **Current**: 42 analytic flair classes cover construction finishes plus powders, Smoke, Steam, Foam, organics, Ice, reactive liquids, Mercury, charged Metal, and Cloner circuitry.
- **Current**: four nearest-neighbour reads from an alias of the existing RG8 world texture derive directional solid bevels, liquid surface lips, and one-cell ambient contact shadow; no second world image or upload exists.
- **Current**: atlas construction multiplies the authored `VALUE_VARIATION` by 1.18, with small material-limited hue variation compiled once at startup; this is a source constant, not a measured m6 visual comparison.
- **Current**: Water coverage, condition colour, and emission are presentation-only and never feed back into physics, activity, or replay.
- **Current**: native publication clears captured dirty state into immutable leases; the desktop worker separately retains copied unacknowledged patches, with bounded full-refresh recovery.
- **Current**: Godot patches a persistent RG8 CPU image, then ping-pongs two textures for temporal interpolation.
- **Current**: emissive materials feed one half-resolution thirteen-sample source and a thirteen-tap dual-radius additive composite; no per-cell `Light2D` nodes are created.
- **Current**: liquid flow bands and wet/glass/smooth-metal/neon/LED animation read presentation time only and never affect replay, dirty state, collision, or sleeping.
- **Planned**: true GPU subregion texture writes and an artist-facing appearance-graph compiler.

## Search anchors

physics-driven colour, material LUT, condition channel, RG8 render texture, dirty render patch, visual program, HDR emission, downsampled glow

## Separation from authoritative physics

Authoritative `Cell` state remains material ID, two material-defined state bytes,
and update epoch. `material_appearance.hpp` selects either zero, `state_a`, or
`state_b` as the one-byte visual condition for each material. This projection is
copied after authoritative mutation and has no write path back into World.

The update epoch is deliberately excluded. It tracks solver execution and may
wrap or clear, so treating it as a visual seed would make settled appearance
depend on scheduler history. Variation instead hashes stable world coordinates
and material ID in the shader.

## Current compact render contract

| Channel | Meaning | Examples | Authority |
|---|---|---|---|
| R | byte-sized material ID | Water, Fire, Metal | Copied authoritative identity |
| G | material-selected condition | Water mass, Fire/Smoke lifetime, Wood/Coal burn, Metal charge, Cement cure, Steam/Foam lifetime, Molten Glass heat | Read-only presentation projection |
| World coordinate | stable variation input | grain, masonry seams, roof courses, rivets | Renderer-derived only |
| Program texel 3 alpha | integer flair class | cobble, corrugation, wet, neon | Immutable presentation program |
| Render time | bounded animation phase | wet glint, glass sheen, neon pulse | Presentation only; never authoritative |

Materials that do not yet expose a meaningful condition project zero. The RG8
layout is intentionally a presentation contract, not a promise that every
future material must fit all physics into one state byte. Optional native fields
may later be reduced to a bounded render projection without exposing those
fields directly to Godot.

## Palette and bounded appearance program

`material_appearance_lut.gd` builds two immutable textures at startup:

- a 64×256 RGBA8 palette atlas whose rows are serialized material IDs and whose
  columns are deterministic value/saturation variants;
- a 4×256 RGBA16F program texture whose row stores tint/blend, condition range,
  value response, alpha response, emission response, emission colour, and an
  integer flair selector in the formerly reserved final alpha component.

The shared palette shader performs a fixed number of samples and common
operations. Fire, Wood, Lava, Oil, Steam, Coal, Metal, Cement, Spark, Molten
Glass, Foam, Oak Timber, Thatch, Chemical Glass, Neon, and LED materials have
explicit profiles. Water uses its projected mass for render-only coverage.
Materials without condition/emission profiles use neutral program curves.

Flair selection reuses the program texel already fetched for emission. Each
selected material branch is bounded and texture-free: it uses world-coordinate
arithmetic, an arithmetic hash, presentation time, and early return. After that
branch, the common relief stage performs four nearest-neighbour material-ID reads
through `current_world_texture`, which aliases the CanvasItem's already-uploaded
RG8 texture. There are no shader loops, per-cell lights, decals, particles,
normal maps, additional world images, or new render textures.

Static structural patterns are world anchored. Oil, Acid, Paste, Slush, Brine,
Cement, Toxic Sludge, Mercury, and Water add a cheap `TIME` phase to existing
triangle-wave bands; this adds no texture sample, neighbour read, loop, or
authoritative update. Rough and hammered metals deliberately have no sparkle.
Smooth plate, painted metal, corrugated sheet, and pipework instead receive
masked manufactured glints that stay away from seams or outside their profile.
Smoke alpha/value now fades from its projected lifetime.

The m9 extension specializes GPU presentation further without changing a
material descriptor or authoritative cell:

- Smoke and Steam combine two slowly counter-moving triangle-wave fields for
  wisps/curls; their alpha remains condition-aware where native RG8 exposes it.
- Foam draws hashed bubble rims whose visibility collapses with its projected
  lifetime.
- Acid and Toxic Sludge carry rising chemical rings and rolling bands; Mercury
  uses travelling mirror bands and rare pin highlights.
- Sand/Dust/Salt/Sodium/Gunpowder receive clustered grain facets; Plant/Fungus/
  Seed receive fibres/nodes; Ice receives intersecting facets and a cold sheen.
- charged Metal adds condition-scaled crawling arcs over manufactured plate;
  Cloner gains a scanning circuit lattice.
- Fire, molten materials, Spark, Neon, LED, and general viscous flow now combine
  more than one bounded arithmetic wave to avoid visibly repeating one pattern.

Time-dependent glint, sheen, flow, scan,
and rare neon ballast variation are intentionally presentation-only. They may
differ at a particular rendered frame without changing authoritative replay.
See [Themed construction materials](themed-construction-materials.md) for exact
ID-to-flair mappings and directional authoring assumptions.

This program texture is a bounded compilation target for a future appearance
graph. The current profiles are authored in GDScript; there is no user-facing
graph editor, graph serialization format, or general compiler yet.

## Dirty publication and upload

The native extension requests immutable dirty patches at render cadence. Each
patch carries world rectangle, byte offset, row stride, and tightly packed RG8
cells. The worker retains and appends unacknowledged patches so a slower renderer
cannot silently skip intermediate changes. If pending data exceeds the bounded
limit, a complete RG8 recovery packet supersedes it.

That retention/acknowledgement loop is the desktop `CyberSimulationWorker`
handoff. Web performs `take_render_snapshot()` and validated patch consumption
synchronously on Godot main, requesting a full refresh after rejection. The
threaded Web profile does not introduce an asynchronous render consumer or
permit rendering to read mutable World storage.

Godot applies those patches to a persistent CPU `Image`. The current
`ImageTexture` path then calls `update(image)`, so GPU transfer remains a full
1024×1024 RG8 texture for each published changed frame. Therefore:

- native-to-GDScript snapshot bytes are dirty-region proportional;
- CPU reconstruction touches dirty rectangles rather than rebuilding all cells;
- GPU upload bytes are still full-frame and remain a profiling target.

Telemetry reports patch count and copied patch KiB. It must not be interpreted
as GPU upload byte count until a renderer-specific subregion path is implemented.

## Temporal smoothing and glow

Two RG8 textures are ping-ponged when a render snapshot arrives. The palette
shader blends selected moving materials from the prior snapshot to the current
snapshot. This changes presentation only; the cellular/character simulation
target remains 60 ticks/s. Slow ticks and Web collider backlog can reduce actual
progress, so independently configured cadence is not a guaranteed wall-clock rate.

HDR output is enabled for the 2D canvas. A half-logical-resolution SubViewport
samples emissive material programs with a fixed thirteen-tap two-radius
footprint. The full-resolution additive composite takes thirteen linear-filtered
near/far samples and retains a compact hot core. It reuses the one existing glow
texture and introduces no CPU publication or simulation state. `G` toggles both
the overlay and its SubViewport updates. This is a visual glow, not an
authoritative heat or lighting field.

## m9 GPU cost envelope

The ordinary palette path adds four RG8 neighbour samples per displayed
fragment. During snapshot transitions the palette may evaluate both old and new
materials, so that bounded relief cost may also be evaluated twice. The glow
source rises from nine to thirteen low-resolution world/program samples, and the
composite rises from one to thirteen filtered samples. At the default 320×180
logical view the emission source is only 160×90; the composite and palette run
over the aspect-fitted display area.

This checkpoint intentionally spends available GPU bandwidth/ALU rather than
CPU time or bridge bandwidth. It does not claim a target GPU time because the
hosted headless driver compiles shaders but does not expose representative GPU
timing. Target hardware should compare `G` on/off and m8/m9 at 1920×1080 before
setting a production quality tier.

## Current limitations and next work

- **Planned**: use a supported renderer path for actual texture subregion writes
  and measure total GPU upload cost against the present full RG8 update.
- **Planned**: project temperature, pressure, mixture, wetness, or other optional
  fields only after their authoritative representations exist.
- **Planned**: bake item/material appearance graphs into the existing palette and
  bounded-program textures, with validation limits and resource versioning.
- **Planned**: expose artist-authored curves/LUT assets without allowing visual
  data or frame-time noise to affect physics.
- **Planned**: profile worst-case mixed-flair screens on target GPUs and expose
  quality/accessibility controls for animated glint and flicker if required.
- **Ambiguous**: final HDR/glow quality, downsample factor, and accessibility
  settings require visual and GPU profiling on target hardware.

## Related decisions

- [Rendering and gameplay bridges](../architecture/rendering-and-gameplay-bridges.md)
- [Item-authored material programs](../architecture/item-authored-material-programs.md)
- [Materials and rule kernels](materials-and-rule-kernels.md)
- [Themed construction materials](themed-construction-materials.md)
- [Profiling and observability](../operations/profiling-observability-and-performance.md)
