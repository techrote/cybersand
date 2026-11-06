---
title: Whole-engine workbench benchmark and exact engine speedups
status: Current
document-kind: evidence
scope: 6 November 2026 experimental-branch (#406) evidence for the built-in bench-canvas, the workbench hard-surface pacing defect and its fix, and three exact native per-cell speedups (pair-rule tables, dense chunk directory, power-of-two addressing); local Windows plus WSL g++, not on main, no default changed
canonical-for: []
last-reviewed: 2026-11-06
related-documents: [2026-11-06-workbench-pf-tick-cost.md, ../architecture/simulation-tick-and-threading.md, ../operations/profiling-observability-and-performance.md, ../systems/player-control-playground.md]
---

# Whole-engine benchmark — 6 November 2026

## Result

1. **`bench-canvas`** is a built-in 1024×512 workbench start for benchmarking
   the whole engine. It holds eight barrels and four reacting zones:
   - a Water dam against a sand dune under a falling sand curtain;
   - a lava basin fed by a Water shelf and hanging ice;
   - oil on Water under a wood deck, with gunpowder, coal and a lava drip;
   - an acid bath with falling metal, beside a Water pool with salt and sodium.

   Its starting setup is 1,898 stamps and 3,931 runs, inside the 2,048 and 4,096
   budgets. The reactions occur in the live World: gunpowder detonates, sodium
   turns to brine, acid eats the wall material, lava makes steam, and wood and
   oil burn.
2. **Pacing defect: the hard-surface packet throttle.** The workbench lock-step
   steps Rapier only once the current hard-surface revision is installed. The
   worker published that geometry at most every 250 ms. On a canvas whose
   reactions edit hard terrain every tick, the whole session (cells, bodies and
   flyers) was capped at about 4 ticks/s: it measured 4.3–4.8 ticks/s against a
   7–8 ms native tick. There were three fixes:
   - under the lock-step, the worker publishes every changed revision (the
     packet is cached per revision);
   - unchanged queued chunks no longer consume the collider chunk budget;
   - a blocked physics callback installs with 4 ms/128 chunks instead of
     750 µs/32 chunks.

   Other modes keep their throttles.
3. **Exact native per-cell speedups** came from profiling (`perf`, g++):
   - `InteractionRules::may_pair` and `has_pair_rule` copied their derived
     8 KiB/256 B tables out of a function-local `constexpr` on every call under
     GCC. Before the fix, `may_pair` was 51% of all samples.
     `MaterialRules::pair_reaction` now uses namespace-scope tables, a
     load-time first-match table built from `match_pair_from` itself, and an
     inline partner rejection in the World chemistry callers.
     `interaction_rules.hpp` is unchanged because it is a catalogue-digest input.
   - `World::find_chunk` hashed an `unordered_map` for every neighbour read.
     An authoritative dense directory now mirrors the map over the reserved
     window; outside it the hash map still serves.
   - `World::address` divided by the runtime chunk size. Power-of-two chunks now
     use a shift and a mask, which is exact for every int64 coordinate in C++20.

## Identity

- Source: #406 `claude/water-ballistic-hybrid` at `abf205ec` plus this change.
  Final local Windows DLL:
  `5811e1799557912f0b45013189fd40ebf1a9a3f889c7fc25dcadd3ea7b496186`
  (LLVM-MinGW 20260826 / Clang 23.1.0). This is not a published runtime.
- Machine: 12 logical CPUs (6 native workers), TITAN RTX, Godot 4.7-stable,
  1920×1080 window. The WSL Ubuntu 24.04 build used g++ 13.3.0.
- The native bench replays the canvas recipe's exact 3,931 runs, without the
  barrels. All scripts were scratch only.

## Measurements

The workbench measurements use `bench-canvas`, 30 s, a still camera and all
liquids on their defaults (Water FreeMass, others CellularYield).

| Build | Cores | Ticks/s | Mean native tick |
|---|---|---|---|
| Before (`abf205ec`, DLL `85e62931`) | 64 | 4.8 | 8.22 ms |
| Pacing fixes only | 64 | 58.3 | 7.12 ms |
| Pacing fixes only | 32 (fine) | 59.9 | 5.02 ms |
| All changes (DLL `5811e179`) | 64 | 59.7 | 4.29 ms |
| All changes | 32 (fine) | 59.9 | 3.57 ms |

`my-canvas` with PF `cached_dormant` gas-free went from 6.28 ms to 3.34 ms at
59.9 ticks/s.

The native bench below measures `World::tick` only, over 600 ticks, with 64-cell
cores. Each row compares the previous HEAD `abf205ec` with this change.

| Compiler | Workers | Before | After | Speedup |
|---|---|---|---|---|
| Clang 23.1.0 (Windows) | 1 | 24.05 ms | 10.33 ms | 2.3× |
| Clang 23.1.0 (Windows) | 6 | 6.72 ms | 2.84 ms | 2.4× |
| g++ 13.3.0 (WSL), pair tables + chunk directory | 6 | 19.38 ms | 4.13 ms | 4.7× |
| g++ 13.3.0 (WSL), pair tables + chunk directory | 1 | 66.67 ms | 14.74 ms | 4.5× |

The g++ rows were measured before the addressing and inline-rejection steps.
Partner tables alone took the 6-worker g++ tick from 20.48 ms to 7.36 ms.

The published Linux runtime is built with g++-13, so it gets the larger gain.
After all changes the g++ profile is flat: no symbol exceeds 5%, and the
remaining cost is ordinary cell reads across the kernels.

## Exactness

- `state_hash` and `physical_state_hash` after 150, 300, 450 and 600 ticks of
  `bench-canvas` are identical to `abf205ec` with 1 and with 6 workers, under
  both Clang and g++. Both compilers end at `0c6c80b8c1233c88` /
  `38fe3d1d9fc09bc1`.
- A new native test, `test_pair_reaction_tables_match_resolver`, compares
  `MaterialRules` against `InteractionRules` for all 65,536 ordered pairs at
  eight probability rolls.
- The native `tests` binary passes 184 tests (Windows `-O2`).
- The full native suite passes under ASan/UBSan with g++ 13.3.0 (WSL). TSan
  under `setarch -R` reports no races in the worker-parity, determinism,
  phased, explosion, pair-table and parallel-heads tests.
- 25 Godot tests pass on DLL `5811e179`: workbench, Rapier, physical-actor,
  flight and PressureFlow (including the collider-budget fence in
  `test_physical_actor_integration.gd`).
- `test_workbench_canvas.gd` (131 checks) now also loads `bench-canvas`. It
  checks the budgets, eight bodies and every zone material, and that 90 ticks
  simulate.

## Protected-source transitions (proposed)

These are behaviour-preserving, execution-only edits. Every World's cell
results, hashes and receipts are unchanged (see Exactness). They are proposed
reviewed transitions for issue 362 and PR 406, pending independent review and
the owner's admission. The source edit is commit `8bbabb2d`; each transition is
pinned to `35c1373ef31c8ed96fd9752eecbc3f129b34c5ba`, the commit that adds this table, which carries
byte-identical sources.

| Path | From LF SHA-256 | To LF SHA-256 |
|---|---|---|
| `native/src/world.cpp` | `09685e01cdd7e2bb898f46ce3c9ab97b7427ac34e7568875a3bdfd7866190ac5` | `a69a70332450ed246753457f85fcedfa0e3a36e848486e12c441a059c3574d1e` |
| `native/src/material_rules.cpp` | `8fd1509bfcef162c5cb6028e9af38c563ad651822b9fcfcc2e79a569d185afa3` | `3afda824571842e387b0cac70218ee5f1f96005d07aaaafcf95c146c3eee3254` |

## Scoped runtime publication

The owner approved this on 2026-11-06. A branch-scoped publisher clones the
#201 moving-camera profile (#405). It changes neither that profile nor the
shared four-path engine. Its files are:

- [`wbh406-runtime-publication.yml`](../../.github/workflows/wbh406-runtime-publication.yml)
- [`wbh406_runtime_publication.py`](../../tools/ci/wbh406_runtime_publication.py)
- the adversarial guards in
  [`test_wbh406_runtime_publication.py`](../../tools/ci/test_wbh406_runtime_publication.py)
- the request
  [`wbh406_publish_request.json`](../../tools/ci/wbh406_publish_request.json)
  (sequence 1)

Only a push to `claude/water-ballistic-hybrid` that carries the request arms
it. Four native groups must pass before any build:

- `LCB-002`, including the P1 wake-summary control;
- `LCB-001 pressure`;
- `Workbench parallel`, the all-variant parallel-heads exactness test;
- `Pair reaction`, the 65,536-pair table test.

Then both runtimes are built from the exact source. Each one runs import plus
`test_lcb_pressure_optimization`, `test_lcb_pressure_reference`,
`test_liquid_pressure_rapier`, `test_simulation_worker_interest_ownership` and
`test_workbench_canvas` on its actual target OS. The canvas case must not
report a skipped built-in load. It has one explicit, stricter bound: 600 s
against its 3,940 s watchdog. The publish job appends exactly one bot commit
with the four runtime/manifest paths, guarded by a force-with-lease on the
built SHA. Full ready-head CI remains a separate gate.

Local guards passed: 25/25 profile tests, the shared-engine suite (unchanged),
and the CI-provider policy. A local `test_workbench_canvas` log (131/0) contains
no `ERROR:` or skip text.

**Published.** Run
[42194937946](https://github.com/techrote/cybersand/actions/runs/42194937946)
(attempt 1, 2026-11-06 09:25–09:37 UTC) built both runtimes from `297e9979` and
passed every job:

- the publisher guards;
- admission;
- the four native groups;
- the Linux build and execution;
- the Windows cross-build and Windows execution;
- publication.

Bot commit `60b4cda4` appended only the four runtime/manifest paths.

| Runtime | SHA-256 | Bytes | Toolchain |
|---|---|---|---|
| `cybersand_native.windows.x86_64.dll` | `0b831fc916a02054703cb3d06b14923beefe40402a572870fbdecc1d79a85155` | 5,035,520 | LLVM-MinGW 20260826 / Clang 23.1.0 |
| `libcybersand_native.linux.x86_64.so` | `1b7481f3eb503cc846fb5f7d69ecb43c003983544d03652adf0e2d5abb0960ba` | 4,480,224 | g++-13 13.3.0 |

After the append, `check_repository.py` reports no errors locally (there were
32 stale-runtime errors before). The full ready-head CI remains a separate gate.

## Gaps

- Windows and WSL on one machine only. There is no Web build or CI-runner
  timing. The scoped publication covers only its five Godot cases; the full
  ready-head CI has not run.
- Gas topology remains serial (see the
  [PF tick-cost record](2026-11-06-workbench-pf-tick-cost.md)).
- The main-thread full-image texture upload and render cost were not profiled.
  Rendering held 60 fps throughout.
- There is no human gameplay acceptance.
