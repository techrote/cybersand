---
title: Issue 62 Stage 3B sparse activity and deadline audit
status: Review-ready implementation
document-kind: audit
scope: Change-driven no-write activity witnesses, bounded deadline indexing, exclusion parking and re-entry
canonical-for: []
last-reviewed: 2026-09-20
related-documents: [issue-12-2026-09-19/stage3b-parent-decision.md, ../operations/soliding-stage3b-production-plan.md, ../systems/settled-region-discovery.md, 2026-09-20-issue-61-stage3b-sparse-mutation-witness.md, 2026-09-20-issue-64-stage3b-local-graph.md]
---

# Issue 62 Stage 3B sparse activity and deadline state

## Authority and reconciliation

Issue #62 is the serialized central-World producer package after #61. Its authority is
the issue body, parent #12, #29 / INT-000, the Stage-3B production plan and the
referenced settled-discovery/lifecycle contracts.

Implementation started from authoritative main
`86c1bcfd0f4d632816a9ecd89efe7668b343c5d0`. Concurrent #64 / PR #98 was
kept in the disjoint settled-region graph lane. After #64 merged as
`bb6f12a7845f7249d68693a277c934e5fef5561d`, PR #97 was reconciled by a
normal two-parent merge at
`9b514125c6057639ad19a5a3f1119911e14134cb`. The #64 merge changed no #62
source/test path; its runtime/provenance publication is retained as the base for
the final #62 source-matched rebuild.

This slice does not implement #63 mask/event/inclusion/coverage indexing, alter
#64 graph semantics, admit Stage 4, change INT-000 material behavior, or absorb
Water/hybrid/remediation work.

## Implemented sparse state

### Parent-local activity witnesses

Each represented discovery parent has bounded coordinator state. No-write
`keep_cell_active` and ordinary sleep/wake transitions emit parent-local activity
witnesses. Native workers carry fixed-capacity job-local signal reports and the
serialized owner reduces them after the existing barrier; workers do not mutate
shared discovery state.

When a #61 payload refresh is already queued, an activity/deadline signal can
coalesce into that queued record without advancing the independent payload
revision. Coalescing is deliberately restricted to the activity/deadline
producer so mask/event/inclusion ABA remains #63-owned.

Activity refresh starts from the previous signal tuple and changes only
`active`. It does not recompute inclusion, pending-event, occupancy, health or
witness-complete state. Coverage transitions retain their explicit
`InclusionFence` path.

### Bounded canonical deadline index

The coordinator owns fixed-capacity parent storage, a bounded parent index and a
deadline heap bounded by the represented tile capacity. Each parent has at most
one current deadline entry. Ordering is canonical by:

1. due tick;
2. world incarnation;
3. parent chunk Y/X;
4. parent activity Y/X.

Insertion, earlier replacement, cancellation, ready marking and consumption
update/remove the current entry in place. Later deadlines do not replace an
earlier authoritative obligation. There is no lazy stale-entry or tombstone
queue.

Deadline generations are nonwrapping. Generation exhaustion fail-closes
observation before an old obligation can become ambiguous or current again.

### Exclusion and re-entry

An overdue deadline whose parent is excluded is removed from the runnable heap
and parked explicitly on that parent. Exclusion does not advance material
simulation or silently consume the obligation. Re-entry reconciles the parked
state and makes an already-due obligation runnable immediately.

Observer-disabled execution remains authoritative-control neutral: discovery
index maintenance cannot change material results.

## Ordinary maintenance locality

The pre-#62 ordinary finish-tick resident-wide discovery signal refresh is
removed. Quiet observer maintenance therefore does not enumerate every
represented discovery tile merely to rediscover unchanged activity/deadline
state.

Authoritative simulation still iterates its own activity blocks for normal
scheduler/sleep accounting and checks its own interaction deadlines. #62 changes
the observer witness/indexing mechanism; it does not replace the simulation
scheduler or reinterpret deadline semantics.

Explicit global producer fences and coverage transitions remain permitted. They
are not used as a disguised ordinary activity/deadline polling path.

## Preservation boundaries

- #58 retire-before-replace and failed-World quarantine remain intact.
- #60 bounded owner/key lookup remains the addressing substrate.
- #61 payload revisions, exact direct/worker mutation witnesses and lost-report
  fencing remain intact. The focused #61 locality regression now expects its
  exact payload witness count plus the one parent-local #62 activity transition
  caused by the same direct mutation.
- #64 exact local graph incidence, reverse dependencies and generation-safe
  retirement are inherited from current main and remain outside the World
  producer implementation.
- #63 retains masks, events, inclusion epochs and general coverage witnesses.
- No material, Water, granular, kinetic, collision or interaction semantics are
  changed.

## Adversarial coverage

The focused #62 suite and storage regressions cover:

- future deadline remains blocking before due;
- earlier replacement and ignored later replacement;
- cancellation, re-schedule, ready marking and consumption;
- equal-due canonical parent ordering;
- exact bounded-capacity obligation fill/drain with no stale entries;
- overdue exclusion parking and already-due re-entry;
- no-write keep-active and ordinary sleep/wake;
- pending #61 payload plus no-write activity coalescing without double revision;
- deadline generation exhaustion and fail-closed observation;
- no obsolete obligation resurrection / ABA ambiguity;
- quiet represented worlds with unchanged signal/revision counters over repeated
  ticks;
- inclusion restoration on re-entry without moving #63 ownership into the
  activity path;
- workers 1/4 authoritative and sparse-state parity;
- observer-enabled versus observer-disabled authoritative neutrality;
- runtime storage accounting for bounded parent/index/deadline state.

The existing #61 sparse mutation suite and #64 settled-region graph suite remain
part of the broader soliding validation surface.

## Validation and publication rule

Pre-reconciliation PR head
`9a846f79e5105edfd3dbd095cc644e954b66074d` passed the Native C++ and
GDExtension/Godot workflows. Its documentation/provenance workflow failed only
because #62 changed native source while the committed runtimes still described
the previous source.

After #64 merged, the source was reconciled at
`9b514125c6057639ad19a5a3f1119911e14134cb` before publication. Final
acceptance requires one source-matched Linux/Windows runtime publication from the
reconciled #62 source, followed by the normal exact-head Documentation/provenance,
Native C++ and GDExtension/Godot gates.

The publication run identity and final exact-head workflow evidence are retained
on PR #97 and in the runtime provenance manifests rather than requiring a
post-validation documentation-only commit.

## Acceptance claim

#62 is complete only when the source-matched runtime/provenance publication is on
PR #97, the final exact PR head passes required automated checks, the final diff
still respects the #63/#64 boundaries above, and the PR is merged. On an
authoritative main containing that merge, the #62 prerequisite for #63 is
satisfied.
