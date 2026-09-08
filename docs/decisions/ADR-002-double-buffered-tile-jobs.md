---
title: ADR-002 — Benchmark-gated cellular scheduling backends
document-kind: decision
canonical-for: [decision-phased-in-place-scheduler]
status: Current
scope: Accepted phased scheduler selection, retained buffered candidate and criteria for reconsideration
keywords: [ADR, phased in-place, Noita, Buffered, benchmark gate, serial fallback]
related-documents: [../architecture/chunk-tile-and-buffer-model.md, ../architecture/determinism-and-boundary-transfers.md, ADR-005-water-model.md]
last-reviewed: 2026-09-08
---

# ADR-002: Benchmark-gated cellular scheduling backends

## Decision and implementation status

**Current:** PhasedInPlace is the native default. Four spatial parity phases,
exclusive bounded write domains, barriers and deterministic merge allow a
persistent worker pool to update cells in place. **Current alternatives:**
SerialInPlace and one-worker PhasedInPlace. **Planned:** active-only Buffered,
whose enum throws when selected; it is not a runnable fallback.

Sources: [World `tick_phased`/`tick`](../../native/src/world.cpp),
[SchedulerGeometry](../../native/src/scheduler_geometry.cpp).
The [geometry contract](../architecture/chunk-tile-and-buffer-model.md) owns
sizes/radii; [determinism](../architecture/determinism-and-boundary-transfers.md)
owns authoritative ordering. Startup Auto and Web profile choices belong in
[threading](../architecture/simulation-tick-and-threading.md).

## Why did phased work replace mandatory buffering?

The earlier plan favored isolated next-state output because its concurrent
ownership was straightforward. Noita-inspired spatial exclusivity made a
lower-traffic option credible: direct bounded mutation avoids per-cell atomics,
ordinary movement-transfer records and next-buffer copying. External inspiration
did not prove an optimum for CyberSand; the executable phased implementation and
measured fixtures supported its provisional selection.

No instrumented Buffered comparison exists. Building it is not a prerequisite
for further work; a demonstrated field need or unacceptable phased behavior
can justify that cost. The historical measurements retain their original scope
in the [validation ledger](../reference/validation-evidence.md).

## Consequences and rejected alternatives

The choice fits density swaps, local reactions and shared-grid Water. Storage,
activity and scheduling granularity remain independent. Its costs are four
barriers, traversal-dependent behavior, strict radius enforcement and a more
subtle exclusivity proof than isolated outputs. Sparse jobs may be cheaper
serially, and backend invariants need not imply byte-identical outcomes.

**Rejected:** per-cell mutexes, material-specific workers, full-world double
buffering and unbounded mixed ownership. Ordinary out-of-domain attempts are
not implemented as general transfer events. Long-range worker effects require
a separately specified bounded event boundary.

## When should this decision be revisited?

Compare behavior, total/stage time, active-work scaling, memory/copy traffic,
barrier imbalance, conservation and capacity behavior on representative current
and larger fixtures. A faster backend that weakens ownership or accepted
invariants fails the gate. A future Buffered design must specify halo/output
ownership and canonical transfers before implementation.

Maintain exact worker parity within the chosen phased semantics, shifted/edge
fixtures and rule-radius checks. Historical sanitizer passes do not validate
current Windows/Web artifacts. Region filtering also differs between serial
and phased paths and has a current re-entry defect; the
[interest contract](../systems/world-storage-and-interest-region.md) records
that limitation. Any production selector must expose such differences rather
than claim universal backend equivalence.
