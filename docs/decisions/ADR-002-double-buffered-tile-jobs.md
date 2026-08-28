---
title: ADR-002 — Benchmark-gated cellular scheduling backends
status: Current
scope: Primary Noita-style phased in-place prototype, buffered reference/fallback, spatial hierarchy, ownership, barriers, deterministic execution, and decision gate
keywords: [ADR, phased in-place, checkerboard, Noita, double buffer, TileJob, worker pool, benchmark gate]
related-documents: [../architecture/chunk-tile-and-buffer-model.md, ../architecture/determinism-and-boundary-transfers.md, ADR-005-water-model.md]
last-reviewed: 2026-08-28
implementation-state: The Noita-inspired four-phase backend, activity hierarchy, bounded write geometry, and persistent worker pool are Current; the buffered fallback remains unimplemented.
---

# ADR-002: Benchmark-gated cellular scheduling backends

## At a glance

- Decision revision: a Noita-style four-phase in-place scheduler is the default standalone native backend.
- Geometry tests prove non-overlapping same-phase write ownership before worker execution.
- 128×128 storage chunks remain independent from scheduling geometry.
- 32×32 regions are the Current native activity granularity.
- 64×64 scheduling cores are the Current native default geometry.
- Active-only double-buffered jobs remain **Planned** only as a demonstrated-need comparison/fallback.
- Ordinary bounded local moves are not staged when the phased scheduler owns their complete write domain.
- Long-range and structural effects remain deferred, bounded events.

## Search anchors

why checkerboard became primary, Noita four phase scheduler, 64 scheduling core, phased in-place ownership, double buffer fallback, scheduler benchmark gate

## Status

**Current** for the phased native backend; **Planned** for the buffered fallback.

World implements 32×32 activity blocks, 64×64 parity scheduling cores, four
phase barriers, declared radius-two write domains, deterministic merge, and a
persistent worker pool. Bundled Linux and Windows x86_64 Godot builds invoke
this World through CyberNativeCellWorld; unsupported platforms use the serial
GDScript fallback.

## Context

The earlier plan prioritized isolated next-state outputs because their concurrency semantics are straightforward. Evidence from the Noita developers changes the performance trade-off: four phases of spatially exclusive in-place work can avoid per-cell atomics while also avoiding the copy traffic and boundary records imposed by general double buffering. Sandspiel independently demonstrates the value of compact cells and direct bounded local mutation.

The external examples do not prove that their exact layouts are optimal for this engine. The decision is therefore to promote phased in-place scheduling to the leading candidate while retaining an instrumented buffered implementation long enough to measure both on identical fixtures.

## Decision

### Shared spatial hierarchy

- WorldStorage retains 128×128 storage chunks for persistence, streaming, serialization, and coarse capacity.
- Fine activity tracking uses 32×32 regions; render dirty extraction is still per storage chunk.
- The phased backend evaluates 64×64 scheduling cores arranged by global coordinate parity.
- Storage boundaries do not define material-rule semantics or require a special simulation rule.
- The write domain is the core rectangle expanded by the configured maximum rule radius. The current active catalogue requires two cells; geometry rejects radii above half a core.

### Primary candidate: phased in-place

- Each phase dispatches only jobs whose complete write domains cannot overlap.
- A job may directly mutate cells only within its phase-owned write domain.
- Material rule reads and writes have an enforced finite radius.
- Scan order, phase order, and deterministic random derivation are authoritative semantics.
- A barrier separates every phase.
- Ordinary falling, rising, density swaps, and bounded reactions occur directly when all touched cells are owned.
- Effects outside the owned domain become bounded deferred events or wait for an eligible phase; the selected policy is still **Ambiguous**.
- Explosions, rigid-body fracture, world generation, and other structural or long-range work never bypass the deferred-event boundary.

### Retained backend: active-only buffered jobs

- A buffered backend reads committed current state and writes isolated next regions.
- It remains available as a correctness aid, performance comparison, rollback path, and possible implementation for fields that require snapshot-style updates.
- Cross-output effects use bounded deterministic transfers.
- It does not share a tick with in-place cell movement unless an explicit field boundary makes ownership unambiguous.

### Decision gate

The phased path is the provisional default because it is working, deterministic,
and measured. A buffered implementation is no longer mandatory before progress;
if implemented for a demonstrated field need, compare:

- total tick time and stage timings;
- resident and transient memory;
- bytes read, written, copied, and staged where measurable;
- active-work scaling and settled-world cost;
- worker utilization and barrier imbalance;
- determinism, edge correctness, conservation, and allocation behavior;
- integration complexity for bounded material rules and optional fields.

No single metric automatically wins. A materially faster backend that weakens required correctness or future rule isolation fails the gate.

## Consequences

### Positive

- The leading candidate eliminates most ordinary movement-transfer records and next-buffer copying.
- Density swaps and local reactions map naturally to in-place cellular rules.
- Exclusive phase ownership avoids per-cell locks and atomics.
- Storage, activity, and scheduling sizes can be tuned independently.
- Retaining the buffered path gives difficult fields an alternative and makes the decision reversible.

### Negative

- Four phase barriers are required per cellular tick.
- Traversal order is observable simulation semantics.
- Every rule must declare and obey a bounded access radius.
- Proving write-domain exclusivity is more difficult than isolated output ownership.
- Maintaining two backends during the decision window has a temporary engineering cost.

### Risks

- An incorrect phase mask can create rare data races or double updates.
- A large rule radius can invalidate the chosen geometry.
- Poor activity compaction can erase the memory-traffic advantage.
- Backend-specific outcomes can make a buffered implementation unsuitable as a byte-identical oracle even when both satisfy the same invariants.
- Four barriers may dominate sparse or low-core-count fixtures.

## Alternatives considered

### Double-buffered TileJobs as the unmeasured default

Previously **Approved design**; now **Planned** only when measurements or field
semantics justify its memory traffic.

### Serial in-place scan

**Current** as a reference/rollback backend, but not the multicore default.

### Per-cell or fine-grained mutexes

**Explicitly rejected**. Lock overhead and contention conflict with cell-scale work.

### Material-specific threads

**Explicitly rejected**. Scheduling is spatial and belongs to SimulationScheduler.

### Full-world double buffering

**Explicitly rejected**. Memory and copy cost scale with all stored cells rather than active work.

### Immediate GPU-authoritative terrain

**Deferred / experimental**; terrain authority remains **Explicitly rejected** at present. See ADR-006.

## Reversal/migration path

Keep these independently runnable checkpoints:

1. Current serial native backend.
2. One-worker phased backend.
3. Multiworker phased backend using identical phase semantics.
4. Optional one-worker active-only buffered comparison only when justified.
5. Production bridge selection recorded with target-hardware benchmark evidence.

If phased ownership or performance fails, select the buffered backend without changing WorldStorage, MaterialRules descriptors, bridge contracts, or fixtures. Field-specific buffering remains possible even if phased cellular material movement wins.

## Validation

- phase write domains are mechanically checked for non-overlap — **Current**, passing;
- one/four-worker phased runs produce identical replay hashes in Water and complete-material fixtures — **Current**, passing;
- completion-order perturbation inside a phase does not alter results;
- every activity, scheduling, storage, and interest-region boundary has shifted-equivalent fixtures;
- no cell is updated more than permitted by the specified phase semantics;
- rule-radius violations fail visibly;
- preallocated normal ticks report no World-owned chunk/temperature allocation — **Current**, passing;
- ASan+UBSan and TSan suites pass; LeakSanitizer remains blocked by the hosted environment;
- both candidates report comparable timing, memory, work, and high-water observations — **Planned** if Buffered is implemented;
- current and 2× fixtures produce a recorded decision-gate result.

## Related decisions

- [ADR-001](ADR-001-native-simulation-core.md)
- [ADR-004](ADR-004-interest-region-and-reconfiguration.md)
- [ADR-005](ADR-005-water-model.md)
