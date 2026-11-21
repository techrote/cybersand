# CI-OPT-002 Stage B — contemporaneous Native comparison

## Observed result

**Both campaigns passed all qualification gates, but this pair does not establish
a meaningful performance improvement.** The Native result arrived only 25 seconds
earlier, while runner time increased by 4m58s and the first completed native family
arrived 209 seconds later. The critical workers used different CPU models. These
tradeoffs remain part of the result; the removed serial work is not presented as
an observed whole-run saving.

The predeclared, source-compatible Native control completed its required result
in **37m28.00s**, and the split candidate in
**37m03.00s**. The observed difference is
**0m25.00s (1.11%)**.
These are complete hosted runs with their original twenty commands and strict
exact-source aggregate receipts. This is a single paired observation, not a
guarantee of the same improvement on every hosted worker.

- Control: [44948256292](https://github.com/techrote/cybersand/actions/runs/44948256292), source `8fada1df005553eecb98935afdbcebd27615bd13`.
- Candidate: [44948729271](https://github.com/techrote/cybersand/actions/runs/44948729271), PR head `65aa1382a49bb01571177b4639f27b64f5dcb66d`; executed merge `9ae8b2a483d756af18ad21f1d99f529645640f12`.
- The executed candidate tree exactly equals the candidate-head tree.

| Measurement | Six-family control | Seven-family candidate | Observed reduction |
| --- | ---: | ---: | ---: |
| Native event-to-required-result | 2248.000 | 2223.000 | 25.000 seconds |
| Full Native workflow event envelope | 2248.000 | 2223.000 | 25.000 seconds |
| First worker start to last worker end | 2245.000 | 2220.000 | 25.000 seconds |
| Initial queue | 3.000 | 3.000 | 0.000 seconds |
| Complete unweighted runner-minutes | 97.567 | 102.533 | -4.967 minutes |

All executed jobs are counted in runner-minutes, including policy, setup, native
families, artifact retention and the final aggregate. The PR-only ready-scope
job is disclosed as skipped and contributes zero runner time. API job timestamps
are used at their one-second resolution; command receipts retain monotonic
elapsed time. The workflow's `updated_at` timestamp is not used as execution time.

## Scheduling and useful feedback

The control runs physics characterisation, ordinary worldgen and sanitized
worldgen serially inside one family. The candidate retains physics and ordinary
worldgen in `worldgen`, and assigns the identical sanitizer command to a separate
required `worldgen-sanitize` family. The aggregate requires all seven. The
parallel cap remains six; the short `soliding-normal` family waits for a slot
while the longer families start first.

The two observed serial predecessor commands in the control totalled
**451.438s**. Removing that dependency lets the sanitizer begin earlier;
this figure is not an additional saving to add to the measured workflow delta.
The actual start delays for every family are retained in the machine report.
Policy completion to family start is labelled as combined matrix scheduling and
runner wait; it cannot be interpreted as pure runner queue time. Job creation to
start and dependency eligibility are retained separately.

| Feedback point | Control | Candidate |
| --- | --- | --- |
| First reliable admission/policy result | Native evidence and provider policy / 34.000s | Native evidence and provider policy / 30.000s |
| First completed Native family | Native family / soliding-normal / 181.000s | Native family / worldgen / 390.000s |
| Last Native family | Native family / worldgen / 2194.000s | Native family / worldgen-sanitize / 2168.000s |

## Decomposing observed latency and runner cost

The following additive decomposition uses the actual sanitizer command's UTC
start, its monotonic elapsed receipt, and the required Native job completion.
Positive values in the final column shorten the candidate result; negative
values offset the improvement. The four contributions sum to the observed
Native required-result reduction. It separates changed command runtime from the
removed serial predecessors. CPU model, filesystem-cache warmth and runner load
were not independently controlled.

| Latency component, seconds | Control | Candidate | Contribution to shorter result |
| --- | ---: | ---: | ---: |
| Removed serial physics + ordinary worldgen commands | 451.438 | 0.000 | 451.438 |
| Other time before sanitizer starts: policy, scheduling, setup | 46.636 | 39.304 | 7.332 |
| Different duration of the identical sanitizer command | 1691.767 | 2124.821 | -433.054 |
| Time after sanitizer: family capture, other-family wait, aggregate | 58.159 | 58.875 | -0.717 |

The post-sanitizer component also includes waiting for another family if it
finishes later than the sanitizer. The last family was
**Native family / worldgen** in the control and
**Native family / worldgen-sanitize** in the candidate. It must not
automatically be labelled artifact overhead. API timestamps have one-second
resolution; the UTC/monotonic decomposition should be interpreted at that precision.

| Runner-cost component, seconds | Control | Candidate |
| --- | ---: | ---: |
| Original twenty commands | 5672.192 | 5968.867 |
| Within-family wrapper overhead | 6.094 | 5.990 |
| Family setup, receipt capture, upload and cleanup | 93.714 | 99.143 |
| Policy, aggregate and other executed jobs | 82.000 | 78.000 |

These cost components sum to complete unweighted runner time. The extra family
adds setup and evidence retention, while unchanged command durations can vary
across workers. Any observed runner-minute increase remains visible even when
the required result arrives sooner.

## Exact command work and host variability

Every original command, argument, sanitizer environment prefix, command-level
timeout and policy key is unchanged. Only the ownership of `worldgen-sanitize`
moves between families. All twenty complete command receipts pass; both runs
retain the same 192-case native registry and its original required mode coverage.
The actual sanitizer logs also contain identical multisets of 28 compiler/link
invocations: 12 object compilations and 16 binary links. The split did not lose
prior sanitized-object reuse from the physics or ordinary-worldgen targets.

| Original command | Family ownership | Control seconds | Candidate seconds |
| --- | --- | ---: | ---: |
| benchmark | native-normal → native-normal | 1.170 | 1.171 |
| build-benchmark | native-normal → native-normal | 18.264 | 18.320 |
| build-settled-regions-sanitized | soliding-asan → soliding-asan | 701.300 | 579.148 |
| build-soliding-sanitized | soliding-asan → soliding-asan | 849.292 | 684.074 |
| build-tests | native-normal → native-normal | 43.789 | 42.811 |
| build-tests-sanitized | asan-ubsan → asan-ubsan | 256.716 | 314.561 |
| build-tests-tsan | tsan → tsan | 83.105 | 84.071 |
| c-header-check | native-normal → native-normal | 0.595 | 0.740 |
| physics-characterisation-sanitize | worldgen → worldgen | 96.556 | 100.787 |
| shared | native-normal → native-normal | 21.538 | 21.809 |
| soliding-benchmark-smoke | soliding-normal → soliding-normal | 1.009 | 1.059 |
| soliding-sanitize | soliding-asan → soliding-asan | 2.237 | 1.578 |
| soliding-stage3-cost-smoke | soliding-normal → soliding-normal | 22.097 | 23.525 |
| soliding-stage3b-validation-apparatus-test | soliding-normal → soliding-normal | 0.459 | 0.559 |
| soliding-test | soliding-normal → soliding-normal | 103.280 | 113.056 |
| tests | native-normal → native-normal | 308.361 | 304.362 |
| tests-sanitized | asan-ubsan → asan-ubsan | 443.784 | 629.916 |
| tests-tsan | tsan → tsan | 671.992 | 680.688 |
| worldgen-sanitize | worldgen → worldgen-sanitize | 1691.767 | 2124.821 |
| worldgen-test | worldgen → worldgen | 354.882 | 241.811 |

Command durations can vary even for unchanged families. Among unchanged
non-worldgen commands taking at least one second in the control, the candidate
to control duration ratios range from
**0.706** to
**1.419**, with
median **1.012**.
This describes the observed variation; it is not a correction factor used to
manufacture a larger improvement.

| Arm / family | Reported CPU | Logical CPUs | Runner image version |
| --- | --- | ---: | --- |
| before / asan-ubsan | Intel(R) Xeon(R) 6975P-C | 4 | 20261116.133.1 |
| before / native-normal | Intel(R) Xeon(R) 6975P-C | 4 | 20261116.133.1 |
| before / soliding-asan | AMD EPYC 7763 64-Core Processor | 4 | 20261116.376.1 |
| before / soliding-normal | Intel(R) Xeon(R) 6975P-C | 4 | 20261116.133.1 |
| before / tsan | Intel(R) Xeon(R) 6975P-C | 4 | 20261116.133.1 |
| before / worldgen | AMD EPYC 9V74 80-Core Processor | 4 | 20261116.376.1 |
| after / asan-ubsan | AMD EPYC 7763 64-Core Processor | 4 | 20261116.376.1 |
| after / native-normal | Intel(R) Xeon(R) 6975P-C | 4 | 20261116.133.1 |
| after / soliding-asan | Intel(R) Xeon(R) 6975P-C | 4 | 20261116.133.1 |
| after / soliding-normal | Intel(R) Xeon(R) 6975P-C | 4 | 20261116.133.1 |
| after / tsan | Intel(R) Xeon(R) 6975P-C | 4 | 20261116.133.1 |
| after / worldgen | Intel(R) Xeon(R) 6975P-C | 4 | 20261116.133.1 |
| after / worldgen-sanitize | AMD EPYC 7763 64-Core Processor | 4 | 20261116.376.1 |

No compiler cache is restored by these workflows. Fresh per-job workspaces and
the existing separate normal/sanitized build directories remain. The original
make targets still combine compilation and native test execution, so this audit
does not invent per-compiler/per-test durations absent from the receipts.

## Source and evidence preservation

The entire `native`, `godot` and `tools/physics` Git subtrees, plus the Makefile
blob, match across merged Stage A, the control, the candidate and its executed
merge. The only control addition is its dedicated workflow; the candidate's
changes are confined to CI tooling/tests and documentation. The candidate does
not change production software, native binaries or native test inventory.

For each run independently, the audit downloaded the complete original family
ZIPs and aggregate ZIP, verified their GitHub SHA-256 digests, reconstructed the
immutable source-fingerprint inputs, and replayed that exact commit's canonical
aggregate verifier. The independently replayed aggregate equals the hosted
aggregate exactly as parsed JSON. Every source/tree/run/
attempt binding, original exit, command-log/file hash, scientific-output
inventory and native test-case order is checked by that run's exact verifier.
Overall workflow and required `native` job conclusions must also be successful.
Source identity is established per run; receipts are never mixed across runs.

The control preserves canonical `native.yml` and every original job byte.
Its alternate workflow has a separately verified SHA-256, bound by the complete
committed tree. The existing receipt's `workflow` fingerprint continues to mean
canonical `native.yml`; it is not misrepresented as a fingerprint of the alternate
control file.

## Scope limits and retained records

This direct comparison concerns the complete Native workflows. The candidate's
five-workflow applicable-check event envelope must be reported separately. The
control intentionally did not rerun GDExtension, Palette or Documentation, so it
cannot establish their before/after cost or a full repository cohort runner-minute
saving. The older seven-workflow main baseline is historical context only.

This is one predeclared contemporaneous pair. Separate hosted workers and their
resource availability can vary despite matching CPU/image labels. The report
preserves that variation and distinguishes first feedback, mandatory result
latency, queue/dependency waits and complete runner-minute cost.

A bounded retrospective check covered all four Native runs already selected in
the initial baseline, retaining their complete job inventories. Three existing
performance artifacts supplied all six family observations for 807,537 additional
bytes; no new campaign ran. All four runs have compatible source/test inputs,
but none used the candidate's AMD EPYC 7763 critical worker for worldgen. CPU
matches in other workloads do not substitute for that missing comparison. The
diagnostic is retained in `historical-native-diagnostics/report.md` and does not
replace the predeclared 25-second headline with a more attractive historical run.

Machine records are `stage-b-control/summary.json`,
`stage-b-candidate/summary.json`, `stage-b-source-equivalence.json` and
`stage-b-native-paired-summary.json`. Complete raw API run/job/artifact pages,
original ZIPs, extracted evidence and independent aggregate replays are retained
beside the individual campaign summaries.

- Control: [native-qualification-44948256292-1](https://github.com/techrote/cybersand/actions/runs/44948256292/artifacts/14725866462), SHA-256 `56d8bdef7847a59e316232b9553afeb16498778bf9992bb968be1dc5f439a12b`.
- Control: [native-shard-native-normal-44948256292-1](https://github.com/techrote/cybersand/actions/runs/44948256292/artifacts/14725295111), SHA-256 `cbcf3a047ab0c90f09bed0daf49e17150390d6a58214db026ca265ff721c0b6c`.
- Control: [native-shard-asan-ubsan-44948256292-1](https://github.com/techrote/cybersand/actions/runs/44948256292/artifacts/14725276340), SHA-256 `91e19eccc8fe4a1fc473e607a2dc7c498e54909293f74a080e6aab5e24fbdb19`.
- Control: [native-shard-worldgen-44948256292-1](https://github.com/techrote/cybersand/actions/runs/44948256292/artifacts/14725108726), SHA-256 `3a5a402f27fef61e2f9c940e212d339187dc2b26ed79fa9ee99ef3ee37826e9f`.
- Control: [native-shard-soliding-asan-44948256292-1](https://github.com/techrote/cybersand/actions/runs/44948256292/artifacts/14725009368), SHA-256 `dedc87d4e13b203eb3a1ea466d4b92766e220a9c4d266e398d8a7432094805b2`.
- Control: [native-shard-soliding-normal-44948256292-1](https://github.com/techrote/cybersand/actions/runs/44948256292/artifacts/14724925725), SHA-256 `c6c666a6b33a12a1bf2b0bbd2d5b692262aa5c1259e376bcd020b6c989eee1f7`.
- Control: [native-shard-tsan-44948256292-1](https://github.com/techrote/cybersand/actions/runs/44948256292/artifacts/14724907366), SHA-256 `0fc7edc3b48f3f7ef425a729f9efd5e47a01fbc0420793582a2a6761450167e3`.
- Candidate: [native-qualification-44948729271-1](https://github.com/techrote/cybersand/actions/runs/44948729271/artifacts/14725892167), SHA-256 `1ff621753245e8d0b348ec3e99f24ba12b271de88489904c4143b5810537a38c`.
- Candidate: [native-shard-worldgen-sanitize-44948729271-1](https://github.com/techrote/cybersand/actions/runs/44948729271/artifacts/14725619047), SHA-256 `65ca2fb8a8525cc4c3a5146fc6ff6c06e7e6cd93cff28dd9059d2776bbd527dc`.
- Candidate: [native-shard-asan-ubsan-44948729271-1](https://github.com/techrote/cybersand/actions/runs/44948729271/artifacts/14725566094), SHA-256 `67b368af7c85a9d03f60a5aada794ffff881e791319a45db4136fdd0e16a7573`.
- Candidate: [native-shard-soliding-asan-44948729271-1](https://github.com/techrote/cybersand/actions/runs/44948729271/artifacts/14725526513), SHA-256 `2f9464a9bb2238297a27e1fd9844330966e1f7c45889fa27e12e45b26341a1c8`.
- Candidate: [native-shard-tsan-44948729271-1](https://github.com/techrote/cybersand/actions/runs/44948729271/artifacts/14724877140), SHA-256 `274ef2e5afa046ef84fc46df418c2602995ef35b6d6e860313755e471c879567`.
- Candidate: [native-shard-native-normal-44948729271-1](https://github.com/techrote/cybersand/actions/runs/44948729271/artifacts/14724867315), SHA-256 `6c768a5a97c7f6bd8ac7e5b4b458ee7e851c3560abff2e33e221b8d1c7d7647b`.
- Candidate: [native-shard-soliding-normal-44948729271-1](https://github.com/techrote/cybersand/actions/runs/44948729271/artifacts/14724548711), SHA-256 `f89283d5398b7ae21808cc77861e73db6c8c8d165432b40b3fdbb355c4d33e4d`.
- Candidate: [native-shard-worldgen-44948729271-1](https://github.com/techrote/cybersand/actions/runs/44948729271/artifacts/14724538389), SHA-256 `c53ba6e97238b186a851b2642b9c0d8a1ab227de8ff6d36901b55279ae8ef38d`.
