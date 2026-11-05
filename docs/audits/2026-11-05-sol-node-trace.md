---
title: Bounded native contact trace registration
status: Current
document-kind: evidence
scope: Registered observation-only follow-up; implementation and new runtimes not yet qualified
canonical-for: []
last-reviewed: 2026-11-05
related-documents: [2026-11-05-sol-application-replay.md, 2026-11-05-sol-active-normal-live.md, ../architecture/rigid-body-and-cellular-coupling.md]
---

# Bounded native contact tracing — 5 November 2026

Root alone continues Draft429 from275ce1ee with
[SOL-NODE-TRACE-001](../../native/tests/fixtures/sol_node_trace_001.json), committed
before production instrumentation. This is a diagnostic follow-up to the complete
recorded application replay, not a new response or correction policy. Current
physics, gains/caps, four passes, friction, final gate and defaults remain fixed.

Planned capture uses optional caller-owned fixed storage for64observed nodes and
eight batches. Solver workspace/result sizes stay independent. Above64nodes,
only observation is incomplete: every original solve node and update still runs.
Original-policy diagnostic activity cannot read its unwritten active-mask array.
A fresh diagnostic-only selector has a separate one-use latch, ordered
independently from normal-policy selection. Result rows own copied captures;
reset/replacement retire scratch and selector state.

New value/overflow/stale-buffer/lifecycle tests and fresh Windows/Linux runtimes
must precede the16episode shared-body campaign. It compares traceoff/on for both
normal policies, workers1/4, one repeat and all180steps/three owners. This is
not a repeat of the full physical matrix or an original SOL acceptance clock.
The historical header guard, old runtimes and all evidence remain unchanged.

The first implementation checkpoint adds the optional templated value observer
and fresh diagnostic adapter in the same four experimental native files. The
off specialization contains no node-observation checks. A Workbench-owned null
`unique_ptr` becomes a fixed buffer only after successful fresh admission;
normal/trace selectors have independent latches. Captures are copied into each
row before scratch reuse. Failed export lengths mark EXPORT_FAILED without
changing the physical response. The [wire schema](../../native/tests/fixtures/sol_node_trace_wire_001.json)
defines every packed column and lossless IEEE754little-endian bit companion.
Decimal JSON is not the exact arithmetic oracle.

Read-only source reviews found and corrected an enum/warning risk, an aliased
body/reset hazard and off-path index bookkeeping before compilation. Native
regressions cover the38frozen cases plus0/1/64/65/1024node boundaries, both
policies, stale primed workspace/sink, body aliasing and nonfinite refused input.
Actual compiler sizes, physical parity and runtime/API qualification are still
unavailable at this checkpoint; no old runtime receipt qualifies this new source.

The initial resource plan retains5GiBfree and atmost2GiBnew artifacts. Actual
buffer size and observer cost must be measured; copied diagnostic payload cost
is not ordinary gameplay or original SOL CPU performance. Original SOL material/
ownership admission, physical clearance and default promotion remain unproved.
Keep Draft and seek separate independent adversarial review before an owner decision.
