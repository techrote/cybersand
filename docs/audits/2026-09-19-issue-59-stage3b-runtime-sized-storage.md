---
title: Issue 59 Stage 3B runtime-sized Stage-3A storage audit
status: Current
document-kind: audit
scope: Mechanical conversion of Stage-3A observer backing storage to runtime-sized semantic-equivalent capacities for Stage 3B issue 59
canonical-for: []
last-reviewed: 2026-09-19
related-documents: [issue-12-2026-09-19/stage3b-parent-decision.md, ../operations/soliding-stage3b-production-plan.md, ../operations/soliding-stage3-freeze.md, 2026-09-19-issue-58-stage3b-lifecycle.md, 2026-09-19-issue-69-stage3b-validation.md]
---

# Issue 59 Stage 3B runtime-sized Stage-3A storage audit

Implementation branch:
`codex/issue-59-stage3b-runtime-sized-storage`.

Authoritative starting `main`:
`3d5504836578eb9d47e11b677767bfbe8039fccb`, the merge of PR #74 /
issue #69 after #58, PR #75 and #57. No pre-existing #59 implementation branch
or PR was present when implementation began.

This issue changes backing representation only. Stage-3A observable semantics,
#58 lifecycle/reset/failure authority, #57's frozen event footprint and #69's
candidate-independent validation apparatus remain authoritative. It does not
implement #60 or any later Stage-3B package and does not execute #70.

## Source audit and capacity mapping

The pre-#59 production coordinator used a runtime logical tile limit but retained
compile-maximum backing in the journal and integrated region implementation.

The bounded conversion is:

| Storage surface | Before | #59 runtime backing |
|---|---:|---:|
| Discovery journal records | `kMaximumWorldDiscoveryTiles = 16384` | `T` |
| Discovery journal queue | `kMaximumWorldDiscoveryTiles = 16384` | `T` |
| Coordinator owner records | runtime `reserve(T)` | unchanged runtime `reserve(T)` |
| Coordinator canonical key index | runtime power-of-two table | runtime power-of-two table derived from `T` |
| Integrated region tiles | `4096` | `T` |
| Region adjacency/edge storage | `4096 * 64` | `64T` |
| Build frontier | `4096 * 32` | `32T` |
| Build seen set | `4096 * 32` | `32T` |
| Build ordered member storage | `4096 * 32` | `32T` |
| Build dependency flags | `4096` | `T` |
| Build dependency revisions | `4096` | `T` |
| Publication member-tile scratch | `4096` stack entries | construction-time `T` backing |
| Publication dependency-sort scratch | `4096` stack entries | construction-time `T` backing |
| Published-region slots | `4096` | **unchanged `P = 4096`** |

Per-tile capacities are intentionally unchanged:

- maximum tile cells `C = 1024`;
- components per tile `K = 32`;
- boundary-neighbour slots `B = 128`;
- the coordinator's `region_scratch` remains `C = 1024`.

No lookup algorithm is replaced. The existing open-addressed coordinator key
index remains the Stage-3A mechanism; #60 still owns the canonical bounded spatial
index.

Derived `64T`, `32T` and key-index arithmetic is checked before allocation.
Invalid/overflowing configuration is rejected deterministically rather than
wrapping or silently clamping.

## Ownership and allocation model

`SettledDiscovery` retains its compile-time template capacity as the supported
maximum/test-contract bound, but construction now selects the effective slot
capacity and allocates journal record/queue backing once at setup.

`SettledRegions` similarly retains compile-time maxima and fixed semantic
constants while construction selects runtime tile, edge and build capacities.
The dynamic arrays are owned for the lifetime of the observer; observer service
does not introduce per-operation heap allocation.

Published-region slots remain an inline fixed-capacity array of 4096. This is the
deliberate #59 semantic-equivalence checkpoint, not an omission.

## Deterministic storage/layout accounting

`SettledWorldDiscoveryCoordinator::storage_layout()` reports structural
capacity/accounting without relying on process RSS. It distinguishes:

- effective tile capacity;
- journal slots and structural bytes;
- coordinator owner-record and key-index capacity/bytes;
- region tile, edge, frontier, seen, member, dependency and revision capacities;
- frozen `C`, `K`, `B` and publication `P`;
- region structural bytes.

`storage_bytes()` and `region_storage_bytes()` now include the dynamically
owned structural arrays. These values are structural element accounting; allocator
metadata/reserved arenas are deliberately not labelled as live bytes or RSS.

The focused matrix checks `T = 64 / 256 / 1024 / 4096`, exact formulas
`T / 64T / 32T`, fixed `1024 / 32 / 128 / 4096`, and strict growth of journal
and region structural bytes as `T` increases. Thus a small configuration no
longer reports or owns the old compile-maximum journal/region backing.

## Stage-3A semantic-equivalence strategy

`native/tests/test_stage3b_runtime_storage.cpp` supplies a narrow test-only
reference adapter over the existing canonical Stage-3A semantics rather than
retaining a second production observer.

For each required `T`:

- a capacity-specialized reference journal is compared with the maximum-supported
  journal constructed at runtime `T`;
- registration through exact `T`, one-past refusal, bounded drain and every
  normalized `DiscoverySummary` are compared;
- a capacity-specialized region contract is compared with the maximum-supported
  region implementation constructed at runtime `T / 64T / 32T`;
- normalized region publication, refusal state and completion are compared;
- the production coordinator is filled through exact `T` and must refuse
  `T+1` with the existing producer-failure/capacity quarantine behavior.

The pre-existing settled-region suite remains the independent exact/one-past
coverage for adjacency and frontier capacity and proves that a bounded capacity
never publishes a truncated prefix. Member/seen capacity shares the same bounded
build cardinality; dependency/revision cardinality is bounded by accepted tiles.
The existing region-capacity tests retain publication-slot refusal semantics while
the production publication capacity remains fixed at 4096.

## Allocation failure and lifecycle continuity

Issue #58's one-shot
`testing::fail_next_settled_world_discovery_construction()` seam is reused at
each required `T`. The #59 matrix verifies that a failed coordinator construction
exposes no partially initialized object and that a subsequent construction starts
empty, serviceable and unhalted with the requested capacity.

The existing #58 World regression remains mandatory and separately proves the
authority boundary: old discovery is retired before destructive reset, failed
replacement leaves discovery unavailable without marking the World failed, later
successful reset gets a fresh incarnation, and stale handles stay stale.

## Runtime/provenance consequence

The repository manifests explicitly track all three #59 production inputs:

- `native/include/cybersand/settled_discovery.hpp`;
- `native/include/cybersand/settled_regions.hpp`;
- `native/include/cybersand/settled_world_discovery.hpp`;
- `native/src/settled_world_discovery.cpp` is also a tracked/compiled input.

The pinned Linux and Windows GDExtension build scripts compile the changed
settled-world-discovery source. Therefore the existing #58 runtimes cannot be
relabelled as #59 runtimes. After source/focused validation is frozen, Linux and
Windows x86_64 runtimes and both provenance manifests must be rebuilt/published
from one exact #59 source head using the repository's pinned toolchains.

Historical Stage-3A and #58 measurements remain attached to their original
source/artifact identities.

## Scope review

No #60 spatial-index implementation, #61 sparse mutation producer, #62
activity/deadline index, #63 event/coverage producer, #64 graph/reverse index,
#65 reconstruction/fairness backend, later fast path/publication/API work,
material behavior, Water behavior or Stage-4 work is included.

PR #75's worker-parity routing is inherited from `main`; #59 does not alter the
parity test or shard placement. #69's 6,488-record final campaign is not executed.

## Validation record

Focused source validation workflow:
Actions run `35470123883` at source checkpoint
`16b9f0cfc0b0e3f1d8e6bea24179fdc8d897db07`.

The runtime-sized storage/parity matrix passed before broader validation. The
same focused run also executes the pre-existing settled-region boundary suite and
#58 World lifecycle/reset/recovery suite.

Final source-matched runtime identities, exact final PR head, normal repository
workflow run IDs and merge result are recorded here only after they exist; G2 is
not treated as closed before that evidence is complete.
