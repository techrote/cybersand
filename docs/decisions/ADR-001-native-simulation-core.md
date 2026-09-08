---
title: ADR-001 — Native SimulationCore
status: Current
scope: Authority placement, Godot dependency boundary, standalone validation, and migration from the split prototype
keywords: [ADR, SimulationCore, native C++, authority, Godot bridge, dual simulation]
related-documents: [../architecture/overview.md, ../architecture/module-boundaries.md, ADR-003-godot-bridge-and-immutable-snapshots.md]
last-reviewed: 2026-09-08
implementation-state: Native cybersand::World is the desktop native and required Web cellular backend through CyberNativeCellWorld; the standalone SimulationCore class extraction and generalized GameplayBridge remain Approved design.
---

# ADR-001: Native SimulationCore

Evidence scope (2026-09-08): **Current** below describes inspected source in the
reconstructed local snapshot, not a verified Git HEAD or an all-platform test pass.
See the [documentation audit](../audits/2026-09-08-documentation-audit.md) for
source identity and dated validation; [M11 audit records](../audits/m11/README.md)
retain historical scope. **Approved design** means Approved direction; Planned,
Deferred, and Rejected statements do not claim implementation.

## At a glance

- Decision: authoritative pixel-physics state and rules belong in native C++ SimulationCore.
- **Current**: CyberNativeCellWorld makes World authoritative where loaded; desktop may fall back to CyberCellWorld, while Web fails if native support is absent.
- **Approved design**: SimulationCore has no Godot API dependency.
- **Approved design**: Godot interacts through RenderBridge and GameplayBridge only.
- Benefit: deterministic native tests and multicore scheduling do not depend on scene/runtime objects.
- Cost: bridge contracts and a deliberate migration are required.
- Non-goal: define final C++ signatures in this ADR.

## Search anchors

why native simulation, authoritative cell owner, can GDScript own physics, Godot-free core, dual world migration

## Status

**Current**, with the intended responsibilities still combined in
`cybersand::World`. A separately named SimulationCore class and generalized
GameplayBridge remain **Approved design** rather than prerequisites for native
authority.

## Context

The repository retains two implementations but selects only one authority per
run. Desktop CyberSimulationWorker prefers CyberNativeCellWorld and advances
native World; CyberCellWorld is its fallback when the extension class is absent.
Both Web profiles require native World and synchronously own calls on the main
thread, with no script fallback. See [tick/threading](../architecture/simulation-tick-and-threading.md). Native World remains Godot-free and is also exercised by
standalone tests, benchmarks, and the C API.

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

- The GDScript fallback cannot provide native performance or bit-equivalent Water behavior.
- Commands, results, snapshots, identifiers, and lifetimes need explicit contracts.
- Debug tooling must cross a bridge instead of reading arrays directly.
- Migration must temporarily compare old and new behavior without allowing two production authorities.

### Risks

- Renaming cybersand::World without separating its mixed responsibilities would create a false module boundary.
- Keeping both CyberCellWorld and native state live in one run would cause divergence; the Current worker selects exactly one backend.
- Godot types leaking into native headers would defeat independent validation.

## Alternatives considered

### Keep GDScript authoritative

**Explicitly rejected** for the production backend. It is useful as a current visual/reference prototype but does not meet multicore, ownership, or native validation goals.

### Keep two synchronized authorities

**Explicitly rejected**. Synchronization creates hidden ownership, duplicate rules, and ambiguity after divergence.

### Make Godot scenes or physics bodies authoritative per cell

**Explicitly rejected**. Per-cell scene/physics objects do not meet density or scale requirements.

### Use the existing native World unchanged as SimulationCore

**Current** as the implemented authority; **Rejected** as a claim that production
module separation is complete. World currently combines storage, rules,
scheduling, dirty extraction and RGBA conversion. Extraction remains Approved
direction and is not a prerequisite for continuing the existing native core.

## Reversal/migration path

The decision remains reversible through the retained GDScript compatibility
fallback and the audited pre-migration checkpoints.

Migration should:

1. preserve the compatibility fallback without running it beside native state;
2. keep native authority and test contracts explicit;
3. retain deterministic single-thread and phased reference paths;
4. expand only bounded value-data bridge contracts;
5. validate new platforms before selecting native authority there;
6. remove the fallback only after all supported platforms have equivalent native coverage.

Reversing after save formats depend on native state would require an explicit data migration ADR.

## Validation

The list below is the required contract, not an all-platform pass claim. Source:
[World](../../native/include/cybersand/world.hpp),
[native fixtures](../../native/tests/test_world.cpp),
[desktop selector](../../godot/scripts/simulation_worker.gd), and
[Web owner](../../godot/scripts/web_demo_controller.gd). Exact fixture hashes
are limited by [hash coverage](../architecture/determinism-and-boundary-transfers.md#replay-state-coverage).

- SimulationCore native tests run without Godot.
- Godot cannot access mutable authoritative memory.
- identical replay inputs yield identical native hashes;
- commands are applied only at tick boundaries;
- no Godot API call occurs in SimulationCore or native workers;
- the backend selector never advances native and fallback authorities together.

## Related decisions

- [ADR-002](ADR-002-double-buffered-tile-jobs.md)
- [ADR-003](ADR-003-godot-bridge-and-immutable-snapshots.md)
- [ADR-005](ADR-005-water-model.md)
