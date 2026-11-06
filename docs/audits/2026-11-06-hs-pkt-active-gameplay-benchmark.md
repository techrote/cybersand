---
title: HS-PKT source-pinned active gameplay stress benchmark
status: Current
document-kind: evidence
scope: Separate non-release experiment on the accepted-source Draft #470 candidate; read-only pinned source arms and experimental diagnostic overlays
canonical-for: []
last-reviewed: 2026-11-06
related-documents: [2026-11-06-hard-surface-packet-incremental.md, 2026-11-06-pf-ballistic-tick-cost.md, ../architecture/data-ownership-and-lifetimes.md]
---

# HS-PKT active hard-terrain, actor and PressureFlow gas A/B/B/A

## Review and experiment scope

This is a **separate, bounded experimental benchmark** stacked on PR #470. It does not amend the previously qualified #470 commit or request runtime publication/merge.

An independent GitHub **COMMENT** review was posted against PR #470 exact head `6aa03fe21dbe88b308793f377e4d223a90e4da8f` (review `5808446014`). The source/candidate-runtime disposition is **ACCEPT WITH QUALIFICATIONS**, not production merge admission. Examined native mutation/worker-bit paths, transactional consumption, adapter exception recovery, render isolation and actual Linux/Windows byte-oracle CI. Original profiling does not qualify sustained active edits on my-canvas or stress-canvas.

## Immutable comparison

| Arm | Source |
|---|---|
| A — original control | PR #406 exact `4a80af2a891332176a3912a235582d77d076a185` |
| B — tested #470 implementation | exact `6aa03fe21dbe88b308793f377e4d223a90e4da8f` |

The experiment's added diagnostic script `godot/scripts/hard_surface_active_stress_profile.gd` is copied byte-identically onto each **separate detached, pinned source** worktree. Each native GDExtension is rebuilt separately using the same pinned godot-cpp, SCons, compiler and engine version, on the **same GitHub-hosted runner**. Both use the same selected Rapier 2D library hash. Diagnostic script overlay and loaded binary SHA-256 are recorded; no engine code, native solver or mainline branch is changed.

Order **A / B / B / A** is fixed; no post-hoc sample selection. A run has two built-in 512×512 and 2048×1024 canvases (respectively `my-canvas` and `stress-canvas`) with their authentic workbench actor definitions. The profiler configures **PressureFlow V1 / cached_dormant** with gas enabled using the native policy validator, opts into native **ballistic Water**, face release, and impact spray plus a finite jet, and verifies the *applied* policy and native ballistic/spray readbacks. The native ballistic ledger must record actual launch/injection activity.

Following 24 warmup ticks it collects 240 simulated ticks. At intervals of two observed ticks it submits an admitted worker-queue disc edit; 8–16 anchored positions cycle **hard Wall / Empty** with each anchor alternating across a full index cycle, not globally per edit. This workload deliberately forces hard-surface revisions while actual Rapier actor coupling and liquid solvers run. The edits enter the same worker command queue used by the real workbench and never mutate World from Godot's main thread.

## Strict readback / limitations

The raw Godot `HS_ACTIVE_PROFILE` lines contain positive-only executed collider packet durations, render exchange, simulation and publication-stage distributions, actual native hard revision changes, accepted edit counts, actor tick/readback activity, PressureFlow policy/gas identity, native ballistic activity, source/runtime hashes, and platform. The reducer verifies eight complete arm/canvas reports and refuses invalid identity, no gas, disabled ballistics, missing actor steps, fewer than 45 accepted edits, fewer than 35 actual hard revision changes, or **fewer than 40 executed collider packet samples** on any arm/canvas. It does **not** require a speedup threshold.

Gas being **enabled** is verified from the applied native policy; the experiment does not assert a nonzero sealed gas inventory unless separately evidenced by compartment diagnostics. Real actor movement and ballistic native events are distinct from merely selecting a UI option.

The results cannot be generalized to the user's desktop GPU/OS without a same-host reproduction, and headline per-packet speedup is not identical to whole-frame or FPS improvement. The benchmark does not qualify canonical retained-runtime LFS provenance or approve a merge.

## Qualification ledger

- Source review: **POSTED**, review `5808446014` on #470.
- Separate benchmark source/workflow: **IMPLEMENTED FOR EXECUTION**, pending exact hosted run.
- Both arms rebuilt on same host: **NOT YET VERIFIED** until CI logs.
- Both canvases, actual actor + PF gas + ballistic activity: **NOT YET VERIFIED**.
- ≥40 per-arm executed hard-packet samples, >=35 hard revisions: **NOT YET VERIFIED**.
- 8/8 complete original log readbacks: **NOT YET VERIFIED**.
- Claimed numerical improvement for sustained active edits: **NONE YET**.
- Binary publication or merge: **NOT AUTHORIZED**.

The experiment is permitted to produce a failed qualification receipt; no missing sample or inactive feature may be relabelled as success. Any failure is retained as evidence for a bounded corrective iteration in the *experimental* branch.
