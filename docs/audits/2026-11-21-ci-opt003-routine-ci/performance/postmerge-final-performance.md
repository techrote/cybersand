# CI-OPT-003 — final post-merge performance and source qualification

**Verdict: both accepted increments remain qualified on their actual merged source.** PR #722 and PR #723 were manually merged after independent source, failure-contract and paired-performance admission. The final main commit is `662df51cd8409a52332fa7ef15d06d8ab8945aed`, tree `39b658c5de9c5e541312b5190bd5d8ba797c6bed`. Every applicable post-merge job has now succeeded. One real checkout/network failure required a complete GDExtension retry; its elapsed delay and runner consumption are retained below.

This report is the independent performance workstream's final numerical readback. It uses the terminal GitHub job records and original source-bound artifacts; it does not infer a full-pipeline speedup from a single mismatched pair of hosted workers. Times are UTC on 22 November 2026. Runner-minutes are actual accumulated job duration, unweighted by operating system, not GitHub billing units.

## Source and scope

| Delivery | Qualified PR HEAD | Merged main SHA | Identical qualified/merged tree |
|---|---|---|---|
| B: exact-configuration soliding object reuse, [PR #722](https://github.com/techrote/cybersand/pull/722) | `cd32ed95b1c3da1d5e8bbecc8020f68e13fe1d55` | `30e1cddd3d678456df10f52f7a2fb2210a9daaad` | `062f8ec0df0e9f1cb548c11860968301cad0ae16` |
| C: bounded worldgen showcase scheduling, [PR #723](https://github.com/techrote/cybersand/pull/723) | `19023b4016facfda2b13b9a1503742e4a9fe1982` | `662df51cd8409a52332fa7ef15d06d8ab8945aed` | `39b658c5de9c5e541312b5190bd5d8ba797c6bed` |

The two main-push cohorts have the same five applicable workflows: Native, GDExtension, documentation/provenance, Wave Flow, and the report-only source-scope advisory. Palette was applicable to the Ready PR cohorts, not these main pushes. Existing conditional main-policy skips are retained explicitly; they are not counted as successful execution. Each latest successful cohort contains 68 executed jobs: Native 8, GDExtension 54, Wave 4, documentation 1, source advisory 1.

“Last non-advisory validation/coverage gate” below excludes only the explicitly report-only source workflow and the separate retained execution/timing-history job. It does not claim these are branch-enforced required contexts. The integration owner's final branch metadata read reported `protected:false`, required-status enforcement `off`, and empty context/check lists; no protection settings were changed. The separate rules endpoint was not available through the connector. The all-applicable metric conservatively waits for every applicable job, including advisories.

| Workflow | B main, attempt 1 | C main |
|---|---|---|
| Native | [44964966221](https://github.com/techrote/cybersand/actions/runs/44964966221) | [44967548870](https://github.com/techrote/cybersand/actions/runs/44967548870), attempt 1 |
| GDExtension | [44964966242](https://github.com/techrote/cybersand/actions/runs/44964966242) | [44967549040](https://github.com/techrote/cybersand/actions/runs/44967549040), successful attempt 2; failed attempt 1 retained |
| Documentation/provenance | [44964966199](https://github.com/techrote/cybersand/actions/runs/44964966199) | [44967548903](https://github.com/techrote/cybersand/actions/runs/44967548903), attempt 1 |
| Wave Flow | [44964966200](https://github.com/techrote/cybersand/actions/runs/44964966200) | [44967548863](https://github.com/techrote/cybersand/actions/runs/44967548863), attempt 1 |
| Source advisory | [44964966217](https://github.com/techrote/cybersand/actions/runs/44964966217) | [44967548854](https://github.com/techrote/cybersand/actions/runs/44967548854), attempt 1 |

## Observed turnaround and resource cost

| Measurement | B main `30e1cddd` | C main `662df51c` |
|---|---:|---:|
| Source push event | 00:06:03 | 00:37:46 |
| Last non-advisory validation gate | 00:51:55, Native `native` | 01:14:22, Linux coverage |
| Event → last non-advisory gate | **45m52s** | **36m36s** |
| Final all-applicable job | 00:51:55 | 01:14:48, timing history |
| Event → all applicable jobs/advisories | **45m52s** | **37m02s** |
| Native event → aggregate status completion | **45m52s** | **22m46s** |
| First complete Native functional family | 2m09s, soliding-normal | 2m34s, soliding-normal |
| First complete functional job across the cohort | 1m23s, Windows Wave Flow | 1m08s, Windows Wave Flow |
| Qualified jobs in successful attempts | 68 | 68 |
| Executed job attempts, including failed earlier attempt | 68 | 74 |
| Native runner-minutes | 92.200000 | 78.633333 |
| GDExtension successful-attempt runner-minutes | 169.600000 | 175.850000 |
| All successful-attempt runner-minutes | **283.250000** | **275.350000** |
| Earlier failed-attempt runner-minutes | 0 | **19.716667** |
| **All actual runner-minutes** | **283.250000** | **295.066667** |

The final GDExtension run record changed to completed at 01:14:49, one second after its last job. The table consistently uses actual last-job completion. C's source event is the original 00:37:46 push, not the retry API's new attempt creation time. The successful GDExtension retry began at 00:53:35: it needed 20m47s to the last platform coverage gate and 21m13s to its final advisory. Those retry-only windows do not replace the 36m36s/37m02s source-event measurements.

**These post-merge differences are observations, not a controlled performance percentage.** B's worldgen worker was AMD EPYC 7763, whereas C's was Intel Xeon 6975P-C. C also incurred an unrelated network incident and full retry. The full-pipeline cost including that incident increased relative to B despite the lower successful-attempt total. The causal evidence for the delivered optimizations is the predeclared same-worker family comparison below.

The final Ready PR qualifications separately passed all applicable source-matched jobs: B had 76 successful jobs in 30m52s with 290.816667 runner-minutes; C had 78 in 30m09s with 285.416667 runner-minutes. C's two extra jobs are inexpensive Ready-scope policy checks, not a scientific inventory change. C's initial Native wait was 7m26s; its first completed Native family was 10m02s after the event, or 2m36s after its first Native worker began. An older PR Native run was active concurrently. The exact cancellation-request event was unavailable, so the possible `always()` contribution remains a source-supported inference to investigate, not a proven scheduler defect. Main-push Native runs intentionally have separate concurrency identities and are preserved.

### Actual infrastructure failure and complete retry

C GDExtension attempt 1 failed because the planner's checkout exceeded its existing five-minute timeout after two TCP 443 connection failures. The third fetch completed shortly before the action timeout; the planner and scientific commands never ran. The two coverage reducers correctly failed for missing evidence. The original attempt had three successful and three failed executed jobs, plus five conditional skips, consuming **19.716667 runner-minutes**. Its original log is `job-137039883118.log`, with job outcomes in `runtime-postmerge-cohort/jobs-44967549040-first-attempt.json`.

The retry reused no earlier-attempt build or qualification artifact. A fresh independent CI review established that every applicable job descends from the root Ready-scope job; rerunning that root generated a complete new DAG for the same commit. Attempt 2 then passed all 54 applicable GDExtension jobs, with only the two expected main-event policy skips. The original event-to-retry interval was 15m49s, comprising failed execution and recovery time; it is not all queue delay. No watchdog or source was changed, and no performance-driven rerun was requested.

The independent terminal platform review verified 338 Linux cases in 24 exact source-derived shards and 315 Windows cases in 23 shards, with 23 explicit existing graphical exclusions on Windows. Both coverage receipts bind the same commit, tree, run and attempt 2. The source reviewer additionally checked 30 retained play-readback proof/log/output seals. See `../reviews/gde-main-attempt2-final-qualification.json` and `../reviews/gde-main-retry-review.md`; neither admits attempt-1 artifacts as successful qualification.

## What became faster, and what now dominates

| Controlled admission | Baseline | Candidate | Observed saving | Interpretation |
|---|---:|---:|---:|---|
| B complete soliding-normal family | 190.811701s | 108.006146s | 82.805556s; **43.3965%** | Exact-configuration object reuse removed 30 repeated core translation-unit compilations; all eight binaries/tests and normal extras preserved. |
| B complete soliding-ASan family | 1285.232141s | 809.250157s | 475.981984s; **37.0347%** | Same-worker reduction in repeated build work; unchanged standalone compile was slightly slower, and actual eight-test execution stayed approximately 1.9s. |
| C complete worldgen family | 1748.640267s | 1232.409098s | 516.231169s; **29.5219%** | Seven independent showcase programs share the original two-job Make budget; nine ordered main tests still run after all showcases succeed. |

B's two independent family pairs saved 9.313126 runner-minutes in aggregate; this is not a full-CI elapsed percentage. C's one whole-family pair saved 8m36.231s of critical work on the same Intel 6975P-C worker/image/compiler. Within C's pair, normal worldgen fell 241.545314→188.024430s and sanitized worldgen 1407.494205→946.740588s; physics remained 98.950507→97.211714s. Normal plus sanitized CPU work increased only about 8.63s, approximately 0.43%, while elapsed time decreased 514.274502s. Greater overlap, rather than dropped assertions, explains the result.

Both pairs were cold builds with the original complete family executor and fixed immutable arms. C retained 28 compiler/link commands and 16 executable tests in each normal/sanitized configuration, all 154 physics CLI invocations and the original scientific assertions. Independent admission checked all 14 complete source-bound raw showcase output groups. The pairs were baseline-first and one sample per target; they support these bounded observations, not a percentile, population estimate or whole-CI 29.5% guarantee. C's added graph/failure controls lie outside the family proof: its Ready policy job was 44s versus B's 27s, and the post-merge policy jobs were 49s versus 24s. That fixed overhead is included in actual cohort timing.

### Current Native path

| Work on final C main | Elapsed | Worker / implication |
|---|---:|---|
| Native policy job | 49s | Includes 32s of evidence/failure controls and 8s checkout. |
| Worldgen family process | 1237.643927s | Intel Xeon 6975P-C, four logical CPUs, image `20261116.133.1`. Physics 96.371137s; normal 183.684111s; ASan/UBSan 956.941814s. |
| Worldgen allocated job | 20m53s | Seven seconds checkout, about 15.36s total outside the family process; two seconds artifact upload. |
| TSan allocated job | **19m53s** | Intel Xeon Platinum 8573C, four logical CPUs, image `20261116.376.1`; only one minute behind worldgen. |
| TSan actual compile / test | 101.691067s / **1074.530439s** | All 192 cases passed; no retry/mapping-error record. Runtime, not compilation, dominates this family. |
| Native aggregate job | 52s | Checkout 12s; family download 2s; aggregate upload 2s; advisory history 29s; verification under the API's one-second resolution. |

TSan's direct-process telemetry reported 1145.61 CPU seconds and peak RSS 3,915,927,552 bytes, roughly 3.65 GiB. The native test process uses approximately one core on average and runs its case list sequentially. Retained output has case names but no individual case clocks, so the 1074.53s cannot be assigned to a particular fixture. Further worldgen-only acceleration would expose the TSan floor after roughly another minute on this allocation. The existing serial case runner/filter and expensive scientific fixture construction merit targeted profiling before any test-harness proposal; no cases or assertions should be relaxed.

B main's corresponding worldgen process took approximately 2667.833s on AMD EPYC 7763: physics 124.515760s, normal 451.809765s, sanitizer 2090.609546s. Comparing that host to C's Intel worker would greatly overstate the causal optimization. C's source-qualified worldgen family was 1241.791111s in Ready qualification, 1232.409098s in its controlled candidate arm and 1237.643927s after merge, each on the recorded Intel 6975P-C class; this is useful descriptive consistency, not a population estimate.

### Current GDExtension path and next priorities

The successful C retry's Linux build was 590s, starting 00:53:40 and ending 01:03:30. Its pinned `godot-cpp` compilation took **444.575292s**, followed by **110.297674s** for the extension on AMD EPYC 7763. The Windows cross-build used AMD EPYC 9V74 and took 231.103667s for `godot-cpp` plus 53.617850s for the extension, within a 310s build job. Both are Linux-hosted compiler jobs; the regression shards themselves execute on the actual Linux and Windows platforms.

Linux's 24 shards ran in waves from 01:03:33 until 01:13:50. The last shard, number 19, spent 186s executing tests, 16s checking out source and one second restoring its runtime artifact in a 216s allocated job. Windows's 23 shards ran from 00:58:53 until 01:12:16; the last shard, number 21, spent 307s in the test step, 22s in checkout and one second downloading the candidate in a 340s job. Actual test work and preceding build/wave dependencies dominate these tails.

Across those 47 shards, checkout consumed 872s of accumulated runner time, about 14.53 runner-minutes. Runtime artifact downloads/restores consumed 70s, about 1.17 runner-minutes. The main regression execution steps consumed 7827s, 130.45 runner-minutes; those steps include harness/import work, so this is not a sum of pure scientific case CPU. These nested step durations must not be added again to the workflow runner-minute totals. The original performance aggregate contains 753 source/run/attempt-matched records, all passed: 653 case records, 47 preflight imports, four build commands and 49 hosted-job observations.

The next plausible interventions, after preserving the delivered increments, are:

| Priority | Intervention | Evidence and bound |
|---|---|---|
| 1 | Profile TSan case/fixture runtime and preserve its full scientific contract while removing demonstrated duplicated setup. | Actual runtime is 17m54.53s; TSan is already within one minute of worldgen on final main. No per-case attribution or speed estimate is established yet. |
| 2 | Test pinned `godot-cpp` SCons concurrency 2→4 before introducing a cross-run cache. | Final Linux dependency compilation alone is 7m24.58s, ahead of all Linux shards. It is a small build-tooling hypothesis; four logical CPUs do not imply four physical cores or a 2× gain. Existing shell-only CPU/RSS telemetry does not capture compiler descendants, so memory headroom remains unmeasured. |
| 3 | Verify PR supersession cancellation behavior and use retained platform timings to assess shard balance and repeated checkout/setup. | The observed Ready wait was 7m26s, but its exact cause is unproven. The final GDE retry needed 21m13s; raw artifact transfer is small. Larger cache machinery has a greater provenance burden than bounded scheduling/build changes. |

No additional hosted campaign was launched to improve these samples. Rejected compiler ordering PR #721 remains Draft/HOLD because its small measured benefit did not justify delivery; #708 and #718 were left untouched. The final Native and platform paths are now close enough that subsequent useful work should follow both, instead of repeatedly optimizing only worldgen.

## Reproducible evidence and original artifact custody

The terminal numerical inputs are `soliding-postmerge-cohort-summary.json` and `runtime-postmerge-cohort-summary.json`, generated by `audit_cohort.py`. The reader checks terminal job outcomes, complete pagination, source SHA and exact run/attempt identities, and requires every prior attempt snapshot when a retry is admitted. C can be replayed without rerunning tests:

```sh
python3 ci-opt003-evidence/performance/audit_cohort.py \
  ci-opt003-evidence/performance/runtime-postmerge-cohort \
  --expected-attempt 44967549040=2 \
  --prior-attempt-jobs ci-opt003-evidence/performance/runtime-postmerge-cohort/jobs-44967549040-first-attempt.json \
  --output /tmp/ci-opt003-runtime-postmerge-readback.json
```

The pair-specific admission procedures and limitations remain in `soliding-final-performance-verdict.md` and `worldgen-runtime-final-performance-verdict.md`. The original ZIP digests below are complete SHA-256 values. Extraction/admission outputs are separate; original artifacts were not rewritten.

| Original artifact | ID | SHA-256 |
|---|---:|---|
| B paired normal | 14730300616 | `350a46cfd441cd24920829231a05ffb6c6a60614c7c6aeea198fb9d36e19d413` |
| B paired ASan | 14731021438 | `3cd95df73c231f7b305f8b8c724f460528625a56cce0836c4fe7685d8d5d54b3` |
| C complete worldgen pair | 14732380696 | `9411292cbcf416dd56600c37e3e19d85c9b3ca4e1fdf885e6b2bff4cbd4e5238` |
| B main raw worldgen | 14732293333 | `913319f5700a818f25679421f3decdadb4bf87b14395f330ebf2d30a2aae8ab6` |
| B main Native aggregate | 14732861215 | `7ae2b34e7208f1971d283ebdf81c51eb7696bd33c5cce78b5a8b028fce23c2ee` |
| C main raw worldgen | 14732372886 | `7623ee9406fa5e29bb3d17282a52ac3a3bdfb9e6e404cbb5372df64479dd3fcd` |
| C main TSan | 14733270246 | `209c7e6d81be802e25060bf2d1d334d11ee1d06ae04cbc630e869a317888f272` |
| C main Native aggregate | 14733002831 | `afd00cbc21bf17e61d0454278c57fe3ae6dc8fb52bbf4d5dff6f12aa84e19f92` |
| C main Linux coverage, attempt 2 | 14733112711 | `8362b7053f1b37a20a926fc7a8cc82ba328c70c17624567cae5638f50382c3dd` |
| C main Windows coverage, attempt 2 | 14733406653 | `849c9ff66891fd70786795bc4c3fc2d9137c4cd530adf30ab28e02b3bb2b1758` |
| C main GDE performance, attempt 2 | 14733641130 | `ae00a0bdd1f340be0986d91f9061c5c71370da2d600ede30e68d3385328cea6f` |

Linux receipt SHA-256 is `7336f99cacd4191ce43e15afd841fd94758de0bb0dce40cbb545d691d8283e23`; Windows receipt SHA-256 is `47c46df1a52274ee3f627813fe76f618185aa214adbf600ddd5493e516116607`. Native aggregates verify the original six families, 20 command receipts and 192 cases in each core mode at their exact merged sources. Hosted Windows qualification is complete; it does not claim physical owner-machine validation.
