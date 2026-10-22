---
title: MAT-003PREPASS S2F untimed source-workload preflight evidence
status: Current
document-kind: evidence
scope: Six Linux source-control preflight fixtures and independent artifact readback, not a carrier performance comparison
canonical-for: []
last-reviewed: 2026-10-22
related-documents: [../operations/mat-003-s2f-feasibility.md, ../operations/mat-003prepass-registration.md, 2026-10-22-mat003-world-correctness.md, ../reference/validation-evidence.md]
---

# MAT-003PREPASS S2F untimed preflight — 2026-10-22

## Qualified result

**Six of six registered developer-preflight source-control fixtures passed**
on Ubuntu 24.04/GCC 13.3.0, with eight focused evidence-contract tests and
a separately executed independent readback of **57 retained files**.
[Hosted preflight run 39867638084](https://github.com/techrote/cybersand/actions/runs/39867638084)
is green; [documentation/provenance run 39867638180](https://github.com/techrote/cybersand/actions/runs/39867638180)
is green. The [compact machine index](mat003-s2f-2026-10-22/hosted-summary.json)
records source/binary/compiler identities, exact per-scene work and memory
receipts, both earlier failed runs and the raw artifact locator.

This stage **does not qualify candidate carrier speed**, the other eighteen
source contexts, independent physical worker-thread participation,
wide-epoch maintenance costs, the full S2A/S2B interleaved AB/BA pairs,
Windows/Wasm/Godot or production migration. The source control is the
unchanged C64-E8 World, not a new C72/C80 executable. Tick nanosecond
arrays are absent by preflight contract; collector elapsed time was budget
enforcement only.

## Source, binary and raw evidence identity

| Identity | Value |
|---|---|
| First machine registration before apparatus | 89b2b22635f53e0caee045bdc9fbfd3803f5b051 |
| S1 evidence intake | 7b71fbb9e1b4286197fb948da3d34f3c3bd5f879 |
| S2F tested branch | 49949bfaff287b6e447dd64c3f9a854a100a65db |
| Hosted PR merge checkout | 257af0b31d1ab214feedeefddc863fcc1b593fe5 |
| Identical branch/merge tree | c79fa77c1f5fa725ef8150a3b11a7fed4134796f |
| Unchanged frozen native dependency baseline | da5112c066416346d6fe3984d4161cd162611e50 |
| GCC 13.3 executable SHA-256 | 1353e9bdd29a7295c7226bf6c63abccce056d8cac31f112e5cdbecc3f28c2769 |
| Frozen S2F source-control binary SHA-256 | 976f45c08c59ca2bdc20291b396181265b958a9b3fc42f57fbc88103a38c3dc4 |

The registration/fixture/runner/verifier and S1 dependency-ledger hashes are
recorded in the compact JSON. The original collector sealed all 36 native/
apparatus input identities and the binary hash **before** running fixtures.
The independent raw-artifact readback passed 57 file size/hash checks and
all six lossless outcome validations; the downloaded ZIP CRC check passed.

The [retained Actions artifact 12464507219](https://github.com/techrote/cybersand/actions/runs/39867638084)
has 348,965 ZIP bytes and locally reverified SHA-256
3c298e08fac7d9976dc26da50d69a76b1ac4a19fd7171e6e0c1771bab15a4d58.
Its recorded expiry is **2026-11-21 22:49:30 UTC**. The checked-in compact
index is not a replacement for binary/raw outcome receipts after expiry.

## Actual untimed workload observations

Each fixture completed 120 warmup and 256 post-warmup source-control ticks
with deterministic seed 204. The input-call counts are attempted public
source edits, **not** proofs of net injected conserved Water quantity.

| Scene | Positive-work ticks | Total visited cells | Scheduled phase jobs | Reactive product witnesses | Process peak RSS |
|---|---:|---:|---:|---:|---:|
| Quiet 512², 1 worker | 0/256 | 0 | 0 | 0 | 29,835,264 B |
| Small active 512², 1 worker | 256/256 | 143,072 | 1,024 | 0 | 29,982,720 B |
| Active 512², 4 configured | 256/256 | 2,907,449 | 14,740 | 0 | 30,105,600 B |
| Reactive 512², 4 configured | 256/256 | 3,135 | 3,303 | 63 | 30,167,040 B |
| Quiet 2048², 1 worker | 0/256 | 0 | 0 | 0 | 62,214,144 B |
| Active 2048², 4 configured | 256/256 | 2,907,449 | 14,740 | 0 | 62,619,648 B |

The fixed 512² active subregion and input schedule produce identical
aggregated work in the 512² and 2048² resident cases; this **does not**
establish whole-region scaling or a relative speed advantage. The large
resident case exercises additional allocated quiet storage. Per-process
peak RSS is a one-sample Linux observation, not additive with the legacy
resident-cell aggregate and not allocator-overhead isolation. Phase-job
counts do not prove four participating physical worker threads.

## Failures and correction integrity

Initial [run 39867119916](https://github.com/techrote/cybersand/actions/runs/39867119916)
failed before any fixture because one deliberately negative test expected
the wrong rejection wording and the new operation page lacked its retrieval
corpus entry. Both were corrected; these failures were never treated as
World evidence.

[Run 39867297931](https://github.com/techrote/cybersand/actions/runs/39867297931)
compiled source control and passed earlier test gates but **failed** the
active-512-w4 post-warmup non-vacuity test. Its
[retained failure artifact 12465220190](https://github.com/techrote/cybersand/actions/runs/39867297931)
contains the original stdout/stderr, source, executable and incomplete
receipt (345,280 ZIP bytes, verified SHA-256
fc30d991342573db53e3e9489f3a66d51e13ed6c405fa16de72772c281e1392c).
The earlier injection pattern allowed an active chamber to settle. Commit
49949bfaff287b6e447dd64c3f9a854a100a65db alternates Water/Sand
sources each tick; on the hosted final run, all 256 observed active ticks
remain nonzero. Prior evidence was not deleted or reclassified.

The CI workflow and collector record a *passed-preflight-only* result; no
timing manifest or performance winner is implied. The two successful run
artifacts remain source-bound to their respective hashes.

## Required next gates

Finish untimed qualification of the other **18** source-control contexts,
then add correctness-observed candidate twins and actual background-worker
execution witnesses before admitting any observer-off S2A timings. The
proposed S2A 224 primary processes and optional S2B 322 processes need new
formal immutable source/binary/fixture/contrast and order registration,
paired seven AB/BA process repetitions and explicit cost/stop rules.
Actual E16 clears must be timed separately from non-wrap E16 operation
and period amortization marked as a projection. S0/S1 remain independently
accepted on their original inputs; issue #204 and G-final stay open.
