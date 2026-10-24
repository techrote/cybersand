---
title: Physical regression timeout diagnosis for issue 233
status: Current
document-kind: evidence
scope: Completed issue 233 diagnostic campaign, source-bound historical and stress timing evidence, captured roster stalls and repair handoff limits
canonical-for: [issue-233-physical-timeout-evidence]
last-reviewed: 2026-10-24
related-documents: [../operations/testing-validation-and-replay.md, ../operations/github-development-and-release.md]
---

# #233 physical regression timeout diagnosis — 2026-10-24

## Source, scope and original failures

Original handoff diagnostic branch: `chatgpt/issue-233-physical-timeout-diagnostics`, based on `main` commit `1e032e492cafb232e604baf6e2b823b13d779aa8`. This retained initial table derives from **five selected actual GitHub-hosted GDExtension runs per platform**, using the latest available job attempt for each run. The completed source-bound campaign and final classification are recorded below.

- [Run 39875771737](https://github.com/techrote/cybersand/actions/runs/39875771737): Windows and Linux physical cases passed.
- [Run 39879178132](https://github.com/techrote/cybersand/actions/runs/39879178132), source `91f093a`: Windows arena and Linux usable course each hit the 180 s timeout.
- [Run 39978072686](https://github.com/techrote/cybersand/actions/runs/39978072686), `3248bf3`: original Windows rigs attempt timed out after the Godot banner; later available rerun finished normally.
- [Run 40041851953](https://github.com/techrote/cybersand/actions/runs/40041851953), `84b9322a1590488fc1a293a4047df4c0f38924c6`: Windows arena passed in 18.504 s.
- [Run 40047749353](https://github.com/techrote/cybersand/actions/runs/40047749353), `31261caa866105f122230b568f39c503105522c8`: attempt 1 Windows arena timed out; latest available Windows job log instead shows Windows rigs timing out, with arena passing in 14.404 s. The original attempt-1 details are retained in [the tracking issue comment](https://github.com/techrote/cybersand/issues/232#issuecomment-6378447089).

Original-attempt timeouts in runs 39978072686 and 40047749353 are **not silently counted as successes**, nor double-counted with latest-attempt observations.

## Measured distributions

Five most recently retrievable attempt-level workflow logs from the run set above, Godot 4.7 stable, Rapier 0.35.2, Ubuntu 24.04 and Windows Server 2022. Timing is the difference between consecutive `Running <test>` log timestamps; it includes small runner turnaround overhead. Explicit `TIMEOUT after 180s` identifies failure. p95 is nearest-rank (with five samples, equal to maximum). All durations in seconds.

| OS | Test | N | Median | p95 | Max | Timeouts |
|---|---|---:|---:|---:|---:|---:|
| Windows | actor arena | 5 | 18.983 | 179.994 | 179.994 | 1 |
| Windows | actor rigs | 5 | 27.993 | 180.010 | 180.010 | 1 |
| Windows | usable course | 5 | 16.829 | 17.683 | 17.683 | 0 |
| Linux | actor arena | 5 | 17.097 | 17.298 | 17.298 | 0 |
| Linux | actor rigs | 5 | 23.520 | 23.917 | 23.917 | 0 |
| Linux | usable course | 5 | 15.900 | 180.003 | 180.003 | 1 |

These 30 selected observations are not an unbiased prevalence estimate or the full historical record. Earlier attempts contain at least two additional independently preserved Windows timeout events. The full flight/usable regression family is only covered prospectively by the new per-run CSV reducer.

## Classification, mechanisms and limitations

**Provisional classification: intermittent hard stall/hang, not a smooth load tail.** Identical tests complete normally in roughly 10–29 s or reach the 180 s watchdog. Both Windows (arena/rigs) and Linux (usable course) have encountered a timeout, ruling out a Windows-only phenomenon for the overall class. This does not prove one shared root cause. Existing logs lack pre-kill native stacks, last tick/stage markers, or worker/step/teardown wait-state evidence. Native worker deadlock, Rapier step coupling, main-thread teardown and host co-tenancy remain hypotheses. The earlier runs do not isolate worker count or shard contention.

## Diagnostic and stress admission

Original proposed apparatus (subsequently reviewed and admitted below): `run_godot_regressions.py` captures bounded last-60-line tails, elapsed test duration, process snapshot/native debugger attempt before tree termination, and last phase; all timeouts remain failed. Affected fixtures emit coarse setup/world/tick/teardown markers. `physical_timing_report.py` and the GDExtension timing job produce per-platform CSV median/p95/max/timeout records. `physical-timeout-stress.yml` is dispatch-only, exact-SHA, hosted Windows/Linux, serial and three-process parallel, five batches of ten per case: 600 total attempts. `aggregate_physical_stress.py` rejects missing/failed/duplicated evidence.

**Original handoff limitation (retained):** There was no completed source-matched diagnostic CI run, no captured hang stack after instrumentation and no dispatched 50-repeat campaign. Dispatch requires workflow availability on the repository default branch. Results must be appended, reviewed and used for the causal discrimination transferred to [#234](https://github.com/techrote/cybersand/issues/234). A rerun passing, a higher timeout or the presence of this apparatus is not issue closure. The 180 s case timeout is unchanged.

## Continuation intake and apparatus review — 2026-10-24

Remote intake confirmed `main` at `1e032e492cafb232e604baf6e2b823b13d779aa8`
and PR #241 still at handoff head `1324a30b66696d326a4f3f30a12e909ac4eaf75f`.
The active source root `C:/khybersand` was on unrelated
`mat/material-fidelity-pass-2`, HEAD `620826f59fbe248f93a45c45e786a7297f2e5288`,
with dirty material/native files and a local DLL. Those files were preserved.
Continuation uses isolated worktree
`C:/Users/_/.codex/worktrees/issue233-diagnostics/khybersand` and branch
`codex/issue233-diagnostics`, starting from the recoverable handoff commit.
All 18 pinned LFS payloads were materialized from the existing object store;
Godot, godot-cpp, SCons and Rapier pins are unchanged. The checker’s required
companion fixture files were extracted from its existing CI pin
`6a58311982941b75f46e22109a0829e5acb83c7e` beside this isolated source checkout.

Review found and corrected diagnostic defects before admission: whole-log tail
reads, unbounded in-memory subprocess capture/inherited-pipe cleanup, Windows
thread collection formatting, and evidence exceptions bypassing termination.
Tails now retain at most 60 lines within 256 KiB; snapshot commands have 12-second
deadlines, bounded cleanup and capped retained output. Windows exposes actual
thread IDs/state/wait reason/CPU. Linux records the owned process session tree,
thread wait channels and bounded native debugger attempt/refusal. Timeout
termination runs in `finally` and timeout failure remains unconditional.

The independent reducer now checks expected source, run ID and attempt, complete
runtime identities across modes, one successful import preflight, exact case and
repetition declarations, and every 180-second case result. Missing/malformed or
failed evidence remains a failed disposition. Per-attempt user/temp directories
are isolated and a nonempty output destination is refused. Historical timing
reduction retains explicit failures and ambiguous final observations with unknown
duration rather than manufacturing successful or zero-second samples.

Changed-claim mapping: the test-selection guide owns diagnostic semantics; the
build guide owns dispatch/artifact procedure; roadmap/handover/index routes point
to those contracts and this audit; supplementary retrieval question TEST04 covers
failure preservation, sample accounting and #234 ownership. Existing native
authority, lifetimes, public interfaces, physics configuration, ADRs and user
controls are unchanged. Coarse fixture logging changes observation only; it does
not distinguish calls inside a marked block without stack evidence.

### Original post-instrumentation ordinary execution

[GDExtension run 40074769682](https://github.com/techrote/cybersand/actions/runs/40074769682),
attempt 1, is associated with PR head `1324a30b66696d326a4f3f30a12e909ac4eaf75f`.
Its actual tested synthetic merge checkout, recorded in every timing row, is
`8b7add40bdf51090774639b1eb6ce868bca819a2`. Linux build, all four Linux shards,
Linux aggregate, Windows cross-build, Windows headless and timing reducer passed.
These precede the continuation corrections and cannot admit the corrected head.
All 45 physical-family observations (23 Linux including a rendered flight case,
22 Windows headless) passed. The three suspect cases each have one observation:

| OS | Test | N / pass / timeout / other | Median = p95 = max (s) | Timeout frequency |
|---|---|---|---:|---|
| Windows | actor arena | 1 / 1 / 0 / 0 | 13.750 | 0/1 |
| Windows | actor rigs | 1 / 1 / 0 / 0 | 18.676 | 0/1 |
| Windows | usable course | 1 / 1 / 0 / 0 | 12.448 | 0/1 |
| Linux | actor arena | 1 / 1 / 0 / 0 | 17.000 | 0/1 |
| Linux | actor rigs | 1 / 1 / 0 / 0 | 23.812 | 0/1 |
| Linux | usable course | 1 / 1 / 0 / 0 | 16.449 | 0/1 |

Durations are runner measurements excluding diagnostic overhead. Godot is
`4.7.stable.official.5b4e0cb0f`; Rapier is pinned `0.35.2`. The source-bound raw
timing artifact is `physical-timing-40074769682-1`. Passing these samples does not
erase historical timeouts or establish a mechanism.

Continuation local validation (Windows x86_64, Python 3.12.10):
`test_godot_regression_sharding.py` 24/24, `test_windows_godot_regressions.py`
15/15, `test_physical_timeout_diagnostics.py` 5/5,
`test_physical_stress_contract.py` 12/12 and `test_physical_timing_history.py`
8/8 passed. These include real child timeouts and real Windows thread readback,
pre-kill ordering, cleanup despite capture exceptions, explicit ptrace refusal,
missing/duplicated/mixed-campaign records and retained unknown historical timing.
Documentation, materialized repository provenance, provider policy, M11 historical
integrity and whitespace checks pass with the pinned companion fixtures present.
Frozen retrieval: hit@1 21/32, hit@5 32/32, MRR 0.7953; new supplementary TEST04
retrieves the timeout procedure at rank 1 and covers the required source-backed
qualifiers. These local checks identify the handoff plus reviewed local delta;
the corrected exact-head hosted gates remain required before merge.

## Apparatus admission and merge

PR #241's final head is `4a485e0ea193a199d2a4b9b74241817c92d29fa1`.
Every applicable ordinary gate passed at that exact current PR head:

| Gate | Run / attempt | Result |
|---|---|---|
| Documentation/provenance, provider policy and its tests, materialized runtime identity, M11 integrity and retrieval | [40079743077](https://github.com/techrote/cybersand/actions/runs/40079743077) / 1 | PASS |
| Native behavioral/integration, ASan/UBSan, soliding sanitizers, TSan, shared library and benchmark | [40079743026](https://github.com/techrote/cybersand/actions/runs/40079743026) / 1 | PASS |
| Linux build, Windows cross-build, Windows headless, all four Linux shards, Linux aggregate and timing reducer | [40079743080](https://github.com/techrote/cybersand/actions/runs/40079743080) / 1 | PASS |

The actual PR merge checkout in the hosted execution artifacts is
`eaaeeefe647ca1346ab25e5e250b4ed0ad4f61e3`, tree
`ebfcb673eea4adadf4363928b2b89853b4717d8f`. Windows passed 126/126 cases plus
one import. Linux passed 138/138 cases in shards 32/35/35/36 plus four imports.
No physical timeout, other failure, skip or missing case occurred. Hosted
synthetic counts were 24 runner tests (one Windows-only test explicitly skipped
on Linux), 15 Windows contracts, 5 diagnostics, 12 stress contracts and 8 history
contracts, all applicable tests passing. The skipped Windows thread readback
passed on local Windows. The opt-in Linux serial-equivalence lane was correctly
outside ordinary admission scope. Cancelled/skipped draft checks and the cancelled
superseded-head Native run `40074769669` were not accepted as admission.

| OS | Test | N / pass / timeout / other | Median = p95 = max (s) | Timeout frequency |
|---|---|---|---:|---|
| Windows | actor arena | 1 / 1 / 0 / 0 | 18.397 | 0/1 |
| Windows | actor rigs | 1 / 1 / 0 / 0 | 28.244 | 0/1 |
| Windows | usable course | 1 / 1 / 0 / 0 | 16.825 | 0/1 |
| Linux | actor arena | 1 / 1 / 0 / 0 | 16.442 | 0/1 |
| Linux | actor rigs | 1 / 1 / 0 / 0 | 21.203 | 0/1 |
| Linux | usable course | 1 / 1 / 0 / 0 | 16.752 | 0/1 |

Independent extraction from every raw execution artifact exactly matches all 45
physical-family rows in `physical-timing-40079743080-1`. Both ordinary runs and
their actual checkout/runtime identities are retained in
[ordinary observations](issue-233/ordinary-observations.csv),
[per-run distributions](issue-233/ordinary-distributions.csv) and
[job receipts](issue-233/ordinary-jobs.csv).

During admission `main` advanced through PR #240 to
`a395e33dc0632f5c3f41e8b8b1c18c89f0aaa131`. Its five-file delta consists only
of documentation and additional tests; production native source/headers,
runtime provenance/payloads, suspect fixtures and diagnostic code are unchanged.
Normal merge policy admitted #241 with the exact-head results above, recorded in
[the admission comment](https://github.com/techrote/cybersand/pull/241#issuecomment-6382660313).
It merged at **2026-10-24 09:40:23 UTC** as
`4348516aba4c8e7036370d73afc14e86a19ea6a2` (parents `a395e33…`, `4a485e0…`).
This merge is the selected immutable stress source. Post-merge ordinary
GDExtension run `40082881910`, Documentation `40082881900` and Native
`40082881961` are recorded separately; their outcomes do not replace PR admission.

The actual Windows Godot isolation probe at head `4a485e0…` returned distinct
`OS.get_user_data_dir()`, `OS.get_cache_dir()` and `OS.get_config_dir()` paths
inside each attempt's assigned root, and created distinct engine log files there.
No explicit fixture/dependency writes to user/source files were found; the shared
project import cache is prepared once before physical attempts. Raw local smoke
and probe evidence remains in the isolated worktree's ignored
`build/issue233-local-smoke` and `build/issue233-isolation-probe` directories.

## Stress registration and interpretation method

[Stress run 40082890839](https://github.com/techrote/cybersand/actions/runs/40082890839)
was manually dispatched from the default-branch workflow after merge, attempt 1,
with `source_sha=4348516aba4c8e7036370d73afc14e86a19ea6a2`; the workflow run head
is the same SHA. The registered count remains 600 physical attempts plus 20
import preflights. The complete result and independent readback follow below;
dispatch alone is not completion evidence.

Fixture inspection distinguishes process concurrency from native worker count:
arena and usable-course construct native Worlds with `workers=1` and advance
them synchronously; the rigs fixture uses real Rapier without constructing a
native cellular World. The ordinary desktop asynchronous pacing owner is absent
from these fixtures. The campaign does not manipulate CyberSand's worker count.
A coarse tick is the last **reported** tick before a block of operations, not an
exact stuck tick. A marker before `_arena.step()` cannot by itself distinguish
native progression, bridge/manual Rapier stepping or post-step work. Similarly,
`bridge_shutdown` spans shutdown, body/terrain cleanup and an awaited process
frame. Source call graphs constrain hypotheses; stacks/wait states and raw logs
must qualify any stronger stage attribution.

## Expanded historical timing record, preserving every attempt

Independent readback recovered retained execution JSON and full job logs for all
27 actual regression jobs in the five historical workflow runs, including the
original and rerun Windows jobs. Artifact creation times were checked against
the corresponding job execution; exact full checkout SHAs came from checkout
logs and remain distinct from workflow/PR heads. Eight Linux job receipts copied
into later workflow attempts retain their original execution timestamps and are
counted as **zero new executions**, rather than inflating passing samples.

[Historical observations](issue-233/historical-observations.csv) contain 284
physical-family measurements: 165 Windows and 119 Linux, with 279 passes,
5 timeouts and no other failures. They retain exact source/runtime identities,
run/attempt/job IDs, artifact IDs and log SHA-256 hashes. Read the
[per-source distributions](issue-233/historical-source-distributions.csv),
[selected-cohort distributions](issue-233/historical-distributions.csv),
[actual job receipts](issue-233/historical-jobs.csv) and
[reused receipts](issue-233/historical-reused-job-receipts.csv) together.
This remains a selected historical cohort, not an unbiased frequency estimate.

| OS | Test | N | Pass | Timeout | Other | Frequency | Median (s) | p95 (s) | Max (s) |
|---|---|---:|---:|---:|---:|---|---:|---:|---:|
| Windows | actor arena | 7 | 5 | 2 | 0 | 2/7 | 18.979 | 180.002 | 180.002 |
| Windows | actor rigs | 7 | 5 | 2 | 0 | 2/7 | 27.979 | 180.002 | 180.002 |
| Windows | usable course | 7 | 7 | 0 | 0 | 0/7 | 16.833 | 17.681 | 17.681 |
| Linux | actor arena | 5 | 5 | 0 | 0 | 0/5 | 17.097 | 17.297 | 17.297 |
| Linux | actor rigs | 5 | 5 | 0 | 0 | 0/5 | 23.507 | 23.905 | 23.905 |
| Linux | usable course | 5 | 4 | 1 | 0 | 1/5 | 15.899 | 180.002 | 180.002 |

The five timeout events are Windows arena and Linux usable-course in
`39879178132` attempt 1, Windows rigs in `39978072686` attempt 1, Windows arena
in `40047749353` attempt 1, and Windows rigs in that run's attempt 2. The latter
rerun was itself a failure; it did not replace the earlier arena timeout.
The four Windows timeout logs contain startup banners without a completed
fixture phase. Linux usable-course printed completed digger and runner demo
output before stopping. These old observations lack the new markers, pre-kill
snapshots and stacks; neither an exact stuck tick nor a causal mechanism is
recoverable from them.

The original 30-observation table above remains unchanged. This expanded table
adds the original attempts and uses measured runner JSON durations, explaining
small differences from the original consecutive-log-boundary timings. Raw
historical/ordinary logs, artifact ZIPs, metadata and the collection helper are
retained outside Git at `C:/Users/_/AppData/Local/Temp/issue233-history`.

## Landed ordinary validation

The selected merge `4348516aba4c8e7036370d73afc14e86a19ea6a2` additionally passed
[Documentation/provenance 40082881900](https://github.com/techrote/cybersand/actions/runs/40082881900),
[Native 40082881961](https://github.com/techrote/cybersand/actions/runs/40082881961)
and [GDExtension/Godot 40082881910](https://github.com/techrote/cybersand/actions/runs/40082881910),
all attempt 1. Source in checkout logs, Windows execution and all Linux shard
artifacts is exactly that merge SHA. Windows records tree
`802583391236f335b6113901e1ed421c912af070`.

Windows passed 127/127 cases plus one import; Linux passed 139/139 cases in shards
33/35/35/36 plus four imports. Exact catalogues match discovery without missing,
duplicated, failed, timed-out, skipped or ambiguous cases. The extra
`test_liquid_policy_worker` from PR #240 explains the increase over PR admission.
The 45-row timing artifact matches independent raw-artifact readback exactly.

| OS | Test | N / pass / timeout / other | Median = p95 = max (s) | Timeout frequency |
|---|---|---|---:|---|
| Windows | actor arena | 1 / 1 / 0 / 0 | 20.399 | 0/1 |
| Windows | actor rigs | 1 / 1 / 0 / 0 | 29.120 | 0/1 |
| Windows | usable course | 1 / 1 / 0 / 0 | 18.157 | 0/1 |
| Linux | actor arena | 1 / 1 / 0 / 0 | 16.849 | 0/1 |
| Linux | actor rigs | 1 / 1 / 0 / 0 | 15.341 | 0/1 |
| Linux | usable course | 1 / 1 / 0 / 0 | 16.292 | 0/1 |

Every suspect finishes with its teardown marker and a successful exit. Across all
three ordinary runs, 794 cases and 15 imports passed. Their 135 physical-family
observations are retained separately from the registered stress N in the ordinary
CSVs above; [complete ordinary accounting](issue-233/ordinary-case-accounting.csv)
binds all 15 actual jobs to their case/preflight counts and runtime provenance.

Runtime identities are unchanged across all three ordinary runs and the stress
runtime receipt. The Windows retained build/source is
`c8f14c7bc18d6ed8349d568cb00e47a826313cf9`, whose complete production-input
ledger remains valid for the selected source; that build identity is not being
mislabelled as the diagnostic source SHA.

| Runtime | Actual identity |
|---|---|
| Godot | `4.7.stable.official.5b4e0cb0f` |
| Windows native SHA-256 | `b13805bf1a0bb3452493c6990b212575787f638c30be22613a5cc03b78933d30` |
| Linux native SHA-256 | `2495cedc12de07be3738a76b41ea352e5dff8309d167ea89f7fc430ae89765cf` |
| Windows Rapier 0.35.2 SHA-256 | `4e26ffa78ec2aaff434c4a70cd2ec85288b10ba5237912c35f204cb1e6ed2180` |
| Linux Rapier 0.35.2 SHA-256 | `147ab5673b9687ccb7a3b12fec07ea55cc674ad8a75f529d1085bf7d61fbd831` |

The Linux stress runtime artifact was independently downloaded and its actual
bytes checked against both `runtime.sha256` and the source receipt. A local
Windows marker probe also read `REGRESSION_PROGRESS` from redirected output while
Godot was still alive, 2.013 seconds after launch and before tree termination.
That checks print visibility for the pinned Windows configuration; an absent
marker still does not identify a causal location by itself.

## Complete registered stress campaign

The single campaign [40082890839](https://github.com/techrote/cybersand/actions/runs/40082890839),
attempt 1, executed all five batches in every Windows Server 2022 / Ubuntu 24.04
and serial / three-process-parallel combination. Each batch executed ten of each
declared suspect case. **600/600 physical attempts are present: 589 passed,
11 timed out, zero other failures, zero missing, skipped, duplicated or ambiguous
attempts. All 20 import preflights passed.** No failed batch was retried or
replaced. Every physical timeout remains a failed test and a failed batch.
The 180-second limit was unchanged; diagnostics occur afterward and are timed
separately together with process-tree termination/cleanup. The selected source and the workflow head are both the #241 merge
`4348516aba4c8e7036370d73afc14e86a19ea6a2`.

Independent raw readback inspected all **620 full logs**, all 600 per-attempt
checkpoints and all 20 batch summaries. Every successful physical case has its
fixture's zero-failure receipt, final teardown marker and successful process exit.
Timeout records match their raw markers, complete logs, bounded tails and pre-kill
snapshots. There are no raw identity, status, marker, receipt or integrity errors.
Downloaded ZIP SHA-256 values match GitHub artifact digests. The Linux runtime
ZIP and actual libraries also match the source/runtime receipt; all batch runtime
identities agree with the table above. This is one complete campaign, with no
successful batches borrowed from another run.

The hosted independent gate, job `120848712191`, finished at
**2026-10-24 10:28:57 UTC** and retained artifact `12556858891`. It checked out
the declared exact source and accounted for all 600 attempts. Its overall
**FAIL** is expected: the seven physical batches with timeouts remain failed.
The gate's 600 observation rows agree with both the independent raw reader and
the local reducer for source/runtime/status/progress/elapsed values. All 22
downloaded artifact ZIPs (20 batches, Linux runtime and final gate) match their
GitHub SHA-256 digests. The independent reducer was also run locally against all
20 retained summaries:

```text
python tools/ci/aggregate_physical_stress.py --input build/issue233-stress-40082890839/artifacts --output build/issue233-local-final-gate --expected-source-sha 4348516aba4c8e7036370d73afc14e86a19ea6a2 --expected-run-id 40082890839 --expected-run-attempt 1
```

It correctly returned failure: seven failed-batch dispositions plus eleven
explicit timeout details, with **no source, runtime, completeness or repetition
errors**. The generic batch message says “incomplete or failed”; the raw summaries
establish that all seven were complete batches containing physical timeouts.
The red result is retained diagnostic evidence and is not an infrastructure
failure or a request to rerun the campaign.

### Full timing distributions

All durations are runner-measured seconds, excluding subsequent diagnostics and
termination. The medians, nearest-rank p95 and maxima include timeout observations
at the watchdog, so those observations are right-censored: their unconstrained
completion time is unknown. Values use the production reducer's three-decimal
rounding; exact half-millisecond medians can differ by 0.001 from a separately
formatted independent calculation. All underlying measurements agree.

| OS | Mode | Test | Executed | Pass | Timeout | Other | Frequency | Median (s) | p95 (s) | Max (s) |
|---|---|---|---:|---:|---:|---:|---|---:|---:|---:|
| Windows | serial | actor arena | 50 | 49 | 1 | 0 | 1/50 (2%) | 19.071 | 19.637 | 179.997 |
| Windows | serial | actor rigs | 50 | 48 | 2 | 0 | 2/50 (4%) | 27.632 | 29.490 | 179.999 |
| Windows | serial | usable course | 50 | 50 | 0 | 0 | 0/50 | 17.129 | 18.052 | 18.615 |
| Windows | parallel | actor arena | 50 | 46 | 4 | 0 | 4/50 (8%) | 25.706 | 179.995 | 180.003 |
| Windows | parallel | actor rigs | 50 | 46 | 4 | 0 | 4/50 (8%) | 34.898 | 179.995 | 180.000 |
| Windows | parallel | usable course | 50 | 50 | 0 | 0 | 0/50 | 24.409 | 26.380 | 27.861 |
| Linux | serial | actor arena | 50 | 50 | 0 | 0 | 0/50 | 12.538 | 17.095 | 17.506 |
| Linux | serial | actor rigs | 50 | 50 | 0 | 0 | 0/50 | 15.244 | 24.459 | 24.576 |
| Linux | serial | usable course | 50 | 50 | 0 | 0 | 0/50 | 12.338 | 17.203 | 17.807 |
| Linux | parallel | actor arena | 50 | 50 | 0 | 0 | 0/50 | 24.224 | 24.987 | 25.238 |
| Linux | parallel | actor rigs | 50 | 50 | 0 | 0 | 0/50 | 30.050 | 30.900 | 30.913 |
| Linux | parallel | usable course | 50 | 50 | 0 | 0 | 0/50 | 24.483 | 25.690 | 25.990 |

The [stress observations](issue-233/stress-observations.csv),
[distributions](issue-233/stress-distributions.csv),
[batch receipts](issue-233/stress-batches.csv),
[timeout evidence inventory](issue-233/stress-timeouts.csv) and
[artifact manifest](issue-233/stress-artifacts.csv) retain source/run/runtime
identities and exact evidence routes. The [campaign receipt](issue-233/stress-campaign.json)
records the full completeness and expected failure disposition. The retained
distribution CSV computes medians exactly from the recorded decimal timings to
four places; the audit table uses the hosted reducer's three-place presentation.
These supplement rather than replace the
historical and ordinary records. Raw files remain in the Actions artifacts and
the isolated worktree's ignored `build/issue233-stress-40082890839` cache; the
independent raw report is in `build/issue233-raw-final-600`. Logs, ZIPs, generated
imports and runtime binaries are intentionally outside the source commit.
The artifact manifest records the actual 30-day GitHub retention, expiring on
2026-11-23; the complete downloaded raw cache is retained locally and this
worktree is kept active for the #234 handoff.

### Every reproduced timeout

All eleven are Windows `phase=roster_step` observations. Repetition numbers are
global within each OS/mode/test (1–50); batches are numbered 0–4. “Tick” is the
last reported loop index, and “diagnostics” is additional elapsed time before
return from diagnostic capture and process-tree termination/cleanup, separate
from the failed test's watchdog duration (`diagnostic_seconds` in runner JSON).

| Mode | Batch | Test | Repetition | Last rig | Last tick | Test elapsed (s) | Diagnostics (s) | Engine cumulative CPU (s) |
|---|---:|---|---:|---|---:|---:|---:|---:|
| serial | 0 | actor rigs | 9 | stuntbuggy | 300 | 179.999 | 5.111 | 20.719 |
| serial | 3 | actor arena | 32 | hammerhead | 0 | 179.997 | 4.727 | 14.000 |
| serial | 4 | actor rigs | 47 | arcadelander | 0 | 179.996 | 5.069 | 24.563 |
| parallel | 0 | actor arena | 7 | pouncer | 60 | 179.995 | 5.191 | 7.188 |
| parallel | 0 | actor rigs | 7 | pouncer | 300 | 179.995 | 5.192 | 8.438 |
| parallel | 1 | actor arena | 11 | ripper | 0 | 180.003 | 3.690 | 2.516 |
| parallel | 1 | actor arena | 14 | pouncer | 120 | 179.992 | 0.394 | 3.719 |
| parallel | 2 | actor arena | 22 | ripper | 120 | 179.999 | 5.520 | 3.375 |
| parallel | 2 | actor rigs | 25 | trialsbike | 300 | 180.000 | 0.499 | 21.938 |
| parallel | 2 | actor rigs | 26 | rocketjumper | 300 | 179.993 | 0.468 | 9.188 |
| parallel | 4 | actor rigs | 47 | clamberer | 900 | 179.995 | 4.149 | 11.844 |

Every full retained timeout log was read and its last-60-line pre-kill tail checked
for exact agreement. Every process snapshot command returned exit 0 before tree
termination. The process tree contains the Godot console wrapper and engine child;
each snapshot exposes 15 actual thread records (14 engine, one wrapper), all in
`Wait`: eight `Unknown`, two `UserRequest`, one `ExecutionDelay` and four
`EventPairLow`. Engine cumulative CPU spans 2.516–24.563 seconds across roughly
180-second lifetimes. These are one-time snapshots and cumulative CPU totals,
not sampled CPU trajectories or proof of a deadlock.

**No native stack was captured.** Every Windows snapshot explicitly records
`Native stack capture: unavailable without a preinstalled debugger; process/thread snapshot retained.`
There is no fabricated stack, function, lock owner or wait dependency. Linux had
no timeout in this campaign, so there is no campaign Linux `ps`/wait-channel or
GDB timeout snapshot to interpret. The Linux diagnostic path attempts bounded
process/thread wait-state and GDB capture; debugger/ptrace refusal is covered by
the admitted synthetic tests, not misrepresented as an observed Linux hang stack.

## Final diagnostic classification and #234 handoff

**Hang or slowness: supported intermittent hard stall / bimodal hang.** All 589
passing observations finish within 37.221 seconds; all eleven timeouts fall at
179.992–180.003 seconds, with waiting threads and modest cumulative CPU. Parallel
execution also causes ordinary measurable slowdown, but that does not explain
the separate full-watchdog cluster. The record supports a stalled execution
class without proving a permanent deadlock, a specific lock or one shared cause.

**Platform dependence: both platforms in the retained overall evidence.** This
campaign reproduced Windows 11/300 and Linux 0/300; Windows serial is 3/150,
Windows parallel 8/150, Linux serial and parallel each 0/150. The historical cohort
still contains four Windows and one Linux timeout, including Linux usable-course
in run `39879178132`. Different historical source SHAs and the absence of stacks
prevent claiming that the Linux event and these Windows roster stalls share a
mechanism. The new Linux negative result does not erase that failure or establish
Windows exclusivity; zero observed events is not proof of zero probability.

**Serial versus parallel/co-tenancy: serial reproduction is established;
causal dependence is not established.** Windows arena rates are 1/50 versus 4/50,
rigs 2/50 versus 4/50 and course 0/50 versus 0/50. The observed increase deserves
retention, but five hosted batches per mode, unrandomized machines, clustered
attempts and sparse events do not isolate host co-tenancy or establish a reliable
causal frequency difference. Two parallel-batch-0 cases time out in repetition 7;
that shared context is recorded without treating them as independent proof.
All twelve timing distributions remain separate rather than pooling heterogeneous
tests or platforms into a purported universal probability.

Passing medians increase by approximately 1.26–1.43× on Windows and 1.93–1.98×
on Linux in parallel mode. Linux serial batch 3 is slower than the other four
hosts without a timeout, while Windows parallel batch 1 is among the fastest
passing hosts and still records two arena timeouts. Windows timeout totals by
batch are serial `1,0,0,1,1` and parallel `2,2,3,0,1`. These observations support
separate ordinary load variation and intermittent stall populations; matching
batch indices do not identify paired hardware or equal host load.

**Native worker-count dependence: not distinguishable from this experiment.**
Three-process parallelism manipulates concurrent Godot processes. It does not
manipulate CyberSand's native worker count. Arena/course request `workers=1`
and synchronous world progression; rigs constructs no native cellular World.
This campaign cannot estimate a native worker-count response.

| Candidate | Classification | Evidence and limit |
|---|---|---|
| Active physical roster/manual-step execution family | Supported as the investigation locus | All eleven follow actual `roster_step` markers after setup/world-built. Six are in pure-Rapier rigs without a CyberSand World. The marked block also includes control, observation and validation work. |
| A particular Rapier/manual-step call or deadlock as the cause | Not distinguishable from current evidence | No native frame or wait dependency was captured. A marker does not identify `_bridge.step()`, `space_step`, controller/readback or the exact blocked operation. |
| CyberSand asynchronous native-world worker/pacing owner as a necessary common cause | Contradicted for these reproduced stalls | The desktop asynchronous owner is absent, and the six rigs stalls have no CyberSand cellular World. This does not exclude other native/library threads, arena-specific contributions or the unlocalized historical Linux event. |
| Native World progression as an arena-specific contributor | Not distinguishable from current evidence | Arena's marked block includes synchronous world and bridge work; the snapshot has no native stack. Rigs reproduction rules out World progression as a necessary explanation for all eleven. |
| Final fixture teardown/quit as the location of these eleven stalls | Contradicted for these reproduced stalls | No captured timeout log records current-rig shutdown/final teardown, successful result or quit after its last roster marker. Earlier object lifetime effects that later stall stepping remain possible. |
| A common cause for historical and current events | Not distinguishable from current evidence | Historical events lack new markers/stacks and use other exact sources. |

Arena logs every 60 iterations of its default 240-tick roster; rigs every 300
of 1,200. Rigs `clamberer tick=900` is the final coarse block, so remaining loop
work **and post-loop assertions/readback before `bridge_shutdown`** remain
possible. Every last tick above is a reported index, not a measured stuck
physical tick or proof of entry into one API. No reproduced timeout was before
the first fixture marker, after successful completion or during final quit.

[#234](https://github.com/techrote/cybersand/issues/234) should consume this exact
source, the complete 600-attempt record, all eleven full logs/tails/snapshots and
their manifest hashes, together with the retained historical Linux failure.
The pure-Rapier rigs reproductions narrow the next investigation to the active
physical roster/control/manual-step/observation path without requiring cellular
World progression. A Windows native break stack or equivalent wait-dependency
capture is still needed to discriminate the blocked call; the present thread
snapshot cannot supply it. Root-cause repair, watchdog/recovery design and fresh
repair qualification belong to #234. No speculative actor/liquid/native repair
or retry was implemented under #233.

The #233 diagnostic deliverable is complete once this evidence checkpoint is
admitted: implemented and reviewed diagnostics/markers, exact-head ordinary
admission, merged dispatch workflow, complete immutable-source stress campaign,
full distributions/frequencies, raw timeout evidence and explicit uncertainty.
The parent [#232](https://github.com/techrote/cybersand/issues/232) remains open
for #234's repair disposition. New timeouts are the retained diagnostic result,
not a reason to erase the campaign or keep the diagnostic task open indefinitely.

## Evidence checkpoint and documentation checklist

The evidence-only continuation branch is `codex/issue233-evidence`, based on
current `main` `fd97367acc5bcf5757b9ca69ae594279f0ad96bf` after the unrelated
PR #242 runtime-publication retirement. That advance changes neither the selected
stress source nor its results; the immutable campaign remains at `4348516…`.
This checkpoint changes only this audit, its curated CSV/JSON records and four
existing documentation routes. It introduces no new native/runtime, fixture,
workflow, dependency or user-control change. No new gameplay/physics ADR or
ownership/lifetime/interface/capacity change is needed. Required binaries and
dependency pins remain materialized and unchanged.

The canonical test guide retains apparatus/failure semantics; roadmap and
handover distinguish completed diagnosis from #234 repair, and the documentation
index routes to this dated evidence. Reverse-link/old-label searches preserve
the original historical tables, IDs, failures and reruns. The existing corpus,
retrieval manifest and TEST04 destination still resolve to the canonical test
guide; audits remain outside the default retrieval answer corpus. Recoverable
source checkpoints are the admitted PR head, merge and evidence PR commits.

Final local checks at this evidence delta passed: `python tools/ci/check_docs.py`
(110 documents, 2,509 links, zero errors/warnings),
`python tools/ci/check_repository.py --require-materialized` (all 18 payloads),
`python tools/ci/check_m11_consistency.py` (18 historical records, 28 source
hashes, unchanged audited revision), `python tools/ci/check_ci_provider_policy.py`
and `git diff --check`. Frozen lexical retrieval remains hit@1 21/32, hit@5 32/32,
MRR 0.7953; the separate unchanged 118-question challenge set is hit@1 95/118,
hit@5 118/118, MRR 0.8859. TEST04 remains rank 1 and manual source review confirms
failure preservation, exact campaign accounting, process/native-worker distinction
and #234/#232 ownership. These lexical metrics do not prove deployed semantic
retrieval quality. The evidence-only PR's exact-head hosted documentation result
and final merge/issue disposition are recorded in its admission and completion
comments; ordinary runtime gates above belong to the actual tested source.

Issue-state correction: GitHub automatically closed #233 at 09:40:25 UTC on
#241's merge because it parsed the PR body's negated closing-keyword phrase as
a closing directive. Final state inspection identified this premature transition;
the issue was reopened while #243 evidence admission was pending. That automatic
transition supplies no completion evidence. Intentional completed closure follows
the full campaign/readback and admission of this evidence checkpoint.

## Successor evidence, separately scoped

The [#234 continuation](2026-10-24-issue-234-physical-hang-repair.md) subsequently
reconciles existing open PR #236's native dumps and cooperative deferred-BVH
backport with this admitted baseline. Its fresh offline readback verifies a
historical physical hang in the same official Rapier DLL by exact function bytes.
This does not add a native stack to any of the eleven #233 captures, change
their source/runtime identities, erase a failure or prove that every retained
timeout shared that wait. The successor owns repair admission and a fresh full
600-attempt zero-timeout qualification; this diagnostic issue remains completed.

On 2026-10-24 the successor admitted PR #236 at head
`330ded5aa0937b4a46ea0b5f270583a8e0375931`, merge/source
`13b8e631f3e8fbaa2176ed41afc02c434b11e558`. Its fresh standard campaign
[40129364630/1](https://github.com/techrote/cybersand/actions/runs/40129364630)
completed 600/600 physical passes plus 20/20 preflights, with 0/50 timeouts in
every OS/mode/test stratum. Independent full-log/checkpoint and timing readers
agree with its complete gate. The [successor qualification record](2026-10-24-issue-234-physical-hang-repair.md)
owns those distributions, native-call attribution, cooperative repair and bounded
guards. This later operational qualification does not alter this audit's eleven
timeouts, historical Linux event, source identities or causal limits.
