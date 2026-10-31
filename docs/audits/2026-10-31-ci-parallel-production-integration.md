---
title: Production CI parallelism integration
status: Current
document-kind: evidence
scope: Source-bound promotion of six Native families and four Windows Godot shards with unchanged scientific coverage and command deadlines
canonical-for: [ci-parallel-production-evidence]
last-reviewed: 2026-10-31
related-documents: [../operations/github-development-and-release.md, ../operations/testing-validation-and-replay.md, ../operations/local-build-and-validation.md, ../reference/validation-evidence.md]
---

# Production CI parallelism integration

The owner requested reconciliation and implementation of
[#311](https://github.com/techrote/cybersand/pull/311),
[#313](https://github.com/techrote/cybersand/pull/313) and
[#314](https://github.com/techrote/cybersand/pull/314) during the separate
PLAY-PACE-003 investigation. The bounded production write set is registered in
[#305 comment6537154140](https://github.com/techrote/cybersand/issues/305#issuecomment-6537154140).
Its branch is `ci/parallel-production-integration-20261031`, based on main
`b55ce690f9a3d2ca3026674a2e9c6a7635966f59`. The three original trial branches
and their evidence remain intact. Their original branch-only workflows would
not accelerate mandatory validation merely by being merged unchanged.

This record describes the prepared production implementation and the completed
source-bound predecessor trials. The linked ownership/qualification ledger is
the durable join for the resulting commit/tree, first-attempt runs, reviews,
integration lease and post-merge results. **Predecessor passes do not qualify
this new tree.** No skipped job, missing artifact or partial matrix is a pass.

## Fresh reconciliation and retained predecessor evidence

| Trial | Frozen head and tree | Original result and scope |
|---|---|---|
| Six Native families, #311 | `3ed088cfa3d289dd18b6e40bf1d7e810a6785ea5`; tree `34dbadbc4ecfd1a9e832090f4d5f458d764eeff2` | [41139999997](https://github.com/techrote/cybersand/actions/runs/41139999997), attempt1 PASS, all six families plus policy and independent aggregate |
| Scope advisory, #313 | `730926d7eb059605ba6d5167dbcf244967656786`; tree `a0e364ac92d705be7469883d33514fc953cc06e0` | [41147668752](https://github.com/techrote/cybersand/actions/runs/41147668752), attempt1 PASS for report-only classification; Native skip remains unauthorized |
| Four Windows shards, #314 | `d1e9e747600d988783728f301b072326a0b35c1a`; tree `d72f99d5906cb9cd0ca1761137750decec47e06f` | [41147691386](https://github.com/techrote/cybersand/actions/runs/41147691386), attempt1 PASS, four actual Windows runners and independent coverage verifier |

All three were still draft on reconciliation, with no submitted substantive
review or unresolved inline thread. Their current bodies retain their earlier
owner holds; this separately registered implementation follows the owner's
new instruction and does not rewrite those historical dispositions. Their
draft-skipped mandatory Native/Godot jobs supply no production qualification.
The original #313/#314 Documentation runs passed their applicable checks, but
their runtime-provenance step was skipped and is recorded as such.

Independent #311 readback retained seven original ZIPs and eight decoded
original job logs. All six family receipts bind the same exact source,
run/attempt, workflow, Makefile, original serial workflow and log SHA-256.
TSan, ordinary and ASan+UBSan each contain the exact ordered 164 source-derived
native test labels. The physics CLI artifact retains 154 invocations: 106 valid
exit-zero cases and 48 expected-invalid exit-one controls, with all 308 original
stdout/stderr hashes and frozen-source assertions verified. The original
qualification receipt is SHA-256
`999c26815f45aee1cdd3315c4406c56f9c9f6c99a33fd89c3f73d5f18fb6349d`.

The Native trial preserves all 20 original timeout-wrapped command strings and
sanitizer environments, but **widens five deadlines**. Its PR body mentions
only the TSan run change; the source is more extensive:

| Command boundary | Original mandatory limit | Experimental #311 limit | Production integration |
|---|---:|---:|---:|
| TSan build | 15 minutes | 20 minutes | 15 minutes |
| TSan suite | 15 minutes | 25 minutes | 15 minutes |
| ASan+UBSan build | 15 minutes | 20 minutes | 15 minutes |
| ASan+UBSan suite | 15 minutes | 25 minutes | 15 minutes |
| Eight soliding sanitizer executables, build | 20 minutes | 25 minutes | 20 minutes |

The interval between #311's first and last TSan pass lines is about 14m07s,
but the original log has no exact test-invocation start marker. That interval
does not retroactively prove compliance with the original 15-minute bound.
The production port restores every original limit and requires fresh execution.
The earlier #308 full-suite TSan exit124 at
[41118526721](https://github.com/techrote/cybersand/actions/runs/41118526721)
remains failed and unexplained; parallel scheduling is not a native-code repair.
The first invalid-workflow and missing-physics-sanitizer-environment #311 trials
remain negative evidence as recorded in the original PR.

Independent #314 readback verifies the same **201 applicable Windows cases**
in its four-way trial and the two-way main baseline
[41103287549](https://github.com/techrote/cybersand/actions/runs/41103287549).
The four-way artifacts contain 205 original process logs, including four imports;
the two-way artifacts contain 203, including two imports. All 760 execution-input
and runtime hashes agree between the workloads. Both used Windows image
`20261025.346.1`. Git's actual Windows checkout filters were used for 124
`text=auto` paths; the first Linux-byte-only readback refusal is retained rather
than normalizing original logs or binaries. The complete comparison receipt is
SHA-256 `8f0c93975f72576c97a605cf5274df69af88d6e2ba425c1df482e0d81ebf3738`.
The later #308/#310 source has 208 applicable Windows cases: those cases must
be discovered and executed on that resulting head, not inferred from this trial.

## Measured elapsed time and limits of the comparison

| Measurement | Earlier two-way Windows baseline | Four-way Windows trial |
|---|---:|---:|
| First Windows shard start to coverage completion | 24m22s | 11m43s |
| Slowest actual Windows job | 24m09s | 11m29s |
| Slowest assigned-case execution step | 23m31s | 10m50s |
| Sum of Windows shard job occupancy | 38m33s | 39m14s |

The Windows branch's active span is 51.9% shorter in this matched-content pair,
while total runner occupancy is similar. This supports parallel elapsed-time
improvement rather than removed test work. It is one historical pair, not a
statistical performance guarantee; physical hosts and background load differ.
The baseline Linux build-to-aggregate span is 21m04s and remains a separate
critical path. Windows-only timing does not prove an eleven-minute full Godot run.

The six-family Native trial takes 23m41s from workflow creation to completion,
or 22m32s from first actual job start to last job end. Historical serial Native
examples in #311 exceed 80 minutes, but are not a controlled same-head pair.
The new production workflow's original-deadline critical path must be measured
afresh. Queue time, active job elapsed time, sum of runner occupancy and actual
test-process CPU are different measurements. No under-30-minute production
guarantee is claimed before the resulting-head matrix finishes.

## Production implementation and preserved contracts

The [Native workflow](../../.github/workflows/native.yml) schedules six independent
GitHub-hosted Ubuntu families: TSan; ordinary/C-header/shared-library/benchmark;
ASan+UBSan; physics CLI and normal/sanitized world generation; ordinary
soliding, benchmarks and Stage-3 apparatus; and the resource-characterized
settled-region build followed by all eight soliding sanitizer binaries and
their complete contract suite. All original commands,
assertions, repetitions, fixtures, environment overrides and per-command bounds
remain. `fail-fast: false` allows other families to retain their first outcomes
when a sibling fails. The stable procedural gate remains `native`.

The [Native evidence verifier](../../tools/ci/verify_native_shards.py) rejects
missing, duplicate, failed or foreign family receipts and mismatched source,
run/attempt, apparatus or original-file hashes. Its focused adverse tests exercise
those failure paths. A complete tracked and nonignored-untracked checkout
fence includes transitive Stage-3 scientific helpers. The aggregate rehashes
original logs, numeric family and capture exit codes, all required physics
invocation streams and both Stage-3 JSON outputs against each producer receipt.
An aggregate cannot credit a failed/skipped producer or accept another source's
successful artifact. Per-family logs and source receipts remain available after
failures, including a simultaneous command timeout and log-capture failure. Hosted provider and draft/ready admission rules
are preserved; there is no provider migration or successor scheduler.

The [Godot workflow](../../.github/workflows/gdextension.yml) changes only the
Windows partition count to four and strengthens Windows coverage admission.
The coverage job uses the producer's exact ready/scope predicate, then runs even
when an admitted matrix fails, is cancelled or lacks an artifact. It independently
verifies source, runtime identity, exact assignments, unique complete case union
and original logs, and explicitly requires the matrix to have succeeded.
Its original negative verifier output is retained. All eight other jobs, Linux
graphical execution, build/physics/timing paths and every existing deadline stay
unchanged. No old trial harness replaces current source.

The [scope classifier](../../tools/ci/native_scope_classifier.py) is report-only.
It authenticates immutable base and executed-head commits/trees, the clean source
checkout and its own committed bytes, then uses a NUL-delimited Git diff with
`--no-renames` so both sides of a rename are classified. Raw path validation
precedes path normalization; malformed, empty, duplicate and unknown inventories
remain conservative. The original 20 fixtures now use checks that execute under
optimized Python. Additional real-Git adverse tests cover wrong/dirty/untracked
source, removed/renamed Native paths, malformed identities and control characters.
The old live historical-PR API probe is omitted from routine execution; its
original result remains retained with its base/rename limitations.

`native_skip_authorized=false` and `existing_native_merge_gate_changed=false`
are unconditional in every advisory. No Native or Godot job consumes an exemption.
The advisory therefore contributes **no claimed runtime saving** and is not a
complete future dependency-skip proof. A skip policy requires its own owner
decision and source-dependency audit.

## Completed source review and local failure controls

Independent review found and resolved two Native evidence defects before
publication: a source fence omitted executed `tools/experiments` helpers, and
the first aggregate did not bind scientific output bytes. The revised source
rejects real tracked/untracked helper drift and missing/corrupted retained
outputs. Thirty-eight focused tests pass normally and under optimized Python;
39 actual-shell synthetic controls preserve all 20 original timeout positions,
numeric command and capture failures, and the inner worldgen pipeline failure.
Seven missing/corrupted temporary copies of original scientific evidence fail
the aggregate. These controls are not hosted scientific-suite execution.
The final independent Native review receipt is SHA-256
`a3cb5628df24a3b87b94921daabe80aed6f10d46c53aa43c41e64dc3be0b7f7c`.

Windows source review preserves all eight unrelated jobs and all deadlines.
Its 28 existing verifier tests pass normally and optimized; six actual shell
controls reject failed, cancelled, skipped, absent and verifier-failed matrix
outcomes. Independent review receipt is SHA-256
`34d18dd32c19a162850245242b472309217731200af8919b10cebc3c331c5e93`.
The advisory retains all 20 original fixtures and adds 17 adverse/Git test
methods; both modes pass without skips. Documentation, M11, repository and
provider checks pass locally. The frozen historical retrieval questions remain
unchanged; the separate three-question CI development set passes all three
retrieval targets and its expected facts were checked against actual source.

The earlier Native invalid-workflow run 41138769680 and cancelled run
41138830547 remain original negative evidence, including all available logs
and artifacts; neither supplies a complete 164-case family result. Their
independent receipt is SHA-256
`36cdd35b85240b6e669d06035f4489b15e574114f608fef789839d589f17927a`.
The complete visible #313 history retains two source commits, four attempt-1
runs, two executed jobs, twelve skipped jobs and both original ZIPs; its receipt
is `ae7232573c6635acc4409fe743ff9437767e65a868128007f9a49b2c38fd9500`.
No skipped or unavailable execution is represented as a pass.

## Qualification, integration and separate PLAY hold

The production integration needs substantive source review and exact-head
Documentation/provenance, all six original-bound Native families plus aggregate,
all applicable Windows/Linux Godot jobs and scope-advisory adverse controls.
Retain the first attempt, all original logs/artifacts and SHA-256 receipts. Inspect
every failed or skipped job; no workflow aggregate substitutes for actual coverage.
Guard any integration with both the reviewed PR head and freshly reconciled main.
Retain the post-merge main results separately from pre-merge tree equivalence.

The active #309 shader/lifecycle investigation remains a separate write set.
Its original #310 head281 Native run was allowed to complete before any #310
push; it was not cancelled to obtain a faster replacement result. Accepted CI
changes may be consumed by #310 without writing the owner-held #308 branch.
The actual Main 30-second acknowledgement and 180-second case deadlines, Linux
LIFE008 15-second operation budget, scientific/training isolation and authentic
runtime/LFS identities are unchanged. Faster CI does not repair Windows PACE,
close #309/#269/#270/#263 or authorize merging #308 while its complete resulting
acceptance matrix remains red. Scheduswarm remains paused.
