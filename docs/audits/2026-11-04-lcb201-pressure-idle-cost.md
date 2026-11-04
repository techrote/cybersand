---
title: LCB-002 #201 current-main PressureFlow idle-cost discrimination
status: Current
document-kind: evidence
scope: Source-qualified diagnosis and bounded Windows/WSL2 native measurement of PressureFlow reference, cached and cached_dormant cost at the #370 quiet-pool host scale, small-scale LCB-002 reconciliation, same-law parity, and an evidence-backed next implementation proposal; no production code, default or host change
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [../architecture/pressure-optimization.md, ../architecture/pressure-flow-v1.md, 2026-10-25-lcb002-pressure-variants.md, 2026-11-03-lcb-reassessment.md, ../architecture/simulation-tick-and-threading.md, ../reference/status-and-roadmap.md]
---

# LCB-002 #201 PressureFlow idle cost — 4 November 2026

## Result

**The quiet-water cost is real and persistent, partly reduced by the existing
variants, and further reducible.** In the task brief's terms this is
**Outcome B** ("residual cost is excessive"). That classification was not a
preregistered numeric criterion; it is unrelated to #26's Outcome B.

- **Real, not a cold window.** At the #370 quiet-pool scale, PF reference costs a
  median **31–41 ms per native tick** (replicate-median p50; per-child 31–44 ms)
  throughout 248 post-cold ticks on Windows.
  FreeMass costs 0.02 ms. The Water is asleep in every arm, with zero visited
  cells, Water calls or phase jobs. The time is **serial pressure preparation**:
  a global gas pass (≈14 ms) and a full head rebuild plus wake scan (≈24 ms) over
  all 1,638,400 resident cells. Configured four workers do not change it.
- **Cached/dormant help but are not sufficient.** Quiet cost drops to **≈9–12 ms**
  (0.28–0.30 of reference), still ≈500× FreeMass. The whole remainder is the
  per-tick sleeping-block wake scan, whose inputs are unchanged on quiet ticks.
  Dormancy adds nothing for sleeping Water.
- **Disturbance erases most of the benefit.** Remote gas edits (C/R 0.43),
  a moving body mask (0.52) and a per-tick boundary edit (0.91) force full gas
  passes and full column rebuilds.
- **Same law preserved.** Reference, cached and dormant matched on every tick of
  every registered child. That covers projection, complete quantity, gas
  table/history, PF ledger, body contacts and complete prepared heads.
- **Historical ratios reproduce** on the unchanged small-scale apparatus.

Two bounded, cached-only proposals (P1, P2) are recorded as **Planned**, with
proof obligations and measured upper-bound benefits. No production code, default,
host or CI changed. #201 stays open.


## Source and runtime authority

| Input | Identity |
|---|---|
| Accepted main (fetched 2026-11-04) | `3da7e7be4a6af4c85e03a7d8a0ed57229e5db33d` (#357). Previously observed `0fd4af5987e77db4da3e37c757cf2c0917ae9e15` is its ancestor; `git diff 0fd4af59 3da7e7be -- native tools/lcb` is empty, so the native/LCB tooling under test is byte-identical to the previously observed main |
| Registration commit | `69eef3f136e9f9cb327cfc973aaf594be69bdeb7`, tree `2dc2dc7d5018642caf0867937f933f5d1a364266`, branch `claude/lcb201-pressure-idle-cost`. It adds only the [registration](lcb201-idle-cost-2026-11-04/plan.json), the [scale driver](../../native/bench/lcb201_pressure_idle_cost.cpp) and the [runner](../../tools/lcb/pressure_idle_cost.py); no `native/src` or `native/include` byte differs from main |
| Implementation under test | PR #253 cached/cached_dormant, execution version 3, inside accepted main's [`world_pressure.inc`](../../native/src/world_pressure.inc), [`world_pressure_cache.inc`](../../native/src/world_pressure_cache.inc), [`world_pressure_gas_cache.inc`](../../native/src/world_pressure_gas_cache.inc) |
| Windows build | `pressure_idle_cost.py build`: LLVM-MinGW 20260826 UCRT, Clang 23.1.0 (`ea7d852a…`), compiler SHA-256 `bf58cf0e…f86a690`, `-std=c++20 -O3 -DNDEBUG -pthread -Wall -Wextra -Wpedantic`, exit 0, clean status, 67-file source fence unchanged. Scale binary `34d68235d504291ab6ad73dc3cf21fc1d7089394f661d534183b97a1c8ac9cc3`; LCB-002 binary `d7939bfd126c3a244709a8a8a92b423de8f180e5b391e0b4ad443d9a554e9233` |
| Linux build | Same runner in a depth-1 clone of the registration commit (`GIT_LFS_SKIP_SMUDGE=1`, clean status), GNU C++ 13.3.0 (`x86_64-linux-gnu-g++-13`, SHA-256 `1353e9bd…2c2769`), same flags; fence unchanged. Scale binary `aea91fb1883b50bee3d6bd3842fe4e2b49b6cfa9df99c99c97ef62ffacabe1db`, LCB-002 binary `f1ca7cea01ede24991ad20bb04bba95a95b5eb2df1f9cdb1fa2445e39725781f` |
| Machine | One AMD Ryzen 5 5600X (6C/12T), 32 GB; Windows 11 Pro 10.0.26300. Linux is WSL2 Ubuntu 24.04 (kernel `6.18.54.1-microsoft-standard-WSL2`) on the **same** hardware |
| Committed runtime check | Main's Windows DLL `ee09f7ab…7199a` records 80 native source inputs; all 80 equal main's Git blob bytes. It was not executed here (no host cohort) |

## Why a scale driver was needed

The registered [LCB-002 apparatus](../../native/bench/lcb_pressure_optimization.cpp)
cannot reproduce the #370 discrepancy. Its Worlds are 128×128 cells at chunk 32,
or 88×8 at chunk 8; phases are fixed at 8/48/32 with mandatory edits; and it has
no FreeMass context arm. The #370 quiet pool is a 1024² prepared domain at chunk
128, where `PreparedWorldBuilder` reserves the domain plus a 128-cell halo:
**100 resident chunks, 1,638,400 resident cells**, of which 151,040 are Water.

The [scale driver](../../native/bench/lcb201_pressure_idle_cost.cpp) therefore
`#include`s the LCB-002 translation unit unchanged and reuses its equivalence,
counter, memory-snapshot, head-comparison and peak-RSS routines. It adds only:

- the `lcb.rest.deep-quiet-pool.v1` geometry (Git blob `4d49876b…`), built through
  `PreparedWorldBuilder` with the controlled host's configuration — chunk 128,
  128 maximum/active chunks, 1,024 active cores, parallel threshold 2, rule radius 2,
  Water policy 8/12, configured Baseline transport, diagnostics on, obstacle field
  `0,0,1024,1024`, interest `16,16,992,272`, explicit `water-normalize-v1` (zero delta);
- phases cold 8 / settle 56 / quiet 96 / tail 96 ticks (256 in all);
- a FreeMass World as cost context only (never a same-law parity target).

The Baseline transport is reproduced as `configured=true` with default pair
values; its material-33 permeability override concerns a material absent here.

## Registered design

The [registration](lcb201-idle-cost-2026-11-04/plan.json) was committed before
any qualifying child. Five earlier diagnostic children (one alone, four
concurrent fixture smokes) are recorded there and excluded from every summary.

| Profile | State class | Tail disturbance |
|---|---|---|
| `pool-vented` | Truly asleep after settling | None |
| `pool-sealed` | Asleep under a one-cell lid; 7,552-cell sealed headspace (positive gas ID) | None |
| `pool-sealed-remote-gas` | Gas-compartment change | Headspace Wall pixel toggled every 8 ticks; lid vent/reseal every 32 |
| `pool-vented-moving-mask` | Explicit body contact | 8×8 native mask crossing the half-submerged surface every 4 ticks |
| `pool-vented-boundary-churn` | Repeated boundary/head change | Lid cell over one surface column toggled every tick |

Each child holds the four Worlds in one process. Preparation order and every
tick use a cyclic shift `(replicate + tick + position) mod 4`. Every arm sees every position, but each arm always follows the same predecessor, so carryover is not counterbalanced; only `World::tick()` is
timed. After every tick the reference, cached and dormant Worlds must have equal
pressure-variant projections, complete quantity ledgers, gas ledger/table/history,
PF ledgers and native body contacts/impulses; complete Water stays 38,515,200
with zero sources/sinks. Complete resident prepared heads are compared on nine
ticks. Any refusal stops the cohort.

The small-scale cohort reruns three unchanged LCB-002 profiles with the
unchanged binary source and reducer: `awake-boxed-water` (awake stationary),
`ordinary-sleeping-water` and `continuous-topology-churn`.

## Commands

```bash
python tools/lcb/pressure_idle_cost.py build --plan docs/audits/lcb201-idle-cost-2026-11-04/plan.json --core-head 69eef3f136e9f9cb327cfc973aaf594be69bdeb7 --compiler C:/Users/_/lcb-local-toolchain/llvm-mingw-20260826/bin/x86_64-w64-mingw32-clang++.exe --out OUT/windows-build
python tools/lcb/pressure_idle_cost.py run --plan docs/audits/lcb201-idle-cost-2026-11-04/plan.json --build OUT/windows-build/build.json --cohort windows --out OUT/windows-run
python3 tools/lcb/pressure_idle_cost.py build --plan … --compiler /usr/bin/g++ --out ~/lcb201-linux-build
python3 tools/lcb/pressure_idle_cost.py run --plan … --build ~/lcb201-linux-build/build.json --cohort linux --out ~/lcb201-linux-run
python tools/lcb/pressure_idle_cost.py reduce --plan … --runs OUT/windows-run --runs OUT/linux-run --out docs/audits/lcb201-idle-cost-2026-11-04/summary.json
```

The WSL2 cohort ran four children (`pool-vented`, `pool-sealed` × 1/4 workers), all passing, 37–39 s each.
The attribution-only perf run hit a `SIGPIPE` in a `| head` report step under
`pipefail` after recording completed; its reports were regenerated from the same
`perf.data` (SHA-256 `254a33c8…ce9b`) and symbolized with `addr2line`, because
this WSL `perf` build does not resolve symbols. The scripts are retained with the
receipts. Committed [`summary.json`](lcb201-idle-cost-2026-11-04/summary.json):
SHA-256 `4fdb0b3f127bbbad39983ebe76067b96a7cc6f6802f27fd4d0301bd83e385dbe`.

Windows ran 48 children (30 scale, 18 small-scale), completing 2026-11-04T02:33:50Z
with no failure, stderr byte or timeout and the source fence unchanged. Scale
children took 30.7–43.2 s each against the 300 s bound. Raw JSONL (102 MB),
per-child command/result/stderr files, host process inventories and the build
receipt are kept outside Git under the repository log policy, in
`C:/Users/_/lcb201-idle-cost-20261104/`. The committed
[`summary.json`](lcb201-idle-cost-2026-11-04/summary.json) binds every raw file
by SHA-256 through its cohort records.

## Where the quiet-pool time goes

The #370 discrepancy is reproduced and explained by source plus counters. After
about three ticks every Water block of the quiet pool is asleep in **all four**
arms: zero visited cells, zero moved cells, zero Water material calls and zero
dispatched phase jobs. The 74 remaining "active" blocks straddle the interest
boundary and are excluded from simulation. What remains is serial owner work
in `prepare_pressure_tick()` ([`world_pressure.inc`](../../native/src/world_pressure.inc)),
which runs before the active-chunk list on every tick of a pressure World.

**Reference (every tick, O(resident cells)).**

1. `resolve_gas_topology()` re-runs the complete gas operator. Its seed scan reads
   all 1,638,400 resident cells and probes the four neighbours of each of the
   151,040 Water cells (604,160 probes). The atmosphere BFS stops at the
   16,384-cell compartment limit (≈17,950 cells). The final relabel pass then
   visits all 1,638,400 cells again.
2. `compute_pressure_heads()` rebuilds every column (1,280) and every row (1,280)
   over all resident cells, writing 1,638,400 base heads.
3. The same function's row loop then runs the **sleeping-block wake scan**: for
   each inactive activity block it reads every cell's head and, for each Water
   cell, its flow/overfill plus four lateral samples (mask, residency, material,
   gauge or head). This is required by the state-only wake rule in
   [pressure_flow_v1](../architecture/pressure-flow-v1.md).

Four workers cannot help: no phase job exists to distribute. This matches the
serial-preparation statement in the [#359 reassessment](2026-11-03-lcb-reassessment.md).

**Cached and cached_dormant (quiet ticks).** Once a reference gas pass reaches a
fixed point (`gas_fixed_point`: unchanged table/topology, labels and resident
footprint), the cache marks gas clean and later ticks take `gas_reuses`: zero
seed, BFS or relabel work. With no producer edits, no column or row group is
dirty, so zero columns, rows, base or final heads are recomputed. **The whole
remaining preparation is the wake scan**, still O(resident cells) plus four
lookups per sleeping Water cell. Its inputs have not changed, so on a quiet tick
it always repeats the previous negative answer. That is the unjustified residual.

**Dormancy cannot help a sleeping pool.** Motion certificates apply only inside
`update_water_pressure`, i.e. to Water that is *visited*. The certificate layer
also stays disabled until a preceding tick made actual Water material calls
(`prepare_pressure_certificates`, [`world_pressure_cache.inc`](../../native/src/world_pressure_cache.inc)).
Dormant equals cached here, apart from the first awake ticks.

**Any gas-input change returns cached work to nearly reference cost.**

- A producer edit with a gas flag sets `gas_dirty`, so the next tick runs the
  **complete** reference gas operator; the cache reuses only proven-unchanged
  sealed-component BFS discovery, never the global seed scan or relabel.
- Whenever a gas pass runs, `prepare_pressure_tick` marks **every** column dirty
  and makes all certificates cold, even when the pass reached a fixed point with
  unchanged gauges.
- Installing or clearing a native body-mask cell calls
  `invalidate_pressure_input(..., gas=true)` (`World::set_transient_obstacle`,
  `World::clear_transient_obstacles` in [`world.cpp`](../../native/src/world.cpp)).
  A moving body therefore forces both effects on every tick it moves.

## Measured cost

All values are Windows, LLVM-MinGW Clang 23.1.0 `-O3`, three rotated replicates.
Each cell is the median across replicates of that child's per-phase statistic.
C/R and D/R are medians of per-replicate phase-total ratios to reference; values
below 1 are faster. The cold phase includes the first ticks, where all 151,040
Water cells are awake.

### Complete `World::tick()` milliseconds at #370 scale (p50 / p95 / p99 / max)

| Profile | W | Phase | Reference | Cached | Dormant | FreeMass | C/R | D/R |
|---|---:|---|---|---|---|---|---:|---:|
| pool-vented | 1 | cold | 35.37 / 112.00 / 112.00 / 112.00 | 10.18 / 98.24 / 98.24 / 98.24 | 9.88 / 108.88 / 108.88 / 108.88 | 0.03 / 83.68 / 83.68 / 83.68 | 0.694 | 0.670 |
| pool-vented | 1 | settle | 40.20 / 47.66 / 49.99 / 50.17 | 10.39 / 15.32 / 15.85 / 16.59 | 10.30 / 14.70 / 15.23 / 16.29 | 0.02 / 0.03 / 0.03 / 0.04 | 0.290 | 0.284 |
| pool-vented | 1 | quiet | 39.57 / 47.81 / 49.65 / 49.69 | 10.97 / 14.96 / 15.94 / 16.20 | 11.08 / 15.12 / 15.68 / 16.02 | 0.02 / 0.03 / 0.04 / 0.05 | 0.287 | 0.290 |
| pool-vented | 1 | tail | 38.71 / 48.41 / 50.92 / 51.89 | 10.78 / 14.85 / 16.50 / 17.12 | 10.43 / 15.51 / 16.39 / 17.15 | 0.02 / 0.03 / 0.04 / 0.74 | 0.282 | 0.289 |
| pool-vented | 4 | cold | 32.78 / 46.35 / 46.35 / 46.35 | 12.39 / 53.28 / 53.28 / 53.28 | 9.31 / 55.64 / 55.64 / 55.64 | 0.02 / 25.17 / 25.17 / 25.17 | 0.579 | 0.552 |
| pool-vented | 4 | settle | 37.48 / 46.90 / 48.15 / 53.27 | 10.07 / 14.58 / 15.06 / 17.07 | 9.98 / 14.88 / 15.29 / 16.88 | 0.02 / 0.03 / 0.03 / 0.05 | 0.283 | 0.287 |
| pool-vented | 4 | quiet | 38.67 / 48.52 / 49.99 / 50.93 | 11.02 / 14.98 / 16.02 / 17.57 | 10.90 / 15.19 / 15.81 / 18.47 | 0.02 / 0.03 / 0.03 / 0.04 | 0.290 | 0.289 |
| pool-vented | 4 | tail | 38.15 / 47.35 / 49.12 / 51.70 | 11.07 / 15.04 / 16.15 / 16.39 | 10.97 / 14.96 / 16.50 / 16.79 | 0.02 / 0.03 / 0.05 / 0.89 | 0.296 | 0.296 |
| pool-sealed | 1 | cold | 32.88 / 100.53 / 100.53 / 100.53 | 9.03 / 94.88 / 94.88 / 94.88 | 9.12 / 96.25 / 96.25 / 96.25 | 0.02 / 72.84 / 72.84 / 72.84 | 0.688 | 0.656 |
| pool-sealed | 1 | settle | 37.59 / 46.81 / 48.24 / 48.63 | 9.43 / 14.06 / 14.75 / 15.73 | 10.27 / 14.72 / 15.23 / 16.90 | 0.02 / 0.03 / 0.03 / 0.04 | 0.289 | 0.290 |
| pool-sealed | 1 | quiet | 39.57 / 46.86 / 49.03 / 53.58 | 11.47 / 15.22 / 15.76 / 16.11 | 11.02 / 15.12 / 16.38 / 16.44 | 0.02 / 0.03 / 0.03 / 0.04 | 0.294 | 0.291 |
| pool-sealed | 1 | tail | 38.54 / 47.58 / 49.16 / 50.18 | 10.96 / 15.07 / 15.86 / 16.46 | 10.94 / 15.02 / 16.70 / 16.82 | 0.02 / 0.03 / 0.03 / 0.77 | 0.298 | 0.292 |
| pool-sealed | 4 | cold | 34.01 / 64.72 / 64.72 / 64.72 | 10.19 / 50.62 / 50.62 / 50.62 | 9.87 / 50.13 / 50.13 / 50.13 | 0.02 / 25.41 / 25.41 / 25.41 | 0.532 | 0.536 |
| pool-sealed | 4 | settle | 35.81 / 44.48 / 44.92 / 45.89 | 10.29 / 14.83 / 15.20 / 15.58 | 10.94 / 15.41 / 16.04 / 16.98 | 0.02 / 0.03 / 0.03 / 0.03 | 0.300 | 0.299 |
| pool-sealed | 4 | quiet | 36.39 / 45.53 / 49.07 / 49.91 | 9.81 / 15.01 / 16.31 / 17.10 | 9.89 / 14.95 / 16.24 / 16.79 | 0.02 / 0.03 / 0.03 / 0.05 | 0.288 | 0.293 |
| pool-sealed | 4 | tail | 31.42 / 38.15 / 45.57 / 50.58 | 9.14 / 12.21 / 15.37 / 16.26 | 8.82 / 13.50 / 15.27 / 18.22 | 0.02 / 0.03 / 0.04 / 1.00 | 0.291 | 0.291 |
| pool-sealed-remote-gas | 1 | cold | 36.35 / 99.95 / 99.95 / 99.95 | 10.02 / 98.25 / 98.25 / 98.25 | 10.78 / 110.42 / 110.42 / 110.42 | 0.02 / 81.76 / 81.76 / 81.76 | 0.675 | 0.676 |
| pool-sealed-remote-gas | 1 | settle | 36.11 / 44.47 / 45.04 / 47.09 | 10.07 / 15.09 / 15.52 / 16.54 | 9.73 / 13.64 / 14.19 / 16.33 | 0.02 / 0.03 / 0.03 / 0.03 | 0.293 | 0.284 |
| pool-sealed-remote-gas | 1 | quiet | 37.13 / 47.50 / 49.27 / 55.37 | 9.40 / 14.96 / 16.20 / 16.74 | 10.40 / 14.69 / 16.16 / 19.46 | 0.02 / 0.03 / 0.03 / 0.03 | 0.287 | 0.291 |
| pool-sealed-remote-gas | 1 | tail | 39.35 / 50.09 / 53.83 / 55.19 | 12.54 / 35.17 / 43.80 / 49.40 | 12.48 / 36.98 / 43.14 / 49.80 | 0.02 / 1.90 / 2.90 / 2.95 | 0.431 | 0.430 |
| pool-sealed-remote-gas | 4 | cold | 31.79 / 52.53 / 52.53 / 52.53 | 8.95 / 53.47 / 53.47 / 53.47 | 9.76 / 53.11 / 53.11 / 53.11 | 0.02 / 25.38 / 25.38 / 25.38 | 0.557 | 0.544 |
| pool-sealed-remote-gas | 4 | settle | 34.52 / 46.63 / 48.52 / 58.08 | 9.67 / 14.26 / 15.48 / 16.17 | 10.17 / 16.67 / 16.78 / 17.67 | 0.02 / 0.03 / 0.04 / 0.04 | 0.288 | 0.294 |
| pool-sealed-remote-gas | 4 | quiet | 38.65 / 46.89 / 48.97 / 50.12 | 10.62 / 14.04 / 15.22 / 15.56 | 10.64 / 15.08 / 16.19 / 17.27 | 0.02 / 0.03 / 0.04 / 0.04 | 0.288 | 0.296 |
| pool-sealed-remote-gas | 4 | tail | 39.73 / 48.55 / 51.76 / 88.01 | 12.49 / 38.92 / 42.83 / 46.07 | 12.63 / 40.96 / 44.48 / 45.91 | 0.03 / 2.17 / 3.03 / 3.34 | 0.429 | 0.429 |
| pool-vented-moving-mask | 1 | cold | 44.88 / 120.30 / 120.30 / 120.30 | 12.94 / 108.19 / 108.19 / 108.19 | 13.43 / 110.12 / 110.12 / 110.12 | 0.03 / 80.96 / 80.96 / 80.96 | 0.700 | 0.653 |
| pool-vented-moving-mask | 1 | settle | 40.14 / 46.53 / 48.13 / 49.03 | 10.82 / 14.21 / 15.95 / 16.96 | 10.99 / 13.56 / 15.12 / 15.43 | 0.02 / 0.03 / 0.03 / 0.06 | 0.284 | 0.285 |
| pool-vented-moving-mask | 1 | quiet | 40.03 / 47.10 / 51.21 / 52.64 | 10.92 / 14.77 / 16.19 / 16.68 | 11.43 / 14.68 / 15.32 / 16.09 | 0.02 / 0.03 / 0.04 / 0.05 | 0.288 | 0.287 |
| pool-vented-moving-mask | 1 | tail | 40.85 / 48.06 / 51.16 / 56.75 | 14.39 / 42.99 / 45.65 / 48.86 | 13.80 / 44.57 / 47.86 / 52.19 | 1.23 / 2.78 / 3.35 / 4.01 | 0.518 | 0.516 |
| pool-vented-moving-mask | 4 | cold | 35.09 / 55.44 / 55.44 / 55.44 | 9.50 / 54.25 / 54.25 / 54.25 | 10.16 / 54.25 / 54.25 / 54.25 | 0.02 / 27.67 / 27.67 / 27.67 | 0.543 | 0.527 |
| pool-vented-moving-mask | 4 | settle | 39.95 / 48.40 / 54.98 / 55.69 | 11.24 / 15.09 / 16.06 / 18.91 | 11.29 / 15.05 / 15.32 / 16.67 | 0.02 / 0.03 / 0.04 / 0.04 | 0.285 | 0.284 |
| pool-vented-moving-mask | 4 | quiet | 40.30 / 46.65 / 51.96 / 53.85 | 12.17 / 15.17 / 17.10 / 27.08 | 11.95 / 15.63 / 17.53 / 22.24 | 0.02 / 0.03 / 0.04 / 0.05 | 0.291 | 0.295 |
| pool-vented-moving-mask | 4 | tail | 41.41 / 49.09 / 54.45 / 57.74 | 14.41 / 41.87 / 46.49 / 49.12 | 14.19 / 43.25 / 48.80 / 53.98 | 1.19 / 2.84 / 3.48 / 3.64 | 0.525 | 0.514 |
| pool-vented-boundary-churn | 1 | cold | 33.68 / 110.77 / 110.77 / 110.77 | 13.92 / 99.65 / 99.65 / 99.65 | 11.86 / 99.39 / 99.39 / 99.39 | 0.02 / 79.63 / 79.63 / 79.63 | 0.684 | 0.668 |
| pool-vented-boundary-churn | 1 | settle | 37.38 / 47.90 / 50.96 / 51.04 | 11.01 / 14.44 / 16.75 / 16.87 | 9.52 / 15.15 / 15.63 / 16.60 | 0.02 / 0.03 / 0.03 / 0.03 | 0.288 | 0.285 |
| pool-vented-boundary-churn | 1 | quiet | 39.99 / 48.27 / 50.90 / 53.36 | 10.96 / 15.33 / 16.74 / 17.30 | 10.99 / 15.12 / 15.89 / 16.66 | 0.02 / 0.03 / 0.03 / 0.04 | 0.284 | 0.285 |
| pool-vented-boundary-churn | 1 | tail | 39.57 / 48.71 / 57.95 / 83.53 | 35.43 / 44.48 / 47.06 / 48.92 | 35.98 / 44.16 / 49.28 / 49.99 | 0.44 / 0.69 / 0.78 / 1.15 | 0.909 | 0.909 |
| pool-vented-boundary-churn | 4 | cold | 34.42 / 50.46 / 50.46 / 50.46 | 9.79 / 48.59 / 48.59 / 48.59 | 10.21 / 49.22 / 49.22 / 49.22 | 0.02 / 26.76 / 26.76 / 26.76 | 0.557 | 0.544 |
| pool-vented-boundary-churn | 4 | settle | 32.20 / 36.86 / 41.62 / 50.32 | 8.99 / 12.11 / 14.78 / 15.16 | 9.02 / 13.08 / 16.21 / 16.98 | 0.02 / 0.03 / 0.03 / 0.03 | 0.282 | 0.290 |
| pool-vented-boundary-churn | 4 | quiet | 32.48 / 40.90 / 46.58 / 46.73 | 8.98 / 12.16 / 14.29 / 15.75 | 9.07 / 11.74 / 13.98 / 16.89 | 0.02 / 0.03 / 0.04 / 0.05 | 0.283 | 0.284 |
| pool-vented-boundary-churn | 4 | tail | 36.68 / 48.37 / 50.03 / 51.72 | 32.96 / 44.07 / 46.32 / 48.67 | 33.63 / 43.45 / 45.77 / 48.25 | 0.39 / 0.67 / 0.70 / 1.11 | 0.919 | 0.915 |

Complete tick minus counted `preparation_nanoseconds` is 0.02–0.05 ms for every
PF arm in the settle and quiet phases. The cold phase is larger (Windows 7.6–57 ms,
Linux 22–80 ms) because ticks 1–3 move every awake Water cell, and ≈1.2 / 0.4 ms in the mask/churn tails, where
FreeMass costs the same. The scheduler, `finish_tick` and kernel residual is
therefore negligible: **preparation is the PF idle cost.**

### Mean per-tick work, selected rows (median across replicates)

| Profile | W | Phase | Arm | prep ms | gas ms | head ms | gas ref/reuse | seed cells | relabel | cols | rows | final | Water mat/motion | cert attempts/saved | fallbacks | jobs ticks | claimants |
|---|---:|---|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---|---|---:|---:|---:|
| pool-vented | 1 | cold | reference | 31.55 | 12.96 | 18.47 | 1.00/0.00 | 1638400 | 1638400 | 1280 | 1280 | 0 | 56640/56640 | 0/0 | 0.00 | 3 | 1 |
| pool-vented | 1 | cold | cached | 12.42 | 3.08 | 9.12 | 0.25/0.75 | 409600 | 409600 | 320 | 160 | 204800 | 56640/56640 | 0/0 | 0.00 | 3 | 1 |
| pool-vented | 1 | cold | dormant | 11.96 | 3.31 | 8.95 | 0.25/0.75 | 409600 | 409600 | 320 | 160 | 204800 | 56640/37760 | 18880/18880 | 0.00 | 3 | 1 |
| pool-vented | 1 | quiet | reference | 39.25 | 14.54 | 24.71 | 1.00/0.00 | 1638400 | 1638400 | 1280 | 1280 | 0 | 0/0 | 0/0 | 0.00 | 0 | 0 |
| pool-vented | 1 | quiet | cached | 11.24 | 0.00 | 11.24 | 0.00/1.00 | 0 | 0 | 0 | 0 | 0 | 0/0 | 0/0 | 0.00 | 0 | 0 |
| pool-vented | 1 | quiet | dormant | 11.46 | 0.00 | 11.46 | 0.00/1.00 | 0 | 0 | 0 | 0 | 0 | 0/0 | 0/0 | 0.00 | 0 | 0 |
| pool-vented | 4 | quiet | reference | 38.53 | 14.12 | 24.45 | 1.00/0.00 | 1638400 | 1638400 | 1280 | 1280 | 0 | 0/0 | 0/0 | 0.00 | 0 | 0 |
| pool-vented | 4 | quiet | cached | 11.16 | 0.00 | 11.16 | 0.00/1.00 | 0 | 0 | 0 | 0 | 0 | 0/0 | 0/0 | 0.00 | 0 | 0 |
| pool-vented | 4 | quiet | dormant | 11.13 | 0.00 | 11.13 | 0.00/1.00 | 0 | 0 | 0 | 0 | 0 | 0/0 | 0/0 | 0.00 | 0 | 0 |
| pool-sealed | 1 | quiet | reference | 38.81 | 13.76 | 25.05 | 1.00/0.00 | 1638400 | 1638400 | 1280 | 1280 | 0 | 0/0 | 0/0 | 0.00 | 0 | 0 |
| pool-sealed | 1 | quiet | cached | 11.47 | 0.00 | 11.47 | 0.00/1.00 | 0 | 0 | 0 | 0 | 0 | 0/0 | 0/0 | 0.00 | 0 | 0 |
| pool-sealed | 1 | quiet | dormant | 11.40 | 0.00 | 11.40 | 0.00/1.00 | 0 | 0 | 0 | 0 | 0 | 0/0 | 0/0 | 0.00 | 0 | 0 |
| pool-sealed-remote-gas | 1 | tail | reference | 39.13 | 14.05 | 25.09 | 1.00/0.00 | 1638400 | 1638400 | 1280 | 1280 | 0 | 960/960 | 0/0 | 0.00 | 36 | 1 |
| pool-sealed-remote-gas | 1 | tail | cached | 15.84 | 2.77 | 13.11 | 0.21/0.79 | 341333 | 341333 | 267 | 10 | 12800 | 960/960 | 0/0 | 0.00 | 36 | 1 |
| pool-sealed-remote-gas | 1 | tail | dormant | 15.97 | 2.87 | 13.10 | 0.21/0.79 | 341333 | 341333 | 267 | 10 | 12800 | 960/875 | 85/85 | 0.00 | 36 | 1 |
| pool-vented-moving-mask | 1 | tail | reference | 40.15 | 14.80 | 25.26 | 1.00/0.00 | 1638400 | 1638400 | 1280 | 1280 | 1248 | 1816/1816 | 0/0 | 0.00 | 72 | 1 |
| pool-vented-moving-mask | 1 | tail | cached | 20.54 | 5.35 | 15.16 | 0.34/0.66 | 563200 | 563200 | 440 | 40 | 51200 | 1816/1816 | 0/0 | 0.00 | 72 | 1 |
| pool-vented-moving-mask | 1 | tail | dormant | 20.48 | 5.53 | 14.95 | 0.34/0.66 | 563200 | 563200 | 440 | 40 | 51200 | 1816/1656 | 163/160 | 0.00 | 72 | 1 |
| pool-vented-boundary-churn | 1 | tail | reference | 39.27 | 14.40 | 24.87 | 1.00/0.00 | 1638400 | 1638400 | 1280 | 1280 | 80 | 768/768 | 0/0 | 0.00 | 96 | 1 |
| pool-vented-boundary-churn | 1 | tail | cached | 35.47 | 14.82 | 20.81 | 1.00/0.00 | 1638400 | 1638400 | 1280 | 160 | 204800 | 768/768 | 0/0 | 0.00 | 96 | 1 |
| pool-vented-boundary-churn | 1 | tail | dormant | 36.36 | 14.86 | 21.51 | 1.00/0.00 | 1638400 | 1638400 | 1280 | 160 | 204800 | 768/768 | 0/0 | 0.00 | 96 | 1 |

The full table for all 40 profile/worker/phase rows is in
[`summary.json`](lcb201-idle-cost-2026-11-04/summary.json) (`comparisons[].median_mean_counters`).

### Linux platform check (WSL2, GNU C++ 13.3.0, one replicate; not pooled with Windows)

| Profile | W | Phase | Reference | Cached | Dormant | FreeMass | C/R | D/R |
|---|---:|---|---|---|---|---|---:|---:|
| pool-vented | 1 | cold | 33.81 / 242.19 / 242.19 / 242.19 | 9.22 / 240.07 / 240.07 / 240.07 | 9.39 / 251.09 / 251.09 / 251.09 | 0.02 / 211.61 / 211.61 / 211.61 | 0.833 | 0.836 |
| pool-vented | 1 | settle | 33.46 / 37.79 / 39.98 / 40.34 | 9.05 / 10.81 / 12.45 / 12.62 | 9.25 / 10.97 / 12.80 / 13.14 | 0.02 / 0.03 / 0.04 / 0.05 | 0.274 | 0.278 |
| pool-vented | 1 | quiet | 33.23 / 36.05 / 37.66 / 40.46 | 8.96 / 9.65 / 11.43 / 11.73 | 9.13 / 10.29 / 11.53 / 12.27 | 0.02 / 0.02 / 0.04 / 0.04 | 0.271 | 0.277 |
| pool-vented | 1 | tail | 34.45 / 38.57 / 40.47 / 48.26 | 9.17 / 10.91 / 13.12 / 13.48 | 9.26 / 10.82 / 12.51 / 13.41 | 0.02 / 0.03 / 0.04 / 0.83 | 0.272 | 0.273 |
| pool-vented | 4 | cold | 46.42 / 90.66 / 90.66 / 90.66 | 9.86 / 92.29 / 92.29 / 92.29 | 9.77 / 95.11 / 95.11 / 95.11 | 0.03 / 65.82 / 65.82 / 65.82 | 0.654 | 0.625 |
| pool-vented | 4 | settle | 34.74 / 46.24 / 50.70 / 67.55 | 9.38 / 13.15 / 14.14 / 17.37 | 9.62 / 13.19 / 16.44 / 17.63 | 0.02 / 0.03 / 0.03 / 0.04 | 0.272 | 0.278 |
| pool-vented | 4 | quiet | 34.41 / 37.84 / 42.52 / 55.13 | 9.19 / 11.92 / 12.46 / 12.59 | 9.29 / 11.07 / 11.96 / 13.16 | 0.02 / 0.03 / 0.03 / 0.04 | 0.270 | 0.271 |
| pool-vented | 4 | tail | 34.32 / 42.27 / 45.29 / 48.71 | 9.25 / 10.97 / 12.68 / 13.33 | 9.27 / 10.88 / 12.75 / 13.55 | 0.02 / 0.03 / 0.05 / 0.56 | 0.270 | 0.271 |
| pool-sealed | 1 | cold | 35.30 / 220.51 / 220.51 / 220.51 | 9.69 / 225.89 / 225.89 / 225.89 | 9.10 / 228.40 / 228.40 / 228.40 | 0.02 / 192.88 / 192.88 / 192.88 | 0.837 | 0.823 |
| pool-sealed | 1 | settle | 33.08 / 37.16 / 38.52 / 39.00 | 9.01 / 9.73 / 11.48 / 13.68 | 8.97 / 9.65 / 10.98 / 11.36 | 0.02 / 0.02 / 0.02 / 0.03 | 0.275 | 0.271 |
| pool-sealed | 1 | quiet | 33.36 / 36.51 / 38.47 / 39.55 | 9.15 / 9.92 / 10.74 / 12.01 | 9.17 / 10.05 / 11.76 / 12.84 | 0.02 / 0.02 / 0.03 / 0.03 | 0.275 | 0.276 |
| pool-sealed | 1 | tail | 33.50 / 37.63 / 39.81 / 41.32 | 9.17 / 11.32 / 12.21 / 12.45 | 9.16 / 10.75 / 15.29 / 16.66 | 0.02 / 0.03 / 0.04 / 0.80 | 0.278 | 0.280 |
| pool-sealed | 4 | cold | 37.01 / 89.11 / 89.11 / 89.11 | 9.40 / 92.44 / 92.44 / 92.44 | 9.48 / 92.98 / 92.98 / 92.98 | 0.02 / 67.60 / 67.60 / 67.60 | 0.675 | 0.679 |
| pool-sealed | 4 | settle | 33.60 / 37.97 / 38.56 / 38.69 | 8.97 / 9.70 / 11.15 / 11.84 | 9.11 / 9.85 / 10.39 / 11.89 | 0.02 / 0.02 / 0.03 / 0.03 | 0.266 | 0.270 |
| pool-sealed | 4 | quiet | 33.71 / 39.22 / 45.02 / 51.31 | 9.29 / 11.82 / 14.01 / 14.75 | 9.20 / 10.79 / 12.24 / 12.72 | 0.02 / 0.03 / 0.03 / 0.03 | 0.275 | 0.271 |
| pool-sealed | 4 | tail | 33.92 / 44.15 / 54.31 / 56.11 | 9.19 / 12.30 / 15.93 / 16.64 | 9.26 / 12.26 / 13.41 / 13.48 | 0.02 / 0.03 / 0.05 / 1.07 | 0.273 | 0.276 |

The WSL2 result has the same mechanism and ratio: quiet C/R and D/R 0.27–0.28;
reference ≈33–35 ms and cached ≈9 ms p50; FreeMass 0.02 ms. Linux cold-phase
maxima are larger (≈190–250 ms at one worker for every arm, FreeMass included),
so they are a platform/first-touch effect, not a PF difference. Peak RSS
286.5–286.9 MiB. Configured 1/4 claimants match Windows.

### Small-scale LCB-002 profiles, unchanged apparatus (median phase total ms; ratio)

| Profile | W | Phase | Ref ms | Cached ms | Dormant ms | C/R | D/R |
|---|---:|---|---:|---:|---:|---:|---:|
| awake-boxed-water | 1 | cold | 10.92 | 9.77 | 5.97 | 0.942 | 0.556 |
| awake-boxed-water | 1 | warm | 64.20 | 58.92 | 23.61 | 0.919 | 0.366 |
| awake-boxed-water | 1 | disturbed | 43.11 | 39.44 | 15.62 | 0.915 | 0.356 |
| awake-boxed-water | 4 | cold | 6.04 | 5.10 | 3.62 | 0.831 | 0.580 |
| awake-boxed-water | 4 | warm | 32.62 | 26.36 | 13.79 | 0.808 | 0.427 |
| awake-boxed-water | 4 | disturbed | 22.01 | 17.97 | 9.64 | 0.816 | 0.434 |
| ordinary-sleeping-water | 1 | cold | 5.43 | 4.50 | 4.11 | 0.830 | 0.780 |
| ordinary-sleeping-water | 1 | warm | 12.86 | 6.34 | 6.23 | 0.490 | 0.489 |
| ordinary-sleeping-water | 1 | disturbed | 9.60 | 5.29 | 5.04 | 0.540 | 0.529 |
| ordinary-sleeping-water | 4 | cold | 3.53 | 2.62 | 2.53 | 0.743 | 0.729 |
| ordinary-sleeping-water | 4 | warm | 13.18 | 6.42 | 6.37 | 0.491 | 0.494 |
| ordinary-sleeping-water | 4 | disturbed | 9.42 | 5.27 | 5.42 | 0.561 | 0.554 |
| continuous-topology-churn | 1 | cold | 0.16 | 0.12 | 0.11 | 0.432 | 0.513 |
| continuous-topology-churn | 1 | warm | 0.87 | 0.10 | 0.10 | 0.113 | 0.116 |
| continuous-topology-churn | 1 | disturbed | 1.19 | 1.28 | 1.27 | 1.089 | 1.079 |
| continuous-topology-churn | 4 | cold | 0.23 | 0.14 | 0.14 | 0.542 | 0.596 |
| continuous-topology-churn | 4 | warm | 0.84 | 0.10 | 0.10 | 0.114 | 0.117 |
| continuous-topology-churn | 4 | disturbed | 1.79 | 1.95 | 1.95 | 1.088 | 1.105 |


## Workers, memory and setup

| Observation | Evidence |
|---|---|
| Configured 1 vs 4 | Cold ticks dispatch up to 80 phase jobs; maximum claimants are 1 at one worker and **4** at four workers, in all four arms |
| Quiet/settle phases | **Zero phase jobs** in every arm and profile, so no claimant exists. PF time is pre-dispatch serial preparation; four workers leave quiet p50 unchanged within noise |
| Disturbed tails | Small jobs on 36/72/96 ticks, at most **one** claimant even at four workers. No scaling claim is made |
| Small-scale `continuous-topology-churn` w4 | Maximum claimants 1. That row's "4 workers" is configuration, not participation |
| World preparation | 102–227 ms per World (median 123 ms) through `PreparedWorldBuilder`, outside tick timers; zero tick-time chunk allocations |
| Cold tick | Tick 1, with every Water cell awake, first gas pass and index/cache build, is the cold-phase maximum: ≈100–120 ms at one worker and ≈46–65 ms at four for all PF arms; FreeMass ≈73–84 / 25–28 ms |
| Declared derived storage | Cached 15,082,780 B; dormant 16,721,180 B including a 1,638,400 B certificate buffer; reference 0. Pressure worker counters 57,344 B per PF World. The cached figure includes 8 MiB of reserved gas-member capacity |
| Process peak RSS | 272.5–274.9 MiB per child: four 1.64M-cell Worlds, four pools and the apparatus. This is not a per-arm figure |

## Same-law correctness and fallback

Every registered scale child completed all 256 ticks with the in-process
refusals armed. Reference, cached and dormant had identical
`PressureVariantEquivalenceV1` projections on every tick, as well as identical
complete quantity ledgers, overfill, gas allocator/revision, gas ledger,
compartment table and retirement history, PF ledgers and native body
contacts/impulses. All Worlds, FreeMass included, held exactly 38,515,200
Water units with zero source/sink flow. On the nine head ticks the complete
resident prepared-head fields (1,638,400 slots per arm) matched
reference exactly, with no unresolved sentinel. Every World stayed healthy.
The reducer independently rechecks per-tick projection agreement and head
discrepancy fields from the raw rows.

The disturbed profiles exercise the invalidation paths that the optimization
must keep correct: remote gas change, vent/reseal and headspace volume change,
a moving native mask producing real body contacts, and a per-tick boundary/head
change. Sealed-headspace compartments, history and retirement stay identical
across variants. The rest-certificate law is unchanged; in particular, any mask
in the 5×5 stencil still declines a certificate. Capacity/budget fallback is
covered by the unchanged LCB-002 `explicit-capacity-budget-fallback` profile and
native tests, not rerun here.

**Native regression groups (WSL2, unchanged main sources).** The Makefile
`build/tests` recipe was compiled with GNU C++ 13.3.0 (`-O0 -g3`, 50.6 s;
binary `bd0d8ec0…fad35`). It was run by name filter, with no failures, skips or
retries:

| Filter | Tests | Result | Seconds |
|---|---:|---|---:|
| `LCB-001 pressure` | 18 | all passed | 46.3 |
| `LCB-002` (cached heads, identity, dormant admission, gas invalidation/fallback, component discovery, capacity/pair budget, stationary-body obligations, remote wake, rotating masks, reconstruction, passages, vent into certified target, retired gas labels) | 15 | all passed | 28.4 |
| `LCB-003 prepared initial pressure` | 1 | passed | 2.7 |

These are the preserved historical failure controls named by #201: retired
gas labels, atmosphere-prefix fixed point, remote gas invalidation, stale
membership, capacity fallback and failed-proof cost admission. No test was
changed. Full-suite, sanitizer, TSan and GitHub-hosted gates were not run;
this checkpoint changes no production source.

## Reconciliation with earlier observations

- **#370 preflight.** The [unmerged draft #370 record](https://github.com/techrote/cybersand/pull/370)
  (`docs/audits/2026-11-03-lcb360-feel-preflight.md` at head `9a7436aa`) reports PF
  **reference** p50 ≈30–31 ms on the quiet pool from 30-tick cold windows, through
  the CI-built DLL in Godot. The present native median of 31–41 ms (below) is
  **consistent with** that value. It comes from a different binary and apparatus,
  so it is not a reproduction of the same measurement. Here the cost persists
  unchanged from tick 9 to 256: it is steady-state serial preparation, not a
  multiplicative PF physics slowdown. FreeMass sleeps to ≈0.02 ms in both records.
- **Earlier LCB-002 ratios.** The table in the #201 task brief is **execution1**
  ([LCB-002 record](2026-10-25-lcb002-pressure-variants.md), "Execution1
  observation" table). It is not the 90-child execution3 campaign or the later
  `c97f68ec…` repeat. All three are shown, each with its own source; today's
  small-scale rerun uses the same apparatus at main.

| Workload | Execution1 C/R · D/R | Execution3 campaign | `c97f68ec` repeat | 2026-11-04 |
|---|---|---|---|---|
| Awake stationary, 1 worker (warm) | 0.906 · 0.363 | 0.895 · 0.362 | 0.905 · 0.357 | 0.919 · 0.366 |
| Awake stationary, 4 workers (warm) | 0.774 · 0.414 | 0.773 · 0.426 | 0.775 · 0.415 | 0.808 · 0.427 |
| Topology churn, 1 worker (disturbed) | 1.084 · 1.075 | 1.103 · 1.086 | 1.084 · 1.079 | 1.089 · 1.079 |
| Topology churn, 4 workers (disturbed) | 1.032 · 1.038 | 1.071 · 1.053 | 1.060 · 1.070 | 1.088 · 1.105 |
| Ordinary sleeping (warm) | — | ≈0.493 | — | 0.490 · 0.489 (w1) |

  Today's ratios fall within, or close to, the spread of the earlier campaigns.
  Three replicates are fewer than their five, and the 4-worker churn row records
  at most one actual claimant. Dormancy's large benefit is specific to **awake**
  stationary Water, which the #370 pool is not. Optimization overhead under
  churn remains visible (≈+9–10%).

## Decision

**Outcome B — residual cost is excessive.** The existing variants are
same-law, safe and worth using as **explicit experimental** PF variants; cached
and dormant are equivalent on sleeping pools. Do not promote either to a default.

| Dominant operation | Why it runs | Can it shrink without changing semantics? |
|---|---|---|
| Quiet cached/dormant: sleeping-block wake scan (≈11 ms) | The state-only wake rule must catch any actionable gradient in a sleeping block | **Yes (P1).** On a quiet tick none of its inputs changed, so its answer is provably the previous negative answer |
| Disturbed cached: global gas pass (≈14 ms) | Any gas-flagged edit, including every mask cell write, invalidates the gas fixed point | Only partly. The reference gas operator is global by design (P3, deferred) |
| Disturbed cached: all-column head rebuild after any gas pass (up to ≈21 ms) | Conservative revocation because gauges feed heads and stencils | **Yes (P2).** Mark only columns whose labels or gauges actually changed |
| Reference: full gas + head + wake every tick (≈38 ms) | That is the reference operator | No. The reference is the law's executable definition |

## Proposed next implementation

**Status: Planned proposal, not implemented.** No production source changed in
this checkpoint. Both items stay inside the pressure-optimization owner
(`world_pressure*.inc`, `pressure_optimization.hpp`), apply only to the cached
and cached_dormant variants, leave the reference operator and every physical
law untouched, and would bump the optimization **execution version to 4**
because they change derived work. Neither touches `native/src/world.cpp`
(#358's write set), #347 contact code or #370's host/UI/fixtures.

### P1 — clean sleeping-segment wake summaries (quiet residual)

*Change.* Keep one derived "clean" bit per (resident chunk, local row, activity
block column) — 128 × 4 bits per 128-cell chunk, 6.4 KB at this scale,
preallocated with the chunk's pressure sidecar and never serialized. In the
cached head path's wake loop, skip an inactive segment whose bit is set. Set the
bit only after a complete negative scan of that segment. Clear it whenever the
segment's block is active, so a block that has just fallen asleep is always
scanned once.

*Proof obligation.* The wake predicate of a cell is a pure function of its own
final head and sidecar flow/overfill, and of mask, residency, material and
gauge-or-head at x±1 and x±2 in the same row; the start band is constant. Each
input must clear every segment that reads it:

| Input change | Existing owner path that must clear bits |
|---|---|
| Cell material or sidecar written by a producer/host/explosion | `invalidate_pressure_input(coord, rect, …)`: clear rows `min_y..max_y`, columns `min_x−2..max_x+2`, crossing chunk seams |
| Body mask set/clear | Same call (already issued with `gas=true`) |
| Final head value change | `put_final` when `old != value`: clear row y, columns x−2..x+2 |
| Any gas pass (labels or gauges) | Clear all bits (later narrowed by P2) |
| Reference preparation/fallback, `cache.cold()`, index rebuild, membership change, simulation-region/adhesion change, restore | Clear all bits |

A sidecar write into a sleeping cell by a neighbouring job must already be
witnessed through `JobEffects::record` → `invalidate_pressure_input`. The
implementation must prove that for every PF write site, or clear bits
conservatively there. A missed path produces a missed wake, which the
same-tick reference/cached/dormant projection parity detects. Bits are
derived owner state: they are cleared only on the serial owner, including the
phase-barrier merge that calls `invalidate_pressure_input`, never inside worker
jobs. The `put_final` x±2 clear must cross chunk seams.

*Required controls.* Remote vent adjacent to a clean segment; an edit at x+2
across a chunk seam; a column repair whose final head changes; a mask installed
at x±2; a block falling asleep then needing a gradient wake; reference fallback
followed by cached reuse; restore/reconstruction; 1/4-worker parity. Rerun this
registered cohort plus `LCB-001 pressure` and `LCB-002` native groups.

*Expected benefit.* The measured upper bound is the cached quiet head stage,
the whole quiet cached/dormant preparation, ≈11.1–11.5 ms mean per tick at Windows scale (complete tick minus preparation is ≈0.03 ms). Perf attribution: on WSL2 (g++ 13.3.0 `-O2 -g -fno-omit-frame-pointer`, `pool-vented` w1, 87,401
samples at 2 kHz, attribution only), call chains place **19.0% of all
process samples in the wake scan** (`compute_pressure_heads` lines 1061–1113).
That compares with 5.4% column pass, 1.7% row pass, 7.1% gas seed/BFS and 0.8% gas
relabel; 54% is untimed apparatus observation. The wake scan runs in all three
PF arms, while gas and column work run only in reference. It is therefore all of
cached/dormant quiet preparation and ≈30% of reference preparation. Its hot path
is `World::find_chunk` → `std::unordered_map<ChunkCoord,…>` probes for the x±1/x±2
samples. Even without elision, a same-chunk pointer fast path (P1b) would cut it
substantially. Remaining per-tick cost would be the O(rows × blocks) bit check
(about 51,200 bit reads here) plus certificate bookkeeping.

**P1b (independent, smaller).** Even when a segment must be scanned, the four
lateral samples resolve their chunk through `find_chunk` (an `unordered_map`
probe) although nearly all of them hit the cell's own chunk. A same-chunk
pointer fast path inside the scan changes no input or decision. It reduces the
hot path that perf identifies, also on scans P1 cannot skip, and needs only the
existing parity controls.

### P2 — narrow gas-triggered head and certificate revocation (disturbed regime)

*Change.* After a gas pass, do not mark every column dirty when its outcome
cannot alter any head input. Record labels that actually changed in the relabel
loop and compartments whose gauge changed. Mark only (a) the columns of
relabelled cells, (b) columns intersecting each changed compartment's bounds
(at most 1,024 compartments; atmosphere/vacuum gauge is a constant 0) and (c) the
existing producer-edit columns. Revoke certificates for those stencils instead
of globally.

*Proof obligation.* Heads read gauges only through `top_pressure`. The wake scan
(x±2 samples) and certificates (`pressure_lateral_gradient`) read them laterally,
so columns marked for relabelled cells must widen by ±2, across chunk seams.
Labels are written in **three** places, and all must be recorded: the per-node
whole-chunk relabel after `ensure_chunk`, the dangling-label→vacuum sanitation,
and the visited-cell relabel. `Compartment` carries no spatial bounds today, so
(b) needs new derived bounds storage with an admitted capacity and a
conservative all-columns fallback. Every gauge read must be at a cell whose
label or compartment was recorded. A fixed point
with unchanged gauges then marks nothing. The gas operator itself stays the
complete reference operator.

*Expected benefit.* In the boundary-churn and moving-mask profiles the head
stage would shrink from a full rebuild to local repair, leaving the global gas
pass: in `pool-vented-boundary-churn` cached spends ≈14.8 ms in gas and ≈20.8 ms in heads per tick; in `pool-vented-moving-mask`, ≈5.4 ms and ≈15.2 ms. The head share is the upper bound, so cached churn would fall from ≈35 ms toward ≈15 ms plus local repair, and P1 would also remove the wake part of the head share.

### P3 — not proposed now: global gas operator cost

The remaining O(resident) seed scan and relabel are the reference gas operator.
Per-chunk seed summaries could skip Water-free/label-free chunks, but labels are
physical authority inside the continuation hash. That needs a separate design
and its own negative controls. It is deferred, not recommended for the next
checkpoint.

## Notes for #360 and #363

**For #360 (LCB-FEEL).** The ≈30 ms PF quiet-pool tick in the #370 preflight is
consistent with a real, persistent native cost rather than a cold-window artifact.
Natively, it is serial PF *reference* preparation over the 1.64M resident cells that the prepared 1024² route makes
resident; it is not Water motion and not a worker-scaling failure. Cached and
cached_dormant are same-law, projection-identical execution variants that cut
quiet cost by about 3.5× (to 0.28–0.30 of reference), yet remain about 500× FreeMass at
idle. Any Water-adjacent edit or moving body mask returns them to roughly
reference cost. Report PF cost with variant and state class (asleep, gas change,
boundary churn, body contact) rather than as one "idle" figure. Configured four
workers do not reduce it. No new #360 scenario, UI or recorder is implied.

**For #363 (LCB-DECIDE).** Native evidence supports these statements only:

1. PF reference idle cost is O(resident cells) per tick by construction.
2. The existing cache removes the global gas and head rebuild only while nothing
   touches gas inputs; a remaining O(resident) wake scan sets its quiet floor.
3. Dormancy is useful only for **awake** stationary Water. That benefit is
   reproduced at small scale; at the #370 pool scale Water simply sleeps.
4. The residual is plausibly reducible by P1 and P2 without a law change, but that
   is unimplemented and unproven.

A PF gameplay-profile or promotion decision should not treat today's cached
variant as practically idle-free at 1024² scale, and should require a full-host
measurement first.

## Independent review

An independent reviewer, given no editing rights, inspected the branch, the
driver, the runner and the raw receipts.

**Checks that passed.**
- p95, max and phase totals recomputed from three raw children (two Windows, one
  Linux) match `summary.json` exactly, as do the ratios, claimants, resident
  chunks, RSS, preparation times, declared memory and perf shares.
- Every source-mechanism claim in this record checks out against
  `world_pressure.inc`, `world_pressure_cache.inc` and `world.cpp`.
- Idle pools block on a condition variable, so they do not spin.
- The host configuration matches the controlled prepared-liquid route.
- The registration commit precedes the build.

**Findings corrected before publication.**
- **Blocker:** historical ratios were mislabelled as execution3. They are now
  execution1, shown beside the execution3 campaign and the `c97f68ec` repeat.
- The reference p50 range is widened to 31–41 ms; between-child spread is
  ≈25%.
- The cold-phase tick-minus-preparation residual is stated separately.
- The rotation is described as a non-counterbalanced cyclic shift, with
  cache-cold absolute times.
- #370 is cited as a draft source, and "consistent with" replaces "reproduces".
- The non-preregistered "Outcome B" label is qualified.
- P2 now covers all three label writes, the missing compartment bounds and
  ±2 lateral widening.
- P1 requires serial-owner clearing and seam-crossing `put_final`
  invalidation.
- Quantile, child-duration and perf-provenance limits are added.
- The driver comment wrongly said the vented profile binds the #370 definition
  hash. This was corrected after execution, comment only: the executed driver is
  the registration commit `69eef3f1`, and the published head differs from it
  only in that comment.

The reviewer judged Outcome B justified on the native evidence.

## Limits

- **Native only.** No Godot, Rapier, `CyberSimulationWorker`, snapshot publication
  or rendering ran. Owner wait, main/Rapier cadence, snapshot age and displayed FPS
  are **not measured**. Desktop simulation and rendering are independently paced,
  so the native tick bounds the simulation rate, not directly the frame rate.
  **The full-host cohort was not executed in this checkpoint.** It needs a new
  derived case, for example the merged PACE-001 shared-host recorder installing
  this pool through `microscenario_apply_controlled_liquid` under each PF
  variant, rather than any #370 UI, recorder or fixture. That is the smallest
  next practical-cost experiment.
- **One machine, local desktop.** Background scheduling was uncontrolled; process
  inventories are retained. WSL2 shares the hardware and is never pooled with
  Windows. Neither cohort is GitHub-hosted CI.
- **Profiles are registered fixtures, not gameplay traces.** Edit cadences are
  bounded examples of each state class. Real body motion each tick is harsher than
  the moving-mask profile's four-tick cadence.
- **Cold-cache absolute times.** Four 1.6M-cell Worlds exceed the 5600X's 32 MB
  L3, and each tick follows an untimed whole-domain observation. Absolute values
  are therefore cache-cold; ratios rest on interleaving within each child. Children
  also differ by ≈25% between replicates, so absolute ranges are wide.
- **Quantiles** use rounded nearest rank. The 8-tick cold phase's p95/p99 equal its
  maximum.
- **Perf attribution** comes from a separately built `-O2 -g` binary (hash
  retained; no separate source fence). The run is the same registration commit's
  driver, all four Worlds share one profile, and stage shares are call-chain
  inferences, not timings.
- **Upper bounds, not implementations.** P1/P2 benefits are measured stage costs
  that the proposals would remove. They are not results of an implemented change.
- **Memory** is process peak RSS with four Worlds and declared derived capacity;
  it is not a per-arm or solver-only census.
- **#201 stays open.** This record neither closes it nor requalifies the
  historical execution3 campaign; its ratios keep their own source identity.
