---
title: PR 405 camera-only PressureFlow current-main transition
status: Current
document-kind: evidence
scope: Source composition, bounded performance evidence, and reviewed material authority
last-reviewed: 2026-11-07
related-documents: [2026-11-05-lcb201-moving-camera-invalidation.md, ../architecture/pressure-optimization.md, 2026-11-07-pf-c2048-mat-auth-transition.md]
---

# PR #405 — camera-only current-main integration

This candidate deletes only the selected-core camera-change
`pressure_->cache->cold()` invalidation in `World::set_simulation_region`.
The independent settled-discovery inclusion wake and all actual pressure
authority-change invalidations remain. The accepted C2048 construction,
C1024 historical identity, Water/ballistic, chemistry, dense directory,
#471 neighbour cursor and #474 default-off lockstep are untouched.

- Protected path: `native/src/world.cpp`
- Accepted main baseline: `e90abd9d25702a9a92e8a3cfe0aaa5e45a277b9d`
- From LF SHA-256: `8a40c7dff894a121a234fbd18de6fa21a43c0c5330ccdc9e12b200af14a4f37d`
- To LF SHA-256: `b6cedf52e795073630f12f77668a461b6f9c3bb5fe02c64e7b6649bee4a6239a`
- Source merge commit: `__SOURCE_MERGE_COMMIT__`
- Original #405 historical head: `ad566a24982b9b54673b6d44e60a0ad98ef921a9` (first parent), accepted main
  second parent. Frozen MAT-AUTH lock and prior transitions are unchanged.

## Rejected broader candidate, preserved history

The old combined #405 branch added a generation-keyed `thread_local Chunk*`
fallback cache as well as the camera change. It did not establish a general
performance benefit. Earlier non-PF slowdown results were confounded by
historical-source drift and base-before-candidate run order. That pointer cache
is **not included** in this candidate: the accepted dense directory and pair
reaction fast paths already exist. Exclusion also avoids the unresolved
GEN-006 selective-eviction/TLS pointer lifetime hazard.

## Correctness and performance evidence

Source `e90abd9d25702a9a92e8a3cfe0aaa5e45a277b9d`, [current-main ABBA run 42353922828](https://github.com/techrote/cybersand/actions/runs/42353922828):
16 native executions in B–C–C–B order, equality of normalized PressureFlow
state and Water quantities for all camera arms, and exact full physical-state
hash and Water quantity for no-camera FreeMass/inertial/gas-free controls.
At 16-cell/tick camera movement, cached p50 +89.76%, cached_dormant p50 +89.70%.
Static-camera cached -2.01%, FreeMass -0.40%, inertial -0.41%, gas-free
cached_dormant -0.41%. The previous multi-ms non-PF slowdown did not reproduce
with this one-source-delta candidate. It remains a one-worker Ubuntu experiment,
not a general platform-performance or whole-game deterministic-replay claim.

The native selected-region regression covers reference/cached/cached_dormant,
1/4 workers, gas on/off, moving/shrinking/unbounded region and exact pressure
state. The Godot worker-interest fixture checks the former camera-flip control
now retains a warm index; its previous rebuild expectation was intentionally
reversed, not discarded.

## Remaining acceptance gates

Source-matched Windows/Linux GDExtension binaries and manifests, MAT-AUTH
source admission, complete exact-head Native/ASan/UBSan/TSan, actual Windows/Linux
Godot (including pressure, ballistic Water and lockstep-default controls),
independent final review and post-merge execution. No earlier published binary
or historical 59-pass head qualifies this source.
