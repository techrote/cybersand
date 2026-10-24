---
title: ADR-009 — Rapier2D rigid-body backend
document-kind: decision
canonical-for: [decision-rapier2d-backend]
status: Current
scope: Accepted Rapier backend/version selection, manual owner and remaining platform/physics/replay work
keywords: [ADR, Rapier2D, Godot Physics, version pin, manual stepping, Salva]
related-documents: [../architecture/rigid-body-and-cellular-coupling.md, ../operations/rapier-2d-migration-runbook.md, ADR-007-rigid-body-cellular-coupling.md]
last-reviewed: 2026-10-24
---

# ADR-009: Rapier2D rigid-body backend

## Decision and implementation status

**Approved and Current:** Rapier2D is the sole runtime rigid-body backend.
Retain exact Godot `4.7.stable.official.5b4e0cb0f` and the official 2D single
Rapier add-on `v0.35.2`. The qualified #234 repair selects the scoped Windows/Linux
x86_64 cooperative deferred-BVH join backport on 2026-10-24. Other architectures and Web retain the
original release artifacts. The add-on's broader 4.7.x declaration does not authorize
untested dependency drift. Versions, release hashes and notices are in the
[Godot runtime lock](../../third_party/godot-runtime.lock.json) and
[Rapier lock](../../godot/third_party/rapier2d.lock.json).

The [dated blocking-call and paired validation record](../audits/2026-10-24-physical-actor-bvh-validation.md)
owns the backport evidence. The patch changes only the parallel deferred receive
to help queued Rayon work while waiting; the outside-pool receive and disconnected
producer failure remain intact. Native cell authority, physics parameters,
thread-pool size and engine-owned interfaces are unchanged. Per-platform runtime
provenance retains the exact upstream sources, patch, dependency lock, compiler,
build run and tested library hashes; the original release archive hash is preserved.
This adopts the prior qualified PR #236 artifacts. The integrated PR head passed
exact-head ordinary gates and merged as `13b8e631f3e8fbaa2176ed41afc02c434b11e558`.
The [integration ledger](../audits/2026-10-24-issue-234-physical-hang-repair.md)
owns completed fresh standard qualification run `40129364630` at that source:
600/600 physical passes, 0/600 timeouts, zero other failures and twenty passing
imports, separately from the prior 300-candidate paired comparison and admitted
#233 baseline. This qualifies the registered workload and exact desktop artifacts;
native-worker count was not varied and the precise scheduler trigger remains
unproven. It does not extend acceptance to other architectures or Web libraries.

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

## 2026-09-09 measured scope

**Current:** the [physics baseline](../audits/2026-09-09-physics-characterisation.md)
uses pinned Rapier v0.35.2/Godot 4.7 in Windows manual-step and asynchronous
fixtures, plus actual Web compatibility/threaded exports. It distinguishes hard
contact from cellular feedback and publishes sample-age/cap observations.
No backend pin, production tuning or ownership decision changes here. Reconstructed
cell overlays and browser fixture execution are not gameplay visual acceptance.
