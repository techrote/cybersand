# OBJECTSHARD-001 portable-math performance delta

**The repaired-source matrix passed its functional assertions but failed ten
registered performance limits.** One subsequent bounded control cohort found no
sampled slowdown between the old and new binaries for the empty Lab and
three-tree workloads. That control does not replace the failed full matrix.

This delta applies to commit
`8f55a4e61b7cbb34a594f5e07e7d81d49aa58945`. The
[earlier performance report](2026-11-22-objectshard-native-performance.md) and
full-tree architectural experiment remain unchanged and specifically bound to
`1bb6185be05f5ef838543a0e13c81428b751d969`.

## Source and unchanged qualification policy

The portability repair replaces five two-component `std::hypot` calls with the
bounded, scaled-square-root contact helper, avoiding the newer Linux GLIBC
symbol dependency. The arithmetic can differ slightly in rounding; this is not
a claim of bit-identical contact geometry. Chemistry, output, the benchmark
harness, its workload inventory, and registered thresholds were unchanged.

| Identity | Value |
| --- | --- |
| Native input digest | `ceb176f8b88b3de87a74a68dfc1a596d06c0d64f0d711067b9a8d7f92e6ce46e` |
| Executable SHA256 | `6697001acedb6e7ee66609f9ce21f7298020eaa247bfa85bc8fc00bb84b4a375` |
| Contact helper SHA256 | `0baf145a2d53bac817e0ede14904c39c21c8b956b7dc7b32e0c6568bab8f5f2a` |
| Coordinator SHA256 | `2c1c7b52c7fc200d5e958175c5cb42e43284e6da46bac44c5a40f1d711e89714` |
| Source-to-commit binding | All 92 captured files matched the repaired commit; zero mismatches |
| Functional assertions | 4,237,384 passed; zero failed |
| Registered performance result | **10 failures among 74 limits; `budget_failed`** |

These remain development-host native C++ measurements. Poses and physics
receipts are synthetic; actual Godot, Rapier, Windows presentation and owner
acceptance require their separate evidence.

## Repaired-source full matrix

Each workload retained 1,440 samples: three constructions, each followed by 480
semantic ticks. No outlier was removed and no threshold was changed. The
registered p95 ceiling is 2 ms, p99 ceiling 10 ms, and maximum ceiling 50 ms.

| Workload | p95 ms | p99 ms | Maximum ms | Failed limits |
| --- | ---: | ---: | ---: | --- |
| Empty Lab | 3.536 | 5.446 | 13.789 | p95 |
| One inert stationary tree | 4.515 | 6.618 | 11.352 | p95 |
| One inert moving tree | 3.991 | 5.604 | 13.140 | p95 |
| One reacting tree | 4.248 | 8.352 | 14.207 | p95 |
| Three reacting trees | 5.760 | 9.020 | 30.745 | p95 |
| Perforated reacting tree | 3.528 | 5.578 | 64.605 | p95 and maximum |
| Saturated World destinations | 4.343 | 8.634 | 26.690 | p95 |
| Twelve dormant shards | 3.491 | 4.232 | 20.946 | p95 |
| Twelve-shard wake burst | 3.745 | 6.150 | 13.397 | p95 |

All allocation, retained-memory and geometry-age limits still passed. All
workloads retained zero steady C++ allocations. The standard single-cell
comparison was included; the earlier full-tree architectural experiment was not
repeated or relabelled as a repaired-source result.

## One bounded matched control

The slowdown of the empty Lab justified a control: it executes no contact
magnitude calculation, yet its p95 increased from the earlier run's 0.723 ms to
3.536 ms. During a later quiet local interval, the exact retained binaries were
executed once per unchanged workload in this order: old empty, new empty, new
three-tree, old three-tree. Every entry again contains 1,440 samples.

| Source | Workload | p95 ms | p99 ms | Maximum ms | Process CPU / wall |
| --- | --- | ---: | ---: | ---: | ---: |
| Old `1bb6185` | Empty Lab | 0.424 | 0.622 | 1.728 | 99.4% |
| Repaired `8f55a4e` | Empty Lab | 0.387 | 0.604 | 2.272 | 99.9% |
| Repaired `8f55a4e` | Three reacting trees | 0.848 | 1.189 | 12.106 | 100.0% |
| Old `1bb6185` | Three reacting trees | 1.231 | 1.945 | 13.469 | 98.6% |

Both binaries met the sampled limits in this control. The observations support
transient shared-host influence and do not show a regression in these two
cases. They do not prove the precise cause of the earlier slowdown, establish
statistical equivalence, or qualify the other seven workloads under repaired
source. CPU/cgroup pressure counters were unavailable in the execution
environment. Recorded host load was approximately 5.1; CPU and wall durations
are retained for each invocation. No further rerun was performed to seek a
green result.

## Evidence and remaining qualification

The [delta evidence manifest](objectshard-001-20261122/portable-math/manifest.json)
retains the full result, failed budget summary, source ledger, commit binding,
control observations and all four raw control JSON results. The original run is
`build/objectshard-benchmarks-portable-math/20261122T020237.281138Z-ceb176f8b88b/`;
the bounded control is `build/objectshard-portable-math-matched-control/`.

The portability repair has source-bound native functional evidence and a
successful matched control, while its **recorded complete native performance
qualification remains failed**. A future controlled complete measurement or
target-PC acceptance may resolve that remaining performance gate. The previous
source's passing matrix and full-tree tradeoff remain useful historical
evidence, not a substitute for that result.
