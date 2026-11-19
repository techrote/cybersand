---
title: WAVE-MT-001 wave flow Water solver evidence
status: Current
document-kind: evidence
scope: 15 November 2026 experimental-branch evidence for WAVE-MT-001 wave_flow_v1; existing-solver baseline, candidate comparison, source-matched complete-native-tick matrix, interference and transport probes, native qualification, independent review, negative results and open gaps; local Windows and WSL Linux only
canonical-for: []
last-reviewed: 2026-11-15
related-documents: [../architecture/wave-flow-v1.md, ../architecture/liquid-solver-family-policy.md, ../architecture/simulation-tick-and-threading.md, ../architecture/pressure-flow-v1.md]
---

# WAVE-MT-001 wave flow evidence — 15 November 2026

The design, limits and controls are in the
[wave flow reference](../architecture/wave-flow-v1.md). This page records what
was measured, on what, and what was not.

## Identity

| Item | Value |
|---|---|
| Base | `main` `dea4e53dd71d6e0af71775593fdc9197a7633e3e` |
| Branch | `claude/cybersand-wave-mt-001-9d38c0` |
| Measured source | commit `90a04f98` (solver and benchmarks; later commits on the branch add only this record and its raw data) |
| Windows | Windows 11 Pro 10.0.26300, MSVC 14.38 (`cl /std:c++20 /O2 /DNDEBUG`), 12 logical processors |
| Linux | WSL Ubuntu 24.04, g++ 13.3.0, repository `Makefile` flags |
| Not covered | GitHub-hosted CI, Godot/GDExtension, real Rapier, Web, any GPU, a person watching it run |

Published GDExtension runtime provenance is **stale** for this branch: it
edits `native/src/world.cpp`, `world.hpp`, `world_pressure.inc` and
`world_quantity.inc` and no runtime was rebuilt or published.

## Baseline: existing solvers on main

Raw: [`baseline-dea4e53d-windows.csv`](wave-mt-001/baseline-dea4e53d-windows.csv)
(two repeats, 30 warm-up and 90 measured ticks, fresh process per row).
Complete `World::tick()` only.

Findings that shaped the design:

- **Cost per visited cell is the problem, not the lack of threads.** A 1024²
  dam break visits about 118,000 cells per tick under FreeMass at 50 ms: roughly
  430 ns per visited cell. Cellular Yield measured about 270 ns, Inertial 340 ns
  and Pressure 670 ns. The existing phased scheduler already scaled about 3.2×
  from one to four workers.
- **Pressure cached+dormant at 2048²** measured 2.1 ticks/s (one worker) and
  5.7 (four) in a dam break, and **8.5 ticks/s for a pool at rest**. The
  owner's earlier figure of about 9.8 ticks/s matches the at-rest case here.
- **No existing law transmits a wave.** In the `wave` scene the other solvers
  schedule 15–26 cores: only the splash is simulated and the rest of the pool
  stays asleep.

## Candidate comparison

Standalone testbed, no World:
[`wave_mt_prototype.cpp`](../../native/bench/wave_mt_prototype.cpp).

| Candidate | Evidence | Outcome |
|---|---|---|
| A. Parallelise PressureFlow | Baseline above: serial preparation plus the most expensive per-cell kernel; an idle 2048² pool already costs 115 ms a tick | Not pursued |
| B. Whole-cell transport plus coarse wave layer | Not built. One height per column cannot represent caves and stacked pools; whole cells quantise amplitude to one cell | Analysed only |
| C. Conserved mass with retained face flux | Prototype: exact conservation; constructive ratio 1.93 and destructive ratio 0.45 at the probe; 87 ms (one thread) and 22 ms (six) for a 2048² pool with every cell solved and no sparsity | Selected |
| C without retained flux | Same kernel, flux not retained: levels, but the probe sees no wave | Rejected |

## Source-matched complete-tick matrix

Raw, unfiltered:
[`matrix-90a04f98-windows-wave-flow.csv`](wave-mt-001/matrix-90a04f98-windows-wave-flow.csv)
and [`matrix-90a04f98-windows-existing.csv`](wave-mt-001/matrix-90a04f98-windows-existing.csv),
both from the same binary. Reproduce with
`python tools/wave_mt/run_matrix.py` and summarise with
`python tools/wave_mt/summarise.py`.

Scenes (square walled World of the stated side):

| Scene | Content |
|---|---|
| `dam` | Reservoir on the left third, three quarters of the height, released at tick zero |
| `wave` | Pool filling the bottom 40%; two Water blocks dropped every 90 ticks |
| `sparse` | One small basin per 128 cells with a falling column of Water |
| `idle` | The same pool, measured after 240 settling ticks |

**1024² dam** — median of 2 runs

| Solver | Workers (observed) | Tick p50 ms | Tick p95 ms | Native ticks/s | Scheduled cores | Peak RSS MB |
|---|---:|---:|---:|---:|---:|---:|
| Cellular Yield | 1 (1) | 55.89 | 61.65 | 17.8 | 65 | 53 |
| Cellular Yield | 4 (4) | 15.99 | 17.76 | 62.2 | 65 | 53 |
| FreeMass | 1 (1) | 50.12 | 53.78 | 19.9 | 42 | 53 |
| FreeMass | 4 (4) | 15.36 | 16.40 | 64.7 | 42 | 54 |
| Inertial | 1 (1) | 21.89 | 23.69 | 45.3 | 42 | 59 |
| Inertial | 4 (4) | 7.27 | 8.11 | 136.0 | 42 | 59 |
| Pressure cached+dormant | 1 (1) | 155.68 | 168.50 | 6.7 | 74 | 73 |
| Pressure cached+dormant | 4 (4) | 63.98 | 68.96 | 16.3 | 74 | 73 |
| wave_flow_v1 | 1 (1) | 3.50 | 6.81 | 256.0 | 15 | 57 |
| wave_flow_v1 | 2 (2) | 2.48 | 3.25 | 402.6 | 15 | 58 |
| wave_flow_v1 | 4 (4) | 1.42 | 1.91 | 693.8 | 15 | 58 |
| wave_flow_v1 | 6 (6) | 1.59 | 2.07 | 620.6 | 15 | 58 |
| wave_flow_v1 | auto (8) | 1.39 | 1.88 | 725.5 | 15 | 58 |
| wave_flow_v1 ×3 | 1 (1) | 12.39 | 15.82 | 80.7 | 18 | 57 |
| wave_flow_v1 ×3 | 2 (2) | 6.94 | 8.43 | 143.1 | 18 | 58 |
| wave_flow_v1 ×3 | 4 (4) | 5.21 | 6.78 | 187.0 | 18 | 58 |
| wave_flow_v1 ×3 | 6 (6) | 4.84 | 6.29 | 202.8 | 18 | 58 |
| wave_flow_v1 ×3 | auto (10) | 4.68 | 5.30 | 218.6 | 18 | 58 |

**1024² wave** — median of 2 runs

| Solver | Workers (observed) | Tick p50 ms | Tick p95 ms | Native ticks/s | Scheduled cores | Peak RSS MB |
|---|---:|---:|---:|---:|---:|---:|
| Cellular Yield | 1 (1) | 11.50 | 12.01 | 91.6 | 22 | 54 |
| Cellular Yield | 4 (4) | 3.33 | 3.75 | 296.3 | 22 | 55 |
| FreeMass | 1 (1) | 21.53 | 22.55 | 48.8 | 22 | 54 |
| FreeMass | 4 (4) | 6.14 | 6.74 | 161.2 | 22 | 55 |
| Inertial | 1 (1) | 14.78 | 23.35 | 57.5 | 26 | 60 |
| Inertial | 4 (4) | 4.69 | 8.23 | 179.4 | 26 | 61 |
| Pressure cached+dormant | 1 (1) | 162.04 | 214.01 | 5.7 | 74 | 77 |
| Pressure cached+dormant | 4 (4) | 68.86 | 83.62 | 14.0 | 74 | 78 |
| wave_flow_v1 | 1 (1) | 5.43 | 7.83 | 173.0 | 11 | 59 |
| wave_flow_v1 | 2 (2) | 3.00 | 3.82 | 323.3 | 11 | 59 |
| wave_flow_v1 | 4 (4) | 1.81 | 2.33 | 540.5 | 11 | 59 |
| wave_flow_v1 | 6 (6) | 1.48 | 1.90 | 663.4 | 11 | 59 |
| wave_flow_v1 | auto (12) | 1.48 | 1.86 | 655.2 | 11 | 59 |
| wave_flow_v1 ×3 | 1 (1) | 16.93 | 20.28 | 57.6 | 20 | 59 |
| wave_flow_v1 ×3 | 2 (2) | 8.90 | 10.54 | 110.2 | 20 | 59 |
| wave_flow_v1 ×3 | 4 (4) | 5.61 | 6.97 | 175.0 | 20 | 59 |
| wave_flow_v1 ×3 | 6 (6) | 5.13 | 6.60 | 193.0 | 20 | 59 |
| wave_flow_v1 ×3 | auto (12) | 4.33 | 5.34 | 224.0 | 20 | 59 |

**1024² sparse** — median of 2 runs

| Solver | Workers (observed) | Tick p50 ms | Tick p95 ms | Native ticks/s | Scheduled cores | Peak RSS MB |
|---|---:|---:|---:|---:|---:|---:|
| Cellular Yield | 1 (1) | 10.66 | 12.08 | 92.4 | 224 | 54 |
| Cellular Yield | 4 (4) | 3.07 | 3.47 | 319.5 | 224 | 55 |
| FreeMass | 1 (1) | 16.63 | 18.29 | 59.6 | 224 | 54 |
| FreeMass | 4 (4) | 4.60 | 5.06 | 215.4 | 224 | 55 |
| Inertial | 1 (1) | 13.38 | 15.95 | 73.9 | 233 | 64 |
| Inertial | 4 (4) | 3.74 | 4.50 | 261.8 | 233 | 64 |
| Pressure cached+dormant | 1 (1) | 67.53 | 72.37 | 14.9 | 224 | 77 |
| Pressure cached+dormant | 4 (4) | 51.64 | 53.72 | 19.5 | 224 | 78 |
| wave_flow_v1 | 1 (1) | 8.22 | 11.18 | 114.3 | 156 | 64 |
| wave_flow_v1 | 2 (2) | 4.02 | 5.53 | 234.8 | 156 | 64 |
| wave_flow_v1 | 4 (4) | 2.48 | 3.73 | 380.9 | 156 | 64 |
| wave_flow_v1 | 6 (6) | 2.10 | 3.07 | 457.3 | 156 | 64 |
| wave_flow_v1 | auto (12) | 1.85 | 2.70 | 503.6 | 156 | 64 |
| wave_flow_v1 ×3 | 1 (1) | 23.54 | 27.71 | 41.9 | 224 | 64 |
| wave_flow_v1 ×3 | 2 (2) | 13.86 | 16.23 | 72.7 | 224 | 64 |
| wave_flow_v1 ×3 | 4 (4) | 7.75 | 9.72 | 126.5 | 224 | 64 |
| wave_flow_v1 ×3 | 6 (6) | 6.75 | 8.68 | 147.3 | 224 | 64 |
| wave_flow_v1 ×3 | auto (12) | 5.96 | 7.23 | 166.8 | 224 | 64 |

**1024² idle** — median of 2 runs

| Solver | Workers (observed) | Tick p50 ms | Tick p95 ms | Native ticks/s | Scheduled cores | Peak RSS MB |
|---|---:|---:|---:|---:|---:|---:|
| Cellular Yield | 1 (0) | 0.00 | 0.00 | 156811.0 | 0 | 54 |
| Cellular Yield | 4 (0) | 0.00 | 0.00 | 172789.5 | 0 | 55 |
| FreeMass | 1 (0) | 0.00 | 0.00 | 133330.5 | 0 | 54 |
| FreeMass | 4 (0) | 0.00 | 0.00 | 158050.0 | 0 | 55 |
| Inertial | 1 (0) | 0.00 | 0.00 | 140744.0 | 0 | 60 |
| Inertial | 4 (0) | 0.00 | 0.00 | 167732.0 | 0 | 61 |
| Pressure cached+dormant | 1 (0) | 0.22 | 0.30 | 4182.7 | 0 | 77 |
| Pressure cached+dormant | 4 (0) | 0.20 | 0.30 | 4573.3 | 0 | 78 |
| wave_flow_v1 | 1 (0) | 0.00 | 0.00 | 173417.5 | 0 | 59 |
| wave_flow_v1 | 2 (0) | 0.00 | 0.00 | 161859.5 | 0 | 59 |
| wave_flow_v1 | 4 (0) | 0.00 | 0.00 | 133475.1 | 0 | 59 |
| wave_flow_v1 | 6 (0) | 0.00 | 0.01 | 129903.0 | 0 | 59 |
| wave_flow_v1 | auto (0) | 0.00 | 0.00 | 162090.5 | 0 | 59 |
| wave_flow_v1 ×3 | 1 (0) | 0.00 | 0.01 | 94862.1 | 0 | 59 |
| wave_flow_v1 ×3 | 2 (0) | 0.00 | 0.00 | 158296.0 | 0 | 59 |
| wave_flow_v1 ×3 | 4 (0) | 0.00 | 0.00 | 146338.5 | 0 | 59 |
| wave_flow_v1 ×3 | 6 (0) | 0.00 | 0.00 | 162833.0 | 0 | 59 |
| wave_flow_v1 ×3 | auto (0) | 0.00 | 0.00 | 123036.3 | 0 | 59 |

**2048² dam** — median of 2 runs

| Solver | Workers (observed) | Tick p50 ms | Tick p95 ms | Native ticks/s | Scheduled cores | Peak RSS MB |
|---|---:|---:|---:|---:|---:|---:|
| Cellular Yield | 1 (1) | 131.76 | 140.63 | 7.5 | 164 | 64 |
| Cellular Yield | 4 (4) | 37.68 | 42.67 | 26.2 | 164 | 64 |
| FreeMass | 1 (1) | 100.88 | 107.09 | 9.8 | 92 | 64 |
| FreeMass | 4 (4) | 28.85 | 32.29 | 34.3 | 92 | 64 |
| Inertial | 1 (1) | 53.62 | 56.84 | 19.1 | 89 | 80 |
| Inertial | 4 (4) | 14.48 | 15.50 | 70.8 | 89 | 80 |
| Pressure cached+dormant | 1 (1) | 477.99 | 595.86 | 2.2 | 228 | 112 |
| Pressure cached+dormant | 4 (4) | 189.09 | 221.99 | 5.4 | 228 | 113 |
| wave_flow_v1 | 1 (1) | 5.80 | 8.84 | 163.7 | 25 | 79 |
| wave_flow_v1 | 2 (2) | 3.90 | 4.92 | 254.0 | 25 | 80 |
| wave_flow_v1 | 4 (4) | 2.72 | 3.63 | 373.4 | 25 | 80 |
| wave_flow_v1 | 6 (6) | 2.73 | 3.40 | 381.8 | 25 | 80 |
| wave_flow_v1 | auto (11) | 2.71 | 3.33 | 378.9 | 25 | 80 |
| wave_flow_v1 ×3 | 1 (1) | 18.81 | 23.40 | 51.6 | 42 | 79 |
| wave_flow_v1 ×3 | 2 (2) | 12.01 | 13.74 | 82.3 | 42 | 80 |
| wave_flow_v1 ×3 | 4 (4) | 8.78 | 11.34 | 110.4 | 42 | 80 |
| wave_flow_v1 ×3 | 6 (6) | 8.77 | 10.24 | 113.5 | 42 | 80 |
| wave_flow_v1 ×3 | auto (12) | 8.62 | 10.08 | 115.2 | 42 | 80 |

**2048² wave** — median of 2 runs

| Solver | Workers (observed) | Tick p50 ms | Tick p95 ms | Native ticks/s | Scheduled cores | Peak RSS MB |
|---|---:|---:|---:|---:|---:|---:|
| Cellular Yield | 1 (1) | 6.83 | 7.53 | 152.6 | 15 | 68 |
| Cellular Yield | 4 (4) | 2.05 | 2.30 | 486.4 | 15 | 69 |
| FreeMass | 1 (1) | 12.97 | 13.84 | 81.0 | 15 | 68 |
| FreeMass | 4 (4) | 3.80 | 4.40 | 258.2 | 15 | 69 |
| Inertial | 1 (1) | 9.13 | 13.94 | 92.9 | 19 | 85 |
| Inertial | 4 (4) | 2.91 | 4.89 | 286.9 | 19 | 85 |
| Pressure cached+dormant | 1 (1) | 495.18 | 751.22 | 1.9 | 199 | 128 |
| Pressure cached+dormant | 4 (4) | 213.70 | 286.57 | 4.5 | 199 | 129 |
| wave_flow_v1 | 1 (1) | 3.52 | 5.16 | 265.5 | 9 | 86 |
| wave_flow_v1 | 2 (2) | 1.97 | 2.52 | 490.6 | 9 | 86 |
| wave_flow_v1 | 4 (4) | 1.24 | 1.62 | 795.9 | 9 | 86 |
| wave_flow_v1 | 6 (6) | 1.01 | 1.33 | 955.0 | 9 | 86 |
| wave_flow_v1 | auto (12) | 1.02 | 1.23 | 956.2 | 9 | 86 |
| wave_flow_v1 ×3 | 1 (1) | 13.83 | 20.66 | 67.9 | 14 | 86 |
| wave_flow_v1 ×3 | 2 (2) | 7.38 | 10.38 | 131.5 | 14 | 86 |
| wave_flow_v1 ×3 | 4 (4) | 4.16 | 6.22 | 235.8 | 14 | 86 |
| wave_flow_v1 ×3 | 6 (6) | 3.65 | 5.13 | 259.7 | 14 | 86 |
| wave_flow_v1 ×3 | auto (12) | 3.22 | 4.26 | 297.0 | 14 | 86 |

**2048² sparse** — median of 2 runs

| Solver | Workers (observed) | Tick p50 ms | Tick p95 ms | Native ticks/s | Scheduled cores | Peak RSS MB |
|---|---:|---:|---:|---:|---:|---:|
| Cellular Yield | 1 (1) | 54.49 | 61.23 | 18.0 | 960 | 78 |
| Cellular Yield | 4 (4) | 14.61 | 16.13 | 67.8 | 960 | 79 |
| FreeMass | 1 (1) | 79.28 | 86.49 | 12.5 | 960 | 78 |
| FreeMass | 4 (4) | 22.40 | 23.90 | 44.7 | 960 | 79 |
| Inertial | 1 (1) | 65.29 | 79.43 | 14.8 | 979 | 110 |
| Inertial | 4 (4) | 19.39 | 22.35 | 51.5 | 979 | 110 |
| Pressure cached+dormant | 1 (1) | 324.47 | 344.52 | 3.1 | 960 | 165 |
| Pressure cached+dormant | 4 (4) | 254.15 | 270.33 | 3.9 | 960 | 166 |
| wave_flow_v1 | 1 (1) | 37.15 | 57.13 | 23.6 | 670 | 115 |
| wave_flow_v1 | 2 (2) | 20.88 | 29.52 | 43.5 | 670 | 116 |
| wave_flow_v1 | 4 (4) | 12.65 | 19.65 | 70.6 | 670 | 116 |
| wave_flow_v1 | 6 (6) | 11.14 | 14.38 | 86.7 | 670 | 116 |
| wave_flow_v1 | auto (12) | 9.13 | 13.23 | 101.9 | 670 | 116 |
| wave_flow_v1 ×3 | 1 (1) | 109.04 | 127.19 | 9.1 | 960 | 115 |
| wave_flow_v1 ×3 | 2 (2) | 60.26 | 74.87 | 16.5 | 960 | 116 |
| wave_flow_v1 ×3 | 4 (4) | 36.51 | 44.57 | 27.2 | 960 | 116 |
| wave_flow_v1 ×3 | 6 (6) | 26.60 | 32.00 | 37.2 | 960 | 116 |
| wave_flow_v1 ×3 | auto (12) | 22.30 | 25.36 | 44.3 | 960 | 116 |

**2048² idle** — median of 2 runs

| Solver | Workers (observed) | Tick p50 ms | Tick p95 ms | Native ticks/s | Scheduled cores | Peak RSS MB |
|---|---:|---:|---:|---:|---:|---:|
| Cellular Yield | 1 (0) | 0.01 | 0.01 | 46060.6 | 0 | 68 |
| Cellular Yield | 4 (0) | 0.01 | 0.01 | 49950.3 | 0 | 69 |
| FreeMass | 1 (0) | 0.01 | 0.01 | 46514.8 | 0 | 68 |
| FreeMass | 4 (0) | 0.01 | 0.01 | 44468.2 | 0 | 69 |
| Inertial | 1 (0) | 0.01 | 0.01 | 48248.8 | 0 | 85 |
| Inertial | 4 (0) | 0.01 | 0.01 | 44387.1 | 0 | 85 |
| Pressure cached+dormant | 1 (0) | 114.17 | 164.71 | 8.1 | 0 | 128 |
| Pressure cached+dormant | 4 (0) | 114.33 | 122.78 | 8.7 | 0 | 129 |
| wave_flow_v1 | 1 (0) | 0.01 | 0.02 | 33137.1 | 0 | 86 |
| wave_flow_v1 | 2 (0) | 0.01 | 0.02 | 35181.6 | 0 | 86 |
| wave_flow_v1 | 4 (0) | 0.01 | 0.02 | 40743.6 | 0 | 86 |
| wave_flow_v1 | 6 (0) | 0.01 | 0.01 | 38092.4 | 0 | 86 |
| wave_flow_v1 | auto (0) | 0.01 | 0.01 | 42078.1 | 0 | 86 |
| wave_flow_v1 ×3 | 1 (0) | 0.01 | 0.01 | 40686.2 | 0 | 86 |
| wave_flow_v1 ×3 | 2 (0) | 0.01 | 0.01 | 42481.3 | 0 | 86 |
| wave_flow_v1 ×3 | 4 (0) | 0.01 | 0.02 | 40815.9 | 0 | 86 |
| wave_flow_v1 ×3 | 6 (0) | 0.01 | 0.02 | 31613.4 | 0 | 86 |
| wave_flow_v1 ×3 | auto (0) | 0.02 | 0.03 | 31258.0 | 0 | 86 |

The 512² rows (wave flow only) are in the raw CSV.

How to read it:

- "Workers (observed)" is the largest number of distinct pool workers that
  claimed tasks in one dispatch, not the configured count.
- `wave_flow_v1 ×3` runs three rounds per tick.
- In `wave`, the existing solvers simulate only the splash; wave flow also
  solves every chunk the wave reaches. The tick costs are therefore **not** for
  equal work, and the scheduled-core column shows it.
- These are native ticks on this CPU. They say nothing about frame rate.
- **Where more workers stop helping.** The 2048² dam scene is flat from four
  to six workers: its Water sits in about four chunk columns, so there are only
  about eight strip tasks, and the tallest strip sets the critical path. Finer
  strips or splitting tall columns are the follow-up, not more threads.
- **Three rounds cost three times.** `×3` on the sparse scene at one worker
  (109 ms) is slower than every existing solver except pressure. Rounds are a
  speed-for-cost dial, not free.
- Peak RSS is higher than FreeMass by the solver's nine bytes per cell.

## Behaviour probes on the real World

Tool: [`wave_mt_scenes.cpp`](../../native/bench/wave_mt_scenes.cpp), four workers.

### Wave interference

A 768×160 pool 64 deep. Disturbance A adds a 24×6 block at one quarter of the
width; B at three quarters; the trough removes the same block. The probe is the
mean level of three columns at the midpoint, with each run's mean level change
removed. Five separate runs test superposition directly.

| Solver | First arrival | Peak A | Peak A+B | Constructive ratio | Destructive ratio | Superposition error |
|---|---:|---:|---:|---:|---:|---:|
| wave_flow_v1 | tick 390 (0.49 cells/tick) | 0.600 | 1.187 | **1.98** | **0.23** | 0.10 |
| FreeMass | never | no change at the probe | no change at the probe | — | — | — |

Ideal linear waves give 2.0 and 0.0. Under FreeMass the probe only ever shows
the constant mean offset: no disturbance reaches it.

### Transport

| Probe | Result |
|---|---|
| Dam break, 512², one round per tick | Water quantity exactly conserved over 3,000 ticks; front advances about 0.08 cells/tick; reservoir stays smooth |
| Dam break, three rounds per tick | Front reaches the far wall (340 cells) by tick 1,500; conserved |
| FreeMass dam break, same scene | Front at x=483 by tick 3,000; visible stair-stepping along activity-block edges |
| Sealed 3-row passage between a 159-row and a 49-row arm | Levels converge monotonically (139.5 and 66.8 after 6,000 ticks); conserved; slow |
| Overflowing basin into a lower pool | Continuous curtain several cells wide; FreeMass gives a one-cell thread |
| Body mask sinking through a pool and lifted out | Quantity conserved; no Water written under the mask; contacts recorded |

Frames: [dam](wave-mt-001/dam-wave-flow-3-substeps-vs-freemass.png),
[waterfall](wave-mt-001/falls-wave-flow-3-substeps-vs-freemass.png),
[body](wave-mt-001/body-wave-flow.png). Each sheet shows wave flow on the top
row and, where present, FreeMass on the bottom row. These are diagnostic
renders from cell state, not the game's presentation.

## Native qualification

| Check | Result |
|---|---|
| `test_wave_flow` on Windows (MSVC `/O2 /W4`) | 10 tests, 0 failures |
| `make wave-flow-test` on Linux (g++ 13, `-O2`) | 10 tests, 0 failures |
| `make wave-flow-sanitize` (ASan + UBSan) | 10 tests, 0 failures, no report |
| `make wave-flow-thread-sanitize` (TSan) | 10 tests, 0 failures, no report (run with `setarch -R`; one earlier attempt aborted at start-up with the sanitizer's own "unexpected memory mapping" before any test ran) |
| Existing native suite on Windows with this branch's World | 192 tests passed, 0 failed |

The ten regressions cover: default-off and typed refusal; dam-break
conservation and terrain integrity; cell-identical results for 1, 2, 4 and 6
workers with more than one actual participant; propagation speed and
constructive/destructive interference; sleep and wake; sealed-passage
equalisation; body masks and contacts; Sand sinking through wave-flow Water;
quantity-ledger population after spreading and erase; chunk-capacity outcome.

**Pre-existing observation, not caused by this branch.** Built unoptimised
with MSVC (`/Od`), the existing test "extended material families" overflows the
default 1 MB stack. The same build of `main` `dea4e53d` overflows the same way
when that test runs alone. The suite result above uses a 16 MB stack. It was
not investigated further.

## Independent review

A separate Opus 5.5 pass reviewed the solver read-only against the claimed
properties. It found no data race, no face applied on one side only, no path to
negative mass and no dependence on worker count. It found, and commit
`90a04f98` fixes:

| Finding | Fix |
|---|---|
| The quantity ledger's Water cell population was never updated as Water spread, so a later erase or reaction could underflow it | Population delta applied in the owner reduction; regression added |
| A sealed stack could pass the carrier ceiling because the limit checked the wrong cell | The whole stack is marked saturated and refuses inflow |
| Other materials were not reliably woken where Water arrived or left | Wake on any Water/Empty transition, with a one-cell margin and along chunk edges |
| Flux damping rounded asymmetrically, leaning right | Symmetric rounding |

Left open from the review: one-unit trickles can stall at the edge of the
solved region; `cybersand_world_liquid_mass` (C API) returns 8 bits and would
wrap a transient overfill; wave flow ignores the selected simulation region.

## Negative results

Kept because each one cost time and would be easy to repeat.

| Attempt | What happened | Lesson |
|---|---|---|
| Head = height of the run's surface; gravity scaled down with depth for stability | A 20-cell splash on a 64-deep pool grew without bound | A restoring force that weakens where the water is deeper pumps energy into waves |
| Constant gravity on the top 32 rows, rows below keep their flux | Still grew | Flux with no restoring force must not be retained |
| Whole-unit flux transfer by truncation | Self-sustained ±0.7-cell noise in a calm pool | All rows move in lockstep; dither the sub-unit part per face |
| "Thick" cells transmit support | Fast outflow thinned deep cells, split the column into two surfaces and created a false head drop | Support follows cells that were full after the previous settle |
| Copy the flux of a falling cell to its destination | Momentum duplicated; kinetic energy created in the column pass | Falling Water carries no sideways momentum in v1 |
| Every exposed row of a liquid cliff pours half a cell | A 2-column checkerboard marched into the reservoir at one column per tick | Pour at most a quarter; two columns must not be able to swap |
| Falling thin cells counted as weight | A curtain of spray blocked the pour behind it | Only a full cell carries what rests on it |
| Uncapped inertia in bulk flow | Reservoir columns swung by ±60 cells for thousands of ticks | Inertia is bounded (`kCoast`); this is why bulk surges are sedate |
| Zeroing a cell's flux when it empties, inside the apply pass | A neighbouring strip read the zero: a rare 5-unit loss and a data race | No pass may write what another strip reads in that pass |
| Skipping faces between two dry columns | Stale flux moved Water out of empty cells | Clear the face rather than assume it is zero |

## Targets and where this stands

| Aspiration | Measured | Status |
|---|---|---|
| ≥ 2× faster complete ticks than pressure-dormant at large scale | 2048², one worker: dam 5.8 ms against 478 ms; sparse 37 ms against 324 ms | Met on these scenes, by 9× to 80× |
| A credible route to 30 ticks/s at 2048² | Dam 164 ticks/s on one worker, 373 on four. Sparse 24 on one worker, 71 on four | Met with two or more workers on every scene; the sparse scene misses on one worker |
| 60 ticks/s on lighter workloads | Dam and wave exceed it on one worker; sparse needs four | Met except sparse on one or two workers |
| Meaningful gain from one to several workers | 2048²: wave 3.5× and sparse 3.3× from one to six workers; dam 2.1× and flat beyond four | Partly met: the dam scene has only a few column strips, and the column pass dominates |
| Minimal idle cost | 0.01 ms a tick at 2048², the same as FreeMass; pressure-dormant 114 ms | Met |
| Modest memory | 9 bytes per cell of solver storage on the 8-byte cell | Larger than intended; 16-bit flux and head are the follow-up |

## Not done

- No `LiquidSolverPolicy` family, capability-matrix cell, wire vectors or
  receipt identity. Selection is a raw `WorldConfig` flag.
- No GDExtension binding, Godot scene, comparison menu or Windows evaluation
  package. The owner cannot yet see it running.
- No real Rapier body: the Needle question is unanswered. Contacts follow the
  existing contract (press down, push sideways); there is no buoyancy.
- No persistence, replay or physical-state hash coverage of the retained flux.
- No hosted CI run, no ready-for-review gates, no runtime publication.
- No trapped-air model.
