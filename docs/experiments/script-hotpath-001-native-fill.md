# SCRIPT-HOTPATH-001 — Native PAINT connected-fill demonstrator

**Canonical issue:** [#689](https://github.com/techrote/cybersand/issues/689)
**Branch:** `exp/script-hotpath-001-native-fill`
**Baseline:** main `de58bf1997ca75825cf3b29e046dc1c1022c45bf`
**Status:** experimental, Draft/HOLD. No owner merge approval.

## Why this candidate

`workbench_paint_editor_shapes.gd::fill_connected` performs a full bounded
material-ID validation, a 4-neighbour component search with GDScript dictionaries
and dynamic arrays, a sort, and a packed-coordinate conversion, on up to 262,144
cells. The selected cells are only a **plan**: the existing worker still
validates identity, source protection, cancellation and per-cell native edits.

The native `cybersand::paint_fill::plan` uses one compact visited array,
one vector for the FIFO queue and final sorted indices, and reads a contiguous
immutable material-ID sample. It returns value-only results, no pointer into
the live World. The `CyberNativePaintPlanner` GDExtension adapter converts
input/output once per operation.

**Explicitly not changed:** native World mutation, PAINT executor and receipts,
capture/undo/redo, GPU upload, PUBPRES #682, simulation timestep, actor physics,
rendering, or any web exporter.

## Compatibility / rollback

If no `CyberNativePaintPlanner` class exists, or interface v1/methods are
missing, `Shapes.fill_connected` uses the **unchanged** script oracle
`Shapes.fill_connected_reference`. To force script baseline in a rebuilt
native runtime, launch with `CYBERSAND_NATIVE_PAINT_FILL=script`.
A new source-matched Linux/Windows native extension must be installed before
the native branch can run. Existing binaries continue through the script path.
No .NET dependency is introduced. The adapter is header-only in the existing
registration translation unit, so it needs no additional native source entries.
Web exports still require a compatible rebuilt native extension.

## Repeatable qualification

Pure C++ regression (does not require Godot):

`make script-hotpath-native-test`

Optional sanitizers:

`g++ -std=c++20 -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined -Wall -Wextra -Werror -I native/include native/tests/test_paint_fill_planner.cpp -o /tmp/test_paint_fill_planner_sanitized && /tmp/test_paint_fill_planner_sanitized`

After rebuilding **the exact PR HEAD** native extension with the existing pinned
Godot 4.7 / godot-cpp tools:

`godot --headless --path godot -s res://tests/test_script_hotpath_native_fill.gd`
`godot --headless --path godot -s res://tests/bench_script_hotpath_native_fill.gd`

Run both default (native-present) and `CYBERSAND_NATIVE_PAINT_FILL=script`
where relevant. The benchmark compares **GDScript reference**, direct C++
GDExtension call, and production dispatch **in the same process**, and records
repeated samples, median and p95 for full-512, fragmented, and 65K bounded
regions. It does **not** measure source capture, native paint apply, GPU
submission, or general gameplay FPS. Measure them separately for an end-to-end
benefit claim. Rebuild after changing native sources: existing DLLs do not
implicitly pick up a new registered class.

## Measured and source-locked qualification

At the accepted experimental implementation SHA
`e943a0f87a6c8beea99caf33f1f85c7ae3c9f4e2`:

- [Exact-source Linux GDExtension and differential/latency checks passed](https://github.com/techrote/cybersand/actions/runs/44836004256);
  819 native and 819 script-fallback comparisons, plus native PAINT shapes,
  worker executor, and mounted Workbench checks.
- [Windows target-OS CI passed](https://github.com/techrote/cybersand/actions/runs/44837049074).
  The source-built Windows DLL hash was
  `4d46ecb1efdd23ce6dd2f6e61f7b353e41e7d61f1346bc4c90852960b22b7981`.
- Owner Windows 11 rendered qualification passed all 16 processes.
  Four interleaved native and four script Workbench executions recorded p95
  gaps **16.8625 ms native** and **16.8425 ms script** (a +0.119% difference),
  with 64 checks per Workbench run and no recorded failures. The separate
  rendered Godot Workbench probe selected **NVIDIA TITAN RTX, OpenGL3**.
  This separate device probe must not be represented as per-process adapter
  identity for every earlier A/B execution.
- Owner PAINT shape measurement for the 262,144-cell *planning* phase was
  11.395 ms native and 771.266 ms GDScript (approximately 67.7×).
  This is **not** a gameplay FPS gain or a capture/apply/render benchmark.

## SCRIPT-HOTPATH-PRODUCTION-001 — runtime publication

The committed GDExtension binaries are currently the desktop LFS pair:
`libcybersand_native.linux.x86_64.so` and
`cybersand_native.windows.x86_64.dll`. Their separately committed
`runtime-provenance.linux.json` and `runtime-provenance.json` manifests
must be rebuilt **together** from a single immutable PR source commit.

The dedicated
[`script-hotpath-production.yml`](../../.github/workflows/script-hotpath-production.yml)
is branch-scoped to `exp/script-hotpath-001-native-fill`.
Only an explicit `script_hotpath_production_publish_request.json` can arm
publication. The publisher inherits the established exact-source input
ledgers, pinned Godot 4.7 / godot-cpp toolchains, target-OS actual execution,
LFS pointer checks, four-path stage admission and branch-head lease.
A successful publisher appends a new binary/provenance commit to **PR #690
only**; it never merges or changes `main`.

The subsequent **full Ready-for-Review CI** must run on the resulting
publication commit before merge approval. Until that happens, all source
and runtime qualification remains an evaluation candidate, and the old
retained desktop binaries may still dispatch to the GDScript fallback.
The publication commit itself is not proof of a gameplay frame-rate gain.

Web `libcybersand_native.web.*.wasm` modules are **not committed LFS
objects** in this repository. They are compiled/exported by
`tools/build_web.py` with separate Emscripten/toolchain inputs, and
are not included in this four-file desktop publication. Web export
compatibility must be tested independently; an older module continues to
use GDScript fallback when the versioned native class is unavailable.

## Known limitations

- The existing 262,144-cell capture, operation and canvas bounds remain
  unchanged. This experiment does not permit bigger fills, bigger Worlds or
  bypass of host-claim admission.
- A high-throughput fill planner can still spend time in native material
  readback and PAINT executor application; the user-facing operation might
  not speed up by the same factor.
- The previous Windows owner and pinned Linux/Windows demonstrator
  validations have passed. Production publication and full integration CI
  remain separate, independently checked acceptance gates.
