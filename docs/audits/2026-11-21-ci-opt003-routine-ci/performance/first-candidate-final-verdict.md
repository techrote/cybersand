# PR721 independent final performance verdict — HOLD

**Do not merge PR721 as a CI performance improvement.** Exact-source functional/safety qualification passes, and the intended heavy-compiler overlap occurs, but the predeclared same-worker comparisons demonstrate only small target savings. No additional hosted samples should be spent trying to justify this scheduling experiment. Preserve its useful diagnosis and redirect implementation to actual serial showcase execution.

## Exact evidence

Candidate `506dfc8c343c5d24fe26e89a9542cf985c52853e`; accepted baseline `846fe0533b3170e7b01f690518da49fc40cc24d1`; proof `371b9aef07e75cf99e20417884402a22a9ad58da`. [Proof44959131042](https://github.com/techrote/cybersand/actions/runs/44959131042), attempt1, both jobs successful.

Original artifacts independently downloaded and SHA256-verified against GitHub:

| Target | Job | Artifact | ZIP SHA256 |
| --- | --- | --- | --- |
| Normal |137013797991|14729210780|`ae9e84dba2ededf27a863e28278649f45c0a8999360a9fc7cd85d75e6e2f2185`|
| ASan/UBSan |137013798101|14730460793|`33c9948018df1916b1c8b87270fd8385dfd82a959b59f2ee1e7e84c4692602db`|

Final independently reviewed strict reader SHA256 `ee58321a5cfab2b27edd7f1ac6383a85e8244cd7496c784facc1690127295eb8` admits both artifacts. Its18 positive/adverse controls were independently rerun. Separate independent raw-command interval accounting agrees. The original weak comparison.json is not an authority.

Every arm contains28 compiler/link invocations,12 object compilations,16 original test binary executions across10 shell recipes, original compiler/sanitizer flags and source-bound successful watchdog evidence. Maximum compiler concurrency remains2. Source is unchanged before/after, and source/instrumentation identities match frozen Git.

## Observed target performance

| Target | Baseline | Candidate | Observed saving |
| --- | ---: | ---: | ---: |
| Normal target |235.386537s|228.906391s|6.480146s (2.752981%)|
| Sanitized target |1180.636648s|1172.141137s|8.495511s (0.719570%)|

The sum of target measurements is1416.023184→1401.047528s, a14.975657s difference (1.057586%). This is a sum across **two different hosted target pairs**, not an observed complete-family or routine-CI percentage. Normal used Intel Xeon6975P-C/image20261116.133.1; sanitized used AMD EPYC9V45/image20261116.376.1. Both exposed4 logical CPUs/2 physical cores. Within each target, baseline and candidate used the exact same worker/compiler sequentially, with cold build directories and no artifact/result cache. OS caches may be warmer for the second arm.

## What actually happened

| Sanitized raw-accounting measure | Baseline | Candidate |
| --- | ---: | ---: |
| Compiler interval union |233.664842s|245.187713s|
| Test interval union |946.586840s|949.474410s|
| Compiler/test overlap |0s|22.846556s|
| Two heavy generator objects overlap |0s|42.787120s|
| Compiler user CPU |439.311186s|439.860907s|
| Compiler system CPU |18.363366s|19.134650s|
| Largest compiler-child RSS |1697524KiB|1697404KiB|
| Largest test-child RSS |632160KiB|632608KiB|

No computation was removed. Both heavy generator objects start at once under the candidate, but unchanged other compilations shift later; compiler union increases11.523s. The unchanged showcase test loop starts11.368s earlier, overlaps remaining compile work, and then takes3.954s longer. Overall sanitizer saving is only8.496s. This directly explains why a visually better compilation schedule barely changes completion.

Actual test runtime dominates. The seven-showcase serial sanitized loop takes876.034s before and879.988s after, about14m36s. Baseline case intervals, derived from original timestamped stdout markers within the verified serial loop, are:

| Showcase | Sanitized seconds |
| --- | ---: |
| Megatruss station |68.803|
| Seeded typology megablock |202.243|
| Metabolist spine |185.095|
| Interlaced viaduct |59.154|
| Rosework gatehouse |131.862|
| Interlock brutalism |102.823|
| Suspended arcology |126.054|

These intervals include tiny shell/printing overhead. The ordinary normal showcase loop is121.322s, also the majority of its131.024s actual test runtime. Bounded concurrency of independent original showcase binaries is therefore the strongest next hypothesis, subject to output custody, failure/cancellation, thread/memory and full scientific coverage verification. A two-job cap is not itself proof of a measured saving.

RSS is a per-child maximum, not simultaneous process-tree aggregate memory. No population percentile or reliable speedup distribution can be inferred from a single pair. The lack of meaningful saving here is enough to stop this experiment; it does not justify spending more runs to seek a favorable pair.

## Hosted qualification and disposition

The separate PR721 applicable six-workflow cohort passed all76 executed jobs on the same exact tree:29m59s event to last required job,292.2833 unweighted runner-minutes, first complete Native functional result3m05s. Native85.70 runner-minutes; GDExtension167.4833. Original Native reducer confirms all six families,192 core cases in each normal/ASan/TSan family,20 inner command receipts and complete original scientific output inventories. Evidence is detailed in `candidate-hosted-qualification.md`.

Historical accepted-main30m37s/298.70 runner-minutes used different workers, a different source and an additional source-guard workflow. Its38s wall difference is descriptive only and cannot override the paired performance verdict.

**Disposition: safety-qualified research, performance HOLD, no merge recommendation.** Keep the existing predeclared stop: one cold pair per target, no favorable-sample reruns. Root should preserve the Draft/HOLD research and continue the separately qualified object-reuse and real-runtime work. The reviewer has performed no remote mutation.

Machine-readable readbacks: `normal-pair-strict.json`, `sanitize-pair-strict.json`, `normal-pair-independent.json`, `sanitize-pair-independent.json`, `sanitize-showcase-spans.json`, and `candidate-cohort-summary.json`. Original ZIPs/extracted artifacts remain unmodified.

