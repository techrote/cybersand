---
title: Troubleshooting simulation and integration
status: Current
document-kind: guide
scope: Symptom routing and discriminating checks; fixes require a separate implementation checkpoint
canonical-for: [symptom-routing]
last-reviewed: 2026-09-08
related-documents: [../reference/status-and-roadmap.md, testing-validation-and-replay.md, profiling-observability-and-performance.md]
---

# Troubleshooting simulation and integration

## Establish the failing path first

Record source/runtime identity, native versus GDScript fallback, desktop versus
Web, profile, worker count and first failing tick. Use
[build checks](local-build-and-validation.md) and the [evidence ledger](../reference/validation-evidence.md)
to distinguish a new failure from an old result. Preserve a minimal fixture before
changing behavior. A source diagnostic explains a defect; it does not approve a fix.

| Symptom | Discriminating check and canonical contract |
|---|---|
| Web drawing stalls despite pthreads | The outer callback still waits for native work; [threading](../architecture/simulation-tick-and-threading.md) distinguishes desktop ownership |
| One core dominates | Confirm backend/count, eligible jobs per phase, threshold and serial planning; [profiling](profiling-observability-and-performance.md) |
| Simulation freezes after camera returns | Inspect region exclusion and sleeping blocks; changing region does not wake them automatically; [storage/re-entry defect](../systems/world-storage-and-interest-region.md) |
| Native tick fails or appears to continue | Both owners stop; World is quarantined and may contain partial mutations. Preserve diagnostics, then explicitly reset or replace; never retry the partial World; [tick failure](../architecture/simulation-tick-and-threading.md) |
| Every other falling row is Empty | Inspect source/destination update stamps and bottom-up vacancies; [materials](../systems/materials-and-rule-kernels.md) |
| Water changes while apparently settled | Compare exact mass, content hash and dirty/activity counts; full state hash advances with time; [Water](../systems/water-design.md) |
| Stable cells look dithered or shimmer | Separate render animation from authority; [appearance](../systems/material-appearance-and-rendering.md) |
| Water forms a heap | Identify native conserved mass versus discrete fallback, pressure bounds and sleep; preserve closed-basin fixture; [Water](../systems/water-design.md) |
| Smoke fails to rise through a medium | Inspect directional exchange/target traits and activity; do not make all solids permeable; [materials](../systems/materials-and-rule-kernels.md) |
| Boundary seam or worker-count divergence | Compare first divergent phase, write domain, stamps, merge effects and conserved totals in shifted/negative-coordinate fixtures; [determinism](../architecture/determinism-and-boundary-transfers.md) |
| Body tunnels, traps or deletes cells | Separate stale samples, sweep limits, terrain backlog, displacement exhaustion and backend selection; [coupling](../architecture/rigid-body-and-cellular-coupling.md) |
| Rapier class missing or body does not step | Run dependency preflight, then isolated automatic/manual fixtures; [Rapier runbook](rapier-2d-migration-runbook.md) |
| Snapshot rejected or Image expects nonzero bytes | Record serial, rectangle, offset, stride and byte count; reject/retain until full-refresh recovery; [render handoff](../architecture/rendering-and-gameplay-bridges.md) |
| Low FPS with small bridge payloads | Dirty bridge patches still end in a full RG8 GPU texture update; distinguish copy/upload/render time; [render handoff](../architecture/rendering-and-gameplay-bridges.md) |
| Capacity exhausted or steady memory grows | Inspect category/use/capacity and lazy chunk/job storage; do not infer atomic rollback or zero allocations; [capacity](configuration-and-capacity-budgets.md) |
| Identical saves diverge after load | CYSD1 restores level fields, not all future-affecting state; [save/replay contract](../reference/level-saves-and-replay.md) |
| Unsafe Godot thread warning | Native workers call no Godot API; desktop owner only exclusive adapter/value APIs; [ownership](../architecture/data-ownership-and-lifetimes.md) |

## Preserve the failure boundary

For mass loss, divergent exact fixtures, dropped authoritative work, invalid leases
or unsafe ownership, stop the affected implementation checkpoint and retain its
inputs/logs. Do not hide the failure with clipping, silently increased capacities,
disabled collision or rewritten historical hashes. Some current failure paths are
incomplete; follow the precise contract instead of assuming the Approved invariant
is already enforced. [Roadmap](../reference/status-and-roadmap.md) names open issues.

For performance-only symptoms, measure the dominant stage and correctness on the
same fixture before tuning. More workers, reduced publication cadence or changing
the renderer cannot by themselves repair faulty sleeping, ownership or physics.
