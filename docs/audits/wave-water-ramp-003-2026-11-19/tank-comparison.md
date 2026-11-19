---
title: Returning wave shape and spreading speed on the ramp candidate
status: Current
document-kind: audit
scope: Native tank and blob evidence for the Water ramp 003 settings
last-reviewed: 2026-11-19
related-documents: [../2026-11-19-wave-water-ramp-003.md, ../../architecture/wave-flow-v1.md]
---

# Returning wave shape and spreading speed

In the deep tank, the selected two-round settings shortened the first complete
wave cycle from 388 to 112 ticks. At that return, the broad crest-to-trough
difference grew from 8.47 to 8.90 cells and the steepest broad slope rose by
17%. The lower half of the returning wave dipped deeper. The faster wave also
decayed sooner in elapsed ticks. On a flat floor, the dropped blob reached x100
in 44 ticks, compared with 198 for the previous settings.

![Broad wave, first-return physical Water depths and flat-floor blob front](tank-and-front.png)

All seven settings used Wave, Waterwall spill, Ballistic Water, blobs and the
Max over-ledge bundle. Each tank started with a fixed step on the left side of
a 64-column pool. All settings for a given geometry received the identical
starting cells. The right-edge front of the falling 12×6-cell blob began at
x69. The wall limits that measurement to x127.

| Setting | First return, standard / deep / full active band (ticks) | Returning range, standard / deep (cells) | Returning slope, standard / deep (cells per cell) | Blob at t40 / 80 / 160 (x) |
|---|---:|---:|---:|---:|
| Sloshy + Max, one round | 534 / 388 / 356 | 4.83 / 8.47 | 0.277 / 0.516 | 85 / 87 / 95 |
| Sloshy + Max, two rounds | 268 / 194 / 178 | 4.85 / 8.55 | 0.283 / 0.533 | 88 / 96 / 115 |
| Fast, one round | 308 / 222 / 204 | 5.13 / 8.74 | 0.331 / 0.578 | 85 / 99 / 123 |
| **Fast, two rounds** | **154 / 112 / 102** | **5.27 / 8.90** | **0.332 / 0.606** | **98 / 123 / 127** |

The three initial right-hand depths were 11, 22 and 30 cells, with steps of
6, 10 and 6 cells respectively. The broad range uses the highest and lowest
sliding eight-column mean depth. The steepness is the largest absolute
difference between adjacent eight-column means, divided by eight. These
measures give the width of the crest a role in the score. A single isolated
peak contributes little. The first return is the first positive peak of the
signed fundamental mode after a reversal. The front needs at least 32 units
of landed grid Water in its column. The samples are two ticks apart.

Fast kept the original 32 active rows and used gain 256, deep gain 48, flux
smoothing 12, coast 127 and empty pour shift 1. It retained Sloshy's damp shift
16, calm damp shift 8, calm and stick flux 128, level shift 3 and sleep after
90. Two rounds run the full Wave cycle twice per native tick. The supplied
canvas and the tick-cost comparisons are in the [ramp evaluation](../2026-11-19-wave-water-ramp-003.md).

## Trade-offs and rejected settings

- At the first and second full returns in the deep tank, the signed fundamental
  had amplitudes of 5.20 and 3.56 cells with Fast two-round, compared with 5.06
  and 3.79 for Sloshy one-round. Fast produced a larger first wave and lost more
  amplitude by the second. Curvature RMS averaged 0.141 cells between returns
  against 0.058 for Sloshy and 0.174 for ordinary Wave tuning with Max spill.
- Reducing smoothing to 4 made the one-round Fast deep-tank slope rise from
  0.578 to 0.599. Short-ripple curvature climbed from 0.134 to 0.224 cells,
  exceeding ordinary Wave with Max spill. The selected setting keeps a steeper
  broad wave than Sloshy with fewer short ripples than the sharper alternative.
- Raising deep gain to 96 with smoothing 16 gave a quick 218-tick return on the
  standard tank. On the deeper step, column curvature peaked at 90 cells and
  less than 1,151 of the initial 1,728 cell equivalents remained in the
  tank's grid at one sample. The full world still conserved all Water. Increasing the initial depth exposed an erratic response and ruled out this
  candidate. The different frequency and jagged columns are visible in the
  [recorded trajectories](tank-traces.csv).
- Additional screening covered deep gains 32–384, ordinary gains 32–512,
  16–32 responding rows and smoothing 4–64. Deep gain 56 with smoothing 12
  passed the 22+10 tank but its first return on the 30+6 tank slipped from
  the selected one-round setting's 204 ticks to 682, with a much weaker
  amplitude. A smaller active band also lost a coherent return for some high-gain
  settings on the deeper fixture. On the 22+10 tank,
  changing level shift between 0, 1, 3 and 5 gave the same measured crest at
  gain 256, deep gain 56 and smoothing 12. Changing adhesion between 0, 1 and 6
  affected the floor front by at most one cell at t80. Keeping the ordinary
  level and adhesion settings avoids unnecessary side effects.

## Reproduction

The six-worker panel comprises 21 closed-tank runs of 1,600 ticks and seven
blob runs of 200 ticks. Every sampled total closed exactly across grid and
flight. The plotting profiles report real native column depths rounded to
one tenth of a cell by the apparatus' per-column probes. Range, slope and
curvature use the full-precision quantity sums. The compact trace file
retains every eighth tick. The test checks conservation every second tick.
These runs measure motion. Concurrent activity during screening excludes their
wall-clock timings from the cost comparison.

The apparatus was built at `971846266cb88fe8ff9547c85807249f29c248ef` on WSL2
Ubuntu 24.04, kernel `6.18.58.1-microsoft-standard-WSL2`, using g++ 13.3.0,
`-O3 -DNDEBUG -pthread`. The 74 native source/header, apparatus and Makefile
blobs matched that commit. The executable's SHA-256 was
`d12116c80e0630068265c96acd6bbdaf0419dbff07b206575af6e40627456089`.
Each run used a 180-second timeout.

```sh
make wave-waterwall
python3 tools/wave_mt/ramp_tank.py build/wave_waterwall /tmp/ramp-tank-results
```

The [complete settings and final-state hashes](tank-results.json),
[sampled wave trajectories](tank-traces.csv) and
[column depths at matching wave phases](tank-profiles.csv) retain the evidence.
