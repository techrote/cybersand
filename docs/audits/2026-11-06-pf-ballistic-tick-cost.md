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

## Gas-off pass

This second pass uses the same configuration with PressureFlow gas off.
my-canvas and bench-canvas already held 60 ticks/s, so the target was
stress-canvas. On the native bench, its gas-off tick is 17.1 ms without ballistic
Water or diagnostics, against 10.0 ms for default liquids. That ~7 ms of
PressureFlow cost is about 4 ms of head preparation (column pass 2.9 ms, row pass
1.3 ms) and about 3 ms of kernel. Ballistic Water and diagnostics add roughly
1–1.5 ms each.

**Findings:**

- **Dormant falls back to the full reference recompute.** On stress-canvas,
  88% of ticks take the full reference head recompute
  (`reference_fallbacks 0.877` per tick). The repair estimate adds the whole
  resident area once anything is dirty, and that exceeds the 4 Mi-cell
  `head_repair_cell_budget`.
- **Raising the budget would not help.** About 2,039 of 2,048 columns are dirty
  every tick. bench-canvas and my-canvas show the same pattern (979/1,024 and
  457/512), because any cell change in a column dirties the whole column.
- **Face release dominated ballistic Water.** On stress-canvas, ballistic advance
  cost 1.6–1.9 ms per tick, serially, with only 74 live parcels. Almost all of it
  was the face-release scan visiting every cell of about 2,100 active blocks.

**One exact change kept: a pooled face-release pre-pass.** One task per listed
chunk records which activity blocks hold any Water. The serial scan skips the
others. It covers every block of each chunk, because a launch may wake a block
that was asleep. A launch only lowers its own Water source cell and never writes
Water elsewhere, so a block without Water before the pass stays without it and
its scan could release nothing. The pool is used only from 32 listed chunks,
because on my-canvas the dispatch cost more than the scan.

A new native regression, `BW-001 ballistic Water face release pooled pre-pass
matches serial`, uses 160 small chunks, Water walls, Water-free sand and
sleeping blocks. Comparing 1 and 4 workers for FreeMass and PressureFlow, it
checks the physical hash, face releases and launches. A scratch probe confirmed
the pooled pass runs (35–39 listed chunks).

| Measurement (native, 6 workers) | Before | After |
|---|---|---|
| stress-canvas ballistic advance | 1.94 ms | 0.91 ms |
| stress-canvas tick | 21.4 ms | 18.7 ms (noisy) |
| bench-canvas ballistic advance | 0.37 ms | 0.27 ms |

Final hashes are identical (stress `3e8732d482c0a918`, bench
`1c0c3766bacae13e`, my-canvas `3a85b92b27334f9b`).

**Workbench, DLL `85b08402`, gas off:**

| Canvas | Native tick | Ticks/s |
|---|---|---|
| stress-canvas | 22.5–23.2 ms (was 24.7 ms) | 18.4–18.7 (unchanged) |
| bench-canvas | 6.58 ms | 59.3 |
| my-canvas | 4.15 ms | 59.7 |

stress-canvas is now bounded by its per-tick worker chain: the native tick plus
the hard-surface packet (6.4–6.7 ms), render snapshot (3.2–3.3 ms) and
publication (2.9–3.1 ms), aligned to physics frames.

**Two trials measured and rejected:**

- Walking head columns in batches of eight, for cache-line reuse. Heads went
  from 4.1 to 5.1–5.6 ms.
- A last-slot hint in the diagnostic histogram. There was no measurable change
  beyond run-to-run noise of about ±1.5 ms.

The source edit is commit `481011090a9a56fb06311144b5bfb26f8f1028a4`. It changes `native/src/world.cpp` from LF
SHA-256 `97e605b556c178f6169c1c89fff49041d5640b8fb0f728a6fc3d6c43506f4f00` to
`5f510058ae43c8dcf6adc2df62b7fde580d5f509012c8c7a358a54f2a7dc2129`. This is a
proposed reviewed transition for issue 362 and PR 406, pending review and the
owner's admission.

**Checks:** 186 native tests pass (Windows), and ASan/UBSan pass the full suite.
TSan is clean for worker parity, determinism, Workbench parallel, BW-001,
explosion and phased. The same ten Godot regressions pass on DLL `85b08402`.

## Incremental collider packet

`CyberNativeCellWorld::get_hard_surface_chunk_rectangles` rebuilt every 64×64
collision chunk on each hard-surface revision. Reacting terrain bumps the
revision every tick. A temporary probe on stress-canvas, gas off, measured an
average of 2.55 ms projecting the dithered display cells and 4.61 ms building
the rectangles, about 7.2 ms in total. The build cost comes from an out-of-line
`is_hard_surface` call per cell and hash maps on every row.

**Change:**

1. A new World method, `copy_hard_surface_bits`, writes a one-bit-per-cell
   hard-surface mask from stored materials through a 256-entry table. The
   display projection's dithering and parcel overlay only exchange Water and
   Empty, neither of which is a hard surface, so the mask equals
   `is_hard_surface` of the projection cell by cell.
2. The adapter keeps the previous mask and each chunk's rectangles. A chunk's
   rectangles depend only on its own 64×64 block, so an unchanged block reuses
   its cached rectangles. A changed block is rebuilt from its bits with the same
   run-merge rule and final sort. The packet layout is unchanged.
3. Two diagnostics are added:
   - `diagnostic_full_hard_surface_chunk_rectangles`, the previous full build;
   - `diagnostic_hard_surface_packet_stats`, rebuilt and reused chunk counts.

**Exactness:**

- `Hard-surface bits match the display projection` (native) checks every
  material id, dithered fractional Water and non-resident chunks, and the
  refusal of regions whose width is not a multiple of 64.
- `test_hard_surface_incremental_packet.gd` compares the incremental packet
  with the full rebuild after each of 90 ticks of paint, erasure, Fire on Wood,
  Lava on Glass and Acid on Metal. It records 183 checks, 0 failures, 685 chunks
  rebuilt and 22,611 reused.
- The existing `test_liquid_physical_preparation.gd` check that pending and
  applied terrain projections agree exactly still passes. So do 14 other
  terrain, Rapier and workbench regressions.

The source edit is commit `0b408ae97c061d7263a3322022429aa32a0385a6`. It adds a read-only World accessor and
changes `native/src/world.cpp` from LF SHA-256
`5f510058ae43c8dcf6adc2df62b7fde580d5f509012c8c7a358a54f2a7dc2129` to
`5a9de5e09a8665392677902ab501696aafefb5bbd2d2800e3dc1059b87a6f17d`. This is a
proposed reviewed transition for issue 362 and PR 406, pending review and the
owner's admission.

**Workbench measurements:**

| Canvas | Packet before | Packet after | Ticks/s |
|---|---|---|---|
| stress-canvas, gas off | 6.4–6.7 ms | 1.8–2.0 ms | 18.4–18.7 → 19.4–20.7 |
| bench-canvas | 1.3–1.5 ms | 0.35–0.39 ms | |

stress-canvas remains bound by its 23 ms native tick. In this session,
bench-canvas with gas on measured 44.8 ticks/s at an 11.3 ms native tick,
against an earlier 9.9 ms run. That native difference is machine variance,
since the packet only shrank. The remaining stress-canvas packet time is the
serial mask copy of about 2 Mi cells.

## Runtime publication (request 3)

The owner approved this on 2026-11-06. Request sequence 3 (`7fab79ba`) armed the
unchanged branch-scoped publisher. Run
[42240246100](https://github.com/techrote/cybersand/actions/runs/42240246100)
(attempt 1, 15:08–15:21 UTC) passed every job:

- the publisher guards;
- admission;
- the four native groups;
- the Linux build and execution;
- the Windows cross-build and Windows execution;
- publication.

Bot commit `77d9e4a0` appended only the four runtime/manifest paths.

| Runtime | SHA-256 | Bytes |
|---|---|---|
| `cybersand_native.windows.x86_64.dll` | `584675c7c092acb2db6e944052a902887d8075436a6daaa57fd330df3cee1d87` | 5,058,560 |
| `libcybersand_native.linux.x86_64.so` | `55478bb8f027d2005fddf447ed378be8e72d4bf0326c111d99b1e09421ec82fb` | 4,503,248 |

The toolchains are LLVM-MinGW 20260826 / Clang 23.1.0 and g++-13 13.3.0. After
the append, `check_repository.py` reports no errors locally. The full ready-head
CI remains a separate gate.

## Gas law: sealing from the open air

The owner observed this while play-testing my-canvas: trapped air was respected
in a cup that never held Water, but not in an arch that started partly full of
painted Water.

**Probe findings:**

- The behaviour is the same with `reference` and without ballistic Water, so it
  is the PressureFlow gas model, not `cached_dormant` or ballistic Water.
- Kernel-vacated cells are labelled vacuum, and labelling of open regions is
  bounded. So a region open to the air can keep vacuum cells. When it seals,
  its compartment counted only unresolved and atmosphere cells as gas.
- In a drained 40×40 chamber, plugged and then touched by Water, the
  compartment sealed with amount 1,489 for volume 1,496, gauge −38.
- An inverted cup sealed by a pool while still holding Water keeps that Water
  up (gauge about −300 to −650). That is correct physics and is unchanged.
- A chamber larger than `kCompartmentVolumeLimit` is always atmosphere.

**Rule (owner approved 2026-11-06):** a region with no prior compartment but
some atmosphere-labelled cells seals with amount = volume, which is
atmospheric, gauge 0. Water-born voids without atmosphere cells keep the vacuum
rule, and the continue, merge, split, vent and collapse paths are unchanged.

**Checks:**

- The new native regression passes, and fails on the previous rule.
- 188 native tests pass.
- Ten Godot regressions pass unchanged on DLL `86bb4c72` (pressure reference
  and optimization, Rapier pressure, solver policy, policy worker, retained
  pressure, LCB physics contracts, scenario catalogue, WEX-001 and Water Feel).
  No pinned baseline moved.

This is a gas-law change on the experimental branch. It is not
behaviour-preserving, and its protected-source transition is recorded as such.

The source edit is commit `a2373e12fb87d8d5b28efcc6037316fb6f605a14`, and the transition is pinned to it.
`native/src/world_pressure.inc` changes from LF SHA-256 `894068b587b17b215c993d0eea5c5f14a8a818d4c1430c246f13bdec66653738` to `26051b0d10ab10d65db822c993742e0a0bf13711f3bd56158e95d77735737aca`. The
owner approved the rule, and the transition is proposed for issue 362 and PR
406, pending independent review.

## Runtime publication (request 4)

The owner approved this on 2026-11-06. Request sequence 4 (`29310b35`) armed the
unchanged branch-scoped publisher, from a source that includes the
sealed-from-open gas rule, the spray re-send and paint compaction. Run
[42271884078](https://github.com/techrote/cybersand/actions/runs/42271884078)
(attempt 1, 18:34–18:51 UTC) passed every job:

- the publisher guards;
- admission;
- the four native groups;
- the Linux build and execution;
- the Windows cross-build and Windows execution;
- publication.

Bot commit `d8c314d7` appended only the four runtime/manifest paths.

| Runtime | SHA-256 | Bytes |
|---|---|---|
| `cybersand_native.windows.x86_64.dll` | `391e7387c3c02f1c46ab4f4b3116edebed2ec12802a1852da2ff871dfa1fceef` | 5,058,560 |
| `libcybersand_native.linux.x86_64.so` | `f47c0d6313bd6aa79767d2683c9273172822e6a04220a7a609f4c6d85dfb96a4` | 4,503,256 |

After the append, `check_repository.py` reports no errors locally. The full
ready-head CI remains a separate gate.

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
4. The hard-surface packet is now incremental (see above). The render
   snapshot (about 3.3 ms) and publication (about 1.9 ms) on stress-canvas
   remain. A parallel or dirty-tracked mask copy could take the remaining
   packet time below 1 ms.
5. A provably exact skip of Water-free head columns (about 40–47% of columns at
   the start on these canvases) could save about 1 ms on stress-canvas. It needs
   a per-column record that the previous heads are all `kNoHead`, and was not
   attempted.

## Gaps

- One machine; no Web build, CI timing or published runtime containing these
  changes.
- The native bench has no bodies or impact spray; the workbench rows include
  them.
- There is no human gameplay acceptance.
