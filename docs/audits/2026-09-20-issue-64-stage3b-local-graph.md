---
title: Issue 64 Stage-3B exact local graph and reverse-retirement evidence
status: Current
document-kind: audit
scope: Issue #64 settled-region graph internals, exact incidence, reverse subscribers and generation-safe retirement
canonical-for: [issue-64-stage3b-local-graph]
last-reviewed: 2026-09-20
related-documents: [../systems/settled-region-discovery.md, ../operations/soliding-stage3b-production-plan.md, issue-12-2026-09-19/stage3b-parent-decision.md]
---

# Issue #64 — exact local graph, face incidence and reverse retirement indexes

## Authority and dispatch

Issue #64 was dispatched from authoritative `main`
`86c1bcfd0f4d632816a9ecd89efe7668b343c5d0` after confirming #59/#60/#61 were
landed and no existing #64 branch or implementation PR existed. Concurrent #62
work was inspected before branching. Its write set is the World/coordinator
producer lane; #64 remains confined to settled-region graph internals plus focused
tests and documentation, so no #62 producer semantics were absorbed.

Native source freeze for this package:

- branch: `codex/issue-64-stage3b-local-graph`;
- source head: `3b195db519287e12a610ea112b4445b0398a509d`;
- source tree: `f40ea2bcfb3bc78cfb726f724a304abd5077047a`;
- PR: #98.

## Implemented graph contract

`SettledRegions` now keeps one bounded exact component capture for each accepted
complete tile revision and derives revision-bound face runs from that capture.
Components own generation-qualified incident-edge lists. Edge allocation uses a
bounded reusable free-list pool; edge traversal and retirement therefore follow
actual local component incidence instead of scanning configured/global adjacency
capacity.

The component record directly indexes both transient build ownership
(`build_generation`) and its current immutable publication generation
(`assigned_region`). Face runs bind boundary component identity to the exact tile
revision and provide a generation-bearing absence target.

Builds and publications own bounded typed dependency lists:

- `TileRevision` — exact resident revision required by the candidate;
- `AbsenceFaceRun` — exact sealed absent-facing run required by the candidate.

Each dependency is also linked from its target back to its subscriber. Tile
revision changes, ready nonmember changes and new-facing residency therefore walk
only the actual reverse subscriber fanout. Publications that do not subscribe to
the changed target remain current.

Logical retirement is immediate: the public region generation becomes invalid
before cleanup work is scheduled. Dependency/subscriber/edge handles carry
non-wrapping generations. Deferred reverse-list cleanup checks both subscriber
generation and target revision/absence generation before unlinking, preventing
slot-reuse ABA from affecting a replacement publication.

## Explicit bounds and refusal semantics

The existing frozen capacities remain:

- tracked tiles: runtime `T`;
- local cells: `C=1024`;
- local components: `K=32` in integrated production;
- boundary slots / maximum face-run descriptors per tile: `B=128`;
- adjacency pool: `64T` integrated;
- frontier/seen/member scratch: `32T` integrated;
- publication slots: `P=4096`.

Issue #64 adds a separately allocated dependency pool
`D=max(16T, frontier_capacity)` by default, which is `32T` in integrated
production, and `2P+2` generation-bearing subscriber headers. Tests may provide
a smaller explicit `D` to exercise refusal. Exhaustion is observable as
`DependencyCapacity`; no dependency, component or edge prefix is represented as
complete. Authoritative cells/World ownership are unchanged.

The current external World storage-layout report still exposes the pre-#64
dependency/revision summary fields owned by the concurrent coordinator lane. The
graph object itself reports its exact structural byte total and exact dependency
capacity. Expanding coordinator reporting is intentionally not used as a reason to
cross the #62 ownership boundary.

## Required acceptance coverage

Existing and added `native/tests/test_settled_regions.cpp` coverage proves:

- exact discovery tuple separation and canonical Empty holes;
- seams, four-neighbour-only connectivity and diagonal rejection;
- new-facing unknown residency immediately revokes the exact absence subscriber;
- a ready nonmember revision changing to a matching tuple retires the dependent
  publication and permits exact merged rediscovery;
- absent-to-resident transitions leave an unrelated far publication current;
- stale edge-slot generation cannot reconnect an old component after pool reuse;
- subscriber/publication slot reuse remains safe while old dependency cleanup is
  deliberately deferred;
- component, edge, frontier, region and explicit dependency capacity refusal;
- retired public handles become invalid immediately and generation exhaustion
  never makes an old handle current again;
- unrelated/far publications and in-flight remote work survive local churn.

The broader suite retains deterministic insertion/publication, split/merge,
unknown-boundary, noncanonical-Empty and integrated World regression coverage.

## Validation evidence

For native source head `3b195db519287e12a610ea112b4445b0398a509d`:

- Native C++ validation run
  `35517674664`: **passed** — GCC-13 compile; native behavioral/integration
  suite; `soliding-test`; characterization and Stage-3B apparatus smoke;
  retained Stage-3 cost smoke; ASan+UBSan; sanitized soliding regressions; TSan;
  shared-library and benchmark compilation.
- GDExtension/Godot run
  `35517674665`: **passed** — Linux x86_64 build, four isolated Godot
  regression shards and Linux gate; Windows x86_64 pinned cross-build.
- Source-matched Linux runtime artifact from that run has SHA-256
  `b13a9698f233bdae38fc1d00188be5a953e1e9bc3055cc9d4f5833c7d00c609d`.
  Its recorded tested PR merge commit is
  `2ad9e0563c339bf1fa0d63ce269d0f4b74c0debf`.
- The first documentation/provenance run `35517674584` failed only because
  changing `settled_regions.hpp` correctly invalidated the retained Linux and
  Windows runtime provenance. Documentation structure itself passed. The
  source-matched runtime publication below repairs that expected gate rather than
  suppressing it.
- One-shot source-matched runtime publication: `ISSUE64_PUBLICATION_RUN`.
- Final exact-head PR validation after provenance publication:
  `ISSUE64_FINAL_VALIDATION`.

## Deferred work and scope boundary

This package does not implement the #65 split/reconstruction/fair reclamation
scheduler, #66 topology-preserving/union fast paths, #67 composable digest work,
or #62/#63 World producer redesign. Global/canonical seed search and publication
slot selection that belong to those later packages are not disguised as #64
graph-local invalidation work.

#64 is complete only when the source-matched runtime/provenance publication has
landed on PR #98, final exact-head required checks pass, and the PR is merged.
