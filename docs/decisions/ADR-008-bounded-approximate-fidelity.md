---
title: ADR-008 — Bounded approximate fidelity under load
document-kind: decision
canonical-for: [decision-bounded-approximate-fidelity]
status: Approved design
scope: Accepted fidelity direction and constraints; fixed current cadence is separate from planned adaptive policy
keywords: [ADR, approximation, fidelity, strict replay, frame pacing, temporal sampling, coarsening]
related-documents: [../architecture/simulation-tick-and-threading.md, ../architecture/determinism-and-boundary-transfers.md, ../operations/profiling-observability-and-performance.md]
last-reviewed: 2026-09-08
---

# ADR-008: Bounded approximate fidelity under load

## Decision and implementation status

**Approved:** interactive frame pacing may take priority over calculating every
secondary interaction each tick. Explicit bounded sampling/deferral is allowed;
local collision, ownership, conservation and accepted authoritative commands
must remain correct. Universal bit-identical gameplay across fidelity policies
is not required.

**Current:** native eligible transport, fixed staggered secondary lanes,
activity sleeping and interest filtering. These are compiled policy, not an
overload-triggered adaptive controller. **Planned:** selectable strict/runtime
policies, hysteresis, work targets, coarser optional fields and distant aggregates.
Exact native fixtures remain Current; complete replay is not implemented.
Sources: [World rules](../../native/src/world.cpp),
[hash coverage](../architecture/determinism-and-boundary-transfers.md).

## Why allow approximation?

A large wake-up can make local secondary work exceed the intended tick interval.
Engineering determinism alone does not make stalled gameplay acceptable.
Reducing slow/distant update frequency can protect responsiveness while
preserving full-resolution occupancy around bodies, hazards and the player.

Naively merging local cells changes narrow gaps, films, collision boundaries
and quantity. Static sleeping material already avoids most rule work; coarse
merging is least useful where it is safest. Temporal and field-specific choices
therefore precede broad spatial reduction.

## Which fidelity tiers are intended?

| Approved scope | Intended constraint |
|---|---|
| Immediate interaction | Full local occupancy/collision and prompt known-contact resolution |
| Active surroundings | Explicit interest-weighted cadence or sampled secondary searches |
| Secondary fields | Lower cadence/resolution only with declared conservation/transfer boundaries |
| Distant world | Sleep or future conserved summaries that expand before interaction |
| Strict validation | Fixed declared policy, stable random/order inputs and exact fixture comparison |

Policies must be bounded, observable and independently reversible. Good
candidates include slow ignition, corrosion, growth and distant fields. Poor
candidates include capacity checks, synchronization, accepted explosions,
closed-boundary conservation or detected penetration. Stateless seeded choices
are preferred; worker timing must never become a hidden random input.

## Which alternatives and assumptions are rejected?

**Rejected:** a universal all-fidelity bit-exact gameplay gate, naive local 2×2
occupancy merging, systematic empty scanlines and render delta as simulation
time. Separate desktop rendering is Current; Web still synchronously waits for
native ticks. `K` changes presentation smoothing, not material accuracy.
The [tick contract](../architecture/simulation-tick-and-threading.md) records
that exception and actual failure/overrun behavior.

Current region re-entry can leave movable cells asleep; this is a defect in the
[interest contract](../systems/world-storage-and-interest-region.md), not an
Approved approximation policy. Fixed secondary lanes also lack a universal
disable switch; do not claim today's runtime can select fully strict execution.

## What evidence is needed for a new policy?

Report its configuration, work deferred/dropped, tick time, backlog, snapshot
age and visual artifacts. Compare fixed-policy fixtures for conservation,
barriers, eventual work and worker parity. Test quality transitions under load
and preserve a reversible comparison. A headless pass cannot approve perceived
motion or frame pacing. The [validation ledger](../reference/validation-evidence.md)
separates tested behavior from these future acceptance requirements.
