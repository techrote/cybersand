# Strata qualification and cost observations

This summary preserves original campaign outcomes. Scene component successes do not upgrade a failed full campaign. Hosted software-adapter execution does not satisfy the physical Windows 11/NVIDIA owner gate.

## Exact source and execution custody

| Platform | Source | Full campaign | Maximum-canvas case | Original evidence |
|---|---|---|---|---|
| linux | `d365f78190af0e006ee9998a17b453f04f31b3ae` | passed | passed | 1,105 source hashes; 136 evidence files |
| win32 | `d365f78190af0e006ee9998a17b453f04f31b3ae` | passed | passed | 1,105 source hashes; 136 evidence files |

Both platforms use pinned Godot `4.7.stable.official.5b4e0cb0f` with retained source-bound CyberSand native and Rapier runtimes. Original manifest hashes, native identities, process identities and all values below are retained in the accompanying JSON.

## Actual scene and fresh-process qualification

| Platform / scene | Install / reopen assertions | Distinct actual engine processes | Complete native planes and saved bytes equal after reopen |
|---|---:|---|---|
| linux / industrial-assembly | 880 / 162 | True | True |
| linux / arcology | 880 / 162 | True | True |
| linux / cavern | 880 / 162 | True | True |
| win32 / industrial-assembly | 880 / 162 | True | True |
| win32 / arcology | 880 / 162 | True | True |
| win32 / cavern | 880 / 162 | True | True |

The assertions include actual ordinary Workbench ownership, all-plane native editing, existing Play/actor identity through presentation changes, guarded edits, per-plane history, actual pixels, same-event pan/zoom input, persistence and teardown. They count assertions rather than separate human interaction scenarios. Mounted failed Play ACK, partial native edit quarantine and post-commit failed publication were source-reviewed, not directly fault-injected.

## Whole-process CPU and memory observations

These include startup, scene replacement, tests and screenshots. CPU is cumulative observed user plus kernel time for the process tree, so it may exceed wall time. RSS/working set is the peak simultaneous sampled process sum; shared pages can be counted more than once. No incremental Strata memory estimate is derived.

| Platform / scene / phase | Wall seconds | Observed CPU seconds | Sampled peak RSS / working set MiB | Bootstrap seconds |
|---|---:|---:|---:|---:|
| linux / industrial-assembly / install | 93.589 | 150.690 | 1352.54 | 12.479 |
| linux / industrial-assembly / reopen | 27.111 | 35.340 | 959.39 | 7.787 |
| linux / arcology / install | 90.557 | 146.560 | 1321.07 | 10.276 |
| linux / arcology / reopen | 27.234 | 35.550 | 977.64 | 7.708 |
| linux / cavern / install | 89.801 | 146.590 | 1327.73 | 10.067 |
| linux / cavern / reopen | 27.648 | 36.440 | 957.24 | 7.743 |
| win32 / industrial-assembly / install | 209.938 | 473.859 | 1108.59 | 54.916 |
| win32 / industrial-assembly / reopen | 21.891 | 56.328 | 752.64 | 4.562 |
| win32 / arcology / install | 227.125 | 511.406 | 1078.45 | 59.012 |
| win32 / arcology / reopen | 22.860 | 58.359 | 745.82 | 5.101 |
| win32 / cavern / install | 208.172 | 466.281 | 1108.02 | 56.817 |
| win32 / cavern / reopen | 20.266 | 52.406 | 729.40 | 4.338 |

## Matched paused callback observations

Each mode sample retains composition resources. The disabled state here is not the pre-allocation ordinary baseline. Values are main callback median/p95 intervals, not physical presented FPS. Every original interval and Godot time observation remains in the campaign record.

| Platform / scene | Disabled median / p95 ms | Flat median / p95 ms | Stack median / p95 ms | Native captures / uploads in all mode samples |
|---|---:|---:|---:|---:|
| linux / industrial-assembly | 115.539 / 128.002 | 119.243 / 131.139 | 126.723 / 131.107 | 0 / 0 |
| linux / arcology | 115.889 / 128.120 | 119.504 / 130.790 | 127.090 / 131.185 | 0 / 0 |
| linux / cavern | 115.853 / 126.318 | 118.475 / 124.627 | 125.054 / 130.084 | 0 / 0 |
| win32 / industrial-assembly | 210.835 / 233.422 | 217.768 / 239.201 | 231.644 / 254.453 | 0 / 0 |
| win32 / arcology | 238.234 / 245.347 | 241.389 / 246.948 | 249.906 / 257.187 | 0 / 0 |
| win32 / cavern | 210.449 / 224.470 | 211.939 / 219.957 | 220.598 / 248.372 | 0 / 0 |

## Explicit callback budget overruns

A true final predicate after a blocking frame is a functional recovery and retains its elapsed time. It is not compliance with the nominal callback limit. Outer process deadlines remain separately enforced.

| Platform / scene / phase | Callback wait | Limit seconds | Actual recheck seconds |
|---|---|---:|---:|
| win32 / industrial-assembly / install | play and all three decorative native owners adopted | 45.000 | 52.169 |
| win32 / arcology / install | play and all three decorative native owners adopted | 45.000 | 56.579 |
| win32 / cavern / install | play and all three decorative native owners adopted | 45.000 | 50.789 |

## Maximum-canvas outcome and remaining delivery gates

- **linux maximum:** passed. 82 assertions at [2048, 2048]; 59.649 process seconds, 93.880 observed CPU seconds, 1923.86 MiB sampled peak RSS/working set. Original native/pixel/owner receipts retained.
- **win32 maximum:** passed. 82 assertions at [2048, 2048]; 157.546 process seconds, 289.656 observed CPU seconds, 1401.43 MiB sampled peak RSS/working set. Original native/pixel/owner receipts retained.

The separate portable extracted-package campaign, actual shipped `Open Workbench.cmd` admission and post-run payload verification passed. [Package observations](package-cost.md) retain their own timings and longer callback wait-budget overruns. The [independent audit](evaluator-independent-audit.json) binds the downloaded archive, exact source and original receipts. Physical Windows 11/NVIDIA appearance, DPI, input and performance remain an owner gate. Draft/HOLD, no merge and no default activation remain unchanged.

## Measurement limits

- CPU and RSS/working-set observations cover whole processes and discovered descendants; they do not isolate incremental layer cost.
- Raw process counters are sampled at 0.5 seconds; short-lived descendants and exit tails may be missed and shared pages may be counted more than once.
- Mode samples observe paused main callback intervals and Godot-tracked static memory. Disabled, flat and stack retain the same composition resources.
- The ordinary baseline precedes Strata allocation at a 512-square canvas and is not a matched-scene resource comparison.
- No incremental native-RSS, GPU-memory, physical presented-FPS or Windows 11/NVIDIA result is inferred.
- A successful final predicate after a callback wait limit is recorded as functional recovery with a budget overrun; the outer process deadline is separate.
