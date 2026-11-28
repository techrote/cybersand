# Pristine extracted Windows package observations

Source `d365f78190af0e006ee9998a17b453f04f31b3ae`, tree `4e2e44513355c6f976d6b672d5dc958f20331add`. This is the actual extracted evaluator campaign; it is separate from the source Windows campaign. Both are retained without substituting the faster run.

## Whole-process observations

| Scene / phase | Assertions | Wall s | Observed CPU-s | Peak working set MiB | Bootstrap s |
| --- | ---: | ---: | ---: | ---: | ---: |
| industrial-assembly / install | 880 | 293.671 | 657.172 | 974.34 | 68.754 |
| industrial-assembly / reopen | 162 | 29.094 | 77.984 | 737.83 | 5.904 |
| arcology / install | 880 | 283.110 | 641.234 | 981.88 | 70.873 |
| arcology / reopen | 162 | 28.407 | 76.719 | 731.19 | 5.493 |
| cavern / install | 880 | 240.375 | 604.938 | 1103.65 | 53.433 |
| cavern / reopen | 162 | 29.187 | 79.516 | 741.20 | 5.533 |

The maximum paused2048square process passed 82 checks, taking 193.484 seconds and 1368.43 MiB sampled peak working set. These values include qualification work and captures.

## Callback wait-budget overruns

| Scene / phase | Predicate | Budget s | Actual final recheck s |
| --- | --- | ---: | ---: |
| industrial-assembly / install | play and all three decorative native owners adopted | 45.000 | 87.289 |
| arcology / install | play and all three decorative native owners adopted | 45.000 | 74.863 |
| cavern / install | play and all three decorative native owners adopted | 45.000 | 49.164 |

Successful final predicates establish eventual functional readiness within the separately enforced outer process bounds. They do not establish compliance with the nominal callback budget.

## Matched paused mode observations

| Scene | Disabled median / p95 ms | Flat median / p95 ms | Stack median / p95 ms | Decorative captures / uploads |
| --- | ---: | ---: | ---: | ---: |
| industrial-assembly | 296.261 / 306.565 | 300.541 / 309.748 | 308.964 / 321.198 | 0 / 0 |
| arcology | 293.798 / 302.208 | 295.064 / 307.683 | 305.370 / 311.030 | 0 / 0 |
| cavern | 302.837 / 314.895 | 304.631 / 317.615 | 314.554 / 322.395 | 0 / 0 |

The same resources remain allocated across mode samples. These are software-rendered callback observations, not presented physical GPU FPS or incremental native-World memory. CPU and working-set counters use the same 0.5-second observer and limitations described in [source cost observations](qualification-cost.md). The physical Windows11/NVIDIA owner gate remains open.
