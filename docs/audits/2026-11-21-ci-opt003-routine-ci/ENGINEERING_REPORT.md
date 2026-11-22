# CyberSand CI-OPT-003 — engineering report

**Two independently qualified CI improvements were manually merged into main.** PR #722 removes redundant soliding compilation. PR #723 accelerates the original worldgen workload through bounded execution of independent showcases. The controlled whole-worldgen family improved from **29m08.640s to 20m32.409s**, an **8m36.231s saving, or 29.52% in that one same-worker pair**. All scientific and platform obligations were preserved.

**Final main is qualified at `662df51cd8409a52332fa7ef15d06d8ab8945aed`.** Native and the complete Linux/Windows retry passed on that exact commit. The final coverage gates completed 36m36s after the original event; all applicable jobs, including the advisory timing aggregate, completed in 37m02s. The recovered cohort consumed 295.0667 unweighted runner-minutes, including the failed checkout attempt. This is not a clean whole-CI speed experiment.

## Contents

1. **Delivered improvements** — exact PR, source, tree, merge and independent-review identities.
2. **Before and after performance** — controlled component measurements and actual complete CI cohorts, with their scope and uncertainty.
3. **What became faster** — eliminated compilations and increased use of already allocated CPU capacity.
4. **Coverage, provenance and failure evidence** — unchanged scientific inventory, adversarial controls and original artifact custody.
5. **Rejected and deferred approaches** — experiments stopped when they failed the value gate, plus proposals that were not implemented.
6. **Remaining bottlenecks** — the observed next limits and bounded follow-up investigations.
7. **Owner handoff and rollback** — delivered state, reproducible evidence, Windows qualification and reversal instructions.

## 1. Delivered improvements

| Increment | Disposition | Exact implementation HEAD | Exact manual merge |
| --- | --- | --- | --- |
| [#722 — soliding object reuse](https://github.com/techrote/cybersand/pull/722) | Merged | `cd32ed95b1c3da1d5e8bbecc8020f68e13fe1d55` | `30e1cddd3d678456df10f52f7a2fb2210a9daaad` |
| [#723 — worldgen showcase concurrency](https://github.com/techrote/cybersand/pull/723) | Merged | `19023b4016facfda2b13b9a1503742e4a9fe1982` | `662df51cd8409a52332fa7ef15d06d8ab8945aed` |
| [#721 — worldgen compiler ordering](https://github.com/techrote/cybersand/pull/721) | Draft/HOLD; insufficient measured value | `506dfc8c343c5d24fe26e89a9542cf985c52853e` | Not merged |

The accepted starting main was `846fe0533b3170e7b01f690518da49fc40cc24d1`. The first improvement was delivered as soon as its independent source review, full applicable hosted qualification and controlled measurements passed. The second was then reconciled onto that accepted main without changing its implementation HEAD. There was no auto-merge.

### Source correlation

| Identity | Soliding increment | Worldgen increment |
| --- | --- | --- |
| Qualified and merged tree | `062f8ec0df0e9f1cb548c11860968301cad0ae16` | `39b658c5de9c5e541312b5190bd5d8ba797c6bed` |
| Tested PR merge checkout | `da63e0f3d5a189a67acdc2e1bc47b87d8a946ae5` | `5c56bce96881291c57cea6575e1f4d5fb89485cc` |
| Controlled proof commit | `fd4921ace2c4f97f06c70b887778b2366d7a9f0f` | `cc22fb8ffbba2a7c18a0bc1c0ad60413ad5c3147` |
| Final admission review | [6009060691](https://github.com/techrote/cybersand/pull/722#pullrequestreview-6009060691) | [6009201962](https://github.com/techrote/cybersand/pull/723#pullrequestreview-6009201962) |

Both actual merge trees were checked against the qualified trees after merging. Worldgen's proof baseline `cd32` and accepted base `30e1` have identical trees. A prospective Git merge also produced the expected final tree before admission. No success from the superseded worldgen source `28ec075` counted toward final qualification.

Fresh reviewers did not author the production changes. Separate source/scientific, workflow/failure and performance reviews examined the implementation and original evidence. The first worldgen review found a reproducible P2; the source was repaired and reviewed again. Final inventory review independently checked the exact Git file identities and full before/after plans. The retained reviews are under `reviews/`; performance decisions are under `performance/`.

No production algorithm, gameplay default, scientific fixture, published runtime binary or provenance manifest was changed. PR #714 remains preserved. PRs #708 and #718 remain untouched Draft/HOLD. Programme #706 remains open.

## 2. Before and after performance

### Controlled measurements

Each configuration received one predeclared cold baseline-then-candidate pair on the same worker, with the original complete production family runner. No repeated campaign selected a favorable host or sample.

| Complete measured family | Baseline | Candidate | Observed saving in the pair |
| --- | ---: | ---: | ---: |
| Soliding normal | 190.811701s | 108.006146s | 82.805556s / 43.40% |
| Soliding ASan/UBSan | 1285.232141s | 809.250157s | 475.981984s / 37.03% |
| Worldgen, including physics characterisation | 1748.640267s | 1232.409098s | 516.231169s / 29.52% |

The two soliding savings sum to **9.3131 runner-minutes of family execution**. They come from two separately hosted configurations; they are not an elapsed time for a single complete CI cohort. Worldgen saves **8.6039 minutes of execution on the actual critical family** without adding a worker or matrix family.

The normal soliding host was AMD EPYC 7763; its sanitized host was AMD EPYC 9V74. Worldgen used Intel Xeon 6975P-C. Every pair used the same worker, compiler binary identities and environment within that pair. Worldgen used GCC 13.3, Ubuntu image `20261116.133.1` and four logical CPUs. The pairs were sequential, so the second arm could benefit from warmer OS caches despite a cold build directory. These observations establish the measured changes in these executions, not a percentile or reliable population-wide percentage.

The original proof jobs consumed **47.7833 runner-minutes** for the rejected compiler-order experiment, **40.85** for soliding and **50.15** for worldgen. These are experimental costs, separate from routine CI consumption.

### Actual complete PR cohorts

| Exact candidate cohort | Applicable executed jobs | Event to final applicable check | Unweighted runner-minutes | First completed Native family |
| --- | ---: | ---: | ---: | ---: |
| #721, compiler-order experiment | 76 | 29m59s | 292.2833 | 3m05s |
| #722, accepted soliding change | 76 | 30m52s | 290.8167 | 2m10s |
| #723, accepted worldgen change | 78 | 30m09s | 285.4167 | 10m02s |

The two additional #723 jobs were cheap Ready-state scope checks, not extra or omitted scientific cases. That cohort includes **7m26s of initial Native waiting** behind a superseded run. Its GDExtension workflow included **4m06s of initial waiting** and finished in 25m04s. Those delays remain in event-to-completion measurements; they are not silently removed to advertise a faster total.

First completed functional feedback across all workflows was Wave at 1m26s for #721, Windows Wave at 1m14s for #722, and Wave at 1m26s for #723. Planning jobs are excluded from that definition. The Wave source was unchanged, so these differences are not attributed to the optimizations.

Worldgen's final PR receipt measured 1241.791111s, or 20m41.791s, on a separate Intel Xeon 6975P-C worker. That is another real execution of the candidate, close to the controlled candidate's 20m32.409s. It does not turn the single baseline/candidate pair into a population estimate.

The worldgen family pair excludes the additional pre-matrix infrastructure controls. The Native policy job took 27s for B and 44s for C in separate hosted cohorts; its failure-control step took 11s and 30s respectively. This observed 17s job increase is retained as overhead, with the worker difference acknowledged.

### Exact merged-main cohorts

| Exact merged source | Qualified executed jobs | Event to last non-advisory validation gate | Event to all applicable jobs | Unweighted runner-minutes |
| --- | ---: | ---: | ---: | ---: |
| `30e1cddd` — soliding | 68 | 45m52s | 45m52s | 283.25 |
| `662df51c` — soliding + worldgen | 68, plus 6 failed-attempt job executions | 36m36s | 37m02s | 295.0667 total; 275.35 latest successful attempts + 19.7167 failed attempt |

“Validation gate” identifies the workflow's source-qualified Native/platform reducer. Fresh main-branch metadata reports `protected: false`, required-status enforcement `off` and no listed contexts; the separate rules endpoint was unavailable through the approved connector. No branch-protection or ruleset setting was changed. Timing labels describe the mission's complete workflow admission obligations rather than claiming branch-enforced contexts. The final GDExtension advisory history job finished 26 seconds after the Linux gate. Full-cohort timings include that job, and all resource totals include applicable advisory work.

Final-main Native completed in **22m46s** from the original event, with the first Native family at **2m34s**. First functional feedback across workflows was Windows Wave at **1m08s**; its unchanged source means this is not an attributed optimization result. The complete GDExtension retry took **21m13s** from its own start and **175.85 runner-minutes**. All 54 executed platform jobs passed, with only the two original event-inapplicable jobs skipped. The original event to retry-start interval was 15m49s and remains part of the 37m02s cohort total.

The soliding-only main cohort completed all 68 applicable executed jobs in **45m52s**, consuming **283.25 unweighted runner-minutes**. Its worldgen receipt took 2667.833s on AMD EPYC 7763, Ubuntu image `20261116.376.1`; the identical-tree Ready cohort had used Intel Xeon 6975P-C. This is a concrete example of hosted variability, not evidence that the source change regressed runtime.

The final-main Native workflow passed at source `662df51cd8409a52332fa7ef15d06d8ab8945aed`. Its worldgen job took 20m53s and TSan 19m53s. Exact command-level receipts and final aggregate timings are retained in the post-merge evidence.

**A real infrastructure failure is retained in the final-main accounting.** GDExtension attempt 1 lost two GitHub TCP/443 checkout attempts (133.700s and 136.446s). Its third fetch returned just before the existing five-minute planner-checkout watchdog expired. The planner never executed, and both coverage reducers correctly failed because mandatory evidence was missing. The failed attempt consumed **19.716667 runner-minutes across six executed jobs**; it is not successful qualification.

The complete retry began at 00:53:35 UTC, under attempt 2 of the same run and unchanged main SHA. Independent DAG review confirmed that retrying the shared root recreates the planner, both builds, every applicable shard and final reducers. Source/run/attempt names isolate its artifacts from attempt 1. Final elapsed time stays anchored to the original 00:37:46 event, including recovery delay and both attempts; the retry's own duration is also reported separately. This recovered main cohort is not a clean successful-CI performance experiment. No source, watchdog or acceptance policy changed in response to the network failure.

The two CI-only main pushes have the same five applicable workflow scopes: Native, GDExtension, Documentation/provenance, Wave and the source-scope advisory. Palette also ran in the full PR qualification cohorts. This event-scope distinction is explicit; a reduced scope is not presented as a speed improvement. Complete main-source timing and runner accounting are retained in [the independent post-merge analysis](performance/postmerge-final-performance.md) and its machine-readable cohorts.

The older accepted-main observation of 30m37s and 298.70 runner-minutes, and the later approximately37-minute Native experiment, informed diagnosis. Their source, event scope and workers differ, so neither substitutes for qualification or a controlled comparison of these candidates.

## 3. What became faster

### Soliding: repeated compilation disappeared

Six soliding executables each compiled the same six core translation units. Per normal or sanitized mode, the old complete build performed 44 translation-unit compilations. The new build performs 14: one configuration-bound object set for the shared core, followed by the same original test binaries and link order. **Thirty duplicate compilations disappear per mode**, while all eight test executions remain in their original order.

The local object identity includes compiler and component bytes, compiler identity, exact flags, relevant environment, core source/header contents, Makefile and helper identity. Atomic publication prevents a failed or interrupted compiler from publishing a partial object. Normal and sanitized objects are isolated. There is no cross-run result cache.

The controlled sanitized commands show the mechanism directly:

| Sanitized component | Baseline | Candidate |
| --- | ---: | ---: |
| Unchanged standalone large build | 578.847724s | 584.297976s |
| Remaining soliding build | 703.564555s | 222.702237s |
| All eight test executions | 1.912204s | 1.857606s |

The unchanged large build became slightly slower, while the affected build became substantially faster. Its peak child RSS stayed about 8.0 million KiB and it remained serial. That avoids introducing a new memory-concurrency risk. The normal benchmark, apparatus and stage-cost commands also remain present.

### Worldgen: the allocated worker executes independent cases concurrently

The rejected experiment exposed the real cost: the seven sanitized showcases spent roughly 14m36s in one serial shell loop. Reordering heavy compiler prerequisites barely affected completion.

The accepted change gives each independent showcase its own phony Make execution target. The existing two-job Make limit applies to both compilation and execution. Every showcase must complete successfully before the original nine principal test recipes execute in their original order. Warm binaries still run all tests. Default showcase invocation paths have no shared-file writes; exporters and benchmarks require arguments absent from CI.

| Whole-worldgen component | Baseline | Candidate | Difference |
| --- | ---: | ---: | ---: |
| Unchanged physics characterisation | 98.950507s | 97.211714s | 1.738794s |
| Normal generation target | 241.545314s | 188.024430s | 53.520884s |
| ASan/UBSan generation target | 1407.494205s | 946.740588s | 460.753617s |

The sanitizer target supplies almost all the critical saving. Its measured child user CPU was 1655.38→1658.36s and system CPU 19.39→19.09s, while utilization rose 118%→177%. Normal utilization rose 143%→187%. Combined normal and sanitized child CPU increased only 8.63s, about 0.43%, while their elapsed time fell 514.27s. The original work is still performed; more of the already allocated worker is useful at once. Peak child RSS stayed about 1.696 GB, with no swap. These are child maxima, not a measurement of simultaneous process-tree aggregate memory.

There is no extra Native family, added runner, reduced assertion set, changed optimization/sanitizer flag, or reused test outcome. The two commands add output grouping, with durable raw output retained separately to preserve interrupted diagnostics.

## 4. Coverage, provenance and failure evidence

### Preserved inventory

| Obligation | Before and after |
| --- | --- |
| Native families | Six, with original maximum parallelism 6 |
| Native outer command obligations | Twenty; only two worldgen argv additions for output grouping |
| Core registry | 192 named cases in each original normal/ASan/TSan configuration |
| Worldgen per mode | 28 compiler/link commands, 12 objects, 16 binaries and 16 executions |
| Worldgen execution structure | Seven required showcases, then nine ordered principal tests |
| Physics characterisation | All 154 invocations, with original assertions reapplied to proof outputs |
| Soliding per mode | All eight original executables and ordered tests |
| Linux platform plan | 338 cases across 24 shards |
| Windows platform plan | 315 cases across 23 shards |
| Published runtime provenance | Both manifests and 105 source-input hashes unchanged |

Graphical, Water/Wave, Gentek and save/reopen obligations remain where applicable in the original platform plans. Required contexts, Draft/Ready execution policy, provider restrictions, failure artifacts, source/run/attempt binding and watchdog budgets are preserved. The final reducer cannot succeed with missing mandatory evidence.

The complete machine inventories are `contract-soliding.json` and `contract-worldgen-runtime.json`. The corrected worldgen contract has SHA256 `0e5e0b310191ca472788f6f7e7ca21413e577d3591835a136409fce59e811bf6`. Independent final review checked all 92 workflow inventories, exact changed/unchanged files and supporting artifact digests, and explicitly separated inherited soliding changes from the worldgen increment.

### Adversarial and failure controls

The soliding infrastructure was exercised against changed compiler/configuration, changed source/header contents with preserved timestamps, deleted/corrupt configuration, incompatible normal/sanitized builds, interrupted compilation, failed test execution and warm object reuse. Actual Make/GCC controls verify behavior rather than merely repeating expected decisions in mocks. A failed test stops the remaining original tests; a failed compiler cannot publish a partial object.

Worldgen graph tests cover all original compiler/test identities, duplicate or missing showcases, missing/partial binaries, reversed scheduling, the shared two-job cap, warm re-execution, keep-going failure, replay failure and the principal-test barrier. The current suites contain 21 graph controls, 51 Native reducer controls and 22 Native watchdog controls. Their local process doubles test infrastructure; actual scientific qualification comes from the hosted executions.

The first source review found **P2 WGEN-RUNTIME-P2-01**. GNU Make output grouping could discard a hung peer's flushed stdout/stderr when the real watchdog terminated Make. The repair writes each case's combined output directly into a source/run/attempt/binary-bound raw file before replay, preserves original child failure priority, and always uploads the raw directory. Successful aggregation requires exactly fourteen current raw logs.

Two non-author reviewers repeated the actual Make/production-watchdog timeout and SIGINT reproduction. Both streams survive, the peer is reaped, the principal tail never runs and the receipt remains incomplete/failed. This explicitly qualifies those tested paths; it is not a blanket assertion about every abrupt termination mechanism. The final hosted worldgen artifact and reducer retained all fourteen logs. [The review thread](https://github.com/techrote/cybersand/pull/723#discussion_r4655537208) was resolved only after that evidence was attached.

### Evidence consumers were also reviewed

The first compiler-order proof's original summary reader could admit malformed raw command inventories. Its summary is not used for admission. A corrected independent strict reader checks all original command/test records and source identities; eighteen positive/adverse controls pass.

For the worldgen proof, independent malformed-evidence tests found that raw log hashes alone did not tie the files to complete replay blocks. A first supplemental substring check also admitted a truncated raw prefix and a contradictory duplicate header. The final supplement requires unique context headers, adjacent case markers and equality with the entire source-derived replay group. Five supplied and five fresh independent controls pass, including legitimate multiline, reverse-order and interleaved-compiler cases. Local process-double replay used Make 4.4.1; the actual hosted artifact uses Make 4.3 and passed the final reader too.

Both the unchanged canonical reader and the corrected supplement independently passed the same original hosted worldgen artifact. All 680 extracted files remained byte-identical afterward. No hosted rerun was used to repair an offline consumer.

## 5. Rejected and deferred approaches

**PR #721 remains Draft/HOLD.** Its complete source qualification passed, but the controlled normal target saved 6.480146s and the sanitized target 8.495511s. Their sum is 14.975657s, about 1.06% of those two separately hosted targets, not a complete-family percentage. Compiler CPU did not disappear. No further campaign tried to justify it. The useful finding was the dominance of serial showcase execution.

**PR #718 remains untouched Draft/HOLD.** Its earlier seventh-family experiment had already shown only 25s improvement in Native completion, more runner consumption and slower first functional feedback on mismatched hosted CPUs. It was used as experimental context, not imported as an assumed optimization.

**PR #708 was not imported or merged.** Exact dependency reuse, publisher admission and other historical ideas require their own current-source justification. The delivered changes use small local build identities and existing concurrency rather than introducing a cross-run cache or a new publisher dependency.

Higher optimizer settings, removed fixtures, relaxed sanitizers, increased watchdogs, extra runner families and reduced platforms were not used to obtain the results. These are scope exclusions, not claims that every such idea received an experiment.

## 6. Remaining bottlenecks

The final merged-source Native receipt puts worldgen at **1237.643927s** on Intel Xeon 6975P-C and TSan at **1178.306377s** on Intel Xeon Platinum 8573C. TSan is only **59.34s behind** at family level. Its actual command receipts separate **101.691067s of compilation** from **1074.530439s of test execution**, with all 192 cases passing. The test binary used 1145.61 CPU-seconds, about 106.6% utilization, and approximately 3.65 GiB peak direct-process RSS. Runtime is the next Native floor; removing more worldgen time alone has little headroom on this worker allocation.

The existing TSan harness flushes case completion lines and supports a name filter, but it has no per-case clock records. An output count is not a timing attribution. The next bounded investigation should time the unchanged cases before selecting an intervention; do not split, skip or reduce tests based on a guess.

Final-main GDExtension's complete retry finished in **21m13s**, close to Native's **22m46s** complete workflow. Linux compilation and the last matrix wave determined that retry's platform path. The recovered whole cohort finished later because the initial checkout failure delayed the retry. These are separately observed workflow windows; subtracting recovery delay is not presented as a measured healthy whole-cohort result.

The final GDExtension retry measured pinned godot-cpp compilation at **444.575292s on Linux** and **231.103667s for the Windows cross-build**, followed by extension compilation at 110.297674s and 53.617850s. These compiler jobs ran on AMD EPYC 7763 and 9V74 respectively; actual regressions ran on their designated Linux and Windows workers. The last Linux shard used 186s for its test step, 16s for checkout and one second for artifact restore within a 216s job. Across all 47 platform shards, checkout cost 14.53 accumulated runner-minutes and artifact restoration 1.17; substantive tests and preceding builds dominate. These nested step durations are already included in the workflow totals.

The next investigations should be bounded by these observations:

| Intervention | Potential value and evidence | Risk and next gate |
| --- | --- | --- |
| Profile the TSan runtime floor | 17m54s of actual test execution sits only about a minute behind worldgen in final main. | Add light timing around unchanged cases before proposing runtime or scheduling work; preserve all 192 cases, instrumentation and state assumptions. |
| Verify PR supersession cancellation behavior | A superseded Native job held the group and imposed 7m26s initial wait on C. This is observed iteration latency. | The 7m26s wait is observed; attribution to the existing job-level always() condition is an inference because the cancellation-request log was unavailable. Reproduce before changing cancellation policy; retain final failure aggregation and artifacts. |
| Measure godot-cpp build concurrency 2 versus 4 | Both builds currently use two SCons jobs on four-logical-CPU workers; dependency compilation is a several-minute stage. | These workers can expose two physical cores with SMT. More jobs are a hypothesis, not a 2× claim; measure descendant CPU/memory and preserve exact toolchain/ABI inputs. |
| Improve existing shard balance from admitted history | Long platform shards can start in late scheduling waves; the existing scheduler supports source-bound cost profiles. | Use its minimum multi-run, both-platform admission. A model of one cohort is not a delivered speedup, and the other workflow may become the completion floor. |
| Immutable dependency reuse | Could remove repeated pinned dependency compilation. | Higher provenance and cache-invalidation complexity; exact source/compiler/flags/ABI and trusted artifact custody must be enforced. It ranks behind a small concurrency experiment. |

The initial C qualification's Windows tail shard took 437s, with 404s in the harness; its GDExtension execution after the first worker began was 20m58s. Different worker assignments explain why an unchanged platform workflow varies substantially. These observations identify work to measure; they do not establish a promised saving for a future platform change.

No additional hosted campaign was started for these hypotheses. The delivered increments were not held behind a larger cache or scheduling architecture project.

## 7. Owner handoff and rollback

Both new CI-only PRs are manually merged. #721, #708 and #718 remain Draft/HOLD research; #714 remains accepted. No unrelated feature branch was rewritten or merged, no auto-merge was enabled and no production default or runtime artifact was promoted.

The actual Linux and Windows hosted regression workflows qualified the implementation source. No physical Windows 11 desktop/UI session was performed or claimed. This mission changed CI/build infrastructure and retained existing platform requirements; it did not introduce a new gameplay acceptance claim.

### Reproducible evidence

The repository evidence branch is `ci/ci-opt-003-evidence-20261121`. It contains the full machine inventories, original finding/repair records, independent reviews, strict reader controls, complete cohort accounting and exact source map. The frozen proof commits contain their own producer and canonical consumer code. Readbacks load trusted code from those immutable Git sources, not executable code from artifact contents.

[OFFLINE_REVIEW.md](OFFLINE_REVIEW.md) gives exact source commits, artifact layout and commands for repeatable readback. The privately supplied `CyberSand_CI_OPT_003_original_evidence.zip` preserves eight unmodified original GitHub artifact ZIPs: all controlled comparisons and selected final Native receipts. Its SHA256 is `c4acd79239032db6c01b9a9484a48958bd3a9ac16ddc56938862304b6c5fce8d`. The nested manifest records every run, attempt, source role and original digest. It is not a complete backup of every platform artifact; other original logs remain linked through the CI runs. A separate `CyberSand_CI_OPT_003_postmerge_evidence.zip` preserves seven original post-merge Native and platform coverage archives, including final main's raw worldgen and TSan evidence and both attempt-2 platform receipts. Its SHA256 is `826c66f04d0f1738919b2ddb7d45e3620c69fdc1bee146088c1f333e0d0ac455`; [postmerge-original-artifact-manifest.json](postmerge-original-artifact-manifest.json) records the exact contents. Neither archive contains Git-backed source or replaces the original hosted qualification.

| Proof | Run | Original artifact(s) |
| --- | --- | --- |
| Rejected compiler ordering | [44959131042](https://github.com/techrote/cybersand/actions/runs/44959131042) | 14729210780, 14730460793 |
| Accepted soliding reuse | [44961498877](https://github.com/techrote/cybersand/actions/runs/44961498877) | 14730300616, 14731021438 |
| Accepted worldgen concurrency | [44963259696](https://github.com/techrote/cybersand/actions/runs/44963259696) | 14732380696 |

The admitted soliding reader SHA256 is `ab0be75fd3cd58d0af24a2bd44b9dff392bbb6c73ab8729217b53c40dd6a573a`. The worldgen reader is `6579cc7476996764cb21b4bfabd90bd3948d55c5e1d1c7c29b10e3c31c06a7a5`, and its mandatory supplemental auditor is `540c4f5490529ec61f767736be8c23bc3451b0e1f383ec9ad5b0e7ce10e69c7a`. The worldgen artifact ZIP digest is `9411292cbcf416dd56600c37e3e19d85c9b3ca4e1fdf885e6b2bff4cbd4e5238`.

Offline admission requires the original extracted evidence, Git history containing the specified source/proof commits, Python 3 and GNU Make. Use the frozen reader with the exact run ID/attempt and explicit repository path; worldgen additionally requires the corrected supplement against the same unchanged extraction. The retained readbacks and reviewer reports document the actual invocations and results. No new live provider or scientific run is needed to recheck those existing artifacts.

### Reversal

A reviewable rollback branch can revert the worldgen merge first with `git revert -m 1 662df51cd8409a52332fa7ef15d06d8ab8945aed`. If both increments must be removed, then revert `30e1cddd3d678456df10f52f7a2fb2210a9daaad` in reverse merge order. Resolve any later accepted-source conflicts explicitly and rerun applicable source-matched qualification. No runtime migration, production binary republishing or gameplay setting change is required by these CI-only reversals. No rollback has been executed.

**Owner status:** both qualified CI-only improvements are already on main; no merge action remains. Final hosted source qualification is complete, with the failed infrastructure attempt and successful full retry explicitly retained. There are no outstanding review threads on the delivered PRs. Physical Windows UI acceptance was not run. The next engineering priority is measured TSan runtime and the competing platform build/shard path, while the supersession cancellation hypothesis needs direct verification. No third unqualified optimization, automatic merge or extra performance-selection campaign was started.
