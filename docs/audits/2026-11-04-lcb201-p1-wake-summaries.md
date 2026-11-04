---
title: LCB-002 #201 experimental P1 wake summaries
status: Current
document-kind: evidence
scope: Experimental draft implementation of the #201 P1 sleeping-segment wake-summary elision and P1b same-chunk wake samples for PressureFlow cached/cached_dormant, with mutation-checked native controls, full native suite and the registered idle-cost cohort rerun against its baseline; not accepted, not on main, no default change
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [2026-11-04-lcb201-pressure-idle-cost.md, ../architecture/pressure-optimization.md, ../architecture/pressure-flow-v1.md]
---

# LCB-002 #201 experimental P1 wake summaries — 4 November 2026

## Result

**Experimental, draft only.** P1 removes the quiet floor that the
[idle-cost record](2026-11-04-lcb201-pressure-idle-cost.md) identified. At the
#370 quiet-pool scale, cached and cached_dormant fall from a median **9–12 ms** to
**0.32–0.34 ms** per quiet native tick on Windows (p99 at most 0.62 ms). The
complete same-law parity of the registered cohort held on every tick of all 48
children, and the full native suite passes (166/166).

P1b, the same-chunk sample path, also runs in reference, which fell from 31–41 ms
to **28.7–30.7 ms**. Ratios to reference therefore understate the cached gain:
quiet C/R moves from 0.28–0.30 to **0.012–0.013**. FreeMass remains ≈0.015–0.02 ms.

| | Status |
|---|---|
| Source | `e5416b81bebf7ce79ac9894f7f9edf88f63b58da` (tree `5736f569…`) on `claude/lcb201-p1-wake-summaries`, stacked on #374's evidence branch |
| Write set | `world_pressure.inc`, `world_pressure_cache.inc`, `world_pressure_cache_state.inc`, `pressure_optimization.hpp` (snapshot fields only), a new `test_pressure_wake_summaries.inc`, and two registry lines in `test_world.cpp` and in `test_lcb_pressure.cpp` |
| Not changed | Physical law, the reference operator, `world.cpp`, the 53-counter schema, Godot adapter, defaults, CI and runtime binaries |
| Execution identity | **Still 3 in this draft.** Acceptance must bump `kPressureOptimizationExecutionVersion` to 4, which cascades to `godot/tests/test_lcb_pressure_optimization.gd`, the LCB-003 publication contract, `tools/lcb/pressure_optimization_cost.py` `EXECUTION`, the identity known answers in `test_pressure_optimization.inc` and a runtime republication |

## Mechanism

`PressureCache` reserves one derived clean bit per indexed cell at construction
(262,144 B at this scale). Every index rebuild zero-fills within that
reservation, with no tick-time allocation; nothing is serialized. In the
cached head path's wake loop:

- a sleeping row segment with all bits set is skipped;
- a complete negative scan sets its bits;
- an active block's segments are cleared.

Bits are cleared by:

| Wake-predicate input | Clearing path |
|---|---|
| Producer, host or explosion cell writes; body-mask set/clear | `invalidate_pressure_input`: rows of the rectangle, columns widened by ±2 across horizontal chunk seams |
| Final head change | `put_final` when the value changes: that cell's row, x±2 |
| Gas labels and gauges | Every gas pass: full reset |
| Membership, cold cache, reference fallback, restore | Index rebuild zero-fill (restore builds a fresh cache) |

Elision requires `sleep_after_quiet_ticks >= 2`, so any block updated in a tick
is still active at the next preparation. All bit writes happen on the serial
owner during preparation or invalidation, never inside a worker job.

P1b resolves wake samples inside the scanning cell's own chunk by direct index
instead of an `unordered_map` lookup. The values read are identical.

## Controls

The new `LCB-002 P1 wake summaries skip quiet scans and stay exact` test runs
reference, cached and dormant together at configured 1 and 4 workers, with gas
both enabled and disabled. On every tick it requires identical projections,
gas/PF ledgers and history, complete quantity, **and an identical count of
blocks woken by the state-only scan**. It covers:

- a quiet pool spanning the x=0 chunk seam: skips occur and zero segments are scanned;
- a host edit two cells from the seam and a body mask at x−2: the clean-cell count
  drops immediately;
- a gas pass rescanning all segments, while a gas-free edit clears only its stencil;
- a two-cell surface-column lowering whose head change wakes sleeping blocks 32+
  rows below **only through the scan**;
- a `sleep_after_quiet_ticks = 1` World, where elision is disabled.

**Mutation checks** (each path removed in turn, WSL2 g++ 13.3.0 `-O1`; log kept
outside Git as `p1-mutations.log`):

| Removed path | Result |
|---|---|
| `put_final` clear | **Caught:** wake decisions diverge from reference |
| Producer/host/mask input clear | **Caught:** the seam edit leaves summaries clean |
| Gas-pass reset | **Caught:** no full rescan after a gas pass |
| Sleep-guard (`>= 2`) | **Caught**, by the guard assertion only |
| x±2 seam widening | **Caught:** wake decisions diverge |
| Active-block clear | Not caught. It is a redundant safeguard: every own-cell flow/overfill write in `update_water_pressure` is witnessed (`store`, `take`/`give`, `move_cell`), so the input clear already covers it. It is kept as cheap protection |

**Suites (WSL2 GNU C++ 13.3.0, Makefile `build/tests` flags `-O0 -g3`):** the
full native suite passes **166/166** in 550 s, binary `150e2cef…daed1d`, with
no new warnings (18 pre-existing). Sanitizer/TSan and GitHub-hosted gates were
not run.

## Cost against the registered baseline

The identical [registration](lcb201-idle-cost-2026-11-04/plan.json) and runner
were used. The fenced build at `e5416b81` used LLVM-MinGW Clang 23.1.0 `-O3`
with a clean status and an unchanged 67-file fence. Scale binary
`52ee8eeff90d6384e445a93d72568cceeaeb17fae4cb58db8ba4f04b99164434`; LCB-002
binary `b91495f5cde4e77def9dd4e5382641f04310a0dbbcda279af38fa435fc55b5af`.
All 48 children passed, completing at 2026-11-04T10:18:36Z.
[`summary-p1.json`](lcb201-idle-cost-2026-11-04/summary-p1.json) SHA-256
`0cc3513e9d439122366ba48d1865f24b38a70def3d586abaa517c23561008e87`. The
baseline cohort ran earlier the same day on the same machine; desktop load was
uncontrolled. Values are baseline → P1, with the same statistics as the
idle-cost record.

| Profile | W | Phase | Ref p50 | Cached p50 | Dormant p50 | C/R | D/R | Cached head ms |
|---|---:|---|---|---|---|---|---|---|
| pool-vented | 1 | settle | 40.20 → 29.80 | 10.39 → 0.33 | 10.30 → 0.32 | 0.290 → 0.012 | 0.284 → 0.012 | 11.10 → 0.35 |
| pool-vented | 1 | quiet | 39.57 → 29.97 | 10.97 → 0.32 | 11.08 → 0.32 | 0.287 → 0.012 | 0.290 → 0.012 | 11.24 → 0.34 |
| pool-vented | 1 | tail | 38.71 → 29.77 | 10.78 → 0.33 | 10.43 → 0.32 | 0.282 → 0.013 | 0.289 → 0.013 | 11.10 → 0.35 |
| pool-vented | 4 | settle | 37.48 → 27.54 | 10.07 → 0.32 | 9.98 → 0.31 | 0.283 → 0.013 | 0.287 → 0.012 | 10.55 → 0.34 |
| pool-vented | 4 | quiet | 38.67 → 30.17 | 11.02 → 0.32 | 10.90 → 0.33 | 0.290 → 0.012 | 0.289 → 0.012 | 11.16 → 0.35 |
| pool-vented | 4 | tail | 38.15 → 28.54 | 11.07 → 0.32 | 10.97 → 0.32 | 0.296 → 0.013 | 0.296 → 0.013 | 11.42 → 0.34 |
| pool-sealed | 1 | settle | 37.59 → 27.51 | 9.43 → 0.32 | 10.27 → 0.32 | 0.289 → 0.013 | 0.290 → 0.012 | 10.58 → 0.33 |
| pool-sealed | 1 | quiet | 39.57 → 30.18 | 11.47 → 0.33 | 11.02 → 0.32 | 0.294 → 0.012 | 0.291 → 0.012 | 11.47 → 0.35 |
| pool-sealed | 1 | tail | 38.54 → 28.77 | 10.96 → 0.33 | 10.94 → 0.33 | 0.298 → 0.013 | 0.292 → 0.013 | 11.33 → 0.36 |
| pool-sealed | 4 | settle | 35.81 → 28.60 | 10.29 → 0.33 | 10.94 → 0.32 | 0.300 → 0.013 | 0.299 → 0.013 | 10.98 → 0.35 |
| pool-sealed | 4 | quiet | 36.39 → 28.95 | 9.81 → 0.33 | 9.89 → 0.32 | 0.288 → 0.012 | 0.293 → 0.012 | 10.72 → 0.35 |
| pool-sealed | 4 | tail | 31.42 → 29.63 | 9.14 → 0.33 | 8.82 → 0.32 | 0.291 → 0.013 | 0.291 → 0.013 | 9.65 → 0.35 |
| pool-sealed-remote-gas | 1 | settle | 36.11 → 28.98 | 10.07 → 0.34 | 9.73 → 0.33 | 0.293 → 0.013 | 0.284 → 0.012 | 10.78 → 0.35 |
| pool-sealed-remote-gas | 1 | quiet | 37.13 → 29.55 | 9.40 → 0.33 | 10.40 → 0.32 | 0.287 → 0.013 | 0.291 → 0.012 | 10.51 → 0.36 |
| pool-sealed-remote-gas | 1 | tail | 39.35 → 30.93 | 12.54 → 0.46 | 12.48 → 0.45 | 0.431 → 0.217 | 0.430 → 0.220 | 13.11 → 3.38 |
| pool-sealed-remote-gas | 4 | settle | 34.52 → 28.52 | 9.67 → 0.33 | 10.17 → 0.34 | 0.288 → 0.013 | 0.294 → 0.013 | 10.56 → 0.36 |
| pool-sealed-remote-gas | 4 | quiet | 38.65 → 28.72 | 10.62 → 0.33 | 10.64 → 0.33 | 0.288 → 0.013 | 0.296 → 0.013 | 11.07 → 0.35 |
| pool-sealed-remote-gas | 4 | tail | 39.73 → 30.36 | 12.49 → 0.50 | 12.63 → 0.49 | 0.429 → 0.224 | 0.429 → 0.222 | 13.44 → 3.50 |
| pool-vented-moving-mask | 1 | settle | 40.14 → 29.22 | 10.82 → 0.32 | 10.99 → 0.32 | 0.284 → 0.012 | 0.285 → 0.012 | 11.14 → 0.33 |
| pool-vented-moving-mask | 1 | quiet | 40.03 → 30.70 | 10.92 → 0.32 | 11.43 → 0.33 | 0.288 → 0.012 | 0.287 → 0.012 | 11.33 → 0.35 |
| pool-vented-moving-mask | 1 | tail | 40.85 → 30.08 | 14.39 → 1.97 | 13.80 → 1.61 | 0.518 → 0.351 | 0.516 → 0.348 | 15.16 → 4.97 |
| pool-vented-moving-mask | 4 | settle | 39.95 → 30.82 | 11.24 → 0.32 | 11.29 → 0.33 | 0.285 → 0.012 | 0.284 → 0.012 | 11.44 → 0.35 |
| pool-vented-moving-mask | 4 | quiet | 40.30 → 30.18 | 12.17 → 0.32 | 11.95 → 0.32 | 0.291 → 0.012 | 0.295 → 0.012 | 11.82 → 0.35 |
| pool-vented-moving-mask | 4 | tail | 41.41 → 29.19 | 14.41 → 1.83 | 14.19 → 1.76 | 0.525 → 0.354 | 0.514 → 0.349 | 14.74 → 4.96 |
| pool-vented-boundary-churn | 1 | settle | 37.38 → 30.54 | 11.01 → 0.32 | 9.52 → 0.33 | 0.288 → 0.012 | 0.285 → 0.012 | 11.36 → 0.35 |
| pool-vented-boundary-churn | 1 | quiet | 39.99 → 29.97 | 10.96 → 0.33 | 10.99 → 0.33 | 0.284 → 0.013 | 0.285 → 0.013 | 11.41 → 0.35 |
| pool-vented-boundary-churn | 1 | tail | 39.57 → 29.80 | 35.43 → 28.16 | 35.98 → 28.49 | 0.909 → 0.941 | 0.909 → 0.939 | 20.81 → 14.81 |
| pool-vented-boundary-churn | 4 | settle | 32.20 → 29.77 | 8.99 → 0.32 | 9.02 → 0.35 | 0.282 → 0.012 | 0.290 → 0.013 | 9.34 → 0.34 |
| pool-vented-boundary-churn | 4 | quiet | 32.48 → 30.22 | 8.98 → 0.34 | 9.07 → 0.32 | 0.283 → 0.013 | 0.284 → 0.012 | 9.56 → 0.36 |
| pool-vented-boundary-churn | 4 | tail | 36.68 → 31.15 | 32.96 → 29.17 | 33.63 → 29.29 | 0.919 → 0.939 | 0.915 → 0.940 | 20.12 → 15.30 |

The unchanged LCB-002 small-scale apparatus at the same P1 head gives:

| Small-scale profile | W | Phase | C/R | D/R |
|---|---:|---|---|---|
| awake-boxed-water | 1 | cold | 0.942 → 0.940 | 0.556 → 0.574 |
| awake-boxed-water | 1 | warm | 0.919 → 0.906 | 0.366 → 0.373 |
| awake-boxed-water | 1 | disturbed | 0.915 → 0.911 | 0.356 → 0.366 |
| awake-boxed-water | 4 | cold | 0.831 → 0.832 | 0.580 → 0.604 |
| awake-boxed-water | 4 | warm | 0.808 → 0.789 | 0.427 → 0.436 |
| awake-boxed-water | 4 | disturbed | 0.816 → 0.796 | 0.434 → 0.426 |
| ordinary-sleeping-water | 1 | cold | 0.830 → 0.752 | 0.780 → 0.702 |
| ordinary-sleeping-water | 1 | warm | 0.490 → 0.030 | 0.489 → 0.031 |
| ordinary-sleeping-water | 1 | disturbed | 0.540 → 0.157 | 0.529 → 0.153 |
| ordinary-sleeping-water | 4 | cold | 0.743 → 0.632 | 0.729 → 0.610 |
| ordinary-sleeping-water | 4 | warm | 0.491 → 0.029 | 0.494 → 0.030 |
| ordinary-sleeping-water | 4 | disturbed | 0.561 → 0.191 | 0.554 → 0.180 |
| continuous-topology-churn | 1 | cold | 0.432 → 0.518 | 0.513 → 0.518 |
| continuous-topology-churn | 1 | warm | 0.113 → 0.098 | 0.116 → 0.097 |
| continuous-topology-churn | 1 | disturbed | 1.089 → 1.204 | 1.079 → 1.206 |
| continuous-topology-churn | 4 | cold | 0.542 → 0.582 | 0.596 → 0.610 |
| continuous-topology-churn | 4 | warm | 0.114 → 0.098 | 0.117 → 0.097 |
| continuous-topology-churn | 4 | disturbed | 1.088 → 1.109 | 1.105 → 1.151 |

**Reading:**

- **Quiet and settling:** the floor is gone. Cached/dormant quiet preparation
  drops from ≈11 ms to ≈0.35 ms.
- **Remote gas and moving mask:** cached tail p50 drops from 12.5 to 0.5 ms and
  from 14.4 to 1.6–2.0 ms. Each gas pass still resets all bits and rebuilds all
  columns, so P2 remains the next lever there.
- **Boundary churn:** a gas pass runs every tick, so cached gains only P1b
  (35 → 28 ms) and stays ≈0.94 of the faster reference. P2 and the global gas
  operator (P3) own this regime.
- **Small-scale churn shows a real P1 overhead.** The 1-worker disturbed cached
  phase total rises from 1.28 to 1.52 ms over 32 ticks, ≈7 µs per tick: per-tick
  index rebuild zero-fill, the gas-pass reset and range clears. Reference moved
  only 1.19 → 1.27 ms. The C/R rise from 1.089 to 1.204 (w1) and 1.088 to 1.109
  (w4) is retained, not explained away.
- **Awake stationary small-scale** ratios are unchanged within noise, because
  P1 skips only sleeping segments. Its absolute times rose for all arms alike
  (host variance).

**Memory:** derived capacity grows by 262,200 B per cached/dormant World here
(cached 15,082,780 → 15,344,980 B). Peak RSS is 273.2–275.3 MiB per
four-World process.

## Execution4 runtime publication

The temporary branch-scoped publisher
([workflow](../../.github/workflows/lcb201-p1-runtime-publication.yml),
[profile](../../tools/ci/lcb201_p1_runtime_publication.py), request sequence 1)
reuses the approved four-path engine, derived from the render-copy profile.
[Run 41829294378](https://github.com/techrote/cybersand/actions/runs/41829294378)
built source `2f9faabdbc1f085b24b5da7e72efd6c640c288a0`, which already contained
execution identity 4. All seven jobs passed:

- the publisher guards and the explicit request admission;
- the native `LCB-002` (16, including the P1 control) and `LCB-001 pressure` (18)
  groups, built with the Makefile under g++-13;
- Linux and Windows builds, each executing import plus the pressure-optimization,
  pressure-reference and actual-Rapier pressure cases on its target OS;
- the publish job.

The publish job appended `6817e008`, whose only parent is the built source and
whose only changes are the two runtime LFS pointers and their manifests. The
Windows DLL SHA-256 is
`ebd6d55506cbf74826b11ce072217c1060f22fabecd0bdc4002d6576cd2c36ff`, and
`check_repository.py` now passes. The guard suite caught one design error: six
focused cases exceed a hosted job's watchdog budget, so the publisher runs three
pressure cases. Policy, worker and Water Feel coverage stays in the full PR gates.
The existing render-copy guard test independently fails the same budget check
on main (15,420 s > 14,400 s); this change does not touch it.

## Full-host cohort: the per-step region flip

`godot/tests/lcb201_pressure_host_case.gd` reuses the merged PACE-001 recorder
(actual `main.tscn` + `CyberSimulationWorker` + main-thread Rapier, headless
Windows, Godot 4.7). It installs the #370 quiet pool through the ordinary
controlled prepared-liquid route under each Water variant, settles 64 native
ticks and measures 240. It runs once per row (the pre-P1 rows measure 120
ticks); it asserts no threshold, and no row failed. With no bodies present,
Rapier has nothing to simulate. Worker step is `worker_step_time_ms`; desktop
simulation is paced at 60 Hz.

| Runtime / worker | Variant | Native Hz | Worker step p50 / p95 / max ms | Main process interval p50 / p95 ms | Snapshot age p50 / p95 ms | Failures |
|---|---|---:|---|---|---|---:|
| main runtime (pre-P1), as shipped | reference | 28.7 | 33.38 / 41.90 / 46.06 | 5.95 / 15.26 | 6.28 / 14.78 | 0 |
| main runtime (pre-P1), as shipped | cached | 24.3 | 40.74 / 47.17 / 49.47 | 8.27 / 14.18 | 5.50 / 10.79 | 0 |
| main runtime (pre-P1), as shipped | cached_dormant | 27.1 | 35.02 / 44.36 / 48.06 | 5.86 / 14.98 | 8.03 / 14.87 | 0 |
| main runtime (pre-P1), as shipped | freemass | 60.0 | 0.29 / 0.41 / 0.52 | 8.38 / 15.30 | 1.19 / 2.17 | 0 |
| P1 runtime, as shipped | reference | 32.4 | 29.62 / 36.30 / 42.26 | 8.72 / 14.74 | 5.57 / 12.37 | 0 |
| P1 runtime, as shipped | cached | 27.8 | 34.31 / 42.68 / 49.44 | 8.89 / 14.60 | 5.62 / 12.10 | 0 |
| P1 runtime, as shipped | cached_dormant | 27.9 | 34.04 / 43.15 / 59.91 | 8.72 / 15.19 | 5.58 / 12.96 | 0 |
| P1 runtime, as shipped | freemass | 60.2 | 0.22 / 0.35 / 0.98 | 7.05 / 15.66 | 1.04 / 1.98 | 0 |
| P1 runtime, scratch no-flip worker | reference | 31.5 | 30.40 / 37.81 / 55.97 | 6.79 / 15.41 | 8.05 / 14.51 | 0 |
| P1 runtime, scratch no-flip worker | cached | 60.0 | 0.70 / 0.98 / 1.35 | 5.61 / 15.40 | 1.12 / 2.38 | 0 |
| P1 runtime, scratch no-flip worker | cached_dormant | 60.0 | 0.70 / 0.98 / 1.43 | 5.60 / 15.42 | 1.21 / 15.18 | 0 |
| P1 runtime, scratch no-flip worker | freemass | 60.0 | 0.26 / 0.38 / 1.31 | 6.71 / 15.37 | 1.11 / 1.91 | 0 |

**Finding: the shipped desktop worker defeats the pressure cache.** Every step,
`simulation_worker.gd` calls `_world.set_simulation_window(...)` (camera window
or whole world). With a fixed-interest scenario, `_scenario_host.apply_interest()`
then calls `set_simulation_window` again with the scenario region. Whenever the
selected cores differ, `World::set_simulation_region` makes the pressure cache
`cold()`, which happens twice per step. Cached and dormant then pay a full
reference preparation plus an index rebuild every tick, which is slower than
reference. This is source-qualified and reproduced natively: a scratch bench
variant that applies the same two region changes before every tick takes cached
from 0.35 ms to ≈36.6 ms (reference ≈30.5 ms), with full parity. The receipts
are kept outside Git (`host-flip/`).

A **local, uncommitted** worker patch skips the camera-window call while a
fixed-interest scenario is active (`host/scratch-noflip.patch`). With it, the P1
runtime's cached/dormant worker step falls to **0.70 ms** and simulation holds
its 60 Hz cap, the same as FreeMass. Reference is unchanged. The patch is not
part of this PR: it is shared host code, outside the pressure-optimization owner.

**Later the same day:** the worker fix merged separately in #390 (main
`751edc0b495dc85484ad5509a7c95f863651c76b`); see the
[region-flip record](2026-11-04-lcb201-region-flip.md). The rows above were
measured before it and are kept as recorded. A combined P1 + #390 rerun from the
published runtime has not been made.

**Consequences:**
- P1 is necessary but not sufficient for an in-app benefit.
- Until the flip is removed, cached/dormant should not be offered as faster
  variants in the desktop app (removed by #390 for fixed-interest scenarios).
- Any moving simulation window, for example ordinary camera motion with the
  window enabled, also turns the cache cold whenever the selected cores change.
  That deserves its own decision: either avoid redundant region writes in the
  host, or narrow the native `cold()` on region change. The latter lives in
  `world.cpp` and needs its own proof.

## Limits

- **Not accepted.** The execution-4 identity, Godot adapter test and
  source-matched runtime republication are done. The full ready-PR
  Native/GDExtension/Water gates and the owner's review remain.
- **`check_repository.py` failed on the pre-publication draft**, because the
  committed runtimes were stale. After the execution-4 publication it passes.
- **Native timing is Windows only,** with no WSL rerun. The host cohort is a single headless Windows run per row, with no moving body.
- **The redundant active-block clear** is argued from source, not from a failing
  control.
