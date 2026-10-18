---
title: Material appearance and rendering
document-kind: contract
canonical-for: [material-visual-projection, palette-program-appearance, render-upload-cost]
status: Current
scope: Native RG8 presentation, palette/program LUTs, shader flair, temporal smoothing, glow, and current GPU upload limitation
last-reviewed: 2026-10-18
related-documents: [themed-construction-materials.md, materials-and-rule-kernels.md, ../architecture/rendering-and-gameplay-bridges.md, ../architecture/item-authored-material-programs.md]
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
implements 45 non-neutral flair classes through bounded analytic branches.
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

**Approved owner intent:** preserve Oil's wave character, distinguish liquid
motion, use restrained glints on smooth/manufactured metals, and leave rough/
hammered metals matte. World-anchored texture must not swim with the camera.
Appearance, flicker, and dither must not affect conservation, collision, sleeping,
or replay.

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
thirteen-sample source and thirteen-tap near/far additive composite derive
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
