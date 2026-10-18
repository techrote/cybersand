---
title: Reconstructed Strata Theatre integration validation
status: Current
document-kind: audit
scope: Fresh Windows evidence and preserved failures for the reconstructed depth branch integrated with actors, material effects, generation and showcase maps
canonical-for: []
last-reviewed: 2026-10-18
related-documents: [../systems/depth-layers-and-parallax.md, 2026-10-18-depth-parallax-prototypes.md]
---

# Reconstructed depth integration — 2026-10-18

Fresh implementation checkpoint `77971728b8821e5e1d3903a5e40e58c45d40e129`, branch
`codex/integrate-depth` published to PR #169. Its ancestry retains the original
reconstructed branch and the reconciled #164/#173/#175 feature heads. This is
new execution evidence, not retrospective certification of the unavailable
original local `4046cf0` object.

Windows Godot `4.7.stable.official.5b4e0cb0f`, GEN-002 Windows native DLL
`29140e5c8449ddf4a2013bfd2b2caeb92114421fb7ddbeda169e90b166f88c35`, retained
Rapier `4e26ffa78ec2aaff434c4a70cd2ec85288b10ba5237912c35f204cb1e6ed2180`.
No native compilation input or dependency pin is changed by the depth integration.

Fresh headless checks passed: `test_depth_layer_runtime` 83 checks,
`test_depth_compositor` 13 checks and `test_depth_lab` 17 checks. They cover
bounded native-world clocks/events, independent render canvases, ROI extent,
compositor inverse coordinates, rejected packets and lab lifecycle. Runtime
cost harness `measure_depth_layer_runtime.gd` completed both 30-warmup /
120-measured-update clock arms; its Windows result is retained locally and does
not replace the original local/Linux timing record.

Actual NVIDIA TITAN RTX / driver 581.80 / Compatibility OpenGL 3.3 execution of
`test_depth_surface_render` passed. It pauses before the first frame and checks
four nonempty, distinct 640 by 360 material surfaces and a one-shot far bake.
`capture_depth_lab.gd --depth-output=<local directory>` rendered five mode plates,
two camera views and rear destruction at 1600 by 1000. The corrected Hybrid
plate was visually inspected with all planes present. These are real GPU pixels,
not browser or lower-end GPU acceptance. Default cost/pacing remains prototype
scope with complete RG8 uploads on changed publication.

Preserved failures: the reconstructed `Compositor` preload name collided with a
native Godot class and prevented scene/test parsing. It is now `DepthCompositor`.
The original TextureRect inherited its 1024 by 1024 texture minimum instead of
the authored 640 by 360 ROI; it now explicitly ignores the texture minimum.
Pausing before the first draw disabled the foreground/rear/effects viewports,
leaving only the far city visible. Disabled/frozen planes now request one bake
on pause or a new publication. Each plane has its own World2D canvas. The pixel
regression first incorrectly expected the scene-facing UPDATE_ONCE property to
become UPDATE_DISABLED after rendering; it now checks one-shot configuration
and actual nonempty pixels. No historical assertions or timing hashes are rewritten.

Documentation metadata initially used unsupported `document-kind: subsystem`;
it is reconciled to `contract`, with explicit corpus/index routing. Portable
class-cache entries are registered. Documentation/repository/M11 and normal
exact-head hosted gates remain required before merge and are recorded in PR #169.
Local commands use 180-second focused test budgets; no long-lived scene process
from failed parsing was retained.
