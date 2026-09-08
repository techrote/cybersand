---
title: Architecture overview
document-kind: contract
canonical-for: [architecture-entry-point]
status: Current
scope: Current execution paths and authority map; routes to the contracts that govern changes
keywords: [architecture, native authority, Godot, Rapier, desktop, Web]
related-documents: [module-boundaries.md, data-ownership-and-lifetimes.md, simulation-tick-and-threading.md, ../reference/status-and-roadmap.md]
last-reviewed: 2026-09-08
---

# Architecture overview

## Which simulation actually runs?

**Current:** `cybersand::World` owns cellular state and rules. The Godot
`CyberNativeCellWorld` adapter owns one World. Desktop selects that adapter when
the extension class is available and otherwise selects the older
`CyberCellWorld` GDScript solver. Web requires the native adapter and reports
load failure instead of falling back. The two solvers are alternatives; their
Water behavior and performance are not equivalent.

Source: [World](../../native/include/cybersand/world.hpp),
[desktop `_create_world`](../../godot/scripts/simulation_worker.gd), and
[Web controller](../../godot/scripts/web_demo_controller.gd).
Source identity and platform execution evidence have separate homes in the
[checkpoint record](../operations/source-checkpoint-and-recovery.md) and
[validation ledger](../reference/validation-evidence.md). A Current source
description is not an all-platform acceptance claim.

## Who owns each kind of truth?

| State | Current authority | Boundary |
|---|---|---|
| Materials, compact state, optional temperature, activity | Native World, or the selected desktop fallback | Godot receives copies and bulk query results |
| External rigid-body transforms and velocity | Rapier2D through Godot PhysicsServer2D | Packed samples become a separate cellular obstacle mask |
| Sampled character | Desktop pacing owner; Web main-thread controller | Reads cellular occupancy; it is not a Rapier body |
| Images, textures, UI, input, shaders | Godot main thread | Presentation never mutates cellular storage |

Rapier is the sole current rigid-body backend, behind
`CyberRapierPhysicsBridge`. Native cellular workers never call Godot or Rapier.
The Godot pacing owner may call its exclusively owned adapter/value APIs; it
does not own live scene-tree objects. Exact resource lifetimes belong in
[data ownership](data-ownership-and-lifetimes.md).

## How does data move on desktop and Web?

Desktop rendering reads immutable published snapshots while a dedicated Godot
Thread advances the character and cells. Rapier steps on the main thread and
exchanges copied body samples/results with that asynchronous owner. A cellular
result can therefore lag behind body motion.

Web runs Rapier, body masking, cells and the character sequentially in
`_physics_process`. Compatibility Web has one cellular worker; threaded Web
can dispatch the same native pool while the main thread waits. Separate render
publication cadence does not make Web simulation asynchronous. Character order,
terrain gating and failure handling differ between controllers; use the
[tick contract](simulation-tick-and-threading.md) before changing either.

Both native paths use sparse storage and bounded phased jobs. Dirty RG8
material/condition copies update a persistent CPU image, followed by a full
GPU texture update. Render-only shaders derive colour, motion and lighting.
The [bridge contract](rendering-and-gameplay-bridges.md) explains payloads and
publication failures; the [coupling contract](rigid-body-and-cellular-coupling.md)
defines rectangle displacement and Rapier hard contact.

## Are the named production modules already separate classes?

**Approved:** SimulationCore, SimulationScheduler, WorldStorage, TileJob,
MaterialRules, RenderBridge and GameplayBridge name intended responsibilities.
**Current:** World still combines much of the core, storage and scheduler.
Material descriptors and native snapshot exchange already have separate APIs;
a generalized bounded gameplay queue does not exist. The
[module boundary map](module-boundaries.md) distinguishes actual symbols from
the proposed extraction. Renaming World alone would not complete it.

## Which contract should foundational work load next?

- Ownership or concurrency: [resource lifetimes](data-ownership-and-lifetimes.md),
  [step order](simulation-tick-and-threading.md), [geometry](chunk-tile-and-buffer-model.md).
- Reproducibility: [native ordering and hashes](determinism-and-boundary-transfers.md),
  [level saves versus exact replay](../reference/level-saves-and-replay.md).
- Physics: [rigid-body coupling](rigid-body-and-cellular-coupling.md),
  [Water](../systems/water-design.md), [invariants](../reference/invariants.md).
- Scope and decisions: [principles](principles-and-non-goals.md),
  [roadmap](../reference/status-and-roadmap.md), [ADRs](../decisions/).

**Planned:** generalized shapes/torque, complete replay, safe live capacity
reconfiguration and typed production command/result queues.
**Deferred:** general world streaming, fully asynchronous Web ownership and
GPU field experiments. **Rejected:** shared mutable rendering reads,
per-cell locks, full-world double buffering as the normal model and current
GPU terrain authority. These limits are decisions, not absent documentation.
