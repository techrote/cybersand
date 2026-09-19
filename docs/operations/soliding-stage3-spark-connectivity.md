---
title: Issue 12 Stage 3 Spark packet B - bounded cross-tile connectivity
status: Planned
document-kind: runbook
scope: Bounded GPT-5.3-Codex-Spark implementation package for local components and complete cross-tile region observations; no World producer or acceleration
canonical-for: []
last-reviewed: 2026-09-19
related-documents: [soliding-stage3-freeze.md, ../systems/settled-region-discovery.md, ../architecture/soliding-lifecycle.md]
---

# Spark packet B: bounded cross-tile connectivity

## Frozen objective

Implement a standalone bounded connectivity/region layer over immutable complete
discovery-tile revisions.

Do not edit World producer semantics and do not introduce material ownership,
stationary acceleration, cohesion, Rapier or persistence.

Read `AGENTS.md`, issue #12 and the Stage-3 freeze before editing.

## Ownership

Prefer new files such as:

- `native/include/cybersand/settled_regions.hpp`
- optional focused `native/src/settled_regions.cpp`
- `native/tests/test_settled_regions.cpp`

You may consume public immutable types from `settled_discovery.hpp`.
Avoid `native/src/world.cpp`, `world.hpp` and producer integration tests.

If a shared interface change is unavoidable, stop and ask the parent to allocate
ownership before editing a file packet A also owns.

## Frozen connectivity model

Implement:

1. bounded per-tile four-neighbor local component extraction;
2. exact revision-bound boundary ports/adjacency;
3. bounded resumable region traversal;
4. immutable complete region snapshots.

Component key in Stage 3 is exact:
`{material, state_a, state_b, temperature}`.

Rules:

- material zero with canonical empty state/ambient temperature is a hole;
- noncanonical Empty is blocking/special, not an ordinary hole;
- differing state/temperature does not merge;
- diagonal contact does not merge;
- face contact does;
- a narrow face neck may connect as discovery topology, but no cohesion is inferred;
- occupancy/incomplete tile signals produce no usable components.

Use fixed reusable scratch. Published component descriptor capacity is finite.
If a tile is too complex, mark connectivity unavailable/refused; never truncate.

A compact row-span/boundary-mask representation is preferred but not mandatory if
your alternative is equally bounded and preserves all properties.

## Boundary and invalidation

Cross-tile edges exist only for equal exact keys on facing shared-edge cells and
matching tile revisions.

Expose an invalidation API suitable for the parent integration layer.

When tile T changes:

- invalidate all region handles referenced by T's old components;
- invalidate region handles on each neighboring tile whose components face T,
  even if T and that neighbor did not previously connect.

This second rule is mandatory: T may create a new bridge, making the neighbor's old
"complete maximal region" stale.

Untracked/blocked/capacity-refused neighbor coverage is unknown. A region whose
possible continuation touches unknown coverage is incomplete and cannot publish.

## Region traversal and identity

Traversal starts from canonical lowest world-coordinate component seed with a
fixed exact-key tie break and fixed neighbor order.

Traversal is resumable and work-budgeted. No one-call world flood-fill.

A publication records at least:

- generation-bearing region handle;
- exact key;
- area;
- bbox;
- tile count;
- component count;
- complete dependency/revision witness or deterministic digest;
- member/topology digest for test comparison;
- classified/dirty latency metadata where supplied.

Publish only after all dependencies still match.

Region handle:
`{world_incarnation, region_slot, region_generation}`.

Stage 3 provides no continuity guarantee across topology mutation. Split/merge
rediscovery may allocate new generations.

Finite frontier/component/region capacity refuses the entire candidate. Never
publish a visited prefix.

Scarce region slots are assigned in canonical seed order, not callback/worker timing.

## Required adversarial fixtures in this package

At minimum:

- one solid spanning 2, 4 and many tiles;
- connection across chunk seam;
- negative-coordinate seam;
- ring/hole spanning multiple tiles;
- material seam;
- state_a/state_b seam;
- temperature seam;
- diagonal-only touch;
- one-cell face neck;
- T junction and bridge;
- edit removing bridge -> one region splits;
- edit adding bridge -> two regions merge;
- invalid tile between two otherwise matching sides;
- neighbor changes from nonmatching to matching key;
- blocked/body tile;
- noncanonical Empty boundary;
- local component-capacity refusal;
- frontier/region-slot capacity refusal;
- revision change during partial traversal;
- repeated churn of one tile while remote region still progresses;
- deterministic result under permuted input callback/order;
- no partial snapshot after any capacity/stale condition.

Use property/randomized testing where useful, but retain small named counterexamples.

## Metrics

Expose/report at least:

- tile component scans;
- local components/spans;
- boundary comparisons/edges;
- region builds started/completed/restarted/refused;
- frontier high-water;
- component/region capacity high-water;
- invalidated region count;
- neighbor invalidation fanout;
- region tile/area distributions;
- cells/components inspected per changed tile;
- maximum/total rebuild latency.

## Acceptance

The package is acceptable when:

- all named topology fixtures pass;
- holes/seams/exact-state boundaries are preserved;
- split and merge invalidate old complete regions immediately;
- traversal is resumable and bounded;
- untracked/capacity coverage cannot yield a complete region;
- deterministic digests are stable under equivalent input ordering;
- no World/material/Rapier semantics are introduced.

## Escalate instead of improvising

Stop if you need a global unbounded flood-fill, persistent union-find that cannot
handle splits correctly, a material-cohesion decision, World worker ownership,
or a shared interface edit owned by another active packet.

Return exact changed files, tests, metrics, capacity assumptions and unresolved
parent decisions.
