---
title: Waterwall discharge, crest flight and slosh evaluation
status: Current
document-kind: audit
scope: Windows and WSL research evidence for the opt-in Wave Waterwall 002 Draft/HOLD candidate
last-reviewed: 2026-11-19
related-documents: [../architecture/wave-flow-v1.md, ../architecture/ballistic-water-v1.md, ../operations/workbench-water-lab.md]
---

# Waterwall 002 evaluation, 19 November 2026

Draft/HOLD [PR 676](https://github.com/techrote/cybersand/pull/676) starts at
`5c415245b6ccf45168a60f0afb5e3626618795b7`, the final reviewed head of [PR 672](https://github.com/techrote/cybersand/pull/672).
The owner's 1024² generated start has SHA-256 `925096d1e9984b855b5465309ef12869a47e29052e0cabd5a25788a051b77107`.
The GEN-007 terrain has SHA-256 `9b8b4ef6339c4d922c499dd3240198209a8a3cfcca9f9fd49cf1b6fa918f91f5`.
The 166-stamp input used by the native harness has SHA-256 `c2dee3e3562b1369fdab0f3874716539704e5eae5a29951f262a0efc599b2a4e`.
Every map run starts with 3,052,350 units across all reservoirs. The historical lower-reservoir probe
is the half-open rectangle `440,540,192,102` and starts with 5,928 full-cell equivalents.

## Protected source review

The chunk constructor reserves a previous-flux field when smoothing is enabled.
The Wave physical hash incorporates the selected nonzero parameters and the live crest flight counters.
Neither change affects the material catalogue or an authored material transition.

| Protected source | Previous LF SHA-256 | Current LF SHA-256 | Source-first commit |
|---|---|---|---|
| `native/src/world.cpp` | `80e05f673b3d6ba35daa7c741805aa272f149e7742d162c94c8c0bd9bdbc1e83` | `fef05d7f0318f0a54948144ee22f30721555a567ac3963309c927b60fbfb0cf0` | `d876bd57897dd421b720e73d15d7c89a830b4896` |
| `native/src/world_pressure.inc` | `c5d639212290c9a4faee47f86a3cfe5bf664a5a51d241d4b5c9c1cdb985b6105` | `bce02406c837967e95206ea6f6e93145b2b327a1d42e3e6e29da9d3507603d03` | `d876bd57897dd421b720e73d15d7c89a830b4896` |
| `native/src/world_pressure.inc` (Workbench Apply) | `bce02406c837967e95206ea6f6e93145b2b327a1d42e3e6e29da9d3507603d03` | `0e012c7f2944cf8d5f9d8aa383e8635bbbd313d26fc5079160a02d5f4e1e3a0f` | `d4df71fc6bc1bf6267270a4c1445207a02716317` |

## Tank waves and spreading

The closed tank is 64 cells across, with 11 rows of Water on the right and 17 on
the left. The open version has a right lip one cell above the lower initial
surface and catches the overflow below. The blob starts twelve cells wide and
six tall, four cells above a flat floor. Each run used six workers and one
substep. Every sampled grid-plus-flight total matched its initial quantity.

| Fixture and measure | Default | Owner slow | Sloshy |
|---|---:|---:|---:|
| Closed tank, mean period (ticks) | 394 | 484 | 536 |
| Closed tank, amplitude after two periods (cells, starts at 3.82) | 0.14 | 1.64 | 2.07 |
| Closed tank, amplitude lost per period | 80.9% | 34.5% | 26.4% |
| Closed tank, short-ripple curvature (cells) | 0.169 | 0.460 | 0.075 |
| Open tank, mean period (ticks) | 404 | 500 | 582 |
| Open tank, amplitude after two periods (cells) | 0.13 | 0.25 | 0.42 |
| Open tank, amplitude lost per period, including overflow | 81.3% | 74.6% | 66.7% |
| Open tank, short-ripple curvature (cells) | 0.163 | 0.407 | 0.073 |
| Blob right edge at t20 / 40 / 80 / 120 / 160, starts at x69 | 74 / 77 / 82 / 85 / 89 | 74 / 78 / 83 / 87 / 91 | 75 / 78 / 84 / 89 / 94 |

Column depth is the exact grid quantity above the tank floor divided by 255.
The long wave is the signed first cosine mode of those depths. The reducer
finds a peak per signed excursion above 0.04 cells, uses the first two full
oscillations for the mean period and takes the geometric mean of their amplitude
ratios. Curvature is the RMS of the horizontal second difference, averaged over
samples from t20 to t300. A blob column must hold at least 32 units to count
toward its front. The owner's slower hand-tuning also outspread default on this
particular drop. The Sloshy preset went further at every reported checkpoint.

![Measured broad-wave amplitude, short-ripple curvature and blob front](wave-waterwall-002-2026-11-19/slosh-and-spread.png)

The gain split and smoothing work independently. Both remain zero in historical
profiles. During screening a four-row active band lengthened the first return
to 656 ticks, with only 1.29 cells of amplitude left. At deep gain 16, increasing
smoothing from 16 to 24 lowered curvature from 0.075 to 0.059 but also reduced
retention per period from 73.6% to 72.6%. The selected setting spends less of
the broad wave on smoothing. Sloshy sets ordinary gain 32, deep gain 16, flux
smoothing 16, damping shift 16, coast 64, level shift 3, calm damping shift 8,
calm flux and stick 128, and sleep after 90. Other Wave controls start from
their ordinary defaults.

### Crest flight at the open tank lip

With Sloshy and Max over-ledge together, a probe four cells beyond the lip
recorded the following through t560. The probe covers x85..116, y32..43, above
the top of the wall at x81, y44. The unit-tick integral measures the amount of
airborne Water at that height across successive ticks.

| Coyote ticks | First airborne Water in probe | Peak airborne units | Airborne unit-ticks | Parcels / units thrown | Peak live |
|---|---:|---:|---:|---:|---:|
| 0 | None | 0 | 0 | 570 / 46,236 | 92 |
| 4 | t146 | 597 | 90,259 | 553 / 44,537 | 99 |

Both runs launched from the lip by t140, conserved all Water, and recorded zero
launch refusals, capacity skips and deferrals. The ordinary closed-tank and
open-tank swing measurements above use spill off.

### Reproduction and source identity

These eleven runs and the normal Wave suite used a fresh archive of source
`d4df71fc6bc1bf6267270a4c1445207a02716317`. WSL2 Ubuntu 24.04 g++ 13.3.0 built
the apparatus with `-O3 -DNDEBUG -pthread` and the native Wave suite with
`-O2 -g -pthread`. Wave passed 33/33, including the independent alternating-ripple
energy test, shallow-front invariance, extreme tuning, paused-face and worker
parity cases. The apparatus SHA-256 was
`2784d7f099e7e78caf3597aa88c50f5a17bc2c4709f9259b0878f44fe11215b1` and the
test executable SHA-256 was
`7b8bd16b5e45ed49930b267ebc06cfa43b9817a3f40093ef4654eb421aac3963`.

```sh
make wave-waterwall wave-flow-test
# For each profile run tank, tank_open (2200 ticks) and blob (240 ticks).
# Append the selected profile's keys. Use no extra keys for default.
timeout 180 build/wave_waterwall tank size=128 ticks=2200 every=4 workers=6 > tank.log
python3 tools/wave_mt/reduce_slosh.py tank.log
# Owner slow
# gain=20 damp_shift=10 coast=48 level_shift=5 calm_damp_shift=6 calm=128 stick=128 sleep_after=90
# Sloshy
# gain=32 deep_gain=16 flux_smoothing=16 damp_shift=16 coast=64 level_shift=3 calm_damp_shift=8 calm=128 stick=128 sleep_after=90
# The lip pair uses tank_open, ticks=560, every=1, the Sloshy keys, and:
# spill=1 ballistic=1 sheet_rate=64 draw=127 draw_head=65535 fall=8 launch_budget=128 catch=1
# coyote_ticks=0 or 4 hydrograph=lip.csv source_box=85,32,32,12 stream_box=82,32,32,12
```

[Per-sample numerical profiles](wave-waterwall-002-2026-11-19/slosh-profiles.csv)
and [fixture results and output hashes](wave-waterwall-002-2026-11-19/slosh-results.json)
retain the numerical evidence. These runs measure simulated motion. The isolated
map timing campaign supplies the tick-cost comparison.

## Independent native review

The reviewer inspected both halves of the face budget, signed arithmetic, optional scratch lifetimes, paused neighbors, generic launches, capacity and physical persistence. Two blocking cases were fixed in `d4df71fc` and independently rerun against the resulting binary.

| Reproduced issue | Repair and verification |
|---|---|
| Workbench Apply carried live crest grace into a replacement that could no longer hash or save it. | Inherited parcels retain their quantity and velocity. Remaining grace is clamped to the receiving law. The native test converts into generic Ballistic, Wave without spill and a shorter two-tick grace. One more tick after generic save/restore produces the same physical hash. |
| A static positive head could fail to start an exposed sheet with ordinary Gain zero. | The open-face test can start from the head direction. In the `falls` fixture at tick 60, sheet 127 put 191.9 cell-equivalents into the air. With sheet off, all 13,200 stayed on the platform. Both conserved Water. The focused suite also checks a blocked side. |

The reviewer ran `test_wave_spill --filter 'crest Apply'` (1/1) and `--filter sheet` (3/3). The release binary had SHA-256 `703a1635d9b194bf32d5768cee105c1f8336877fefdf01d5eb1d7bd269e9a1c9`. Their independent saturated nine-slot tank at 1, 2, 3, 6 and 8 workers produced hash `8d1a52e335f20113`, zero drift, 71 launches, 2,269 deferrals and 104 capacity skips at 160 ticks on the pre-fix prototype. The two follow-up fixes and their new witnesses passed the independent source recheck.

For the odd-mass ridge, the test totals each side's landed sheet plus that side's launched parcel before the next round. Each side can use at most half the donor. Two sides cannot overdraw it even if Stream share and Stream draw are both 255. At a full half-face reservation a new crest throw leaves no allowance for an extra grid pour. The eight-worker saturated run and the 31-case spill suite cover different failure modes.

## Design choices

- **Keep grid sheets with crest spray.** A deep row can use the existing falling column, while the top retains visible throws. The pool stays at 4,096 slots. Raising its cap would spend more CPU on parcel flight. The earlier grid-only, hybrid, Stream draw, sheet-only and tuned bundles are compared below. Set Sheet rate to zero to restore the older face policy.
- **Give only the crest a few level ticks.** The existing bounded parcel owner already accounts for movement, wall contact, pauses, landing and capacity. A separate grid overhang would need horizontal per-cell age and direction plus multi-face conflict resolution. That alternative and a separate run-length sheet owner were considered at design level. Neither has a measured implementation here. Set Coyote ticks to zero to use ordinary thrown arcs.
- **Limit the refill work.** In the one-round exploratory screen a local wet-to-wet feed extension changed the reservoir from 684 to 669 cell-equivalents at t900. Extending it four cells gave 717. Applying a head floor everywhere gave 234 but increased moved mass from 55 million to 470 million units; under ordinary tuning it worsened drainage from 1,176 to 1,815. These discarded variants were scratch builds. Their runs were for movement only.
- **Keep spreading independent of the deep-water setting.** Sloshy retains normal Gain 32 and reduces the restoring gain for deep columns. The smoothing strength was selected against actual curvature and retained oscillation. An existing Wave preset restores the previous tuning. Max over-ledge stages only spill controls, so the two bundles can be evaluated independently.


## Reservoir and tall-face discharge

In the first quiet run Max over-ledge used one round, six workers, Sheet rate 64,
Coyote ticks 4, Fall 8, Pool feed 127, Feed head limit 65,535 and a launch budget of 128.
Blobs were on. Stream share and Stream draw were zero. Each figure below compares fresh Worlds,
on the same machine, for 1,500 ticks. A separate instrumented pass computed net flux including
parcels inside the probe. The continuity window was 24 rows high, sampled each tick from 60 to 300.
A dry grid row may still contain airborne spray.

| Map mode | Mean net units/tick, first 300 | Peak | Half-empty tick | Grid cells t900 | Mean dry rows | Thrown units | Peak live | Median / p95 ms |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Original Wave | 636 | 1,070 | 1,378 | 3,824 | 0 | 0 | 0 | 2.75 / 5.05 |
| #672 hybrid | 1,878 | 3,942 | 453 | 1,497 | 13.66 | 8,749,479 | 3,510 | 3.87 / 5.91 |
| Stream draw 128 | 1,609 | 2,179 | 495 | 1,577 | 0 | 7,527,042 | 2,327 | 3.68 / 4.73 |
| Sheet rate 64 alone with release | 1,461 | 1,821 | 549 | 1,760 | 0 | 6,295,985 | 2,213 | 3.49 / 5.27 |
| Four coyote ticks alone with release | 1,945 | 4,369 | 441 | 1,474 | 13.83 | 8,545,138 | 3,780 | 3.51 / 4.41 |
| Max over-ledge | 2,115 | 3,374 | 369 | 902 | 0 | 6,265,581 | 2,324 | 3.66 / 4.59 |

On the 60-row platform fixture, the #672 hybrid and Max reached half-empty at 986 and
905 ticks. Their first-300 means were 2,244 and 2,197 units/tick, and both peaked at
7,608 units/tick. The new bundle chiefly improves sustained drainage here. Average dry
rows fell from 23.07 to zero. A vertical column at a particular outlet is a local visual
measure; it does not measure flux across the entire scene.

These sequential timings came from the deep-column prototype before the final static-head and
Apply fixes. The [final-source measurements, captures and qualification](wave-waterwall-002-2026-11-19/qualification.md)
extend this registered record. See that appendix for the combined preset, stream gaps, refusals and deferrals,
timing variation, final machine identities and the owner-local ZIP. The six-worker comparison command was:

```sh
python3 tools/wave_mt/waterwall_discharge.py build/wave_waterwall terrain-1024.bin stamps.txt /tmp/ww002-results \
  --bundle sheet_rate=64 coyote_ticks=4 draw=127 draw_head=65535 fall=8 launch_budget=128
```

The runner times each native tick without profiling, then restarts the same process with a per-tick
source-box and stream-row trace. Each process has a 600-second timeout. Grid plus in-flight drift was zero.
This branch requests source-matched publication on GitHub-hosted Linux and Windows. The PR stays Draft/HOLD for owner evaluation.
