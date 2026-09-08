---
title: ADR-009 — Rapier2D rigid-body backend
document-kind: decision
canonical-for: [decision-rapier2d-backend]
status: Current
scope: Accepted Rapier backend/version selection, manual owner and remaining platform/physics/replay work
keywords: [ADR, Rapier2D, Godot Physics, version pin, manual stepping, Salva]
related-documents: [../architecture/rigid-body-and-cellular-coupling.md, ../operations/rapier-2d-migration-runbook.md, ADR-007-rigid-body-cellular-coupling.md]
last-reviewed: 2026-09-08
---

# ADR-009: Rapier2D rigid-body backend

## Decision and implementation status

**Approved and Current:** Rapier2D is the sole runtime rigid-body backend.
Retain exact Godot `4.7.stable.official.5b4e0cb0f` and the official 2D single
Rapier add-on `v0.35.2`. The add-on's broader 4.7.x declaration does not authorize
untested dependency drift. Versions, release hashes and notices are in the
[Godot runtime lock](../../third_party/godot-runtime.lock.json) and
[Rapier lock](../../godot/third_party/rapier2d.lock.json).

Ordinary RigidBody2D/RectangleShape2D nodes remain supported while
`CyberRapierPhysicsBridge` owns explicit space stepping and direct-server state.
Cellular liquids retain native authority; this migration does not substitute
Rapier/Salva particles. Source: [project selection](../../godot/project.godot),
[bridge](../../godot/scripts/rapier_physics_bridge.gd).

## Why choose an explicit adapter owner?

The earlier proof applied delayed cellular results through scene properties.
Direct PhysicsServer state avoids treating cached presentation transforms as
physics truth. Manual stepping, batch active transforms and a controlled query
flush make the integration order inspectable. Stable value samples preserve
backend independence and keep live RIDs off cellular workers.

The [threading contract](../architecture/simulation-tick-and-threading.md)
owns exact desktop/Web order. Desktop coupling is asynchronous; Web sequences
both solvers on the main thread. Fully asynchronous Web ownership is **Deferred**.
Neither path proves complete coupled replay merely by using a dependency
advertised as deterministic.

## Consequences and alternatives

The selection gives one backend and explicit main-thread integration, but adds
pinned binary/template/notices requirements for every export target. Performance
remains workload-dependent. Solver, scale, CCD and collision-filter changes
require project fixtures, not assumptions about the dependency.

**Rejected for production:** continued Godot Physics 2D selection and replacing
cellular Water with Rapier/Salva during this migration. **Deferred:** embedding
Rapier directly into a future native/Rust core. No per-frame backend toggle or
native Rust host is implemented.

A later backend replacement must preserve engine-owned value contracts,
material authority and tested contact behavior. Historical pre-Rapier checkpoint
names are not proof of a currently usable rollback; consult the
[source checkpoint](../operations/source-checkpoint-and-recovery.md).

## What remains incomplete?

**Planned:** generalized shapes/torque, adaptive CCD/substep policy, high-count
callback removal, complete physics replay and remaining export-platform
acceptance. Per-body cast-shape CCD is already Current. The rectangle fixture
allows bounded transient penetration; it does not certify zero penetration or
all thin/fast shapes.

The [coupling contract](../architecture/rigid-body-and-cellular-coupling.md)
owns numerical limits. The [Rapier runbook](../operations/rapier-2d-migration-runbook.md)
and [validation ledger](../reference/validation-evidence.md) distinguish retained
Windows/Chromium results from historical Linux evidence, manifest checks and
untested platforms. Selected body save fields omit Rapier solver internals;
[level saves](../reference/level-saves-and-replay.md) are not exact trajectories.
