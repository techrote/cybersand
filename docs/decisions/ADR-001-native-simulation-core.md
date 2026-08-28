---
title: ADR-001 — Native SimulationCore
status: Approved design
scope: Authority placement, Godot dependency boundary, standalone validation, and migration from the split prototype
keywords: [ADR, SimulationCore, native C++, authority, Godot bridge, dual simulation]
related-documents: [../architecture/overview.md, ../architecture/module-boundaries.md, ADR-003-godot-bridge-and-immutable-snapshots.md]
last-reviewed: 2026-08-26
implementation-state: Approved direction; current Godot and native simulations remain separate and no SimulationCore symbol exists.
---

# ADR-001: Native SimulationCore

## At a glance

- Decision: authoritative pixel-physics state and rules belong in native C++ SimulationCore.
- **Current**: CyberCellWorld powers the Godot proof while cybersand::World is a separate native kernel.
- **Approved design**: SimulationCore has no Godot API dependency.
- **Approved design**: Godot interacts through RenderBridge and GameplayBridge only.
- Benefit: deterministic native tests and multicore scheduling do not depend on scene/runtime objects.
- Cost: bridge contracts and a deliberate migration are required.
- Non-goal: define final C++ signatures in this ADR.

## Search anchors

why native simulation, authoritative cell owner, can GDScript own physics, Godot-free core, dual world migration

## Status

**Approved design**.

No repository class or namespace named SimulationCore exists. The decision is not implemented.

## Context

The current repository has two independent simulation authorities:

- CyberCellWorld in godot/scripts/cell_world.gd owns the runnable finite Godot cell world.
- cybersand::World in native source owns sparse chunks for standalone tests, benchmarks, and the C API.

CyberSimulationWorker moves GDScript simulation off the main thread but keeps material work serial and dependent on the Godot runtime. Scaling across cores while preserving replay, storage, and ownership requires a platform-neutral authority.

## Decision

- Create a native C++ SimulationCore as the only production authority for committed simulation state and semantics.
- Keep Godot scene-tree, rendering, audio, gameplay objects, and physics objects outside SimulationCore.
- Let WorldStorage own physical storage under SimulationCore authority.
- Let MaterialRules supply immutable descriptors and compact rule behavior.
- Let SimulationScheduler coordinate tick timing and workers without owning material policy.
- Connect Godot only through RenderBridge and GameplayBridge contracts.
- Keep native reference tests executable without Godot.

Exact interfaces and migration checkpoints remain to be specified in implementation plans.

## Consequences

### Positive

- Native single-thread and multithread implementations can share one authority.
- Deterministic replay and conservation tests can run without Godot.
- Godot rendering and gameplay can evolve without exposing simulation storage.
- Future tools, servers, or alternate presentations can reuse the backend.
- Material and storage design can remain data-oriented.

### Negative

- The current GDScript proof cannot simply remain the production authority.
- Commands, results, snapshots, identifiers, and lifetimes need explicit contracts.
- Debug tooling must cross a bridge instead of reading arrays directly.
- Migration must temporarily compare old and new behavior without allowing two production authorities.

### Risks

- Renaming cybersand::World without separating its mixed responsibilities would create a false module boundary.
- Keeping both CyberCellWorld and native state live after migration could cause divergence.
- Godot types leaking into native headers would defeat independent validation.

## Alternatives considered

### Keep GDScript authoritative

**Explicitly rejected** for the production backend. It is useful as a current visual/reference prototype but does not meet multicore, ownership, or native validation goals.

### Keep two synchronized authorities

**Explicitly rejected**. Synchronization creates hidden ownership, duplicate rules, and ambiguity after divergence.

### Make Godot scenes or physics bodies authoritative per cell

**Explicitly rejected**. Per-cell scene/physics objects do not meet density or scale requirements.

### Use the existing native World unchanged as SimulationCore

**Explicitly rejected** without refactoring. World currently combines storage, rules, scheduling, dirty extraction, and RGBA conversion.

## Reversal/migration path

The decision is reversible before Godot production migration by retaining the current GDScript proof as the last working checkpoint.

Migration should:

1. preserve the existing prototype unchanged;
2. define native authority and test contracts;
3. create a deterministic single-thread reference;
4. connect a read-only comparison/view path;
5. switch Godot to bridge consumption only after parity criteria pass;
6. remove duplicate production simulation authority.

Reversing after save formats depend on native state would require an explicit data migration ADR.

## Validation

- SimulationCore native tests run without Godot.
- Godot cannot access mutable authoritative memory.
- identical replay inputs yield identical native hashes;
- commands are applied only at tick boundaries;
- no Godot API call occurs in SimulationCore or native workers;
- current GDScript proof remains a rollback point until the bridge checkpoint passes.

## Related decisions

- [ADR-002](ADR-002-double-buffered-tile-jobs.md)
- [ADR-003](ADR-003-godot-bridge-and-immutable-snapshots.md)
- [ADR-005](ADR-005-water-model.md)
