# Rejected experiment: paired column scheduling

**Decision: do not integrate C2.** Correctness held in the tested cases, but the intervention did not demonstrate useful performance.

| Run order | Source | Column wall mean over first 144 native ticks | Native tick p50 | Native tick p95 | Native maximum |
|---|---|---:|---:|---:|---:|
| 0 | C2 | 72.435 ms | 154.076 ms | 200.798 ms | 221.396 ms |
| 1 | C1_adjacent_control | 60.891 ms | 136.085 ms | 147.353 ms | 182.642 ms |

C2 took 72.435 ms per native tick in the column stage, versus 60.891 ms for the immediately following C1 control. Earlier balanced C1 repeats were 57.682 and 52.201 ms. Unchanged flux/apply stages also slowed, so this brief sequence cannot isolate a precise treatment effect from environment variance. It provides no basis for adopting the change.

Both runs passed exact fixture, current two-round Wave/spill/ballistic settings, four participating workers, native sample/terrain/input/Water accounting and genuine callback-credit checks. Their first 144 actor trajectories and admitted moves match. Separate native tests reported identical live physical-state and inventory checkpoints across D0/C1/C2. None of those correctness results establish improved timing.

The frozen graphical validator refuses both headless captures. Retain the original raw outputs and exact C2 runtime; continue with diagnostic column subphase timing instead of expanding this unfavorable experiment into a broad campaign.
