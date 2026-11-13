---
title: RENDER-UPLOAD-001 GPU material publication investigation
status: Current
document-kind: audit
scope: Isolated opt-in drawable-texture prototype, original camera evidence attribution, exact Godot API mechanism and source-qualified qualification
canonical-for: [render-upload-001-investigation-evidence]
last-reviewed: 2026-11-13
related-documents: [../systems/material-appearance-and-rendering.md, ../architecture/rendering-and-gameplay-bridges.md, ../reference/validation-evidence.md, ../operations/local-build-and-validation.md]
---

# RENDER-UPLOAD-001 GPU material publication investigation

**Draft / HOLD. No merge or production-default promotion.**
[Issue #577](https://github.com/techrote/cybersand/issues/577) owns this bounded
research and its final engineering report: hosted measurements, raw artifact
links, failures and the architecture decision. This immutable source checkpoint
contains the executable protocol, preflight evidence and opt-in candidate. Keeping
the campaign report in the canonical issue allows every hosted receipt to retain
the exact executable commit it tested. A smaller submitted payload is not by
itself a performance result.

## Contents

- [Source and scope](#source-and-scope): preserved accepted main and independent feature ownership.
- [Pipeline reconstruction](#pipeline-reconstruction): native dirty regions through immutable handoff to final sampling.
- [Original evidence](#original-evidence): verified historical #566 samples and their measurement limits.
- [Pinned Godot mechanism](#pinned-godot-mechanism): full updates, supported rectangular blits and backend boundaries.
- [Candidate comparison](#candidate-comparison): selection and rejection reasons without theoretical-byte claims.
- [Prototype and failure contract](#prototype-and-failure-contract): complete temporal history, bounded storage and fallback.
- [Qualification and measurements](#qualification-and-measurements): executed gates, reproducible commands and preserved failures.
- [Recommendation](#recommendation): explicit production decision and remaining gates.

## Source and scope

Starting accepted main is `ac0d9fb944cb5a81369d03c0c3bc5eab50ab6742`, including
merged #565. The separate `research/render-upload-001` branch is based directly
on that source. Initial live inspection found camera #566 open/Draft at
`90838045d6fe8085646f2318f9753b8c3a92af29`, Flatten #572 open/Draft at
`529c5df85193363f7e67d5153590157da15dc908`, and agent-painter #569 open/Draft at
`2a565df45efc568eb96a2166e0b77f299e289625`. None is an implementation dependency
or an authorized write target of this investigation.

Immediately before publication, main was still `ac0d9fb9`; #566 remained
open/Draft and had independently advanced to
`f8041847bc7627b3fdd3d7426d45f646f79995fd`. Its new source is not incorporated
or relabelled as this experiment's accepted baseline.

The retained native runtime is reusable because this branch changes no native,
GDExtension or native dependency source. The campaign authenticates every current
native input, both the committed LFS object and actual platform binary, native
and Rapier provenance, engine archive, launcher and actual engine executable.
This is a new script/rendering experiment with a retained source-matched native
runtime, not a new native build. The exact qualification commit, tree and all
research input hashes are emitted by the campaign, alongside any local delta.

## Pipeline reconstruction

1. Native [`RenderSnapshotExchange::publish`](../../native/src/world.cpp)
   leases immutable storage. The World publication implementation discovers and
   sorts dirty chunks, preflights capacity, copies material/condition bytes and
   clears dirty state only after complete capture. Backpressure and capacity
   failure retain changes. Native workers call no Godot API.
2. [`CyberNativeCellWorld::take_render_snapshot`](../../godot/native_extension/cyber_native_cell_world.cpp)
   transfers the native lease into copied Godot metadata and byte arrays.
3. The exclusive [`CyberSimulationWorker`](../../godot/scripts/simulation_worker.gd)
   accumulates unacknowledged patches, publishes immutable arrays and carries the
   render serial, material revision and World generation with those exact bytes.
   A status snapshot may retain an older material publication. Excess accumulated
   patches or bytes request a complete resynchronization.
4. [`Main.consume_render_snapshot`](../../godot/scripts/main.gd) ignores already
   consumed render serials. `apply_render_patches_to_image` validates the entire
   metadata packet before making compact temporary Images and blitting them into
   the persistent CPU material plane. The full-image default then alternates the
   previous/current GPU resources and calls `ImageTexture.update(image)`.
5. The unchanged [`material_palette.gdshader`](../../godot/shaders/material_palette.gdshader)
   samples material IDs, condition and neighbours from the appropriate complete
   temporal snapshot. Emission and vapour also consume ordinary Texture2D
   bindings. Material appearance remains derived presentation; the CPU/GPU
   images never own native cells or material quantity.
6. Main acknowledges the render serial only after an accepted publication. World
   generation changes invalidate vapour history; ordinary full transport refresh
   does not mean World replacement. Skipping a status snapshot and rejecting an
   incomplete material publication remain different operations.

The precise native copy, lease and ACK contracts remain owned by the canonical
[render bridge](../architecture/rendering-and-gameplay-bridges.md) and
[data ownership](../architecture/data-ownership-and-lifetimes.md), not this audit.

## Original evidence

These are **original #566 measurements**, not new execution of this prototype.
The retained ZIPs and extracted report bytes were independently matched to the
GitHub artifact digests from [run 43501089014](https://github.com/techrote/cybersand/actions/runs/43501089014).
The candidate was `aa2d1c0aa49dd20cb8bb5ce0e003b1901a4f6f06`; accepted-main
comparison was `ac0d9fb944cb5a81369d03c0c3bc5eab50ab6742`.

| Original manual 2048² candidate | Windows | Linux |
| --- | ---: | ---: |
| Measured changed publications | 16 | 16 |
| Native dirty payload | 9,120 bytes | 9,120 bytes |
| Logical complete-image submissions | 134,217,728 bytes | 134,217,728 bytes |
| Combined CPU upload-path p50 | 120.569 ms | 0.888 ms |
| Combined CPU upload-path p95 | 123.940 ms | 0.962 ms |

- [Windows artifact 14078701733](https://github.com/techrote/cybersand/actions/runs/43501089014/artifacts/14078701733):
  SHA-256 `9c24c8f9f2c0963ae8b8edd1232b1b5099f1c7b7c81844ad6a1ff8da5b859b30`.
- [Linux artifact 14079096347](https://github.com/techrote/cybersand/actions/runs/43501089014/artifacts/14079096347):
  SHA-256 `b7bd920919a796dda3a46eb22cabbde582f6d95a0ab720a58ed451628c9b930a`.

The original timer covers validation, byte slicing/compaction, temporary Image
construction, CPU blitting, texture update, binding and history bookkeeping.
It is not GPU completion or PCIe traffic. Its 16 upload events occupy 4.44% of
360 frames, so overall frame p95 can miss these stalls; nearest-rank p95 of the
16 upload samples is their maximum. The later `78a277f2` campaign's
140.566/1.556 ms Windows/Linux p95 values remain separate replication.

Windows used ANGLE/D3D11 Microsoft Basic Render Driver; Linux used OpenGL
llvmpipe LLVM 20.1.2, on different hosted CPUs. That is a comparison of software
stacks and machines, not an isolated operating-system or hardware-GPU result.

## Pinned Godot mechanism

The project pins **Godot 4.7.stable.official.5b4e0cb0f**, full engine commit
`5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`. Inspected source:

- [`ImageTexture`](https://github.com/godotengine/godot/blob/5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88/scene/resources/image_texture.cpp)
  checks size/format/mipmaps and submits through `RenderingServer.texture_2d_update`.
  Its API has no arbitrary destination rectangle.
- [Compatibility texture storage](https://github.com/godotengine/godot/blob/5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88/drivers/gles3/storage/texture_storage.cpp)
  maps R8/RG8 to GL_R8/GL_RG8 without a Godot RGBA conversion. The ordinary 2D
  branch calls full-size `glTexImage2D`; array layers use `glTexSubImage3D` over
  a complete layer. No dirty-image comparison elides identical content here.
- [`DrawableTexture2D` API](https://github.com/godotengine/godot/blob/5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88/doc/classes/DrawableTexture2D.xml)
  exposes rectangular `blit_rect` into a persistent ordinary sampled Texture2D.
  It is explicitly experimental, but implemented for GLES3 and RenderingDevice.
  Its smallest target format is linear RGBA8, rather than R8/RG8.
- [`RenderingDevice`](https://github.com/godotengine/godot/blob/5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88/servers/rendering/rendering_device.cpp)
  exposes texture-copy machinery and whole-layer update. A separate RD design
  would not cover the project's Compatibility default.

`glTexImage2D` is a full-image redefinition request; it is not proof of new GPU
allocation every call. Inspected [ANGLE D3D11 source](https://github.com/google/angle/blob/d8c00a9d42834118e90c3a8a7fb562bcf86a7145/src/libANGLE/renderer/d3d/TextureD3D.cpp#L1673) can retain storage when the
dimensions/format match, while still loading the full source region. Profiling
the actual Windows ANGLE/D3D11 branch, staging allocator or software rasterizer
requires more than the original timer. The inspected ANGLE dependency branch is hypothesis support, not independently established identity of the official Windows binary or its executed internal branch. Timing ratios alone do not identify it.
Godot's `Image.get_data()` uses copy-on-write storage, so an unconditional deep
Godot CPU copy is also not established merely by that call.

`RenderingServer.force_sync()` drains/synchronizes the rendering command queue
in the [inspected implementation](https://github.com/godotengine/godot/blob/5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88/servers/rendering/rendering_server_default.cpp#L435); it is not a demonstrated GPU completion fence.
The API diagnostic separately times update, queue drain and actual full readback.
Readback includes completion, conversion and copying costs and deliberately stays
outside ordinary frame cohorts. It still does not measure physical transfer bytes.

## Candidate comparison

| Candidate | Current assessment | Correctness and maintenance cost |
| --- | --- | --- |
| A: avoid duplicate publication | Existing serial guard and native NoChanges already suppress the common duplicate; narrower byte-equality opportunities remain unproven | Exact identity/ACK/history semantics must survive; full-plane comparison costs work |
| B: ImageTexture/RenderingServer rectangle update | Ordinary update APIs have no destination rectangle; no supported simple drop-in subrectangle upload | Direct private OpenGL access or an engine patch would add an unjustified boundary here |
| C: tiled Texture2DArray | Credible supported full-layer update; one array sampler can avoid one draw per tile | Requires changing every material/effect sampler and preserving independent layer histories; deferred because a smaller candidate exists |
| D: DrawableTexture2D patch blits | **Selected bounded prototype**; supported public experimental API on GLES3/RD, no palette/effect shader rewrite | Double target bytes for RG8; staging resources and extra draw/copy work; explicit history journals and backend qualification |
| D: RD-only compute/copy | Technically possible on an RD backend, outside Compatibility | Backend dependency and resource-lifecycle complexity exceed this bounded task |
| E: full/partial threshold | Simple prototype threshold only: 50% dirty area or over 64 coalesced regions uses one full blit | Threshold is a research parameter, not an asserted measured optimum; dense full blit adds work versus legacy update |

## Prototype and failure contract

Select privately with `-- --render-upload=drawable`. Omit it, or use
`-- --render-upload=full`, for the existing default. The research harness can
set `render_upload_strategy_override` before mounting the same Main scene.
No permanent product settings interface is added.

[`render_upload_experiment.gd`](../../godot/scripts/render_upload_experiment.gd)
owns two complete RGBA8 targets and one dirty tile journal per target. Every
accepted patch marks both journals. The next target uploads **all regions it has
missed**, extracted from the complete canonical CPU Image, before the pair swaps.
It does not assume that the latest patch makes a two-publication-old target
complete. Journals use 64-cell tiles, coalesce row runs, and are bounded to 4,096
tiles. Native render serials may have gaps because the worker retains/coalesces
changes; stale/repeated serials are refused. World replacement requires explicit
complete-image coverage. Full refresh invalidates all tile coverage.

The new tiny [`texture_blit` shader](../../godot/shaders/render_upload_copy.gdshader)
uses nearest filtering and disabled blending. The existing palette, emission,
vapour, camera and native sources are unchanged. A startup readback canary checks
byte-preserving RG8-to-RGBA8 copying. Routine publications perform no GPU readback.

Preflight and source-resource allocation finish before target writes. Staging
textures are retained through `frame_post_draw`, bounded to 128 MiB and 64 batches.
Refusal preserves the accepted GPU pair and journal state. Main withholds ACK,
requests the existing full refresh and keeps the last valid display. After a
valid complete refresh it exceptionally reads the old valid current texture once
to reconstruct the previous ImageTexture, publishes the complete new current
image and disables the experiment for that Main instance.

The engine blit API returns void. Acceptance means successful application
preflight and command submission, not an independent per-blit GPU success signal.
The canary and exact framebuffer/readback gates address tested backend behavior;
driver/device-loss recovery remains an explicit production qualification limit.

At 2048², two RG8 baseline textures have 16 MiB nominal texel storage; two RGBA8
targets have 32 MiB. The CPU RG8 plane remains 8 MiB. Source staging, retained
driver copies and framebuffer/effects add to these numbers; nominal texel bytes
are not process RSS or measured physical VRAM allocation.

## Qualification and measurements

### Apparatus and admission

The dedicated [workflow](../../.github/workflows/render-upload-research.yml) runs
this owner-authorized research on the isolated Draft head. General repository
Draft suppression remains unchanged. Two literal hosted platforms execute their
own sequential same-host ABBA twice for each of fifteen cases (three groups per OS, six independent runners), keeping source, fixture, engine, platform,
renderer and all raw arms. The
[campaign runner](../../tools/render_upload/run_campaign.py) refuses mismatched
runtime/source identities, incomplete samples, fallback during timing, invalid
native backend and changed initial image/fixture between arms.

The [API probe](../../godot/tests/probe_render_upload_api.gd) tests exact R8/RG8
rectangular copies and separately measures identical versus one-cell-different
full submissions at 512², 1024² and 2048². The
[correctness fixture](../../godot/tests/test_render_upload_experiment.gd) tests
complete temporal histories, rejection/fallback, resource recreation and actual
shader outputs. The [benchmark](../../godot/tests/run_render_upload_benchmark.gd)
distinguishes deterministic renderer-seam fixtures from the mounted native
Workbench, reusing the existing render-copy timing seams and #566's mounting
methodology with explicit donor attribution.

Synthetic sparse, repeated, disjoint/line, dense and full fixtures are exact
material-byte inputs to the real CPU/publication/shader path; they are not native
simulation performance. Mounted PAINT, native Art bursts, isolated activity and
interleaved Sand/Water are application cohorts. Native active scenes begin from
the same paused layout after warmup; their asynchronous tick progress and elapsed
time must accompany frame comparisons. They are not fixed-work solver benchmarks.

CPU patch, validation, image maintenance, source extraction, staging API, blit
submission, overall publication, frame interval, native worker/exchange/copy,
publication age, logical payload and memory counters remain separate fields.
Nested timers overlap. Frame intervals include fixture/test scheduling; GPU
transfer, hardware utilization and physical scanout latency are unmeasured.

### Current executed preflight

- Pinned 4.7 API probe: ten R8/RG8 whole-plane, boundary, overlapping/disjoint,
  same-frame reuse and full-refresh stages passed on local OpenGL llvmpipe
  LLVM 19.1.7 / Mesa 25.0.7. This is software rendering.
- Helper smoke: odd 257×263 image and three alternating publications preserved
  both complete current and previous images byte-for-byte. The second/third
  update repaired regions absent from the newest patch.
- Main opt-in mounted native PAINT smoke: four completed changing brush/erase
  operations, no rejected publications, drawable path stayed active.
- Complete graphical correctness: **214 assertions, zero failures**, 28 byte-identical framebuffer pairs plus one deliberately different stale-history negative control (29 comparisons), 19 expected refusal receipts and eight compact PNGs.
- Existing render patch handoff regression passed with the full default.
- Six final local smoke cases passed: manual/full, manual/drawable, active Sand/Water, disjoint regions, dense update and native burst. A separate coverage sweep exercised all six dirty-area strata.
- Independent source review found no P1/P2 blocker for bounded Draft research qualification; it explicitly withheld production acceptance.
- These are local-delta preflights, not resulting-commit hosted acceptance.

### Preserved failures and limits

An initial local graphical launch used an X server from a different execution
sandbox and failed before the fixture because its display was unreachable.
The succeeding local runs launch the display and Godot in the same command.
An earlier helper smoke omitted the Dummy audio driver; its unrelated audio
fallback diagnostic remains retained and is not a clean final qualification log.
No hardware-accelerated desktop is claimed by these local probes.
The first end-to-end local campaign passed the API, correctness and four timing arms, but its final custody check correctly failed because initial editor import created four new research UID files. That original campaign remains failed. The new resource UIDs are retained in source before the next campaign; unrelated generated legacy UIDs are explicitly excluded, never silently treated as source changes.

The [local preflight archive](2026-11-13-render-upload-local-preflight.zip)
retains the original failed display/audio/custody logs, clean correctness captures,
raw smoke samples and a per-file SHA-256 manifest. These are explicitly local
delta observations, not hosted resulting-commit acceptance or measured speedups.

The [bounded integration runner](../../tools/render_upload/run_regressions.py)
executes thirteen existing regression processes plus import on each hosted OS.
Seven mounted Workbench author/reopen processes require the drawable strategy,
passed canary and actual requested backend throughout. Default headless handoff,
World-generation and recorder controls, plus isolated overlay/palette/vapour
controls, keep their original scope and are not relabelled as mounted candidate
coverage. Original failures remain in the same artifact; only dependent reopen
cases are blocked when their author phase fails.

Hosted source IDs, raw artifact links, before/after tables, executed regression
results and further failures belong to the [canonical engineering report](https://github.com/techrote/cybersand/issues/577).

## Recommendation

**Experimental constraint: Draft/HOLD; full-image default retained.** The public experimental drawable API makes
a bounded implementation feasible without an engine patch or existing shader
redesign. Correct sparse publication is technically demonstrated locally. It is
not by itself a production recommendation: application frame improvement,
dense/active cost, Windows correctness, variance and memory must be evaluated
together. The canonical issue records the final **PRODUCTION CANDIDATE /
FURTHER RESEARCH / NO-GO** decision against actual campaign source and artifacts.

The proposed optimization is camera-independent. It changes how the complete
material snapshots reach ordinary Texture2D bindings, not their world-coordinate
sampling, physical-pixel motion or picking. Accepted legacy camera compatibility
is in this branch. #566 remains a separate unmerged source at intake; an eventual
camera join must be rechecked and qualified, not inferred from this report.

### Documentation map

Appearance/upload cost and private switch are routed through the canonical
appearance contract. Immutable owner/lifetime/ACK facts remain in the render
bridge. No native ABI, physics, material identity, solver, save format, gameplay
ownership or production control/default change needs a new ADR. This dated audit
owns measured evidence; retrieval/navigation links do not promote its experiment.
