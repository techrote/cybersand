---
title: PLAY-PACE-003 cold graphical startup diagnosis and correction
status: Current
document-kind: evidence
scope: Bounded issue 309 palette compiler diagnosis, visual parity, source-bound graphical qualification and preserved blockers
canonical-for: [play-pace003-cold-startup-evidence]
last-reviewed: 2026-10-31
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

The first published checkpoint is draft stacked [PR #310](https://github.com/techrote/cybersand/pull/310),
head `7d26f54d1ec856f40a1ac464ed7a42de23f6d423`, tree
`21007709ed7179491186543b73d3f6419607ff8f`, parent exactly #308 above.
Its original/candidate hosted diagnostic is attempt 1
[41135828311](https://github.com/techrote/cybersand/actions/runs/41135828311).
Draft-skipped Native, Godot and Main jobs are not passes. No #308 ref changed.

Substantive source review found and corrected three evidence weaknesses before
the next qualifying run: cached material references did not prove attachment
to the actual visible CanvasItems; identical clipped PNGs could hide blank or
different/nonfinite HDR output; adjacent-frame quantiles omitted silence at
the measurement-window boundaries. The successor reads real material/node,
viewport and texture-chain custody, requires finite exact native framebuffer
bytes plus distributed material-pixel sentinels, and reports leading/trailing
gaps and full-window event rates alongside unchanged adjacent quantiles. A
review also caught an initial verifier assumption of sandbox dimensions; the
required authored Course overview remains 512×256, glow 256×128. Production
geometry and all timing limits are unchanged.

The [post-PACE graphical runner](../../tools/play/run_pace003_graphical_regressions.py)
executes seven existing fixtures on both OSes: all-five LIFE007, three-order
LIFE008, all-five UI005, UI003 physics/pause/stale-epoch, material132 pixel,
vapour-history pixel and Water-coverage pixel tests. Every first attempt retains
its original 180-second cap and runs after the original PACE measurement.
Failures remain red while later independent cases still execute. The aggregate
job budget accommodates those additional cases; no case/Build/import deadline
is extended. These automated checks do not replace #270's physical devices,
actual OS-focus transitions or human feel.

## Hosted qualification at 62d3f6cf

The next [PR #310](https://github.com/techrote/cybersand/pull/310) checkpoint is
`62d3f6cf12340a2124773695b98915dda5f16907`, tree
`9d7a2727a4ca33487a13815da673e5a704509649`, still based on #308 at
`2443a78378d649df588efeac9db7c54084473329`. Ordinary CI executed merge
`b6a1f4cf7d525a7323bfe7886e1678aaa697882a`; its original GitHub commit response
proves the same tree and exact base 2443/head 62d parents. PACE explicitly
checks out qualification head 62d while retaining that workflow/merge identity.

| Exact-62d gate, attempt 1 | Original run | Independently read result |
|---|---|---|
| Docs/provenance | [41136597980](https://github.com/techrote/cybersand/actions/runs/41136597980) | PASS |
| Native | [41136597982](https://github.com/techrote/cybersand/actions/runs/41136597982) | PASS, all 18 required workflow steps |
| Ordinary Godot | [41136597999](https://github.com/techrote/cybersand/actions/runs/41136597999) | PASS, 220 Linux cases including 12 actual display cases; 208 Windows headless cases |
| Main PACE003 plus seven graphical fixtures | [41136597969](https://github.com/techrote/cybersand/actions/runs/41136597969) | Linux PASS; Windows FAIL; aggregate remains FAIL |

The full Native job ran 22:12:59–23:04:45 UTC. Actual TSan, normal and
ASan+UBSan execution each prints all 164 exact-source test names once, in order,
and the complete success total. TSan retains separate 15-minute build and run
bounds; its combined step took 9m34s. All eight soliding sanitizer executables
ran, and normal/sanitized semantic-plane runs each reported 774,842 assertions
with zero failures. The native subtree, Makefile and required Native workflow
are byte-identical to base 2443. This is a new successful execution, not a
Native code correction or an explanation of the preserved historical TSan
exit 124.

Original full job-log text is retained with disclosed connector-decoded UTF-8
representation. Docs job 124340484315 has 101,692 bytes / SHA-256
`cb28053fd22de62842ade5c6f10363a4ea237017c83490b7fe79e8bd0899f128`; Native job
124340512565 has 230,803 bytes / SHA-256
`57e67ffbdb82dea12150ea54f0f498e5f06d92f42d04514b0ff8c6e0ca0fa664`. The
independent Godot union/log/runtime receipt has SHA-256
`3faa2bede1f819dd4f47277b128cb5a9d4072dc38e70fad9255c19602d661cb9`; the complete
Native readback is
`a1cdcfa2b2e7f1eeff1b808b39f323a994bdeb2651e47328d99e92f85f968873`. The
ordinary-gate originals manifest binds 12 raw ZIPs and 16 full job logs,
44,099,352 bytes before extracted copies, with SHA-256
`1db5477294ea05e68eee7447186a912212bcf37abb9409e0de1e661da43167c7`.

Earlier exact-62d draft Docs 41136429118 was cancelled during the ready
transition; Native 41136429140 and Godot 41136429275 were skipped while draft.
They remain recorded and are not passes. Existing optional dispatch-only
physical stress and variable-controlled serial equivalence were also skipped;
neither replaces actual executed coverage. Independent readback proves the
source-derived Linux and Windows shard unions and checks every original case
log. Windows ordinary headless success supplies no graphical-startup evidence.

### Hosted Linux cold Main and Windows failure

Linux artifact 13017233186 retains two separate first-attempt cold processes,
each with private project, XDG cache/config/data and Mesa cache custody, real
960×540 Main output, accepted course/actor and successful worker join. Both
reported 17 assertions with zero failures. The earlier shared-user-cache Auto
pair above is not relabelled as this new execution.

| Retained Linux measurement | One worker | Auto |
|---|---:|---:|
| Main acknowledgement after request | 10.517283 s | 12.672816 s |
| First submission after Main ready | 9.420709 s | 11.630761 s |
| Largest startup adjacent Main callback gap | 9.335634 s | 11.539763 s |
| Submitted interval p50 / p95 / p99 | 63.909 / 70.899 / 79.475 ms | 64.258 / 71.559 / 82.834 ms |
| Full-window submission events/s | 15.438784 | 15.296248 |
| Completed native ticks/s | 60.024928 | 59.987895 |
| Snapshot age p99 | 17.872 ms | 18.183 ms |
| Native worker capacity / actual maximum participants | 1 / 1 | 4 / 1 |
| Snapshot serials coalesced between Main reads | 667 | 669 |
| Stop/join | 3.091 ms | 13.494 ms |

The submission counts measure render submissions; physical scanout was not
measured. Native completions have a separate rate, and neither row observed
parallel native participation. Raw callback, boundary-gap, publication and
lifecycle fields remain available in the reports. No representative-hardware
speed, universal 60 FPS or Auto scaling follows.

The maximum render-payload ages remain 17.025671/17.048321 seconds. Both measured
windows retained `render_tick = 5` and one unchanged render-generation timestamp,
while fresh worker snapshot metadata and native completions advanced. One-worker
snapshot ticks advanced 128 to 1026 and serials 280 to 1178; Auto ticks advanced
129 to 1027 and serials 283 to 1181. The source-matched worker
`_publish_snapshot` collects terrain changes on World revision or forced refresh
and advances the render-generation timestamp/tick only when the render serial
advances; Main uploads and acknowledges a greater accepted render serial.
These observations are consistent with unchanged terrain-payload reuse. They
must not be described as a new image for every native tick, or interpreted as
stale simulation solely from the older terrain-payload timestamp. Snapshot age
and render-payload age remain separate measurements. The retained source/data
interpretation receipt `linux-62d-publication-interpretation.json` has SHA-256
`f7fac4d7f3f2f19f7b9e451b74bf2d76f9fa72e9ad30246acf9452c708d98e22`.

The retained PNG SHA-256 values are
`3e731b2a7e7949d033fba8554c74b4a6f2c50525e23f111a0bf4d7cdc501d621` and
`b5a38ade6202cc4dc6571ee233eb879ad91890ca9038afad26092ff0fcd16885`. All seven
subsequent Linux graphical fixtures passed, including actual five-rig
failure/recovery, navigation cancellation, selector/pause/stale-epoch checks and
material/vapour/Water pixels. Physical devices, actual OS-focus transitions and
human feel remain separate #270 requirements.

Windows artifact 13018441199 retains both first-attempt Main processes timing
out at the unchanged 180-second bound, without qualifying acknowledgement,
steady-state window or Main PNG. Six subsequent graphical fixtures also timed
out; only the separate vapour-pipeline fixture passed (26 assertions, real EXR
pixels). That single fixture cannot qualify the failed Main/palette route.
Windows ANGLE/Microsoft Basic Render Driver controls remain unchanged.

Both platform reports bind the source tree and actual retained runtimes. Linux
native/Rapier SHA-256 values are
`496bf3df06be2c6bf47b2e5e4ea525ed4d969c3a34cf1a97d71e4668cdc250e6` /
`566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a`; Windows
values are `e66b9b04b546b09cb4feea204373faf12a7248abf1701da88fc6ecf87b666ecb` /
`b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7`.
Manifest/source-input and canonical LFS identity checks are retained. Pinned
Godot remains `4.7.stable.official.5b4e0cb0f`.

### Prepared archive readback correction

The original Linux in-job verifiers passed before upload. The frozen 62d offline
verifiers reject the downloaded ZIP because artifact upload omits empty
directories: recorded generated cache/config directories and five fixtures'
deliberately empty pixel directories are absent after extraction. The original
strict rejection is retained; no missing directory or log is reconstructed.

The prepared successor implementation now includes the reviewed explicit API
keyword `offline_archive_readback=True` in both campaign and graphical readback.
Its candidate-preview checks allow an absent generated directory only when the
retained expected file inventory is exactly empty; the default remains strict.
At-launch emptiness, environment/path binding, receipts, every nonempty cache
file and required PNG/EXR remain mandatory. It performs offline readback without
a new process, cache warm-up or qualification retry. The unchanged Linux
originals pass that explicit successor readback; the Windows originals still
fail on their actual process/campaign failures. This pending implementation is
not part of tested 62d, is not deployed or accepted by this checkpoint, and must
not inherit 62d gates.

### Prepared late-completion rejection — 2026-10-31

The shared [process monitor](../../tools/ci/godot_process_monitor.py) had a
separate false-success seam: its loop could first observe an already-exited
zero-status child after the fixed case deadline and return ordinary completion.
The prepared successor now records the clock when completion is first observed
and conservatively returns `case_deadline` if that observation is late. The
exact OS exit time is unknown. In-bound and exactly-at-bound observations retain
their classification; later diagnostic cleanup cannot retime that observation.

Eleven local Linux monitor tests pass normally and under Python optimization. The new
late-zero-exit control fails against the retained original monitor as expected,
preserving a direct negative for this defect. Receipt SHA-256 is
`592cedf0ceeafe860195fbe52b4e2610bbcdd5b3af740f53e5e9a2af3b2f5c77`.
The parent also prepares the narrow outer
[runner](../../tools/ci/run_godot_regressions.py) guard: an already-exited leader
does not receive a live-process capture, and Windows does not receive `taskkill`
for that exited wrapper. Its observed return code and explicit skipped-capture
reason remain recorded. POSIX descendant cleanup is preserved using the process
group captured at each `start_new_session` launch, including when its leader
has exited. Ten focused local Linux timeout tests pass normally and under
optimization; the deliberately Linux-only process-group fixture explicitly skips
on Windows and supplies no Windows execution claim. The final caller execution
receipt is `63c35fe1a5a3b3b61666965eee212932bfe02d052617c5808ae1e82bf5edccfb`;
independent final review has no actionable findings, receipt
`a7e628e659f10db29841daefeca3bcae4cda202a62e22b5ff083bfd88efbfc0e`.
These four source/test paths belong to a prepared successor on 62d, awaiting
its own exact-head qualification. They neither change a deadline, renderer,
runtime, gameplay/native path nor reinterpret any original 62d result. The
separate phase-4 diagnostic checkout is unchanged.

### Separate Windows compiler diagnosis in draft PR #312

The same manual owner registered
[`codex/play-pace003-windows-diagnosis-20261030`](https://github.com/techrote/cybersand/pull/312)
against #310 at 62d. Initial diagnostic commits
49b12d0fa0adf81be5e76ddc616fe63d6705fbd2 and
72d513cbfa9919ba31a6ef37b64af4844210c390 remain in its history. They do not
change #308 or qualify a production shader. No Scheduswarm dispatch was started.

| Diagnostic phase | Exact head / tree | Original run and disposition |
|---|---|---|
| Phase 1, authentic compiler passthrough | `3b986726c52babe3013df48300d97f775392aa38` / `68e5e16ad5585cec678801dec6099c7ae78d959c` | [41139717684](https://github.com/techrote/cybersand/actions/runs/41139717684), attempt 1 FAIL; all five cold processes timeout at 180s |
| Phase 2, bounded exclusive dispatch ranges | `f20ae3ab40d8f4d8f2081fdeeafa8ceab04876e8` / `6d5cf3c7680579ba81decdc9d5487086d2040892` | [41141840826](https://github.com/techrote/cybersand/actions/runs/41141840826), attempt 1 FAIL; final readback confirms all five cold processes timeout at 180s |
| Phase 3, single-exit control flow | `512dbb9e139bc18c6b034f803b95b43a08d888da` / `4fb6655e53eac4942402b38dac6754d7c2d07725` | [41144657058](https://github.com/techrote/cybersand/actions/runs/41144657058), attempt 1 FAIL; all four first cold processes timeout at 180s; original job ended 2026-10-30 23:56:35 UTC |
| Phase 4, exact captured HLSL compiler-only contrast | `5de468478c37c8ae9e2d446ba348d4e3ecf54bd6` / `8957ae44174226758069a534f8a4c03edce79e51` | [41149030607](https://github.com/techrote/cybersand/actions/runs/41149030607), attempt 1 FAIL; both full-HLSL processes timeout at the unchanged 180s cap; original job ended 2026-10-31 00:20:39 UTC |

The retained 23:43:44 UTC API snapshot advances the earlier queue observation:
generic Windows job 124366820691 started at 23:43:07 and matrix job
124366820371 at 23:43:12. The generic job was materializing runtimes and the
matrix was installing dependencies; neither had begun its engine cases in that
snapshot. The now-terminal phase-3 results below supersede that pending state
without changing its historical meaning. The roughly 15-minute hosted CI queue
is separate from the unchanged 180-second measured process budgets. Per-case
original records, rather than queue or workflow duration, establish the failures.

Phase 1's independent compiler-matrix receipt has SHA-256
`096515f0a88cbf319b1309eaef52335f0d4de3fad69c6e1c6be9b9a419b3393e`. It binds the
actual unfinished palette `D3DCompile` input to the captured process/thread,
replacing the earlier module-offset-only attribution for this diagnostic
execution. The unchanged-hoist control's call 44 targets `ps_5_0`, entry `main`,
flags `0xc000`; its 175,942-byte HLSL has SHA-256
`192c1a086d5124ce4b22cb172bd90876212779e4d6c67447f9278493ba3ff03c`. The captured
compiler is the authentic System32 DLL, SHA-256
`64054871e088d47b4b7380f90efa40cf2f57bd966724764330a029f4fc3aa6eb`; the
passthrough proxy is
`710823019572e55df1d6ba4e03a9bba39a538dc76b00dc551def100eb0101c13`. The separate
preflight verified all 29 exports and unchanged byte/results.

The ordinary-flair exclusion's call 44 returned `E_FAIL` (`0x80004005`, X8000
uninitialized-temporary validation) after 145.5123312 seconds wall and
145.421875 seconds thread CPU. ANGLE's fallback call 45 uses byte-identical HLSL
with flags `0xc002` and remains unfinished at the process bound. Neither an API
failure nor that within-process fallback is graphical success. All five cases
retain their first failures, no atlas and no warm execution. Exclusions are
explicitly nonqualifying, and the full-visual structural candidates remain
unaccepted. No symbolized internal optimizer-pass explanation is claimed.

Phase 2 now has its own final independent receipt, SHA-256
`081a81da7c9912fcb9602a2404c78f88c0c43e4b2279e4cfbc919c10a45bde6d`. All five
first cold cases time out at 180s; each has 43 completed compiler calls followed
by the unfinished palette call 44, `ps_5_0`/`main`, flags `0xc000`. No atlas,
warm execution or completed candidate exists. The separate CPU/thread readback,
SHA-256 `9e7073d4dd2e931446b9c638a1bdc77e30164a8971b25a4c2bae3c7247e11bc3`,
binds actual process/thread IDs to minidumps and the exact compiler PDB. At the
last sampler observation within 180s, accumulated CPU after the open-call begin
ranges 177.40625–177.984375 seconds across the five cases; this is a sampled
bound, not a completed-call duration. These terminal negatives establish the
attempted variants' failure under the fixed contract, not fundamental renderer
incapability or a successful architectural replacement.

Source-copy custody remains a separate negative: retained 3b/f20 diagnostic
artifact sets omit the copied workflow under `.github`, leaving the source-copy
bundle incomplete. Both final matrix receipts preserve
`retained_source_copy_complete=false`; the strict copy-completeness checks
remain failed. Available committed-source, HLSL, runtime, proxy and original-DLL
identities are independently verified. Fetching a missing source later does not
put it into the original ZIP. These artifacts are not described as complete
retained source bundles, and neither phase qualifies Main or a production
candidate.

### Phase 3 source review and Linux visual evidence

Diagnostic head 512dbb9e descends from f20ae3ab and retains the production
palette. It adds four independent cold diagnostic rows: the retained hoist
control and three full-visual single-exit hypotheses. The original 180-second
process bound, authentic compiler inputs/flags and cold-cache controls remain.
Any subsequent warm execution is separately labelled and cannot replace a cold
failure. The diagnostic source adds an explicit visible artifact-path mapping
for the copied workflow. Original phase-3 readback now verifies all ten copied
source files, including that mapping; this fixes the new bundle and does not
repair the original 3b/f20 source-copy omissions.

The transformation retains each selected returning branch's formulas,
conditions, ordering and lazy continuation, assigns its original return value
to the existing `colour` parameter, and uses one final function return. It
introduces no material exclusion, loop, switch or eager helper evaluation.
Building finish and ordinary flair have 50/51 original returns; the extended
candidate also transforms neighbour relief and structured fill, with 3/19.
Unknown-ID fallbacks, LED-bezel and activated-rocket behavior remain in the
source comparison. This is a control-flow hypothesis motivated by the compiler
observations, not a proven source-initialization defect or internal FXC-pass
diagnosis.

| Frozen diagnostic shader | SHA-256 |
|---|---|
| Catalogue helpers on exact retained hoist input | `0e462ec704b2e0b2ca3dee1752a2da553af24b173307678e28aad836170efbd9` |
| Catalogue, neighbour and structured helpers | `06a0c12299a98da9e2a1751166283c13e6a46a6dba94d7ef5d40cce8a732fbb8` |
| Same four helpers on exact retained unified input | `cbad4e5b0a4916b9dee2fafb4c890003ae3c2191651bcd49f56380efff4e5ea1` |

The guarded input hashes are hoist
`426c2b8a829d6ca216659b73f7663ba6c7f6dddd300726b81ed1eec85bbd3e1d` and unified
`10edc6410eeed27a4883e7452abe5d5a47f213b256886c89daa0b88dbd33600f`.

[Review 5719765260](https://github.com/techrote/cybersand/pull/312#pullrequestreview-5719765260)
records substantive in-session review of source 512dbb9e. It is an owner-account
COMMENT, not a separate-account approval. The actionable proof gap was resolved
before publication: equality is checked against an independently normalized
tree reparsed from the actual emitted shader, in addition to the intermediate
tree. Conditions/results corrupted deliberately, missing else arms and work
after a result are rejected. Signatures, bytes outside the selected functions,
scope and absence of `colour` shadowing were independently checked. The 18
runner tests and 10 focused parser controls pass normally and under Python
optimization. These checks establish their narrow source scope, not GPU or
Windows behavior.

Six serial local Linux atlas processes compare the three frozen shaders with
the two retained original-reference processes on the 62d project. Each shader
matches all 16 standard and 16 extended frames: 96 candidate frame comparisons
and 256 retained original image files. Native finite RGBAF bytes, complete PNG
bytes and decoded RGBA are exact; distributed material-coverage sentinels pass.
The extended recipe covers previous/current interpolation, letterboxing,
negative camera origin, player and rotated-body overlap, and disabled detail.
All 782 recorded source-input hashes, actual native/Rapier bytes, commands,
private caches and public GL call traces are independently read back. The two
historical references were reused unchanged; they are not contemporaneous
repetitions. Uniform settings derive from retained harness source; raw input
textures were not separately retained, although independently calculated RG8
fixture hashes match. Resolver bypass and foreign-process trace rows remain
identified; no global interception or internal Mesa-function attribution is
claimed. This isolated, instrumented atlas evidence is NONQUALIFYING for
Main, FPS or Windows. Receipt `phase3-linux-atlas-readback.json` has SHA-256
`dd51a538be953db4ebd62484b4a379b6128be0eadeab7a6380ba2bdcbf177e40`.

The separate hosted Linux job 124366820504 in
[41144657056](https://github.com/techrote/cybersand/actions/runs/41144657056)
also completes at exact source 512/tree 4fb. This generic diagnostic compares
the original shader `3d9ee3b0...` with retained hoist `426c2b8a...`; it does not
execute a phase-3 single-exit candidate or Main. Its 16 PNG/native frame pairs
are exact, source custody covers 791 inputs, process wall time is
35.689/13.754 seconds, and palette-link wall time is 24.268716/7.463931 seconds.
Original artifact 13021010697 and job log are retained below. Independent audit
SHA-256 is `71f070ec9f16c04e9c07b3cd78abe11b86f5be39ec470a6ebd55ff41dfc16bed`;
pixel receipt SHA-256 is
`1eab06e801a629d0ad77b52ee077c0967626ea1e82e72a9b608511b8600eb939`.

### Terminal phase 3 Windows evidence — read back 2026-10-31

Original matrix artifact **13020549731** verifies all 791 execution inputs,
actual runtime/LFS identities, private cold caches, terminal report, authentic
compiler passthrough and all ten copied diagnostic sources. Its independent
custody receipt has SHA-256
`5049a438f88a15457afaec905583ea792b2f432e4e45b111bcab21e1b06fae4f`.
All four first cold rows fail the unchanged 180-second process bound. None
produces an atlas/PNG or an eligible warm run. Each completes calls 1–43 with
HRESULT zero and retained nonempty bytecode, then leaves palette `D3DCompile`
call 44 open with `main`/`ps_5_0`, flags `0xc000`, flags2 zero, the original
macro and null include callback. There is no returned palette HRESULT,
message blob, bytecode or subsequent fallback call in this phase.

| Original cold row | Captured palette HLSL bytes / SHA-256 | Compiler-thread CPU after begin, last sample at or before 180s |
|---|---|---:|
| Hoist control | 175,942 / `192c1a086d5124ce4b22cb172bd90876212779e4d6c67447f9278493ba3ff03c` | 175.796875 s |
| Single-exit catalogues | 177,592 / `7584cee92f91133e593ed669fef01073c944dd0a09c659b4e85943db57db7df8` | 175.953125 s |
| Catalogues plus warning helpers | 177,978 / `7aa915b1a0a8d89525bbb61adfa75501115d686153324d4db60bf0bcea6e9aad` | 175.984375 s |
| Unified plus all four helpers | 179,152 / `b06e3a36c7901a4f0bffa1ab5187fae67f220faa0f680a3f8b12b92a4b2a74f7` | 176.093750 s |

The HLSL proves the intended transformations reached the compiler: building
finish returns 50→1 and ordinary flair 51→1 in all three candidates;
neighbour relief 3→1 and structured fill 19→1 in the two all-helper candidates.
Explicit `else` counts increase by exactly 49/50/2/18. Catalogue-only HLSL is
byte-identical to control outside its two transformed functions; all-helper
HLSL is byte-identical outside its four. The unified candidate additionally
reduces actual flair call sites from two to one. Its broader intentional
dispatch/view change does not receive an outside-four-functions equality claim.
The unchanged control HLSL exactly matches the original phase-1 capture.
The source-matched structural receipt has SHA-256
`2da984a4c52580cc7a1b0021ceb5e614f3cf24104881a1e8dd9105e5538f5383`.

The source/HLSL readback also compares all preceding 43 complete compiler-input
multisets with phase-1 control; a separate readback compares phase-3 control and
the phase-2 control. All match, while async call order can differ. The latter
control receipt is
`f3932128ad5f957416a8e14e32a5d2aa8c02ea87a753518dbfbbc5a429e106dd`.
The CPU/thread/minidump readback is
`b5360ff5d31d76bd7b935fc0bd083aa2ee246d2a391bd8b3633a5e0cd09127fa`.
The table reports sampled same-thread CPU since the begin marker, not completed
API durations. Later timeout-diagnostic samples remain separately labelled.
Exact compiler PDB identity supports nearest public instruction names, not a
fully unwound stack or attribution to one internal optimizer pass. These
censored failures establish that the tested rewrites do not meet the Windows
contract; they do not rank their total compile costs or establish fundamental
renderer incapability.

The separate source-512 generic Windows job **124366820691** in
[41144657056](https://github.com/techrote/cybersand/actions/runs/41144657056)
is also terminal FAIL. Its original and unchanged-hoist cold rows time out at
180.002/180.000 seconds, with no atlas or warm execution. Artifact **13020508845**
verifies 791 source inputs, runtime manifests/LFS identities, original logs,
caches and captures; independent receipt SHA-256 is
`10fc0a6d776fe920dffdba8beccd96cb3809895a301482b3bf9ba517cb42a2dc`.
Those generic cases do not execute single-exit shaders. Their captured hot
compiler-module instructions remain narrower evidence than the matrix's direct
HLSL/API capture. The successful Linux original/hoist job and failed Windows
job keep the generic workflow aggregate red.

### Three local Main previews and their custody boundary

Each frozen candidate also has one first local Main attempt with one-worker and
Auto controls, the original 30-second acknowledgement/180-second case limits,
and the existing 15-second sample after the apparatus's two-second preparation
following startup acknowledgement. These are 62d plus five recorded local
paths: the palette and the campaign/graphical offline-readback helpers and their
tests. They are NONQUALIFYING previews, not execution of diagnostic source 512
or a production successor head. Runtime/LFS bytes remain those recorded above.

| Local candidate | ACK seconds, one / Auto | Submission events/s, one / Auto | Submitted p99 ms, one / Auto | Whole-campaign custody |
|---|---:|---:|---:|---|
| Catalogue single-exit | 14.386446 / 14.491111 | 13.039802 / 13.265314 | 100.298 / 97.044 | Rejected: terminal/final-report mismatch; original rows independently verified |
| All four helpers | 15.646317 / 14.624035 | 13.185791 / 12.392740 | 115.327 / 104.046 | Original terminal/report match; strict frozen 62d readback passes |
| Unified plus all four | 8.183386 / 8.567439 | 12.243895 / 12.858990 | 112.584 / 100.198 | Original terminal/report match; strict frozen 62d readback passes |

The catalogue terminal and wrapper bind a passed 1,390,832-byte final report,
SHA-256 `1d90e9b9d803d78131d7dea62db8ac93d266407759d0dbbdf742cb66b1b560ba`.
The retained file instead contains a 1,390,778-byte earlier checkpoint,
SHA-256 `a96a9ccbfcc09527de0c9ffa08620f850ecab001d073f2753e8e866a2ce25fc5`,
with failed status, no errors and no finished timestamp. Both completed raw
rows match their original logs, but this does not restore whole-campaign
custody. Default and unconfined reads confirm the discrepancy; its cause
remains unproved. The earlier unified-preview mismatch remains a separate
negative. No unavailable final bytes were reconstructed or restored, and no
hosted artifact is relabelled from this local anomaly.

All six raw rows have 17 assertions/zero failures, actual attached-shader and
private-cache identities, accepted terrain/actor, generation/epoch-consistent
samples, newer-epoch reset and worker/Rapier retirement. Direct inspection of
all six PNGs shows the course, actor, luminous strips, sand and water. No steady
callback/submission gap exceeds 250 ms. Native completions remain about 60/s;
only one native participant is observed even at Auto capacity four. The fixed
terrain render tick of 5 accompanies advancing worker metadata/native ticks,
consistent with unchanged payload reuse.

The clean 62d local reference has ACK 15.325078/14.794823 seconds and submission
rates 12.745012/12.438930 per second. Unified startup improves in these samples,
but its one-worker submission rate is 3.93% lower while Auto is 3.38% higher;
the all-helper one-worker p99 rises to 115.327 ms from reference 101.244 ms.
Single runs with uncontrolled external load neither prove a regression nor
guarantee its absence. Frame submissions are separate from native completions
and unmeasured physical scanout; no parallel scaling is established.

The retained tape exercises direction, lift and primary-tap injection, initial
neutral rearm/resume, reset and shutdown. These Main previews do not directly
assert pause/recovery, physical input/focus, displacement from each input,
human feel or replay equivalence. Candidate-specific graphical lifecycle/UI
fixtures and exact-head Windows/Linux qualification remain required.
Independent Main receipt hashes are
`3853438296600eae2d4de5361a25831d2a36b2396eddcc9a19baf6e1b06092ac`,
`48a480d6171bc559db7ef508a30e1cbd5d580c541d6ab4b183c69faa964bb5b6` and
`ca67089f062ba4b25864ab644219fd698155afeb3c41f10ea713ff5931459ac3` in table
order; the original-copy/visual/chronology receipt is
`9fee4057d71dc86fd01ab9c492429e8d66e4c1181d7c957abc839691185f6ea3`.
Final production shader selection and all resulting-head gates are pending.

### Two precise measured-route continuation gaps

The frozen-62d requirements review, receipt SHA-256
`db59935241e791ee7a6a3bd08dc9587f54dc8de85441ef76eb04bbd27e00a157`, preserves
the cold pair and all seven graphical fixtures. They already assert five-rig
acceptance and policy refusal, keyboard/primary-edge admission and neutral
rearm, real failed-World quarantine/recovery, joined retirement and weak-reference
release, stale run/epoch rejection, history reset and actual material pixels.
UI003 checks pause through manually invoked physics; ordinary LIFE001 already
checks healthy Rapier pause/resume in its separate lifecycle suite. Those
concrete assertions remain valid within their original source/platform scope.
They do not fill two narrower gaps in the measured graphical Main route:

1. `MeasurementHost._physics_process` records direction, lift and primary-tap
   transitions in `raw.input_tape`, indexed by completed Rapier ticks, but
   [`verify_row`](../../tools/play/run_pace003_campaign.py) does not require or
   validate that field. A future responsiveness claim must require its bounded,
   ordered event semantics and measured tick span, then retain at least one
   actual non-neutral command admitted through the ordinary keyboard path and
   its subsequent completed Rapier step. Accepted-command totals alone are
   insufficient because normal neutral input also submits commands. This adds
   an observation of the existing workload, not a different input tape.
2. Neither PACE nor its seven graphical fixtures pauses an already-running
   healthy Main/native owner, observes quiescence through automatic callbacks,
   and resumes that same owner. A future bounded probe should run after the
   measured window/capture and before existing reset/shutdown: use production
   pause, observe the worker's pause acknowledgement, require fixed native and
   Rapier ticks while Main/physics callbacks and submissions continue, then
   resume through the UI after neutral rearm and require both clocks and a new
   submission with unchanged owner/generation/epoch. Retain transition times
   and refuse missing, stale or frozen recovery evidence.

These are continuation requirements after the Windows startup blocker, not a
request to rerun broad lifecycle or five-rig performance suites now. Preserve
the existing 30-second pre-Build and 180-second case bounds, sample window,
seven-fixture matrix and every first failure. Add focused missing/malformed
tape, neutral/unadmitted-action, pause-acknowledgement, post-pause tick,
missing-resume and stale-identity controls when implementing that narrow probe.
No agreed graphical FPS/stall threshold exists: a custody-valid report can
still disclose a long measured gap, and must not be presented as uninterrupted
responsiveness. Physical devices, real OS-focus transitions and human feel
remain the separate #270 gate.

### Terminal phase 4 compiler-only diagnosis — 2026-10-31

The [registered continuation](https://github.com/techrote/cybersand/issues/305#issuecomment-6536254998)
publishes diagnostic head `5de468478c37c8ae9e2d446ba348d4e3ecf54bd6`, tree
`8957ae44174226758069a534f8a4c03edce79e51`, parent exactly phase-3 head 512.
[Run 41149030607](https://github.com/techrote/cybersand/actions/runs/41149030607)
is now terminal FAIL. Original artifact **13022287635** retains both first
full-HLSL failures, with no retries. [Review 5720034205](https://github.com/techrote/cybersand/pull/312#pullrequestreview-5720034205)
records substantive source review as an owner-account COMMENT, not a separate
account approval.

The [exact-input replay](https://github.com/techrote/cybersand/blob/5de468478c37c8ae9e2d446ba348d4e3ecf54bd6/tools/diagnostics/replay_pace003_hlsl.py)
authenticates original phase-1 ZIP 13020405751 and reuses its exact 175,942-byte
control HLSL `192c1a08...`. Source name, entry/profile, macro array, null include
pointer and flags2 remain identical. One fresh process calls the authenticated
absolute System32 compiler at `0xc000`; a second uses `0xc004`, changing only
`D3DCOMPILE_SKIP_OPTIMIZATION`. Validation remains enabled. Both keep the
180-second process cap; tiny API preflights use a separate source/process.
No Godot, graphics device, native World or production shader/runtime setting is
changed, and no compiled output is installed into a graphical acceptance cache.

The review resolved an attribution gap: `compile-return.json` is persisted with
HRESULT and exact call wall/thread/process CPU immediately after the compiler
returns, before blob capture, disassembly or DLL rehashing. The parent checks
case/PID/TID/flags, raw CPU arithmetic and equality with any later result,
separating API return from complete diagnostic postprocessing. A timeout or
completion observed beyond the fixed deadline stays red. Sixteen focused
controls pass normally and under Python optimization; invocation review receipt
SHA-256 is `641da407d3b7c7f3398da309851e9a7759052a2c14913c2937c92fac5d3d1d3f`.

Both tiny preflights return HRESULT zero with immediate API-return receipts,
DXBC and disassembly, at 0.0017259/0.0015380 seconds of measured API wall time.
The full source behaves differently in both fresh processes:

| Original full-HLSL case | Flags | Case timeout observation | Total process / compile-thread CPU at timeout | API return / postprocessing |
|---|---|---:|---:|---|
| Original O2 | `0xc000` | 180.0135896 s | 179.859375 / 179.859375 s | Neither observed |
| Skip-optimization bit only | `0xc004` | 180.0126130 s | 179.984375 / 179.968750 s | Neither observed |

Neither full-source row has `compile-return.json`, `end.json`, returned
bytecode or a message blob. Both retain a complete begin/input identity and
`case_timeout`; the small observation overshoot does not change the 180s cap.
The CPU values are total process/thread samples at timeout, including setup
and that observation interval, not exact API durations or samples taken before
180s. The original final report SHA-256 is
`bbc8385cdbebf857a9ef765a74d0f5108183f9b43abfca937c4e894e66093194`.
Its `experiment_completed` status means the two planned diagnostic cases were
recorded, not that compilation or qualification passed; the workflow exits red.
Independent custody receipt SHA-256
`defad456c71c3a07a233600b34848994d365ab9379b47a7934674b7597eafd07`
verifies all 64 original files, the nested phase-1 ZIP/API/HLSL, six raw-exact
Git source copies, both preflights and each row/log/stage record. Actual
compile PID/TIDs match minidumps captured near 150.009/150.011 seconds in the
authentic compiler; these captures are separate from the timeout CPU snapshots.
The matched public PDB maps nearest instructions to `MatchComplexTree+0xb61`
and `CompactPool_Excluded+0x37`, respectively. Neither nearest symbol supplies
a full unwind, source location or internal-pass attribution.

The bounded CPU-heavy failure reproduces with the exact HLSL and authentic
System32 compiler without Godot, an executing ANGLE renderer, a graphics device
or native World. Those components are therefore not necessary for this isolated
reproduction. Adding only skip optimization does not make the input finish
within the contract; it does not isolate an O2-only defect or a named internal
compiler pass. The result supplies no completed-duration ranking and no reason
to broaden the first contrast into an unbounded flag search. No renderer or
runtime change, relaxed deadline, visual reduction or cache substitution is
accepted. Fundamental renderer incapability is not established.

Windows remains the unresolved correction gate. Retain the exact captured
input, compiler identity, failed variants and standalone reproduction alongside
the Linux-validated hoist and prepared evidence/monitor fixes. The following is
a concrete continuation proposal, not an implemented or qualified architecture.

### Proposed bounded owner decision and continuation

The existing manual owner should choose and register one bounded next lane in
#305/#309, preserving #308/#310/#312's branches, review history and evidence.
Keep the Linux-validated guarded hoist as the recoverable production candidate.
Neither alternative below is asserted to work, and neither authorizes #309
closure or #308 integration while its resulting-head gates remain red.

| Proposed lane | First reviewable experiment | Acceptance boundary |
|---|---|---|
| Palette-program decomposition | Design a bounded partition of the current palette program, explicitly mapping each material/current-previous path, render target and composition step to the existing route. Register exact shader/presentation/apparatus files before implementation; compare the original and partitioned generated inputs and first cold compiler/draw timings. | Preserve exact native HDR framebuffer/PNG results, compositing/alpha/history semantics, camera, all material/detail paths, glow/trails and actual Main gameplay. Keep all expensive required startup inside the original measurement contract and retain the unchanged 30s acknowledgement and 180s process caps. No partition is selected or shown feasible by this proposal. |
| Upstream compiler/runtime investigation | Provide the exact source-5de/run41149030607 standalone reproduction: 175,942-byte HLSL, original invocation metadata, authentic compiler identity, both failed flags, original captures and censored CPU observations. Seek a source-matched upstream diagnosis or bounded candidate runtime. | Before any acceptance on a changed engine, separately register and authenticate its new source/engine pin and relevant runtime/provenance inputs, then execute the complete resulting-head matrix. An upstream suggestion, different compiler setting or unverified binary is not a correction receipt. |

The proposed code write boundary is Godot shader/presentation code, its focused
graphical/behavior apparatus and corresponding documentation. Native World,
worker/pool/publication ownership, Rapier threading, input/equipment ordering,
liquid-policy semantics, scientific fixtures and training work are excluded.
Any engine-pin/provenance change in the upstream lane requires an explicit
additional registered write set and source/runtime authentication; it is not
silently folded into a shader edit. Neither lane changes CI provider/hardware
or renderer flags, adds hidden prewarming, drops visuals or easier workload,
or expands the failed contrast into optional O0 experiments.

Before claiming a correction, the chosen lane must supply all of the following:

- Clean GitHub-hosted Windows/Linux execution of the actual `main.tscn` route
  under the registered original platform controls, with a genuine cold process
  per explicit one-worker and Auto row on equivalent content. Retain every first
  attempt and any failure, accepted terrain/actor, a real PNG, the latched
  pre-Build acknowledgement within 30s, the 180s case and 240s import caps.
- Source-matched original/candidate native-HDR and PNG comparisons across the
  standard/extended material inputs and the full presentation/composition path,
  plus direct actual-Main visual inspection and all seven existing graphical
  regressions. Keep all five mechanical presets, policy/refusal, failure/stale
  and retirement assertions; a successful isolated shader does not qualify Main.
- Separate startup and steady-state records for submissions, native completions,
  p50/p95/p99 intervals, boundary stalls, snapshot/payload age, task participation,
  publication/coalescing and join. Require the existing input tape and the narrow
  healthy automatic pause/resume probe above before a new direct-responsiveness
  claim; no parallel scaling or FPS guarantee without its own measured evidence.
- Exact source/tree/runtime/LFS manifests, original logs/artifacts/captures,
  exit codes and independently checked SHA-256 receipts. Do not reuse a warm
  result, reconstructed file or earlier tree's green as cold acceptance.
- All applicable resulting-head Docs/provenance, Native including full TSan,
  Windows/Linux ordinary Godot and graphical gates, substantive review, fresh
  ownership reconciliation and expected-head guarded integration. #269/#270/#263
  retain their separate requirements, including physical devices and human feel.

### Original output receipts and remaining integration order

The following are raw original artifact ZIP identities; the cancelled draft Docs
artifact is retained alongside the successful ready run. The independent
ordinary-gate originals manifest above binds each full original job log as well.

| Artifact | Run | Bytes | SHA-256 |
|---|---|---:|---|
| 13015773481, cancelled draft Docs | 41136429118 | 1,364,791 | `5b71997a4d6dc320f30075c96ead140c3e81943f9c21065347d21fc9659344ae` |
| 13017157289, Docs | 41136597980 | 1,364,790 | `b2e8b5f47effe6308920946b6fc330c5f93cf3a17389fb3a4a6d8cb3eaa833fb` |
| 13017421338, Native physics | 41136597982 | 94,663 | `48847d9fa4ae18ee551cd95335585048041b98527d347bbfe68c2ee6c3efe7d0` |
| 13017333133, Linux runtime | 41136597999 | 21,905,803 | `af03e188886755deb519f97f0c5954701ee1e762beb519cc978e50bda092c434` |
| 13017935940, Linux shard 0 | 41136597999 | 4,335,428 | `dd2226eff261323aa0a2a83a341594abfd43f99c46449fb29c03fdc742bf4853` |
| 13017596161, Linux shard 1 | 41136597999 | 162,542 | `2e513c80a4e49ed24985861701df8d5b2d4ae1a98cd3ba8de26c33d6d68f83d9` |
| 13017640706, Linux shard 2 | 41136597999 | 3,210,465 | `5e76a15f959df85135b365f3e3f632c99b68c32f3abaacb08edd0e01ffeaa375` |
| 13018150494, Linux shard 3 | 41136597999 | 606,662 | `88329c1485670518168bb56374df0008c9501302ab1e1c0bb14078b6c9c3eefc` |
| 13018515006, Windows shard 0 | 41136597999 | 834,844 | `798c3f01207d5a7a56f6c3db3666e1632e0e36c9201539811ea845f8d8b2e9d6` |
| 13018196065, Windows shard 1 | 41136597999 | 390,072 | `6d5fb6534db5ff9a1e0ba371b9554b605b6519577c0eb145615d6c7a21c73f06` |
| 13018280950, Windows coverage | 41136597999 | 2,331 | `36b9f279de2d51cac08758d912e6dcdfc48a6fcc082a00ca92dd636d5d239412` |
| 13017796871, physical timings | 41136597999 | 3,728 | `bd14fee57219526772272d142bb4fe179c0f20b0f79429d2a5ba499a31f96e70` |
| 13017233186, Linux PACE/graphics | 41136597969 | 22,054,628 | `dc63bf37db0721663f99ea74f170cb8b39cabe365735b7696df64c4d864fe188` |
| 13018441199, Windows PACE/graphics | 41136597969 | 3,180,192 | `93f628af503c5c03d7d9fc98dd78bfb15d71beb20b7d127e9d6c742ac9e1797b` |
| 13020405751, Windows diagnostic phase 1 | 41139717684 | 3,299,869 | `426dd61cb2dc13395c586b4e601f83f67f16865f1d101cd2dab28682be6b6fad` |
| 13020262243, Windows diagnostic phase 2 | 41141840826 | 3,329,600 | `636ff23fd0161740480222800339e5b98562c9e454d56195b545a11c88544492` |
| 13021010697, Linux original/hoist diagnostic at 512 | 41144657056 | 29,226,705 | `f71c8b2e424736778b37cff45f094e40f4d7446b944efbd5605e68360f95f5bf` |
| 13020508845, Windows original/hoist diagnostic at 512 | 41144657056 | 830,545 | `e4cb52741ddad0a6943bcf2e03e6b1dcade1b7b80d53bbfda3620d6f6712097d` |
| 13020549731, Windows diagnostic phase 3 | 41144657058 | 2,860,062 | `e419f33c5a5e85a86a0209e7b847ed5e6a395100564472fc71aafc11c72443b4` |
| 13020810883, source-512 Docs | 41144657170 | 1,364,790 | `8053fef81a1008ca9872f510eb12234c3af60261521c0210b3acfe80f9fb9778` |
| 13022287635, exact-HLSL compiler-only phase 4 | 41149030607 | 3,026,839 | `8cb709913ebc99b425dbc76888e6c5b0750e7e2ecc5044908b624aa4870dbd3d` |

The phase 1 original job 124354789522 log is 51,019 bytes, SHA-256
`ba876049ed192a4e429608153894516447bc19eacb7bf216b41ada08e6a18875`. The phase 2
original job 124357722115 log is 51,224 bytes, SHA-256
`49e52cf62072b59f43f8e2ff10f80e65df729299b9a7d02e0a2f1d31ddb25c96`. No failed
artifact, incomplete compiler call or omitted source copy is reconstructed or
overwritten by a successor.

The source-512 hosted Linux job 124366820504 log has SHA-256
`a5dc3d358dfb1d8f46a82a8213d14d0143d25becd1ee78563206d5e06b560010`.
The separate #312 49b-through-f20 run/attempt ledger retains all 24 attempt-1
runs, 73 jobs, 13 executed-job logs and 12 original ZIPs, including cancelled and
skipped draft outcomes; its JSON SHA-256 is
`18c037e1ce20bdb805db2ff17b661aa99911c9b032f4f947b411a1e7e9f20da1`.
That ledger's end revision is f20; it does not assert a phase-3 Windows result.

The source-512 continuation ledger has SHA-256
`b6c7ac4b493f5ff2ca1c0fd218424903bac74f61b0af5bf95421679b5846ae1f` and adds six
original attempt-1 runs, 19 jobs, four executed-job logs and four ZIPs. Together
the two ledgers retain **30 original runs/attempts, 92 jobs, 17 executed-job logs
and 16 original ZIPs** through 512; 75 skipped jobs are not passes. The separately
retained phase-4 replay above is outside those through-512 totals. Source-512 Docs
[41144657170](https://github.com/techrote/cybersand/actions/runs/41144657170)
passes at merge checkout `53acec81ceaa792bcb0771cc2b5c18322f50ea6d`, whose tree
and exact base/head parents match 512. Its dependency-pins/published-runtime
provenance step was skipped. Native 41144657184, ordinary Godot 41144657289 and
PACE qualification 41144657239 are draft-skipped, not resulting-head greens.

The original decoded source-512 logs are: Docs job 124366820753, 97,728 bytes /
SHA-256 `f08e093689d1edb306e9b6e4e32e23f1a9f46c8b0acd08d86ec45f4d3bf115b2`;
generic Windows job 124366820691, 42,966 bytes /
`f08a82a0416089039de6942c9f426bacc726cd7642838af7c855838ed6d296e1`; matrix
job 124366820371, 52,637 bytes /
`9325478d7fd5c84fe4d6398b3a49940e93d38e25e4a69585443697d35dd76e47`.
The Linux original log identity is above. Connector-decoded logs retain their
disclosed UTF-8 representation; they are not claimed to be raw HTTP bytes.

The separate phase-4 replay job 124380857479 original decoded log is 48,256
bytes / SHA-256
`b9fa406239cab87335692c8cf3b6aaac2c89c8121c74e67dcd33d15f53442b75`.

Fresh read-only #311 reconciliation at 2026-10-30 23:50 UTC records open draft
head `3ed088cfa3d289dd18b6e40bf1d7e810a6785ea5`, tree
`34dbadbc4ecfd1a9e832090f4d5f458d764eeff2`, based on accepted main b55ce690.
Its sole changed path is the added `.github/workflows/native-parallel-qualification.yml`,
disjoint from #308/#310/#312. The owner-held **DO NOT MERGE / non-required**
disposition persists; no new #305 ownership registration or review was visible.
Run 41139999997 has success metadata, but that reconciliation does not qualify
its original logs/artifacts. Its TSan and ASan+UBSan build/run bounds and combined
soliding sanitizer build bound differ from the mandatory gate; the body claim
that only TSan's deadline changes is incomplete. This is an owner finding, not
authority to alter or adopt that PR. Receipt SHA-256 is
`75d9c7e79f25f2136ce56cb8a3eb1b62af9f8f0815b3e05c07aefdcd69acc45a`.

#309 remains open because Windows cold Main qualification is red. Preserve
the Linux-validated correction on #310 and keep diagnostic #312 separate until
a bounded production choice has causal/visual support and new exact-head
Windows/Linux evidence. Any correction or documentation/readback successor
must retain its own source/tree and applicable gate disposition; 62d greens do
not qualify a different tree. Integration into #308 requires fresh ownership
reconciliation and expected-head protection; #308 must not merge into main
until the complete resulting-head matrix, including Native TSan, is green.
The separate non-required Native experiment in draft #311 is owner-held and
does not substitute for that gate. #269/#270/#263 remain open for their own
requirements. Training/scientific fixtures, native ownership, main-thread
Rapier, liquid policy and runtime/LFS authenticity remain unchanged.
