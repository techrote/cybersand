---
title: Rigid-body and cellular coupling
document-kind: contract
canonical-for: [rigid-body-cellular-coupling]
status: Current
scope: Rectangle occupancy, bounded displacement/ejection, granular bearing and Rapier hard contact; generalized physics and exact replay remain absent
keywords: [Rapier2D, occupancy mask, sweep, CCD, terrain budget, impulse, unresolved overlap, granular bearing]
related-documents: [simulation-tick-and-threading.md, data-ownership-and-lifetimes.md, ../reference/interfaces-and-message-contracts.md, ../operations/rapier-2d-migration-runbook.md]
last-reviewed: 2026-09-13
---

# Rigid-body and cellular coupling

## When a crate moves through sand, are its pixels erased and restored?

**Current:** native World owns cellular materials; Rapier2D owns independent
rigid bodies. Bodies are never erased from/restored into the material array.
`CyberNativeCellWorld` projects copied rectangles into a separate transient
body-ID field. Sand, liquids, Smoke, painting and the sampled character read
that endpoint field as occupied. The three 8×14 demo bodies are drawn through
shader transforms; body colour is not stored in the cell texture. Moved-body
overlap is resolved by bounded material ejection; if no destination fits, the
material stays in place and unresolved overlap is counted. The body receives
bounded reaction observations instead of silently deleting trapped sand.

[CyberRapierPhysicsBridge](../../godot/scripts/rapier_physics_bridge.gd) owns live
Nodes/RIDs and manual stepping on the main thread. The native adapter receives
values only. Desktop samples asynchronously; Web sequences both solvers and
waits behind pending terrain colliders. Exact controller order belongs in
[threading](simulation-tick-and-threading.md), not a universal coupling schedule.

## How is a moved rectangle reconciled?

Source: [native `prepare_rigid_body_coupling`, `parse_body_states`, `rasterize_body_sweep`, `reconcile_swept_overlaps`](../../godot/native_extension/cyber_native_cell_world.cpp).

1. Clear/wake the previous obstacle field and clear observations. Parse at most
   16 complete records with body IDs 1–16; retain the first duplicate ID.
2. Traverse ascending body IDs and rasterize a temporary sweep from prior to
   current accepted transform. The first mask writer wins where bodies overlap.
3. When overlap response is enabled, reconcile movable material against the
   temporary sweep. Then clear it and rebuild only endpoint occupancy.
4. Accumulate endpoint boundary pressure, cellular movement contacts and current
   local granular bearing. Publish bounded observations keyed by body/sample
   identity.

The GDScript fallback projects input order; arbitrary sample reordering is not
claimed equivalent. Body/body collision remains Rapier's responsibility.

## What are the current numerical bounds and units?

Body centres/sizes/corrections use cell/pixel coordinates; rotation is radians,
linear velocity is pixels per second, angular velocity is radians per second.
Mass and returned central impulses use the Godot physics adapter's quantities;
there is no approved production SI calibration or generalized force/torque
unit contract. Packed fields are documented in
[interfaces](../reference/interfaces-and-message-contracts.md).

| Operation | Current bound or response |
|---|---|
| Translation sweep | More than 32 pixels between samples is treated as a teleport: endpoint only |
| Sweep sampling | Approximately one-cell spacing, capped at 24 intervals/25 samples; interpolates centre, shortest rotation and size |
| Endpoint overlap | Search outward from nearest face and along its tangent, at most eight cells |
| Ejection reachability | Half-cell samples may cross neither stored hard terrain nor another body's mask; the source body's mask is traversable |
| Swept-only overlap | Prefer ejection in body-travel direction; rotational response remains approximate |
| No valid destination | Retain the cell and report unresolved overlap plus reaction; no particle fallback or silent deletion |
| Native impulse | Contact/displacement/density pressure terms; combined magnitude capped at 3 per body/tick |
| Granular bearing | Exposed downward raster cells; #10 packing query over stored material; `92/60` gravity impulse/mass/tick, `0.18` yield response, `2.0` capacity/sample, cap `20` |
| Settled correction | At velocity at most `4 px/s`, undo at most `0.5` cell and `0.99` of the current sampled downward travel; never a world-height clamp |
| Stale results | Reject age above eight body samples; suppress correction above one; scale impulse by `1/(1+0.25*age)` |

Ejection transfers the compact cell state including Water mass. Pure closed
Water conservation does not establish general body/cell energy conservation.
Duplicate sample serials are not applied twice. Sample wrap and age constants
are in [Rapier `apply_cellular_results`](../../godot/scripts/rapier_physics_bridge.gd).

## Who resolves hard terrain and thin floors?

**Current:** hard-surface pixels, including construction materials, are merged
into static Rapier rectangle shapes. Cellular hard-contact correction/support
is disabled to avoid double-solving delayed contacts. The demo bodies already
have cast-shape CCD enabled and zero restitution; see
[body configuration](../../godot/main.tscn). A future adaptive CCD/substep
controller is a separate **Planned** feature.

Hard-terrain extraction creates 64×64 packets: 256 units for the 1024² demo.
The consumer checks a 32-chunk/750-microsecond soft rebuild budget between units.
The preceding native `get_hard_surface_chunk_rectangles` extraction is outside
that budget, and one indivisible changed chunk may exceed it. This is bounded
consumer granularity, not an end-to-end frame-time guarantee. Source:
[native extraction](../../godot/native_extension/cyber_native_cell_world.cpp),
[Rapier `process_hard_surface_collider_budget`](../../godot/scripts/rapier_physics_bridge.gd).

## What does the fixture prove, and what remains open?

For the accepted ordinary barrel envelope and separate **Planned** reversible
soliding work, see the [current evidence](../audits/2026-09-13-issue-11-repair.md)
and [characterisation plan](../operations/physics-characterisation-plan.md).
The owner now calls the demo rectangles barrels; this does not change their
Current rectangle geometry or internal scene identifiers.

The dated 600-tick rectangle fixture permits two pixels and observed about 1.32 pixels of
transient floor penetration; it is not a zero-penetration proof. Its exact
platforms, artifact identity, inputs and tolerance are in the
[Rapier runbook](../operations/rapier-2d-migration-runbook.md) and
[validation ledger](../reference/validation-evidence.md). Level/body restoration
is not complete trajectory replay; see
[level saves](../reference/level-saves-and-replay.md).

**Planned:** generalized shapes/contours, torque feedback, fracture membership,
particle conversion, serialized sweep/CCD policy and wider numerical acceptance.
The sampled character reads the body mask but is not a PhysicsServer collider
and does not push a body. Rectangle sweep coverage and capped pressure are a
bounded gameplay approximation, not exact continuum mechanics or a guarantee
for every fast/thin/rotating shape. Rationale lives in
[ADR-007](../decisions/ADR-007-rigid-body-cellular-coupling.md) and
[ADR-009](../decisions/ADR-009-rapier-2d-rigid-body-backend.md).

## What did the measured barrel baseline establish?

**Historical measured baseline, 2026-09-09:** the [issue #9 report](../audits/2026-09-09-physics-characterisation.md)
separates stored-cell displacement, boundary pressure, transient contact and
Rapier hard-floor collision. Packed Sand does not stop an ordinary barrel before
the deep hard floor. Contact feedback from retained masked grains can point
downward: dispatch uses stored material, while kernel lookup sees the Wall proxy.
That source path remains retained characterization. Current source now defers a
masked authoritative cell to overlap reconciliation and never substitutes the
body's Wall proxy for the stored source material.

`record_impulse` clamps after each displacement/boundary addition; the final
combined result is capped again after pixel contact. Opposing terms therefore
cannot be assessed from a single final cap count. Diagnostic construction options
and the unchanged nine-float result are described by the
[measurement runbook](../operations/physics-characterisation.md). Raw impulses
are not calibrated force or buoyancy. Disabling contact experimentally does not
meet the half-depth impact target and does not implement static bearing.

The historical Water control exposed endpoint-only ejection across a hard floor.
Current source additionally checks the bounded path against stored hard terrain
and other body masks. Failure retains the complete source cell and reports an
unresolved overlap; native and fallback regressions cover both barrier classes.

## Sampled player support is a separate owner

**Current:** the [granular policy](../systems/granular-interaction-policy.md)
defines shared material capability and local packing/stability. The sampled
character owns its collision response. Rectangle bearing separately consumes
the same current stored-material predicate and returns a central cellular
impulse/correction to main-thread Rapier. Neither path creates a Rapier granular
collider or a second material owner.

## What is the current issue #11 disposition?

**Current, repaired 2026-09-13:** the [focused repair evidence](../audits/2026-09-13-issue-11-repair.md)
supersedes the negative disposition in the dated September 12 reconciliation.
Three-seed 30-second P4 runs peak at `3.75` cells for one-height and `6.65`
for four-height drops, with worst final-ten-second descent `0.03` cell. The
120-second finalist remains bounded. P5 excavation removes all sampled bearing
immediately and the body falls more than 41 cells by tick 661 before later
re-bearing on real collapsed material.

The accepted scope is rectangular bodies, deep supported material, mass
`0.5..2`, the tested sizes/orientations/powders, and current or one-sample-old
coupling without sustained publication gaps. Eight-height impact, two-or-more
sample delay, thin beds, crowded/general shapes and general torque/CCD/fracture
remain explicit limits. The narrow #12 statement is: #11's support prerequisite
is satisfied within the documented ordinary rectangle/load envelope.
