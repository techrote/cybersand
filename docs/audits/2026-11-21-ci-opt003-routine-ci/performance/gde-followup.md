# CI-OPT-003 bounded GDExtension follow-up

## Observed source and scope

This is diagnostic evidence from unchanged GDExtension code, not qualification of a future optimization. [Run 44959001009](https://github.com/techrote/cybersand/actions/runs/44959001009), attempt 1, PR721 HEAD `506dfc8c343c5d24fe26e89a9542cf985c52853e`, tested merge `47d50be954d056db4dc58e13ec16fd4be6ad2733`, tree `71500851801b166188c27141e3b89f2f8e8b3fe1`. Both HEAD and merge have the same tree. All 54 applicable executed jobs passed; two conditional jobs were skipped (Ready scope for a non-ready event, optional physical stress).

Event 22:52:56 UTC; last Windows functional shard 23:10:02 (17m06s); last Linux functional shard 23:09:37 (16m41s); Linux coverage 23:10:09; Windows coverage 23:10:31; final advisory history 23:10:53 (17m57s). Total unweighted hosted runner consumption was **167.4833 minutes**. Artifact and step durations below use complete terminal job records and original per-command/per-case records, not model-generated timings.

## Dependency and actual work

| Component | Elapsed | Work observed |
| --- | ---: | --- |
| Execution plan | 61s | Runs concurrently with builds; not critical in this cohort |
| Linux build job | 420s | godot-cpp 302.8715s + source-built CyberSand extension 81.901s; remaining setup/stage ~35s |
| Windows cross-build job | 256s | godot-cpp 178.546s + source-built extension 47.483s; remaining setup/stage ~30s |
| Linux shard phase | 575s from first start to last finish | 24 shards, max8; 4303 summed job-seconds |
| Windows shard phase | 764s from first start to last finish | 23 shards, max8; 4813 summed job-seconds |
| Linux exact coverage | 29s | 11s verifier, 2s downloads, 10s checkout plus setup |
| Windows exact coverage | 27s | 14s verifier, 2s downloads, 6s checkout plus setup |
| Advisory history | 49s | 25s matching hosted history; does not replace coverage |

The Windows critical chain is build → shard6 (176s) → shard11 (293s) → shard22 (288s), with approximately3s between releases. Last shard22 starts at23:05:14, 7m58s after its build finished, while the bounded matrix admits other work. This is not all external queue latency; it is mainly the max8 scheduling waves.

Linux build finishes22:59:59. Last shard18 starts23:06:10 after shard13; it finishes23:09:37. The source runs substantive cases, rather than spending most of its time transferring artifacts.

| Last shard | Full job | Checkout | Harness step | Actual case execution | Import |
| --- | ---: | ---: | ---: | ---: | ---: |
| Windows22 | 288s | 23s | 248s | 231.645s across16 cases | 11.818s |
| Linux18 | 207s | 19s | 175s | 162.870s across16 cases | 9.079s |

Windows22's largest tests are material_lab_workbench_integration87.569s, workbench_lcb_salvage50.776s, liquid_trial_body36.295s. Linux18's largest are workbench_reservoir_lab46.808s, lcb_pressure_reference28.741s and liquid_pressure_rapier17.581s. The published test cases, scientific assertions and physical loops remain required.

Repeated across all shards:

- Full-history checkout: Windows470s across23 (mean20.43s); Linux376s across24 (mean15.67s), combined14.10 runner-minutes.
- Godot imports: Windows227.198s, Linux187.870s, combined6.918 runner-minutes.
- Artifact restore/stage: Windows download20s plus verify48s; Linux download61s plus verify17s. This is not a dominant cost.
- Official Godot archive setup: Windows20s aggregate, Linux137s; not a multi-minute critical step on any worker.
- Actual cases: Windows315 cases totaling3669.034s; Linux338 cases totaling3314.446s.

## Ranked next engineering hypotheses

1. **Exact-input reuse of the immutable godot-cpp dependency build**, while rebuilding the current-source CyberSand extension and executing every regression. The dependency is pinned to `101ae38034304346a46ea9ea84ae156d3e860496`, SCons4.10.1, exact toolchain/platform flags, and its5m03 Linux /2m59 Windows compilation dominates build delay. This is potentially several minutes of GDExtension turnaround and8.02 runner-minutes per complete cohort before restore/verification costs. It requires a strict source/toolchain/SCons/flags/ABI identity, immutable digest-bound artifacts, trusted producer and fail-closed incompatibility handling. Existing same-run runtime reuse already works; do not cache test results or import #708 wholesale. Cache invalidation and producer custody make this more invasive than the current Native changes.

2. **Refresh expected-cost scheduling evidence and balance the existing shards**, without adding runners or removing cases. The current committed scheduler profile has zero observations, so it falls back rather than using its existing robust multi-run estimates. Windows tail has real imbalance: job durations117–344s, while long shards21/22 start last. A retrospective model that reorders these exact observed jobs longest-first on8 lanes yields634s instead of764s on Windows; Linux547s instead of575s. These are optimistic models using observed durations, not achieved improvements; different worker assignment can change each duration. Reducing only the Windows tail hits the Linux completion floor25s earlier in this cohort. Use the existing source-bound, both-platform, minimum-three-run profile admission; do not bypass it using this single cohort. This is a low-code hypothesis, with evidence acquisition and host variability as the real constraints.

3. **Avoid repeating full-repository history transfer while preserving required ancestry checks.** Both platform shards explicitly use fetch-depth0 because material authoring validates immutable compatibility ancestry. The logs show all refs/tags fetched for every shard. An exact-current-checkout plus explicit, verified required ancestry transport could recover part of the14.1 runner-minutes and tens of seconds across matrix waves. Shallow checkout alone is unsafe; inventory each ancestry consumer and retain its original semantic check. Reusing Godot import state could save additional work but carries portability/path/native-runtime identity risks, and the measured ~8–10s import per shard is smaller than the real tests.

Do not optimize reducers first: coverage takes27–29s and artifact restore mostly1–3s per shard. Do not raise max-parallel by assumption. Native worldgen still determines the current routine cohort, so these are follow-on hypotheses only after a measured Native improvement exposes GDExtension.

## Evidence and uncertainty

Terminal jobs: `candidate-cohort/jobs-44959001009.json`. Downloaded original artifacts independently SHA256-matched to GitHub:

- Windows22 artifact14728374991: `9482fb910a42f99eec49d4dbc67b26e5cd4bb0751a68d575d7cddd364a5f6619`.
- Linux18 artifact14729306406: `e669b75c032dbce292f1ab2247aef1cc202aebdd5cb3600ca379babc2edfe4ca`.
- Current performance aggregate14729222691: `50d7e1c8e1366abe2b72481ae4bdce086e417f8d3ab7fc84f7289f2274f560de`.

Raw logs of both build jobs and both tail shards retained as `job-ID.log`; per-case summary `gde-followup-raw-summary.json`. Platform telemetry confirms a mixture of Intel/AMD worker models. Windows22 used AMD64 Family25 Model1 and Linux18 Intel Xeon Platinum8573C; no precise cross-worker speedup is inferred. The performance aggregate contains the hosted job durations as well as individual cases: their sums are kept separate to avoid double-counting runner-minutes.

