---
title: ADR-009 - Rapier2D rigid-body backend
status: Current
scope: Production 2D rigid-body backend selection, version lock, integration stages, stepping ownership, performance path, and rollback boundary
keywords: [ADR, Rapier2D, Godot Rapier Physics, manual stepping, PhysicsServer2D, rigid body]
related-documents: [../architecture/rigid-body-and-cellular-coupling.md, ../operations/rapier-2d-migration-runbook.md, ADR-007-rigid-body-cellular-coupling.md]
last-reviewed: 2026-08-27
implementation-state: Rapier2D v0.35.2 is vendored and selected under Godot 4.7; the main scene uses explicit stepping, direct state, active-transform batching, and asynchronous packed cellular coupling, with focused Linux x86_64 fixtures passing.
---

# ADR-009: Rapier2D rigid-body backend

## At a glance

- Decision: Rapier2D becomes the sole runtime rigid-body backend.
- Decision: pin Godot 4.7.x and Godot Rapier Physics tag v0.35.2 for the first migration checkpoint.
- **Current**: ordinary RigidBody2D/RectangleShape2D compatibility is retained while the project owns explicit stepping.
- Decision: preserve the separate cellular occupancy and packed impulse/result bridge.
- Decision: read authoritative coupling state from PhysicsServer/Rapier rather than relying on cached scene-node state.
- Decision: cellular liquids remain authoritative; Rapier fluids are not substituted during migration.
- **Current**: the official 2D single add-on, dependency lock, activation helper, preflight, drop-in fixture, and migration runbook exist.
- **Current**: direct server state and bounded swept cellular reconciliation protect the coupling boundary from stale node caches and skipped transforms.
- **Planned**: export-platform validation, generalized shapes, optional substeps/CCD policy, torque, and high-count callback removal.

## Search anchors

Rapier selection, replace Godot Physics 2D, Rapier2D version, manual physics step, batch body transforms, physics serialization

## Status

**Current**. The backend selection and first manual-step coupling checkpoint are implemented.

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
runnable sandbox then takes explicit step ownership:

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

## Consequences

Benefits:

- one explicit main-thread Rapier timeline replaces implicit auto-step ordering;
- direct body state, contact impulses, manual stepping, and batch transforms are available;
- physics state can be serialized independently of scene presentation;
- ordinary Godot body nodes remain usable during the low-risk first stage.

Costs and constraints:

- Godot 4.7.x and 148 MiB of multi-platform vendored add-on content become project/deployment dependencies;
- Rapier physics determinism does not make SceneTree callbacks deterministic;
- collision layers/masks must be designed symmetrically because Rapier does not support asymmetric collision filtering;
- solver, CCD, and length-unit changes require fixture evidence rather than speculative tuning;
- addon binaries and notices must be packaged for every supported export target.

## Alternatives

### Continue using Godot Physics 2D

**Explicitly rejected** for the production runtime. The pre-migration checkpoint
remains a recovery artifact, not a selectable production backend.

### Embed Rapier into the future native simulation immediately

**Deferred / experimental**. A single Rust GDExtension can forward Rapier's
initialization stages, but combining that work with the first backend migration
would obscure coupling and packaging failures.

### Replace cellular Water with Rapier/Salva particles

**Explicitly rejected** for this migration. The material engine's multi-material
occupancy, reactions, and large-world activity model remain authoritative.

## Reversal or migration

Rollback restores the complete pre-Rapier source checkpoint. It does not add a
per-frame backend toggle. A later native/Rust consolidation may preserve the
same packed body-sample/result contract while changing where Rapier is hosted.

## Validation

- verify the exact addon tag, asset hash, registered server, and selected engine;
- run focused automatic and manual RigidBody2D fixtures plus a 180-frame full-scene smoke test;
- compare body/body stacks, solid impact, liquid buoyancy, overlap ejection, reset, and sleep behavior;
- measure Rapier step, query flush, transform extraction, mask rasterization, reconciliation, and snapshot age separately;
- verify each intended export architecture; only Linux x86_64 has run here;
- verify bounded CCD/substeps with fast thin-body fixtures when introduced;
- save/load Rapier state together with matching cellular and command state before claiming replay support.

## Related decisions

- [ADR-007: Separate rigid-body occupancy coupling](ADR-007-rigid-body-cellular-coupling.md)
- [ADR-008: Bounded approximate fidelity](ADR-008-bounded-approximate-fidelity.md)
- [Rapier2D migration runbook](../operations/rapier-2d-migration-runbook.md)
