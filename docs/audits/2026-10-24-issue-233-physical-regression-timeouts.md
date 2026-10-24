---
title: Physical regression timeout diagnosis for issue 233
status: Current
document-kind: evidence
scope: Dated historical GitHub Actions Godot timeout evidence, provisional classification and limits of the proposed diagnostic apparatus
canonical-for: [issue-233-physical-timeout-evidence]
last-reviewed: 2026-10-24
related-documents: [../operations/testing-validation-and-replay.md, ../operations/github-development-and-release.md]
---

# #233 physical regression hang baseline — 2026-10-24

## Source, scope and original failures

Current diagnostic branch: `chatgpt/issue-233-physical-timeout-diagnostics`, based on `main` commit `1e032e492cafb232e604baf6e2b823b13d779aa8`. This dated table derives from **five selected actual GitHub-hosted GDExtension runs per platform**, using the latest available job attempt for each run; it does not assert a completed diagnostic stress campaign.

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

New proposed source: `run_godot_regressions.py` captures bounded last-60-line tails, elapsed test duration, process snapshot/native debugger attempt before tree termination, and last phase; all timeouts remain failed. Affected fixtures emit coarse setup/world/tick/teardown markers. `physical_timing_report.py` and the GDExtension timing job produce future per-platform CSV median/p95/max/timeout records. `physical-timeout-stress.yml` is dispatch-only, exact-SHA, hosted Windows/Linux, serial and three-process parallel, five batches of ten per case: 600 total attempts. `aggregate_physical_stress.py` rejects missing/failed/duplicated evidence.

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
