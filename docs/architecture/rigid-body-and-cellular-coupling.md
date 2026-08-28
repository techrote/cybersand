---
title: Rigid-body and cellular coupling
status: Current
scope: Rapier2D manual-step proof, separate cellular occupancy mask, asynchronous two-way coupling, swept overlap reconciliation, limitations, and native migration requirements
keywords: [RigidBody2D, Rapier2D, occupancy mask, two-way coupling, pressure impulse, overlap ejection, physics substep]
related-documents: [simulation-tick-and-threading.md, data-ownership-and-lifetimes.md, rendering-and-gameplay-bridges.md]
last-reviewed: 2026-08-28
implementation-state: Rapier2D v0.35.2 is manually stepped on the main thread; hard terrain is partitioned into 64×64 rebuild units, while CyberNativeCellWorld consumes copied body state, reconciles a bounded swept path, retains an endpoint obstacle field, and returns bounded fluid/particle impulses.
---

# Rigid-body and cellular coupling

## At a glance

- Purpose: keep independent rigid bodies visible to cellular physics and provide bounded two-way interaction.
- **Current**: rigid bodies are never removed from or restored into the material array because they are not stored there.
- **Current**: the native cellular bridge reconciles a bounded swept rectangle between accepted samples, then rasterizes the newest transform into a separate transient occupancy field.
- **Current**: Sand, liquids, Smoke, painting, and the sampled character treat occupied mask cells as solid.
- **Current**: cell impacts, density-derived boundary pressure, and displaced pixels produce bounded impulses for the corresponding RigidBody2D.
- **Current**: endpoint overlaps eject outward; swept-only overlaps push in body-travel direction, in deterministic body/input and cell order.
- **Current**: three red 8×14 RigidBody2D test objects spawn above the 8×14 character.
- **Current**: Rapier2D is the sole runtime rigid-body backend and one main-thread bridge owns its space step, direct state, batch transforms, and query flush.
- **Current**: Wall pixels are merged into static Rapier rectangle shapes; cast-shape CCD is enabled for the three test bodies and restitution is zero.
- **Current**: hard terrain is extracted in 64×64 chunks and scanned under a 32-chunk/750-microsecond per-frame soft budget.
- **Planned**: generalized shape rasterization, particle fallback, rotation-aware torque, selective substeps, and high-count callback removal.

## Search anchors

rigid body passes through sand, rigid body occupancy mask, Rapier cellular coupling, pixel pressure force, body pushes liquid, deterministic overlap resolution, physics substeps

## Finding from source inspection

Before this checkpoint the proposed remove/simulate/restore sequence was not an
implementation. The runnable Godot project contained `CyberCellWorld` and a
custom sampled character, but no RigidBody2D nodes, rigid-body pixels, occupancy
mask, Box2D dependency, or two-way bridge. The coupling concern therefore
applied: adding transformed bodies without a separate mask would have made them
invisible to material movement.

The project now uses ordinary Godot `RigidBody2D` nodes backed solely by the
vendored Rapier2D PhysicsServer2D implementation. `CyberRapierPhysicsBridge`
owns the space RID and direct server calls; the packed worker boundary remains
backend-neutral.

## Current prototype sequence

The current implementation is asynchronous and non-destructive:

1. The Godot physics callback consumes each published cellular sample at most once and applies its bounded correction/impulse directly to Rapier body RIDs.
2. The bridge manually advances the inactive Rapier space by one configured fixed delta.
3. Active transforms are fetched in a batch, callbacks are flushed once, and velocity/sleep state is read from PhysicsServer2D rather than cached scene properties.
4. Body ID, sample ID, transform, size, velocity, angular velocity, and mass are copied into packed value data.
5. The worker latches the newest complete sample; no Node, RID, or direct physics state crosses the thread boundary.
6. `CyberNativeCellWorld` clears/wakes the prior endpoint field and rasterizes a capped start-to-end sweep for overlap displacement and reaction.
7. It discards that temporary sweep and rasterizes only the newest endpoint into `rigid_body_occupancy`, avoiding a phantom obstacle or sweep-wide pressure.
8. Emissions, sampled-character collision, and falling-sand rules run against material occupancy plus the endpoint rigid-body mask.
9. Movement attempts and endpoint boundary samples accumulate capped impulses; Wall overlap produces no cellular correction because Rapier owns that contact.
10. The worker publishes packed results and contact/displaced/unresolved counts in an immutable snapshot for the next eligible physics callback.

Pausing still refreshes the obstacle mask, but skips overlap mutation, pressure,
and impulse generation. Rendering composites current rigid-body transforms in
the shader; body colour is not written to the authoritative material texture.

## Collision and displacement rules

| Situation | Current response | Status and limitation |
|---|---|---|
| A cell attempts to enter a body cell | Reject movement, count contact, and add a small density-scaled impulse in the attempted direction | **Current**, approximate impact |
| Movable material overlaps the endpoint body | Search outward from the nearest body face, then symmetrically along its tangent, for an empty non-body cell within eight cells | **Current**, deterministic bounded ejection |
| A moving body sweeps across material between accepted samples | Rasterize up to 24 intermediate rectangles across at most 32 pixels; eject in travel direction and return reaction impulse | **Current**, bounded translation-oriented approximation |
| No ejection target exists | Retain the material, report unresolved overlap, and apply a reaction impulse to the body | **Current**, no particle fallback |
| A body overlaps or borders Wall | Let the merged static Rapier collider, zero restitution, friction, and cast-shape CCD resolve the contact | **Current**; cellular correction/support is intentionally disabled to prevent bounce and delayed tunnelling |
| Movable material borders a body | Add a density-scaled opposing impulse; side pressure tends to cancel while material below contributes support/buoyancy | **Current**, rudimentary pressure rather than a pressure field |
| Two bodies overlap in the mask | First valid input body owns the mask cell | **Current** mask rule; body/body collision remains PhysicsServer2D's responsibility |
| Painting targets a body | Reject non-empty emission into its occupied cells | **Current** |

Cell ejection transfers the existing compact cell state, including Water mass. It
does not create a particle. A later particle system may receive material only
through an explicit bounded fallback; unresolved pixels are currently retained
and observable instead of silently deleted.

## Ordering and approximation contract

This proof aims for stable gameplay, not exact continuum mechanics or bit-exact
agreement between the independent solvers.

- Body input order and cell traversal order define overlap ownership and ejection order.
- Coupling sample IDs prevent one worker sample from applying twice.
- Fluid/particle forces are capped to avoid explosive feedback; hard-surface positional correction is not duplicated.
- The worker may skip intermediate body transforms when it is overloaded.
- A conservative capped sweep reconciles translation between the two samples; the persistent collision mask still represents only the newest transform.
- Motion beyond 32 pixels is treated as a teleport, and rotational-only sweep response is approximate.

The Current sweep samples at approximately one-cell spacing, capped at 24
intermediate intervals and disabled for transforms more than 32 pixels apart.
Those are prototype constants, not a serialized production policy. Selective
Rapier CCD or bounded physics substeps should be introduced only when a fast,
thin-body fixture demonstrates a remaining gameplay failure.

Manual Rapier stepping and active-transform batching are **Current**. The
asynchronous worker still means a cellular result may be delayed under load;
the bridge consumes the newest unapplied sample instead of stalling rendering
or applying the same sample twice.

## Hard-terrain rebuild granularity

The 1024² material lab now exposes 256 independent 64×64 hard-surface packets.
The previous 128×128 partition exposed only 64 packets and allowed the time
budget to be checked only after a much larger indivisible extraction/merge job.
The smaller unit reduces the worst atomic area to one quarter. Unchanged chunks
are cheap to scan, so the per-frame count rose from 8 to 32 to retain an
approximately eight-frame full snapshot traversal while the 750-microsecond
time budget still stops changed work between chunks. This bounds granularity;
it does not prove a particular target-machine peak until the same fragmented
hard-surface scene is reprofiled on Windows.

## Native coupling contract

The Current rectangle bridge and future generalized bridge retain these properties:

- separate entity occupancy from material identity;
- publish only packed immutable body samples and results across the Godot/native boundary;
- let local cellular jobs read a stable start-of-stage mask without per-cell locks;
- gather job-local impact, displacement, pressure, and optional torque observations;
- reduce observations in stable body-ID order;
- reconcile moved-body overlaps before exposing the next completed state;
- report ejection overflow, stale samples, and unresolved overlap;
- keep body visuals and PhysicsServer objects on allowed Godot threads.

Generalized fracture bodies, pixel membership fields, contour generation, and
particle conversion remain **Planned** and are not implied by this rectangular
proof. The custom sampled character reads the body mask, but it is not itself a
PhysicsServer collider and does not push a body; the three test rectangles are
spawned horizontally clear of it.

## Related decisions

- [ADR-003: Godot bridge and immutable snapshots](../decisions/ADR-003-godot-bridge-and-immutable-snapshots.md)
- [ADR-007: Separate rigid-body occupancy coupling](../decisions/ADR-007-rigid-body-cellular-coupling.md)
- [ADR-009: Rapier2D rigid-body backend](../decisions/ADR-009-rapier-2d-rigid-body-backend.md)
- [Simulation tick and threading](simulation-tick-and-threading.md)
