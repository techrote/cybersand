---
title: Preserved performance observations from earlier checkpoints
document-kind: historical-record
canonical-for: [historical-performance-observations]
retrieval-scope: historical-only
status: Current
scope: Verbatim performance-record sections retained from source checkpoint 126175c; historical runs only, never current acceptance
last-reviewed: 2026-09-08
related-documents: [../operations/profiling-observability-and-performance.md, ../operations/web-threading.md, ../reference/validation-evidence.md]
---

# Preserved performance observations from earlier checkpoints

**Historical record. Exclude from ordinary Current-behavior retrieval.**
This archive preserves the following sections as they appeared at local Git
checkpoint `126175cfc4dd1fb8659212f62b9b517bac54d8c2`, before the structural
documentation rewrite on 2026-09-08. Their reported dates, platforms, failures,
numbers, and uncertainty remain unchanged. Words such as “current,” “now,” or
“final” within an extract refer to its original checkpoint.

The originating source/checkpoint of each *test execution* is limited to what
the extract and linked raw evidence record; the documentation preservation
commit does not supply missing test provenance. Claims here are not fresh runs,
current binary validation, target-hardware guarantees, or proof that an old
rollback archive is available. [Current evidence](../reference/validation-evidence.md)
and the [profiling procedure](../operations/profiling-observability-and-performance.md)
are maintained separately.

## Hosted 2026-08-27/28 records

Original document: `docs/operations/profiling-observability-and-performance.md` at the preservation commit above.

### 2026-08-27 hosted-container observations

These are checkpoint observations, not portable performance promises because
the hosted CPU identity and contention are not a frozen reference platform.
Every row used 512×512 dense cells or the named 1024×544 sparse fixture for 120
ticks with 128-cell chunks and an optimized LTO build.

| Fixture | Backend/workers | Allocation mode | Mean tick | Authoritative hash relation |
|---|---|---|---:|---|
| Dense 512×512 | Serial / 1 | preallocated | 13.40 ms | Behavioral comparison only; scan semantics differ |
| Dense 512×512 | Phased / 1 | preallocated | 12.87 ms | Same phased semantics |
| Dense 512×512 | Phased / 4 | preallocated | 5.05 ms | Exact state/content match with phased / 1 |
| Dense 512×512 | Phased / 8 | preallocated | 3.74 ms | Exact state/content match with phased / 1 |
| Sparse 1024×544 | Phased / 4 | preallocated | 0.86 ms | Four jobs per phase; below parallel threshold |

All preallocated rows reported zero tick-time chunk and temperature allocations.
The dense fixture exposed 18, 18, 17, and 17 jobs across its four phases. Eight
workers won this particular hosted run, unlike an earlier run in the same environment; that
variance reinforces that these numbers are observations rather than a worker
selection policy. The sparse fixture averaged four jobs per phase, below the
default dispatch threshold of eight, and intentionally stayed sequential.

### 2026-08-28 m6/m7 checkpoint comparison

Three interleaved default native benchmark runs compared the m6 checkpoint with
the m7 themed-material catalogue on the same hosted container. Both checkpoints
produced authoritative state hash `0x31407faccd6020d7` in every run.

| Checkpoint | Observed mean-tick range | Interpretation |
|---|---:|---|
| m6 rollback baseline | 17.79–18.90 ms | Hosted reference only |
| m7 themed materials | 17.90–18.56 ms | No measurable native simulation regression |

The ranges overlap and are smaller than ordinary hosted contention variance, so
they do not establish a speedup or a portable budget. The 41 inert themed solids
have radius-zero rule kernels; Oak Timber and Thatch reuse the existing bounded
combustion kernel. Their analytic surface detail runs in the presentation shader
and therefore does not add authoritative simulation work. A target-GPU profile
of mixed flair branches, HDR emission, and the half-resolution glow pass remains
required before setting a rendering acceptance threshold.

### 2026-08-28 m7/m8 temporal-fidelity comparison

Five interleaved 512×512 dense, 120-tick, phased/eight-worker runs compared the
m7 rollback archive with m8. Observed m8 means were 4.98, 5.40, 5.91, 6.02,
and 8.20 ms; m7 means were 6.17, 6.48, 7.06, 7.14, and 7.65 ms. The medians are
5.91 and 7.06 ms/tick respectively (about 16% lower for m8), though the ranges
overlap under hosted contention. State hashes differ by design because Smoke
now ages and culls.

The m7 Windows profile supplied with this checkpoint showed Process Time
65.26 ms alongside a 64.49 ms hard-collider peak, while Rapier itself reported
only about 0.06 ms. m8 changes collision extraction from 128×128 to 64×64
packets, reducing the indivisible rebuild area to one quarter. The budget still
stops only between packets, so this is a bounded-work design improvement, not a
claim that the target peak is eliminated. Repeat the same fragmented-hard-solid
scene on Windows and compare `collider peak` before accepting the fix.

### 2026-08-28 m8/m9 GPU-only presentation expansion

m9 does not change native simulation source, cell layout, render snapshot size,
palette size, four-texel program rows, or glow texture count. It binds the
already-current RG8 texture under one named sampler so helper functions can read
four nearest neighbours. The normal palette path therefore grows from six to
approximately ten texture fetches per displayed fragment; a snapshot transition
can evaluate old and new colour/relief paths. Selected material branches add
arithmetic/hash work but no sampler access.

The half-logical-resolution emission source grows from 9 to 13 positions, each
reading the existing world/program textures. The full-resolution additive glow
composite grows from 1 to 13 filtered reads. `G` remains the useful full glow
A/B control. These are deliberately GPU-biased costs, but the headless hosted
driver supplies shader compilation rather than representative GPU time. Record
GPU frame time at 1920×1080 with m8/m9 and `G` on/off before defining tiers.

`F3` hides the debug statistics label and causes `update_status()` to return
before building its formatted strings. Counters still update so restoring the
readout presents current data.

## Local 2026-09-08 Auto/four-worker records

Original document: `docs/operations/web-threading.md` at the preservation commit above.

Retained Auto validation (2026-09-08): Windows reported 12 logical threads and selected
six workers. All 14 Godot fixtures passed, including Auto boundaries and the
benchmark regression; the expanded full-run regression passed separately after
fixing a typed-array initialization error. Native and Chromium 152 reference
benchmarks completed all eight cases with matching final level hashes across
worker counts and platforms. The 600-tick stress runs also matched level hashes
and move totals between native and Web. Browser Escape cancellation left the
player's Neon Works world at its original tick 0; no console errors or warnings
were observed in the successful run.

| Workload | Native mean tick | Web mean tick | Web p95 tick |
| --- | --- | --- | --- |
| 480×480, 4 workers | 4.79 ms | 6.15 ms | 11.02 ms |
| 480×480, 6 workers | 3.82 ms | 4.73 ms | 6.48 ms |
| 960×960, 4 workers | 17.88 ms | 18.16 ms | 20.29 ms |
| 960×960, 6 workers | 14.17 ms | 14.61 ms | 17.00 ms |
| 960×960, Auto stress, 600 ticks | 17.08 ms | 21.23 ms | 28.28 ms |

These are historical single-run reference measurements, not a promise of 60 FPS. The long
stress case exceeds the 16.67 ms tick budget. Native reports are under
`validation/local/20260908-150349/` and `20260908-150723/` in the workspace;
the browser summary is `validation/local/auto-workers-20260908/browser-reference.json`.
The native regression suite also passed 39/39. Both final exports passed six
HTTP payload checks. That checkpoint's historical BUILD_ID check listed seven
hash differences; the [current audit](../audits/2026-09-08-documentation-audit.md)
records the separate fresh check. Historical locks are preserved.

### Earlier four-worker baseline

Historical earlier local result (2026-09-08, Chromium 152 on Windows): four workers active,
120/120 exported-level hashes identical to one worker, 98,286 moves in each run,
480 parallel phases, no browser console errors/warnings, and the native C++
exception rejection probe passes. Mean native tick time was 4.2365 ms for one
worker and 2.9923 ms for four; this is one short fixture run, not a general FPS
or cross-device performance guarantee. Native regressions passed 39/39 and
Godot fixtures passed 12/12; the async parity fixture also passed separately.
The threaded Foundry local save/load round trip reproduced the entire 17,712
character CYSD1 export with no error and kept four workers. Material Lab,
Waterworks, Foundry, and Neon Works ran interactively with no rejected render
snapshots observed. Both profiles passed all six HTTP payload checks.

At that earlier checkpoint, the historical consistency checker reported five BUILD_ID source
hash differences, including the locally configured project.godot. Historical
locks have not been rewritten; this is not an audited M11 release attestation.

An initial pool of 12 prewarmed pthreads stalled the browser acceptance sequence.
That earlier successful export used 24 to accommodate world replacement and runtime
threads. The probe yields between ticks and worker-count runs. Keep this
lifecycle fixture when changing pool sizing; the precise lower safe bound has
not been established.

## Sandspiel-study hosted benchmark record

Original document: `docs/research/sandspiel-performance-and-material-port.md` at the preservation commit above.

### Historical 2026-08-27 hosted benchmark record

The retained record below does not identify the current local build or establish
fresh sanitizer coverage. Consult the audit's evidence inventory before reusing
the figures as a comparison; missing original raw evidence must remain a gap.

The final density/leveling 2026-08-27 hosted run measured 512×512 dense phased
ticks at 12.87 ms with one worker, 5.05 ms with four workers, and 3.74 ms with eight workers. Each
phased run produced identical state/content hashes and zero World-owned tick
allocations. These single-run observations are environment-specific, not
target-hardware promises or evidence that eight workers will win on other CPUs.
Normal, ASan+UBSan, and TSan suites passed.
