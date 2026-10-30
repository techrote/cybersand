---
title: PLAY-PACE-003 cold graphical startup diagnosis and correction
status: Current
document-kind: evidence
scope: Bounded issue 309 palette compiler diagnosis, visual parity, source-bound graphical qualification and preserved blockers
canonical-for: [play-pace003-cold-startup-evidence]
last-reviewed: 2026-10-30
related-documents: [2026-10-30-play-life006-stress-and-recovery.md, ../systems/material-appearance-and-rendering.md, ../operations/profiling-observability-and-performance.md, ../operations/local-build-and-validation.md]
---

# PLAY-PACE-003 cold graphical startup

This is the manual [#309](https://github.com/techrote/cybersand/issues/309)
successor to blocked [PR #308](https://github.com/techrote/cybersand/pull/308).
The [ownership registration](https://github.com/techrote/cybersand/issues/305#issuecomment-6534184231)
owns only `codex/play-pace003-cold-start-20261030`, stacked from
`codex/play-life006-integrated-stress-20261030` at
`2443a78378d649df588efeac9db7c54084473329`, tree
`b5a8ce67b317ef49b6faf7e4cf9f2d6027882dc9`. Freshly inspected main was
`b55ce690f9a3d2ca3026674a2e9c6a7635966f59`.
Scheduswarm remains paused; no task, dispatch or successor was created.
The broader #154/#156 investigation and optional #304 are not taken over.

## Frozen failures and fresh terminal readback

All four runs below are original attempt 1 at PR #308's recorded head.
Original ZIPs, terminal logs and the prior evidence archive were independently
read back. The archive is 106,740,937 bytes, SHA-256
`3f7ece69e7e8f6224dac8915c7c4a61653b719121ef5ef5098efb35df149305b`.
It is not reconstructed from summaries.

| Gate | Original run | Fresh terminal result |
|---|---|---|
| Docs/provenance | [41118526759](https://github.com/techrote/cybersand/actions/runs/41118526759) | PASS |
| Native | [41118526721](https://github.com/techrote/cybersand/actions/runs/41118526721) | FAIL, full TSan suite reaches unchanged 15-minute bound, exit 124; later checks skipped |
| Ordinary Godot | [41118526958](https://github.com/techrote/cybersand/actions/runs/41118526958) | Applicable Windows/Linux jobs PASS: 208 Windows and 220 Linux unique cases |
| Graphical PACE003 | [41118526813](https://github.com/techrote/cybersand/actions/runs/41118526813) | Both OSes FAIL before measurement; no PNG; Auto unattempted by that historical apparatus |

Ordinary Godot executed merge commit
`ac08bc209816fcd6f21fc0acd32fc58ac289debe`, with parents exactly main and
PR #308 above, and a tree identical to the PR head. This is verified tree
equivalence, not an assertion that the executed commit IDs are identical.

Linux original artifact **13006399308** has SHA-256
`166fef2d8b2392c28d9b03d80736a74fbf8e233ae912c0713e63798d739449bc`.
Its first submission is 29.055561 seconds after Main ready, adjacent callback
gap 28.943430 seconds, and no accepted actor/course within the pre-Build
30-second limit despite candidate terrain readiness. Exit 1 after 33.549
seconds is an internal readiness failure, not the external process watchdog.

Windows original artifact **13006548159** has SHA-256
`5f7db041d0a39987fbad78996519c2ba92bc359e787811981b05009d518f6997`.
Selector admission is at 4.416344 seconds, with no acknowledgement before the
180-second bound. A chronology correction matters: the retained `6048.dmp`
belongs to diagnostics requested at 150.0019766 seconds, when hot thread 7320
had 149.046875 CPU seconds. Its RIP maps to `d3dcompiler_47.dll+0x99790`.
The later timeout snapshot reports 173.890625 CPU seconds for that thread;
Main remains at 1.968750 CPU seconds. These are separate snapshots, not one
simultaneous fully symbolized stack. They do not alone identify a shader.

Independent readback authenticated 773 execution inputs per original platform,
each original process log, both committed runtime manifests, all 80 native
inputs and four Rapier inputs. The terminal evidence receipt verifies 12
original ZIPs and 434 ordinary Godot process logs. Native's last printed pass
is W-CY workers/persistence/transport, five seconds before exit 124. There is
no following test-start marker and no printed TSan race report; neither fact
turns the full-suite timeout into a pass.

## Registered hypothesis and controlled intervention

`main.tscn` binds the World material directly to
`res://shaders/material_palette.gdshader`. Source inspection found seven
mutually exclusive structured-fill calls to the same large
`apply_material_flair` helper. The historical MAT-002 building-dispatch
compiler failure was a lead, not proof of this defect.

The correction moves those seven calls to one guarded call immediately after
the common region geometry. Each selected branch receives exactly the same
incoming colour, material, flair, coordinates, condition and time; branch
specific detail still executes afterwards. No appearance formula, material,
texture, renderer setting, native code or resource-ownership transition changes.
Building IDs 81–131 and nonstructured dispatch remain separate and unchanged.
The guard preserves the original no-flair paths for IDs
5, 7, 46, 55, 64, 68, 69, 73, 74, 75, 76 and 80, and thin ID 50 when
`across_span <= 3.5`. No outside-view or temporal-path optimization is included.

| Shader input | Bytes | SHA-256 |
|---|---:|---|
| Frozen original | 123,648 | `3d9ee3b04ce6eee03490ad2c4af1f487f208e9ff0db31e6d514127633c2e0fef` |
| Guarded structured-flair hoist | 123,903 | `426c2b8a829d6ca216659b73f7663ba6c7f6dddd300726b81ed1eec85bbd3e1d` |

## Local Linux causal evidence

Local software environment: Ubuntu 24.04.3, AMD EPYC 9V74, nine exposed logical
processors, Mesa 25.2.8 / LLVM 20.1.2 llvmpipe; pinned Godot
`4.7.stable.official.5b4e0cb0f`. Controls remain
`LIBGL_ALWAYS_SOFTWARE=1`, `LP_NUM_THREADS=2`, `GALLIVM_PERF=nopt` and Xvfb.
The engine archive SHA-256 is
`0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c`;
the executable is
`f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`.
Retained native/Rapier payloads were materialized from their committed LFS
identities and verified by the original campaign preflight. They are not rebuilt.

The first local attempt failed headless import because sandboxed sockets/editor
configuration were unavailable. Its original exit/log remains retained.
With an isolated writable configuration and actual display sockets, the first
unchanged Main graphical case failed in 61.713 seconds: first submission
59.300359 seconds after Main ready, no in-deadline acknowledgement. No source
input changed during that execution. An attempted post-start GDB attachment
found the process already gone and supplies no stack evidence.

Separate, explicitly **NONQUALIFYING** isolated palette processes use identical
640×360 material atlases, full original shader bytes and fresh private XDG
cache/config/data directories. A bounded GDB sample of the original process
finds Main inside libc/libgallium while llvmpipe workers wait. It is not a
symbolized Mesa optimizer-pass attribution.

The [driver-call helper](../../tools/play/gl_startup_trace.c) intercepts the
pinned GLAD resolver using glibc `LD_AUDIT`, preserving real calls/arguments.
It records source dumps, attachments, monotonic wall and calling-thread CPU
times, with bounded events. It does not force a render or warm the engine.

| Observed boundary | Original wall / thread CPU, seconds | Hoist wall / thread CPU, seconds |
|---|---:|---:|
| Palette fragment `glCompileShader` | 0.051605 / 0.051574 | 0.044173 / 0.044174 |
| **Palette `glLinkProgram`** | **34.263257 / 34.258410** | **11.757624 / 11.749225** |
| First palette `glDrawElementsInstanced` | 7.586700 / 7.583838 | 3.292077 / 3.291566 |
| First atlas capture | 42.035089 wall | 15.225674 wall |
| Complete 16-frame process | 45.309281 wall | 18.368575 wall |
| Peak process RSS | 3,616,852 KiB | 1,255,708 KiB |

Both processes exit zero within 180 seconds. Exact emitted fragment shader 60
and vertex shader 59 attach to palette program 58. Only fragment 60 differs
among 40 emitted GLSL dumps; the other 39 are byte-identical. The measured
34-second interval is CPU work within palette program linking, followed by
another CPU-heavy first-draw interval. Its precise internal pass/JIT mechanism
remains unassigned. This local causal result does not establish Windows cause
by analogy, representative hardware speed or native parallel scaling.

Independent trace readback finds zero dropped events, 40 complete dumps, no
unmatched retained begin/end pairs and successful compile/link status. It also
preserves one primary-process resolver-pointer-change bypass and two fork-child
bypass rows in each raw file. Filtering by the actual process PID yields fully
paired observed palette calls; universal GL interception is not claimed.

## Visual preservation and real-host scope

The [atlas probe](../../godot/tests/play_pace003_palette_atlas.gd) and
[comparator](../../tools/play/compare_pace003_palette_atlas.py) exercise all
132 material slots, broad plates, one/three/four-cell horizontal and vertical
strips, isolated and corner shapes, conditions 0/1/127/128/254/255, fixed times
3.0/9.5, temporal blends 0/0.5/1 and a nonstructured control. All **16 frames
match exactly in RGBA8 and raw framebuffer bytes** between the local original
and hoist. The predeclared existing 2/255 tolerance was not needed or enlarged.
This is a same-backend visual comparison, not the Main acceptance gate.

The first corrected local Main pair executed the actual Jet Barrel / Current-0 /
keyboard-only / free-play / overview route at 960×540. Both processes passed
17 assertions, retained real terrain/actor PNGs and joined the real worker.
Acknowledgement latency was 15.851795 seconds for one worker and 4.950157
seconds for Auto. Inspection then identified a cache-custody omission:
Godot Compatibility stores shader cache below **`user://shader_cache`**, not
only `.godot/shader_cache`. Those two rows shared the private user-data
directory. They retain fresh-process evidence, but Auto is **not** credited as
an independently empty-user-cache cold run. The successor apparatus isolates
that actual user-data location per row as well; it cannot relabel the earlier
pair. Its exact-head hosted results belong in the continuation receipts below.

That first local pair observed approximately 60 completed native ticks/s,
mean submitted-frame intervals 79.602/81.225 ms, and one participating native
worker in both configurations (allocated capacities 1/4). These lightweight
software-renderer results establish neither 60 graphical FPS nor Auto scaling.
The observed gameplay PNG was inspected for actual terrain, materials and actor;
nonblank UI alone is not accepted as visual correctness.

## Apparatus and acceptance boundaries

PACE003 retains the real pre-Build **30-second** Main acknowledgement deadline,
**180-second** per-case deadline and **240-second** import deadline. It keeps
startup separate from the disclosed post-acceptance steady-state preparation.
Additive scene load/instantiate/add-child/ready markers separate resource/scene
work from callback intervals. Attached production shader/file/code hashes bind
the actual material resources to execution inputs, so a flat diagnostic shader
cannot qualify by leaving a nonblank UI.

Each requested worker configuration retains its own first attempt even after an
earlier failure; any failure keeps the aggregate failed. Cold-cache inventories,
retained generated bytes and original-cache restoration happen outside the
timed process and perform no rendering. Unobservable OS/driver caches remain
explicitly uncontrolled. Late/absent or stale acknowledgement, frozen/stale
callback traces, missing graphics, shader substitution, worker-retirement
failure, source drift, cache mislabelling/corruption and first-failure masking
are adverse checks, not alternate success paths.

The standalone [diagnostic workflow](../../.github/workflows/play-pace003-shader-diagnostic.yml)
runs both authenticated original and candidate shaders on each hosted OS,
retains CPU/thread samples and original failures, and never reports PACE
qualification. An original baseline timeout still yields a failed diagnostic
job even when the candidate completes. The original
[Main workflow](../../.github/workflows/play-pace003-host.yml) remains the
separate graphical acceptance route. Driver instrumentation is absent there.

## Continuation receipts and safe integration

This implementation checkpoint establishes the local Linux mechanism and
pixel-preserving candidate. Windows-specific source-matched diagnosis, clean
hosted Windows/Linux cold Main qualification, focused graphical/lifecycle
regressions, exact-head ordinary gates and substantive review are still
required. Consult the current #309 / scoped-PR receipts for exact subsequent
commit/tree/run/attempt/artifact identities; a pending or skipped job is not
success. Preserve each first failure and its original evidence when adding a
successor result.

No merge or closure is authorized by these local observations. Native's full
TSan exit 124 remains an independent mandatory gate, outside this shader write
set. Do not merge #308 into main until the resulting-head acceptance matrix is
green. #269/#270/#263 remain open for their separate lifecycle, physical-device,
OS-focus and human-feel requirements. Training/scientific fixtures, native
ownership, Rapier threading, liquid policies and runtime/LFS provenance remain
unchanged.
