---
title: PressureFlow cached_dormant with ballistic Water, face release and impact spray — tick cost
status: Current
document-kind: evidence
scope: 6 November 2026 experimental-branch (#406) evidence for the workbench configuration PressureFlow cached_dormant + ballistic Water + face release + impact spray, the serial gas-topology cost, and three exact speedups (pooled gas seed pre-pass, pooled gas label pass, face-release interior reject); local Windows plus WSL g++, not on main, no default changed
canonical-for: []
last-reviewed: 2026-11-06
related-documents: [2026-11-06-workbench-pf-tick-cost.md, 2026-11-06-stress-canvas.md, ../architecture/pressure-flow-v1.md, ../architecture/ballistic-water-v1.md, ../reference/configuration-reference.md]
---

# PF dormant + ballistic Water tick cost — 6 November 2026

## Result

The configuration is Water PressureFlow `cached_dormant`, with ballistic Water,
face release (the workbench tuning: 320 releases per tick, speed 288, period 1,
minimum height 4) and impact spray all enabled.

**Starting point** (local DLL `fa2205d0`, 64-cell cores):

| Canvas | Gas off | Gas on |
|---|---|---|
| my-canvas | 3.57 ms, 60 ticks/s | 7.37 ms, 60 ticks/s |
| bench-canvas | 6.78 ms, 60 ticks/s | 13.47 ms, **30.5 ticks/s** |
| stress-canvas | 24.7 ms, 18.7 ticks/s | fails |

stress-canvas with gas on fails with the explicit capacity outcome "pressure
gas compartment capacity exhausted".

**Where the time goes** (bench-canvas, gas on). The native bench shows that gas
topology (`resolve_gas_topology`) costs about 4.5 ms of an 11 ms tick, and it
runs serially on the owner thread:

| Phase | Time | Work |
|---|---|---|
| BFS flood | 2.6 ms | 81,562 cells, 317,402 probes |
| Whole-world seed scan | ~1.2 ms | 622,701 cells, 132,737 probes |
| Label pass | 0.49 ms | |
| Compartment reducer | 0.03 ms | |

The gas component cache never engages in this scene: 0 components, 0 reuses, 0
builds. It needs a topology fixed point, and active Water, parcels and face
release change the topology every tick. Ballistic Water itself adds only about
0.3 ms, and physics diagnostics add nothing measurable.

**Three exact changes:**

1. **Pooled gas seed pre-pass** (`world_pressure.inc`, workbench pool only).
   One read-only task per resident chunk marks the cells whose serial seed step
   can do anything:
   - unmasked Water beside an unmasked Empty cell or a non-resident neighbour;
   - Empty with a live compartment label.

   The serial loop then visits only the marked cells, in the original order.
   Any other unmasked Water would make four `seed_needed` probes that are all
   false, whatever the visit stamps or chunk nodes, so it is skipped but its
   four probes are still booked. Every gas counter therefore matches the full
   scan. The path is used only when the gas cache is not ready, because a
   cached replay can request a mid-scan restart. A one-entry chunk-lookup cache
   is also added; no chunk is created or retired during the seed/BFS phase.
2. **Pooled gas label pass.** Each chunk writes only its own labels from the
   now read-only region and compartment tables. The tasks reduce the
   changed-label flag, and `gas_relabel_cells` adds the cell counts exactly as
   before.
3. **Face-release interior reject** (`world_ballistic.inc`). A Water cell
   whose two in-chunk horizontal neighbours are both non-Empty cannot be a
   face, because `open_at` would fail on both sides. It now skips the hash and
   the four map lookups. All of those checks are pure, so the result is
   unchanged.

A fourth trial was measured and **rejected**: a pre-pass bitmap of unmasked
Empty cells for the BFS. It needs a mask check for every Empty cell, which
outweighs what the BFS saves (gas 3.0 → 3.6 ms).

## Identity

- Source: #406 `claude/water-ballistic-hybrid` at `37c49708` plus this change.
  Final local Windows DLL:
  `c9f079d64e9b22b242d0655aa20335ea570473665badf9dd1d2a115ee7f96da6`
  (LLVM-MinGW 20260826 / Clang 23.1.0). This is not a published runtime.
- Machine: 12 logical CPUs (6 native workers), TITAN RTX, Godot 4.7-stable,
  1920×1080. WSL Ubuntu 24.04 with g++ 13.3.0 and `perf`.
- The scratch tools were not committed:
  - a native bench of the workbench World configuration (PressureFlow variant,
    gas, ballistic Water, face tuning, parallel heads, diagnostics) that
    replays a canvas's merged rectangles with `World::set`, so there are no
    bodies and no impact spray;
  - a workbench driver;
  - worker stage timers in a scratch project copy.

## Measurements

The native rows are `World::tick` means over ticks 31–600, with 6 workers and
bench-canvas, gas on and ballistic Water on.

| Build | Mean tick | Gas phase | Final hashes |
|---|---|---|---|
| Before (`37c49708`) | 10.73–10.77 ms | 4.46 ms | `63ce119ac0004618` / `43c89806e35eabcc` |
| Seed pre-pass + label pass | 9.19–9.42 ms | 2.98–3.11 ms | identical |
| + face-release reject (final) | 8.92–9.06 ms | ~3.0 ms | identical |

On my-canvas with gas on, the native tick went from 5.84 to 4.83 ms, with
identical hashes (`637f1a1792550cef` / `a3fce7164bfc64d2`).

The workbench rows use 20 s runs, a still 480×270 camera and spray enabled:

| Canvas | Before | After |
|---|---|---|
| bench-canvas, gas on | 13.47 ms, 30.5 ticks/s | 9.83–9.97 ms, **55.8–57.0 ticks/s** |
| bench-canvas, gas off | 6.78 ms, 59.8 ticks/s | 6.04 ms, 59.6 ticks/s |
| my-canvas, gas on | 7.37 ms, 59.9 ticks/s | 5.95 ms, 59.9 ticks/s |
| my-canvas, gas off | 3.57 ms, 59.9 ticks/s | 3.77 ms, 59.9 ticks/s (noise) |

An earlier bench-canvas gas-on run (11.87 ms, 36.5 ticks/s) is excluded. It
overlapped the WSL sanitizer builds on the same CPUs.

## Exactness

- `Workbench parallel PressureFlow heads match serial (all variants)` now also
  compares every gas work counter between serial and pooled Worlds:
  - seed cells and probes;
  - BFS cells, probes and nodes;
  - relabel cells, identity nodes and restarts;
  - component reuses, member validations and gas reuses.

  Its fixture has sealed gas, transient masks and non-resident chunk gaps
  across signed boundaries. It passes for reference, cached and cached_dormant
  (14,405,631 checks).
- The native `tests` binary passes 185 tests (Windows `-O2`). The full suite
  passes under ASan/UBSan (g++ 13.3.0, WSL). TSan under `setarch -R` reports no
  race in the worker-parity, determinism, Workbench-parallel, pair-table,
  explosion and phased tests.
- Ten Godot regressions pass on DLL `c9f079d6`:
  - `test_lcb_pressure_optimization`, `test_lcb_pressure_reference` and
    `test_liquid_pressure_rapier`;
  - workbench: canvas, physics play, retained pressure, live liquid edit and
    liquid edges;
  - `test_simulation_worker_interest_ownership` and
    `test_microscenario_workbench`.

## Protected-source transitions (proposed)

These are execution-only edits. Cell results, hashes, receipts and pressure
counters are unchanged. They are proposed reviewed transitions for issue 362
and PR 406, pending independent review and the owner's admission. The source edit and this record are commit `fd061dd098d2e4b277141b76ada7f4b340e02e97`, to which
both transitions are pinned.

| Path | From LF SHA-256 | To LF SHA-256 |
|---|---|---|
| `native/src/world.cpp` | `3c90c5887800f75936a3e75c57030dcf4c7809640652ea2fc03f3e6b597ab654` | `97e605b556c178f6169c1c89fff49041d5640b8fb0f728a6fc3d6c43506f4f00` |
| `native/src/world_pressure.inc` | `af5bcaf27e4e7bd17d65279aaddb074359db20ff9c06cb5dfabf1a573e02be18` | `894068b587b17b215c993d0eea5c5f14a8a818d4c1430c246f13bdec66653738` |

## Remaining costs and next investigations

1. **Gas BFS, about 2.4 ms serial.** This bounded atmosphere exploration
   explores 81k cells per tick in about 767 regions. It is inherently serial in
   the current labelling. A cross-tick reuse that is exact outside a fixed
   point would need a new proof.
2. **stress-canvas with gas on fails** because it exceeds
   `PressureFlowParameters::kCompartmentCapacity`. This is a capacity contract
   of the gas model, not a defect in these changes. Raising it is a separate
   PressureFlow decision.
3. **stress-canvas with gas off** costs 24.7 ms with PressureFlow, against
   about 14 ms with default liquids. PressureFlow head preparation and kernels
   at 2048×1024 are the next target.
4. The hard-surface packet (1.3–1.4 ms on bench-canvas) and worker publication
   (~1.1 ms) still lengthen each lock-step tick.

## Gaps

- One machine; no Web build, CI timing or published runtime containing these
  changes.
- The native bench has no bodies or impact spray; the workbench rows include
  them.
- There is no human gameplay acceptance.
