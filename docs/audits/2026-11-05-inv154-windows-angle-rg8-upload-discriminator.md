---
title: INV-004 Windows graphical RG8 full-image texture upload discriminator
status: Current
document-kind: evidence
scope: Source-guarded standalone Windows ANGLE full-image RG8 ImageTexture.update timing, not full gameplay or native GPU acceptance
canonical-for: []
last-reviewed: 2026-11-05
related-documents: [../operations/profiling-observability-and-performance.md, ../architecture/rendering-and-gameplay-bridges.md]
---

# INV-004 — bounded Windows ANGLE RG8 upload discriminator (2026-11-05)

## Source, ownership, and rationale

Accepted main `ba9cbc89029be88b812af59b19e5c59829bbcd90`, tree `3af18f50e6094776263119623b64a1b2f4ca0ab2`, during registration. The source-locked `godot/scripts/main.gd` Git blob is `791ef440efd6edb206c6f1be33989cb62e9213b2`. Its `apply_render_patches_to_image()` handles the dirty rectangles and `finish_texture_upload() -> update_render_texture() -> texture.update(image)` submits the full RG8 image on every accepted new render publication. The image is 1024 × 1024 × 2 bytes = **2,097,152 bytes** regardless of the size of a changed patch; this is a logical API payload size, *not a measured driver transfer*.

This is a distinct diagnostic from [#403](https://github.com/techrote/cybersand/pull/403) (palette FXC cold compilation), [#417](https://github.com/techrote/cybersand/pull/417) (MicroScenario UI copying), [#428](https://github.com/techrote/cybersand/pull/428) (actor-overlay cloning) and [#401](https://github.com/techrote/cybersand/pull/401) (Windows process shutdown experiment). Render publication source and GPU upload design remain owner-locked. No production renderer, Main, worker, native World, Rapier, shader, snapshot contract or defaults change here. The diagnostic measures one current API call in a simplified, **standalone** graphical Godot project. It does not assert what fraction of real Main frame time it consumes.

## Preregistered bounded experiment

- Run **official SHA-512-verified Godot 4.7** from the repository's Windows pin on a GitHub-hosted **Windows Server 2022**, `--rendering-driver opengl3_angle`, without `--headless`. Windows video controller, driver, CPU, system, engine, source SHA/tree, renderer and stdout are recorded.
- Use a displayed `TextureRect` backed by **RG8 `ImageTexture`** and `Image.create_empty`, sizes **256²** (131,072 bytes) and **1024²** (2,097,152 bytes). Per size: (A) static/no-upload floor; (B) a genuine single-pixel CPU image change, followed by a **full** `ImageTexture.update(image)`; (C) full-image CPU fill, followed by an identical full-update API call. All changed arms submit one update per observed frame.
- Three rotated-order repetitions, **40 measured frames per arm per repetition**, **12 unmeasured warm-up frames per arm**, vsync disabled. Each frame reports monotonic CPU image preparation, synchronous `update()` API elapsed, `frame_post_draw` wait, and frame interval independently. Keep every sample and outlier. Do **not** present `frame_post_draw` wait as GPU-only or photon latency.
- A and B are *not equivalent semantic alternatives*: zero-upload is a static control, and a dirty-pixel update is not a selective GPU subregion upload. Same pixels are presented without the material shader or native simulation; these are strictly API/machine discriminators, not a production optimizer or visual correctness test.
- Refuse wrong main source blob, missing engine PIN, wrong Windows graphical DisplayServer, incomplete rows/samples, pixel write failures, nonzero exit or renderer mismatch. Resource/time budgets: 2 sizes × 3 arms × 3 repeats × (12 warm-up + 40 measured) = 936 graphical frame waits, plus under 4 minutes of script timeout. One Windows runner only; no cache flushing, parallel tests, crossbuild or cold FXC shader trials.

Reproduce on a Windows host with verified Godot 4.7:

```powershell
Godot_v4.7-stable_win64_console.exe --path .\standalone --rendering-driver opengl3_angle --script res://probe.gd
```

The CI workflow builds the scratch Godot project from the exact committed test and records complete raw samples and platform evidence. The script is independently usable in a minimal Godot project. It does not load CyberSand native/Rapier binaries.

## Interpretation and next decision

Compare only within the same hosted graphical cohort. Synchronous `update()` cost may reflect queued transfer or driver/engine synchronization; without GPU timestamps it is **not** proof of GPU utilization, fully transferred bytes or input-to-photon latency. Frame intervals mix host scheduling, rendering and synchronization and are not actual gameplay FPS. `ImageTexture.update` still logically receives the entire RG8 backing image even when one pixel changes.

**If** 1024² full updates impose significant measured upload API overhead versus 256² and the separate unchanged static control, next run should instrument **real Windows graphical Main** per accepted publication: dirty patch area, cadence, `update_render_texture()` elapsed, actual frame-time percentiles, native tick progression and copy/actor costs. An expensive result alone does **not** authorize subregion rendering, image caching, cadence reduction, lower resolution or a change in snapshot ACKs. If cost is negligible on this cohort, close the isolated hosted-API hypothesis and prioritize actual Main CPU phase tracing instead.

### Execution ledger

The workflow artifact and source-linked PR comments own exact run status. A queued, skipped, errored or unfinished job is **not** a successful Windows graphical measurement. Record the source SHA/tree of any **executed** job separately from later documentation-only heads. This draft intentionally makes no production merge or performance-gain claim.
