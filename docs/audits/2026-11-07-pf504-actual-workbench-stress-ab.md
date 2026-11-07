---
title: PF504 actual workbench stress-canvas source-matched A/B
status: Planned
document-kind: audit
scope: Real gameplay full-resolution 2048x1024 eight-actor stress-canvas native A/B
last-reviewed: 2026-11-07
related-documents: [2026-11-07-pf-c2048-explicit-capacity.md, ../architecture/pressure-flow-v1.md]
---

# PF504 — actual workbench stress-canvas B-C-C-B

This is an independent **qualification experiment**, not an optimization merge, physics acceptance or runtime publication. It addresses the mismatch between PR #504's native-only 14.10% tick and 19.36% gas-phase improvement (72 source-matched pairs, run 42333533560) and PR #505's separate **2.71% slowdown** in an actual but half-scale Godot application workload (80 trials, run 42340715185). Do not extrapolate across these two different fixtures.

## Exact native sources

Accepted C2048 control SHA: 24a8bbe8ccf0d17196ebbab580b924930a964584.

Unmerged PR #504 candidate SHA: 186452b9f035961325ad71917a76ba8834e30bcf.

Their native production code may differ **only** at native/src/world_pressure.inc; the source SHA-256 values must match the reviewed 71723fa3... and 899ada71... transitions. Build two independent GDExtension libraries with the same GCC 13, SCons 4.10.1, pinned godot-cpp 101ae380, Godot 4.7 and pinned Rapier native runtime. No installed stale LFS library is allowed.

## Actual gameplay workload

Use the actual authored workbench_setup.gd::stress_canvas, not a half-sized re-creation: **2048 x 1024**, eight live Rapier barrels, C2048 PressureFlow Water cached_dormant gas, ballistic face/jet/spray, deterministic hard wall/erase edits every two native ticks. Preserve the admitted workbench test's 24 warmup plus 240 sample ticks, actor progress, collider packet revisions and conservative sample thresholds.

On a single hosted Linux machine, run **B-C-C-B** in fresh Godot processes. Source-built runtime binaries are swapped into the same accepted C2048 Godot application while all GDScript, physical scene, options, workbench content, Godot, Rapier and test harness stay unchanged.

Measure workbench native simulation_time_ms p50/p95 (observed wall time), hard-packet p50/p95, publication cost, actor steps, real ballistic parcel ledger and worker-frame sample counts. Archive all source/runtime SHA fingerprints and raw logs with a strict comparator and a JSON outcome. Negative speedups are valid findings, not a reason to skip evidence.

## Explicit limits

The workbench currently lacks native physical-state hash, complete native quantity/gas conservation ledger, native gas-stage **CPU** and actual participating worker count. A passing result validates **a matched, genuine, bounded application performance experiment**, not bitwise physics exactness or an unrestricted release. Ordinary asynchronous actor movement is not lockstep determinism.

Do not merge PR #504, modify production LFS/provenance, rerun the expensive 1,080+1,080 factorial, or overwrite the independent PR #505 result as part of this task.
