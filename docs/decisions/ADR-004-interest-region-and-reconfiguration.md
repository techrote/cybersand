---
title: ADR-004 — Interest region and safe reconfiguration
status: Approved design
scope: Camera-centred simulation policy, serializable dimensions and capacities, initial reservations, expansion transition, diagnostics, and non-limits
keywords: [ADR, interest region, capacity budget, active chunks, reconfiguration, 10 percent, 20 percent]
related-documents: [../systems/world-storage-and-interest-region.md, ../operations/configuration-and-capacity-budgets.md, ADR-002-double-buffered-tile-jobs.md]
last-reviewed: 2026-08-27
implementation-state: Native construction/event capacities, explicit region reservation, allocation observations/failure, and snapshot slot/patch/byte capacities are Current; camera policy serialization and safe live reconfiguration are not implemented.
---

# ADR-004: Interest region and safe reconfiguration

## At a glance

- Decision: simulated interest size and capacity budgets are explicit, serializable, observable configuration.
- Initial policy uses the visible region plus 10% horizontal and 20% vertical margins.
- Initial buffers may reserve for the current and 2× target fixtures.
- Reservations are not permanent world-size or simulated-area limits.
- Larger requests trigger a diagnosed tick-boundary or loading reconfiguration.
- **Explicitly rejected**: clipping, compile-time maxima, silent overflow, and hidden hot allocation.
- Unresolved: serialized schema, exact margin semantics, and pause/failure behavior.

## Search anchors

increase simulation window, is active budget permanent, safe resize, capacity beyond target, interest margin, memory limit

## Status

**Approved design**.

Current Godot constants implement a finite camera proof. Native World and
`cybersand_config_v2` now expose construction-time chunk/work capacities,
event queue/radius, region reservation, resident bytes, and tick allocation
events. RenderSnapshotExchange takes explicit slot/patch/byte capacities and
reports exact requirements and high-water. No persistent schema or
pause/drain/resize/publish transition exists.

## Context

The prototype benefits significantly from simulating only the camera-visible region plus margins. The eventual visible area is expected to grow, potentially to roughly twice the pixels in each direction and later to the actual hardware performance limit.

Freezing current buffer sizes as architecture would turn a provisional reservation into technical debt. Allowing hidden growth during hot ticks would make latency and memory unpredictable.

## Decision

- Treat interest-region width/height and active-chunk budget as versioned serializable configuration concepts.
- Keep task, transfer, snapshot, optional-field, and relevant storage reservations explicit.
- Start with reservations derived from reproducible current and 2× fixtures.
- Expose measured tick time, active chunk/tile counts, transfer/snapshot high-water, dirty upload bytes, allocation count, and memory.
- When a request exceeds reservation, perform intentional reconfiguration only at a simulation tick boundary or loading transition.
- Report requested, available, and resulting capacity and memory.
- Preserve 128×128 storage chunks and the independent activity/scheduling geometry selected by ADR-002 while capacities grow.

Exact World/event C++ and C ABI construction names/defaults and snapshot
exchange capacities are now **Current**. Persistent
configuration keys, migration format, and live-reconfiguration caller result
remain undefined.

## Consequences

### Positive

- Simulation scale can grow without an architectural rewrite.
- Normal ticks can remain allocation-free.
- Capacity choices are measurable and tunable.
- Failures are visible rather than silently corrupting work.
- Stored world extent remains independent of active simulation area.

### Negative

- Reconfiguration requires a drained safe state and careful lifetime management.
- Configuration and save formats require versioning.
- Temporary memory may increase during a resize/loading transition.
- Callers need a clear pending/success/failure experience once specified.

### Risks

- Treating 2× as a hard ceiling would violate the decision.
- Margin semantics could drift between Godot and native code.
- A partial resize could invalidate views or lose dirty state.
- Active, loaded, and stored budgets may be confused if not separately reported.

## Alternatives considered

### Compile-time maximum simulation dimensions

**Explicitly rejected**. They prevent later scaling without code/architecture changes.

### Silently clip the requested region

**Explicitly rejected**. It hides missing simulation and produces inconsistent gameplay.

### Grow containers automatically during TileJob execution

**Explicitly rejected**. It introduces unbounded latency and invalidation risk.

### Reserve for the largest imaginable world

**Explicitly rejected**. It wastes memory and still cannot guarantee future scale.

### Fixed current-size window forever

**Explicitly rejected** as a permanent design. Current size remains a useful fixture.

## Reversal/migration path

The current finite Godot constants remain a rollback point until native configuration and reconfiguration pass.

Individual capacity changes are reversible by loading a previous compatible configuration at a safe transition, provided current committed state fits. Schema-breaking changes require versioned migration.

The architecture can later support larger reservations without changing chunk/tile semantics.

## Validation

- current and 2× fixtures are driven by configuration;
- exceeding capacity never clips or silently allocates;
- successful reconfiguration preserves committed authoritative state and replay behavior;
- failed reconfiguration leaves a valid prior state and explicit diagnostic;
- no worker holds invalidated views;
- high-water and memory observations reflect the transition;
- stored, loaded, active, interest, and rendered regions remain distinguishable.

## Related decisions

- [ADR-002](ADR-002-double-buffered-tile-jobs.md)
- [ADR-003](ADR-003-godot-bridge-and-immutable-snapshots.md)
- [Configuration reference](../reference/configuration-reference.md)
