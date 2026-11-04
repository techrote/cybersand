# Independent hosted CPU findings — SOL364

**The unchanged registered CPU gate passes all 24 groups in run 41815817333: 12 baseline and 12 candidate groups, with three trials per group and all 72 trials present.** This result applies to source `9edc4f8f7d8cd8fc65119d176c9e1981ab6ea77d`, tree `b5baf8b23ff947c2d7b70e69745c10f18fbe9ebe`. It establishes the registered contact-cost result for this execution. It does not establish sustained physical clearance or merge readiness.

The complete 24-group table, including each repeat, sample standard deviation and worst-repeat numerator/denominator, is in `cost-review.md`. Every trial's all-attempt work, counters, refusal reasons, stage timings and latency observations is in `case-accounting-annex.json`. `before-after-groups.json` retains the corresponding old/new group ranges, maxima, variance and observation denominators.

## Highest registered mean

The highest new mean is Windows, four workers, `embedded_sand/candidate/r2`:

\[
\frac{58.555\text{ ms owner}+433.285\text{ ms response}}{299\text{ complete consumed observations}}
=1.6449498327759198\text{ ms}.
\]

Its owner numerator includes **370 attempts: 361 complete and 9 refused**. Its main-thread numerator includes **298 response attempts: 294 accepted and 4 `NonDissipativeResponse` refusals**. The 62 complete owner attempts not consumed by the main reader remain included in cumulative owner work. The difference between all attempts and consumed observations also includes setup/refused attempts; it is not a count of proven overwritten publications.

The 433.285 ms response total partitions into 420.555 ms planning, 0.586 ms RID-state reads, 3.557 ms impulse application/refresh, 3.745 ms readback and 4.842 ms residual caller/guard/instrumentation work. The 58.555 ms owner total partitions into 57.662 ms native call and 0.893 ms metadata envelope/freezing. Native geometry 54.9494 ms and native payload freezing 0.8992 ms are nested parts of that native-call interval.

The highest individual owner attempt is 3.335 ms, and the highest individual response attempt is 3.797 ms. Those observations are retained; the registered 2 ms criterion is a mean per complete consumed observation, not a per-attempt maximum.

## Earlier failures remain failed

The original source-qualified Windows four-worker `embedded_sand/baseline/r0` remains **480.685 ms / 224 = 2.145915178571 ms, FAIL**, with 369 owner attempts and zero response work. Its old timing did not separately record all-attempt native geometry and freezing. Subtracting consumed-observation geometry from all-attempt owner work would mix denominators and cannot establish the old freezing cost.

The new Windows four-worker embedded baseline repeats are:

| Repeat | Owner attempts | Complete consumed | All owner work ms | Cost ms per complete observation |
|---|---:|---:|---:|---:|
| r0 | 370 | 357 | 144.376 | 0.404414565826 |
| r1 | 369 | 357 | 134.088 | 0.375596638655 |
| r2 | 369 | 260 | 269.111 | 1.035042307692 |

All three have zero Sand-response work. In the most expensive new baseline repeat, native geometry accounts for 262.6654 ms, native payload freezing for 3.2029 ms and the envelope for 1.133 ms; geometry and native freezing are nested within 267.978 ms native-call work. The experiment continues to count hundreds of owner attempts, including unconsumed and refused attempts.

The later local Linux worker-1 development failure also remains **(116.446 + 408.867) / 261 = 2.012693486590 ms, FAIL**, with 369 owner attempts and 245 response attempts. It lacked the later response-stage breakdown, so a planner/RID/readback decomposition of that failed local receipt cannot be reconstructed.

The new source-qualified Linux worker-1 embedded candidate repeats are 1.236303226, 1.282837079 and 1.439424242 ms. All three include 369 owner attempts, with 310, 356 and 330 complete consumed observations respectively. These are separate asynchronous histories; the changes in measured work and consumption ratio are descriptive comparisons, not an identical-input estimate of optimization speedup.

## Complete work accounting

Across all 72 hosted trials, the review retains:

- **26,575 owner attempts:** 25,983 complete and 592 refused.
- **22,850 complete consumed observations**, independently matched to 22,850 unique trace receipts.
- **3,133 complete owner attempts not consumed**; their work remains in the owner numerator.
- **10,900 main response attempts:** 10,571 accepted and 329 refused. Refusals comprise 278 `NonDissipativeResponse`, 43 `PoseDrift` and 8 `InvalidGeometryWitness` outcomes.
- **7,415.191 ms owner work + 10,517.331 ms response work.** These totals describe accumulated measured intervals and do not replace any of the 24 separate group gates.

The summed main response work partitions as follows:

| Stage | Accumulated ms |
|---|---:|
| RID-state reads | 25.164 |
| Planning | 10,052.250 |
| Impulse application/refresh | 107.977 |
| Readback | 139.342 |
| Residual caller/guards/instrumentation | 192.598 |
| **Inclusive response** | **10,517.331** |

Planning is **95.577956% of summed response work**. Thus a future bounded effort to increase contact-cost margin should begin with repeated per-plan exact-geometry construction and clipping, preserving all identity, witness, duplicate and energy checks. No additional optimization is required to turn this specific 24-group execution green; it already passes.

Owner native-call work totals 7,347.243 ms, with 67.948 ms envelope work. Within native-call work, geometry totals 7,108.830670 ms and native payload freezing totals 94.679081 ms. These nested values must not be added again to the inclusive numerator.

## Timing and memory scope

The registered numerator covers native contact observation/value construction, metadata envelope/freezing and bridge Sand-response calls. Cumulative metrics bookkeeping occurs after the ready timestamp, and shared publication is outside the historical contact interval. The contact gate is not a whole simulation/snapshot CPU budget, and no separate mutex CPU measurement exists here.

Owner-ready-to-receipt latency has a weighted mean of **6.811427440 ms** and observed maximum **17.874 ms** over 22,850 receipts. Accepted publication-to-response latency has a weighted mean of **7.711499764 ms** and observed maximum **19.990 ms** over 10,571 accepts. Their endpoints and denominators differ. They describe elapsed handoff/queue/scheduling and response delay, not an independently measured scheduler or mutex CPU decomposition, and are not added to the contact-work numerator.

The contact timers use monotonic elapsed intervals, **not operating-system thread CPU time**. Separate Linux process receipts report 18.37 and 18.07 direct-process CPU seconds, with peak RSS 340,951,040 and 349,761,536 bytes for worker counts 1 and 4. Those values include the entire recovery-test process and cannot be allocated to contact stages. Corresponding Windows process resource measurements are marked unavailable; no Windows memory number is inferred.

## Independent authentication and arithmetic

The review independently retrieved GitHub artifact metadata, hashed all six relevant ZIPs against their reported SHA-256 digests and byte sizes, and checked relevant extracted members against the authenticated ZIP bytes. It then verified the build-before/build-after source maps, exact source commit/tree, built runtime bytes, host-before/host-after input maps, process logs and canonical result hashes. The concise process footer is not used as a substitute for the complete JSON.

The executed hosted native binaries are:

| Platform | Native SHA-256 |
|---|---|
| Linux | `de38c0de458b2a30d43cb36c633cb7ee3b469f8d84f7a3e512fafc9838bb82a5` |
| Windows | `a5e616c0e72eee56c84f66151499d401dd3f4fb7faab347adbc6335493fefd61` |

The earlier local `a013…` ELF is not treated as the hosted Linux executable. Complete engine, Rapier, bindings and compiler identities are retained for each cohort in `cost-review.json`.

The standalone helper imports no repository cost analyzer. Its 72 independently calculated costs, observation denominators, owner-attempt counts and response-attempt counts agree exactly with the source-matched repository analyzer. It also recomputes accepted application/latency totals and all four explicit response-stage totals from individual trace receipts, and reconciles evaluated/accepted/refused counts. The five response stages sum to inclusive response work, and native-call plus envelope sums to inclusive owner work.

Portable canonical raw evidence paths are under `docs/audits/sol281-20261103/hosted/9edc4f8f7d8cd8fc65119d176c9e1981ab6ea77d/`. The helper, metadata, per-group report and full case annex should remain together under `docs/audits/sol364-20261104/hosted-review/`.

**Disposition: the CPU gate passes this exact-source hosted matrix. Both earlier failed receipts remain unchanged. Physical clearance and integration decisions require their separate evidence.**
