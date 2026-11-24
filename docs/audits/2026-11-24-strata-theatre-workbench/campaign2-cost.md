# Strata qualification and cost observations

This summary preserves original campaign outcomes. Scene component successes do not upgrade a failed full campaign. Hosted software-adapter execution does not satisfy the physical Windows 11/NVIDIA owner gate.

## Exact source and execution custody

| Platform | Source | Full campaign | Maximum-canvas case | Original evidence |
|---|---|---|---|---|
| linux | `99d3d9ef8cbf112e13979e6d64ed3113b4ec55fc` | failed | failed | 1,105 source hashes; 126 evidence files |
| win32 | `99d3d9ef8cbf112e13979e6d64ed3113b4ec55fc` | failed | failed | 1,105 source hashes; 126 evidence files |

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
| linux / industrial-assembly / install | 73.335 | 116.910 | 1355.64 | 8.717 |
| linux / industrial-assembly / reopen | 23.026 | 29.920 | 969.50 | 6.311 |
| linux / arcology / install | 79.718 | 124.420 | 1331.99 | 10.857 |
| linux / arcology / reopen | 23.546 | 30.180 | 976.94 | 6.840 |
| linux / cavern / install | 74.817 | 120.190 | 1349.61 | 9.025 |
| linux / cavern / reopen | 24.205 | 31.180 | 955.16 | 7.477 |
| win32 / industrial-assembly / install | 249.515 | 603.484 | 988.02 | 58.095 |
| win32 / industrial-assembly / reopen | 28.391 | 74.219 | 741.18 | 5.788 |
| win32 / arcology / install | 247.812 | 603.922 | 1096.90 | 56.526 |
| win32 / arcology / reopen | 27.234 | 72.203 | 741.21 | 5.738 |
| win32 / cavern / install | 252.125 | 613.875 | 1105.51 | 57.825 |
| win32 / cavern / reopen | 28.453 | 76.484 | 742.81 | 5.849 |

## Matched paused callback observations

Each mode sample retains composition resources. The disabled state here is not the pre-allocation ordinary baseline. Values are main callback median/p95 intervals, not physical presented FPS. Every original interval and Godot time observation remains in the campaign record.

| Platform / scene | Disabled median / p95 ms | Flat median / p95 ms | Stack median / p95 ms | Native captures / uploads in all mode samples |
|---|---:|---:|---:|---:|
| linux / industrial-assembly | 90.029 / 107.481 | 91.640 / 96.151 | 96.747 / 100.226 | 0 / 0 |
| linux / arcology | 90.054 / 102.122 | 95.407 / 111.222 | 102.078 / 116.934 | 0 / 0 |
| linux / cavern | 91.780 / 105.061 | 94.759 / 105.760 | 103.060 / 114.624 | 0 / 0 |
| win32 / industrial-assembly | 291.125 / 296.770 | 294.998 / 304.352 | 306.551 / 312.963 | 0 / 0 |
| win32 / arcology | 294.967 / 303.107 | 298.517 / 307.790 | 310.679 / 317.809 | 0 / 0 |
| win32 / cavern | 299.357 / 317.567 | 301.661 / 308.488 | 312.673 / 317.865 | 0 / 0 |

## Explicit callback budget overruns

A true final predicate after a blocking frame is a functional recovery and retains its elapsed time. It is not compliance with the nominal callback limit. Outer process deadlines remain separately enforced.

| Platform / scene / phase | Callback wait | Limit seconds | Actual recheck seconds |
|---|---|---:|---:|
| win32 / industrial-assembly / install | play and all three decorative native owners adopted | 45.000 | 55.473 |
| win32 / arcology / install | play and all three decorative native owners adopted | 45.000 | 54.705 |
| win32 / cavern / install | play and all three decorative native owners adopted | 45.000 | 56.026 |

## Maximum-canvas outcome and remaining delivery gates

- **linux maximum:** failed. [Errno 17] File exists: '/home/runner/work/cybersand/cybersand/build/strata-linux/maximum'
- **win32 maximum:** failed. [WinError 183] Cannot create a file when that file already exists: 'D:\\a\\cybersand\\cybersand\\build\\strata-windows\\maximum'

The portable extracted-package campaign and actual shipped `Open Workbench.cmd` admission are separate required gates. A passing source campaign cannot stand in for them. Physical Windows 11/NVIDIA appearance, DPI, input and performance remain an owner gate. Draft/HOLD, no merge and no default activation remain unchanged.

## Measurement limits

- CPU and RSS/working-set observations cover whole processes and discovered descendants; they do not isolate incremental layer cost.
- Raw process counters are sampled at 0.5 seconds; short-lived descendants and exit tails may be missed and shared pages may be counted more than once.
- Mode samples observe paused main callback intervals and Godot-tracked static memory. Disabled, flat and stack retain the same composition resources.
- The ordinary baseline precedes Strata allocation at a 512-square canvas and is not a matched-scene resource comparison.
- No incremental native-RSS, GPU-memory, physical presented-FPS or Windows 11/NVIDIA result is inferred.
- A successful final predicate after a callback wait limit is recorded as functional recovery with a budget overrun; the outer process deadline is separate.
