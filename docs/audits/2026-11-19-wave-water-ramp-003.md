---
title: Horizontal Water spread and returning crests on the owner ramp
status: Current
document-kind: audit
scope: Water ramp and tank measurements, player defaults, evaluated runtime and platform qualifications on the branch above PR 676
last-reviewed: 2026-11-19
related-documents: [../architecture/wave-flow-v1.md, ../operations/workbench-water-lab.md, 2026-11-19-wave-waterwall-002.md]
---

# Water ramp, 19 November 2026

The owner selected Wave Flow, waterfall spill and ballistic release for new player sessions. The parent for this evaluation is [Waterwall 002](https://github.com/techrote/cybersand/pull/676) at `57de8e73f93f10e63761b7e8d2430ddafcb970cb`. Its recommended Sloshy + Max over-ledge bundle is the comparison setting.

## Authored ramp

The supplied file is an ordinary 2,048 × 2,048 Workbench setup v2 with 635 rectangle edits and no actors or sources. Its SHA-256 is `7aba8a47c926cc1911bc4ee519179c595b686692d5c78db8f103b8b62d311acb`. Two suspended bodies start with 9,773,895 units of Water in 38,329 cells. The lower body ends at x738 above a long shallow trough that first rises and then falls. The parent Windows Workbench loaded the named setup through its ordinary Load action and conserved the initial quantity at ticks 0, 100, 300 and 600.

## Selected player settings

Use the **Gameplay default** profile on this branch. It requests two Wave rounds per native tick, Gain 256, Deep gain 48, flux smoothing 12, Coast 127, Empty pour shift 1, damping shift 16, calm damping shift 8, Calm and Stick 128, and sleep after 90. Spill and release are active with blobs, sheet rate 64, four coyote ticks, fall 8, draw 127, draw head 65,535 and a 128-parcel launch budget. The normal Ballistic Water owner still handles spray and jets. Water Lab keeps all numeric edits staged until Apply. Sloshy and Max over-ledge can reproduce the previous recommendation.

| Six workers, same initial conditions | #676 Sloshy + Max, one round | Faster tuning, one round | Faster tuning, two rounds |
|---|---:|---:|---:|
| Continuous two-cell-deep front reaches x900 | 504 ticks | 440 ticks | 224 ticks |
| 128 full cells of floor-attached Water beyond x960 | 728 ticks | 664 ticks | 344 ticks |
| Previous waterwall half-empty | 388 ticks | 558 ticks | 287 ticks |
| Previous waterwall full cells remaining at t900 | 236 | 959 | 317 |
| Previous waterwall thrown units through t1500 | 8.16 million | 7.24 million | 6.58 million |

Matched two-round Sloshy reached x900 at tick 248. Running a second round accounts for most of the faster horizontal travel. At the same round count, the faster tuning advances the coherent front and steepens the returning crest. More throw speed or a larger parcel budget alone did little for the downstream deposit. The old waterwall releases earlier under the new default but leaves a longer tail and throws less spray.

On the 11-row tank with a six-row initial step, the first full crest return took 154 ticks with the new profile and 534 with Sloshy. Crest-to-trough range on the eight-column averaged surface rose from 4.83 to 5.27 cells and the broad slope rose from 0.277 to 0.332. On the 22+10-row tank the return took 112 versus 388 ticks, the range rose from 8.47 to 8.90 and the slope rose from 0.516 to 0.606. Every comparison starts from the same Water and step height within each tank. Higher deep gain caused sharp residual ripples or lost the coherent returning wave near the upper end of the 32-row band. On the deep tank the chosen wave loses a little more height over a second cycle than Sloshy.

The ramp took 4.74–4.88 ms per native tick at the median and 7.42–8.13 ms at p95 with two fast rounds, compared with 2.48–2.51 and 3.69–3.70 ms with one fast round. The desktop simulation targets 60 Hz (16.67 ms per tick). Isolated native ticks reached 19.65–22.54 ms. These are native Worker timings on the owner's host, measured sequentially during a reserved window. The owner's previously open Workbench remained open and lightly active. Rendering, Rapier and end-to-end frame time have separate costs.
