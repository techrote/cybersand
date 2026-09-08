---
title: Web worker profiles and reference tests
document-kind: runbook
canonical-for: [web-worker-profiles, worker-reference-benchmark]
status: Current
scope: Compatibility/threaded Web build and hosting, fixed worker policy, synchronous ownership, and reference-test interpretation
last-reviewed: 2026-09-08
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
| Compatibility, default | Forced 1 | `source/build/web` | Synchronous Godot callback |
| Threaded | Auto or explicit request | `source/build/web-threaded` | Same callback; phased jobs may run concurrently |

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

From `C:/kybersand`:

```powershell
.\dev.cmd web --profile threaded
.local/python/Scripts/python.exe source/tools/serve_web.py --directory source/build/web-threaded --port 8002 --open
```

While the preview server is running:

```powershell
.\dev.cmd http-smoke --profile threaded --url http://127.0.0.1:8002/
```

`dev.cmd web` builds compatibility. Use export-only only with a matching fresh
side module; successful packaging does not prove source-to-binary freshness.
The [build guide](github-development-and-release.md) owns exact dependency pins
and unresolved CI/toolchain drift. Native/Web generated bindings stay separate.

The supplied server sets COOP `same-origin`, COEP `require-corp`, appropriate
WASM MIME and no-cache behavior. Threaded hosting needs a secure context
(HTTPS or localhost) and cross-origin isolation. Serve the complete export,
including worker JavaScript, PCK, WASM, notices and manifest. HTTP/checksum
success is structural evidence; open the actual browser for execution.

Local delivery is a separate explicit workflow after acceptance:
`Deliver-Web.ps1 -Profile threaded` copies to `C:/cybersand/web-threaded`;
compatibility uses `C:/cybersand/web`. Documenting this command does not execute
delivery or remote publication.

## Reference benchmark and parity checks

Open Web **Performance**:

- **Benchmark:** supported actual worker counts from requested 1, 2, 4, 6;
  deterministic 480×480 and 960×960 Sand/Water worlds; ten warmup ticks then
  120 measured ticks per case with deterministic replenishment.
- **Stress test:** Auto at 960×960, ten warmup then 600 measured ticks.
- **Cancel/Escape:** checked between ticks, with a two-minute case limit.
  A native tick already running must finish before cancellation.

[worker_benchmark.gd](../../godot/scripts/worker_benchmark.gd) uses temporary
worlds, restores the process worker setting, and compares final exported-level
hashes. Reports include requested/actual workers, mean/p95/max native time,
test frame intervals, moves, parallel phases, and level hash. Frame intervals
include test/UI scheduling, not normal gameplay rendering. Copy results selects
JSON and attempts clipboard copy; the last successful report is stored at
`user://last_worker_benchmark.json`.

Local commands use the same headless Godot fixture:

```powershell
.\dev.cmd benchmark
.\dev.cmd stress-test
```

Logs/reports go to `validation/local/<timestamp>/`. Compare native tick timings
with browser tick timings, not headless versus browser frame intervals.

The opt-in URL `?test=1&parity=1` additionally runs the one/four-worker
four-demo probe: 30 ticks each, 120 exported-level hashes. It is also
[test_web_worker_parity.gd](../../godot/tests/test_web_worker_parity.gd).
Neither this nor the performance hash comparison proves complete replay state,
Rapier trajectory equivalence, or all-platform equality.

## Acceptance and unresolved limits

Use the [local validation procedure](local-build-and-validation.md) and the
host guide at `C:/kybersand/docs/BROWSER_VALIDATION.md`, then verify
both profiles: actual worker count, native exception rejection, render patches,
input/menu/pause/reset, level import and replacement-world lifecycle. Physics
Pit has separate [Rapier acceptance](rapier-2d-migration-runbook.md).

Historical tests exposed a stall with 12 prewarmed pthreads; a later four-worker
export used 24, and current Auto exports use 32. The preserved record does not
establish the minimum safe pool or robustness on every low-core device.
Retest replacement, import, benchmark cancellation, and pool release whenever
sizing changes. Browser/device coverage, complete replay, and production
frame-time thresholds remain incomplete.
