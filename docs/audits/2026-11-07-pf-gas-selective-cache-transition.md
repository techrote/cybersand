---
title: PressureFlow selective gas-cache bootstrap protected-source transition
status: Proposed
document-kind: audit
scope: PR #532 native/src/world_pressure.inc reviewed transition only; no material identity or runtime publication
last-reviewed: 2026-11-07
related-documents: [../architecture/pressure-optimization.md, ../architecture/pressure-flow-v1.md, 2026-11-07-pf-c2048-mat-auth-transition.md]
---

# PressureFlow selective gas-cache bootstrap — MAT-AUTH transition

PR #532 changes one MAT-AUTH protected consumer while preserving the material catalogue, liquid policy identities and physical/save authority.

## Exact protected-source transition

- Path: `native/src/world_pressure.inc`
- Previously admitted LF SHA-256: `71723fa32bbd29aafe93f1a8dd233cece1eec7ed295da81c1e021f635085c17a`
- First investigative LF SHA-256: `f575825e96e61caad200974a1f39396d4d09921e548719643145c5d2915abb2b`
- First investigative source commit: `f0fffc6a488f585ff10966427e87cfc3d23ed04b`
- Sparse-relabel LF SHA-256: `af72f8e71c0f6b155e2e78f188f956f06af383217df6ccc23d28087ea1c63abf`
- Sparse-relabel source commit: `d281bb41700197539f313190f7b4d68844686cf1`
- Prior-visit proof LF SHA-256: `33445b83c3759c495680256e5ac781abdee26d257e516b7edb9d601a57460bd0`
- Prior-visit proof source commit: `d73c4ee016cdbd92f2d7e95d588891350f32d8c3`
- Final head-budget separation LF SHA-256: `ee0b330e76fc3c5de100d30af6942598232c0b3665f8af1067b81a07b2b70dd8`
- Final head-budget separation source commit: `95de28826b948a902faf2361fb00bc14ab2d69ad`
- Parent issue: #201
- Implementation PR: #532

The first transition implemented the bounded selective-component bootstrap experiment. Exact workbench-derived replay then proved that the mechanism could not admit a single component: 1,659 component proof checks and one 2,097,152-cell build scan produced zero members/builds/reuses, while all source-paired physical ticks remained exact. That path is retained in history as an explicitly reviewed investigation but is not the final production mechanism.

The second transition replaces that NO-GO with a lower-cost authoritative relabel path. The gas BFS and identity reducer remain unchanged. For cached variants with a complete resident index, a bounded bitset records cells actually visited by the authoritative BFS. Relabelling still performs the original complete scan for every gas-dirty chunk and every chunk known to contain an occluded positive label; only clean/no-hidden-label chunks may relabel from the exact visited-cell bitset. Dirty-proof overflow, cache membership uncertainty, gas-cache replay, allocation, or any bit/index inconsistency falls back to the original complete relabel sweep. The final transition additionally retains the previous authoritative visit bitset: sparse relabelling processes the union of current and prior visits so a remote vent/split cannot strand a formerly visited positive label in a clean chunk. If prior-visit history is unavailable, the first pass is a complete sweep and re-establishes it.

The final transition separates an unrelated head-repair budget fallback from full cache invalidation. The full workbench runs the head operator in `ReferenceBudgetFallback`; previously that path called `cache->cold()`, falsely discarding complete resident-index and gas visit evidence every tick. It now invalidates only head/certificate/wake reuse. Actual membership, restore, policy or authority changes retain the full cold path.

## Authority boundary

This transition does **not** change material IDs, catalogue bytes, pressure law, gas quantity law, compartment identity/lineage rules, CYPS semantics, C1024/C2048 capacity identities, physical-state hashing, Water defaults or the MAT-AUTH lock. The cache remains derived and nonserialized. An uncertain or incomplete proof falls back to the complete reference gas operator.

The wider PR advances only the pressure-optimization **execution identity** from v4 to v5 because derived gas bookkeeping work changes. The physical-state/save identity remains unchanged.

## Review and merge constraint

The compatibility guard authenticates the source commit above and requires it to remain in HEAD history. PR #532 therefore requires a merge commit for this transition; squash/rebase integration would need a separately reviewed replacement transition pointing at retained merged bytes.

Status remains **PROPOSED / NO MERGE** until exact-head native, deterministic replay, real-workbench performance, platform/runtime and independent-review gates pass.
