---
title: Rigid-body and cellular coupling
status: Current
scope: Rapier2D manual stepping, separate cellular occupancy, desktop asynchronous and Web synchronous coupling, bounded sweep, and remaining generalized-physics work
keywords: [RigidBody2D, Rapier2D, occupancy mask, two-way coupling, pressure impulse, overlap ejection, physics substep]
related-documents: [simulation-tick-and-threading.md, data-ownership-and-lifetimes.md, rendering-and-gameplay-bridges.md]
last-reviewed: 2026-09-08
implementation-state: Rapier2D v0.35.2 is manually stepped on the main thread; hard terrain is partitioned into 64×64 rebuild units, while CyberNativeCellWorld consumes copied body state, reconciles a bounded swept path, retains an endpoint obstacle field, and returns bounded fluid/particle impulses.
---

# Rigid-body and cellular coupling

Evidence scope (2026-09-08): **Current** below describes inspected source in the
reconstructed local snapshot, not a verified Git HEAD or an all-platform test pass.
See the [documentation audit](../audits/2026-09-08-documentation-audit.md) for
source identity and dated validation; [M11 audit records](../audits/m11/README.md)
retain historical scope. **Approved design** means Approved direction; Planned,
Deferred, and Rejected statements do not claim implementation.

## At a glance

- Purpose: keep independent rigid bodies visible to cellular physics and provide bounded two-way interaction.
- **Current**: rigid bodies are never removed from or restored into the material array because they are not stored there.
- **Current**: the native cellular bridge reconciles a bounded swept rectangle between accepted samples, then rasterizes the newest transform into a separate transient occupancy field.
- **Current**: Sand, liquids, Smoke, painting, and the sampled character treat occupied mask cells as solid.
- **Current**: cell impacts, density-derived boundary pressure, and displaced pixels produce bounded impulses for the corresponding RigidBody2D.
- **Current**: endpoint overlaps eject outward; swept-only overlaps push in body-travel direction, in deterministic native body-ID and cell traversal order; the fallback uses input order.
- **Current**: three red 8×14 RigidBody2D test objects spawn above the 8×14 character.
- **Current**: Rapier2D is the sole runtime rigid-body backend and one main-thread bridge owns its space step, direct state, batch transforms, and query flush.
- **Current**: Hard-surface pixels (including Wall and construction materials) are merged into static Rapier rectangle shapes; cast-shape CCD is enabled for the three test bodies and restitution is zero.
- **Current**: hard-terrain collider consumption is partitioned into 64×64 chunks with a 32-chunk/750-microsecond per-frame soft budget; full native packet extraction is outside that budget.
- **Planned**: generalized shape rasterization, particle fallback, rotation-aware torque, selective substeps, and high-count callback removal.

## Search anchors

rigid body passes through sand, rigid body occupancy mask, Rapier cellular coupling, pixel pressure force, body pushes liquid, deterministic overlap resolution, physics substeps

## Finding from source inspection

Historical pre-coupling rationale (retained from the earlier design account,
not a description of the 2026-09-08 source): remove/simulate/restore was not an
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

Local Web extension (2026-09-08): the Web controller uses the same Rapier bridge
on the Godot main thread, synchronously applying the previous cellular result,
stepping Rapier, packing body state, and ticking the native cellular world.
It waits for pending hard-terrain collider chunks to drain before either solver
advances. Menu, focus loss, and pause stop both solvers. Physics Pit owns the
three bodies; switching demos destroys its static colliders and freezes bodies.
The threaded profile parallelizes cellular jobs; it does not move Rapier calls
onto those workers. See the [runbook](../operations/rapier-2d-migration-runbook.md).

The desktop controller uses the following asynchronous, non-destructive sequence:

1. The Godot physics callback consumes each published cellular sample at most once and applies its bounded correction/impulse directly to Rapier body RIDs.
2. The bridge manually advances the inactive Rapier space by one configured fixed delta.
3. Active transforms are fetched in a batch, callbacks are flushed once, and velocity/sleep state is read from PhysicsServer2D rather than cached scene properties.
4. Body ID, sample ID, transform, size, velocity, angular velocity, and mass are copied into packed value data.
5. The worker latches the newest complete sample; no Node, RID, or direct physics state crosses the thread boundary.
6. `CyberNativeCellWorld` clears/wakes the prior endpoint field and rasterizes a capped start-to-end sweep for overlap displacement and reaction.
7. It discards that temporary sweep and rasterizes only the newest endpoint into `rigid_body_occupancy`, avoiding a phantom obstacle or sweep-wide pressure.
8. Emissions, sampled-character collision, and falling-sand rules run against material occupancy plus the endpoint rigid-body mask.
9. Movement attempts and endpoint boundary samples accumulate capped impulses; Hard-surface overlap produces no cellular correction because Rapier owns that contact.
10. The worker publishes packed results and contact/displaced/unresolved counts in an immutable snapshot for the next eligible physics callback.

Desktop pausing still refreshes the obstacle mask, but skips overlap mutation, pressure,
and impulse generation. Rendering composites current rigid-body transforms in
the shader; body colour is not written to the authoritative material texture.

## Collision and displacement rules

| Situation | Current response | Status and limitation |
|---|---|---|
| A cell attempts to enter a body cell | Reject movement, count contact, and add a small density-scaled impulse in the attempted direction | **Current**, approximate impact |
| Movable material overlaps the endpoint body | Search outward from the nearest body face, then symmetrically along its tangent, for an empty non-body cell within eight cells | **Current**, deterministic bounded ejection |
| A moving body sweeps across material between accepted samples | Rasterize at most 24 intervals (25 endpoint-inclusive samples) for translations up to 32 pixels; eject in travel direction and return reaction impulse | **Current**, bounded translation-oriented approximation |
| No ejection target exists | Retain the material, report unresolved overlap, and apply a reaction impulse to the body | **Current**, no particle fallback |
| A body overlaps or borders a hard-surface material | Let the merged static Rapier collider, zero restitution, friction, and cast-shape CCD resolve the contact | **Current**; cellular correction/support is intentionally disabled to prevent bounce and delayed tunnelling |
| Movable material borders a body | Add a density-scaled opposing impulse; side pressure tends to cancel while material below contributes support/buoyancy | **Current**, rudimentary pressure rather than a pressure field |
| Two bodies overlap in the mask | Native projection processes ascending body IDs; the first mask writer wins. Duplicate ID records retain the first parsed record. The GDScript fallback projects input order. | **Current** source-specific rules; body/body collision remains Rapier's responsibility |
| Painting targets a body | Reject non-empty emission into its occupied cells | **Current** |

Cell ejection transfers the existing compact cell state, including Water mass. It
does not create a particle. A later particle system may receive material only
through an explicit bounded fallback; unresolved pixels are currently retained
and observable instead of silently deleted.

## Ordering and approximation contract

This proof aims for stable gameplay, not exact continuum mechanics or bit-exact
agreement between the independent solvers.

- Native ascending body-ID order and cell traversal define mask/ejection order. The fallback uses input order; arbitrary reordered inputs are not claimed equivalent.
- Coupling sample IDs prevent one worker sample from applying twice.
- Fluid/particle forces are capped to avoid explosive feedback; hard-surface positional correction is not duplicated.
- The desktop worker may skip intermediate body transforms under load; the Web owner consumes one synchronous sample per accepted physics callback.
- A conservative capped sweep reconciles translation between the two samples; the persistent collision mask still represents only the newest transform.
- Motion beyond 32 pixels is treated as a teleport, and rotational-only sweep response is approximate.

The Current sweep samples at approximately one-cell spacing, capped at 24
intermediate intervals and disabled for transforms more than 32 pixels apart.
Those are prototype constants, not a serialized production policy. Cast-shape CCD is already enabled on the three test bodies in `main.tscn`.
A selective CCD/substep controller is Planned and requires fast/thin-body
fixtures; enabling that future policy is not the same as enabling today's
per-body CCD setting.

Manual Rapier stepping and active-transform batching are **Current**. The desktop
asynchronous worker still means a cellular result may be delayed under load;
the bridge consumes the newest unapplied sample instead of stalling rendering
or applying the same sample twice.

## Hard-terrain rebuild granularity

The 1024² material lab now exposes 256 independent 64×64 hard-surface packets.
The previous 128×128 partition exposed only 64 packets and allowed the time
budget to be checked only after a much larger indivisible extraction/merge job.
The smaller unit reduces a collider-consumption chunk's atomic area to one quarter. Unchanged chunks
are cheap to scan, so the per-frame count rose from 8 to 32 to retain an
approximately eight-frame full snapshot traversal while the 750-microsecond
time budget still stops collider work between chunks. The native
`get_hard_surface_chunk_rectangles()` call extracts a complete packet before
that consumer budget; extraction occurs on the desktop pacing owner or Web
main thread. A single changed chunk can also exceed the soft time budget.
This bounds consumer granularity;
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

## Source and validation anchors

- [Native parse/projection/reconciliation](../../godot/native_extension/cyber_native_cell_world.cpp), `prepare_rigid_body_coupling`, `parse_body_states`, `rasterize_body_sweep`.
- [Packed layout](../../godot/scripts/rigid_body_coupling.gd), [Rapier owner](../../godot/scripts/rapier_physics_bridge.gd), [body configuration](../../godot/main.tscn).
- [Desktop owner](../../godot/scripts/simulation_worker.gd), [Web owner](../../godot/scripts/web_demo_controller.gd), and [fallback](../../godot/scripts/cell_world.gd).
- [Rapier runbook](../operations/rapier-2d-migration-runbook.md) scopes dated native/Chromium fixtures; coupled exact replay and general shape/torque behavior remain unverified or Planned.

## Related decisions

- [ADR-003: Godot bridge and immutable snapshots](../decisions/ADR-003-godot-bridge-and-immutable-snapshots.md)
- [ADR-007: Separate rigid-body occupancy coupling](../decisions/ADR-007-rigid-body-cellular-coupling.md)
- [ADR-009: Rapier2D rigid-body backend](../decisions/ADR-009-rapier-2d-rigid-body-backend.md)
- [Simulation tick and threading](simulation-tick-and-threading.md)
