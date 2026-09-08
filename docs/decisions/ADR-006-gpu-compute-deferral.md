---
title: ADR-006 — GPU compute deferral
document-kind: decision
canonical-for: [decision-gpu-compute-deferral]
status: Approved design
scope: Accepted CPU authority, deferred GPU field experiments and conditions for reconsideration
keywords: [ADR, GPU compute, deferred, CPU authority, synchronization, readback]
related-documents: [../architecture/principles-and-non-goals.md, ../systems/smoke-heat-pressure-roadmap.md, ADR-001-native-simulation-core.md]
last-reviewed: 2026-09-08
---

# ADR-006: GPU compute deferral

## Decision and implementation status

**Approved:** keep native CPU authority for material occupancy and collision.
**Rejected at this stage:** GPU-authoritative terrain. **Deferred:** isolated
GPU experiments for suitable non-authoritative or separately designed fields.
This is not a permanent ban on GPU compute.

**Current:** Godot uses presentation shaders under GL Compatibility; no
compute-simulation backend is implemented. Sources:
[project renderer](../../godot/project.godot),
[material shader](../../godot/shaders/material_palette.gdshader) and
[native World](../../native/src/world.cpp). Rich shader motion/glow is visual
derivation, not evidence of GPU simulation or GPU saturation.

## Why defer authority?

Terrain interacts with CPU collision queries, material rules, commands, saves
and future streaming/replay. Moving those bytes to a GPU without a complete
ownership design risks readback latency, stalls and competing CPU/GPU truths.
A small fast kernel alone does not establish a faster integrated simulation.
Native ownership and fixtures are the immediate foundation.

The decision leaves room for resident derived fields whose consumers tolerate
their latency and non-authoritative nature. It selects no API, shader language,
field format, cadence or target hardware. That specificity belongs to a later
proposal with measured end-to-end cost.

## Consequences and alternatives

CPU authority simplifies collision access and independent tests, while initial
scale depends on CPU memory bandwidth and scheduling. A future GPU path will
need separate platform/fallback evidence. A derived visual field must not
silently start deciding authoritative motion.

**Rejected:** immediate GPU terrain authority and a permanent prohibition on
all GPU compute. **Deferred:** wholesale PhysX-like material offload; no such
compatible implementation is demonstrated here. **Current:** GPU rendering
from immutable simulation publication. The
[bridge contract](../architecture/rendering-and-gameplay-bridges.md) remains
applicable regardless of visual sophistication.

## What would justify a new decision?

Name the field and authority level; define CPU/GPU ownership, synchronization,
collision/query latency, save/replay behavior, device loss and fallback. Compare
representative current/larger fixtures including compute, transfer, synchronization,
readback and memory. A non-authoritative experiment must leave native
fixture state unchanged; an authoritative field requires a new explicit ADR.

No future experiment is considered validated merely because shaders compile or
a headless scene runs. Use [validation evidence](../reference/validation-evidence.md)
and [profiling guidance](../operations/profiling-observability-and-performance.md)
to distinguish actual device measurements from source inspection.
