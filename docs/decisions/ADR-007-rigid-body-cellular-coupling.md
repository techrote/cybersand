---
title: ADR-007 - Separate rigid-body occupancy coupling
status: Current
scope: Entity/material representation, start-of-stage collision mask, two-way observations, overlap reconciliation, and backend independence
keywords: [ADR, rigid body, occupancy mask, two-way coupling, overlap, Rapier2D]
related-documents: [../architecture/rigid-body-and-cellular-coupling.md, ADR-003-godot-bridge-and-immutable-snapshots.md, ../architecture/simulation-tick-and-threading.md]
last-reviewed: 2026-09-08
implementation-state: Rectangle coupling is Current with desktop asynchronous and Web synchronous ownership, manual Rapier stepping, separate endpoint occupancy, bounded sweep and per-body cast-shape CCD; generalized shapes, selective substep/CCD policy, torque and particles remain Planned.
---

# ADR-007: Separate rigid-body occupancy coupling

Evidence scope (2026-09-08): **Current** below describes inspected source in the
reconstructed local snapshot, not a verified Git HEAD or an all-platform test pass.
See the [documentation audit](../audits/2026-09-08-documentation-audit.md) for
source identity and dated validation; [M11 audit records](../audits/m11/README.md)
retain historical scope. **Approved design** means Approved direction; Planned,
Deferred, and Rejected statements do not claim implementation.

## At a glance

- Decision: rigid bodies remain independent physics entities and project a separate read-only occupancy mask into cellular stages.
- Decision: material cells are not destructively removed merely to transform a rigid body.
- Decision: workers return bounded value-data observations; they never access live Godot physics objects.
- Decision: moved-body overlaps use an explicit, ordered reconciliation stage.
- **Current**: the Godot proof implements this decision for three rectangles.
- **Current**: moved rectangles reconcile a bounded swept path before retaining only endpoint occupancy.
- **Current**: the native bridge carries packed rectangle samples/results; generalized shapes and production policy remain **Planned**.
- **Explicitly rejected**: one mutable pixel grid jointly owned by PhysicsServer2D and cellular workers.

## Search anchors

ADR rigid body mask, remove restore pixels, start transform obstacle, pixel force body, deterministic overlap

## Status

**Current** for the Godot/native rectangular proof; generalized shapes, torque,
particles, and final production policy remain **Planned**.

## Context

Rigid bodies and cellular materials have different integration rules and thread
owners. Temporarily erasing a body's visual/material pixels without another
collision representation exposes false Empty cells to Sand, liquids, and gases.
Restoring transformed pixels afterwards cannot undo every movement through that
false space and creates ambiguous overwrite behavior.

The project also needs pressure and impact feedback, moving-body displacement,
bounded overload behavior, and compatibility with Rapier2D, the selected and
enabled rigid-body backend.

## Decision

1. A rigid body is not authoritative material occupancy.
2. At the cellular stage boundary, accepted body transforms rasterize into a separate stable occupancy mask.
3. Cellular reads treat that mask as solid while retaining original material state separately.
4. Cell impacts, boundary pressure, displacement, unresolved overlap, and later torque are accumulated as bounded observations keyed by stable body identity.
5. After external rigid-body movement, an ordered reconciliation stage ejects, converts, defers, or reports overlapped material according to explicit capacity and material traits.
6. Only packed immutable samples/results cross the engine boundary.
7. Current rectangles use a bounded sampled sweep and already enable cast-shape CCD in Rapier. A selective CCD/substep policy remains Planned; it must keep work bounded.

The current rectangle proof is approximate. It establishes the ownership and
message shape, not final numerical constants or production interfaces.

## Consequences

Positive consequences:

- cellular rules never see a temporarily hollow body;
- rendering, material identity, and rigid-body identity remain decoupled;
- workers require no per-cell atomics or PhysicsServer calls;
- backend replacement does not require rewriting material rules;
- overlap loss and capacity pressure can be observed explicitly;
- different materials can later choose displacement, trapping, conversion, or pass-through traits.

Costs and risks:

- independent solvers introduce sample latency and approximation error;
- mask rasterization and reconciliation consume bounded per-body work;
- fast motion requires swept coverage or substeps;
- pressure impulses need tuning and may not equal a continuum solution;
- rigid bodies still need their own collision representation for body/body contacts.

## Alternatives

### Remove and restore rigid-body pixels

**Explicitly rejected** as the only collision representation. It creates false
Empty space during the cellular step and ambiguous material overwrite after
movement. A visual pixel payload may still be transformed for rendering if the
separate collision mask remains present.

### Generate a PhysicsServer collider for every active cell

**Explicitly rejected**. Per-cell physics objects would multiply object,
broadphase, synchronization, and lifecycle costs. Merged hard-surface static rectangles are already **Current**; generalized
contours remain **Planned**.

### One-way rigid-body-to-cell mask

**Explicitly rejected** as the complete solution. It blocks cells but cannot
support buoyancy, impact response, displacement reaction, or gameplay forces.

### Put body membership directly in every base cell

**Deferred / experimental** for fracture bodies only. Optional membership data
may be appropriate in affected chunks, but charging every base cell and sharing
ownership does not solve external solver synchronization.

## Reversal or migration

The decision can be revised if one solver becomes authoritative for both rigid
and cellular motion and demonstrates better performance and behavior. Migration
must preserve stable body identity, material conservation rules, explicit
overlap outcomes, and the no-worker-Godot-access boundary.

## Validation

Current implementation: [native coupling](../../godot/native_extension/cyber_native_cell_world.cpp),
[Rapier bridge](../../godot/scripts/rapier_physics_bridge.gd),
[body configuration](../../godot/main.tscn). Native mask ownership is ascending
body-ID order; fallback ownership follows input order.
[The runbook](../operations/rapier-2d-migration-runbook.md) scopes dated
Windows/Chromium evidence separately from historical Linux results.

The rectangular proof should be manually checked for:

- Sand, Water, Paste/Slush, and Smoke not moving through a stationary or falling body;
- bodies landing on Wall without permanent penetration;
- bodies displacing movable material without silently deleting it;
- material impacts and pressure changing body motion in the expected direction;
- repeated coupling samples not applying twice;
- unresolved overlap being visible in diagnostics;
- stable rendering while simulation cadence degrades under load.

Exact numerical parity between rigid-body backends is not required.

## Related decisions

- [ADR-003: Godot bridge and immutable snapshots](ADR-003-godot-bridge-and-immutable-snapshots.md)
- [ADR-002: Benchmark-gated cellular schedulers](ADR-002-double-buffered-tile-jobs.md)
- [ADR-009: Rapier2D rigid-body backend](ADR-009-rapier-2d-rigid-body-backend.md)
- [Rigid-body and cellular coupling](../architecture/rigid-body-and-cellular-coupling.md)
