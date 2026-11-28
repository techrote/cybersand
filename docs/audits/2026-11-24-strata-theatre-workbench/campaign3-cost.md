# Strata qualification and cost observations

This summary preserves original campaign outcomes. Scene component successes do not upgrade a failed full campaign. Hosted software-adapter execution does not satisfy the physical Windows 11/NVIDIA owner gate.

## Exact source and execution custody

| Platform | Source | Full campaign | Maximum-canvas case | Original evidence |
|---|---|---|---|---|
| linux | `d95f9ceaa77ff444d8ff85ce9b90a1173edb7989` | passed | passed | 1,105 source hashes; 136 evidence files |
| win32 | `d95f9ceaa77ff444d8ff85ce9b90a1173edb7989` | passed | passed | 1,105 source hashes; 136 evidence files |

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
| linux / industrial-assembly / install | 93.316 | 154.170 | 1330.80 | 9.953 |
| linux / industrial-assembly / reopen | 26.578 | 34.970 | 948.09 | 7.524 |
| linux / arcology / install | 91.991 | 152.080 | 1356.55 | 9.774 |
| linux / arcology / reopen | 25.405 | 33.550 | 954.48 | 6.999 |
| linux / cavern / install | 90.398 | 150.240 | 1335.32 | 9.406 |
| linux / cavern / reopen | 25.606 | 33.830 | 960.14 | 7.113 |
| win32 / industrial-assembly / install | 152.234 | 370.312 | 1113.84 | 33.549 |
| win32 / industrial-assembly / reopen | 17.031 | 44.078 | 745.44 | 3.754 |
| win32 / arcology / install | 141.656 | 355.047 | 1115.45 | 30.707 |
| win32 / arcology / reopen | 16.984 | 44.469 | 746.80 | 3.685 |
| win32 / cavern / install | 155.063 | 383.797 | 1101.44 | 32.078 |
| win32 / cavern / reopen | 17.843 | 47.000 | 756.21 | 3.795 |

## Matched paused callback observations

Each mode sample retains composition resources. The disabled state here is not the pre-allocation ordinary baseline. Values are main callback median/p95 intervals, not physical presented FPS. Every original interval and Godot time observation remains in the campaign record.

| Platform / scene | Disabled median / p95 ms | Flat median / p95 ms | Stack median / p95 ms | Native captures / uploads in all mode samples |
|---|---:|---:|---:|---:|
| linux / industrial-assembly | 129.552 / 155.764 | 130.099 / 171.165 | 137.460 / 153.728 | 0 / 0 |
| linux / arcology | 130.582 / 167.873 | 126.140 / 171.619 | 134.550 / 167.763 | 0 / 0 |
| linux / cavern | 124.310 / 158.955 | 126.439 / 156.556 | 136.538 / 161.183 | 0 / 0 |
| win32 / industrial-assembly | 181.699 / 188.103 | 183.557 / 195.212 | 190.042 / 200.934 | 0 / 0 |
| win32 / arcology | 179.328 / 188.845 | 182.848 / 193.308 | 189.448 / 202.709 | 0 / 0 |
| win32 / cavern | 195.562 / 211.412 | 187.969 / 198.357 | 196.454 / 210.301 | 0 / 0 |

## Explicit callback budget overruns

A true final predicate after a blocking frame is a functional recovery and retains its elapsed time. It is not compliance with the nominal callback limit. Outer process deadlines remain separately enforced.

| Platform / scene / phase | Callback wait | Limit seconds | Actual recheck seconds |
|---|---|---:|---:|
| All recorded scenes | None | — | — |

## Maximum-canvas outcome and remaining delivery gates

- **linux maximum:** passed. 82 assertions at [2048, 2048]; 58.062 process seconds, 94.030 observed CPU seconds, 1925.61 MiB sampled peak RSS/working set. Original native/pixel/owner receipts retained.
- **win32 maximum:** passed. 82 assertions at [2048, 2048]; 117.625 process seconds, 227.484 observed CPU seconds, 1407.61 MiB sampled peak RSS/working set. Original native/pixel/owner receipts retained.

**Actual package disposition for this source:** workflow run `45453973319`, package job `138666134832`, failed during package verification with `Portable generator profiles differ from archived source recipes`. No archive was admitted or extracted. Both source campaigns passed; the complete delivery workflow failed. The narrow repair matches the existing direct canonical-recipe staging contract and requires qualification on its new source.

The portable extracted-package campaign and actual shipped `Open Workbench.cmd` admission are separate required gates. A passing source campaign cannot stand in for them. Physical Windows 11/NVIDIA appearance, DPI, input and performance remain an owner gate. Draft/HOLD, no merge and no default activation remain unchanged.

## Measurement limits

- CPU and RSS/working-set observations cover whole processes and discovered descendants; they do not isolate incremental layer cost.
- Raw process counters are sampled at 0.5 seconds; short-lived descendants and exit tails may be missed and shared pages may be counted more than once.
- Mode samples observe paused main callback intervals and Godot-tracked static memory. Disabled, flat and stack retain the same composition resources.
- The ordinary baseline precedes Strata allocation at a 512-square canvas and is not a matched-scene resource comparison.
- No incremental native-RSS, GPU-memory, physical presented-FPS or Windows 11/NVIDIA result is inferred.
- A successful final predicate after a callback wait limit is recorded as functional recovery with a budget overrun; the outer process deadline is separate.
