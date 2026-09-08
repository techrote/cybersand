---
title: ADR-009 - Rapier2D rigid-body backend
status: Current
scope: Approved Rapier2D backend selection, current desktop/Web adapters, dated validation and unfinished production/replay work
keywords: [ADR, Rapier2D, Godot Rapier Physics, manual stepping, PhysicsServer2D, rigid body]
related-documents: [../architecture/rigid-body-and-cellular-coupling.md, ../operations/rapier-2d-migration-runbook.md, ADR-007-rigid-body-cellular-coupling.md]
last-reviewed: 2026-09-08
implementation-state: Rapier2D v0.35.2 is selected under exact Godot 4.7. Desktop cellular coupling is asynchronous; Web outer ticks are synchronous. Historical Linux and dated Windows/Chromium fixture passes do not establish generalized coupling or exact replay.
---

# ADR-009: Rapier2D rigid-body backend

## At a glance

- Decision: Rapier2D becomes the sole runtime rigid-body backend.
- Decision: retain exact Godot `4.7.stable.official.5b4e0cb0f` and Godot Rapier Physics tag v0.35.2; the add-on's broader 4.7.x requirement does not authorize version drift.
- **Current**: ordinary RigidBody2D/RectangleShape2D compatibility is retained while the project owns explicit stepping.
- Decision: preserve the separate cellular occupancy and packed impulse/result bridge.
- Decision: read authoritative coupling state from PhysicsServer/Rapier rather than relying on cached scene-node state.
- Decision: cellular liquids remain authoritative; Rapier fluids are not substituted during migration.
- **Current**: the official 2D single add-on, dependency lock, activation helper, preflight, drop-in fixture, and migration runbook exist.
- **Current**: direct server state and bounded swept cellular reconciliation protect the coupling boundary from stale node caches and skipped transforms.
- **Current**, bounded: the bridge enables shape-cast CCD and a three-rectangle thin-floor fixture exists; its accepted penetration bound is not zero penetration.
- **Planned**: remaining export-platform validation, generalized shapes, expanded substeps/CCD policy, torque feedback, and high-count callback removal.

## Search anchors

Rapier selection, replace Godot Physics 2D, Rapier2D version, manual physics step, batch body transforms, physics serialization

## Status

**Current**. The backend selection and first manual-step coupling checkpoint are implemented.
The source is a local reconstructed snapshot plus edits, not the historical M11
commit. See [the current audit](../audits/2026-09-08-documentation-audit.md) for
identity, dependency hashes and fresh Windows checks. **Approved** describes
the backend/ownership direction; complete production coupling remains partial.

## Context

The rectangle proof previously used ordinary RigidBody2D nodes through Godot's
default PhysicsServer2D and applied delayed cellular results through scene-node
properties. The project now selects Godot Rapier Physics and treats the physics
server as authoritative. Performance remains workload-dependent and must be
measured with this project's coupling traffic.

## Decision

Rapier2D is the only intended runtime backend. The official v0.35.2 2D single
build is vendored with its release asset hash and upstream notices. The focused
drop-in fixture retains ordinary RigidBody2D nodes with automatic stepping; the
runnable desktop sandbox then takes explicit step ownership:

1. consume the newest unapplied cellular result on the main thread;
2. apply bounded correction and impulse directly through PhysicsServer2D RIDs;
3. call `RapierPhysicsServer2D.space_step` once at the configured fixed delta;
4. fetch active body RIDs/transforms in a batch from Rapier;
5. flush queries once and read velocity/sleep state from PhysicsServer2D;
6. publish a copied packed body sample to the asynchronous cellular worker;
7. reconcile a bounded transform sweep against pixels, then retain only the endpoint body mask;
8. advance cells against that mask and publish packed observations in the immutable worker snapshot.

`CyberRapierPhysicsBridge` disables automatic space stepping during its lifetime.
Scene callbacks never become worker-thread inputs. The worker is deliberately
not blocked waiting for Rapier; a result may therefore lag by one or more body
samples under load, and sample serials prevent replaying it twice. Rapier's
state-sync callback may be disabled later for high-count bodies, with transforms
rendered through the direct-server batch path.

The [Web controller](../../godot/scripts/web_demo_controller.gd) instead applies
the preceding cellular result, steps Rapier, samples bodies, prepares coupling,
then completes the native cellular tick synchronously in `_physics_process`.
Compatibility forces one cellular worker; threaded Web uses the native pool
internally while the main thread waits. Both keep Rapier calls on the main
thread through [rapier_physics_bridge.gd](../../godot/scripts/rapier_physics_bridge.gd).
Fully asynchronous Web ownership is **Deferred**.

## Consequences

Benefits:

- one explicit main-thread Rapier timeline replaces implicit auto-step ordering;
- direct body state, contact impulses, manual stepping, and batch transforms are available;
- selected body transforms, velocities and sleep state can be saved independently of scene presentation; full Rapier replay-state persistence is **Planned**;
- ordinary Godot body nodes remain usable during the low-risk first stage.

Costs and constraints:

- exact Godot 4.7 and matching pinned add-on binaries/notices are project/deployment dependencies; remaining local LFS pointers are not usable runtime binaries;
- Rapier physics determinism does not make SceneTree callbacks deterministic;
- collision layers/masks must follow the adapter's tested symmetric setup; the local fixtures do not establish the full pinned backend's asymmetric-filter behavior;
- solver, CCD, and length-unit changes require fixture evidence rather than speculative tuning;
- addon binaries and notices must be packaged for every supported export target.

## Alternatives

### Continue using Godot Physics 2D

**Rejected** for the production runtime. Historical guidance proposed the
pre-migration checkpoint as recovery material; its availability is not verified
in this source directory, which has no Git history.

### Embed Rapier into the future native simulation immediately

**Deferred**. Native/Rust hosting needs a separately designed and validated
integration; it is not the current GDScript/GDExtension adapter boundary.

### Replace cellular Water with Rapier/Salva particles

**Rejected** for this migration. The material engine's multi-material
occupancy, reactions, and large-world activity model remain authoritative.

## Reversal or migration

The intended rollback restores a verified complete pre-Rapier checkpoint;
establish that artifact's availability before depending on it. It does not add a
per-frame backend toggle. A later native/Rust consolidation may preserve the
same packed body-sample/result contract while changing where Rapier is hosted.

## Validation

Retained local Web acceptance, 2026-09-08: the official v0.35.2 threaded/no-thread WASM
binaries run with the pinned Godot 4.7 templates without recompiling Rapier.
The shared 600-tick fixture passes on Windows and Chromium with one/six cellular
workers. It exercises the thin floor, material displacement, pause/menu ownership,
reset, demo lifecycle, exact cellular save payload, and body restoration within
1e-5 float tolerance. This is not an exact coupled replay checkpoint. See the
[runbook](../operations/rapier-2d-migration-runbook.md) for provenance and bounds.
The fresh documentation audit reran Windows native/Godot tests with the retained
DLL and checked existing Web checksums; it did not rebuild or rerun the browser.
The following are ongoing validation gates, not a claim all have passed:

- verify the exact addon tag, asset hash, registered server, and selected engine;
- run focused automatic and manual RigidBody2D fixtures plus a 180-frame full-scene smoke test;
- compare body/body stacks, solid impact, liquid buoyancy, overlap ejection, reset, and sleep behavior;
- measure Rapier step, query flush, transform extraction, mask rasterization, reconciliation, and snapshot age separately;
- verify each intended export architecture; historical Linux and dated Windows/Chromium results have separate scopes, and other targets remain unverified;
- verify bounded CCD/substeps with fast thin-body fixtures when introduced;
- save/load Rapier state together with matching cellular and command state before claiming replay support.

## Related decisions

- [ADR-007: Separate rigid-body occupancy coupling](ADR-007-rigid-body-cellular-coupling.md)
- [ADR-008: Bounded approximate fidelity](ADR-008-bounded-approximate-fidelity.md)
- [Rapier2D migration runbook](../operations/rapier-2d-migration-runbook.md)
