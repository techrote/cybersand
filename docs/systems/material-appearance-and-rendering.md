---
title: Material appearance and rendering
document-kind: contract
canonical-for: [material-visual-projection, palette-program-appearance, render-upload-cost]
status: Current
scope: Native RG8 presentation, palette/program LUTs, shader flair, temporal smoothing, glow, and current GPU upload limitation
last-reviewed: 2026-09-08
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
| Render time | Presentation-only animation | Liquid bands, wet glints, neon pulse |

The update epoch is excluded: visual appearance must not depend on scheduler
history. Condition projection is not a promise that future physics must fit in
one byte. Future fields may supply bounded projections only after their
authoritative semantics exist.

The desktop GDScript fallback publishes R8 material IDs without the native
condition channel. Native Web uses RG8, including its single-worker compatibility
profile.

## Palette and bounded program

[CyberMaterialAppearanceLut](../../godot/scripts/material_appearance_lut.gd)
builds a 64×256 RGBA8 palette and a 4×256 RGBA16F program texture at startup.
Palette rows follow material IDs; variants derive from stable coordinates.
The program describes tint/blend, condition range, value, alpha, emission
response/color, and an integer flair selector in texel 3 alpha.

The [material palette shader](../../godot/shaders/material_palette.gdshader)
implements 42 non-neutral flair classes through bounded analytic branches.
Their selected finish uses arithmetic, hashes, and optional presentation time;
it adds no per-cell object, particle, light, or physics field. The common relief
stage then reads four neighbors from the same already-uploaded world texture
to derive structural highlights/shadows, liquid surface lips, and contact shadow.

Water mass determines render-only coverage. Smoke/Steam use wisps; Foam uses
condition-dependent collapsing rims; powders, organics, and Ice have distinct
grain/fibre/facet programs. Reactive liquids and Mercury have chemical/mirror
bands; Metal charge drives arcs and Cloner has circuitry. The
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
previous and current material appearance during transitions. Configured
publication cadence is separate from target fixed-step simulation rate;
overload and Web terrain backlog can reduce actual progress.

HDR 2D output supports one half-logical-resolution glow SubViewport. Its
thirteen-sample source and thirteen-tap near/far additive composite derive
emission from the existing presentation inputs. This is a visual halo, not an
authoritative heat/light field. `G` disables both its overlay and updates;
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
