---
title: ADR-003 — Godot bridge and immutable snapshots
status: Current
scope: Godot/native authority boundary, immutable dirty snapshots, queued commands/results, thread restrictions, and bridge pressure
keywords: [ADR, RenderBridge, GameplayBridge, immutable snapshot, Godot thread, mutable memory]
related-documents: [../architecture/rendering-and-gameplay-bridges.md, ADR-001-native-simulation-core.md, ADR-004-interest-region-and-reconfiguration.md]
last-reviewed: 2026-09-08
implementation-state: The native reusable immutable dirty-snapshot exchange, C lease API, and copied Godot dirty-RG8 adapter are Current; the generalized GameplayBridge remains Planned.
---

# ADR-003: Godot bridge and immutable snapshots

Evidence scope (2026-09-08): **Current** below describes inspected source in the
reconstructed local snapshot, not a verified Git HEAD or an all-platform test pass.
See the [documentation audit](../audits/2026-09-08-documentation-audit.md) for
source identity and dated validation; [M11 audit records](../audits/m11/README.md)
retain historical scope. **Approved design** means Approved direction; Planned,
Deferred, and Rejected statements do not claim implementation.

## At a glance

- Decision: Godot interacts with simulation through RenderBridge and GameplayBridge only.
- RenderBridge consumes immutable dirty snapshots.
- **Current**: native snapshot slots are bounded/reused, leases are immutable, and pressure retains dirty state.
- **Current**: the Godot adapter copies and accumulates dirty RG8 patches without exposing mutable native storage.
- GameplayBridge queues tick-boundary commands and consumes immutable results.
- Godot never reads mutable SimulationCore or WorldStorage memory.
- Native workers never access scene-tree, rendering, audio, or gameplay objects.
- Cost: bounded publication storage and explicit pressure/lifetime contracts are required.
- Unresolved: true GPU texture-subregion writes, gameplay schemas, production capacities, and optional snapshot compression/coalescing.

## Search anchors

can Godot access cells directly, immutable dirty snapshot, RenderBridge ownership, GameplayBridge command, worker scene access

## Status

**Current**, partial.

The repository contains the platform-neutral native publication half of
RenderBridge in `render_snapshot.hpp/.cpp`, C ABI exchange/lease functions, and
a `godot-cpp` binding that returns copied immutable dirty RG8 patches. It contains
no generalized GameplayBridge.

## Context

The current Godot proof copies dirty material/condition patches into
CyberSimulationSnapshot and applies them to a persistent RG8 CPU image. The
main thread still submits the complete backing image through
`ImageTexture.update()`; the GDScript solver provides a platform fallback.

A native authoritative backend must prevent presentation and gameplay lifetimes from racing mutable simulation state.

## Decision

- RenderBridge is the only simulation-to-Godot rendering boundary.
- It receives immutable dirty snapshots created after authoritative commit.
- GameplayBridge is the only gameplay intent/result boundary.
- Commands are queued and latched at simulation tick boundaries.
- Results are immutable after publication.
- Godot object references never enter native worker jobs.
- Snapshot/task/transfer storage is bounded and observable.
- Mutable simulation pointers, references, array views, and container handles are never exposed to Godot.

The Current native payload uses deterministic dirty rectangles and packed
material/condition bytes. Slot pressure is non-blocking and preserves dirty
state. The condition byte is a read-only material-selected projection. Production
capacities, gameplay contracts, renderer-specific GPU subregion writes, and
future compression/coalescing are not decided by this ADR.

## Consequences

### Positive

- Simulation and rendering can run concurrently without renderer locks on authoritative cells.
- Snapshot lifetime is independent of active mutable buffer lifetime.
- Native tests can replace bridges with data-only fixtures.
- Godot thread restrictions are easier to audit.
- Dirty-region publication can reduce full-world copies/uploads.

### Negative

- Dirty data must be copied or encoded into bounded publication storage.
- Consumer lag needs an explicit policy.
- Gameplay object identity needs a data representation rather than pointer sharing.
- Debug tools cannot casually inspect live mutable arrays.

### Risks

- Treating conventionally immutable GDScript objects as the final contract may leave mutation holes.
- Clearing dirty state before a snapshot is safely retained can lose visual updates.
- Retained snapshots can exhaust bounded capacity if lifetimes are unclear.
- Bridge code can become a second gameplay-authority layer if results are not clearly defined.

## Alternatives considered

### Godot reads native mutable memory directly

**Explicitly rejected**. It creates races, lifetime coupling, and renderer locks.

### Lock authoritative state during rendering

**Explicitly rejected**. Rendering duration would block simulation and make frame load affect physics throughput.

### Full-state snapshot every changed tick

**Explicitly rejected** as the ordinary native bridge path. A bounded full RG8
packet remains the explicit recovery path when patch capacity is exceeded or a
consumer requires resynchronization.

### Run all simulation on the Godot main thread

**Rejected** as the production-scale ownership target. **Current** Web uses
synchronous main-thread ticks as a bounded compatibility/threaded adapter;
separate publication cadence does not remove its render-blocking wait. Full
asynchronous Web ownership remains Planned and the exception is explicit in
[tick/threading](../architecture/simulation-tick-and-threading.md).

## Reversal/migration path

- Retain current GDScript snapshot rendering as the unsupported-platform rollback point.
- Introduce immutable native snapshots before removing mutable/full-copy access. **Current** for native publication and copied Godot consumption.
- Compare visual content and dirty coverage.
- Switch GameplayBridge command/result flow independently of unrelated Godot gameplay refactors.
- If dirty publication fails, roll back to a bounded full-region immutable snapshot, not mutable memory.

## Validation

- snapshot bytes remain unchanged throughout consumer lifetime;
- Godot cannot obtain mutable authoritative storage;
- snapshots correspond to serialized completed mutations/ticks (including initial/full-refresh state);
- dirty state is not lost under capacity pressure;
- commands apply only at permitted boundaries;
- native workers make no prohibited Godot calls;
- snapshot and upload bytes/high-water are observable;
- presentation changes do not alter replay hashes.

The Current [native fixtures](../../native/tests/test_world.cpp) cover stable
outstanding leases including exchange
facade destruction, two-slot pressure
and recovery, exact capacity requirements, dirty retention, deterministic patch
order, high-water counters, C lease lifetime after exchange-handle destruction,
and concurrent producer/consumer access. TSan execution belongs to historical
M11 evidence. The [focused Godot regression](../../godot/tests/test_native_render_bridge_regression.gd)
checks a complete 2,097,152-byte RG8 recovery packet and an 18-byte one-patch
Water edit; generalized gameplay command/result validation remains **Planned**.

## Related decisions

- [ADR-001](ADR-001-native-simulation-core.md)
- [ADR-004](ADR-004-interest-region-and-reconfiguration.md)
- [ADR-006](ADR-006-gpu-compute-deferral.md)
