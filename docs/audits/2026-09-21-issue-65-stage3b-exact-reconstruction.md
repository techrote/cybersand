---
title: Issue 65 Stage-3B exact reconstruction, reclamation and fairness evidence
status: Review-ready implementation
document-kind: audit
scope: Issue #65 generic exact split/deletion backend
canonical-for: [issue-65-stage3b-exact-reconstruction]
last-reviewed: 2026-09-21
related-documents: [../operations/soliding-stage3b-production-plan.md, ../systems/settled-region-discovery.md, issue-12-2026-09-19/stage3b-parent-decision.md]
---

# Issue #65 — resumable exact reconstruction, reclamation and deterministic fairness

## Authority and source freeze

Issue #65 is the Stage-3B join between the landed sparse producer lane (#63) and
the landed exact graph/reverse-incidence lane (#64). Parent #12, the Stage-3B
production plan, #69 preregistration, and landed #58-#64 contracts remain
authoritative. #66+ fast paths, Stage 4, INT-000 semantic changes and Water/hybrid
work remain outside this package.

The implementation branch is
`codex/issue-65-stage3b-exact-reconstruction` / PR #106. It is reconciled with
authoritative `main` `20337053911d28f985a3211b5cd7c8f70fd4d9b5`.
The frozen native/test source is `8dfa779a561374a5693556f50def3e9666783a98`.
Later documentation/provenance commits do not change that native source.

## Exact reconstruction contract

Topology-changing retirement retains a bounded source manifest rather than falling
back to ordinary independent rediscovery. Reconstruction uses the current #64 exact
component graph and typed dependencies, with generation-qualified retained tickets,
bounded seed/frontier nodes, staged members/children, and exact source identity.

A ticket advances through admission, child traversal, dependency validation,
publication preflight, hidden preparation and atomic commit. Replacement children
remain externally invisible while their preparation ticket is live; a completed
ticket releases visibility for the complete batch together. No prefix child is
published when a later child or publication resource cannot be represented.

Fresh source attachment initializes the admission cursor explicitly. Unknown source
coverage uses a ticket-owned staged subscriber on the exact waited tile, so the
existing #64 reverse dependency index wakes the retained ticket when the observation
generation/revision becomes usable. Blocked work is not polled.

## Primitive-bounded service and fairness

Reconstruction tickets are retained and serviced in deterministic round-robin order.
A large child does not own the scheduler until traversal completion.

Variable-size reconstruction work is explicitly resumable:

- retained seed admission probes one seed per service primitive;
- canonical frontier-min selection scans one frontier candidate per primitive;
- component traversal, staged-member folding, dependency validation, sorting/folding
  and publication preparation are resumable;
- shared digest scratch is represented as a generation-bearing bounded resource.
  Contending tickets park without discarding partial work and resume Building when the
  current scratch owner releases it;
- cleanup/reclamation has its separate bounded service opportunity.

The service loop also guarantees that a phase which resets itself without consuming a
primitive cannot strand already-actionable cleanup. This closes the case where an
exhausted ordinary seek returned zero while subscriber/source/region reclamation was
still live.

## Capacity, refusal and retry

Capacity outcomes distinguish structural impossibility from temporary contention.

- intrinsic frontier/dependency/member/region limits produce stable typed refusal;
- transient bounded-resource contention parks a ticket and retries only after the
  corresponding resource generation advances;
- an impossible all-child result never publishes the subset that happens to fit;
- terminal reconstruction `GenerationExhausted` remains observable across later
  accepted observations and cannot be silently cleared while the exhausted identity
  remains terminal;
- manifest/source allocation failure fails observation closed rather than losing the
  only reconstruction source;
- integrated dependency storage reporting now reflects the actual default exact
  dependency pool (`32T` in the production configuration), not the old `T`
  summary.

## Reclamation and ABA safety

Retired publication membership, subscribers, staged children, frontier seeds and
source manifests all have bounded ownership and incremental cleanup.

Publication slots are reusable only after member/subscriber references are gone.
Generation-qualified handles prevent stale publication, subscriber, dependency,
edge, ticket, seed and staged-object references from aliasing reused storage.

A focused ABA forensic pass found that the cleanup objects themselves were valid:
one inactive cleanup-pending subscriber with a live dependency, two region-reclaim
entries, and a live source cleanup chain. The liveness defect was scheduler-side:
an exhausted ordinary seek could become Idle and return zero before servicing those
queues. The service fallback now gives cleanup its bounded progress opportunity before
`advance()` may report zero.

## Focused adversarial coverage

`native/tests/test_settled_regions.cpp` retains or adds coverage for:

- genuine split and many-child atomic split;
- alternate-path deletion without false split;
- unvisited/current member mutation and frontier-phase mutation;
- mutation after traversal and during hidden publication preparation;
- unknown continuation, no-hot-spin wait and exact reverse-index wake;
- intrinsic frontier, dependency and region-capacity refusal without prefix
  publication;
- transient region-capacity wait, unchanged-generation suppression and retry after
  the relevant generation advances;
- large local reconstruction yielding to unrelated remote admitted work;
- later low-key arrivals not starving an older retained ticket;
- deterministic ticket/publication semantics under service budgets 1 and 7;
- bounded reclamation pressure and eventual drain;
- publication/subscriber slot reuse with stale-handle/reverse-link rejection;
- locality evidence that ticket reconstruction does not invoke the ordinary global
  component seeker;
- generation/publication exhaustion without stale-handle resurrection.

The existing #61-#64 and integrated World suites remain regression authority for
producer semantics, exact graph invalidation, observer-disabled neutrality, workers
1/4 behavior and failure/quarantine contracts.

## Validation checkpoint

The temporary test-only forensic access and focused workflow were removed before
source freeze.

GitHub-hosted focused `make soliding-test` run **35654164638** passed on clean
native/test source `8dfa779a561374a5693556f50def3e9666783a98`.

Final completion still requires, in order:

1. one full GitHub-hosted exact-head Native/GDExtension/Water validation pass from
   the frozen native source;
2. one source-matched Linux + Windows runtime/provenance publication using
   GitHub-hosted runners only;
3. final exact-head Documentation/provenance, Native and GDExtension/Godot gates;
4. merge/landed-SHA verification and #65 closure only if the substantive criteria
   remain satisfied.

#66 is the next serialized Stage-3B package after genuine #65 completion. It is not
started by this work.
