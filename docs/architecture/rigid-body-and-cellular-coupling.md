---
title: Rigid-body and cellular coupling
document-kind: contract
canonical-for: [rigid-body-cellular-coupling]
status: Current
scope: Rectangle occupancy, bounded displacement/impulses and Rapier hard contact; generalized physics and exact replay remain absent
keywords: [Rapier2D, occupancy mask, sweep, CCD, terrain budget, impulse, unresolved overlap]
related-documents: [simulation-tick-and-threading.md, data-ownership-and-lifetimes.md, ../reference/interfaces-and-message-contracts.md, ../operations/rapier-2d-migration-runbook.md, ../audits/2026-09-24-rem002-issue11-integration-forensics.md, ../audits/2026-09-25-pchar001-player-representation-experiment.md]
last-reviewed: 2026-09-25
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
4. Accumulate endpoint boundary pressure, cellular movement contacts and the
   bounded granular-bearing contribution from exposed downward body cells. Bearing
   queries the existing granular support policy against **stored** material, not
   the transient body proxy. Publish bounded observations keyed by body/sample
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
| Endpoint overlap | Search outward from nearest face and along its tangent, at most eight cells; the bounded half-cell path may not cross hard terrain or another body's transient mask |
| Swept-only overlap | Prefer ejection in body-travel direction; rotational response remains approximate |
| No valid destination | Retain the complete stored cell payload and report unresolved overlap plus reaction; no particle fallback or silent deletion |
| Granular bearing | Exposed downward body cells query the version-1 granular support predicate against stored material; response is recomputed each accepted sample, capped at 20 impulse units and uses at most 0.5-cell low-speed correction |
| Native impulse | Contact/displacement/density pressure terms retain the ordinary cap; the bounded bearing term shares the cellular coupling owner rather than becoming a second collider/solver |
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

For the **Planned** investigation of barrel sinking into powders, half-depth
embedding and reversible soliding, see the [characterisation plan](../operations/physics-characterisation-plan.md).
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

## PCHAR-001 switchable barrel-player experiment

**Current experiment:** the ordinary sandbox can select either the historical
sampled character or a barrel-style player through a fresh-reset-only boundary.
The barrel player is the existing body-0 rectangle and uses the same
`CyberRapierPhysicsBridge` sampling, transient body mask, native cellular
reaction results, static hard-terrain colliders and Rapier ownership as the red
reference barrel. There is no in-place sampled↔body ownership conversion.

Barrel locomotion adds only a bounded main-thread horizontal central impulse.
The controller reads live Rapier velocity **after** cellular results are applied,
adds at most 3 impulse units per fixed step toward a 42 px/s horizontal target,
does nothing when there is no horizontal input, and never assigns linear velocity
or changes the vertical component. Existing cellular displacement/contact/bearing
results therefore remain observable rather than being overwritten by a character
velocity controller.

PCHAR-001 does not change generic body↔cellular semantics, result ABI, bearing,
ejection, sample-age policy, Water behavior or hard-terrain ownership. Any such
change still belongs to #83 / REM-004. The switch is an evidence-generating
player-representation experiment under parent #132, not a declaration that the
current rectangle envelope is production-complete.

## What did the measured barrel baseline establish?

**Historical 2026-09-09 scope:** the [issue #9 report](../audits/2026-09-09-physics-characterisation.md)
separated stored-cell displacement, boundary pressure, transient contact and
Rapier hard-floor collision. On that source, packed Sand did not stop an ordinary
rectangle before the deep hard floor; masked stored grains could produce
Wall-proxy-derived contact feedback; and endpoint-only ejection could move Water
across a one-cell hard floor. Those observations remain valid historical evidence
for the identified source. They are no longer Current behavior after REM-002.

## What does REM-002 establish on Current source?

**Current bounded baseline, 2026-09-24:** [REM-002 evidence](../audits/2026-09-24-rem002-issue11-integration-forensics.md)
reconciles the never-integrated historical #11 repair into current main without
claiming broad body/granular gameplay acceptance.

Current semantics are:

- a stored cell beneath a transient body mask remains material authority and does
  not execute its normal cellular kernel as the body Wall proxy;
- ejection endpoints and their bounded path reject hard terrain and foreign body
  masks; if no legal target exists, the complete payload stays at the source and
  unresolved overlap is reported;
- an ordinary rectangle may receive a bounded cellular-owned granular-bearing
  contribution from current support-capable packed material;
- bearing is recomputed from current cells every accepted sample and disappears
  after excavation/support loss; there is no support cache or granular Rapier
  collider;
- hard terrain remains Rapier/static-terrain contact, and liquids do not become
  granular bearing;
- the existing 11-float input / 9-float result ABI and sample-age policy remain
  unchanged.

On frozen source `df54e927...`, the focused real-Rapier Linux regression measured
one-height Sand peak/final depth **3.748/0.000 cells**, four-height
**6.652/1.472 cells**, and explicit excavation released the body into substantial
downward travel. The exact runtime/platform qualifications and retained hashes are
in the dated REM-002 audit.

This is still a bounded ordinary rectangle/load baseline. General shapes, high
energy/thin beds, crowding, sustained publication delay, calibrated force/torque,
fracture and broad body↔granular gameplay acceptance remain outside this contract
and are owned by REM-004 / #83 where applicable.

## Sampled player support is a separate owner

**Current:** the [granular/player policy](../systems/granular-interaction-policy.md)
still owns sampled-character material-aware packing queries, directional collision
and bounded enclosure recovery. REM-002 reuses the same support predicate for a
separate bounded body-coupling observation against stored material; it does not
make the sampled character a Rapier collider and does not add a second material
owner.
