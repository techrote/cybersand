---
title: MAT-003PREPASS S2F source-control feasibility and untimed preflight
status: Planned
document-kind: guide
scope: Isolated S2F source-only workload qualification, without admitted paired performance comparisons or production migration
canonical-for: []
last-reviewed: 2026-10-22
related-documents: [mat-003prepass-registration.md, architecture-programme.md, ../audits/2026-10-22-mat003-world-correctness.md, ../research/mat-003prepass-gen006-handoff.md]
---

# MAT-003PREPASS S2F source-only preflight

## Immutable predecessor and stage decision

Issue [#204](https://github.com/techrote/cybersand/issues/204) has S0 storage
and [S1 native World correctness](../audits/2026-10-22-mat003-world-correctness.md)
qualified only for their tested Linux inputs. The S1 checkpoint head is
7b71fbb9e1b4286197fb948da3d34f3c3bd5f879; its 17-arm World execution
and independent readback are run 39854839256. Draft
[PR #208](https://github.com/techrote/cybersand/pull/208) remains independent.

S2F prepares a **separately registered source-control workload feasibility
gate**, not 64/72/80-bit carrier performance rankings, epoch cost claims,
new material semantics or production migration. Its first
[machine registration](../../tools/experiments/mat003_perf/s2f_registration.json)
was committed as 89b2b22635f53e0caee045bdc9fbfd3803f5b051 **before
apparatus code**. Native baseline da5112c066416346d6fe3984d4161cd162611e50
is guarded by the registered source hashes in the original S1
[world registration](../../tools/experiments/mat003_prepass/world_registration.json).
S1 production inputs, experimental tools and its evidence are unchanged.

## Frozen scope and preliminary subset

The future source-control-only S2F grid has **24 contexts**:
512² / 1024² / 2048² resident cells × quiet/sleeping, small active region,
maintained liquid/granular and reactive catalogue scenes × phased 1/4
configured workers. Each uses seed 204, 120 warmup and 256 sample ticks.
Every future context must separately qualify; neither source timings nor
candidate comparisons are accepted yet.

This preflight deliberately executes six **untimed** developer specimens, in
literal registration order: quiet-512-w1, small-512-w1, active-512-w4,
reactive-512-w4, quiet-2048-w1, active-2048-w4. It checks 376 completed
ticks, exact resident geometry, quiescent zero visits, maintained positive
visits on at least 231 of 256 post-warmup ticks, deterministic input-call
counts, and actual RustedSteel presence in the reactive control.

This is neither the full 24-context feasibility matrix nor an equivalence
qualification of new candidate arms. Four configured workers do not prove
four actual background threads; S1 observer atomics must not enter
candidate primary timing measurements.

## Frozen input, execution and readback contract

The isolated [collector](../../tools/experiments/mat003_perf/s2f.py)
refuses an existing output path, copies all compiled native dependency bytes
and experiment scripts into an immutable source snapshot, checks each native
input against S1 hashes and the baseline Git object, captures compiler binary
SHA-256/GCC 13.3/binutils 2.42, and compiles one source-control binary.
It **seals the binary hash before invoking** any fixture. Each sequential
preflight retains command, stdout, stderr, exit/timeout, final work counters,
source hashes, process peak RSS, nonadditive resident aggregate and every
artifact size/SHA-256. A failure or budget stop is incomplete, not a pass.

The independent [verifier](../../tools/experiments/mat003_perf/verify_s2f.py)
requires six complete cases, correct order, exact registration fields,
consistent raw work arrays and zero timing arrays. It rejects changed
artifacts, invented worker observations, missing nonquiet work and vacuous
reactive results. Dedicated [negative tests](../../tools/experiments/mat003_perf/test_s2f_evidence.py)
check representative refusal cases.

From repository root in the registered Ubuntu 24.04/GCC 13.3 Linux host:

    python3 tools/experiments/mat003_perf/s2f.py --output build/mat003-s2f/preflight-001
    python3 tools/experiments/mat003_perf/verify_s2f.py build/mat003-s2f/preflight-001

The [GitHub-hosted job](../../.github/workflows/mat003-s2f.yml)
runs the collector and verifier separately and preserves raw evidence for 30
days. Bounds are 180 seconds per compiler process, 120 seconds per fixture,
1,200 seconds total; no competing benchmark job or external runner.

The executable also contains an optional diagnostic timing path, but the
registered collector **only invokes qualify mode**. No collected nanosecond
arrays are permitted in the preflight. Any independently invoked timing
before its own formal registration is unqualified diagnostic data. Process
peak RSS is not additive with World resident-cell accounting; no allocator
overhead, cache causality, hardware-counter result or candidate advantage
is claimed.

## S2A/S2B remain unadmitted

The parent [S2 proposal](mat-003prepass-registration.md#s2-performance-feasibility-proposal--not-admitted)
requires eight E8 physical/capacity contrasts and eight matched E8/E16
contrasts: 16 × seven independent interleaved AB/BA process pairs =
**224 primary processes**. An optional follow-on S2B has 23 further
full-grid word64 E8/E16 contrasts = **322** more processes. These counts are
budget proposals, not authorizations or measured results.

Before those runs, qualify all 24 source-control contexts, immutable
candidate builds without correctness observers or per-tick semantic capture,
source-matched observed twins, actual background worker execution,
conservation and input/source/sink ledgers, registered binary/fixture hashes,
real clear events and clear-time observability. Record startup separately
from 120-tick warmup and per-process sampled ticks. E16 no-wrap runs
cannot substitute for actual rollover cost, and periodic amortization is
a projection, not elimination of clear hitches.

**Next step:** complete the separately registered full source matrix and
correctness-observed/timing-twin qualification before requesting a distinct S2A
timing admission. Keep #204 and G-final open, GEN-006 persistence unimplemented,
and the production 64-bit E8 carrier unchanged.


## Actual hosted preflight readback — 2026-10-22

[CI run 39867638084](https://github.com/techrote/cybersand/actions/runs/39867638084) passed six of six untimed source-control fixtures and all eight preflight evidence tests. The independent verifier passed 57 raw file size/hash checks. [Documentation run 39867638180](https://github.com/techrote/cybersand/actions/runs/39867638180) also passed for the apparatus source. The [dated evidence report](../audits/2026-10-22-mat003-s2f-preflight.md) and [compact machine index](../audits/mat003-s2f-2026-10-22/hosted-summary.json) retain source/binary/artifact identities and earlier failures. The first non-vacuous active scene failed and was corrected to alternate Water/Sand sources; its raw failure artifact remains independent. Work tallies and process RSS are not speed measurements. The remaining 18 source contexts and all S2A/paired performance comparisons stay held.


## Full source matrix and candidate twins — 2026-10-23

[CI run 39870102635](https://github.com/techrote/cybersand/actions/runs/39870102635)
completed the next untimed gate. All **24/24** registered source-control contexts
passed, including the eighteen contexts held after the six-specimen preflight.
Independent source readback checked **93 files** with zero errors.

The dependent candidate job then built all seventeen S1 arms twice from one
immutable per-arm overlay: an observer-enabled correctness form and an
observer-off timing-twin form. Both forms ran untimed at active-512-w4 and
quiet-2048-w1. The resulting **34 builds / 68 fixture executions** passed
independent readback of **1,075 files** and all **68 cases**. Non-source observed
four-worker candidates produced direct dispatch/background-worker task evidence;
observer-off twins retained zero observer counts. Pair members matched exact
registered semantic/work/input/Water-ledger fields, and candidate semantics/work
matched the source reference at both anchors.

The retained artifacts are source
[12465598582](https://github.com/techrote/cybersand/actions/runs/39870102635/artifacts/12465598582)
(`sha256:f4ff6e4baf81e44c0e7b09e82b66131272a1b5445ba4c7f2bc69431f0f10a908`)
and candidate twins
[12466540426](https://github.com/techrote/cybersand/actions/runs/39870102635/artifacts/12466540426)
(`sha256:eaef86b77775e4f8b266879db4726e4523f98c9ee62988c5e21e073e03eb9b45`).
See the [dated evidence](../audits/2026-10-23-mat003-s2f-full-and-twins.md).

This qualifies the source-context and twin prerequisites only. S2A timings remain
unadmitted until a new registration freezes its 16 contrasts, seven alternating
AB/BA pairs per contrast, timing-capable observer-off apparatus, flags/hashes,
warmup/horizon, process order, budgets and stop rules. Wide-epoch clear
**correctness** is inherited from S1, but clear latency remains a separate timing
requirement and no speed or carrier winner is claimed here.


## S2A apparatus qualification and narrow admission — 2026-10-23

The separately preregistered S2A apparatus is now qualified and the exact primary
paired schedule is admitted, but no S2A timing run has executed.

The first apparatus run,
[39871650103](https://github.com/techrote/cybersand/actions/runs/39871650103),
preserved a verifier-only failure after 17/17 builds and 25/25 qualifier
executions: the readback still expected registration v2 after the preregistered
statistics amendment had advanced it to v3. The retained failed artifact is
12467345034. No timing was admitted.

The corrected
[run 39872073828](https://github.com/techrote/cybersand/actions/runs/39872073828)
passed **17 sealed builds, 25/25 untimed qualifier contexts, 940-file independent
readback and 25/25 independent case checks**. The admitted apparatus artifact is
[12466348465](https://github.com/techrote/cybersand/actions/runs/39872073828/artifacts/12466348465),
`sha256:ef0720eeca60dbe4daa7a05eaa5d792dbcb5138875e5d37f564fe6579b8d9a4a`.

Atomic admission commit
`e40cc0d060f4a26ead664ad5c6787a7aafd53cfe` changed registration v4 to
`admitted-paired-timing` and, in the same commit, changed the S2A workflow to
**manual `workflow_dispatch` only**. The timing runner is bound to the exact
qualified binary artifact and published source/evidence hashes. No S2A timing
workflow was started by admission.

Admitted scope is exactly **16 contrasts × seven alternating AB/BA fresh-process
pairs × two processes = 224 processes**, with seed 204, 120 warmup ticks and
256 measured ticks. Input cost and startup remain outside `tick_ns`; the
primary pair ratio is B/A mean tick latency over the full 256-tick sample.

S2B, wide-epoch clear-latency timing, fixed-memory conclusions,
Windows/Wasm/Godot performance, E24/E32, carrier selection, production migration
and GEN-006 persistence remain held. See the
[dated S2A admission evidence](../audits/2026-10-23-mat003-s2a-admission.md).
