---
title: ADR-007 — Separate rigid-body occupancy coupling
document-kind: decision
canonical-for: [decision-separate-rigid-body-occupancy]
status: Current
scope: Accepted independent body representation and value-data coupling; rectangle proof is not generalized physics
keywords: [ADR, body mask, remove restore pixels, two-way coupling, overlap, rigid body]
related-documents: [../architecture/rigid-body-and-cellular-coupling.md, ADR-003-godot-bridge-and-immutable-snapshots.md, ADR-009-rapier-2d-rigid-body-backend.md]
last-reviewed: 2026-09-13
---

# ADR-007: Separate rigid-body occupancy coupling

## Decision and implementation status

**Approved and Current for rectangles:** independent rigid bodies project a
separate stable obstacle mask into cellular work. Materials remain in their own
authoritative grid. Only packed value samples/results cross the worker boundary;
live physics objects stay with the main-thread adapter. Moved-body overlap has
an explicit bounded reconciliation outcome.

Current implementation sources are
[native coupling](../../godot/native_extension/cyber_native_cell_world.cpp) and
[Rapier bridge](../../godot/scripts/rapier_physics_bridge.gd). Exact geometry,
sweep/impulse bounds and numerical limits belong in the
[coupling contract](../architecture/rigid-body-and-cellular-coupling.md).
**Planned:** generalized shapes, torque, fracture membership and particle fallback.

## Why not remove and restore body pixels?

Temporarily erasing a crate's old pixels while simulating sand would expose
false Empty space. Restoring its transformed pixels cannot undo all movement
through that space and leaves overwriting ambiguous. Separate occupancy lets
cellular rules see a stable body without transferring ownership of its
material or physics state.

A mask alone is insufficient for the complete interaction: material impacts,
displacement and approximate pressure must also affect the body. Ordered
observations make that feedback explicit and testable without workers calling
PhysicsServer2D. Hard terrain contact is solved by Rapier rather than duplicated
by delayed cellular correction.

## Consequences and alternatives

The boundary decouples body visuals, material identity and backend identity.
It permits bounded displacement and reports unresolved overlap rather than
silently deleting cells. Its costs are mask/rasterization work, solver sample
latency, approximate feedback and the need for fast-motion safeguards.

**Rejected:** remove/simulate/restore as the sole collision representation,
shared mutable body/material authority, per-active-cell PhysicsServer colliders
and one-way masking as the complete solution. Merged static hard-terrain
rectangles are Current; they do not violate the per-cell-object rejection.
**Deferred:** optional membership data for future fracture bodies.

## What would justify revision?

One solver could eventually own both forms of motion, but only with evidence
that preserves stable IDs, conservation rules, explicit overlap outcomes and
bounded ownership. Backend replacement must not leak its types into rules.

The rectangle proof already uses sampled sweep and per-body cast-shape CCD;
it does not implement adaptive substeps. Validate shape/cell contact, thin
floors, displacement, stale/duplicate samples and observable unresolved overlap
for the affected platform. The [evidence ledger](../reference/validation-evidence.md)
scopes executed fixtures; exact level restoration is not exact coupled replay.
Broader acceptance requires more than passing the existing three-body scene.

## 2026-09-09 diagnostic checkpoint

**Current:** [issue #9 measurements](../audits/2026-09-09-physics-characterisation.md)
add bounded observation and isolated parameter fixtures without changing this
ownership decision. Repeated masked-source contacts, per-add saturation and
missing persistent bearing must be considered before selecting a support model.
**Current:** #10's [granular policy](../systems/granular-interaction-policy.md)
changes player and pair rules. The 2026-09-13 #11 repair resolves masked-source
feedback, barrier-aware bounded ejection and ordinary rectangle bearing through
this existing cellular coupling owner. It adds no granular Rapier collider and
does not generalize dynamic aggregate ownership; aggregates still need the
explicit exclusive-ownership ADR described by the characterisation plan.

## Issue #10 sampled support decision

**Current:** The character owner alone resolves material-aware sampled support.
That #10 decision itself adds no Rapier proxy or body-bearing impulse. See the
[granular/player policy](../systems/granular-interaction-policy.md); the separate
#11 rectangle consumer is recorded below.

## Issue #11 ordinary rectangle bearing decision

**Current within the documented ordinary envelope:** downward exposed rectangle
raster cells sample authoritative stored material through the #10 packing query.
The cellular coupling owner emits one capped central bearing impulse and a
same-tick settled correction; Rapier applies that result to its body. No support
height or per-body support history is stored. Missing, stale or region-paused
active samples produce no bearing. Excavation therefore releases the body without
collider invalidation. See the [dated repair evidence](../audits/2026-09-13-issue-11-repair.md).
