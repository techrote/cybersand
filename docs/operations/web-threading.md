---
title: Web worker profiles and reference tests
document-kind: runbook
canonical-for: [web-worker-profiles, worker-reference-benchmark]
status: Current
scope: Compatibility/threaded Web build and hosting, fixed worker policy, synchronous ownership, and reference-test interpretation
last-reviewed: 2026-11-24
related-documents: [github-development-and-release.md, rapier-2d-migration-runbook.md, ../architecture/simulation-tick-and-threading.md, ../reference/configuration-reference.md, ../reference/validation-evidence.md]
---

# Web worker profiles and reference tests

**Current:** compatibility Web uses one native cellular worker; optional threaded
Web uses the existing phased pool. Both synchronously finish a cellular tick in
Godot's `_physics_process`; Rapier stays on Godot main. Pthreads do not create
desktop-style asynchronous simulation/render ownership. That extension is
**Deferred**.

Source identity is in the [checkpoint](source-checkpoint-and-recovery.md), dated
native/browser evidence in the [validation ledger](../reference/validation-evidence.md),
and historical timing/failure records in the
[performance archive](../audits/2026-09-08-performance-history.md).

## Current profiles

[build_web.py](../../tools/build_web.py) stages the same native solver, assets,
and Web controller with matching thread/no-thread Godot templates and Rapier
WASM. [CyberNativeCellWorld::create_world](../../godot/native_extension/cyber_native_cell_world.cpp)
resolves worker policy at world construction.

| Profile | Cellular workers | Output | Ownership |
|---|---|---|---|
| Compatibility, default | Forced 1 | `build/web` | Synchronous Godot callback |
| Threaded | Auto or explicit request | `build/web-threaded` | Same callback; phased jobs may run concurrently |

Auto chooses 2/4/6 at reported logical-thread thresholds 4 and 12, including two
when only one logical thread is reported. Exact settings, clamps, and the
32-prewarmed-pthread/two-Godot-worker distinction belong to
[configuration](../reference/configuration-reference.md#adapter-worker-policy).
Prewarmed spare threads support overlapping current/replacement/test worlds;
they are not all simulation workers.

Web diagnostics use `navigator.hardwareConcurrency` for the browser's reported
logical count; the no-thread C runtime's fixed 1 is not physical-core detection.
Neither Auto nor the reference benchmark tunes a running pool from timings.

## Build and preview

Work from the actual source root. The source tools expose their accepted options
without compiling or exporting:

```bash
python3 tools/build_web.py --help
python3 tools/serve_web.py --help
```

A Web build requires isolated pinned `godot-cpp`, activated Emscripten, SCons,
the exact Godot executable and matching dynamic-link Web templates. Native test
bindings are a **separate checkout** passed through `--native-cpp` when
`--native-tests` is selected. Export-only requires an existing matching side
module; packaging alone cannot establish source freshness.

**Current source limitation:** the accepted workflows select Emscripten 4.0.11,
while `build_web.py` enforces 4.0.20; the workflow's `--native-tests` route omits
the separately required `--native-cpp`. The
[Godot lock](../../third_party/godot-runtime.lock.json) still records export
templates as `absent-and-unpinned`. A fresh source checkout therefore does not
have a qualified reproducible Web export path merely because these tools exist.
The [release guide](github-development-and-release.md#unresolved-ci-contradictions)
owns these source-visible gaps. Fixing producer/consumer pins, templates or CI is
a separately authorized implementation task.

For an **already produced, complete export** whose identity you have checked,
serve it from the source root:

```bash
python3 tools/serve_web.py --directory build/web-threaded --port 8002 --open
```

Use `build/web` for the compatibility profile. The server verifies required export
files, binds to loopback by default and supplies COOP `same-origin`, COEP
`require-corp`, WASM MIME and no-cache headers. Threaded hosting needs HTTPS or
localhost plus cross-origin isolation. Keep worker JavaScript, PCK, WASM, notices
and manifest together. HTTP/header checks are structural evidence; actual browser
execution is a separate gate. Stop the local server with Ctrl+C.

The former `C:/kybersand`, `dev.cmd web/http-smoke` and `Deliver-Web.ps1` recipes
belong to the companion workspace and its original configured environment. They
are preserved in the [source-pinned previous guide](https://github.com/techrote/cybersand/blob/00cdb02f103265b6dc5224c68283e9a0c8cb449f/docs/operations/web-threading.md#build-and-preview).
They are not scripts supplied by a standalone source clone and do not grant
publication authority.

## Reference benchmark and parity checks

Open Web **Performance**:

- **Benchmark:** requested 1, 2, 4, 6 and Auto, resolved/clamped to the runtime;
  deterministic 480×480 and 960×960 Sand/Water worlds; ten warmup ticks then
  120 measured ticks per case with deterministic replenishment.
- **Stress test:** Auto at 960×960, ten warmup then 600 measured ticks.
- **Cancel/Escape:** checked between ticks, with a two-minute case limit.
  A native tick already running must finish before cancellation.

[worker_benchmark.gd](../../godot/scripts/worker_benchmark.gd) uses temporary
worlds without rewriting the process worker setting, and compares final exported-level
hashes. Reports include requested/actual workers, mean/p95/max native time,
test frame intervals, moves, parallel phases, and level hash. Frame intervals
include test/UI scheduling, not normal gameplay rendering. Copy results selects
JSON and attempts clipboard copy; the last successful report is stored at
`user://last_worker_benchmark.json`.

The source checkout has a direct headless runner. With the exact pinned Godot
and source-matched native runtime available, use an isolated user profile as
explained in [local validation](local-build-and-validation.md):

```bash
godot --headless --path godot --script res://tests/run_worker_benchmark.gd
godot --headless --path godot --script res://tests/run_worker_benchmark.gd -- --stress
```

These execute benchmark workloads; they are not documentation-only smoke checks.
The runner prints `WORKER_BENCHMARK` JSON and accepts `--report=<path>` for an
explicit output file. It does not automatically create the companion workspace's
old `validation/local/<timestamp>/` tree. Compare native tick timings with browser
tick timings, not headless frame intervals with browser frame intervals.

The opt-in URL `?test=1&parity=1` additionally runs the one/four-worker
four-demo probe: 30 ticks each, 120 exported-level hashes. It is also
[test_web_worker_parity.gd](../../godot/tests/test_web_worker_parity.gd).
Neither this nor the performance hash comparison proves complete replay state,
Rapier trajectory equivalence, or all-platform equality.

## Acceptance and unresolved limits

Use the [local validation procedure](local-build-and-validation.md) and
source-matched export evidence. The old companion `BROWSER_VALIDATION.md` is not
a source-checkout prerequisite. Verify both profiles: actual worker count, native exception rejection, render patches,
input/menu/pause/reset, level import and replacement-world lifecycle. Physics
Pit has separate [Rapier acceptance](rapier-2d-migration-runbook.md).

Historical tests exposed a stall with 12 prewarmed pthreads; a later four-worker
export used 24, and current Auto exports use 32. The preserved record does not
establish the minimum safe pool or robustness on every low-core device.
Retest replacement, import, benchmark cancellation, and pool release whenever
sizing changes. Browser/device coverage, complete replay, and production
frame-time thresholds remain incomplete.
