---
title: ADR-001 — Native SimulationCore
document-kind: decision
canonical-for: [decision-native-cellular-authority]
status: Current
scope: Accepted native authority decision, current integration and incomplete module extraction
keywords: [ADR, native authority, SimulationCore, Godot-free, fallback]
related-documents: [../architecture/module-boundaries.md, ../architecture/overview.md, ADR-003-godot-bridge-and-immutable-snapshots.md]
last-reviewed: 2026-09-08
---

# ADR-001: Native SimulationCore

## Decision and implementation status

**Approved and Current:** authoritative cellular state and rules belong in native
C++. `cybersand::World` supplies that authority through `CyberNativeCellWorld`.
Desktop selects the GDScript fallback when the native class is absent; Web
requires native support. The alternatives are not synchronized authorities and
do not promise identical Water behavior.

**Approved, incomplete:** separate SimulationCore, storage, scheduler and bridge
responsibilities. World still combines several of them. A class called
SimulationCore is not required to make native authority real, and renaming World
would not complete the [module boundaries](../architecture/module-boundaries.md).

Source: [World](../../native/include/cybersand/world.hpp),
[desktop selector](../../godot/scripts/simulation_worker.gd),
[Web owner](../../godot/scripts/web_demo_controller.gd).
Actual platform evidence is separate in the
[validation ledger](../reference/validation-evidence.md).

## Why place authority here?

The engine needs dense cell-scale rules, shared spatial scheduling and native
fixtures independent of a scene runtime. Godot is valuable for presentation,
input and adapters, but its object lifetimes must not determine worker storage
or update order. A reusable native core also supports standalone tools,
benchmarks and alternative presentations.

The chosen boundary keeps Godot/Rapier types outside core headers. Immutable
render publication and data-only gameplay commands/results cross adapters.
The exact resource contract is in
[data ownership](../architecture/data-ownership-and-lifetimes.md).

## Consequences and alternatives

Native authority permits one/multiworker fixtures without Godot and lets
presentation evolve independently. It costs explicit command, query, snapshot,
identity and lifetime design; debug tools cannot borrow live mutable arrays.
The retained fallback adds maintenance and requires honest semantic differences.

**Rejected:** GDScript as the production cellular authority, two synchronized
cellular truths, and per-cell scene/PhysicsServer objects. Keeping today's World
is Current; treating its mixed responsibilities as finished production module
separation is Rejected as a claim of completion.

## What would justify revision?

A replacement must preserve single authority, bounded ownership, native
validation and compatible data semantics. Current runnable fallback paths are
the desktop script selector and native serial/one-worker phased variants; they
are not interchangeable exact-state restores. Historical checkpoint names alone
do not establish recovery availability. Use the
[source checkpoint](../operations/source-checkpoint-and-recovery.md).

Keep extraction and bridge changes focused and validate them through the
canonical contracts. Complete replay is still Planned; native hash equality
has the [documented coverage limits](../architecture/determinism-and-boundary-transfers.md#replay-state-coverage).
