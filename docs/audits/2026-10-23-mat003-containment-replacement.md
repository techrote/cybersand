---
title: MAT-003 small-fixture containment repair and blocked replacement registration
status: Current
document-kind: audit
scope: Isolated source repair and replacement registration preparation; no builds, probes, cases or timing
canonical-for: []
last-reviewed: 2026-10-23
related-documents: [2026-10-23-mat003-windows-correctness-attempt.md, ../research/mat003-correctness-only-plan.md]
---

# Source diagnosis and isolated repair

Owner authorized investigation/repair, independent review and replacement registration preparation, stopping before execution. Intake is ffe6598, with tested apparatus source6e85fe6. The failed attempt (293 completed ticks, failure on294) and its835-entry archive remain unchanged. The exact failed coordinate/caller is unrecorded; no replay, reconstructed failed state or asserted specific physics cause supplies missing evidence.

The fixture reserved256² cells and capped resident chunks at4, but had a bottom floor and open outer sides. Serial World move/transfer writes can call ensure_chunk on a nonresident destination. Phased prepare_write_domain separately allocates an absent neighboring chunk when its radius-intersection contains any rule-active source, regardless of whether an eventual collision would stop movement. Simulation interest restricts selected cores, not all destinations. Merely increasing the cap or adding one-cell walls would not preserve the exact resident geometry and phased preallocation contract.

The small-only fixture now checks side256 and maximum_rule_radius2, then fills all four outer two-cell strips and corners with inactive Wall inside the existing grid. The interior retains all original seeds, lifecycle actions, input pulses, chunk seam crossing and2048-tick horizon. Seed3,3 is outside the band; all other fixture writes are also interior. The existing floor joins the band. No resident count, capacity, process matrix, worker setting or production rule changes.

For serial writes, every dynamic source remains at least2cells from an external chunk, and Current Wall is immovable/non-active for these materials. For phased execution,64-cell cores align within the128-cell chunks/256-cell grid; external candidate intersections contain only inactive Wall in their two-cell source strips. Core-self chunks remain resident. Neighbor waking uses find_chunk; temperature spread allocates sidecars only on existing chunks. This is a source-bound containment argument, not runtime proof.

Independent full-cell readback requires materialWall and zero a/b/R/U in every border cell at every small endpoint including tick0. Epoch labels/clear follow existing checks; no invented ambient-temperature invariant is imposed. Three new future negative fixtures cover missing outer Wall, active inner strip and corrupt neutral state; positive fixtures cover edges/corners, legal epochs and interior dynamics. These fixtures are written but not executed. All decoded temperatures and complete raw bytes remain retained and compared by the existing oracle.

## Replacement gate

The replacement keeps the152-case matrix, original resident-size/worker/horizon/resource limits, no retries and complete raw retention. Only the48 small-World cases have changed initial boundaries. Every candidate will require newly generated sources and rebuilt binaries; the old32-binary certificate cannot admit changed source. The replacement registration must explicitly remain blocked with no binary/build seals until a separately authorized build-only stage and independent binary review are complete. Its preparatory hash cannot authorize cases or timing. Exact final execution hash is available only after those gates and a further independently reviewed execution registration.

No apparatus import, compilation, generator invocation, probe, candidate case, negative-fixture execution or timing occurred. Static AST parsing and documentation checks are maintenance only. Production/Water/GEN-006, accepted controls/statistics and all prior failures remain untouched; R16-T1 conditional and PR211/221 draft. Independent source disposition, new source identity and blocked registration seal follow below.

Independent reviewer /root/independent_review approved the exact four-file repair for source freeze, with no definite source blocker identified. It confirmed complete band geometry, explicit radius/extent guards, interior fixture writes, both serial/phased allocation arguments and full endpoint verification. Canonical LF hashes: world.cpp a1617ab1bb1bea888f34fc2892efc0b02c00f6a494e566bb6af6efd23c63d184; readback.py eff3ab7257a622c786a96c65a275bb3b0990dbefb039f701a272d78ed1809ed4; world_oracle.py a0ee90375b7528110c89d1aaf7d3c5cc7d7a618b4cf7c731009c9e866c17f902; negative.py 98df4ab09f7d7d0b41d6b786543bd9b91ee132e79ec53ffbb211f48ceb05757b. This source-only review grants no build, case or timing authority and demonstrates no runtime success. Static AST parsing, docs/repository/historical M11 and diff checks passed.
