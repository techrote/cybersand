# #18: optional-state allocation and admission preparation

**Analytic storage preparation only.** Existing G-L remains authoritative; no layout candidate, history encoding or motion target is selected. See [programme sources](primary-sources.md).

## Count touched blocks, not only participating cells

For independent per-cell usage probability `p` and an allocation block containing `B` cells, the chance that the block needs allocation is `1-(1-p)^B`. The calculation uses `expm1/log1p` for stable small probabilities. This is an independence model, not a measured CyberSand distribution. Actual Water fronts can be clustered, dispersed, correlated or persistent after motion stops.

The fixed illustrative resident world is 1024x1024 cells, with 32x32 allocation blocks. For a fixed used-cell count `k`, maximally packed usage touches at least `ceil(k/1024)` blocks; maximally dispersed usage can touch `min(k,1024)` blocks. Those bounds and the independent expectation are distinct scenarios, not interchangeable samples from one experiment.

| Per-cell independent usage | Expected touched-block fraction |
|---:|---:|
| 0.01% | about 9.73% |
| 0.1% | about 64.10% |
| 1% | 99.9966% |
| 5% | effectively 100% at the displayed precision |

The complete table retains exact generated values and corresponding packed/dispersed bounds. At approximately 1% use, the rounded 10,486 participating cells can occupy just 11 packed blocks or all 1,024 blocks when dispersed. “Only 1% of cells need history” is therefore insufficient to size a block-allocated sidecar.

## Explicit assumptions, not a measured sizeof

The example reserves two bytes per cell in each allocated block, plus 32 bytes of block header and an eight-byte directory entry for each resident block. The directory is 8,192 bytes even at zero usage. A full set of allocated blocks costs 2,138,112 additional bytes. At the 1% packed bound, the corresponding total is 31,072 bytes. Universal 4-to-8-byte widening adds 4,194,304 bytes in the same resident world, before any other structures.

These are hypothetical allocation footprints. The example sidecar can still use less memory than universal widening even when every block is touched, because its assumed payload is two bytes rather than four additional inline bytes. That does not establish a winner: lookups, object headers, alignment, allocators, cache behavior, read amplification, activity scans, snapshots, transfer logic and reclaimed-block policy are excluded. A spare inline bitfield is a different comparison and must not be charged four bytes automatically.

Temporal locality matters as much as spatial locality. Record both active-history density and allocated-history density, peak/resident bytes, allocation/reclamation events, retention after decay and per-tick touched blocks. A block that was touched once and never reclaimed defeats an “active only” memory estimate. Do not impose a smaller allocation geometry on the existing scheduler without separate evidence; this study keeps storage/activity/core dimensions unchanged.

## Admission sheet to complete after the real H apparatus

A useful candidate request names one reproducible failure, its scenario and source/policy identities, the intended directional-persistence observable, a maximum acceptable approximation, and at least one negative control. Separate a disappearing display glyph from a material trajectory, and emitter quantization from transport. A familiar-looking jet is not enough unless the measurement identifies what the baseline cannot do.

Compare against the same mass, coherence, threshold, rendering and input policy. Require exact integer quantity; distinguish transferred quantity, front position, direction persistence, active work and changed appearance. A history proposal must specify decay, splitting/merging, region pause/re-entry, sleep, creation/reset, failed-world treatment, capacity and deterministic workers before meaningful speed measurements.

Neither more bits nor a useful memory estimate supplies that target. The present action remains to build #19's verified apparatus. #18 can later proceed on a named deficit or conclude a reasoned no-go. Sparse ballistic #20 and production G-final do not become admitted through this allocation table.
