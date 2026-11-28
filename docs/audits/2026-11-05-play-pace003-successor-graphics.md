---
title: PLAY-PACE-003 successor — graphical startup, FXC attribution and steady-state pacing
status: Current
document-kind: evidence
scope: Local Windows source-matched baseline of main ee92dc45, FXC cost attribution, four retained negative palette compiler-input experiments, steady-state pacing apparatus and the PR 394 exit-lifecycle handoff; no production shader or Main change
canonical-for: []
last-reviewed: 2026-11-05
related-documents: [../systems/material-appearance-and-rendering.md, ../operations/profiling-observability-and-performance.md, 2026-10-31-palette-shader-integration.md]
---

# PLAY-PACE-003 successor — 2026-11-05

## Identity and scope

| Item | Value |
|---|---|
| Source | main `ee92dc45b12455f01218394fd773da516caf356e` (unchanged production shader/Main) |
| Palette shader | full `f686ca416b5b011751ddd5d38a24824742d01cb8d489b46710ee1f1fbb2a09c1`, ANGLE bounded `7e5650cb807825e8febebd402dcba262d0df10baf02d478ee3c30f99ca3d460d` |
| Engine | Godot `4.7.stable.official.5b4e0cb0f`, win64 exe SHA-256 `b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8` |
| Runtime | `cybersand_native.windows.x86_64.dll` `ebd6d555…`, Rapier `b54e54bd…` (LFS-materialized, main pins) |
| Host | Windows 11 Pro 10.0.26300, Ryzen 5 5600X, 64 GB, NVIDIA TITAN RTX driver 32.0.15.8180; shared desktop with ~18% background load |
| Backends | native `opengl3` (NVIDIA GL 3.3) and `opengl3_angle` (ANGLE 2.1.1 → D3D11 FL11, `d3dcompiler_47.dll` from System32) |

All results are **local, NONQUALIFYING** observations on one discrete-GPU desktop.
No Linux, llvmpipe, WARP or hosted-runner result is claimed here. Single-sample
wall times on this host vary by up to ±20%; conclusions below rely on interleaved
repeats and on deterministic DXBC instruction counts.

## G1 baseline — Main cold/warm

`play_palette_shader_main_probe.gd`, two sequential Main lifetimes, isolated
`APPDATA`/`LOCALAPPDATA` per cohort (Godot program-binary cache cold, then reused).

| Driver | Cache | Main ack, lifetime 0 (s) | Lifetime 1 (s) | Process wall (s) |
|---|---|---:|---:|---:|
| opengl3 | cold | 1.97 | 2.22 | 8.41 |
| opengl3 | warm | 1.91 | 1.77 | 7.96 |
| opengl3_angle | cold | **70.81** | 2.05 | 79.31 |
| opengl3_angle | warm | 1.74 | 1.65 | 6.93 |

The NVIDIA driver keeps its own GL disk cache outside the redirected directories,
so "cold" native runs can hit it. A source with a never-seen uniform (forced driver
miss) shows the native palette link costs about **4 s** on a truly cold NVIDIA cache
(atlas first frame 4.06–4.83 s). Godot's program cache holds exactly one palette
program after cold Main (748,267-byte entry): there is no duplicate variant compile
and recreated Main reuses the selected resource.

## FXC attribution (new apparatus)

`tools/play/fxc_trace/` contains a forwarding `d3dcompiler_47.dll` proxy (placed
beside a scratch copy of the engine only). It records each ANGLE `D3DCompile`
call's exact HLSL, flags, target and thread time, then forwards unchanged.

Traced cold ANGLE Main: 64 compiler calls, 51.31 s in total. **One call — the
palette `ps_5_0`, 179,094 bytes of HLSL — took 47.64 s wall / 45.20 s thread CPU
(93%)**; the next largest took 1.33 s. ANGLE compiles with `OPTIMIZATION_LEVEL2`
(`0xC000`) and `ANGLE_ENABLE_LOOP_FLATTEN=1`. The offline harness reproduces the
identical 548,808-byte DXBC (18,134 instruction slots, 55 samples, 271 `if`,
25 `loop`).

Optimization levels 0–3 produce the same program and cost; even
`SKIP_OPTIMIZATION` costs ~44 s CPU and emits 33,839 instructions. The cost is
structural — FXC's handling of one fully inlined `main` — not optimizer depth.

Single-function ablation (offline, serial, stub returns its input; diagnostic only):

| Stubbed function | FXC wall (s) |
|---|---:|
| none (same batch) | 58.0 |
| `apply_material_flair` | 17.2 |
| `apply_building_finish` | 21.2 |
| `apply_structured_fill` | 30.8 |
| `apply_ambient_particles` (+growth/vapour) | 37.0 |
| `displayed_material_id` (both sites) | 39.2 |
| `apply_growth_decor` | 39.3 |
| `apply_detail_edges` | 42.7 |
| `apply_volume_and_contact` | 44.2 |
| `apply_neighbour_relief` | 46.8 |

Savings are strongly super-linear in removed code: the cost grows faster than
linearly with total inlined program size. This is the causal handle for the
planned shader rework: total ANGLE program size, not any one construct, dominates.

## Retained negative compiler-input experiments

Each candidate was generated mechanically, compiled through real ANGLE, and
checked with the unchanged strict `compare_pace003_palette_atlas.py` oracle.

| Hypothesis | Change | Native atlas | FXC, interleaved median of 3 (s) | DXBC instr. | Result |
|---|---|---|---:|---:|---|
| baseline | — | — | 45.8 | 18,134 | — |
| H1 nesting depth | 5 pure `id`-equality else-if chains → `switch` | 16/16 byte-exact | 51.1 | 19,714 | **Negative** (+12%) |
| H2 gradient flattening | `texture` → `textureLod(…, 0.0)` (no mipmaps; ANGLE then emits no `[flatten]`/`[loop]`) | 16/16 exact; ANGLE 16/16 exact | 44.2 | 18,171 | Neutral |
| H2b | HLSL-level attribute removal | — | 49.5 / 53.8 (single) | 18,171 | Neutral |
| H4 dedupe | one `[loop]` site computes both displayed IDs | 16/16 byte-exact | 45.2 | 17,981 | Neutral (−0.8% instr.) |

H2 was also checked at runtime because ANGLE's `[flatten]` makes the empty-cell
particle/growth block execute for every pixel. The presentation-cost apparatus
shows no gain (native world GPU 0.421 vs 0.429 ms; ANGLE uncapped frame
0.513→0.572 ms, consistently slower). Real-Main uncapped ANGLE pacing varies from
85 to 238 fps between identical baseline runs, so the apparent first-run gain was
an outlier. None of these candidates is proposed. Do not reopen them without a
new causal hypothesis; #316's decomposition NO-GO also stands.

## Steady-state pacing (new apparatus)

`godot/tests/play_render_pacing_probe.gd` runs one actual Main lifetime
(acrobat, native worker, main-thread Rapier, 1920×1080 window) through warmup,
idle, move-right/left (camera follow), brush rain and settle phases. A harness
subclass of `main.gd` times `_process`, `_physics_process`, snapshot consumption
and shader-parameter updates through `super()`, without modifying `main.gd`.
Separate clocks: presented-frame interval, viewport CPU/GPU time, native ticks,
Rapier steps, uploads, and key-edge to first presented frame with a changed camera.

Native GL, V-Sync on (3 repeats agree):

| Phase | Interval p50 / p99 (ms) | `_process` p50 (ms) | Uploads/s × ms | World GPU (ms) | Native/Rapier per s |
|---|---|---:|---|---:|---|
| idle | 16.68 / 16.77 | 3.3 | 0 | 0.36 | 60 / 60 |
| move | 16.68 / 16.86 | 3.3–4.2 | 0 | 0.36 | 60 / 60 |
| brush | 16.68 / 16.77 | 3.6 | 38 × 0.29 | 0.36 | 60 / 60 |

Input → first presented changed frame: one frame (3.7–15.2 ms). Uncapped native
GL reaches 221–326 fps. One 104.8 ms frame appeared once in the first brush run
(`_process` 3.8 ms, viewport CPU 0.8 ms, 7 native ticks elapsed); it did not recur
in three repeats and stays unexplained. ANGLE warm V-Sync pacing is 60 fps with
p99 ≤ 17.9 ms; ANGLE exposes no GPU timer (reads 0).

On this discrete GPU there is no demonstrated renderer bottleneck: the palette
pass is ~0.4–0.8 ms GPU at 1080p and the full 2,097,152-byte RG8 upload per
changed publication costs ~0.27 ms CPU. The largest per-frame cost is Main's
GDScript `_process` (1.4–4.6 ms), which belongs to the shared Main/workbench
write set; no change is made there.

## PR 394 lifecycle handoff

PR 394 head `38b9464efcfad8b0368418b1c2c6b96e4a5528b0`, palette run
[41941292111](https://github.com/techrote/cybersand/actions/runs/41941292111):
compile-guard, bounded-oracle and material-render pass; vapour-render and
Main cold/warm fail only the natural-exit policy. Their fixtures pass
(26/0 and 29/0) and then log `3 ObjectDB instances were leaked` and
`1 resources still in use at exit`. The same workflow passes on main `ee92dc45`
(run 41931371687), and the shader is unchanged. Locally, an export of PR 394 with
its own LFS runtime (`cybersand_native` `cb675a4c…`) runs the vapour fixture
26/0 and then **crashes at exit with 0xC0000005 on every run**; the identical
main export exits 0. Bare `main.gd` construction and vapour setup without rendering
exit cleanly. This is a PR 394 Main/worker lifecycle defect, not a shader or
compiler failure; ownership stays with PR 394.

## Reproduction

```text
# Usage strings: tools/play/fxc_trace/*.py
tools/play/fxc_trace/build_proxy.bat        # VS x64 developer prompt
CYBERSAND_FXC_TRACE=<dir> <scratch-godot-with-proxy> --rendering-driver opengl3_angle \
  --path godot --script res://tests/play_palette_shader_main_probe.gd
python tools/play/fxc_trace/fxc_bench.py 3 <out.jsonl> base=<call.hlsl> cand=<call.hlsl>
CYBERSAND_PACING_VSYNC=1 CYBERSAND_PACING_OUTPUT=<dir> <godot> --rendering-method gl_compatibility \
  --rendering-driver opengl3 --path godot --script res://tests/play_render_pacing_probe.gd
```

Raw traces, HLSL captures, atlases and pacing JSON are retained outside Git.

## Gaps

No hosted, Linux, llvmpipe, WARP, integrated-GPU or physical-display evidence.
FXC timings are single-host. The pacing probe is apparatus, not acceptance.
The unexplained 104.8 ms frame and PR 394's exit crash remain open.
