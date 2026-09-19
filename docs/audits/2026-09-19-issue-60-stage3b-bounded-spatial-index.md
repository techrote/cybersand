---
title: Issue 60 Stage 3B bounded spatial indexing audit
status: Review-ready implementation
document-kind: audit
scope: Canonical bounded discovery-tile lookup and generic rectangle compatibility for Stage 3B issue 60
canonical-for: []
last-reviewed: 2026-09-19
related-documents: [issue-12-2026-09-19/stage3b-parent-decision.md, ../operations/soliding-stage3b-production-plan.md, 2026-09-19-issue-59-stage3b-runtime-sized-storage.md]
---

# Issue 60 Stage 3B bounded spatial indexing

## Dispatch boundary

Issue #60 starts from corrected authoritative `main`
`3e4cb8b0106faa3da2f8fb7df4ccd4af577eb21a`, after #59 / PR #76 and the
post-#59 authority-hygiene merge.

The package is restricted to bounded deterministic registration/lookup and
geometry compatibility. Sparse producer work (#61-#63), reverse region
dependency/retirement indexing (#64), later reconstruction/publication/API work
(#65-#68), and final campaign execution (#70) remain outside this change.

## Pre-edit source audit

At dispatch:

- `SettledWorldDiscoveryCoordinator::Impl` still uses the Stage-3A
  open-addressed canonical-key table retained deliberately by #59;
- `SettledRegions::find_tile` is a resident-tile linear scan;
- new region-tile registration proves non-overlap by scanning all resident
  rectangles;
- `SettledRegions::link_faces` scans all resident tiles to discover facing
  neighbours;
- adjacency rebuild and several face-related invalidation/deferred-work paths
  rediscover facing tiles by resident scans;
- the World producer commonly performs a key lookup and then immediately calls
  tile/dirty/observe again by key, so an incarnation-qualified direct owner
  handle can remove redundant lookup without changing producer semantics.

## Approved design constraints

The implementation will preserve stable append-only tile/record slots and add:

1. a runtime-capacity, array-backed height-bounded ordered index over canonical
   discovery-tile keys;
2. canonical in-order traversal independent of insertion order, allocation
   order, or tree rotations;
3. incarnation-qualified direct owner handles for callers that have already
   resolved a canonical key;
4. checked signed-coordinate face derivation and per-boundary-cell mapping;
5. a bounded row-interval ordered compatibility index for arbitrary
   non-overlapping rectangles, with at most 32 row entries per accepted tile.

Hashing may remain only as an optional measured control; it is not the sole
worst-case guarantee.

## Validation obligations

Focused validation must cover negative coordinates, signed endpoint overflow,
partial/custom rectangles, forward/reverse insertion, exact capacity refusal,
generic overlap/containment, deterministic canonical traversal, direct-handle
staleness/incarnation checks, and the absence of unrelated resident-tile scans
on canonical registration/facing lookup.

Final exact-head repository validation and source-matched runtime/provenance
publication are required if the landed implementation changes tracked runtime
inputs.


## Implementation checkpoint

The implementation retains append-only stable owner/tile slots and replaces the
normal-path key structures with construction-time array-backed AVL indexes:

- coordinator canonical-key index: exactly `T` nodes;
- region canonical-key index: exactly `T` nodes;
- generic row-interval compatibility index: at most `32T` nodes, one interval
  per occupied tile row;
- no tree-node allocation, resizing or rehashing occurs after construction.

The canonical comparator is lexicographic over incarnation, chunk, activity and
subtile coordinates. AVL rotations only relink stable pool indices; in-order
traversal is therefore canonical and independent of insertion/rotation history.

World paths that have resolved an owner use an incarnation-qualified
`WorldDiscoveryTileHandle`. This removes repeated key lookup without changing
the still-global producer scans owned by #61-#63.

Generic rectangles remain supported. Registration proves non-overlap by bounded
row-interval predecessor/lower-bound queries. Point containment uses the same
index. Facing geometry is derived with checked signed endpoint arithmetic and
mapped into the existing 128 boundary slots without scanning unrelated resident
tiles. Adjacency rebuild, facing publication retirement and deferred-face
clearing consume that bounded face map. The remaining full dependency-bitmap
walk in `build_related` is intentionally retained for #64, which owns reverse
dependency incidence.

Existing `RegionRefusal` numeric values remain stable; the new fail-closed
`SpatialIndexCapacity` refusal is appended after the prior enum values.

## Focused validation

Temporary focused Actions run
`35472375089` passed on the implementation source before workflow removal:

- Stage-3B bounded spatial-index adversarial tests;
- the #59 runtime-sizing contract;
- existing settled-region regressions;
- existing World settled-discovery regressions.

The new adversarial suite covers forward/reverse AVL insertion and canonical
traversal, height bounds, exact capacity refusal, direct-handle incarnation/slot
failure, negative/custom/partial rectangles, overlap and containment, partial
face runs, insertion-order-independent normalized region output, and
`INT64_MIN`/`INT64_MAX` endpoint handling.

The normal documentation gate correctly reports the native Linux and Windows
runtime provenance stale after the changed tracked source inputs. A single
source-matched publication is therefore required after final source review.
