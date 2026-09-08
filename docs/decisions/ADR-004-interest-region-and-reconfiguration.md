---
title: ADR-004 — Interest region and safe reconfiguration
document-kind: decision
canonical-for: [decision-interest-capacity-reconfiguration]
status: Approved design
scope: Accepted scalable interest/capacity direction, current construction limits and unresolved margin/reconfiguration semantics
keywords: [ADR, interest region, 10 percent, 20 percent, capacity, safe resize]
related-documents: [../systems/world-storage-and-interest-region.md, ../operations/configuration-and-capacity-budgets.md, ../reference/configuration-reference.md]
last-reviewed: 2026-09-08
---

# ADR-004: Interest region and safe reconfiguration

## Decision and implementation status

**Approved:** interest dimensions and capacity reservations should be explicit,
serializable and observable. A starting fixture or 2× reservation is not a
permanent world-size ceiling. Growth should happen at a drained tick boundary
or loading transition, with requested/available/resulting capacity reported.

**Current:** WorldConfig/C ABI expose construction capacities and explicit region
reservation; native snapshot slots also have explicit capacities. **Planned:**
general configuration serialization and live pause/drain/resize/publish.
CYSD1 level restoration does not implement that transition.
Sources: [WorldConfig](../../native/include/cybersand/world.hpp),
[C API](../../native/include/cybersand/c_api.h).

## Which margin policy is actually approved?

The retained direction says 10% horizontal and 20% vertical margins, but does
not resolve whether those mean each side or total expansion, which dimensions
are the base, or how rounding applies. **Ambiguous:** that percentage policy
requires clarification before implementation.

**Current:** desktop presets and Web quality profiles use explicit per-side
pixel pairs, not one universal percentage formula. Their values and actual
region behavior belong in the
[interest contract](../systems/world-storage-and-interest-region.md) and
[configuration reference](../reference/configuration-reference.md).
Do not silently select an interpretation to make documentation agree.

## Why choose explicit reconfiguration?

Simulation interest can remain small relative to stored world extent and grow
with hardware or product needs. A compile-time limit would turn an initial
reservation into permanent debt; automatic hot growth would hide latency and
invalidate worker views. A diagnosed transition preserves scalability without
making ordinary ticks depend on allocator success.

The cost is a complete transition/lifetime design, possible temporary memory
increase and explicit pending/failure UX. Exact API states and whether the
caller pauses, rejects or enters loading remain undecided.

## Which alternatives are rejected?

**Rejected:** silently clipping requests, fixed current-size windows forever,
reserving the largest imaginable world and growing containers during worker
execution. These restrictions are production direction, not proof that every
prototype path is compliant: lazy coordinator preparation can still allocate
inside a tick, and current failure can follow partial progress.

**Current defect:** region-excluded phased blocks can sleep without waking on
re-entry; SerialInPlace ignores the region. The
[interest contract and probe](../systems/world-storage-and-interest-region.md)
record this separately from the Approved requirement to preserve correct
wake/eligibility. Safe re-entry must not be inferred from a bounds setter.

## What evidence is needed to complete this decision?

A transition must preserve committed state, prevent dangling job views, report
memory/high-water changes and leave a valid outcome on failure. Test existing,
larger and over-capacity configurations, plus region exit/re-entry and sleeping
material. Current capacity fixtures are useful inputs, not proof of implemented
live resize. See [validation](../reference/validation-evidence.md) and
[ownership](../architecture/data-ownership-and-lifetimes.md).

## Failed-world boundary

**Current:** a region request can be retained while a World is failed but does
not recover it. Explicit clear/reset or validated replacement is required;
the latest region then applies to freshly established activity. This issue #1
recovery policy ([ADR-010](ADR-010-failed-tick-quarantine.md)) does not implement
the Planned state-preserving live resize protocol.
