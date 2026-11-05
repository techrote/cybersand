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


## Actual Windows graphical result — 5 November 2026

**Executed source:** \`181f93a6554e854ac86236d711e305a864fe28ed\`, tree \`5ed665a2b9ee8d5afdc359d1587fde57b1eb1f37\`; preserved standalone probe and guarded production Main blob as registered above. **Exact-head graphical diagnostic: PASS**, [Actions run 42017936151](https://github.com/techrote/cybersand/actions/runs/42017936151) / [raw artifact 13409807829](https://github.com/techrote/cybersand/actions/runs/42017936151/artifacts/13409807829). Artifact ZIP SHA-256: \`5a50ece2690fa2173ad3969e8dd819b023da92cbea453a361030265f001173a8\`. Full raw 720-frame result, 18-run summary, source/engine/driver/OS manifests, exact commands, import/Godot logs and provider-policy output are retained unchanged. This section is a subsequent **documentation-only commit** and does not represent a second graphical execution.

**Platform:** GitHub-hosted Windows Server 2022 Datacenter (build 20348), AMD EPYC 7763 (2 visible cores / 4 logical threads), Microsoft Hyper-V Video controller (10.0.20348.1), graphical Windows DisplayServer. Official SHA-512-verified Godot 4.7-stable; actual compatibility path: ANGLE OpenGL ES 3.0 on **Microsoft Basic Render Driver via D3D11**, software display cohort. \`--rendering-driver opengl3_angle\`; not \`--headless\`. A real Windows Godot graphical rendering experiment, **not native end-user discrete-GPU performance**; no CyberSand Main, native World, Rapier, palette shader or gameplay simulation is loaded.

All 18 size/arm/repetition rows completed, **40 measured frames each**, 12 warm-up frames each; **720 measured frames total**, zero script/runner assertions failed; the updated-pixel positive controls passed. Every arm retains individual monotonic timestamp/call/wait/interval samples. Values below pool the 3 rotated repetitions (120 frames per row); p95/p99 are the values at rounded zero-based indices \`round((N-1)*fraction)\` of the sorted pool, *not* confidence intervals or 1,000-frame tail estimates.

| RG8 size | Arm | \`update(image)\` CPU-call p50 / p95 / p99 (ms) | Post-draw frame-interval p50 / p95 (ms) | CPU preparation p50 (ms) |
| --- | --- | ---: | ---: | ---: |
| 256² (128 KiB) | No upload; static control | 0 / 0.001 / 0.001 | 3.259 / 3.669 | 0 |
| 256² | Single changed pixel; **full** update | 2.699 / 3.239 / 9.023 | 3.306 / 3.808 | 0.004 |
| 256² | Full fill; **full** update | 2.698 / 3.144 / 8.833 | 3.281 / 3.710 | 0.006 |
| 1024² (2 MiB) | No upload; static control | 0 / 0.001 / 0.001 | 3.239 / 3.631 | 0.0005 |
| 1024² | Single changed pixel; **full** update | 2.757 / 3.281 / 8.799 | 3.348 / 3.855 | 0.004 |
| 1024² | Full fill; **full** update | 2.692 / 3.288 / 8.950 | 3.398 / 3.981 | 0.102 |

**Discriminating observation:** The median synchronous \`ImageTexture.update\` call occupies ≈2.7 ms in both 256² and 1024² cases, despite a 16× logical RG8 payload-size difference; changing just one pixel does **not** avoid the full-image API submission. However, the complete frame-to-frame interval rises by only ≈0.02–0.16 ms in these arms relative to each same-size static control, *not* by 2.7 ms. The post-draw waiting segment becomes shorter when synchronous update work is present. This is consistent with **CPU waiting/synchronization being redistributed between the API call and the subsequent frame wait**, but the experiment cannot independently attribute the stall to GPU transfer, queueing, software rendering or driver scheduling. In particular, **2.7 ms must NOT be added to Main frame time or advertised as an achievable optimization**. The stand-alone test does not establish general GPU cost scalability.

**Long-tail negative:** There were **12 post-draw intervals above 8 ms out of 480 updated-arm frames** (one for each 3-repeat/2-size/2-active-arm block); **none** of the 240 static-control intervals exceeded 8 ms. No observed interval exceeded 16.67 ms. The 120 samples per cohort and one shared-host run are insufficient to estimate production p99. Preserve these spikes, but do not treat them as proof of actual gameplay stalls.

**Decision and next gate:** **Do not implement a renderer rewrite, disable full-image updates or alter any publication/ACK policy based on this result.** The hosted ANGLE synchronous-call cost is real, but the near-unchanged whole graphical interval falsifies the tempting simple additive-cost interpretation. The next best independent slice is a **source-pinned actual graphical Main** trace (on an actual target Windows machine if possible) of \`update_render_texture()\` elapsed and adjacent frame/post-draw wait, including worker publication cadence, native completed ticks, current dirty area, upload frequency, actual physics/actor population, and loaded native/Rapier/GPU identities. Compare paused/static versus small changing Water workload at unchanged camera/resolution and retain reset/exit. Keep #403 shader compile, #401 crash, #417 UI and #428 overlay attribution in their independent lanes.
