---
title: Web worker profile
status: Current
scope: Current local Web worker profiles, synchronous ownership, build procedure and dated Windows/Chromium benchmark evidence
last-reviewed: 2026-09-08
---

# Web worker profile

Status: **Current** local source profiles; retained Chromium acceptance was
recorded on 2026-09-08. The [documentation audit](../audits/2026-09-08-documentation-audit.md)
separates inspected source identity and fresh checks from these earlier runs.
The workspace is a reconstructed snapshot plus local changes, not a source Git checkout.

Both Web profiles run the cellular tick synchronously in
[web_demo_controller.gd](../../godot/scripts/web_demo_controller.gd)
`_physics_process`. Threaded Web parallelizes jobs inside that call; it does not
have desktop `CyberSimulationWorker`'s asynchronous Godot owner. Rapier remains
main-thread owned in both profiles. Fully asynchronous Web ownership is **Deferred**.

The optional threaded profile builds the existing C++ phased scheduler with
pthreads and selects Auto workers using the owner's 2026-09-08 rules, implemented
by [the native adapter](../../godot/native_extension/cyber_native_cell_world.cpp):

| Reported logical threads | Auto workers |
| --- | --- |
| Fewer than 4 | 2 |
| 4 through 11 | 4 |
| 12 or more | 6 |

This policy is shared by the native adapter and threaded Web. It is selected
when `cybersand/native_worker_threads=0`, once when a world is created; it does
not change worker count during play. Even a report of one logical thread selects
two Auto workers as requested. No-thread Web always forces one worker.
A low-thread warning recommends at least four physical CPU cores without
claiming that the browser can detect physical cores.
Web UI and reference reports read `navigator.hardwareConcurrency` directly:
the no-thread Emscripten C runtime's fixed value of 1 is not a hardware report.

Compatibility remains the default one-worker export.
Both profiles use the same solver, assets, and Godot Web controller.

From `C:/kybersand`:

```powershell
.\dev.cmd web --profile threaded
.local/python/Scripts/python.exe source/tools/serve_web.py --directory source/build/web-threaded --port 8002 --open
# While the server runs:
.\dev.cmd http-smoke --profile threaded --url http://127.0.0.1:8002/
# After browser acceptance:
.\Deliver-Web.ps1 -Profile threaded
```

Delivery goes to `C:/cybersand/web-threaded`; the compatibility delivery remains
`C:/cybersand/web`. `dev.cmd web` builds compatibility as before. Use
`web-export --profile threaded` only when the matching C++ WASM is already fresh.

The threaded Godot 4.7 dlink templates are extracted from the retained official
export-template archive into `.local/web-templates`. Native and Web godot-cpp
bindings remain separate. The current builder checks Godot 4.7, godot-cpp
`101ae380…`, SCons 4.10.1 and Emscripten 4.0.20. Historical CI still requests
4.0.11; see [build/CI drift](github-development-and-release.md).

The export prewarms an Emscripten pthread pool separately from Godot's two-worker
pool. Spare capacity is needed while old and replacement native worlds coexist
during transactional world construction/import; unused prewarmed workers do not
represent additional simulation workers. See [build_web.py](../../tools/build_web.py) for the
current bounded pool size.

Auto and the live benchmark require room for the current world and temporary
test/replacement pools; the current prewarmed pool is 32, with two Godot workers.
The earlier four-worker validation below used 24 prewarmed pthreads.

Hosting requires HTTPS (or localhost) and cross-origin isolation: COOP
`same-origin` and COEP `require-corp`. The supplied preview server sets these.
Deploy each complete export as a unit, including its worker JavaScript files,
PCK, WASM modules, and checksums. No remote deployment is configured by this task.

## Acceptance

### Auto and reference tests

Open **Performance** in the Web menu. **Benchmark** compares supported counts
from 1, 2, 4 and 6 on deterministic Sand/Water worlds of 480×480 and 960×960.
It excludes ten warmup ticks, then measures 120 ticks per case, with deterministic
emission to maintain activity. It compares final exported level hashes across
worker counts. **Stress test** runs Auto for 600 measured ticks at 960×960.

Both use separate worlds and keep the current game unchanged. Each case is
limited to two minutes; Cancel or Escape stops between ticks. No new simulation
rules or approximations are introduced. A native tick already in progress must
finish before cancellation can take effect.

Results include actual worker count, mean/p95/max native tick time, test frame
intervals, moves, parallel phases and final level hash. Frame intervals include
test scheduling and the menu; they are not normal gameplay FPS or a rendering
stress test. Results never retune Auto. **Copy results** selects the JSON report
and attempts clipboard copy; Ctrl+C is available if the browser blocks it.
The last successful report is saved locally as `user://last_worker_benchmark.json`.

Native reference commands, after `native-build` and `godot-test`:

```powershell
.\dev.cmd benchmark
.\dev.cmd stress-test
```

They use the same fixture under headless Godot and save reports and command logs
under `validation/local/<timestamp>/`. Compare native tick timings between native
and Web; headless frame intervals are not directly comparable to browser frames.
Policy boundary tests cover logical counts 0, 1, 2, 3, 4, 5, 11, 12, 16, 20 and 64.
Benchmark regression covers deterministic output, statistics, cancellation and
restoration of the process's worker setting. Real low-core hardware remains a
separate validation target.

Retained Auto validation (2026-09-08): Windows reported 12 logical threads and selected
six workers. All 14 Godot fixtures passed, including Auto boundaries and the
benchmark regression; the expanded full-run regression passed separately after
fixing a typed-array initialization error. Native and Chromium 152 reference
benchmarks completed all eight cases with matching final level hashes across
worker counts and platforms. The 600-tick stress runs also matched level hashes
and move totals between native and Web. Browser Escape cancellation left the
player's Neon Works world at its original tick 0; no console errors or warnings
were observed in the successful run.

| Workload | Native mean tick | Web mean tick | Web p95 tick |
| --- | --- | --- | --- |
| 480×480, 4 workers | 4.79 ms | 6.15 ms | 11.02 ms |
| 480×480, 6 workers | 3.82 ms | 4.73 ms | 6.48 ms |
| 960×960, 4 workers | 17.88 ms | 18.16 ms | 20.29 ms |
| 960×960, 6 workers | 14.17 ms | 14.61 ms | 17.00 ms |
| 960×960, Auto stress, 600 ticks | 17.08 ms | 21.23 ms | 28.28 ms |

These are historical single-run reference measurements, not a promise of 60 FPS. The long
stress case exceeds the 16.67 ms tick budget. Native reports are under
`validation/local/20260908-150349/` and `20260908-150723/` in the workspace;
the browser summary is `validation/local/auto-workers-20260908/browser-reference.json`.
The native regression suite also passed 39/39. Both final exports passed six
HTTP payload checks. That checkpoint's historical BUILD_ID check listed seven
hash differences; the [current audit](../audits/2026-09-08-documentation-audit.md)
records the separate fresh check. Historical locks are preserved.

### Earlier four-worker baseline

Historical earlier local result (2026-09-08, Chromium 152 on Windows): four workers active,
120/120 exported-level hashes identical to one worker, 98,286 moves in each run,
480 parallel phases, no browser console errors/warnings, and the native C++
exception rejection probe passes. Mean native tick time was 4.2365 ms for one
worker and 2.9923 ms for four; this is one short fixture run, not a general FPS
or cross-device performance guarantee. Native regressions passed 39/39 and
Godot fixtures passed 12/12; the async parity fixture also passed separately.
The threaded Foundry local save/load round trip reproduced the entire 17,712
character CYSD1 export with no error and kept four workers. Material Lab,
Waterworks, Foundry, and Neon Works ran interactively with no rejected render
snapshots observed. Both profiles passed all six HTTP payload checks.

At that earlier checkpoint, the historical consistency checker reported five BUILD_ID source
hash differences, including the locally configured project.godot. Historical
locks have not been rewritten; this is not an audited M11 release attestation.

An initial pool of 12 prewarmed pthreads stalled the browser acceptance sequence.
That earlier successful export used 24 to accommodate world replacement and runtime
threads. The probe yields between ticks and worker-count runs. Keep this
lifecycle fixture when changing pool sizing; the precise lower safe bound has
not been established.

`?test=1` exposes existing read-only DOM diagnostics including actual worker
count. `?test=1&parity=1` additionally runs a startup acceptance fixture comparing
one and four workers over 30 ticks in each of the four demos. The fixture compares
120 SHA-256 hashes of exported level bytes, counts moves and parallel phases, and
reports mean native tick time. This is level-state parity, not complete scheduler
or RNG replay parity. The fixture yields between ticks for browser responsiveness.
The same fixture runs as `test_web_worker_parity.gd` under `dev.cmd godot-test`.

The Web controller still waits for each native tick before continuing its Godot
frame. This enables parallel cellular jobs; it does not implement the desktop's
fully asynchronous simulation/render owner. Both profiles now include Rapier2D;
see the [Rapier runbook](rapier-2d-migration-runbook.md) for current Web acceptance.
Emscripten labels dynamic linking with pthreads experimental; compatibility
remains available for environments where the threaded profile cannot run.

References: [Godot Web export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)
and [Emscripten dynamic linking](https://emscripten.org/docs/compiling/Dynamic-Linking.html).
