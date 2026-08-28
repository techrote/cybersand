---
title: Rapier2D migration runbook
status: Current
scope: Pinned dependency acquisition, safe activation, staged coupling migration, diagnostics, acceptance gates, packaging, and rollback
keywords: [Rapier2D, migration, install addon, activate physics server, preflight, manual stepping]
related-documents: [../decisions/ADR-009-rapier-2d-rigid-body-backend.md, ../architecture/rigid-body-and-cellular-coupling.md, testing-validation-and-replay.md]
last-reviewed: 2026-08-27
implementation-state: Official Rapier2D v0.35.2 binaries are vendored and selected; drop-in and manual-step fixtures pass on Godot 4.7 Linux x86_64, while export-platform validation and high-count callback removal remain pending.
---

# Rapier2D migration runbook

## At a glance

- Purpose: switch the rigid-body backend without conflating dependency, behavior, coupling, and optimization changes.
- **Current**: `godot/third_party/rapier2d.lock.json` pins Godot 4.7.x, Rapier v0.35.2, the official asset size, and SHA-256.
- **Current**: the official 2D single add-on is vendored and `project.godot` selects `Rapier2D` at 60 physics ticks per second.
- **Current**: dependency, drop-in RigidBody2D, full-scene, and manual-step fixtures pass on Linux x86_64.
- **Current**: one main-thread bridge owns manual stepping, direct server state, batch active transforms, and callback flushing.
- **Current**: moving-body samples use bounded swept overlap reconciliation before the endpoint obstacle mask is published to cells.
- **Planned**: package and validate every intended export architecture.

## Search anchors

install Rapier2D, enable Rapier Physics, Rapier migration order, activate Rapier2D safely, Rapier preflight, manual stepping workflow

## Prepared inputs

| Input | Path | Purpose |
|---|---|---|
| Dependency lock | `godot/third_party/rapier2d.lock.json` | Version, source, expected addon/server, release metadata, and verified checksum |
| Vendored add-on | `godot/addons/godot-rapier2d` | Official 2D binaries, GDExtension descriptor, license, and notices |
| Guarded activation | `godot/tools/activate_rapier_2d.gd` | Select Rapier2D only after registration and version checks |
| Backend preflight | `godot/tests/test_rapier_backend_preflight.gd` | Confirm registration, project selection, and Godot version after restart |
| Drop-in fixture | `godot/tests/test_rapier_drop_in.gd` | Confirm an ordinary RigidBody2D/RectangleShape2D advances under automatic Rapier stepping |
| Manual-step fixture | `godot/tests/test_rapier_manual_step.gd` | Confirm explicit stepping, packed samples, and pause ownership |
| Behavioral fixture | `godot/main.tscn` | Three 8×14 bodies plus cellular mask/force observations |
| Coupling contract | `godot/scripts/rigid_body_coupling.gd` | Backend-neutral packed body samples and results |
| Step owner | `godot/scripts/rapier_physics_bridge.gd` | Main-thread RID ownership, force application, stepping, batch reads, and flush |

## Stage 1: acquire and activate — complete on Linux x86_64

1. Install the pinned Godot 4.7.x editor/export templates.
2. Download the official Rapier2D release asset for tag v0.35.2 from the upstream release page.
3. Record the asset filename and SHA-256 in the lock manifest; retain the MIT license/notice.
4. Extract only the Rapier2D `addons` content into `godot/addons` and verify all intended platform libraries exist.
5. Open the project once so Godot imports the GDExtension without selecting it.
6. Run `godot --headless --path godot --script res://tools/activate_rapier_2d.gd`.
7. Restart Godot, then run `res://tests/test_rapier_backend_preflight.gd`.

No Rapier-specific solver setting is changed in this stage. Rapier's default 2D
length unit of 100 matches Godot's conventional 100 pixels per metre and the
project's current pixel-space scale.

## Stage 2: drop-in baseline — focused fixture complete

Retain RigidBody2D nodes, automatic stepping, callbacks, current shapes, and the
packed cellular bridge. Exercise body/body collision, falling onto cellular
Wall, displacement through Water/Sand/Smoke/Paste/Slush, reset, sleep, and pause.
Record physics-step time, query-flush time where available, worker snapshot age,
contacts, displaced cells, and unresolved overlaps. Fix only backend
compatibility defects in this stage.

## Stage 3: explicit coupling ownership — current

Introduce one main-thread Rapier bridge that owns the space RID, body RID table,
fixed delta, and coupling stage order. Disable automatic space stepping, apply
cell-derived impulses before `space_step`, fetch active transforms directly,
perform swept-mask reconciliation, and call `space_flush_queries` once. Keep all
cellular mutation on its existing worker owner through packed commands/results.

The current main thread performs one Rapier step per Godot physics callback and
consumes the newest unapplied cellular result. The cellular worker remains
asynchronous, so its response may be one or more samples old under overload;
sample serials prevent duplicate force application. A bounded swept rectangle
mask covers skipped transforms for displacement, then is discarded in favour
of the endpoint mask before cell movement and pressure sampling.

Add Rapier substeps only when a motion/shape fixture demonstrates tunnelling.
Enable CCD per fast body before raising any global substep bound.

## Stage 4: scale path

Active RIDs and transforms are already read in a batch and the shader renders
the bridge's authoritative transform cache. The three low-count test nodes keep
their state-sync callbacks. Disabling callbacks and moving high-count body
classes to direct-server rendering remains **Planned** and must be measured.

## Acceptance and rollback

Linux activation and manual-step ownership are accepted for this source
checkpoint. Export architectures are not yet accepted merely because their
binaries are present. Rollback restores the pre-Rapier checkpoint as a whole;
the production project does not carry a runtime Godot-physics fallback.

Focused local validation:

```sh
godot --headless --path godot --script res://tests/test_rapier_backend_preflight.gd
godot --headless --path godot --script res://tests/test_rapier_drop_in.gd
godot --headless --path godot --script res://tests/test_rapier_manual_step.gd
godot --headless --path godot --quit-after 180
```

## Related decisions

- [ADR-009: Rapier2D backend](../decisions/ADR-009-rapier-2d-rigid-body-backend.md)
- [Rigid-body and cellular coupling](../architecture/rigid-body-and-cellular-coupling.md)
- [Testing and replay](testing-validation-and-replay.md)
