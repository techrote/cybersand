---
title: PF-V2 named-canvas PressureFlow bottleneck discrimination
status: Current
document-kind: audit
scope: Issue #481 tooling-only current-main measurement plan and execution record; no solver change or optimization admission
canonical-for: []
last-reviewed: 2026-11-06
related-documents: [2026-11-06-workbench-pf-tick-cost.md, 2026-11-06-pf-ballistic-tick-cost.md, 2026-11-06-stress-canvas.md, 2026-11-06-pf-run-head-repair-draft.md, ../architecture/pressure-flow-v1.md]
---

# PF-V2 named-canvas bottleneck discrimination

**Scope:** profiling apparatus and evidence only. This branch does not change `World`,
PressureFlow, material authority, compatibility locks, defaults, or a production runtime.

Pinned starting main: `7e2c2fd1aa2759590d63d5dfb53ce9e4c0a76e4b`.

The workflow generates `my-canvas`, `bench-canvas`, and `stress-canvas`
rectangle streams directly from the canonical `workbench_setup.gd` recipes, then
compiles a native profiler against the same pinned source. The profiler enables the
actual workbench parallel PressureFlow head path and records existing cumulative
native timers/counters only.

Configurations cover reference/cached/cached_dormant, gas off/on at six configured
workers, one-worker cached_dormant controls, and a separate gas-off cached_dormant
ballistic face-release context using the workbench tuning (budget 320, speed 288,
period 1, minimum height 4). That native context contains no Rapier body impact
spray and must not be represented as a full workbench/Godot result.

Stress gas-on capacity refusal is retained as a legitimate result. No capacity is
raised to manufacture a timing.

## Execution record

Pending first exact-source hosted run. Preserve raw per-configuration JSON, generated
scene rectangle inputs, compiler/host/source identities and a machine-readable
summary. The decision must choose the next target from invalidation breadth, head
preparation, gas topology, Water kernel/neighbour work, ballistic face release, or
no useful PressureFlow-local optimization.
