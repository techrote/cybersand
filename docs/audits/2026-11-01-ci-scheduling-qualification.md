---
title: CI scheduling rehabilitation qualification
status: Current
document-kind: evidence
scope: Source-bound scheduling baseline, implementation, hosted qualification and independent review
canonical-for: [ci-scheduling-qualification-2026-11-01]
last-reviewed: 2026-11-01
related-documents: [../operations/ci-execution-and-performance.md, 2026-11-01-ci-workflow-audit.md, ../operations/github-development-and-release.md]
---

# CI scheduling rehabilitation qualification

## Source and scope

Intake fetched `origin/main` at `15b3a4012b9d5998e808fb371792dd7a71398507`
and created `codex/ci-scheduling-rehabilitation-20261101` in
`C:/Users/_/.codex/worktrees/ci-scheduling-rehabilitation/khybersand`.
The original `C:/khybersand` checkout remains on its unrelated material branch
with its dirty native/runtime/generated files preserved. All 18 required LFS
objects materialized and `git lfs fsck` passed. Dependency versions and runtime
bytes are unchanged: Godot 4.7, godot-cpp `101ae380`, pinned SCons 4.10.1 and
the selected Rapier 0.35.2 deferred-BVH backport.

The canonical [execution contract](../operations/ci-execution-and-performance.md)
owns current scheduling and watchdog semantics. The separate
[workflow audit](2026-11-01-ci-workflow-audit.md) covers every workflow. No native
simulation, scientific fixture, per-case watchdog or runtime publication changes
are in scope. This work is delivered for draft review; it does not authorize merge.

## Historical baseline and comparability

The full paginated job inventory for [GDExtension #1711](https://github.com/techrote/cybersand/actions/runs/41250780110)
contains 162 records, of which two are skipped and 160 execute. API head is
`4752aac3`; actual PR merge checkout is
`6f5e48883f476041ef5beb71870b86956bd35e01`. The run **failed**. Four Linux
display-package preparation jobs expired before case execution; Windows coverage
passed all 236 cases, while Linux executed 237 of 250 with 13 absent. These are
infrastructure failures and incomplete coverage, not a successful baseline.

| Measure | Historical #1711 |
|---|---:|
| Executed jobs / all records | 160 / 162 |
| Windows / Linux regression shards | 76 / 78 |
| Median Windows / Linux creation-to-start delay | 19.02 / 22.71 minutes |
| Median Windows / Linux job execution | 82 / 90 seconds |
| Peak active workflow jobs | 15 |
| Total runner execution | 316.28 minutes |
| Creation to last job completion | 105 minutes 22 seconds |
| Pre-dispatch interval | 44 minutes 23 seconds |
| First job creation to completion | 60 minutes 59 seconds |

The prior same-ref run `41243402757` completed exactly when #1711's first jobs
were created. Intermediate pending run `41247393922` was cancelled as #1711
queued. Thus `cancel-in-progress: false` both blocked a newer PR and failed to
preserve all pending attempts under GitHub's default one-pending queue.

Fresh main has 246 Linux and 233 Windows cases, so exact inventory preservation
is checked against fresh main, rather than attributing this pre-existing source
difference to scheduling. The historical advisory telemetry has one observation
per fixture and lacks rows for setup-failed cases. It cannot establish a robust
multi-run performance baseline or completeness. Coverage receipts remain authority.

The [machine baseline](evidence/2026-11-01-ci-scheduling/baseline-41250780110.json)
retains full job/step timing reductions and authenticated artifact identifiers.
`tools/ci/ci_run_metrics.py` collects all pages and rejects duplicates, truncation
and mixed attempts. Creation-to-start delay combines matrix admission, dispatch
and account capacity; the API does not isolate those causes. Regression-step
time includes import, runtime checks and readback, not only useful case work.

## Implementation and qualification record

The expected-cost LPT planner selects **20 Linux and 19 Windows shards** at this
source. Estimates total 5,748.75 Linux and 5,508.75 Windows seconds, with maximum
shard estimate 292.5 seconds on both platforms. Linux estimates range 283.5–292.5
seconds (4–16 cases); Windows 285–292.5 seconds (5–15 cases). These are scheduling
predictions, not measured runtime. The source still discovers exactly 246/233 cases.

The deterministic model uses committed historical weights with a 15-second unknown
fallback and 1.5 margin, plus upward hints for measured slow fixtures. Its 300-second
useful-work target and 16-case density guard avoid one oversized ordinary shard.
A committed history snapshot may increase estimates using a rolling median of at
least three successful comparable runs on each platform, within 30 days of the
snapshot date. Source/fixture/cohort mismatches, failed and incomplete rows and
nonindependent duplicates cannot train it. The initial snapshot is empty because
available source-comparable samples are insufficient; no robust baseline is claimed.

Each hosted regression parent remains 360 minutes: 280 minutes execution, 70 for
setup/artifacts and 10 headroom. Before starting a case, the runner reserves that
case's entire watchdog, readback, diagnostics/cleanup and terminal metadata.
A generous single-case ceiling remains available even if its scheduling estimate
was wrong. An admission refusal writes named unstarted cases and fails the shard;
independent readers reject incomplete, missing, duplicate or foreign evidence.

The bounded matrices permit eight active jobs per OS. Together with the existing
six Native families, routine regression demand is 22 slots plus auxiliary jobs.
This is a per-run capacity choice, not a global 40-job guarantee. Explicit manual
and main-source runs retain unique concurrency groups; only superseded automatic
PR runs cancel. Windows harness/self-watchdog controls run on shard 0 once per
workflow; every fixture still executes exactly once per applicable platform.

The original fresh-main [baseline 41248137886](https://github.com/techrote/cybersand/actions/runs/41248137886)
also failed: two Linux display setups expired, leaving 6/246 cases absent. It used
75 Windows/77 Linux shards and158 executed jobs, with median queues 49.23/61.68
minutes, wall 123m21s and 280.13 runner-minutes. Its successful jobs consumed 248.90
runner-minutes. The requested #1711's successful jobs consumed254.30 minutes;
failed setup jobs account for 61.98 more. Both failure-inclusive and successful-job
costs must be considered when interpreting any speedup.

Local Python 3.13 Windows and Python 3.12 WSL checks are supplemented by actual
GitHub-hosted qualification below. actionlint 1.7.12 validates the whole workflow
inventory; syntax validation has shellcheck/pyflakes integration disabled.
Hosted results and independent review disposition are recorded as they complete.
No runtime improvement is claimed from shard count alone.

## Documentation change map

| Contract | Disposition |
|---|---|
| Scheduling/watchdogs, cancellation, capacity | Updated canonical CI execution and development/release guides |
| Source identity and platform evidence | This dated audit plus machine reductions; historical records unchanged |
| Discovery, immutable case evidence and independent readers | Complete inventory required; aggregation remains fail closed |
| Native ownership, simulation interfaces, gameplay and scientific inputs | Unchanged; no architectural ADR required |
| Roadmap, handover, retrieval/index routes | Updated to the new CI contract and audit |
| Build/test controls | Policy checker, planner and workflow validation commands retained in source |

Local documentation validation uses the same companion commit as CI,
`6a58311982941b75f46e22109a0829e5acb83c7e`, materialized outside the source
worktree. The first source-only check correctly reported six absent companion
references; supplying the pinned companion resolved them without checker changes.
