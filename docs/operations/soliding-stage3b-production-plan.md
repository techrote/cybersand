---
title: Issue 12 Stage 3B production implementation plan
status: Approved design
document-kind: runbook
scope: Dependency, ownership, gate and validation routing for Stage-3B locality/scalability implementation
canonical-for: [soliding-stage3b-production-plan]
last-reviewed: 2026-09-20
related-documents: [../audits/issue-12-2026-09-19/stage3b-parent-decision.md, ../audits/2026-09-19-issue-69-stage3b-validation.md, soliding-stage3-freeze.md, soliding-stage3b-astra-review.md, soliding-programme.md]
---

# Issue 12 Stage 3B production implementation plan

## Current base and boundaries

Production decomposition is approved from `main`
`35d03001257e0e2a3f60fa7ce6c9f6774c93e9d7`, the same head inspected by the
read-only architecture reviews.

Issue #12 remains the programme parent. Stage 3A remains the untouched
correctness/control reference. Stage 4 remains blocked.

Issue #29 / PR #55 merged independently as
`910717aac101363ec2b1b89e4041a22bc9a97b97` while #57 was being prepared.
That merge changed interaction/material-rule, `native/tests/test_world.cpp` and
MicroScenario/workbench surfaces, but did not change `native/src/world.cpp`,
World event/discovery geometry or settled-discovery internals. Stage 3B observes
authoritative interaction mutations; it does not duplicate INT-000 semantics.
Recheck current ownership before the later central World producer handoffs.

## Live execution checkpoint — 2026-09-20

Authoritative main has advanced through #60 / PR #78. #56, #57, #58, #59, #60
and #69 are complete. #61 is now the serialized central-World producer owner;
#62 then #63 remain downstream. #64 is dependency-ready as the separable
graph/index lane and may run in parallel only while its actual write set remains
disjoint from #61-#63. #65 is still the join.

The development-claims remediation programme does not pause this lane. REM-002
#81 must inspect live #61-#63 ownership before touching body/World/test surfaces
and stop on a real collision. Stage 4 remains blocked.

## Resolved #57 event/halo contract

Issue #57 originally inspected the event/discovery source at
`910717aac101363ec2b1b89e4041a22bc9a97b97` and revalidated the same facts
after merge-based reconciliation against current `main`
`17f01f729b41da0e0a635a279b6e72684422cdd4`. This resolves G-P4 for the later
#63 producer package without changing Stage-3A source or event physics.

For an accepted explosion with radius `R`:

- the authoritative **effect footprint** has maximum cell reach
  `E = R + 2`; execution may clear cells inside `R`, convert eligible Wall
  in the outer two-cell annulus to granular Stone, and set the centre to Fire.
  `collapse_strength = 0` or target/random conditions may make an individual
  event sparser, but `E` is the source-proven conservative maximum for the event
  kind. The event performs no temperature write;
- the configured **dependency halo** is the independent
  `r = maximum_rule_radius` rule/scheduler reach;
- the required **pending observation footprint** at acceptance is the inclusive
  axis-aligned box with half-extent
  `P = E + r = (R + 2) + r`.

Thus #63 must mark every tracked discovery tile intersecting
`[x-P, x+P] × [y-P, y+P]` pending before event execution. `R + r` is too
small when `r < 2`; `R + max(2, r)` fails to add the dependency halo beyond
the event's actual effect reach. The default `r = 2` previously hid the
distinction because current Stage-3A marks only `R + 2`.

The current source discrepancy is deliberate follow-on work, not a #57 source
edit: `World::queue_explosion`, `World::observe_discovery_event` and
`World::discovery_signals` currently use only `R + 2`. #63 owns changing
the sparse event/coverage producer to the resolved formula after #62 and #57.

Implementation requirements for #63 are:

- use checked signed endpoint arithmetic for `P`; negative coordinates and
  discovery-tile/activity/chunk face and corner crossings use the same formula;
- never reject or alter an otherwise accepted authoritative event solely because
  discovery cannot represent/index the wider observation footprint;
- when `P` cannot be represented or local incidence capacity cannot preserve
  integrity, conservatively fence/refuse discovery, escalating to an
  observer-wide quarantine when necessary, until the event obligation drains;
- absent/resident-untracked coverage remains an observation state, not a reason
  to change event acceptance. Coverage registered before event drain must inherit
  pending state when it intersects `P`;
- overlapping events retain independent obligations; shared coverage clears only
  after every intersecting event drains, with no counter underflow/early clear;
- rejected events create no pending state;
- no deferred event kind other than `ExplosionCommand` exists at the inspected
  head. Any future kind needs its own source-proven effect footprint or a
  conservative fence.

The #63 regression matrix must cover default `r = 2`; valid smaller
`r = 1`; a valid larger `r > 2`; minimum legal `R = 1`; rejected
`R = 0`; face and corner crossings; negative coordinates; overlapping events;
absent/untracked coverage registered before drain; acceptance-before-execution;
successful drain including a halo-only tile; rejected radius/capacity/
authoritative-endpoint events; and the case where authoritative `R + 2`
coordinates are representable but the wider observation expansion is not.
Retain the existing event-before-execution/drain and deferred-explosion physics
tests as existing evidence rather than duplicating them.

Evidence continuity for this decision is
`13a26b78b1ef4d6eafa5f2fc649c79976a2eb6ac` (preparatory briefing boundary)
through `35d03001257e0e2a3f60fa7ce6c9f6774c93e9d7` (architecture-review head):
the relevant Stage-3 native source/tests/bench were unchanged across that
interval, and intervening MS-001/CI integration was not a fresh Stage-3 timing
campaign. The Stage-3 native event/discovery source also remained unchanged
between the architecture-review head and the #57 inspected source head. Final
revalidation against `17f01f729b41da0e0a635a279b6e72684422cdd4` found that
intervening #58 changes are limited, for this contract, to discovery
retirement/reset lifecycle ordering; explosion acceptance/execution, the
`R + 2` event effect reach, independent `maximum_rule_radius` semantics and
the existing Stage-3A event observation footprint are unchanged. PR #75's
intervening change is CI routing only.

## Work packages

| Issue | Package | Prerequisites | Main result |
|---|---|---|---|
| #56 | Record parent decision and implementation authority | parent decision | Repository execution authority and routing |
| #57 | Resolve event effect-footprint / dependency-halo contract | #56 | P4 resolved: explosion pending half-extent `(R + 2) + r` |
| #58 | Harden observer lifecycle/reset/allocation failure | #56 | G1 closed on main by PR #72: safe lifecycle/failure foundation |
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
| G1 lifecycle safety | #58 / PR #72 merged | Reset/replacement cannot revive stale observation |
| G2 runtime sizing | #59 / PR #76 merged | Capacity-sized reference preserves Stage-3A semantics |
| G3 indexed geometry | #60 / PR #78 merged | Registration/lookup have bounded deterministic structure |
| G4 producer completeness | #61-#63 | Every frozen producer route is witnessed or safely fenced |
| G4 graph incidence | #64 | Exact local graph and reverse invalidation exist |
| G5 exact backend | #65 | Generic split/delete works before fast paths |
| G6 publication policy | #67 | Residual global fold or composable digest cost is explicit |
| G7 consumer contract | #68 | Local/blocked/global observation meanings are distinct |
| G8 evidence | #70 | Exact-head campaign ready for parent Stage-3B decision |

None of these gates admits Stage 4.

### Issue #59/#60 completion and #61 handoff checkpoint

Issue #59 completed on PR #76 and merged to authoritative `main`
`5d89be4488e5fec3bf37e40ac87601fb14f2989b`. The landed Stage-3A-equivalent
backing conversion sizes journal `T`, edges `64T`, frontier/seen/members
`32T`, and key/index storage by effective capacity while retaining
`C=1024`, `K=32`, `B=128` and publication `P=4096`.

G2 is closed. #60 subsequently completed on PR #78 and is present in authoritative
main `e87ac54459a3a62350fa7aa3da6ce979c30a18b8`, closing G3. #61 is the current
central-World production package; it must start from live authoritative main and
must recheck overlapping current ownership rather than reviving a historical
implementation branch.

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
- The fixture catalogue has 168 versioned logical fixtures. Each carries a
  canonical declarative fixture-protocol hash binding exact geometry/generator
  parameters and operation schedule into every run/result provenance record.
  Historical `local-edit` remains an 8x8 patch and historical `bridge` remains
  a whole column; separate genuine one-cell tuple and topology fixtures carry an
  exact one-cell mutation contract.
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
- The #58 replacement-failure fixture uses retire-first lifecycle semantics: a
  failed replacement leaves discovery unavailable, does not mark the World failed,
  and a later successful clear creates a fresh observer incarnation.
- The #57 event-halo fixture binds the additive pending footprint
  `P = (R + 2) + maximum_rule_radius`; #63 retains implementation ownership for
  the sparse event/coverage producer.

#70 must freeze one authoritative simulation/material baseline, exact source/runtime
identity for every available arm, final capacities, compiler/artifact identity,
target host/OS/power mode and any interface-driven pre-results amendment before
executing the registered plan. Untouched historical Stage 3A remains a separately
identified reference series when it cannot share the matched authority.

## Immediate execution order

1. #56 authority/routing is complete.
2. #58 / PR #72 is complete and G1 is closed; #57 / PR #73 is complete and
   G-P4 is closed. #69 preregistration is complete; #70 remains gated on #68 and
   the frozen candidate/source-runtime identity.
3. #59 / PR #76 and #60 / PR #78 are complete; G2 and G3 are closed.
4. Run #61-#63 as the serialized World-producer lane while #64 may run as the
   parallel graph lane when its live write set remains disjoint. #63 remains
   blocked on both #62 and #57.
5. Join at #65.
6. Only then #66 -> #67 -> #68.
7. Freeze one coherent candidate and execute #70.
8. Return #70 to the supervising parent. Do not self-admit Stage 3B.

