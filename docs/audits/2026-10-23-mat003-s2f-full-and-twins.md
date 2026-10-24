---
title: MAT-003PREPASS full S2F source qualification and S2 candidate-twin evidence
status: Current
document-kind: evidence
scope: Full 24-context Linux source-control qualification and untimed observer-on/off candidate twins; no performance timing
canonical-for: []
last-reviewed: 2026-10-23
related-documents: [../operations/mat-003-s2f-feasibility.md, ../operations/mat-003prepass-registration.md, 2026-10-22-mat003-s2f-preflight.md, 2026-10-22-mat003-world-correctness.md]
---

# MAT-003PREPASS S2F full source and candidate twins — 2026-10-23

## Qualified result

Hosted run [39870102635](https://github.com/techrote/cybersand/actions/runs/39870102635)
completed the registered untimed gate on GitHub-hosted Ubuntu 24.04/GCC 13.3.0.
The tested branch head was
`3c9deff11c8bf4d761c4a1e5d64b8625ad915058`; both jobs checked out PR merge
`440316fec74fa871b1b37fbde73a1e1b4f3dcff0`, which GitHub described as merging
that head into the immutable S1 evidence base
`7b71fbb9e1b4286197fb948da3d34f3c3bd5f879`.

This run contains **no admitted performance measurements**. Both collectors
required `formal_timing_admitted=false` and `performance_qualification=false`;
all qualification timing arrays were empty.

## Full source-control context qualification

Job `120142180569` executed the complete registered
C64-E8-source matrix in literal order:

- 512², 1024² and 2048² resident scales;
- quiet, small-active, maintained active liquid/granular and reactive scenes;
- phased one-worker and four-configured-worker variants;
- seed 204, 120 warmup ticks and 256 post-warmup qualification ticks.

All **24/24** contexts passed. This includes the eighteen contexts that remained
unqualified after the earlier six-specimen preflight. The separate verifier
re-read all 24 contexts and checked **93 retained files** with zero errors.

Raw source qualification artifact
[12465598582](https://github.com/techrote/cybersand/actions/runs/39870102635/artifacts/12465598582)
is 368,808 bytes with GitHub artifact digest
`sha256:f4ff6e4baf81e44c0e7b09e82b66131272a1b5445ba4c7f2bc69431f0f10a908`.
The candidate job downloaded the same artifact and independently reverified the
24-context evidence before any candidate build. Recorded expiry:
**2026-11-21 23:12:02 UTC**.

## Independently validated candidate twins

Job `120142437112` was mechanically gated on the successful full-source job.
It generated every candidate from one immutable, hash-guarded S1 overlay and
built two variants per registered arm:

- **observed**: correctness dispatch/worker counters enabled;
- **timing-twin**: those counters compiled out.

The matrix covered all **17 S1 arms**, both modes and both preregistered S2A
anchors: active 512²/four configured workers and quiet 2048²/one worker.
That is **34 sealed candidate builds** and **68 untimed fixture executions**.

Before fixture execution, the collector sealed the complete binary set. The
independent verifier then checked **1,075 retained files** and all **68 cases**
with zero errors. It required:

- identical immutable overlay identity for each observed/timing-twin pair;
- compile command equality apart from the observer definition and output path;
- exact observed/timing-twin agreement on semantic/work/input/Water-ledger fields;
- source-matched semantic/work agreement for all candidate arms at both anchors;
- nonzero dispatch, dispatched-task and background worker-task evidence for
  observer-enabled non-source candidates at the four-worker active anchor;
- zero observer counters in the observer-off twins;
- empty timing arrays and no performance qualification;
- sealed/executed binary digest agreement.

Raw twin artifact
[12466540426](https://github.com/techrote/cybersand/actions/runs/39870102635/artifacts/12466540426)
is 9,861,415 bytes with GitHub artifact digest
`sha256:eaef86b77775e4f8b266879db4726e4523f98c9ee62988c5e21e073e03eb9b45`.
Recorded expiry: **2026-11-21 23:18:14 UTC**.

## What this establishes

The previously held source-workload gate is now complete, and the registered
candidate observer-on/off twins are source-matched at the two proposed S2A
anchors. Candidate four-worker executions have direct background-worker task
evidence rather than configured-worker count alone. The observer-off form is
available without the correctness atomics used to prove that evidence.

Together with S1, this provides correctness evidence for all seventeen carrier
arms, natural E16 rollover on the bounded 256-cell fixture, and forced resident
clear correctness at 512²/1024²/2048².

## What remains held

This evidence is **not** a speed ranking and does not itself admit S2A timings.
In particular:

- it does not prove four distinct worker threads participated or simultaneous
  execution; the retained observer proves actual background worker-task
  execution only;
- no wide-epoch clear latency is qualified here; S1 natural rollover and forced
  resident clears are correctness evidence, not timing evidence;
- process RSS is retained but fixed-cell/fixed-memory analysis and allocator
  overhead remain separate;
- Windows, Wasm and Godot execution remain unqualified;
- S2B, E24/E32, production carrier selection, GEN-006 persistence/streaming and
  production migration remain held.

## Admission disposition

The source-context and candidate-twin prerequisites for a **separately
preregistered S2A paired timing apparatus** are satisfied. Timing remains held
until that next registration freezes the exact 16 contrasts, seven alternating
AB/BA process pairs per contrast, timing-capable observer-off binaries/fixtures,
compiler/flags, 120-tick warmup, sampled horizon, process order, budgets,
stop rules, input-cost separation and clear-event interpretation **before any
timed invocation**.

No existing elapsed collector/job duration is S2A evidence.
