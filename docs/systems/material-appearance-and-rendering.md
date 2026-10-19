---
title: Material appearance and rendering
document-kind: contract
canonical-for: [material-visual-projection, palette-program-appearance, render-upload-cost]
status: Current
scope: Native RG8 presentation, palette/program LUTs, shader flair, temporal smoothing, glow, and current GPU upload limitation
last-reviewed: 2026-10-19
related-documents: [material-visual-pattern-library.md, ../reference/material-effects-register.md, themed-construction-materials.md, materials-and-rule-kernels.md, ../architecture/rendering-and-gameplay-bridges.md, ../architecture/item-authored-material-programs.md]
---

# Material appearance and rendering

**Current:** native material identity and one derived condition byte form an
immutable RG8 presentation stream. GPU shaders create variation, animation,
relief, and emission without changing physics. CPU patch copies are dirty-region
proportional, but each changed GPU texture update still uploads the full 1024²
RG8 image. True GPU subregion writes are **Planned**.

This page owns appearance and cost semantics at the
[secured checkpoint](../operations/source-checkpoint-and-recovery.md).
The [render bridge](../architecture/rendering-and-gameplay-bridges.md) owns payload
lifetimes; the [evidence ledger](../reference/validation-evidence.md) distinguishes
headless checks, browser observations, and absent representative GPU profiling.

## Current visual projection

The optional [Neon Reliquary district backdrops](../operations/neon-reliquary-demo.md#presentation-and-ownership)
use the same accepted current/previous textures to fill only empty space with
distant scenery. It masks current cells, unfinished material transitions and the
sampled player. The top tile retains its original cyan atmosphere; lower tiles
progress through warm residential haze, utility teal and swamp green. This changes
none of the material palette/program, condition projection,
emission or glow behavior described here.

[Blacksite Nine](../operations/blacksite-nine-demo.md) adds two scene-specific
passes over the same immutable textures: an Empty-space industrial backdrop,
and multiplicative exposure with an eight-sample recess shadow for occupied
cells. Both use absolute world coordinates, including neighbouring cells beyond
the current camera frame. They introduce no camera-relative parallax, per-tile
tint or time-dependent grain. This keeps the treatment continuous across all
twelve tile boundaries. The grade preserves the sampled player and leaves
instrument glass and LEDs comparatively bright. It does not alter material
identity, collision, native rules, the base palette or the glow source. Both
passes are disabled when scene variants admit rigid bodies, whose masks they do
not own. **Depth & haze** controls these scene passes. The guide and
[dated audit](../audits/2026-10-18-blacksite-nine.md) distinguish actual pixel
checks from unmeasured hardware performance.

[project_visual_state](../../native/include/cybersand/material_appearance.hpp)
selects zero, `state_a`, or `state_b` for each material. No visual seed or RGB
field enlarges the four-byte authoritative Cell.

| Input | Meaning | Examples |
|---|---|---|
| RG8 R | Material ID | Water, Smoke, Metal |
| RG8 G | Material-selected condition | Water mass; Fire/Smoke lifetime; Wood/Oil/Coal burn; Metal charge; Cement cure |
| World coordinates and ID | Stable presentation variation | Grain, courses, seams, rivets |
| Presentation time | Presentation-only animation | Liquid bands, Oil waves, neon pulse |

The update epoch is excluded: visual appearance must not depend on scheduler
history. Condition projection is not a promise that future physics must fit in
one byte. Future fields may supply bounded projections only after their
authoritative semantics exist.

The desktop GDScript fallback publishes R8 material IDs without the native
condition channel. Native Web uses RG8, including its single-worker compatibility
profile.

### Water Feel Lab presentation modes

**Current, experiment-only:** issue #19 can derive four discrete Water coverage
levels from the immutable normalized RG8 condition byte. An optional local 3x3
gradient orients the partial fill for strong edges; weak, ambiguous and unsupported
cases fall back to horizontal coverage. Synthetic positive/negative cases and an
actual OpenGL pixel test establish the bounded behavior. Presentation switching
preserves authoritative state and does not select a new production renderer.
The [completion record](../audits/2026-09-12-issue-19-water-feel-lab.md#v1-result-derived-four-level-presentation)
records exact evidence and unmeasured GPU-cost limits.

## Palette and bounded program

[CyberMaterialAppearanceLut](../../godot/scripts/material_appearance_lut.gd)
builds a 64×256 RGBA8 palette and a 4×256 RGBA16F program texture at startup.
Palette rows follow material IDs; variants derive from stable coordinates.
The program describes tint/blend, condition range, value, alpha, emission
response/color, and an integer flair selector in texel 3 alpha.

The [material palette shader](../../godot/shaders/material_palette.gdshader)
implements 50 non-neutral flair classes through bounded analytic branches.
Their selected finish uses arithmetic, hashes, and optional presentation time;
it adds no per-cell object, particle, light, or physics field. The common relief
stage then reads four neighbors from the same already-uploaded world texture
to derive structural highlights/shadows, liquid surface lips, and contact shadow.

Animated branches read one `presentation_time()` helper. Its
`presentation_time_override` uniform (also on the
[emission shader](../../godot/shaders/material_emission.gdshader)) defaults to
negative, which keeps engine `TIME`; capture fixtures set the same non-negative
sample on both passes so paired images share an exact phase.

Water mass determines render-only coverage. Smoke/Steam use wisps; Foam uses
condition-dependent collapsing rims; powders, organics, and Ice have distinct
grain/fibre/facet programs. Reactive liquids and Mercury have chemical/mirror
bands; Metal charge drives arcs and Cloner has circuitry.

### Wet and liquid families

**Current since 2026-10-18:** the former shared wet finish is split by family
(`FLAIR_OIL`, `FLAIR_PASTE`, `FLAIR_SLUSH`, `FLAIR_WET_SURFACE` in the
[LUT](../../godot/scripts/material_appearance_lut.gd)). Oil keeps its approved
wave/streak pattern at the named `OIL_WAVE_RATE` (the same expression it
previously derived from its ID); Paste and wet Cement use heavy matte clumps with a very
slow settle, Cement's settle scaled by its cure-remaining condition; Slush shows
icy granules in slowly shifting meltwater; Brine uses the Water finish plus fixed
salt motes; Wet Asphalt/Cobblestone keep their solid substrate under a fixed,
world-anchored film. These phases are decorative presentation, not measured flow.
Glass, Chemical Glass, Dark Glass and Ice sheens are time-independent so still
glazing stays still.

**Current since the 2026-10-18 detail pass:** shared `value_noise`/`fbm3`,
`heat_ramp` and `lattice_particle` helpers drive richer animated finishes
(heat-ramped Fire and Lava, advected Smoke/Steam, Water caustics, Oil
iridescence, burn-progress embers, striated neon) and presentation-only pixel
particles. `apply_ambient_particles` draws embers above hot or burning cells and
fumes above Acid/Toxic Sludge in Empty cells; a candidate particle reads at most
three cells below it. Particles are lattice-anchored in world space and never
become per-cell objects, lights or simulation state. They raise the measured
world-pass GPU cost (see the review record).

`material_colour` gathers the four neighbour IDs once per evaluated snapshot and
shares them between `apply_volume_and_contact` and the structural relief.
That stage adds liquid depth shading (three extra upward reads for liquid pixels
only), exposed-surface froth/skin, soft gas and foam boundaries, neighbour
contact effects (molten/water flashes, boiling, acid fizz, fire flaring on fuel),
emitter rim light on adjacent solids and soft ambient occlusion in Empty cells.

Shape-aware construction fills (`uses_structured_fill`, `region_extent`,
`apply_structured_fill`) give pipes, hazard stripes, insulation, cables, timber,
corrugation, stained glass, neon, brick, tile and reinforced concrete
orientation, cross-section and edge treatment from a bounded per-direction run
length (at most 16 extra reads, those materials only). Since the fourth
iteration this covers Wall, Cloner, Wood, Ice, Metal, Concrete, Glass and every
construction ID 38–80. They remain time-independent apart from cable data
pulses, neon plasma, pipe steam leaks, the Chemical Glass tank bubbles, the
Rubber conveyor, the LED display and Cloner trace pulses. The
`structured_detail` uniform (default 1) disables them as a quality-tier hook. The
[2026-10-18 review](../audits/2026-10-18-material-readability-pass.md) records the
paired captures and limits. The
[construction catalogue](themed-construction-materials.md) owns exact themed
ID-to-finish mappings.

**Approved owner intent:** distinguish liquid motion, use restrained glints on
smooth/manufactured metals, and leave rough/hammered metals matte. **Owner
direction 2026-10-18 (second pass):** slowly scrolling hatched bands read badly,
especially on Oil and Mercury bulk; liquid bulk should swirl pseudorandomly. This
supersedes the earlier "preserve Oil's wave character" preference for the bulk
pattern; Oil keeps its named `OIL_WAVE_RATE` as the swirl phase and its
iridescence. World-anchored texture must not swim with the camera.
Appearance, flicker, and dither must not affect conservation, collision, sleeping,
or replay.

### Second fidelity pass (MAT-002)

**Current since 2026-10-18 (pass 2):**

- **Swirling liquid bulk.** `swirl_field` (two slow warp noises bending `fbm3`)
  and `field_contours` replace the travelling `triangle_wave` bands of Oil, Mercury,
  Water ripple, Acid/Toxic Sludge, Paste/Cement swell and Slush meltwater. Oil
  suppresses per-cell dither and draws its rainbow along curved contours.
- **Organic corrosion.** `corrosion_field` (blotches, gravity-stretched spill runs,
  clustered pits) replaces the 3×3 hash blocks of Rust and Rusted Steel scale;
  Rusted Steel spills from top edges and seams and only perforates inside corrosion.
- **Living finishes.** `FLAIR_PLANT` draws jittered cellular leaves, midribs and
  stems with a slight sway; `FLAIR_FUNGUS` a mycelium web with fruiting knots and
  bioluminescent pulses; `FLAIR_MITE` thin-film iridescence with glistening
  highlights; Seed keeps `FLAIR_ORGANIC`.
- **Growth decor in Empty cells.** `apply_growth_decor` (quality uniform
  `growth_decor`, default 1) draws grass tufts, flowers and leaves above Plant and
  Moss Wall, mushrooms (some bioluminescent) above Fungus, and vines/hyphae hanging
  beneath them. A selected sprout group scans its centre column (≤ 6 reads,
  45% of groups); hanging growth scans its own column (≤ 5 reads, 32% of
  columns). Both scans stop at the first occupied cell. It never alters material
  cells or simulation; the quality hook leaves occupied pixels unchanged.
- **Fireworks.** `FLAIR_ROCKET` stripes idle Rockets and turns any flight state
  (condition byte ≥ 1) into a flickering white-gold core with HDR emission; Empty
  cells beside a flying Rocket show coloured sparks (≤ 4 reads for lattice
  candidates). The emission source takes the brightest of the 2×2 cells its
  half-resolution texel covers. The 2026-10-19 review corrected its block origin:
  a fragment's UV denotes the centre of that block, whose lower-right cell is
  not the first cell. The shader now derives the footprint and block origin
  explicitly, retaining one-cell sampling in full-resolution fixtures. Actual
  pixel checks exercise all four single-cell positions, image edges, camera
  offsets, an idle Rocket and a Spark.
- **Steam and Smoke.** Steam is near-white (`0xE6EEF2D8`, mirrored natively) and
  denser; Smoke's last lifetime thins from the wisps inward. A presentation-only
  **vapour afterimage** ([material_vapour_trail.gdshader](../../godot/shaders/material_vapour_trail.gdshader),
  `setup_vapour_trail_pipeline`/`update_vapour_trail` in [main.gd](../../godot/scripts/main.gd))
  ping-pongs two half-float view-sized SubViewports once per rendered frame. Each
  keeps the brighter of current Steam/Smoke coverage and the reprojected, risen,
  bilinearly diffused previous frame, decayed with 0.42 s / 0.65 s e-folding times;
  the palette draws the remainder over Empty cells. It reads the same immutable
  snapshot and continues fading while simulation is paused. Elapsed presentation
  time is not clamped to a simulation-step limit, so long frames also dissipate
  old history. Capture fixtures leave `vapour_trail_strength` at 0.

  Both viewport generations are initialized and resized together. Resetting the
  view size invalidates both histories, avoiding a lost second frame or stale
  history when switching back to an earlier size. Camera changes reproject the
  existing history in world coordinates; samples outside its footprint contribute
  nothing. `set_vapour_trail_enabled(false)` stops both viewport updates and sets
  palette strength to zero; re-enabling starts from current gas. This persistent
  quality hook remains separate from the user-facing glow control.

  The desktop owner's `render_world_generation` is retained with the exact
  render bytes. An accepted upload from a new World/reset generation clears the
  trail. Ordinary full-image refreshes preserve it, including every R8 fallback
  publication and native transport resyncs. The R8 shader uses a neutral lifetime
  because that format carries no condition byte. See the
  [bridge contract](../architecture/rendering-and-gameplay-bridges.md).
- **Building catalogue.** `FLAIR_BUILDING` selects `apply_building_finish` by
  material ID for IDs 81–131 using the run probe (or a fixed panel geometry
  when `structured_detail` is 0). The 2026-10-19 review places that finish at one
  dispatch site per `material_colour` evaluation, preserving the same geometry
  while avoiding duplication of the large catalogue branch at every ordinary
  flair-helper call during driver inlining. Luminous building materials do not rim-light
  their own interior. The [building catalogue](building-material-catalogue.md)
  lists each finish.
- **Colour intent.** Toxic Sludge is a deeper, darker green (`0x2B6A22`, mirrored
  natively) with dark depths and oily filaments.

These are presentation-only. Evidence, cost and limits are in the
[original dated record](../audits/2026-10-18-material-fidelity-pass-2.md) and
[2026-10-19 review and validation](../audits/2026-10-19-mat002-review-and-validation.md).
The latter records real software-rendered pixel checks, source-matched native
and fallback owner checks, the software shader-compiler memory failure and its
dispatch repair. Software-rendered correctness does not establish target-GPU
performance or owner visual acceptance.

## Dirty bytes versus GPU upload

[CyberNativeCellWorld](../../godot/native_extension/cyber_native_cell_world.cpp)
copies published RG8 patches. [Desktop worker](../../godot/scripts/simulation_worker.gd)
retention/acknowledgement prevents a slow consumer losing intermediate updates;
bounded full refresh replaces excessive pending copies. The
[Web controller](../../godot/scripts/web_demo_controller.gd) consumes synchronously
and requests a full refresh after rejection. Pthreads do not create a mutable
render read path.

[main.gd](../../godot/scripts/main.gd) validates patches and updates a persistent
CPU Image, then calls `ImageTexture.update(image)`. At 1024² RG8 this uploads
2,097,152 bytes for each changed publication, even for a small dirty patch.
Patch count/copied KiB therefore measures bridge work, not GPU upload traffic.
No second mutable world image is introduced by shader neighbor sampling.

## Temporal smoothing and glow

Two RG8 textures alternate on accepted snapshots. The shader may evaluate
previous and current material appearance during transitions. Only pixels whose
displayed material changes and where either side is temporally smoothed are
crossfaded. **Current since 2026-10-18:** each side's neighbour relief reads its
own snapshot (same four reads), so `snapshot_blend` 0 and 1 reproduce the
previous and current snapshot alone for those pixels. The emission pass reads
only the latest snapshot; halo changes are not crossfaded. **Current desktop
default:** publication targets 60 Hz; `H` cycles the retained 30/45/60 Hz
presentation modes. The desktop simulation remains independently fixed at 60 Hz;
changing publication cadence does not change its simulation timestep. The compact
desktop HUD reports both the configured publication target and a measured effective
publication rate when samples are available. Overload and Web terrain backlog can
reduce actual progress.

HDR 2D output supports one half-logical-resolution glow SubViewport. Its
sixteen-cell source (a 2×2 maximum plus twelve surrounding samples) and
thirteen-tap near/far additive composite derive
emission from the existing presentation inputs. This is a visual halo, not an
authoritative heat/light field. `G` disables both its overlay and updates on
desktop and Web; `set_glow_enabled` in [main.gd](../../godot/scripts/main.gd)
owns that state for input, initialization and Web level restore (before
2026-10-18 Web `G`/restore flipped only the flag);
other controls are in [Material Lab](../MATERIAL_LAB.md).

## Historical cost comparison and remaining evidence

The retained m9 description records a source change from nine to thirteen
glow-source samples and from one to thirteen composite samples, plus four
neighbor reads in the ordinary palette. A transition can evaluate relief for
both old and new materials. At the desktop default 320×180 logical view the
glow source is 160×90. These are algorithmic sample counts, not measured GPU
milliseconds. The m9 record supplied no representative target-GPU timing.

**Planned:** actual texture subregion writes; target-GPU comparisons with glow
on/off and mixed-flair scenes; quality/accessibility controls as needed; and
artist-authored assets or an appearance graph compiled into bounded programs.
Current profiles are authored in GDScript. No general graph editor, serialized
graph schema, orientation channel, or compiler exists. Final HDR/downsample/
animation policy remains open until visual and performance evidence supports it.
