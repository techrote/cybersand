---
title: Architectural principles and non-goals
document-kind: design
canonical-for: [architectural-constraints-and-rejected-shortcuts]
status: Approved design
scope: Accepted architectural constraints, explicit current exceptions, deferred scope and rejected approaches
keywords: [native authority, fixed tick, bounded work, approximation, rejected, GPU authority]
related-documents: [module-boundaries.md, data-ownership-and-lifetimes.md, ../reference/invariants.md, ../reference/status-and-roadmap.md]
last-reviewed: 2026-09-08
---

# Architectural principles and non-goals

## Which constraints govern foundational work?

**Approved:** native C++ remains production cellular authority; Godot owns
presentation, input and adapters; the rigid-body backend remains replaceable.
The core must run without Godot. Fixed simulation quanta, explicit owners,
bounded work/capacity and traceable evidence take priority over incidental
prototype structure. [ADR-001](../decisions/ADR-001-native-simulation-core.md)
and [module boundaries](module-boundaries.md) explain the authority decision.

No native pool worker may call Godot APIs. The desktop Godot pacing Thread may
call its exclusively owned adapter/value methods, but may not access live
scene-tree/Rapier objects. Rendering consumes immutable snapshots and never
locks or borrows mutable cellular state. Resource enforcement belongs in
[ownership](data-ownership-and-lifetimes.md), not an assumed universal
thread-safety property of GDExtension.

Worker timing must not decide mutation ownership or conflict order. Exact
native fixture comparison is **Current** for declared inputs; complete replay
and a selectable strict runtime policy remain **Planned**. A passing cellular
hash does not establish Rapier trajectory equivalence or save continuation.
See [hash coverage](determinism-and-boundary-transfers.md) and
[level saves](../reference/level-saves-and-replay.md).

## What approximation is acceptable?

**Approved:** protect interactive frame pacing through explicit bounded
sampling/deferral of secondary or distant work, while preserving local
occupancy, closed-boundary conservation and accepted authoritative commands.
Perfect continuum physics or identical outcomes at every gameplay fidelity
level are not requirements. Random-looking choices should have stable declared
inputs; data races are never an approximation technique.

**Current:** native rules include fixed secondary cadence, activity sleeping
and region filtering. They do not form a general adaptive fidelity controller.
Desktop rendering is independent of the cellular owner; Web still waits for
synchronous ticks. Explicit phased pause/re-entry and failed-world quarantine
are defined contracts; neither silently skips accepted work or replays events.
[ADR-008](../decisions/ADR-008-bounded-approximate-fidelity.md) owns fidelity intent;
[threading](simulation-tick-and-threading.md) owns actual behavior.

## Can materials run on GPU compute or arbitrary JavaScript?

**Current:** authoritative material rules execute in native CPU kernels.
**Rejected at this stage:** GPU terrain authority and arbitrary JavaScript or
other scripts in the per-cell hot loop. **Deferred:** GPU field experiments.
**Planned:** a validated bounded material-program compiler; see
[item-authored programs](item-authored-material-programs.md). Visual graphs
would compile before play and obey the same radius/work bounds, rather than
grant unrestricted scripting access.

## Which shortcuts are rejected?

| Rejected approach | Reason and permitted alternative |
|---|---|
| Per-cell locks or material-specific threads | Cell work is too small for those synchronization/lifecycle costs; use spatial ownership and a shared pool |
| Expanding class hierarchy per material | Descriptors and compact kernels keep state and work inspectable |
| Full-world double buffering as normal operation | Cost would scale with all stored cells; any future buffering is active/field-specific |
| Mutable render reads or rendering locks around World | Consumer lifetime would race or block authoritative work; publish immutable copies |
| Hidden tick-time growth or silent capacity clipping | Pressure must be explicit; production growth needs a drained transition |
| Mixed in-place/next-buffer ownership of one field | Ownership must be unambiguous at every stage |
| GPU terrain authority in this architecture | Collision/query/replay synchronization is not designed or validated |
| Naive local 2×2 occupancy coarsening | It changes narrow gaps, films, silhouettes and collision topology |
| A competing liquid world or per-cell PhysicsServer object | Shared material authority and bulk coupling avoid divergent state/object overhead |

These rejections are scoped decisions. A later reversal requires evidence and
an ADR; they do not forbid render-only GPU effects, explicit full-refresh
recovery packets or separately owned future fields.

## Which Current exceptions must remain visible?

World still combines several production responsibilities. Lazy coordinator
preparation may allocate chunks/temperature during a tick; preallocation
covers those measured allocation classes. The desktop emission queue and
Godot render accumulation are dynamic arrays, not general bounded native
queues. Godot still uploads the full RG8 texture after dirty CPU patching.
The GDScript solver remains a desktop fallback with different semantics.

Sources: [World](../../native/src/world.cpp),
[worker](../../godot/scripts/simulation_worker.gd),
[renderer](../../godot/scripts/main.gd), [fallback](../../godot/scripts/cell_world.gd).
These exceptions require honest scope; they are not permission to extend them
into new hidden ownership or allocation paths.

## What is deliberately outside the next foundation?

**Deferred:** broad world streaming/macroscale aggregation until local material
behavior is mature; fully asynchronous Web ownership; GPU/coarse-field/hexagonal
experiments. **Planned:** general persistence/replay, production fidelity
controls, typed bounded queues and wider physics coupling. Basic optional
temperature storage and finite-demo level saves already exist; neither implies
those larger systems.

Every change should name its owner, writable stage, bounds, failure outcome,
observable metric and detecting fixture. The [invariant register](../reference/invariants.md)
provides stable review IDs; the [documentation checklist](../../AGENTS.md#documentation-obligations)
keeps the authoritative contract, consumers and evidence synchronized.
