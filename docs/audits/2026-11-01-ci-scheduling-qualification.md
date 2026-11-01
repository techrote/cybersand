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
are in scope. The initial delivery was for draft review and did not authorize
merge. The owner's subsequent final-integration instruction is recorded below.

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
The original hosted results and independent review disposition follow. Runtime
improvement is measured separately from the reduction in shard count.

## Exact implementation checkpoint and independent review

Implementation commit `9a01d782a6b93cb3878b12e50ee40ebfd502e31b`, tree
`39b73e3bbbd33d4da983d194fd50bf3fa81b19f1`, is the recoverable hosted qualification source in
[draft PR #340](https://github.com/techrote/cybersand/pull/340). The final evidence
checkpoint records documentation only; the implementation identity remains explicit.
The execution policy bytes remain SHA-256
`9eaec2e6318073bff7cfbac209d2d959a751b85ffd63cb94c147e9be237516dc`.

An independent reviewer examined the exact committed scheduler, both runners,
original coverage readers, workflow policies, display preparation and metrics
reduction. A second reviewer independently challenged partition capacity and
history sample semantics. Corrected findings before hosted launch:

- Canonical relative-path sorting makes source fingerprints identical on Windows
  and Linux; only tracked inputs contribute.
- History cohorts identify fixture and platform, malformed input falls back, and
  integer/string spellings cannot inflate the distinct-run sample count.
- The 16-case capacity is enforced on every shard, including adversarial mixtures
  of expensive and cheap cases.
- Windows evidence includes the imported history dependency in its input manifest.
- Local enlarged watchdog policy remains supported, while hosted planning keeps
  the six-hour limit.
- Metrics reject telemetry or successful coverage from another source/run/attempt,
  and distinguish PR head SHA from actual merge-checkout SHA.
- Synthetic Native log and Windows LFS-pointer fixtures now use explicit bytes,
  preserving their intended failure checks on Windows.

The exact-commit reviewer reported no unresolved material finding and independently
reran all 44 Windows coverage-reader tests successfully. The implementation worker's
181 focused tests passed (10 scheduling, 11 planner, 87 shared runner, 19 Windows
runner, 10 Linux reader, 44 Windows reader). Workflow scheduling 10, metrics 7,
provider 6, validation-contract 17, Native-shard 45 (one platform skip), physical
stress 12, Rapier-pair 12 and Linux display-setup 4 controls also passed in their
applicable environments. `check_docs`, materialized `check_repository`, historical
`check_m11_consistency`, provider policy, scheduling policy and `git diff --check`
passed. Retrieval finds the canonical page in the top five for 32/32 frozen and
154/155 supplementary questions; the new CI scheduling question ranks first.
The retained unrelated LCB03 miss is explicit; lexical retrieval is not semantic
answer validation.

## Hosted qualification and measured outcome

Original attempt 1 passed at implementation source `9a01d782`:

- [GDExtension 41261767969](https://github.com/techrote/cybersand/actions/runs/41261767969):
  both complete matrices, cross-builds, independent coverage and timing collection.
- [Native 41261769747](https://github.com/techrote/cybersand/actions/runs/41261769747):
  all six families and the stable aggregate, with no errors in the source-bound
  [retained aggregate receipt](evidence/2026-11-01-ci-scheduling/native-qualification-41261769747.json).
- [Documentation 41261769387](https://github.com/techrote/cybersand/actions/runs/41261769387):
  current documentation, retained history, retrieval, workflow inventory and actionlint.
- [Desktop identity packet 41261769405](https://github.com/techrote/cybersand/actions/runs/41261769405)
  and [Native scope advisory 41261769322](https://github.com/techrote/cybersand/actions/runs/41261769322)
  also passed. Draft-suppressed behavioral jobs are not counted as qualification.

| Measure | Historical #1711 | Fresh-main baseline | Revised original run |
|---|---:|---:|---:|
| Executed jobs (all job records) | 160 (162) | 158 (160) | **45 (47)** |
| Windows / Linux regression shards | 76 / 78 | 75 / 77 | **19 / 20** |
| Median Windows / Linux creation-to-start delay | 19.02 / 22.71 min | 49.23 / 61.68 min | **2m50s / 2m57s** |
| Median Windows / Linux job execution | 82 / 90 s | 79 / 88 s | **193 / 179 s** |
| Peak active workflow jobs | 15 | 9 | **10** |
| Peak active Windows / Linux matrix jobs | 10 / 15 | 9 / 9 | **8 / 8** |
| Average active jobs over complete workflow | 3.00 | 2.27 | **6.65** |
| Workflow creation to last job completion | 105m22s | 123m21s | **20m30s** |
| Total runner execution | 316.28 min | 280.13 min | **136.25 min** |
| Successful case-process time / all runner wall time | 28.55% | 33.06% | **70.59%** |
| Successful Windows / Linux cases | 236 / 237 | 233 / 240 | **233 / 246** |
| Missing expected cases | 13 Linux | 6 Linux | **0** |
| Unexpected / duplicate observed cases | 0 / 0 | 0 / 0 | **0 / 0** |
| Outcome | Failed setup / incomplete coverage | Failed setup / incomplete coverage | **Passed complete coverage** |

The revised run uses **71.9% fewer executed jobs**, **80.5% less end-to-end time**
and **56.9% fewer runner-minutes** than #1711. Comparing only #1711's successful
job time still gives a 46.4% runner-time reduction; the old failed setup costs do
not explain the entire saving. Runner time is summed job wall time, not CPU time
or billing-weighted Windows minutes. Larger median jobs are intentional and
remain far below their unchanged watchdogs.

These are observed whole-system results, not a controlled causal attribution of
every saved second to sharding. The owner upgraded to Pro and the repository
queue was clear at launch; other repositories' occupancy is not observable from
this repository's job data. Native qualification ran alongside GDExtension. API
creation-to-start delay includes intentional matrix-cap waiting; it cannot isolate
runner acquisition from matrix admission or dispatch. Linux starts after its
build, by which time Windows is largely finished, explaining an overall peak 10
despite independent 8/8 limits. No global account cap is claimed. Average active
jobs includes pre-dispatch blocking, while process-time share includes setup and
failed jobs in its denominator; neither measures CPU utilization.

Fresh-main and revised original plans have identical case-name Counters and
identical timeout, flags and display-requirement fields. All 479 revised telemetry
case rows are natural successful completions. Both original hosted independent
coverage readers passed. A separate local Windows reread verifies 233 cases,
19 shards and 252 original logs; Linux verifies 246 cases, 20 shards and 266 logs.
Each platform also passes 15 fresh PLAY readbacks. The Linux local adapter changes
only the derived expected `--path` to the fixed original hosted checkout path;
it does not alter original receipts/logs or derive arbitrary expectations from
untrusted commands. The [independent report](evidence/2026-11-01-ci-scheduling/independent-qualification-41261767969.json)
retains reader receipts, hashes, exact inventory comparisons and adapter scope.
Source/runtime
identity is unchanged: the selected Windows native DLL is SHA-256
`e66b9b04b546b09cb4feea204373faf12a7248abf1701da88fc6ecf87b666ecb`;
the freshly rebuilt Linux native library is
`496bf3df06be2c6bf47b2e5e4ea525ed4d969c3a34cf1a97d71e4668cdc250e6`,
also matching the retained fresh-main bytes. Full source-input and Rapier identities
remain in the original receipts.

The [complete revised reduction](evidence/2026-11-01-ci-scheduling/revised-41261767969.json)
records all job pages, artifact IDs/digests, step categories and actual case costs.
Median preparation / regression-step / publication-and-teardown times are
13 / 175 / 3 seconds on Windows and 23.5 / 152.5 / 2 seconds on Linux.
Regression-step time includes import and independent readbacks. Actual case
processes total 5,770.428 seconds. The whole-workflow critical path is reduced
without claiming all elapsed runner time is useful CPU execution.

## Why retain 19 Windows and 20 Linux shards?

The completed run supports the initial conservative estimates and keeps the
longest actual jobs at 246 seconds Windows and 230 seconds Linux. An offline
16-shard alternative reassigns exactly the same cases with the same algorithm,
using measured case/readback durations and median fixed per-job overhead with
eight idealized slots. Index-order dispatch predicts only 17 seconds Windows
and 31 seconds Linux improvement, about 4.25 runner-minutes total, while longest
projected jobs increase from about 234/230 to 274/275 seconds. Four dispatch-order
sensitivities and their assumptions are retained in the independent report.

One sample does not establish a stable distribution, GitHub dispatch order is not
guaranteed, and regrouping can change runtime. This small uncertain gain does not
justify a second full launch or relaxing the reviewed useful-work target now.
Retain the qualified 19/20 split, then revisit after comparable history accumulates.
No stress campaign was launched and no failed run was replaced by a retry.

## Final integration authorization and evidence boundary

After the initial draft delivery, the owner requested a fresh independent review,
resolution of material findings, ready-for-review transition, all required
exact-head checks, conditional merge and post-merge verification. The prior
`9a01d782` trial remains the measured scheduling qualification; it does not
substitute for those later source-bound gates.

Final independent review starts from PR head
`6080414e75ba6288bf3ee1b520890120009a3b99` against unchanged main
`15b3a4012b9d5998e808fb371792dd7a71398507`. Separate reviewers examine the
scheduler/runners and workflow/evidence contracts. The final
[PR integration ledger](https://github.com/techrote/cybersand/pull/340) records
their disposition, the frozen final head, its actual tested merge-checkout
identity, complete run IDs, guarded merge commit and post-merge results.
These outcomes are recorded there after execution, without changing the source
under an in-flight qualification run or retroactively relabelling earlier trials.

Both fresh reviews found no material production defect. The scheduler reviewer
reran all 181 focused controls and independently compared base/current discovered
case attributes. The workflow reviewer reran actionlint, all 24 inventory checks
and focused contracts, and recomputed retained job/count/timing claims from the
machine reports. An adjacent pre-existing Windows archive-test fixture normalized
its deliberately unsafe backslash name before validation. The final test-only
correction preserves the requested ZIP member bytes and asserts the actual member
name before requiring rejection. Production archive validation was already correct
and is unchanged. All 31 history tests pass on Windows and Ubuntu 24.04 WSL after
the fixture correction; this is not a relaxed archive-admission rule.

Native, GDExtension, Documentation/provenance and the affected PLAY desktop
identity workflow require complete successful results. Water receives an explicit
final-source dispatch when its path filters do not admit the changed workflow,
rather than counting a skipped job as runtime qualification. LIFE009's dedicated
campaign is restricted to historical source: `run_life009_campaign.py` compares
protected production/runtime/workflow inputs against `0bf28d57` and intentionally
refuses current main. Its five cases remain in the complete GDExtension programme
with independent readbacks. That obsolete campaign is not a required current-main
gate, and its source guard is not weakened to manufacture a passing manual run.
Dedicated stress campaigns and historical source-pinned publishers retain their
separate registration and acceptance boundaries.

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
