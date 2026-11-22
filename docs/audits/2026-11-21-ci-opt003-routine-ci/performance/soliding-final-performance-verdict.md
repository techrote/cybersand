# PR722 independent performance admission: GO

Reviewed candidate `cd32ed95b1c3da1d5e8bbecc8020f68e13fe1d55`, tree `062f8ec0df0e9f1cb548c11860968301cad0ae16`; baseline `846fe0533b3170e7b01f690518da49fc40cc24d1`. This is an admission for a useful resource and Native feedback improvement. Worldgen remains the critical path, so this change does not establish a reduction in complete routine CI turnaround.

## Controlled execution and what became faster

The predeclared hosted proof ran one cold baseline-then-candidate pair per complete family, using the actual unchanged production family runner. No repeated runs were selected for favorable results. Each arm retained all eight soliding tests, with normal benchmark, apparatus and stage-cost commands also present. Normal and sanitized configurations used separate hosted jobs; each comparison used one worker and identical compiler/configuration within its job.

| Complete workload | Baseline seconds | Candidate seconds | Observed saving |
| --- | ---: | ---: | ---: |
| Soliding normal family | 190.811701 | 108.006146 | 82.805556 seconds / 43.3965% |
| Soliding ASan/UBSan family | 1285.232141 | 809.250157 | 475.981984 seconds / 37.0347% |
| ASan standalone large build, unchanged | 578.847724 | 584.297976 | 5.450252 seconds slower |
| ASan remaining builds | 703.564555 | 222.702237 | 480.862317 seconds saved |
| All eight ASan test executions | 1.912204 | 1.857606 | 0.054598 seconds saved |

The implementation removes thirty repeated core translation-unit compilations per configuration: six shared core inputs previously compiled separately for six binaries are each compiled once into configuration-isolated objects. It changes neither the assertions nor the test execution inventory. The unchanged standalone build became slightly slower while the affected remainder became substantially faster; the measured effect is consistent with eliminating redundant compilation. The eight actual sanitized tests still execute and have essentially unchanged runtime.

The separate family savings sum to 558.787539 seconds, or 9.313126 runner-minutes, as an observed additive component saving. This is not a measured whole-cohort percentage or a promise about future worker models. The normal host was AMD EPYC 7763; the sanitizer host was AMD EPYC 9V74. Both exposed four logical CPUs, used GCC/G++ 13.3.0 and Ubuntu image `20261116.376.1`. Within each pair all host, compiler-binary and environment identities match.

The sanitizer standalone `/usr/bin/time -v` receipts measured baseline user/system CPU 556.02/11.92 seconds, candidate 565.02/11.89 seconds; CPU utilization was 98% for each. Peak child RSS was 8,013,720 versus 8,014,284 KiB. There was no swap. These measurements cover the standalone high-memory build only; the other original production commands do not expose complete descendant CPU/RSS, and no total-CPU saving is claimed. Keeping this approximately 8 GiB compiler job serial avoids a new memory-concurrency hazard.

## Evidence admission and provenance

Proof run: <https://github.com/techrote/cybersand/actions/runs/44961498877>, attempt 1, proof source `fd4921ace2c4f97f06c70b887778b2366d7a9f0f`. It completed successfully. The two proof jobs consumed 40.85 unweighted runner-minutes in total: normal 5m29s, sanitizer 35m22s. Proof event to completion was 35m27s. This is experimental overhead, separate from routine CI savings.

I independently reviewed the frozen offline reader and reran its controls plus five additional malformed-evidence controls. Final reader SHA256: `ab0be75fd3cd58d0af24a2bd44b9dff392bbb6c73ab8729217b53c40dd6a573a`. I independently replayed original raw family/command receipts, test lists, source/configuration contracts, watchdogs, binary inventories, immutable proof fingerprints, natural completion, host identities and original log hashes. Both original artifacts pass.

| Original artifact | ZIP SHA256 | Independent output |
| --- | --- | --- |
| Normal `14730300616` | `350a46cfd441cd24920829231a05ffb6c6a60614c7c6aeea198fb9d36e19d413` | `soliding-normal-pair-strict.json` |
| ASan `14731021438` | `3cd95df73c231f7b305f8b8c724f460528625a56cce0836c4fe7685d8d5d54b3` | `soliding-asan-independent-admission.json` |

The sanitizer ZIP was independently rehashed locally before admission; its extraction remains unchanged. Offline readback results live outside original artifact contents. Synthetic adversarial reader controls are validation of the evidence consumer, not scientific execution evidence.

## Final-source full qualification and limits

The exact PR722 Ready cohort executed 76 jobs successfully across all six applicable workflows. Tested merge `da63e0f3d5a189a67acdc2e1bc47b87d8a946ae5` has the same tree as candidate HEAD. The cohort completed in 30m52s event-to-final-check and consumed 290.816667 unweighted runner-minutes. Native used 82.166667 minutes, with its unchanged worldgen family still the longest job; GDExtension completed in 17m35s and used 168.783333 minutes. First Native functional completion was 2m10s; the first whole-cohort functional result was Windows Wave at 1m14s, which should not be attributed to this change.

Source-matched qualification: Native <https://github.com/techrote/cybersand/actions/runs/44960371733>, GDExtension <https://github.com/techrote/cybersand/actions/runs/44960371856>, Docs <https://github.com/techrote/cybersand/actions/runs/44960371795>, Palette <https://github.com/techrote/cybersand/actions/runs/44960371741>, Wave <https://github.com/techrote/cybersand/actions/runs/44960371730>, advisory <https://github.com/techrote/cybersand/actions/runs/44960371735>. Full raw job data and cohort calculations are in `soliding-cohort/` and `soliding-cohort-summary.json`.

Each controlled pair is one sequential observation, not a population estimate or percentile. The second arm may benefit from OS filesystem warmth despite independent cold build directories. That caveat cannot plausibly account for all of the eliminated compiler invocations, and the unchanged large build provides a useful local counterexample, but a precise general speedup is not established. Historical and other-candidate whole-cohort results use different hosts and are descriptive only.

**Verdict: GO for this independently qualified CI-only increment.** The measured saving is substantial in the changed work, resource cost falls, all required scientific work remains present, and the full applicable Linux/Windows/Native cohort passed. No performance reason remains to hold this small reversible change behind the ongoing worldgen experiment. Root remains the merge owner and should confirm post-merge exact-source required-check behavior.

## Delivered merge and post-merge observation

Root manually merged PR722 after admission review `6009060691`. Accepted main is now `30e1cddd3d678456df10f52f7a2fb2210a9daaad`; I independently verified its tree is `062f8ec0df0e9f1cb548c11860968301cad0ae16`, identical to the qualified PR source. Parent commits are original accepted main `846fe0533b3170e7b01f690518da49fc40cc24d1` and candidate `cd32ed95b1c3da1d5e8bbecc8020f68e13fe1d55`.

The main push cohort began at 2026-11-22 00:06:03 UTC: Native `44964966221`, GDExtension `44964966242`, Docs `44964966199`, Wave `44964966200`, advisory `44964966217`. At 00:09 UTC the advisory passed and the four validation workflows were still running. The applicable push workflow scope differs from the Ready PR cohort (which also ran Palette), so complete-event timings must be reported separately. No post-merge green result is asserted before those jobs finish.
