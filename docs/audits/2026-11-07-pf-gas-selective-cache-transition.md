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
- Proposed LF SHA-256: `f575825e96e61caad200974a1f39396d4d09921e548719643145c5d2915abb2b`
- Source commit holding those bytes: `f0fffc6a488f585ff10966427e87cfc3d23ed04b`
- Parent issue: #201
- Implementation PR: #532

The protected-file edit is limited to the stale-cache retry path. When an optimistic component replay requests a complete uncached restart, the owner now discards the retained dirty-chunk proof before recursively resolving gas topology. That proof belongs to the failed replay attempt and must not authorize the new selective bootstrap.

## Authority boundary

This transition does **not** change material IDs, catalogue bytes, pressure law, gas quantity law, compartment identity/lineage rules, CYPS semantics, C1024/C2048 capacity identities, physical-state hashing, Water defaults or the MAT-AUTH lock. The cache remains derived and nonserialized. An uncertain or incomplete proof falls back to the complete reference gas operator.

The wider PR advances only the pressure-optimization **execution identity** from v4 to v5 because derived cache work changes. The physical-state/save identity remains unchanged.

## Review and merge constraint

The compatibility guard authenticates the source commit above and requires it to remain in HEAD history. PR #532 therefore requires a merge commit for this transition; squash/rebase integration would need a separately reviewed replacement transition pointing at retained merged bytes.

Status remains **PROPOSED / NO MERGE** until exact-head native, deterministic replay, real-workbench performance, platform/runtime and independent-review gates pass.
