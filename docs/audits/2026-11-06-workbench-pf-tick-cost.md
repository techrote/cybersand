---
title: Workbench PressureFlow tick cost and lock-step pacing
status: Current
document-kind: evidence
scope: 6 November 2026 experimental-branch (#406) evidence for the desktop workbench 30 Hz lock-step defect, its sample-driven worker wake fix, exact parallel cached PressureFlow head preparation (column pass and row sub-bands) and the opt-in fine scheduling-core option; local Windows only, not on main, no default changed
canonical-for: []
last-reviewed: 2026-11-06
related-documents: [../architecture/pressure-flow-v1.md, ../architecture/simulation-tick-and-threading.md, ../reference/configuration-reference.md, 2026-11-05-wcx-ballistic-water.md]
---

# Workbench PressureFlow tick cost — 6 November 2026

## Result

1. **The owner-reported slow motion was mostly pacing, not PressureFlow cost.**
   The workbench is an exact lock-step. `main.gd` steps Rapier only after the
   worker has completed the published body sample, and the worker ticks once per
   sample. The worker still slept on its own free-running 60 Hz timer, so its
   phase drifted against the physics callback. Whenever a completion landed just
   after the callback checked for it, Rapier skipped that frame. This gave
   plateaus of exactly 30 Hz (90 ticks per 3 s) for cells, bodies and the
   flyer, even with 4–6 ms FreeMass ticks. Longer ticks made the plateaus longer.
2. **Fix (GDScript, desktop workbench only).** While the workbench lock-step is
   active, the worker polls for the next body sample in 250 µs slices instead of
   sleeping out the whole interval. It ticks as soon as the sample arrives, and
   never earlier than the sample. There is still one tick per sample. With this
   fix, gas-free dormant PressureFlow and FreeMass on `my-canvas` hold 180 ticks
   per 3 s for the whole 30 s run.
3. **Exact parallel PressureFlow head preparation** now covers the cached
   variants too:
   - the column pass, with private per-position row-dirty records OR-merged
     after the join;
   - the row pass, as tasks per (chunk row, activity-block row), with deferred
     global wake effects and deferred, coalesced certificate invalidation.

   On `my-canvas` (6 workers), dormant gas-free head preparation fell from
   2.64 ms to 0.95 ms per tick. Physical state, CYPS bytes, ledgers, heads,
   wakes and every work counter are identical to the serial pass.
4. **Opt-in fine scheduling cores** (32 instead of 64 cells) roughly halve the
   phased scan. The scan is bound by the slowest core of each of the four
   phases, so finer cores shorten that critical path. This changes the update
   geometry. It is equally deterministic and worker-count independent, but not
   bit-identical to the default, so it stays a workbench construction toggle
   ("Fine cores") and is off by default.
5. **Remaining cost: gas topology.** Gas topology is still serial and runs on
   every tick that moves Water. It costs 4.6–6.1 ms on `my-canvas`. Gas-free
   PressureFlow remains the setting for vented scenes. An incremental or
   parallel topology is the next lever, but no design has been chosen.

## Identity

- Source: #406 branch `claude/water-ballistic-hybrid` at `8f189e09` plus this
  change (see the commit that adds this record).
- Windows DLL (local, pinned LLVM-MinGW 20260826 / Clang 23.1.0):
  `d1f1d9c1e863bc98865e0884d70b06810f4bd5b00b26557bcc88d3b45b6b40ce`. This is
  not a published runtime.
- Machine: 12 logical CPUs, so the adapter's automatic policy gives 6 native
  workers. The GPU is a TITAN RTX, rendering a 1920×1080 window with Godot
  4.7-stable.
- Fixture: the built-in `my-canvas` start (512×512, chunk 128 with halo = 36
  chunks; dam column, sand ramp, pool, U-tube). The native bench reproduces its
  disc stamps.

## Measurements

The workbench measurements below use a rendered window, a still camera and
30 s runs. The native tick column is the worker's `simulation_time_ms`; the
rate column is ticks per 3 s, where 180 is full 60 Hz. The profiling scripts
were scratch only and are not retained.

| Build | Water | Mean native tick | p95 | Ticks per 3 s |
|---|---|---|---|---|
| Before (`679cc569`, free-running timer) | FreeMass | 5.75 ms | 6.87 ms | 90–180 |
| Before | PF `cached_dormant`, gas off | 8.20 ms | 9.95 ms | 89–180 |
| Before | PF `cached_dormant`, gas on | 13.61 ms | 16.65 ms | mostly 90 |
| Pacing fix only | FreeMass | 5.51 ms | 6.40 ms | 179–180 |
| Pacing fix only | PF `cached_dormant`, gas off | 7.17 ms | 9.28 ms | 178–180 |
| Pacing fix only | PF `cached_dormant`, gas on | 12.97 ms | 15.80 ms | 92–178 |
| All changes (`d1f1d9c1`) | PF `cached_dormant`, gas off | 6.22 ms | 7.72 ms | 179–180 |
| All changes, fine cores | PF `cached_dormant`, gas off | 5.14 ms | 6.14 ms | 179–180 |
| All changes, fine cores | PF `cached_dormant`, gas on | 10.20 ms | 12.49 ms | 144–180 |
| All changes, fine cores | FreeMass | 3.36 ms | 4.12 ms | 179–180 |

Native bench (`World::tick` only, 600 ticks, 6 workers, phased backend,
`parallel_job_threshold` 2). Times are means; heads are the per-tick
`head_nanoseconds`.

| Configuration | PF dormant gas off | PF dormant gas on | PF reference gas off | FreeMass |
|---|---|---|---|---|
| Serial heads, 64 cores | 8.11 ms (heads 2.60) | 14.69 ms (gas 5.25, heads 3.80) | 9.44 ms (heads 3.95) | 5.30 ms |
| Parallel heads, 64 cores | 6.05 ms (heads 0.95) | — | 6.07 ms (heads 0.95) | — |
| Parallel heads, 32 cores | 4.41 ms (heads 0.92) | 9.33 ms (gas 4.65, heads 1.18) | — | 2.70 ms |

The serial profile showed that the phased scan takes 5.4 ms with 64-cell cores
and barely improves from 4 to 6 workers (8.10 ms against 8.15 ms per tick in the same build). That
is critical-path bound, not throughput bound.

## Exactness

`native/tests/test_workbench_pressure_heads.cpp` now runs every PressureFlow
variant: reference, cached and cached_dormant. It compares 1 and 6 workers, each
with parallel heads off and on, for 160 ticks. The comparison covers physical
hash, CYPS bytes, quantity ledger, diagnostics including wakes, every prepared
head, and work counters, now including certificate invalidation cells,
attempts, reuses and layer activations. Result: 14,405,631 checks, 0 failures,
with 453,619 certificate invalidation cells exercised in cached_dormant. The test
is now part of the Makefile `TEST_SOURCES` `tests` binary, so the CI
native-normal, ASan/UBSan and TSan families run it. Before, it was a standalone
program run only by hand. The complete native test binary passed 182 tests on
this source, with a local Windows `-O2` build.

The local Godot regressions also passed: 18 workbench, PressureFlow and
worker-interest tests, run against DLL `d1f1d9c1`. The canvas test
(`test_workbench_canvas.gd`, 109 checks) now also covers a fine-core rebuild
that installs and simulates.

## Gaps

- Windows only, on one machine. There is no Linux, Web or CI-runner timing, and
  no published runtime.
- The pacing fix has no timing regression in CI, because timing on shared
  runners would be flaky. The evidence above is dated local measurement.
- Fine cores are not bit-identical to the default geometry. Making them the
  default is an owner decision.
- Gas topology is still serial (above).
- No human gameplay acceptance beyond the owner's report.
