# CI engineering closure — recovered performance judgment

**Evidence date: 24 November 2026. Scope: historical CI experiments and selection
for an isolated CI/tooling candidate.** This record does not authorize a merge,
Ready promotion, new campaign, publication, provider change or product change.

Keep the current **GDExtension Linux 8 / Windows 8** scheduling limits. The
corrected 16/16 and 14/18 proposals have successful historical source-bound
qualification, but the recovered observations do not establish a useful
full-campaign advantage under shared capacity. Select only the **Palette Windows
2→3** scheduling increment for the Draft integration candidate. Reject production
RAM-disk/RAM-first adoption on the completed experiments. No new hosted execution
was requested to reach these decisions.

The canonical machine-readable companion is [performance.json](performance.json),
schema `cybersand-ci-engineering-closure-performance-v1`. It retains exact source
identities, six GDExtension cohorts, 479 original job/attempt records, phase and
queue distributions, every observed case name/time, all 48 RAM trials, the 19
Palette process joins, and 375 original artifact metadata records. Forty-four
downloaded artifact ZIP digests were independently matched to GitHub metadata.
Original failures remain failures; later successes have separate identities.

## Decisions and rollback

| Candidate | Decision and scope | Evidence and rollback |
|---|---|---|
| [#731, 12/12](https://github.com/techrote/cybersand/pull/731) | **REJECT this exact candidate.** | GDE coverage passed, but mandatory documentation/scheduling policy rejected its limits. No policy waiver. Main stays 8/8. |
| [#735, corrected 16/16](https://github.com/techrote/cybersand/pull/735) | **HOLD adoption.** | Exact corrected cohort passed. The Linux cap of 16 realized only nine overlapping shards, and end-to-end qualification was 33m22s. If an owner later admits greater capacity, this is the simpler qualified scheduling option. A later rollback restores both caps to eight and removes its named-job policy exception/test guards. |
| [#739, Linux 14 / Windows 18](https://github.com/techrote/cybersand/pull/739) | **HOLD adoption; no demonstrated advantage over 16/16.** | Final cohort passed in 33m27s. Initial same-tree cohort retained a real Palette LFS failure. Faster final Windows shard span does not establish a whole-campaign gain. Any later rollback restores both caps and associated policy/test guards to 8/8. |
| [#736, Palette Windows 3](https://github.com/techrote/cybersand/pull/736) | **GO for the one-line Draft candidate; final-source qualification and owner acceptance remain pending.** | Same six cohorts and 19 processes; Windows span 351→208s, whole Palette workflow 450→358s, almost unchanged runner time. Rollback changes only Windows `max-parallel: 3` back to `2`. |
| [#732, staged-copy RAM](https://github.com/techrote/cybersand/pull/732) | **REJECT production adoption.** | Near-zero selected-shard changes; source/dependency/build were outside the RAM experiment. Keep the research record; do not merge its workflow. |
| [#733, RAM-first](https://github.com/techrote/cybersand/pull/733) | **REJECT production adoption.** | All four median execution comparisons regress slightly; preparation changes have mixed signs. Keep the complete negative experiment; no production rollback is needed. |
| [#718, seven Native families](https://github.com/techrote/cybersand/pull/718) | **Retain HOLD.** | Earlier independent review found 25s faster Native completion, 5.09% more runner time and 209s later first functional feedback on different CPUs. Accepted main retains six families. |
| [#721, compiler prerequisite ordering](https://github.com/techrote/cybersand/pull/721) | **Retain HOLD.** | Earlier predeclared same-worker pair saved 14.976s, 1.058%, across its two commands. No fresh campaign to seek a more favorable observation. |

The Palette choice is deliberately narrow. It permits the third existing Windows
cohort to start without waiting for one of the first two to finish; it creates no
new case or runner type. It can consume one additional concurrent Windows slot
for that workflow. The owner still controls capacity admission and merge.

## Sources and measurement method

Accepted main inspected for this review is
`00cdb02f103265b6dc5224c68283e9a0c8cb449f`, tree
`06b62d73138028d1f7615b83edc9810491bf6287`. It retains GDE 8/8. Its current plan has
**340 Linux and 317 Windows cases** across 24 and 23 shards. The historical
fan-out comparison has **338 Linux and 315 Windows cases**, across the same shard
counts. Historical 653-case qualification is not qualification of current main's
657-case source, nor of the eventual combined tooling candidate.

The original jobs endpoint was read separately for each run attempt, with
`per_page=100` and the complete returned `total_count` checked. No queried
attempt needed a second page. Original plans, consolidated telemetry, both
platform coverage receipts and selected original negative job logs were recovered
from their original run identities. The report preserves artifact IDs, names,
sizes, digests, expiration state, and which ZIPs this review actually downloaded.

Wall time uses actual job `started_at` / `completed_at` timestamps. Workflow
`updated_at` can trail the final job by a second and is not the measurement
endpoint. Runner-minutes sum allocated non-skipped job duration divided by 60;
they are unweighted by OS billing rules, rounding or prices. Overlapping intervals
measure realized concurrency within the specified workflow/cohort. They do not
measure account-wide capacity. Creation-to-start combines matrix admission,
GitHub dispatch and available capacity; it must not all be called runner queueing.
Step timestamps have one-second resolution and omit inter-step gaps.

For an earlier attempt, `attempt_conclusion` is the attempted result. The nested
`run.conclusion` in retained summary metadata describes the latest run state;
GitHub's eventual success badge does not change an earlier failure. Attempt API
URLs and hashes are retained where this distinction matters.

### Exact GDExtension identity ledger

PR `head_sha` and the checkout actually tested can differ because a PR workflow
executes its merge checkout. The original plan and source-bound receipts own the
tested identity; the API head alone cannot replace it.

| Configuration | Original run / attempt | API head | Actual tested commit | Actual tested tree |
|---|---|---|---|---|
| 8/8 accepted retry | [44967549040 / 2](https://github.com/techrote/cybersand/actions/runs/44967549040/attempts/2) | `662df51cd8409a52332fa7ef15d06d8ab8945aed` | `662df51cd8409a52332fa7ef15d06d8ab8945aed` | `39b658c5de9c5e541312b5190bd5d8ba797c6bed` |
| 12/12 | [44974802645 / 1](https://github.com/techrote/cybersand/actions/runs/44974802645/attempts/1) | `9fe3f0963b67facd9b6139e9272b296968f20b6e` | `bfe9d03e6d7b216725919b106fb44ded9e7d29f0` | `8711f522c6e5ee9b91ae16381eeb21daa1e10ac6` |
| 16/16 before policy repair | [44977849960 / 1](https://github.com/techrote/cybersand/actions/runs/44977849960/attempts/1) | `fea11a6061a4ca3ce0c9217bc2e124e2cfb08c24` | `4cd6382ed6acca9f4d6df4b3439611910b71230b` | `01b92a45462eb65492ff244e09e46dfe6851b775` |
| 16/16 corrected | [44984940287 / 1](https://github.com/techrote/cybersand/actions/runs/44984940287/attempts/1) | `d170da41fb66cc4a6e23f73343c1f059592ecb63` | `8c606a1e440367f2e60fabfe48f137b2831c4c00` | `8f5171f04f013a3621cf6068e679428b22732339` |
| 14/18 initial | [44985182561 / 1](https://github.com/techrote/cybersand/actions/runs/44985182561/attempts/1) | `97418f385450dd12d3e450bba79b7cf0cae3076f` | `e4d721574530e08c9d990f36c53e73adb1def180` | `75dac7110e09e44c2d34b458f56564e0c914ec9b` |
| 14/18 final | [44989006830 / 1](https://github.com/techrote/cybersand/actions/runs/44989006830/attempts/1) | `bfbbb86877746e5ed0c2f609274b1ce7b03b0990` | `b1179c12b5cef3a55495b22713738eaad4e2b414` | `75dac7110e09e44c2d34b458f56564e0c914ec9b` |

Every row has 338 Linux plus 315 Windows naturally completed, non-watchdog cases,
with no duplicate, missing or unexpected case. The complete original
case-to-shard assignments, flags and timeouts compare equal across all six plans.
Both independent coverage receipts bind the same source, tree, run and attempt.
There are 15 retained PLAY proof files per platform per cohort. Windows retains
the same explicit 23 graphical exclusions in each receipt. Those exclusions and
the two skipped jobs, `ready validation scope` and `physical-actor-stress`, are
recorded separately and do not count as successful execution. The 54 applicable
GDE jobs pass in each successful row.

Consolidated telemetry legitimately contains both null and hashed tracked-delta
states for a single tested source, including materialized-runtime state. This
review preserves both. It does not convert them to a uniformly clean checkout.
The narrow `ci_run_metrics.py` correction makes the mixed nullable values sortable
without changing or omitting their identities. Its real-shape regression fails
with the old helper and passes with the correction; all eight focused tests pass.

These are independent custody and inventory checks of existing hosted results.
The original hosted reducers remain authoritative for their full raw-log/native
and graphical readbacks. This retrospective review did not download every large
GDE shard archive or claim a new physical-device execution.

## GDExtension timing and observed overlap

All durations below include the stated original attempt only; the failed 8/8
attempt and developer recovery delay are accounted for separately afterward.

| Configuration | Attempt start → final GDE job | Allocated runner-minutes | Linux shard span | Windows shard span | Requested caps L/W | Realized peak shards L/W | Peak all GDE jobs |
|---|---:|---:|---:|---:|---:|---:|---:|
| 8/8 accepted retry | 21m13s | 175.850 | 10m17s | 13m23s | 8 / 8 | 8 / 8 | 17 |
| 12/12, policy red | 16m50s | 169.533 | 7m31s | 10m05s | 12 / 12 | 12 / 12 | 25 |
| 16/16 before repair, policy red | 15m03s | 169.550 | 6m36s | 9m28s | 16 / 16 | 16 / 16 | 26 |
| 16/16 corrected | 20m21s | 166.750 | 11m15s | 15m16s | 16 / 16 | 9 / 16 | 18 |
| 14/18 initial, Palette red | 19m25s | 170.783 | 8m08s | 13m59s | 14 / 18 | 14 / 13 | 20 |
| 14/18 final | 23m20s | 178.067 | 6m38s | 8m10s | 14 / 18 | 14 / 18 | 19 |

### Platform phases

Build duration is the entire allocated build job. Shard span runs from the first
shard start to the last shard completion. Reducer tail runs from that last shard
completion to the reducer's completion, including dispatch, checkout and artifact
recovery. Platform runner time includes its build, all shards and reducer.

| Configuration | Platform | Build | Build → first shard | Shard span | Last shard → reducer | Build finish → reducer | Platform runner-minutes |
|---|---|---:|---:|---:|---:|---:|---:|
| 8/8 | Linux | 9m50s | 3s | 10m17s | 32s | 10m52s | 82.800 |
| 8/8 | Windows | 5m10s | 3s | 13m23s | 30s | 13m56s | 89.250 |
| 12/12 | Linux | 7m04s | 3s | 7m31s | 35s | 8m09s | 79.100 |
| 12/12 | Windows | 3m37s | 2s | 10m05s | 3m03s | 13m10s | 87.100 |
| 16/16 before repair | Linux | 6m47s | 3s | 6m36s | 1m05s | 7m44s | 77.133 |
| 16/16 before repair | Windows | 4m12s | 3s | 9m28s | 1m08s | 10m39s | 89.150 |
| 16/16 corrected | Linux | 6m40s | 34s | 11m15s | 42s | 12m31s | 74.483 |
| 16/16 corrected | Windows | 4m14s | 3s | 15m16s | 37s | 15m56s | 88.683 |
| 14/18 initial | Linux | 6m55s | 2m27s | 8m08s | 40s | 11m15s | 77.700 |
| 14/18 initial | Windows | 4m26s | 10s | 13m59s | 38s | 14m47s | 89.350 |
| 14/18 final | Linux | 10m39s | 3s | 6m38s | 5m57s | 12m38s | 90.200 |
| 14/18 final | Windows | 4m23s | 2s | 8m10s | 37s | 8m49s | 84.767 |

The final 14/18 Linux reducer's original
[job 137109540239](https://github.com/techrote/cybersand/actions/runs/44989006830/job/137109540239)
records two 100-second `codeload.github.com` action-download timeouts during setup.
Its 357-second tail is therefore not pure compute or evidence of a bad cap. The
corrected 16/16 Linux shard creation-to-start median is 245s, p95 541s, maximum
578s, and only nine shards overlap despite requesting sixteen. The APIs cannot
separate owner-wide contention from matrix/dispatch behavior. The JSON retains
the full per-platform distributions and step-phase totals instead of treating
one nominal cap as the delivered concurrency.

All recorded regression hosts expose four logical CPUs. Linux hardware ranges
across AMD EPYC 7763/9V45/9V74 and Intel Xeon 6975P-C/8573C/8370C classes; Windows
also uses multiple AMD and Intel models. Linux image versions include
`20261116.133.1` and `20261116.376.1`; Windows reports `20261116.370.1`. Both native
cross-build jobs, including the Windows target build, execute on Linux; Windows
regression shards run on actual Windows. More Windows shard VMs do not increase
the CPU allocation of one Windows VM, and a smaller Linux cap transfers no cores
between VMs.

### Complete source-cohort wait and cost

These observations wait for all applicable jobs, including advisory work. They
are not a controlled whole-CI treatment comparison. Main push includes Wave and
does not include Palette; the fan-out PR cohorts include Palette and not Wave.

| Source cohort | Original event → final job | Runner-minutes, all attempts | Latest job outcomes | Peak jobs within this source cohort | Final path |
|---|---:|---:|---|---:|---|
| 8/8 accepted main, including failed attempt | 37m02s | 295.067 | 68 success, 4 conditional skips; earlier attempt 3 success / 3 failure / 5 skips retained | 17 | GDE timing history; last platform gate at 36m36s |
| 12/12 | 22m16s | 262.433 | 71 success, 1 failure, 3 skips | 31 | Native |
| 16/16 before repair | 23m16s | 256.367 | 71 success, 1 failure, 3 skips | 30 | Native |
| 16/16 corrected | 33m22s | 280.200 | 72 success, 3 skips | 23 | Native |
| 14/18 initial | 33m47s | 276.583 | 70 success, 2 failures, 3 skips | 23 | Native |
| 14/18 final | 33m27s | 294.350 | 72 success, 3 skips | 26 | Native |

Native worldgen allocated jobs are 1242s, 1273s, 1922s, 1929s and 1905s in the
five PR rows respectively. Native remains the final path in all of them, even
when GDE shard spans improve. This is another reason not to convert GDE-only
percentages into a developer-wait claim. The corrected 16/16 and final 14/18
complete cohorts differ by just five seconds, while the latter consumed 14.15
more observed runner-minutes. Differing hosted workers and infrastructure prevent
attributing that difference solely to fan-out. There is no defensible reason to
prefer the asymmetric policy on these measurements.

The owner previously recorded a 40-runner account ceiling. Its actual applicable
entitlement was not independently available from these bounded repository reads.
The largest measured selected-source peak here is 31; that is neither proof of a
31-runner account limit nor a measurement of spare account-wide capacity. Other
programmes and repositories may be active concurrently. Ten Pro sessions are not
ten runner slots. Keep the owner capacity decision and current live admission
ledger separate from this historical comparison.

## Original failures and retry accounting

The accepted 8/8 run's original source event was **2026-11-22 00:37:46 UTC**.
[Attempt 1](https://github.com/techrote/cybersand/actions/runs/44967549040/attempts/1)
failed: its planner checkout had two TCP 443 connection failures lasting
133.700s and 136.446s, then reached the existing checkout watchdog. The planning
command and scientific test inventory never ran. Both coverage reducers correctly
refused absent evidence. There were six executed jobs (three successful and
three failed), five skipped records, and **19.716667 runner-minutes** consumed.

Attempt 2 started at **00:53:35**, reached the last platform reducer at
**01:14:22**, and finished its final timing-history job at **01:14:48**. Thus the
successful retry took 20m47s to platform coverage and 21m13s to all jobs. The
original event-to-retry interval of 15m49s includes failure and recovery time; it
is not all queue delay. The complete developer wait is **36m36s** to the last
platform gate and **37m02s** to every applicable job. All successful-attempt
cohort cost is 275.350 runner-minutes; adding the original failure yields
295.066667. The retry did not reuse failed-attempt artifacts as successful proof.

Other retained negatives are independently visible in their original logs:

| Original record | Observed failure | Consequence |
|---|---|---|
| [#731 Documentation 44974802604](https://github.com/techrote/cybersand/actions/runs/44974802604), job 137062184664 | Scheduler policy permits 1..8; both proposed caps were 12. | This exact source is not fully qualified although GDE passed. |
| [#735 original Documentation 44977850017](https://github.com/techrote/cybersand/actions/runs/44977850017), job 137071626745 | Same policy mismatch before the correction. | The faster 15m03s GDE observation does not substitute for corrected-head qualification. |
| [#739 original Palette 44985182460](https://github.com/techrote/cybersand/actions/runs/44985182460), job 137094185991 | Linux visual shard 1 cannot materialize Git LFS dependencies because of authorization failure; its final readback refuses the absent cohort. | Initial source `97418f38` remains red. Final `bfbbb868` is a separate request with the same tree and its own successful evidence. |

Corrected #735's five workflows are Documentation 44984940236, Native
44984940258, GDE 44984940287, Palette 44984940235 and advisory 44984940283.
Final #739's are Documentation 44989006734, Native 44989006707, GDE 44989006830,
Palette 44989006738 and advisory 44989006756. All applicable jobs in those exact
cohorts pass. The JSON retains all earlier and final records separately.

## Independent Palette decision

The candidate [run 44978447427 / attempt 1](https://github.com/techrote/cybersand/actions/runs/44978447427)
executes source `3c9900ef426c7b50d682c569e06363e821aa31df`, tree
`4a85d204d16d27812cde4ff163ba302934dbc592`. Its comparison against accepted base
`662df51c` changes only the Windows matrix's `max-parallel` from two to three.
The preceding baseline [44977849917 / attempt 1](https://github.com/techrote/cybersand/actions/runs/44977849917)
has source `fea11a6061a4ca3ce0c9217bc2e124e2cfb08c24` and the same Palette plan.

| Measurement | Windows cap 2 baseline | Windows cap 3 candidate |
|---|---:|---:|
| Entire Palette workflow | 7m30s | 5m58s |
| Allocated runner-minutes | 16.866667 | 16.800000 |
| Windows jobs / realized peak | 3 / 2 | 3 / 3 |
| Windows span | 5m51s | 3m28s |
| Linux jobs / realized peak | 3 / 2 | 3 / 2 |
| Linux span | 3m43s | 3m37s |
| Plan finish → last Windows start | 173s | 35s |
| Final reducer queue / execution | 3s / 68s | 41s / 53s |
| Required v3 suite verdict | Passed | Passed |
| Retained v2 image diagnostic | Failed, non-gating | Failed, non-gating |

All eight candidate workflow jobs pass. Its Documentation 44978447442 and
advisory 44978447468 also pass; the complete applicable three-workflow cohort
takes 9m44s and 26.483333 runner-minutes. No Native/GDE run was applicable to that
historical narrow path scope.

Six candidate ZIPs were downloaded with whole-archive SHA-256 validation. The
small original qualification, readback, compiler, manifest and process-log
receipts were recovered from each. All **19 cases** (ten Linux, nine Windows)
match the unchanged plan, exact source/tree/run/attempt, natural process exit,
nonce, actual runtime and log digest. Linux actual engine PID equals the launched
PID. The Windows console wrapper and actual engine PID can differ; both are
retained separately and compiler observations bind the actual engine PID under
the existing platform contract. Every known process exited. A separate assurance
review replayed the canonical process/context checks against these same original
receipts and agreed with this bounded GO selection.

The v3 full-suite verdict still owns the original pixel-buffer and image
acceptance. This review checked retained JSON/log manifest entries and did not
perform a new pixel render or physical owner-GPU test. The explicitly failed v2
finished-image diagnostic remains visible under its existing non-gating scope;
there is no universal cross-backend pixel-identity claim.

The observed 92-second full-Palette saving is one historical pair, not a promised
20.44% future speedup. The bounded dependency removal, unchanged inventory and
nearly equal allocated runner cost justify the one-line candidate. Source-exact
qualification of the eventual integration branch remains a separate gate.

## RAM experiments: completed evidence, negative production decision

| Method | Original run / attempt | Exact source | Exact tree |
|---|---|---|---|
| #732 SSD-staged copy | [44976089046 / 1](https://github.com/techrote/cybersand/actions/runs/44976089046) | `a7a8c90bc1c876d8d6e667b580dda7ae34a2486c` | `a5d64af99de187f2958635347c7efa112e1136f9` |
| #733 RAM-first direct checkout/build | [44976706404 / 1](https://github.com/techrote/cybersand/actions/runs/44976706404) | `ffc4d1a65b7f1ce85a840948f250ebb330b5f33d` | `e1b62dc9be220c8380c434bf0c58ecac42e60bc6` |

Each study completes all four declared Linux shards (2, 6, 12, 19), three stock
and three RAM repetitions per shard: **24 trials, 56 distinct cases and 336
actual case executions**. Across both studies all 48 trials, 672 case executions
and 48 imports are present and passed naturally. The 720 original process-log
hashes were checked with their source, tree, run, attempt and shard identities;
no missing or failed trial was dropped. Orders are stock/RAM/RAM/stock/stock/RAM
for shards 2 and 12, and RAM/stock/stock/RAM/RAM/stock for shards 6 and 19.

The methods are materially different. **#732 stages a prebuilt SSD workspace**
into each selected filesystem, with fresh project caches for each repetition.
It measures the execution/storage treatment after staging, not direct checkout
or native build on RAM. **#733 mounts an 8 GiB `tmpfs` with `noswap` in each
worker's first user step**, then directly checks out, resolves dependencies and
builds separate stock/RAM arms on the corresponding filesystems. Source, caches,
temporary home and test executables reside on the selected arm; the host OS,
installed toolchain executables and Actions internals are still hosted OS
resources. Some hosts have OS swap configured, so `noswap` for this mount must
not be described as an entirely swap-free VM.

Actual arm filesystems are stock `ext2/ext3` and RAM `tmpfs`, and source-input
identities match every repetition within each study. Both arms and both studies
have identical CyberSand library bytes
`a15fc422313eb01e79bc904f44cc8879816484ae4fc98c63ac4b815afdb6a5e7`,
Rapier bytes `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a`,
and Godot bytes `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`.

### Median execution observations

Positive saving means RAM was faster; a negative value means RAM was slower.
These are medians of three declared original repetitions, not population
estimates or whole-CI speedups. Execution, import, readback, staging/copyback and
preparation phases remain separate in the JSON trial records.

| Method | Shard | Stock median seconds | RAM median seconds | RAM saving |
|---|---:|---:|---:|---:|
| SSD-staged copy | 2 | 89.478 | 88.944 | +0.596% |
| SSD-staged copy | 6 | 132.317 | 132.335 | −0.014% |
| SSD-staged copy | 12 | 216.874 | 216.394 | +0.221% |
| SSD-staged copy | 19 | 191.071 | 186.984 | +2.139% |
| RAM-first | 2 | 107.729 | 108.276 | −0.508% |
| RAM-first | 6 | 120.692 | 121.238 | −0.452% |
| RAM-first | 12 | 209.020 | 209.107 | −0.042% |
| RAM-first | 19 | 137.503 | 137.761 | −0.188% |

#733 preserves each arm's cache between its three repetitions. Its first run is
the project's initial-cache observation; the later two are warm within that arm.
The OS page cache was not flushed, so neither label guarantees a machine-wide
cold state. The two arms were prepared on the same host, and preparation order
and background/network variation remain possible influences.

| RAM-first shard | Preparation stock → RAM, seconds | First execution stock → RAM, seconds |
|---|---:|---:|
| 2 | 480.800 → 475.265 | 111.841 → 110.129 |
| 6 | 372.192 → 387.079 | 121.975 → 137.306 |
| 12 | 396.082 → 379.716 | 221.255 → 213.958 |
| 19 | 367.581 → 387.532 | 140.146 → 146.767 |

Preparation has mixed signs; it provides no consistent RAM-first gain. Staged
shard 19 used an AMD EPYC 7763; the other staged hosts used Intel 6975P-C. RAM-first
shard 2 used Xeon 8573C, while its other three hosts used 6975P-C. All had four
logical CPUs and approximately 16 GiB memory. Sampled available memory remained
above roughly 12.7 GiB in these trials, but the recorded start/end measurements
and direct-process GNU time do not establish continuous peak whole-VM RSS or
safety for a much larger future workload. Mount capacity and memory data are
retained in the original artifacts and per-arm report.

No Windows storage trial or complete-CI RAM treatment exists here. These four
selected Linux shards, the staged-copy experiment and the direct-checkout/build
experiment have distinct scopes. All are useful completed evidence; none
justifies merging a production storage default. No more repetitions are needed
to close these negative arms.

## Earlier accepted work and the delivery boundary

[The retained CI-OPT-002 judgment](https://github.com/techrote/cybersand/blob/eb901f91780b9553cc61bcdd24584f032ccd9a6f/docs/audits/2026-11-21-ci-opt-002/final-verdict.md)
already distinguishes #714's accepted early provenance refusal from #718's
unmerged seven-family split. The latter's Native pair is control 44948256292
versus candidate 44948729271; its actual merge checkout is
`9ae8b2a483d756af18ad21f1d99f529645640f12`, tree
`b01d95a8cb90ae0be9fb36e368694167dd80efb6`. Its previously independent artifact
replays remain useful within that exact source scope. This mission did not run
another Native comparison or re-download all those Native archives.

[The retained CI-OPT-003 post-merge report](https://github.com/techrote/cybersand/blob/fe7614079fc5691f15030dc9d955bf32e91e4723/docs/audits/2026-11-21-ci-opt003-routine-ci/performance/postmerge-final-performance.md)
records separately accepted #722 soliding object reuse and #723 bounded worldgen
scheduling. #722's same-worker normal family changed 190.811701→108.006146s
(43.3965%) and its ASan family 1285.232141→809.250157s (37.0347%). #723's complete
worldgen family pair changed 1748.640267→1232.409098s (29.5219%). These were
baseline-first, one-pair family comparisons with their original scientific
inventory preserved. They are not whole-CI percentages. Their accepted merge
commits `30e1cddd3d678456df10f52f7a2fb2210a9daaad` and
`662df51cd8409a52332fa7ef15d06d8ab8945aed` remain ancestors of inspected main.

This review selects no new GDE policy exception and no experimental native graph
or storage change. It supplies the bounded Palette scheduling increment and the
nullable-identity telemetry replay repair for the isolated integration branch.
Independent assurance has checked the latter's eight tests and the original
Palette process/context evidence. The integration owner still must finish
final-source policy checks, decide whether current shared capacity can admit the
minimum applicable hosted qualification, and preserve HOLD if it cannot. The
historical successes do not waive any mandatory native, graphical, provenance,
publication or owner acceptance gate.
