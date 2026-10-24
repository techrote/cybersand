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

**Unqualified:** There is no completed source-matched diagnostic CI run, no captured hang stack after instrumentation and no dispatched 50-repeat campaign yet. Dispatch requires workflow availability on the repository default branch. Those results must be appended, reviewed and used for the causal discrimination transferred to [#234](https://github.com/techrote/cybersand/issues/234). A rerun passing, a higher timeout or the presence of this apparatus is not issue closure. The 180 s case timeout is unchanged.
