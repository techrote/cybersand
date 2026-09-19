---
title: Issue 12 Stage 3B production implementation plan
status: Approved design
document-kind: runbook
scope: Dependency, ownership, gate and validation routing for Stage-3B locality/scalability implementation
canonical-for: [soliding-stage3b-production-plan]
last-reviewed: 2026-09-19
related-documents: [../audits/issue-12-2026-09-19/stage3b-parent-decision.md, ../audits/2026-09-19-issue-69-stage3b-validation.md, soliding-stage3-freeze.md, soliding-stage3b-astra-review.md, soliding-programme.md]
---

# Issue 12 Stage 3B production implementation plan

## Current base and boundaries

Production decomposition is approved from `main`
`35d03001257e0e2a3f60fa7ce6c9f6774c93e9d7`, the same head inspected by the
read-only architecture reviews.

Issue #12 remains the programme parent. Stage 3A remains the untouched
correctness/control reference. Stage 4 remains blocked.

The decomposition checkpoint above originally observed issue #29 / PR #55 as
independently active. **Reconciled 2026-09-19:** PR #55 has since merged into
`main` at `910717aac101363ec2b1b89e4041a22bc9a97b97`. Stage 3B continues
to observe authoritative interaction mutations without duplicating INT-000
semantics. The #69 evidence lane deliberately remains independent of the merged
MicroScenario/workbench and interaction-rule surfaces.

## Work packages

| Issue | Package | Prerequisites | Main result |
|---|---|---|---|
| #56 | Record parent decision and implementation authority | parent decision | Repository execution authority and routing |
| #57 | Resolve event effect-footprint / dependency-halo contract | #56 | Closes P4 before event producer work |
| #58 | Harden observer lifecycle/reset/allocation failure | #56 | Safe lifecycle/failure foundation |
| #59 | Runtime-size Stage-3A-equivalent storage | #58 | Remove compile-max small-world allocation without semantic change |
| #60 | Canonical bounded spatial indexing | #59 | Bounded deterministic registration/lookup |
| #61 | Sparse mutation and worker witness core | #60, #58 | Change-driven payload witnesses |
| #62 | Indexed activity/deadline sparse state | #61 | Remove observer deadline/activity resident polling |
| #63 | Sparse mask/event/inclusion/coverage witnesses | #62, #57 | Complete non-payload producer coverage |
| #64 | Exact local graph/face/reverse retirement indexes | #60, #59 | Local incidence and dependency invalidation |
| #65 | Resumable exact reconstruction/reclamation/fairness | #63, #64 | Correct generic split/delete backend |
| #66 | Certified local replacement and bridge/merge fast paths | #65 | Safe locality optimizations |
| #67 | Publication aggregates and staged digest compatibility | #66 | Honest/local publication cost |
| #68 | Typed local/subregion observation contract | #67 | Unambiguous local/blocked/global outputs |
| #69 | Preregister validation apparatus/run-plan schema | #56 | Candidate-independent evidence plan |
| #70 | Execute registered campaign and parent exit packet | #68, #69 | Exact-head Stage-3B evidence for parent admission |

## Dependency graph

```text
#56 authority
 ├─ #57 event/halo decision ------------------------------┐
 ├─ #58 lifecycle -> #59 sizing -> #60 index             │
 │                              ├─ #61 -> #62 -> #63 ----┤
 │                              └─ #64 -------------------┤
 │                                                       v
 │                                                     #65
 │                                                      |
 │                                                     #66
 │                                                      |
 │                                                     #67
 │                                                      |
 │                                                     #68
 └─ #69 validation preregistration ----------------------┤
                                                        v
                                                       #70
                                                parent admission
```

#65 is the join between the producer and graph lanes. #57 only gates the
event/coverage completion in #63. #69 is intentionally early and mostly parallel.

## Ownership and concurrency

### Central World producer lane

Issues #61, #62 and #63 are serialized under one integration owner because they
touch authoritative World mutation/tick/activity/event paths. Re-read current #29
before each handoff. Do not preserve a stale branch merely to avoid integrating
newly landed authority-preserving changes.

### Graph lane

Issue #64 should remain primarily inside settled-region graph/index internals and
may proceed in parallel with #61-#63 after #60 lands. It must converge with #63
before #65.

### Evidence lane

Issue #69 proceeds after #56 without candidate semantic changes. Its executable
preregistration contract is `tools/experiments/stage3b_validation.py`; the dated
[issue #69 evidence record](../audits/2026-09-19-issue-69-stage3b-validation.md)
records the fixture/schema inventory and qualification boundary. The final
campaign may use MS-001 only as supplemental integration evidence after exact
source/runtime identity is fixed.

### Historical branches

PR #23 remains Phase-0 evidence and is not a production base. It must not serialize
current Stage-3B work.

## Gates

| Gate | Closed by | Meaning |
|---|---|---|
| G0 production authority | #56 | Stage-3B implementation routing is canonical |
| G-P4 event footprint | #57 | Sparse event observer semantics are explicit |
| G1 lifecycle safety | #58 | Reset/replacement cannot revive stale observation |
| G2 runtime sizing | #59 | Capacity-sized reference preserves Stage-3A semantics |
| G3 indexed geometry | #60 | Registration/lookup have bounded deterministic structure |
| G4 producer completeness | #61-#63 | Every frozen producer route is witnessed or safely fenced |
| G4 graph incidence | #64 | Exact local graph and reverse invalidation exist |
| G5 exact backend | #65 | Generic split/delete works before fast paths |
| G6 publication policy | #67 | Residual global fold or composable digest cost is explicit |
| G7 consumer contract | #68 | Local/blocked/global observation meanings are distinct |
| G8 evidence | #70 | Exact-head campaign ready for parent Stage-3B decision |

None of these gates admits Stage 4.

## Required ordering principles

- correctness/failure hardening before optimization;
- semantic-equivalent runtime sizing before capacity-policy changes;
- bounded index before locality claims;
- reverse incidence before local-retirement claims;
- generic exact reconstruction before any fast path;
- a fast path must differentially match #65 and fall back on ambiguity;
- local observations cannot make global benchmarks look faster by changing result type;
- final measurements require one coherent frozen authoritative source baseline.

## Validation programme

The final campaign preserves Current/discovery-off and untouched Stage 3A as
controls and includes the runtime-sized reference plus useful candidate
intermediate arms.

Fixtures must include genuine one-cell material/state/temperature edits; the old
8x8 local-edit and full-column bridge controls under their real definitions;
large connected topology, true bridge/non-bridge/split cases; absent/resident-
untracked/new-coverage cases; future/earlier/cancelled/excluded deadlines;
no-write activity; event/mask/inclusion ABA; local churn versus remote progress;
every important capacity/refusal mode; allocation-failure injection; deterministic
worker/allocation/insertion permutations; and reclamation/peak-memory cases.

Use workers 1 and 4, at least five sequential process repeats per paired final
campaign cell, preregistered balanced ordering, ASan/UBSan and feasible TSan.
Preserve failures, refusals, timeouts and incomplete jobs as evidence.

No numerical acceleration percentage is preregistered. The exit review must
address safety, producer locality, index locality, memory reconciliation, bounded
deletion/service, unrelated remote progress, publication honesty/locality and
evidence quality.


## Issue #69 registered campaign contract

The candidate-independent #69 apparatus freezes the experiment shape before the
final candidate exists.

- Arms are explicit for Current/discovery-off, untouched Stage 3A, runtime-sized
  Stage-3A-equivalent, optional sparse-producer/indexed-graph intermediates and the
  complete Stage-3B candidate. Missing arms are marked unavailable rather than
  silently dropped.
- The fixture catalogue has 168 versioned logical fixtures. Historical
  `local-edit` remains an 8x8 patch and historical `bridge` remains a whole
  column; separate genuine one-cell tuple and topology fixtures carry an exact
  one-cell mutation contract.
- Workers are exactly 1 and 4. Drain-to-completion and fixed primitive budgets
  `1, 8, 64, 256, 1024` are registered. A whole-region loop is never counted as
  one primitive and the new primitive count is not equated to Stage-3A abstract
  work units.
- Paired drain cells and interruption-sensitive fixed-budget cells use five
  sequential process repeats. Correctness-only drain qualifications are single
  deterministic processes unless a pre-results amendment is registered.
- A fixed SHA-256 cell shuffle and balanced normal/reversed arm order are recorded.
  Final benchmark processes are sequential/uncontended and warm-up/qualification
  output remains separate.
- The default generated final plan has 6,488 run records. This is a deliberately
  bounded matrix rather than a wasteful Cartesian duplication of semantically
  meaningless Current/historical fixed-budget cases.
- Result schema v1 retains explicit success, correctness failure, refusal, timeout,
  source failure, failed-world, unavailable and not-applicable states plus exact
  source/compiler/runtime/hardware/order provenance. Slow performance remains a
  measurement, not a threshold-derived failure state.
- Reducer schema v1 preserves terminal states, high-water/refusal evidence and an
  exact provenance index; flags missing/insufficient samples; summarizes declared
  numeric metric populations directly; and encodes no candidate winner or universal
  percentage-speedup threshold.

#70 must freeze one authoritative simulation/material baseline, exact source/runtime
identity for every available arm, final capacities, compiler/artifact identity,
target host/OS/power mode and any interface-driven pre-results amendment before
executing the registered plan. Untouched historical Stage 3A remains a separately
identified reference series when it cannot share the matched authority.

## Immediate execution order

1. Complete #56 and merge the authority/routing PR.
2. Start #57, #58 and #69 in parallel.
3. #58 -> #59 -> #60.
4. After #60, run #61-#63 as the serialized World-producer lane while #64 runs as
   the parallel graph lane.
5. Join at #65.
6. Only then #66 -> #67 -> #68.
7. Freeze one coherent candidate and execute #70.
8. Return #70 to the supervising parent. Do not self-admit Stage 3B.

