---
title: LCB-002 #201 moving-camera PressureFlow cache invalidation
status: Current
document-kind: evidence
scope: Diagnosis, behaviour-preserving narrowing and native before/after evidence for World::set_simulation_region discarding the cached/cached_dormant PressureFlow derived state on every selected-core change; exactness, negative control and cost under camera-like region motion; experimental branch, not on main
canonical-for: []
last-reviewed: 2026-11-05
related-documents: [2026-11-04-lcb201-region-flip.md, 2026-11-04-lcb201-p1-wake-summaries.md, 2026-11-04-lcb201-pressure-idle-cost.md, ../architecture/pressure-optimization.md, ../architecture/simulation-tick-and-threading.md]
---

# LCB-002 #201 moving-camera cache invalidation — 5 November 2026

## Result

`World::set_simulation_region` called `pressure_->cache->cold()` whenever the
selected scheduling cores changed. A desktop camera window crosses a 64-cell
core seam every few ticks, so each crossing forced a gas reference pass, a
pressure index rebuild and a full head recomputation (1,024 columns on the
host-sized fixture). Nothing in the PressureFlow cache reads the selected or
applied region: the index, heads, gas topology and components, rest
certificates and P1 wake summaries are all computed over every resident chunk.
The invalidation was conservative, not required.

The branch removes that one invalidation. Results stay **bit-identical**: the
reference, cached and cached_dormant arms have equal pressure-variant
equivalence hashes on every tick at every speed, with one and four workers.
Pure camera motion no longer causes any gas pass, index rebuild or column
recomputation in the cached arms. Cached p99 at 1–4 cells per tick falls from
≈32–37 ms to ≈11–14 ms; cached p50 at 16 cells per tick falls from ≈26–31 ms to
≈11 ms; at 64 cells per tick (a new core set every tick) from ≈48–52 ms to
≈26–32 ms. Static-camera cost is unchanged (≈0.21 ms cached, ≈18.7 ms reference).

The remaining cost under motion is the existing **inclusion wake**: at tick
entry, `begin_tick` wakes every block whose included core range changed, and
those blocks then run ordinary kernels (the reference arm shows the same
growth, ≈18.6 → ≈50 ms). That wake decides which cells simulate, so it is a
scheduling/physics semantic with region-history consequences. It is
deliberately **unchanged** here; narrowing it would be an authority change that
needs its own owner decision and qualification.

## Source and change

| Item | Value |
|---|---|
| Base | accepted main `ba9cbc89029be88b812af59b19e5c59829bbcd90` (tree `3af18f50e6094776263119623b64a1b2f4ca0ab2`), #394 merged |
| Branch | `claude/pf201-moving-camera` (separate from the ballistic Water branch; no ballistic code) |
| Production change | `native/src/world.cpp` `World::set_simulation_region`: the selected-core-change `pressure_->cache->cold()` is removed; the settled-discovery inclusion request and tick-entry inclusion wake are unchanged |
| Protected source | `native/src/world.cpp` LF SHA-256 `a47955f79ed5fbc8bc0ca8e2892ed4eb0ddbd728b841bc08ccee14a4c239e4a7` → `b713711374e1ba887bcdd9a49629c11aaf66b55b621b347f1fe0d050d569bc0a` at source commit `9adb98c1671808c01c4919dd79846e68b202c452`; proposed reviewed transition (issue 201, PR 405) in `tools/material_catalogue/compatibility.py`, pending independent review and the owner's admission |
| New regression | `native/tests/test_pressure_moving_region.inc`, test "LCB-002 #201 moving region keeps exact warm pressure caches" |
| New apparatus | `native/bench/lcb201_moving_camera.cpp` |

`set_liquid_surface_adhesion_enabled` keeps its `cold()`: adhesion changes the
kernel's motion law, so derived certificates and wake summaries can depend on it.

## Exactness evidence

- **Regression test.** Three arms (reference, cached, cached_dormant), workers 1
  and 4, gas off and on, 8-cell cores/chunks. A vented pool across chunk seams, a
  sealed lidded gas room and a falling Water slab keep real motion alive while
  the region moves 5 cells per tick in a ping-pong window for 48 ticks, then
  shrinks to one core and re-enters unbounded. Every tick compares the complete
  gas-cache-equivalent state and the full quantity ledger
  (`acceptance_equal`). It also requires that region motion alone causes no index
  rebuild, no reference fallback and (gas off) no gas reference pass.
- **Negative control.** Re-inserting the old `cold()` makes the same test fail
  with "region motion alone rebuilt the pressure index"; the patch was then
  restored byte-for-byte.
- **Benchmark parity.** `lcb201_moving_camera` hard-fails on any same-tick
  `PressureVariantEquivalenceV1` difference between reference and either cached
  arm. All runs below completed without a divergence.

## Cost evidence

Command (WSL2 Ubuntu 24.04, kernel 6.18.54.1-microsoft-standard-WSL2, g++
13.3.0, `-O2 -DNDEBUG`, 12 logical CPUs shared with a concurrent Godot run, so
absolute times are advisory):

```bash
g++ -std=c++20 -O2 -DNDEBUG -Inative/include native/src/world.cpp native/src/material_rules.cpp native/src/scheduler_geometry.cpp native/src/settled_world_discovery.cpp native/bench/lcb201_moving_camera.cpp -pthread -o moving_camera_<arm>
./moving_camera_<arm> 160 1 quiet > <arm>-quiet.jsonl
./moving_camera_<arm> 160 4 flow > <arm>-flow-w4.jsonl
```

Binary SHA-256: baseline (main) `29e52405…3243de93`, patched `e82538e9…3677a49`.
Fixture: 1024×1024, chunk 128, host capacities, vented 960×140 pool, sealed gas
room; 120 settle ticks under a fixed 480×270 interest, then 160 timed ticks with
the window moving horizontally (ping-pong) at the given speed. Only `World::tick`
is timed.

Quiet profile, one worker:

| Speed (cells/tick) | Core changes | Arm | Baseline p50/p95/p99 ms | Patched p50/p95/p99 ms | Baseline gas / index / columns | Patched gas / index / columns |
|---:|---:|---|---|---|---|---|
| 0 | 0 | reference | 18.64 / 22.62 / 25.89 | 18.82 / 20.48 / 23.52 | 160 / 0 / 163840 | 160 / 0 / 163840 |
| 0 | 0 | cached | 0.21 / 0.32 / 0.35 | 0.21 / 0.27 / 0.39 | 0 / 0 / 0 | 0 / 0 / 0 |
| 0 | 0 | cached_dormant | 0.22 / 0.30 / 0.38 | 0.22 / 0.27 / 0.40 | 0 / 0 / 0 | 0 / 0 / 0 |
| 1 | 6 | reference | 20.21 / 30.34 / 33.44 | 18.87 / 28.09 / 34.21 | 160 / 0 / 163840 | 160 / 0 / 163840 |
| 1 | 6 | cached | 0.22 / 12.14 / 31.78 | 0.20 / 10.25 / 11.13 | 6 / 6 / 6144 | 0 / 0 / 0 |
| 1 | 6 | cached_dormant | 0.22 / 12.37 / 32.75 | 0.21 / 10.19 / 11.32 | 6 / 6 / 6144 | 0 / 0 / 0 |
| 4 | 21 | reference | 21.74 / 37.07 / 39.47 | 19.43 / 31.33 / 34.99 | 160 / 0 / 163840 | 160 / 0 / 163840 |
| 4 | 21 | cached | 0.24 / 33.57 / 37.36 | 0.21 / 11.38 / 13.06 | 21 / 21 / 21504 | 0 / 0 / 0 |
| 4 | 21 | cached_dormant | 0.26 / 34.03 / 37.20 | 0.22 / 11.34 / 13.76 | 21 / 21 / 21504 | 0 / 0 / 0 |
| 16 | 83 | reference | 31.15 / 35.64 / 42.73 | 30.10 / 37.27 / 55.14 | 160 / 0 / 163840 | 160 / 0 / 163840 |
| 16 | 83 | cached | 25.62 / 36.65 / 41.61 | 10.95 / 13.34 / 19.03 | 83 / 83 / 84992 | 0 / 0 / 0 |
| 16 | 83 | cached_dormant | 25.73 / 36.40 / 40.86 | 10.94 / 13.93 / 23.80 | 83 / 83 / 84992 | 0 / 0 / 0 |
| 64 | 160 | reference | 50.69 / 57.35 / 61.44 | 50.44 / 57.13 / 90.92 | 160 / 0 / 163840 | 160 / 0 / 163840 |
| 64 | 160 | cached | 51.63 / 59.54 / 68.18 | 32.11 / 36.83 / 42.85 | 160 / 160 / 163840 | 0 / 0 / 0 |
| 64 | 160 | cached_dormant | 51.72 / 59.07 / 68.96 | 31.63 / 36.39 / 40.05 | 160 / 160 / 163840 | 0 / 0 / 0 |

"Flow" profile, four workers (cached arm): speed 1 p95/p99 13.01/32.94 → 10.04/13.50 ms;
speed 4 32.79/45.36 → 12.30/14.12 ms; speed 16 p50 30.59 → 10.58 ms; speed 64 p50
48.41 → 26.11 ms; gas passes and index rebuilds 6/21/83/160 → 0. The profile's
reservoir sits outside the moving window, so its Water is paused; motion inside
the window is limited to woken pool blocks. The regression test supplies the
active-flow exactness case.

## Native suite

The full native suite (`tests`, WSL g++ 13.3.0, `-O1 -g`, run from the repository
root, 2 min 20 s) passed **167/167** on the branch, including the new regression.
No Windows MSVC/LLVM, Godot or in-app host run has been made for this branch yet.

## Second step: pair-chemistry lookup cost (gas-free cached_dormant profile)

The owner asked for gas-free `cached_dormant` PressureFlow optimisation. A `perf`
profile (`-e cpu-clock`, `native/bench/wcx_surge_assessment.cpp`, one worker,
dam break) of that arm attributed **≈36 % of the tick** to
`InteractionRules::may_pair` and `MaterialRules::pair_reaction`, and ≈15 % to
chunk hash-table lookups. Preparation (heads only, 214 of 1,024 columns per tick)
was ≈0.63 ms; the rest was ≈11k Water kernel calls per tick.

`may_pair` and `has_pair_rule` (in `interaction_rules.hpp`, a protected identity
input that is not edited) declare their 256-entry constexpr tables as non-static
locals, which this GCC build materializes on every call. `world.cpp` now tabulates
both functions' exact results once per process (`pair_tables()`), skips
`pair_reaction` only where `may_pair` is false (where it returns no reaction
anyway), and uses the cached participation flag. Reactions, probability rolls,
neighbour order and all state are unchanged.

Same dam break (1024×192, 4 workers, 300 ticks, `-O2`); surface-motion metrics are
identical before and after in every arm:

| Arm | p50 before | p50 after | p95 before | p95 after |
|---|---:|---:|---:|---:|
| PressureFlow cached_dormant, gas off | 8.07 ms | 3.83 ms | 9.41 | 4.35 |
| FreeMass | 7.97 ms | 2.58 ms | 8.98 | 3.01 |
| PressureFlow reference, gas on | 11.79 ms | 7.17 ms | 13.66 | 7.95 |

The full native suite passed 167/167 on two consecutive runs with this step. One
earlier full run reported the "worker activity publication" fixture's final
premise (at least two actual pool participants) as missed; every per-tick
1-worker/4-worker/serial-reference equality inside it had passed, and the fixture
then passed 20/20 isolated repeats on both the base and patched builds. It is
recorded as an intermittent participation premise, not a behavioural difference;
the fixture's failure message now prints which premise failed.

The gain is engine-wide (any material with pair chemistry probes neighbours this
way), not specific to PressureFlow. The next candidate is the per-sample chunk
hash lookup in the PressureFlow kernel and wake scan.

## Gaps and next steps

1. Desktop in-app before/after with the worker's camera window (the #370 host
   path) is not yet measured; the native evidence above predicts the cached
   moving-camera step falls to the inclusion-wake cost.
2. The inclusion wake is now the dominant moving-camera cost. Measuring how much
   of it is necessary (blocks that were asleep and untouched while excluded) is
   the next experiment; changing it is out of scope without an owner decision.
3. Windows and Linux CI gates, independent review and ready-state qualification
   remain required before integration.
