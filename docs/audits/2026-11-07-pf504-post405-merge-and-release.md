---
title: CyberSand #504 gas fastpath after accepted #405 camera-only integration
status: Planned
document-kind: audit
scope: Integration, replay, source-matched Windows/Linux runtime admission, guarded merge
last-reviewed: 2026-11-07
related-documents: [2026-11-07-pf-gas-c2048-merge-transition.md, 2026-11-07-pr405-current-main-reconciliation.md, ../architecture/pressure-optimization.md]
---

# #504 on accepted #405 main — guarded source integration and final acceptance

## Source authority

The source reconciliation [two-parent merge `48fce8ebbcb0be3acbf9a0a459f4ce99f690805d`](https://github.com/techrote/cybersand/commit/48fce8ebbcb0be3acbf9a0a459f4ce99f690805d) preserves both histories: #504 experiment/source-published head `9933c74403d83652ad9928070234767b09a7b1d3` as first parent; accepted #405 main `81bbd5ff5cf366159e2b8a630609359c13560080` as second.

The combined tree is based on accepted main, carrying only #504 gas fastpath `native/src/world_pressure.inc` and its reviewed tests/CI/audits. Native `world.cpp` is **byte-identical to accepted main**, retaining #405's selected-camera-only cache warmth and deliberately omitting the discarded thread-local chunk pointer cache. Both native test registrations and both *append-only* material-source review transitions are retained; the historical immutable lock is untouched. All other accepted main source, scripts, materials, tests and docs are preserved. The original #504 branch and experimental source-backed evidence remain intact.

## Design choices

- **Select accepted #405 camera cache retention instead of historical #405 combined moving-camera/TLS optimization.** Its actual same-host current-main acceptance isolated the camera invalidation benefit without importing unqualified pointer lifetime risk. Reversing would need a new independent TLS proposal with lifetime, worker, eviction, exactness and whole-engine performance gates.
- **Keep #504's existing optimized gas discovery unchanged instead of speculative further optimization.** The true 2048×1024 eight-barrel workbench demonstrated an approximately 2–6% complete native tick improvement across *different same-host experiments*, with +10–16% gas-stage savings. The 1024×512 application screen did not improve; no universal positive claim is made. Reversing this choice means reverting the #504 gas operator and its single reviewed transition rather than altering accepted main #405.
- **Treat existing installed binaries/provenance as stale after combining source.** Do not mix the accepted camera-only runtime with new gas source, nor reuse the old #504 runtime missing #405. Build/validate distinct Linux/Windows GDExtensions against the *exact combined source*, retain SHA-256 and material authority, then append only four runtime/manifests under an expected branch SHA lease. This is branch-level development runtime, not a default promotion.

## Required gates (NO MERGE until proven)

1. Complete strict same-input 2048×1024 *Godot-authored material* native replay against accepted #405 `main` and the combined source, with exact native hash5/Water & gas ledgers on every completed tick, 1/4 worker parity and stationary/moving camera. A deterministic scripted eight-actor mask/edit/jet input tape is a native physics input fixture, **not a recording of independently timed Rapier body dynamics**. Preserve this distinction. Report any mismatch fail-closed.
2. Run one source-matched real Godot/Rapier full-size workbench B-C-C-B plus bounded reduced Windows control on the two exact current-main-equivalent sources. Screen for real application regressions; do not substitute the old #504 synthetic or old base.
3. Qualify Linux/Windows GDExtension source builds and real target Godot tests (including pressure variants, Rapier, C2048, workbench, worker interest), source-locked retained LFS binaries+manifests. Verify both source input digests, runtime SHA-256, ABI/platform floor, materials, and body ownership.
4. Complete latest-head Native suite, ASan/UBSan/TSan, Godot, documentation/provenance, Water apparatus and relevant shader tests without skipped required groups; independent code and evidence review; merge only under an expected-head guard and no concurrent main drift.

The original 2,160 paired trials are **not part** of this bounded acceptance. Source tests, candidate runtime publication and final merge are distinct events. A passing mechanical source guard is not a reviewer approval. This record must be updated with source heads, build/runs/artifacts, exact results, known gaps and disposition before any merge.
