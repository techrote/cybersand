# CI-OPT-002 rapid delivery — final evidence index

**Final disposition, 21 November 2026:** Stage A merged and post-merge verified. Stage B PR #718 passed every applicable correctness/source gate but remains **Draft/HOLD, not merged**, on the separate final reviewer's performance judgment. No 30% reduction in successful routine CI is claimed.

This is a dated CI engineering record for the exact source identities below. It does not grant permission to skip tests, publish runtimes, or change active development policy. The current operating policy is in `docs/operations/ci-execution-and-performance.md` on the accepted source.

## Delivered first increment

[PR #714](https://github.com/techrote/cybersand/pull/714) merged at `846fe0533b3170e7b01f690518da49fc40cc24d1`, from candidate `68e0261466fc275a095360c63ed6f67311ecc0f6` on accepted base `0f0161af337d6d0cee8fa961a9667aff570a75b0`. Its exact qualified tree is `1232a6e825561ce8b5cd125e1bad7fa6aa7e1590`.

The existing complete documentation and runtime-provenance checks moved ahead of expensive material/LCB compilation. All 22 original step definitions, the stable check context, Draft condition and source/binary controls remain unchanged.

The actual paired stale-source rejection interval fell from **593.895424190 seconds to 2.767057805 seconds**, saving **591.128366385 seconds** after the common post-inventory boundary. Both canonical under-test checks genuinely failed with exit 1. Each proof arm also passed three clean materialized-runtime checks and rejected four actual reversible adverse mutations. Proof success means correct expected refusal, not application qualification.

The positive candidate [Documentation run 44945708005](https://github.com/techrote/cybersand/actions/runs/44945708005) and the exact-merge [post-merge run 44947889002](https://github.com/techrote/cybersand/actions/runs/44947889002) passed every original step and verified all 18 materialized runtimes. No successful routine-CI speedup is inferred from their different durations.

## Stage B measured result and decision

[PR #718](https://github.com/techrote/cybersand/pull/718) retains candidate `65aa1382a49bb01571177b4639f27b64f5dcb66d`, tree `b01d95a8cb90ae0be9fb36e368694167dd80efb6`. Its actual tested merge was `9ae8b2a483d756af18ad21f1d99f529645640f12`, with that same tree. It separates worldgen sanitization from the preceding physics/ordinary-worldgen commands, keeping all 20 commands, every child watchdog and the six-runner cap.

| Actual metric | Six-family control | Seven-family candidate |
|---|---:|---:|
| Required Native result / workflow elapsed | **37m28s** | **37m03s** |
| Unweighted Native runner-minutes | **97.566667** | **102.533333** |
| Initial queue | **3s** | **3s** |
| First successful Native policy result | **34s** | **30s** |
| First completed functional Native family | **3m01s** | **6m30s** |

The elapsed gain was only **25 seconds (1.11%)**, with **4m58s more runner time (5.09%)** and **3m29s later first functional feedback**. The critical host differed: control AMD EPYC 9V74, candidate AMD EPYC 7763. The complete decomposition is 451.438 seconds of removed serial predecessors, plus 7.332 seconds of other launch improvement, offset by 433.054 seconds of longer execution of the identical sanitizer command and 0.717 seconds after it. The removed dependency is real, but is not a measured seven-minute whole-run improvement.

All five Ready-state candidate workflows passed. The complete applicable cohort took **37m03s** and used **299.600 unweighted runner-minutes** across **73 executed jobs**, with **3 explicit conditional skips**. The dedicated control covers Native only; the older accepted-main cohort includes seven workflows. Those differing whole-cohort costs are not a controlled savings comparison.

Independent final judgment: **source/coverage SAFETY GO; PERFORMANCE HOLD**. All 15 Native family/aggregate ZIPs and nine platform ZIPs were independently verified, and each run's own immutable Native verifier replayed exactly to its hosted aggregate. Hosted qualification retained all 653 Linux/Windows Godot cases across 47 shards, all original Native commands, 18 materialized runtimes, Art smoke and current Palette v3 acceptance. Palette's older v2 finished-image diagnostic remains failed and non-gating; universal cross-backend pixel parity is not claimed.

Four already-selected historical Native baselines were checked for a genuinely matching critical CPU/image cohort. Their source and test inputs were compatible, but none matched the candidate's critical host. They remain diagnostic context, not a retrospective replacement headline. No additional hosted campaign was launched to seek a preferred percentage. The Draft transition happened only after all Ready-state runs were terminal and cancelled no qualification.

## Evidence reports

- [Baseline audit](baseline-report.md): 19 selected successful/failed runs; complete routine cohort, source-compatible repeats, expensive publication/graphical examples and bottleneck attribution.
- [Complete baseline job/step measurements](baseline-summary.json): every selected job and step, including failures and conditional skips. Formatting is compact; values match the original audit JSON.
- [Stage A paired report](stage-a-paired-report.md) and [machine record](stage-a-paired-summary.json): exact commands, controls, source/runtime identities, queue, elapsed and runner accounting, limitations and artifact digests.
- [Stage B command equivalence](stage-b-command-equivalence.json): all 20 definitions and child allowances retained, with the sole sanitizer ownership move.
- [Stage B independent source review](stage-b-final-source-review.json): exact candidate and CI-only scope.
- [Stage B production-input equivalence](stage-b-source-equivalence.json): unchanged native/Godot/physics subtrees, Makefile and all 20 command definitions across accepted base, control, candidate and actual tested merge.
- [Stage B platform review](stage-b-platform-review.md), [machine record](stage-b-platform-review.json) and [final artifact cross-check](stage-b-platform-final-spotcheck.json): actual Linux/Windows binaries, all 653 Godot cases, Documentation provenance and current Palette acceptance.
- [Stage B actual local adverse controls](stage-b-local-adverse-summary.json): rapid local pushes, source drift, stale lease and failed/terminated workers. This is local Git/process/verifier evidence, separate from hosted qualification.
- [Merged source scope](merged-source-scope.json): exactly the two Stage A paths reached main. [Candidate comparison](cumulative-source-scope.json) separately includes the unmerged Stage B proposal.
- [Stage B paired Native report](stage-b-native-paired-report.md), [machine record](stage-b-native-paired-summary.json), [control receipts summary](stage-b-control/summary.json) and [candidate receipts summary](stage-b-candidate/summary.json).
- [Candidate full cohort](stage-b-candidate-cohort.md) and [measurements](stage-b-candidate-cohort.json).
- [Historical compatibility diagnostic](historical-native-diagnostics/report.md) and [machine record](historical-native-diagnostics/summary.json).
- [Independent final judgment](final-verdict.md), [machine verdict](final-verdict.json) and [Native artifact/replay cross-check](native-final-spotcheck.json).
- [Current CI routing guide](ci-policy.md): routine checks, publication, complete acceptance and research at accepted main, which still has six Native families.
- [Retention manifest](retention-manifest.json): retained-file hashes and the distinction between original reviewer hashes and the navigation-only adaptation in this report copy.

Raw native/scientific logs, runtime/build artifacts and proof archives remain with their original Actions runs. This report branch contains measurements and review records, not compiled outputs, runtime binaries or replacement qualification artifacts. Original failures retain their original status.

## Observed scheduling tradeoff

In the contemporary pair, the first successful Native policy result arrived at 34 seconds in the control and 30 seconds in the candidate. The first completed functional Native family arrived later: 181 seconds for the control's short soliding family versus 390 seconds for the candidate's worldgen family. Prioritizing longer work under the same six-runner cap improves no metric by definition; the final required aggregate time establishes only the 25-second observed difference. This tradeoff is retained alongside the measured final timing rather than omitted.

## Historical implementation disposition

[PR #708](https://github.com/techrote/cybersand/pull/708) remains Draft/HOLD at unchanged head `11e23b392b63dfb15ea0916c90ca8d9361d3406b`. Its obsolete former-#691 parent stack was not merged. Stage A recovers the earlier-admission idea using the complete existing checker and its original Draft condition. The old publisher request/lease changes require adaptation to a current owner; Palette preflight and shared Godot acquisition remain unqualified follow-up proposals. Ordinary main pushes already avoid the full 80-Gentek campaigns, so those historical trigger changes do not shorten the measured current routine path.

## Measurement boundaries

Workflow elapsed wall time is event creation to the last actually executed job completion. The mandatory-check critical path ends at the required aggregate and includes its dependencies; a later optional collector is accounted for separately. Runner-minutes sum actual job start-to-completion intervals, including failures, without platform billing multipliers. Initial queue delay is separate. Later waits may include dependencies, bounded matrix scheduling and runner queues; they are not all labelled queue delay.

A failed or cancelled worker cannot be counted as successful qualification. Conditional scope skips are preserved explicitly. The old accepted-main seven-workflow cohort and the Stage B five-workflow candidate have different applicable scopes, so their total runner-minutes are not a controlled cost comparison. The dedicated six-family Native control and seven-family candidate preserve the same 20 command/test definitions and application source; their direct comparison is the appropriate Native scheduling measurement.

Both paths begin on fresh hosted runners without a restored compiler cache. No warm-cache or broad percentile claim is available. Separate workers can differ in CPU/storage speed. A single contemporary pair plus retained historical variability supports an observed result with limitations, not a universal 30% guarantee.

The owner-authorized first increment was merged before deeper optimization began. No auto-merge, paid runner, production behavior change, runtime publication or modification/cancellation of unrelated missions was performed.
