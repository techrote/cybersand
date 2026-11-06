---
title: Heavy-activity stress canvas and the bottlenecks it surfaced
status: Current
document-kind: evidence
scope: 6 November 2026 experimental-branch (#406) evidence for the built-in stress-canvas, box stamps with merged construction rectangles, the distinct-core capacity correction, the per-tick MicroScenario summary copy and the remaining native and workbench costs; local Windows plus WSL g++, not on main, no default changed
canonical-for: []
last-reviewed: 2026-11-06
related-documents: [2026-11-06-whole-engine-bench.md, 2026-11-06-workbench-pf-tick-cost.md, ../reference/configuration-reference.md, ../operations/configuration-and-capacity-budgets.md, ../systems/player-control-playground.md]
---

# Stress canvas — 6 November 2026

## Result

1. **`stress-canvas`** is a built-in 2048×1024 workbench start for stress
   testing. It has two tiers of eight zones. The shelf between the tiers has
   pour gaps, so upper-tier products fall into the lower tier. Eight barrels
   drop into the pools.

   There are 55 materials, staged against their authored pair partners, heat
   sources or fire:
   - snowfield;
   - glassworks;
   - pyrotechnics (woods, gunpowder, magnesium and thermite under fire and
     sparks);
   - foundry (wax, sulfur, polymer, phosphor and sugar glass);
   - avalanche;
   - biology (plant, seed, fungus, mites);
   - sludge and mercury;
   - oil depot with rockets and cement;
   - volcano (basalt and obsidian);
   - molten-glass quench;
   - acid bath with submerged metal, iron, zinc, marble and chalk;
   - salt lake (rock salt, sodium, brine under fire);
   - earthworks (adobe, clay, rammed earth, gypsum, quicklime, sandbags);
   - refinery fire;
   - dam break;
   - lava against ice.

   Cloner is excluded because it grows without bound.
2. **Box stamps and merged rectangles.** A starting-paint stamp is now either a
   brush disc `[x, y, radius, material]` or an axis-aligned box
   `[x, y, width, height, material]`. The brush still produces only discs and
   the palette is unchanged. Starting paint may also use an explicit list of
   staged materials. `rectangles()` now extends a run that is identical
   (start, width, material) to one ending on the previous row, so a painted box
   costs one record.

   Native construction rasterises rectangles into a per-cell map, so any
   non-overlapping decomposition of the same cells builds the same World.
   - stress-canvas: 119 stamps, 129 rectangles. Disc fills would have needed
     5,787 stamps, against a budget of 2,048.
   - bench-canvas: 3,931 rows → 2,702 rectangles.
3. **Distinct-core capacity.** Core enumeration pushed one candidate per active
   32-cell activity block and deduplicated only after the capacity check. A
   64-cell core therefore counted up to four times. At 2048×1024 with heavy
   activity, the workbench World failed on tick 1 with "active scheduling-core
   capacity exhausted": up to 2,048 block candidates against a capacity of
   1,024, although only 512 distinct cores exist.

   Candidates are now checked against the entries already recorded for the same
   chunk before the capacity check. The final sort/unique still removes any
   cross-chunk duplicate. The scheduled core set, and therefore every cell
   result, is unchanged. Only the spurious exhaustion is gone. A 4-core capacity
   now admits 16 active blocks in 4 cores, and a fifth distinct core still
   fails.
4. **Per-tick MicroScenario summary copy.** The workbench worker publishes
   `MicroScenarioHost.summary()` with every snapshot. The summary deep-copied
   the install-time pair inspection: N(N+1)/2 records for N present materials,
   which is 1,540 for stress-canvas. It also deep-copied the interaction-profile
   arrays. This cost 23.4 ms per publication on the worker and about 6 ms of
   main-thread consumption. Both are now frozen once at install (a recursively
   read-only copy) and shared. The values are unchanged, and consumers that
   copy them still receive writable copies.

## Identity

- Source: #406 `claude/water-ballistic-hybrid` at `6f719f04` plus this change.
  The workbench measurements used the local DLL
  `fa2205d0b949be818b79c0088605f2cb61ffbb0b5ed9931ea1504e169fba92c9`
  (LLVM-MinGW 20260826 / Clang 23.1.0, with the distinct-core correction). It is
  not a published runtime.
- Machine: 12 logical CPUs (6 native workers), TITAN RTX, Godot 4.7-stable,
  1920×1080 window. The WSL Ubuntu 24.04 build used g++ 13.3.0 and `perf`.
- The scratch scripts were not committed:
  - a native bench that replays the canvas's merged rectangles with
    `World::set`, so Water uses the default kernel rather than the workbench
    FreeMass policy;
  - a workbench driver;
  - stage timers inserted into a scratch project copy's `main.gd` and
    `simulation_worker.gd`.

## Measurements

### Native `World::tick` (6 workers, 64-cell cores, 1,800 ticks)

| Window | Mean | Max | Scheduled cores | Active blocks | Visited cells |
|---|---|---|---|---|---|
| ticks 1–180 | 8.59 ms | 10.61 ms | 292 | 1,013 | 403,274 |
| ticks 721–900 | 13.26 ms | 15.77 ms | 441 | 1,560 | 431,124 |
| ticks 1,621–1,800 | 15.07 ms | 22.57 ms | 599 | 2,144 | 428,516 |

The overall mean is 12.90 ms (Clang) and 13.99 ms (g++). The final
`state_hash`/`physical_state_hash` are `6f280206c9ae8fc3`/`d1449e4958df35df`
under both compilers. Cost rises with scheduled cores while visited cells stay
flat, as smoke and steam spread activity.

The g++ `perf` leaf profile is flat:

| Leaf (inlined) | Share |
|---|---|
| `find_chunk` | 14.1% |
| `address` | 8.6% |
| `get` | 6.7% |
| `PrecisionStorage` loads | 8.9% |
| `stored_material` | 3.0% |
| `schedule_pending_reaction_wake` + `may_pair_react` | 7.6% |
| `update_rule_kernel` | 5.8% |
| `rule_is_active` | 4.0% |
| `scan_rect` | 3.8% |
| `try_move` | 3.8% |

Roughly 40% of the time is the per-neighbour coordinate → chunk → cell read.

### Workbench (20–30 s, still camera, default liquids, 64-cell cores)

| Build | Ticks/s | FPS | Native tick | Worker publish | Rapier waits on sample |
|---|---|---|---|---|---|
| Before the summary fix | 10.0–11.8 | 52–56 | 12.7–15.2 ms | 32.2 ms | 488 of 607 physics frames |
| After the summary fix | 28.2 | 60.0 | 14.0 ms | 1.5 ms | 582 of 1,207 |

Fine cores did not help (10.1 ticks/s before the fix).

After the fix the per-tick worker chain is:

| Stage | Mean |
|---|---|
| Native tick | 14.0 ms |
| Hard-surface chunk packet | 5.4 ms |
| Render snapshot | 3.0 ms |
| Publication | 1.5 ms |

Each tick then waits for the next 60 Hz physics frame. Main-thread
`consume_worker_snapshot` fell from 7.5 ms to 1.2 ms. Rapier stepping is
0.54 ms and hard-terrain installation 0.61 ms.

## Verification

- A native regression, `Active-core capacity counts distinct cores`, fails on
  the previous `world.cpp` and passes now. The native `tests` binary passes 185
  tests (Windows `-O2`).
- `test_workbench_canvas.gd` (160 checks, 0 failures) adds:
  - merged-rectangle exactness against an independent stamp raster for
    my-canvas, bench-canvas, stress-canvas and mixed disc/box stamps;
  - refusal of malformed boxes and of staged-only brush materials;
  - a stress-canvas load with eight barrels, every staged material painted, and
    90 simulated ticks.

- Nineteen Godot regressions pass on that DLL:
  - workbench: canvas, physics play, input, desktop interest, failure recovery
    and live liquid edit;
  - MicroScenario: `test_microscenarios`, workbench, workbench lifecycle and
    native observation;
  - pressure reference;
  - the capacity-one forced-failure tests: `test_lcb_negative_contracts`,
    `test_liquid_ordinary_demo_host`, `test_tick_failure_regression` and
    PLAY-LIFE005/007/008.
- **Negative-fixture correction.** PLAY-LIFE005 injected its capacity failure
  with two Sand points in two activity blocks of the *same* 64-cell core, inside
  a fixed interest region of exactly that core. Under distinct-core counting,
  that fixture can no longer exhaust capacity one, and the test failed
  ("Main consumes the actual native scheduling-capacity failure").

  The fixture now uses a two-core interest region (`[0,0,128,64]`) and puts the
  second point in the second core, (84,20). It again observes the real native
  `active scheduling-core capacity exhausted` failure, with all 30 assertions
  passing. No assertion was removed or relaxed.

## Protected-source transition (proposed)

This is a behaviour-preserving, execution-only edit to the core-candidate
capacity check. Cell results, hashes and the scheduled core set are unchanged;
the change only removes spurious exhaustion. It is proposed as a reviewed
transition for issue 362 and PR 406, pending independent review and the owner's
admission. The source edit and this record are commit `5fbf0a39c43a234fec2c092d52ea43066bf49335`, to which
the transition is pinned.

| Path | From LF SHA-256 | To LF SHA-256 |
|---|---|---|
| `native/src/world.cpp` | `a69a70332450ed246753457f85fcedfa0e3a36e848486e12c441a059c3574d1e` | `3c90c5887800f75936a3e75c57030dcf4c7809640652ea2fc03f3e6b597ab654` |

## Next investigations

1. **Hard-surface packet (5.4 ms per tick).**
   `get_hard_surface_chunk_rectangles` re-projects every cell and rebuilds all
   512 collision chunks with hash maps on each revision. Reacting terrain bumps
   the revision every tick. Rebuilding only the chunks dirtied since the
   previous revision is the largest remaining workbench cost outside the
   native tick.
2. **Neighbour reads (~40% of the native tick).** A chunk-local fast path that
   reads in-chunk neighbours by index offset would remove most `find_chunk` and
   `address` work. It must stay exact.
3. **Pair-reaction wake scheduling (7.6%).** It re-reads neighbours that the
   kernel has just read.
4. **Activity growth.** Smoke/steam spread doubles the scheduled cores over
   1,800 ticks. Gas dissipation and sleep behaviour set the long-run cost.
5. **Render snapshot (3.0 ms) and pipelining.** The lock-step serialises the
   worker chain and the physics frame. Tick rate is bounded by the native tick
   plus packets, rounded up to the next physics frame.

## Gaps

- One machine (Windows and WSL); no Web build, CI timing or published runtime
  containing these changes.
- The native bench uses the default Water kernel, not the workbench FreeMass
  policy.
- `Performance.TIME_PROCESS` reported 25–50 ms means with spikes of up to
  275 ms while frames held 52–60 fps. That monitor was not reconciled with the
  stage timers.
- There is no human gameplay acceptance.
