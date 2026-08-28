---
title: Cyber Sand Engine documentation index
status: Current
scope: Entry point, evidence policy, status vocabulary, reading routes, and documentation map
keywords: [documentation index, RAG, current, approved design, architecture, retrieval]
related-documents: [architecture/overview.md, reference/retrieval-index.md, reference/status-and-roadmap.md]
last-reviewed: 2026-08-28
implementation-state: This index describes m11: the m9 visual baseline plus the render-patch lifetime fix, corrected fallback regressions, and reproducible portable checkpoint tooling.
---

# Cyber Sand Engine documentation

## At a glance

- Purpose: provide a concise, retrieval-friendly source of truth for humans and agentic developers.
- Current guarantee: every claim labelled **Current** is tied to inspected repository evidence.
- Design guarantee: unimplemented requirements are never described as completed features.
- Non-goal: this set does not replace source inspection before changing implementation code.
- Start with [Architecture overview](architecture/overview.md) for system boundaries.
- Use [Retrieval index](reference/retrieval-index.md) to answer a specific development question quickly.
- Use [Status and roadmap](reference/status-and-roadmap.md) before planning implementation work.
- Rapier2D v0.35.2 is vendored, selected, and manually stepped; use the migration runbook before changing the version, stepping owner, or export bundle.

## Search anchors

documentation map, status vocabulary, Current evidence, Approved design, Planned, Deferred / experimental, Explicitly rejected, Ambiguous, safe change workflow

## Evidence policy

Source code is authoritative for **Current** status. Existing milestone documents are useful historical context, but they cannot override contradictory source behavior.

The repository inspected for this baseline is:

- Build identity: **m11-audit-remediation-render-handoff-water-native-repro-2026-08-28**
- Preferred Godot simulation: godot/native_extension/cyber_native_cell_world.cpp plus native/src/world.cpp
- Platform fallback simulation: godot/scripts/cell_world.gd
- Current Godot worker: godot/scripts/simulation_worker.gd
- Current native simulation: native/include/cybersand/world.hpp and native/src/world.cpp
- Current native material definitions: native/include/cybersand/material.hpp
- Current native snapshot publication: native/include/cybersand/render_snapshot.hpp and native/src/render_snapshot.cpp
- Current native tests: native/tests/test_world.cpp
- Current benchmark harness: native/bench/benchmark.cpp

Bundled Linux and Windows x86_64 builds advance native World through the
GDExtension. The fallback remains behaviorally useful for unsupported
architectures but is not the preferred authority or the source for native
performance claims.

## Status vocabulary

| Label | Meaning |
|---|---|
| **Current** | Directly evidenced in inspected source code or project configuration. |
| **Approved design** | Accepted architecture or behavior that is not yet fully implemented. |
| **Planned** | Intended work whose design is not fully approved or specified. |
| **Deferred / experimental** | Deliberately postponed or allowed only as a later benchmarked experiment. |
| **Explicitly rejected** | Must not be introduced without a new architecture decision. |
| **Ambiguous** | Evidence is incomplete, contradictory, or split across prototype implementations. |

Status applies to individual statements and table rows, not merely to the containing document.

## Critical constraints

- **Current**, Linux and Windows x86_64: native C++ owns authoritative cellular simulation through `CyberNativeCellWorld`; the GDScript solver is an unsupported-architecture fallback.
- **Current**: Godot remains the presentation, input, and Rapier integration layer.
- **Current** native behavior: World coordinates fixed ticks through a persistent worker pool.
- **Current** native hierarchy: 128×128 chunks, 32×32 activity blocks, and 64×64 scheduling cores.
- **Current**: the Noita-style four-phase in-place backend is the default and same-phase write domains are geometry-tested.
- **Planned**: active-only buffered jobs remain a demonstrated-need fallback and field-specific option.
- **Current**: phase, scan, random, and job-effect merge order is deterministic across tested worker counts.
- **Current** native layer: RenderSnapshotExchange publishes bounded immutable dirty leases; Godot consumes copied dirty RG8 patches and reconstructs a persistent CPU image, while true GPU subregion submission remains **Planned**.
- **Current**: bounded explosion commands commit at tick boundaries and convert selected static Wall into granular Stone.
- **Current**, partial capacity behavior: native regions/capacities are configurable, preallocatable, and observable; persistence/live resize are **Planned**.
- **Current**: native Water uses conserved 8-bit pairwise mass and stable render-only dither; buffered flux remains **Planned**.
- **Current** Godot/native source: a separate transient rectangle body mask and packed result bridge support three RigidBody2D test objects; generalized collider rasterization is **Planned**.
- **Current** Godot runtime: Rapier2D owns rigid-body physics; main-thread manual stepping and bounded swept pixel reconciliation are active.
- **Current** fallback only: the GDScript solver retains adaptive block cadence; the preferred native runtime advances selected active jobs every tick.
- **Deferred / experimental**: GPU compute may later host suitable non-authoritative fields.
- **Explicitly rejected**: per-cell mutexes, material-specific threads, full-world double buffering, hidden hot-path allocation, and current GPU terrain authority.

## Documentation map

- [1024² material lab](MATERIAL_LAB.md): runtime controls, executable families,
  expected interactions, and useful manual pairings.

### Architecture

- [Overview](architecture/overview.md): module ownership, current versus target, and top-level data flow.
- [Principles and non-goals](architecture/principles-and-non-goals.md): hard constraints and rejected shortcuts.
- [Module boundaries](architecture/module-boundaries.md): responsibilities and permitted dependencies.
- [Data ownership and lifetimes](architecture/data-ownership-and-lifetimes.md): every important buffer and queue.
- [Simulation tick and threading](architecture/simulation-tick-and-threading.md): fixed-tick stage sequence and worker restrictions.
- [Chunk, tile, and buffer model](architecture/chunk-tile-and-buffer-model.md): independent storage, activity, scheduling, and buffer geometry.
- [Determinism and boundary transfers](architecture/determinism-and-boundary-transfers.md): stable scheduling, staging, merge, and replay.
- [Rendering and gameplay bridges](architecture/rendering-and-gameplay-bridges.md): immutable snapshots and tick-boundary commands.
- [Item-authored material programs](architecture/item-authored-material-programs.md): planned visual rule graphs, bounded compilation, stable material identity, and equipment/spawner emission.
- [Rigid-body and cellular coupling](architecture/rigid-body-and-cellular-coupling.md): separate obstacle masks, two-way impulses, and overlap reconciliation.

### Systems

- [Activity, dirty regions, and waking](systems/activity-dirty-regions-and-waking.md)
- [Materials and rule kernels](systems/materials-and-rule-kernels.md)
- [Themed construction materials](systems/themed-construction-materials.md)
- [Material appearance and rendering](systems/material-appearance-and-rendering.md)
- [Water design](systems/water-design.md)
- [Smoke, heat, and pressure roadmap](systems/smoke-heat-pressure-roadmap.md)
- [World storage and interest region](systems/world-storage-and-interest-region.md)

### Operations

- [Configuration and capacity budgets](operations/configuration-and-capacity-budgets.md)
- [Profiling, observability, and performance](operations/profiling-observability-and-performance.md)
- [Testing, validation, and replay](operations/testing-validation-and-replay.md)
- [Troubleshooting](operations/troubleshooting.md)
- [Rapier2D migration runbook](operations/rapier-2d-migration-runbook.md)

### Decisions

- [ADR-001: Native SimulationCore](decisions/ADR-001-native-simulation-core.md)
- [ADR-002: Benchmark-gated cellular scheduling backends](decisions/ADR-002-double-buffered-tile-jobs.md)
- [ADR-003: Godot bridge and immutable snapshots](decisions/ADR-003-godot-bridge-and-immutable-snapshots.md)
- [ADR-004: Interest region and safe reconfiguration](decisions/ADR-004-interest-region-and-reconfiguration.md)
- [ADR-005: Water model](decisions/ADR-005-water-model.md)
- [ADR-006: GPU compute deferral](decisions/ADR-006-gpu-compute-deferral.md)
- [ADR-007: Separate rigid-body occupancy coupling](decisions/ADR-007-rigid-body-cellular-coupling.md)
- [ADR-008: Bounded approximate fidelity under load](decisions/ADR-008-bounded-approximate-fidelity.md)
- [ADR-009: Rapier2D rigid-body backend](decisions/ADR-009-rapier-2d-rigid-body-backend.md)

### Reference

- [Glossary](reference/glossary.md)
- [Invariants](reference/invariants.md)
- [Interfaces and message contracts](reference/interfaces-and-message-contracts.md)
- [Configuration reference](reference/configuration-reference.md)
- [Status and roadmap](reference/status-and-roadmap.md)
- [Retrieval index](reference/retrieval-index.md)

### Research and import ledgers

- [Sandspiel performance study and material port ledger](research/sandspiel-performance-and-material-port.md): audited source, portable optimizations, complete imported interaction inventory, rejected coupling, and staged activation status.

## Safe change workflow

1. Find the relevant question in the retrieval index.
2. Confirm whether the affected behavior is **Current** or only approved/planned.
3. Inspect the cited source path before editing.
4. Check module ownership and invariants.
5. Identify the required tests and metrics.
6. Make one reversible checkpoint without unrelated refactoring.
7. Update status and ADRs only after implementation evidence changes.

## Known documentation limits

- The versioned C ABI is implemented; final extracted C++ modules and Godot GDExtension classes are not.
- No serialized configuration schema or exact capacity key names have been approved.
- No canonical transfer sort tuple has been approved.
- Snapshot pressure currently returns non-blocking explicit outcomes and retains dirty state; production capacities and Godot upload policy remain unapproved.
- Generalized liquid-reaction mass accounting and serialization are not implemented.
- The 2026-08-27 hosted benchmarks are checkpoint observations, not a frozen target-hardware gate.

## Related decisions

All ADRs in the [decisions directory](decisions/) define the approved architectural direction. They must be read as design decisions, not implementation claims.
