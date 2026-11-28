---
title: ObjectShard M4 owner-reported severe active-Rapier FPS and moving-Wood edit failure
status: Draft/HOLD — unqualified source candidate
document-kind: engineering-audit
last-reviewed: 2026-11-23
---
# ObjectShard M4 — physical edit and active Rapier frame pacing

## Reproduced negative acceptance baseline (retain)

Owner on Windows 11/Godot 4.7 official/Rapier2D 0.35.2 reports sustained **below 10 display FPS for the entire time Rapier bodies are active**. Exact owner machine frame traces have not yet been received. Treat as an acceptance-blocking severity-one performance defect, not a known limitation to waive.

The source-exact Windows candidate `607e0e6ec438f053f7a420bd2072b2a9e9a2bcca` returned:
`{"checks":39,"failures":["real applied-pose moving Wood cell erased through native shard receipt"],"native_and_rapier_steps":120}`.
Historical Windows job: https://github.com/techrote/cybersand/actions/runs/45101963624. **No current-candidate pass is implied**.

## Moving-edit witness defect

`godot/tests/test_object_shard_m4_same_world_physical_chain.gd` originally hard-coded `target = 4`. Native `Coordinator::capture_component()` constructs a one-empty-cell border around detached components. A 3x3 Wood authoring fixture therefore creates a 5x5 carrier, and zero-based index 4 is in its empty border, **not an owned Structural Wood cell**. The owner test previously submitted an unsupported moving-cell erase rather than an admitted structural edit.

The corrected test enumerates the **currently published exact native snapshot** and selects a Wood cell with `role == Structural (1)` and `material == Wood (7)`, asserting the entire nine-cell structural roster before attempting the revisioned native edit. It selects the central Wood witness to preserve connected geometry and never falls back to ordinary terrain painting. The new diagnostic source distinguishes stale body/pose/material/geometry/incarnation/payload from unsupported role or failed debit.

The test is not considered fixed until the actual Godot 4.7 owner-local native+Rapier physical-chain suite completes with a **zero-failure receipt** on the changed SHA, including post-edit geometry/mass/COM/inertia reinstallation and native acknowledgement.

## Frame-pacing repair candidate — preserve physics fidelity

The retained M3 exclusive worker historically called `CyberObjectShardLab::snapshot()` after **every** intermediate Rapier `accept_motion` receipt. That serializes full native World RGBA/material rasters, all mutable shard cells, terrain chunks and full accounting, even when intermediate frames are not displayed. A standard semantic interval has multiple real substeps, so the vast majority of these snapshots are redundant.

The opt-in candidate limits intermediate `motion` packets to *value-only* native applied pose acknowledgements when and only when all are true: exact result `ok`, `applied`, integral semantic tick and complete applied pose serial roster, and explicitly non-final segment. The host validates transport session, expected/native tick, operation, sequence and final/intermediate boundary. The previous full snapshot stays the only paint/edit authority until the final full native receipt. Refused/unapplied/invalid/final packets retain the full diagnostic path. All Rapier substeps, contact sweeps, physics parameters, material chemistry, GCR composition, material debits and native motion applications remain unchanged.

Original user-visible FPS measurement and semantic ticks/s are distinct: the candidate records actual main-thread `_process` intervals, specifically those with active Rapier RIDs, in addition to per-stage native, snapshot, accounting, receipt and physics measurements. The 240-interval real three-body profile exercises Water, Sand, Fire, terrain and live authoring; no simulated frames or duplicated World are admissible.

## Acceptance gates — NOT CLEARED until proven

1. Exact changed-source GCC/Clang sanitizer and native World/coordinator material-conservation.
2. Official Godot 4.7 actual GDExtension moving-Wood, Rapier installed geometry+mass/COM/inertia, post-edit receipt and retirement: **all positive**, not merely refusal.
3. Same live World Water/Fire, three owners, authored edits, reset/replacement, malformed/late receipt adversaries, full immutable GCR coexistence.
4. Actual Windows executable/package with same source SHA, DLL and Rapier; rendered interactive acceptance.
5. Owner machine measured active-body display frame intervals and stage timings, explicitly comparing to the user's below-10-FPS regression. Aim for responsive 60 FPS where feasible; investigate any sustained below 30 FPS. Do not present headless CPU simulation ticks as NVIDIA display FPS.
6. Keep original negative logs and previous source-provenance failures. No merge, production default or Ready promotion without owner authority.

The M4 ordinary Workbench command/geometry handoff remains a **separate unfinished integration gate**, independent of the M3 physics host optimisation. This branch is an experimental repair candidate, not final M4 release.
