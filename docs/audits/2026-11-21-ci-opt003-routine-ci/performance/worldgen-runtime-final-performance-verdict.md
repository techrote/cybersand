# PR723 independent performance admission: GO — merged

Candidate `19023b4016facfda2b13b9a1503742e4a9fe1982`, tree `39b658c5de9c5e541312b5190bd5d8ba797c6bed`, materially shortens the actual worldgen critical family. The complete cold same-worker pair saved **516.231169 seconds (8m36.23s; 29.5219% of this measured family)** with every original compilation, execution, sanitizer flag, scientific assertion and watchdog preserved. The separately qualified final-source Ready cohort passed all 78 executed jobs.

After independent GO and review `6009201962`, root manually merged PR723 into main as `662df51cd8409a52332fa7ef15d06d8ab8945aed`. Its tree exactly matches the qualified candidate and tested merge tree; parents are accepted main `30e1cddd3d678456df10f52f7a2fb2210a9daaad` and candidate 19023. Post-merge exact-commit checks remain a separately observed cohort.

## Controlled measurement and actual mechanism

Proof run <https://github.com/techrote/cybersand/actions/runs/44963259696>, attempt 1, executed the actual complete family once for baseline `cd32ed95b1c3da1d5e8bbecc8020f68e13fe1d55` and once for candidate 19023. Baseline has exactly the accepted PR722 main tree. Both arms used one Intel Xeon 6975P-C hosted worker, four logical CPUs, 16,078,416 KiB reported memory, Ubuntu image `20261116.133.1`, GCC/G++ 13.3.0 and GNU Make 4.3. Compiler executable, environment and tool hashes match within the pair.

| Complete original work | Baseline seconds | Candidate seconds | Observed saving |
| --- | ---: | ---: | ---: |
| Whole worldgen family | 1748.640267 | 1232.409098 | 516.231169 / 29.5219% |
| Physics characterization | 98.950507 | 97.211714 | 1.738794 |
| Normal worldgen | 241.545314 | 188.024430 | 53.520884 |
| ASan/UBSan worldgen | 1407.494205 | 946.740588 | 460.753617 |

Seven independent showcase programs formerly ran in a serial shell loop after compilation. They now use independent Make recipes under the existing two-job limit, sharing that limit with compilation. The nine ordered principal tests still follow all seven successful showcases. No additional GitHub family or runner, cached test result, relaxed compiler optimization or production algorithm change provides the saving.

Original GNU time records show nearly the same CPU work fitting into less elapsed time:

| Metric | Normal baseline→candidate | Sanitizer baseline→candidate |
| --- | --- | --- |
| Child user CPU seconds | 338.61→344.40 | 1655.38→1658.36 |
| Child system CPU seconds | 8.45→8.61 | 19.39→19.09 |
| Aggregate CPU utilization | 143%→187% | 118%→177% |
| Maximum child RSS KiB | 933,264→933,408 | 1,696,048→1,695,928 |
| Swaps | 0→0 | 0→0 |

Combined child CPU increased 8.63s (about 0.43%) while normal+sanitized elapsed time fell 514.274502s. Maximum child RSS is not simultaneous process-tree memory. Raw showcase logs do not contain per-case clocks; no per-case durations or exact compiler/test overlap intervals are invented. The source graph and aggregate CPU measurements support the scheduling explanation.

The family pair represents 8.603853 runner-minutes saved on its assigned worker. The experiment itself consumed 50.15 runner-minutes (one job 23:44:36→00:34:45 UTC), with 50m12 from event to last job completion. Experimental cost is separate from routine savings.

## Coverage, custody and independent readback

Immutable proof source `cc22fb8ffbba2a7c18a0bc1c0ad60413ad5c3147`, tree `915d0be2d54adafa23637023c009044c9e5ce9a4`, adds only its seven declared proof files. Both arms retain the original three family commands, all 28 compiler/link invocations and 16 execution obligations per worldgen configuration, and all 154 physics CLI invocations. The original three physics assertion groups were independently reapplied to each arm's retained outputs. Canonical watchdogs, exact source/run/attempt identities, natural-completion receipts and binary inventories all passed readback.

Original artifact 14732380696 has ZIP SHA256 `9411292cbcf416dd56600c37e3e19d85c9b3ca4e1fdf885e6b2bff4cbd4e5238`. I independently rehashed it and ran both reviewed consumers against its unchanged extraction:

- Frozen source-aware reader SHA256 `6579cc7476996764cb21b4bfabd90bd3948d55c5e1d1c7c29b10e3c31c06a7a5`: PASS.
- Corrected complete-showcase supplement SHA256 `540c4f5490529ec61f767736be8c23bc3451b0e1f383ec9ad5b0e7ce10e69c7a`: PASS for all 14 original raw candidate groups.
- All 680 extracted files remained byte-identical after readback; manifest SHA256 `dee5bee14185a18440778b6831a611332ffc75851f93c1a9f3309d997e2fe500`.

The original reader did not fully couple each raw showcase payload to its combined replay. The offline supplement was independently challenged with resealed truncation and conflicting duplicate-header cases, repaired to compare complete source-derived Make output groups, and freshly reviewed. Ten synthetic positive/adversarial controls and a real local GNU Make 4.4.1 process-double replay passed. These controls validate the consumer; they are not scientific execution evidence. Actual hosted GNU Make 4.3 evidence then passed both consumers. Neither frozen producer nor candidate source nor original artifacts were changed, and no hosted rerun was required.

Independent outputs: `worldgen-runtime-independent-admission.json`, `worldgen-runtime-independent-replay-admission.json`, `worldgen-runtime-pair-measurements.json`. Fresh review: `reviews/showcase-replay-audit-review.md`.

## Whole-source turnaround and external overhead

The final Ready cohort completed **30m09s** after its event and consumed **285.416667 unweighted hosted runner-minutes**, passing 78 executed jobs across all six applicable workflows. Two additional cheap Ready scope jobs account for the count difference from PR722's 76. Tested merge checkout `5c56bce96881291c57cea6575e1f4d5fb89485cc` has exactly the candidate tree. Original job data and run URLs are in `runtime-cohort-summary.json` and `runtime-source-qualification.md`.

Native waited 7m26 while an older superseded PR run remained active; GDExtension waited 4m06. These waits remain in actual turnaround. The existing job-level `always()` condition is a plausible cancellation explanation, but the exact cancellation-request event log was unavailable, so that root cause remains an inference. First whole-cohort functional result was Wave normal at 1m26; first Native result was 10m02 after the event, or 2m36 after Native's first worker began. These scopes must not be conflated.

The added graph/failure controls cost work before the matrix, outside the family pair. The observed Native policy job was 27s for PR722 and 44s for PR723; the control step was 11s versus 30s. The observed whole-job increase 17s comes from separate hosted jobs, so it is not an exact controlled overhead estimate. It is included in whole-cohort time and excluded from the 29.5219% family result.

PR722's separate Ready cohort was 30m52s/290.816667 runner-minutes. Different workers, queues and two skipped scope jobs prevent interpreting the 43s whole-cohort difference as a causal speedup estimate. The older accepted-main 30m37 cohort is historical context. No population, percentile or 20–30% routine-CI claim is made from the paired family result.

## Limits and remaining bottlenecks

There was one baseline-then-candidate same-worker pair, with independent cold build trees and no retries or sample selection. The second arm can have warmer OS caches. Nearly unchanged child CPU work, stable unchanged physics work, preserved execution inventory and substantially higher sanitizer CPU utilization support the scheduling explanation without establishing a distribution over hosted workers.

The next latency floor is shared between worldgen around 20–21 minutes, the main TSan family around 19–20 minutes, and GDExtension around 18–21 minutes before its initial queue. Pinned godot-cpp compilation remains a several-minute dependency; bounded SCons parallelism is a smaller next hypothesis than persistent cross-run caching. Verify PR supersession cancellation behavior against the observed wait; its exact cause is not confirmed by a cancellation event record. These follow-ups do not belong in the frozen qualified increment.

**Final verdict: GO, followed by authorized manual merge.** The actual critical family is meaningfully faster, its runner consumption falls, all scientific/sanitizer obligations remain present, complete Windows/Linux qualification passed, and original evidence passed both independently reviewed consumers. The five-workflow post-merge main cohort is being observed separately from the six-workflow Ready cohort.
