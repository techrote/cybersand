---
title: Issue 61 Stage 3B sparse mutation and worker witness audit
status: Review-ready implementation
document-kind: audit
scope: Change-driven material/payload mutation witnesses and deterministic native worker reduction
canonical-for: []
last-reviewed: 2026-09-20
related-documents: [issue-12-2026-09-19/stage3b-parent-decision.md, ../operations/soliding-stage3b-production-plan.md, ../systems/settled-region-discovery.md, 2026-09-19-issue-60-stage3b-bounded-spatial-index.md]
---

# Issue 61 Stage 3B sparse mutation and worker witness core

## Dispatch and authority

Issue #61 was dispatched from authoritative post-#60 `main`
`e87ac54459a3a62350fa7aa3da6ce979c30a18b8`. PR #78 / issue #60 was
confirmed landed at that exact head and no existing #61 implementation
branch, pull request, or owner was present.

Authority is the #61 issue body plus its referenced Stage-3B parent decision,
production plan, settled-region system contract, #58 lifecycle work, #60
bounded spatial indexing and #29 / INT-000 interaction authority.

This slice does not implement #62 activity/deadline indexing, #63
mask/event/inclusion/coverage indexing, #64 graph/reverse-incidence work, or
later Stage-3B/Stage-4 packages.

## Producer audit

The authoritative payload write routes in `World` were traced before
modification:

- direct material/state mutation converges on `write_cell` or the direct
  setters and the common discovery payload hook;
- temperature mutation has its own direct setter hook;
- stored-cell movement mutates source and destination in `move_cell`;
- fractional Water movement mutates source and destination in
  `transfer_water`;
- native rule kernels route payload writes through `write_cell`,
  `move_cell`, or `transfer_water`;
- phased workers never own shared discovery state: they mutate authoritative
  World storage within the prepared write domain and return `JobEffects` for
  serialized owner reduction.

The pre-#61 worker path collapsed all writes in a touched chunk into a bounding
rectangle and then rediscovered canonical discovery tiles from that rectangle.
The pre-#61 direct hook also performed immediate signal recomputation after
payload invalidation. The resident-wide activity/deadline refresh at tick
finish remains separate and is intentionally retained for #62.

## Implemented witness architecture

### Immediate payload witness

A payload mutation immediately advances the independent, nonwrapping discovery
revision for its canonical tile. Repeated writes may be represented by one
owner-side operation carrying an exact `mutation_count`; the revision advances
by that count, so ABA/change-and-restore history cannot disappear merely because
deferred service is coalesced.

Direct mutation resolves the canonical #60 owner handle and calls
`notify_payload`. It does not enumerate resident discovery tiles and does not
synchronously scan unrelated signal metadata.

### Bounded deferred service

The coordinator owns a construction-time payload queue with exactly `T`
entries, where `T` is the configured discovery tile capacity. Every record has
one pending bit plus latest payload revision/reason. Repeated mutations to the
same tile update that witness and retain one queue entry.

Deferred payload service refreshes signals for that tile before ordinary journal
scan work may proceed. Each serviced tile is charged as explicit work. The queue
does not resize, allocate on the hot path, or use an overflow list.

### Native worker reports

Each `JobEffects` has a fixed array of canonical discovery mutation reports.
Workers only update this job-local array; they never call the shared discovery
coordinator. Reports are deduplicated by chunk/activity/subtile identity and
carry an exact mutation count.

After the worker barrier, the owner consumes reports in the already
deterministic phase/core reduction order, resolves #60 owner handles and applies
`WorkerMutation` payload witnesses. Movement and Water record both source and
destination endpoints.

The former coarse worker `dirty_discovery_rect` path has been removed rather
than retained as a fallback.

### Lost-report fence

If a job cannot represent every unique payload report, authoritative simulation
has already performed the writes and must not be rolled back or failed merely
because the observer lost detail. The owner therefore records report overflow
and fail-closes discovery with the existing producer-failure boundary. No stale
tile remains consumer-visible; the World itself remains authoritative and
healthy.

## Scope preservation

- #58 retire-before-replace lifecycle and failed-World quarantine are unchanged.
- #60 canonical bounded key/handle lookup remains the addressing substrate.
- #29 / INT-000 material, Water, granular, kinetic and interaction semantics are
  unchanged; #61 observes their writes only.
- The global activity/deadline refresh remains for #62.
- Mask/event/inclusion producer sparsification remains for #63. Payload service
  may refresh the affected tile's current signals but does not introduce a new
  mask/event/inclusion index.
- Region reverse dependency and split/merge graph work remains for #64.
- No scheduler skip, cohesion inference, Rapier handoff or Stage-4 consumer
  behavior is introduced.

## Adversarial validation obligations

The #61 focused suite covers:

- state and temperature ABA with exact tuple/heat restoration;
- render-dirty consumption independence;
- locality against a far registered tile;
- source and destination movement witnesses;
- Water source/destination mass witnesses;
- same-barrier coalesced worker restore with exact revision increments;
- workers 1/4 authoritative and witness parity;
- native report saturation and observation-only fencing;
- discovery-disabled authoritative neutrality in the saturation fixture;
- runtime storage accounting for the fixed `T` payload queue;
- deferred signal-source exception quarantine preserving #58 `SourceFailure`
  semantics.

## Focused and source-matched runtime validation

Focused Actions run `35476335629` passed after the saturation fixture was
isolated from an unrelated test-only active-core cap. It covered the #61
adversarial suite, runtime-sized storage regression, existing settled-World
discovery regression, structural removal of the coarse worker rectangle path,
and ASan/UBSan.

Final native source was then frozen at
`e75c5fd52a14a01185795b78651f82960d97f9c6`. One source-matched publication,
Actions run `35476457792`, reran the exact-source focused suite and sanitizer
before any runtime build, then passed:

- Linux x86_64 GDExtension build and ABI/runtime-floor validation;
- Windows x86_64 pinned LLVM-MinGW cross-build;
- exact binary/source-input provenance regeneration and verification;
- LFS publication from the same source identity.

The resulting publication head is
`208de4ffb68595bd6733e857bf11c91b85be84ed`. Windows execution is unavailable
and is not claimed; the final PR head still requires the normal exact-head
Documentation, Native, and GDExtension/Godot gates.

## Locality claim

For ordinary payload mutation, work is proportional to the mutation reports plus
height-bounded canonical owner lookup and affected-tile service. Neither direct
nor worker payload invalidation calls a discovery-wide resident loop.

This is deliberately narrower than claiming that the whole producer is sparse:
the resident-wide activity/deadline path still exists until #62, and #63/#64
retain their declared work.
