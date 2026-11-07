---
title: PressureFlow exact gas hotpath reviewed-source transition
status: Current
document-kind: evidence
scope: Draft experimental optimization of native PressureFlow gas discovery and seed prefilter, preserving identity, water/gas laws, capacity and source-chain authenticity
canonical-for: []
last-reviewed: 2026-11-07
related-documents: [../architecture/pressure-flow-v1.md, ../architecture/pressure-optimization.md, ../operations/material-catalogue-shadow.md]
---

# PressureFlow gas-discovery hotpath candidate — 7 November 2026

**Scope:** [PR #504](https://github.com/techrote/cybersand/pull/504) is a Draft performance implementation from accepted main `ab12ccef49ba2afaed2520d4d9a86eb14c7779cb`. It does **not** incorporate the concurrent in-flight C2048 [PR #491](https://github.com/techrote/cybersand/pull/491), the moving-camera/hash-map [PR #405](https://github.com/techrote/cybersand/pull/405), or the benchmark-only [PR #493](https://github.com/techrote/cybersand/pull/493). This source transition authenticates an experimental candidate. It is **not** production acceptance.

| Protected source | Admitted base LF SHA-256 | Candidate LF SHA-256 | Authenticated source commit |
|---|---|---|---|
| `native/src/world_pressure.inc` | `26051b0d10ab10d65db822c993742e0a0bf13711f3bd56158e95d77735737aca` | `a71d593a7ce3831e96f8bae47f5ff520ea75220da0ce94314d6d9ffc57960641` | `250f91bc4bb41d5ec0c8115933d87ade5648aa5e` |

The candidate preserves the original 4-connected, north/west/east/south BFS exploration order, 16,384-cell atmosphere bound, gas overlap and identity reducer, compartment IDs and ordered records, sealed/vented/vacuum rules, gauge formula and conservation. It replaces repeated `address()` calls for *same-chunk BFS neighbours* with local index arithmetic, while chunk seam neighbours always take the original complete address calculation. The read-only pooled seed prefilter makes the same immediate neighbour material/mask tests directly against its resident chunk for interior Water cells; edge cells still use the original cross-chunk lookup. When the mask's authoritative `occupied_indices` is empty, redundant mask tests are declined; source `World::clear_transient_obstacles` clears that set and all occupied `body_ids` together. No history, persistence or material catalogue identity is changed.

A new `test_lcb_pressure_gas_exact_hotpath` native regression exercises gas on/off, reference/cached/cached_dormant, one/four worker counts, negative and positive chunk seams, mask insertion/removal, and Water/wall edits. Existing pressure, mask, pocket, worker, save/restore and exact gas/quantity ledgers remain mandatory. Matched objective gas-on/gas-off measurements and cross-platform source-matched runtime publication are **not established** by this document.

**Source/provenance policy:** Append this non-identity-input reviewed transition to `tools/material_catalogue/compatibility.py` with the exact earlier hash and `250f91bc4bb41d5ec0c8115933d87ade5648aa5e`; retain the immutable compatibility lock and all older transitions. If #491 or another protected source owner merges first, reconcile both code and this audited transition as an additional **new** append-only source commit, never by rewriting the lock or historical evidence. Merge-commit ancestry must preserve the reviewed source commit.

**Decision:** Draft only until exact-head native/Godot Windows and Linux, sanitizer, MAT-AUTH checks, source-matched paired stress timing, source-compatible runtime publication and independent code review are complete. A faster-looking result without physical hash parity or matched initial materials cannot authorize admission.
