---
title: Depth/parallax prototype record
status: Current
document-kind: evidence
scope: 2026-10-18 Strata Theatre implementation, original local validation and remote reconstruction boundary
canonical-for: [depth-parallax-prototype-evidence]
last-reviewed: 2026-10-18
related-documents: [../systems/depth-layers-and-parallax.md, ../systems/material-appearance-and-rendering.md]
---

# Depth/parallax prototype record — 2026-10-18

## Request and implementation

The owner requested working prototypes for a quantized foreground-derived
pseudo-Z effect; separate active, scripted/set-piece, environmental-effects
and true-background pixel worlds; controlled interlayer destruction; and
additional depth experiments.

The result is **Strata Theatre**, with Flat, Quantized relief, Four layers,
Hybrid and Diorama comparison modes.

## Publication provenance

The first implementation was completed in a local isolated checkout based on
main ec05d7227885bda59bf72a5889b004296b9a07e5 and committed locally as
4046cf07a05e935c9f8ae0f52544a22980ba0363
(Prototype depth layers and parallax lab).

That local Git object was not available to the GitHub object API when explicit
publication permission was later granted. The remote branch
prototype/depth-parallax-lab was therefore reconstructed from the **same base**
and the retained implementation/evidence record.

**The remote draft is not claimed byte-identical to local 4046cf0.** The local
results below are not exact-head certification of the reconstructed branch.
The draft must rerun import, focused Godot, graphical-pixel and repository
checks before it can become merge-ready.

## Original local validation

The original local implementation reported all eleven selected focused Linux
Godot runners passing:

- test_depth_layer_runtime;
- test_depth_compositor;
- test_depth_lab;
- test_native_render_bridge_regression;
- test_render_patch_handoff_regression;
- test_presentation_controls;
- test_tick_failure_regression;
- test_physics_async;
- test_gameplay_recorder;
- test_pchar001_player_representations;
- test_penv001_player_environment.

The depth runtime test reported 165 checks and the scene integration test 176
checks in that local tree.

Real OpenGL rendering through Godot 4.7 / llvmpipe checked transparent Empty,
foreground occlusion, canonical glass alpha, different rear-plane displacement
under camera movement, visible relief and negative controls. The ordinary
sandbox -> depth lab -> fresh sandbox lifecycle was also exercised.

Those results establish feasibility of the design. They must be reproduced
for the remote reconstruction.

## Original local bounded CPU characterization

The foreground was settled while the rear waterfall and rain continued.
Timings are host elapsed owner/update timings, not a frame budget.

| Play / rear / effects rates | Owner update mean | p95 | Copied publication mean |
|---|---:|---:|---:|
| 60 / 20 / 30 Hz | 1.739 ms | 4.187 ms | 0.151 ms |
| 60 / 10 / 15 Hz | 0.852 ms | 3.966 ms | 0.078 ms |

The 120 measured updates followed 30 warmup updates. The default arm completed
120/40/60 play/rear/effects ticks and the reduced arm 120/20/30. Background
remained at tick zero.

The original host was Linux on an AMD EPYC 9V74. These measurements exclude
Image blits, ImageTexture.update, shader execution and window presentation.
Initial publication of all four full RG8 images was about 169 ms.

godot/tests/measure_depth_layer_runtime.gd is retained so the remote head can
produce new source-bound results.

## Current acceptance boundary

Before changing this draft to ready-for-review:

1. run Godot import using the repository-pinned runtime;
2. execute the three depth tests plus affected existing render, async, recorder
   and player regressions;
3. run capture_depth_lab.gd on a real graphical DisplayServer and inspect all
   five modes plus camera-shift/backdrop-breach captures;
4. rerun the bounded runtime cost script;
5. run documentation/repository/historical checks required by AGENTS.md;
6. confirm no native runtime, dependency or generated-import delta entered.

Windows hardware rendering and real browser/WebAssembly remain separate
qualification targets. Headless/native checks do not establish subjective
depth quality or target-GPU cost.
