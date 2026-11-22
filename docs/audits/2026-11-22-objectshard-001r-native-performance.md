---
title: ObjectShard 001R native performance qualification
status: Planned
document-kind: audit
scope: Source-bound native cost evidence; no Rapier, rendering or owner physical acceptance claim
last-reviewed: 2026-11-22
related-documents: [2026-11-22-objectshard-final-acceptance.md, 2026-11-22-objectshard-001r-native-admission.md]
---

# ObjectShard 001R native performance qualification

The registered 74-limit matrix remains unchanged. This record keeps the original M2 timing failure, a fresh M2 control, the finisher's first memory failure, its focused repair, and final-source qualification separate. The experiment executes real native World, shard chemistry, ownership and exchange, with synthetic pose and installation receipts. It does not measure Rapier, Windows presentation, GPU work or physical owner acceptance.

## Source cohorts and negative results

The original M2 final acceptance remains **10 failed timing limits out of 74**: all nine p95 ceilings and the perforated maximum. Its 3.536 ms empty-Lab p95, 5.760 ms three-body p95 and 64.605 ms perforated maximum remain in the [historical final acceptance](2026-11-22-objectshard-final-acceptance.md). A later passing control does not revise those observations.

A fresh build of historical M2 documentation HEAD `dc4282e5f5f9b886315e8450613740d265f5fbc3` passed all 74 limits on this host, with 4,237,384 functional assertions and zero failures. Its input digest is `ceb176f8b88b3de87a74a68dfc1a596d06c0d64f0d711067b9a8d7f92e6ce46e`. This is an independently retained cohort, not a replacement for the original failure.

The first integrated 001R source, `f11be5aa55babad3fbabe0471ae47517322989b1`, passed 4,237,399 functional assertions but **failed 14 of 74 limits**. Every failure concerned requested C++ live/peak bytes; the seven default-canvas workloads exceeded 6,291,456 bytes. The largest peak was 6,670,496 bytes. Timing, steady allocation and geometry-age gates passed. The [negative report](objectshard-001r-20261122/native-performance/f11-memory-negative-summary.json) and [raw observations](objectshard-001r-20261122/native-performance/f11-memory-negative-benchmark.json) remain unchanged.

## Focused memory repair

The bounded ingress-history rollback vector added a second copy of 12,288 private cache records. Each record held a 24-byte full Handle plus six coordinate bytes and padding, totaling 32 bytes. The repair stores the registry's never-reused 64-bit shard ID plus the coordinates, with a compile-time 16-byte size assertion. Both live and rollback vectors retain their full capacities. The resulting saving is exactly **393,216 bytes**.

This cache grants no authority. Public operations still validate session, shard ID and generation through a full Handle. Cache refresh resolves the compact ID through the bounded current body roster and then checks that body's complete Handle with the registry. Registry IDs remain monotonic across session reset and refuse exhaustion. Regression coverage checks reset, wrong generation, old session, refused-motion history rollback and exact material ownership.

The repaired pre-telemetry iteration passed all 74 limits with maximum requested C++ live/peak bytes of **6,277,280**. That leaves only **14,176 bytes** below the registered default-canvas ceiling. This narrow margin is reported explicitly; it is not a bound for every future canvas or payload. The new complete-census cache and exact contact-history machinery have a real storage cost: the representative three-body peak is 1,608,008 bytes above the freshly measured M2 control's 4,669,272 bytes. The measurement concerns requested C++ allocations, not RSS, allocator metadata, Godot or Rapier.

## Measurement method

The unchanged harness uses GCC 14.2, C++20, `-O3 -DNDEBUG -pthread`, no LTO. Each integrated workload runs 480 ticks in three repetitions, giving 1,440 native frame observations. Construction and promotion are reported separately. Registered limits remain frame p95 ≤2 ms, p99 ≤10 ms, maximum ≤50 ms, requested C++ live/peak ≤6 MiB, registry retained ≤256 KiB, zero steady C++ allocations and geometry age ≤one semantic tick.

The matched comparison executes three alternating pairs of the already-built historical control and repaired candidate. Its order was registered before execution: control/candidate, candidate/control, control/candidate. All six complete runs passed all 74 gates with zero functional failures. The host was shared and not CPU-pinned; load and every observed maximum are retained. There was no repeat-until-green selection. The [registered plan](objectshard-001r-20261122/native-performance/paired-pre-telemetry/plan.json), [execution receipts](objectshard-001r-20261122/native-performance/paired-pre-telemetry/runs.json), [all comparisons](objectshard-001r-20261122/native-performance/paired-pre-telemetry/comparison.json) and runnable comparison script preserve the method.

The paired candidate uses frozen input `b9fc822657c0762fea847ef28f8e9a1e60d2233283612916be334b379e015690`, captured as f11 plus the private-cache repair. It predates the final telemetry correction that includes history-only ingress work in the contact timer. It is therefore an explicitly identified implementation comparison, not the final-source receipt. Overall native frame timing includes that work in both versions; the earlier contact subcounter did not include all paths.

## Matched frame observations

Values below are microseconds. p50 and p95 are medians of three per-process statistics, not pooled percentiles. Maximum retains the largest observation across all three processes. Each cell shows **M2 control / repaired iteration**.

| Workload | p50: control / candidate | p95: control / candidate | Maximum: control / candidate |
| --- | ---: | ---: | ---: |
| `empty_lab` | 265.943 / 267.094 | 382.790 / 377.583 | 5706.526 / 13220.326 |
| `inert_stationary` | 393.263 / 389.474 | 476.918 / 454.664 | 6611.823 / 3340.735 |
| `inert_moving` | 405.286 / 402.695 | 452.867 / 462.733 | 2100.537 / 2778.451 |
| `reacting_one` | 399.183 / 404.278 | 458.624 / 620.223 | 1570.303 / 3531.450 |
| `reacting_three` | 639.393 / 660.341 | 828.199 / 775.019 | 10518.873 / 6078.566 |
| `perforated_reacting` | 399.982 / 405.656 | 463.031 / 463.753 | 4451.034 / 1300.440 |
| `saturated_world_destinations` | 398.513 / 394.834 | 519.890 / 484.199 | 9967.811 / 3157.876 |
| `dormant_twelve` | 328.993 / 340.266 | 426.168 / 410.226 | 9311.006 / 1869.358 |
| `wake_burst_twelve` | 334.700 / 349.521 | 391.714 / 441.929 | 1760.574 / 1316.495 |

The representative three-body p50 rose 3.28%, and wake-burst p50 rose 4.43%. This bounded comparison did not reproduce the approximately doubled timings seen in the first f11 matrix run. Some tails worsened: one reacting body's median p95 rose 35.24% and wake-burst p95 rose 12.82%. All remained within their registered limits. These measurements support a small recurring native-cost change with variable tails; they do not support a general frame-rate improvement claim.

The isolated [admission benchmark](2026-11-22-objectshard-001r-native-admission.md) measures a different operation: repeated unchanged body-slot refusal. Its large improvement comes from eliminating repeated component flood fills. It must not be substituted for overall frame timing.

## Final source and coverage

Final qualified code is **`514d76fbf4df30eb05353bc14b6a4ec3ea9bf61c`**, tree `e2b0753b82650734b5738ff000be62a2c7db2abe`. This includes the cache compaction and the reviewed contact-timer correction. Documentation-only descendants must identify this executed source separately.

The final complete matrix passed **4,237,399 assertions / zero failures and 74/74 registered limits**. Native input: `1aab8c0f4ca49e4981697571e108e3bbf86ff2b0156416a5b737322702628ece`; executable SHA-256: `7d1ddcf453349b2458031fe66bb641f80c1617931e053a302bc11fa98dddcac0`. See the [source manifest](objectshard-001r-20261122/native-performance/final-514d-inputs.json), [qualification receipt](objectshard-001r-20261122/native-performance/final-514d-summary.json) and [complete measurements](objectshard-001r-20261122/native-performance/final-514d-benchmark.json).

| Final-source workload | p50 µs | p95 µs | p99 µs | Maximum µs | Peak requested C++ bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| `empty_lab` | 268.662 | 368.092 | 475.788 | 757.163 | 6,128,318 |
| `inert_stationary` | 396.905 | 636.302 | 1557.727 | 21145.004 | 6,177,628 |
| `inert_moving` | 403.581 | 515.634 | 695.565 | 1736.004 | 6,177,628 |
| `reacting_one` | 409.465 | 554.523 | 1029.444 | 8798.157 | 6,177,628 |
| `reacting_three` | 677.363 | 929.858 | 1496.219 | 8577.911 | 6,277,280 |
| `perforated_reacting` | 414.551 | 531.381 | 800.702 | 3162.766 | 6,177,628 |
| `saturated_world_destinations` | 435.765 | 825.913 | 1024.120 | 2069.149 | 6,177,628 |
| `dormant_twelve` | 601.697 | 779.907 | 939.985 | 2127.176 | 3,742,430 |
| `wake_burst_twelve` | 634.585 | 905.288 | 1182.677 | 8787.688 | 3,742,430 |

Every integrated case reports zero steady C++ allocations. The largest registry retained observation is 173,438 bytes, and maximum geometry age is zero semantic ticks. These are native adapter observations; synthetic immediate geometry receipts cannot establish real main-thread installation latency.

The final three-body p50 counters separately report World 72.293 µs, chemistry 15.271 µs, contact 91.010 µs, occupancy-inclusive work 254.985 µs, overlap relocation 174.893 µs, terrain geometry 133.667 µs, exchange 13.660 µs and native snapshot 99.775 µs. These scopes overlap and must not be added. Per-tick shard geometry has median zero and maximum 61.201 µs. Construction and promotion contain only three samples and are descriptive, not statistically qualified tail bounds.

Final-source focused **ASan + UBSan** qualification passed coordinator 3,120, admission 28,092 and external Fire 3,683 checks: **34,895 checks, zero failures**, including the new contact-history timer assertion. Leak sanitizer remains disabled by the established runner. This is the focused native delta, not the complete ordinary World catalogue. Its input digest is `0a00eea4542784565f02e7fd4cd275f5abb4ed79005b2a5bdbe284c167b4bc8d`; see the [focused sanitizer receipt](objectshard-001r-20261122/native-performance/focused-final-514d-summary.json).

All 94 captured files in each final source manifest were independently compared byte-for-byte, via SHA-256, with the corresponding files in commit 514d. There were **zero source mismatches**; see [the final source binding](objectshard-001r-20261122/native-performance/final-source-binding.json).

Reproduction from the qualified source:

```sh
python3 tools/objectshard/run_benchmarks.py --qualify --jobs 2 --output build/objectshard-001r-matrix
python3 tools/objectshard/run_native_tests.py --suite coordinator --suite admission --suite external_fire --sanitize --jobs 2 --output build/objectshard-001r-focused-sanitized
```


## Scope and remaining limitations

The retained compact-versus-miniature comparison is the existing 3×3 local carrier fixture with real Wood chemistry, Fire delivery and downstream World Smoke. It compares every local and external payload each tick against a tuned `SerialInPlace` World with eight-cell chunks, one worker and bounded capacities. It is not a benchmark of two complete Godot products or a claim that all future material behaviours are supported.

Zero recurring C++ allocations and finite storage in this campaign do not establish full-process allocation freedom. The benchmark's contact poses and acknowledgements are synthetic; actual Rapier settling, timed shape installation, presentation and Windows qualification have separate receipts. Larger authored Lab canvases are separately measured in the [admission evidence](2026-11-22-objectshard-001r-native-admission.md); their storage is not covered by the default-canvas 6 MiB claim.

No performance budget, test inventory, shape capacity, body capacity, ingress-history capacity or ownership guard was weakened to obtain the repaired result.
