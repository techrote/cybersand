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

## Evidence captured so far

- The pure C++ kernel and standalone oracle test were compiled locally with
  GCC 14.2.0, `-O2 -Wall -Wextra -Werror -Wpedantic -Wconversion -Wshadow`:
  `SCRIPT_HOTPATH_NATIVE_TEST PASS`.
- The same source-identity kernel/test also passed
  `-fsanitize=address,undefined` locally.
- Godot/GDExtension builds and source-matched Windows/Linux runtime benchmarks
  **have not yet run in this environment** (pinned Godot and godot-cpp absent).
  Do not treat pure-C++ passes as a qualified GDExtension or claim speedup.
- Target decision: promote only if differential parity holds and the end-to-end
  planning path demonstrates a meaningful repeatable gain, ideally at least 3x
  median at 262K cells without p95 regressions; otherwise preserve the negative
  result and return to the GDScript planner.

## Known limitations

- The existing 262,144-cell capture, operation and canvas bounds remain
  unchanged. This experiment does not permit bigger fills, bigger Worlds or
  bypass of host-claim admission.
- A high-throughput fill planner can still spend time in native material
  readback and PAINT executor application; the user-facing operation might
  not speed up by the same factor.
- Source-matched Godot differential tests and a genuine Windows owner
  evaluation remain required before merge approval.
