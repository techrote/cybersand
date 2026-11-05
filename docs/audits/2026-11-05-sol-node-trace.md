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

At a4232ccd, all nine retained-oracle binaries preserve the38frozen physical
observations. Three additional trace binaries pass43cases under both policies,
64,902checks each: Linux optimized/strict ASan+UBSan and actual Windows MSVC.
Observed workspace size is74,752bytes and optional trace size55,872bytes on all
three compilers. Traceoff/on physical results/final contacts, reused sink and
body-alias cases match. Raw commands/logs/binaries remain under the new
`build/sol-node-trace/values-001` directory; these are copied-value tests, not
new live physical episodes or runtime admission.

A separate trace runtime adapter preserves the original runtime runner and its
ff0d7cf5receipt. It pins the new registration/wire and writes fresh outputs below
`build/sol-node-trace/runtimes-001`, retaining native84, frozen manifests and32
material-custody files. Actual extension builds and Godot execution remain pending.

Both fresh extensions build successfully at0b76d261, with84native inputs,32
material-custody files and unchanged10,230Windows/1,165Linux dependency entries
before/after each build. Windows DLL SHA isa15c0a84e0cf208698f80588cc5ad1f2eb4f47c5110acec7d834d983f0cda1e3;
Linux SO SHA isd86457925c314b2f14daf0e16df7241940663f6fa9273e5db1eee2b26c73b730.
These fresh outputs remain experimental. Actual Godot lifecycle, scoped suites
and the registered live trace campaign are not yet executed.

The new derived authored fixture configures trace before the normal helper's
first getter. Trace observation failures record fixture failures without changing
the physical response packet. New lifecycle fixtures exercise selector order,
early locks, three-owner captures, held packet reuse/replacement/reset/teardown
and explicit off. Existing source-qualified suites and old fixtures are retained.

First actual-host attempts at5399a910 pass98existing normal-policy checks on
both fresh runtimes and the Linux runtime floor. The new API fixture refuses
its three-actor configuration because Scooper extends beyond the256cell canvas;
continuation on the fallback bridge then faults before creating the native test
World. Owned Windows/Linux processes are explicitly terminated (exits1/15).
[Apparatus002](../../native/tests/fixtures/sol_node_trace_apparatus_002.json)
preserves the failed copies/logs and corrects only API positions/early handling.
The shared-body campaign inputs and compiled native source stay fixed. No
physical episode or trace-lifetime PASS is inferred from these failed attempts.

The initial resource plan retains5GiBfree and atmost2GiBnew artifacts. Actual
buffer size and observer cost must be measured; copied diagnostic payload cost
is not ordinary gameplay or original SOL CPU performance. Original SOL material/
ownership admission, physical clearance and default promotion remain unproved.
Keep Draft and seek separate independent adversarial review before an owner decision.

Atb9053353, all28native qualification commands pass, including166core tests
per optimized/strictASan+UBSan variant. The corrected API attempt reaches its
final teardown assertion, then faults by querying a child after its viewport
was freed. Windows times out124; Linux aborts6. Both failed copied projects,
logs and source/project post-checks remain intact. [Apparatus003](../../native/tests/fixtures/sol_node_trace_apparatus_003.json)
moves only that assertion before freeing its parent. No registered physical
episode has run. The new independent [audit registration](../../native/tests/fixtures/sol_node_trace_audit_001.json)
reuses existing numeric audit tolerances and explicitly refuses full closure
for overflow prefixes. A combined qualification runner reuses one private
project per host for lifecycle, affected suites and the registered campaign.
