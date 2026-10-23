---
title: MAT-003 continuation decisions and admission boundary
status: Current
document-kind: reference
scope: Source-bound S2P packed diagnosis, WCLEAR-001 apparatus and C128-001 feasibility; timing and production selection remain separately held
canonical-for: [mat003-continuation-decisions, mat003-packed-diagnosis, mat003-wide-clear-admission, mat003-c128-feasibility]
last-reviewed: 2026-10-23
related-documents: [../operations/mat-003prepass-registration.md, mat-003prepass-epoch-consumers.md, mat-003prepass-gen006-handoff.md, ../architecture/chunk-tile-and-buffer-model.md, ../operations/architecture-programme.md]
---

# MAT-003 continuation decisions and admission boundary

## Scope and preserved evidence

**Current source / Planned performance admission:** continuation starts at
`2b2a1dd64f16dc46d5e812b757de73f47df0fb2b`, the head of draft
[PR #211](https://github.com/techrote/cybersand/pull/211) used by accepted
[S2A run 39876455400](https://github.com/techrote/cybersand/actions/runs/39876455400).
Separate child work items under [#204](https://github.com/techrote/cybersand/issues/204)
are [S2P #218](https://github.com/techrote/cybersand/issues/218),
[WCLEAR-001 #219](https://github.com/techrote/cybersand/issues/219) and
[C128-001 #220](https://github.com/techrote/cybersand/issues/220).
[PR #221](https://github.com/techrote/cybersand/pull/221) stacks on #211;
neither PR is admitted for merge or promotion by this report.

The accepted 224-process S2A campaign, its source identities, statistics and raw
artifact `12468697797` (SHA-256
`9de681dde221093dcd740673f50a9549240d1858c86c44c1f85182696dc0a1db`)
remain unchanged. The accepted active-512-w4 median B/A mean-tick ratios are
1.49605/1.51165 for packed C72/C80, 1.01991/1.01797 for aligned, and
1.00001/1.00194 for split, against C64-E8-word. These are source/workload/platform
qualified S2A findings, not new observations. No S2A repetition or S2B is run.

## S2P mechanism and controls

**Current inspected implementation:** accepted
[`Packed<1/2>::word`](../../tools/experiments/mat003_prepass/carriers.hpp)
reconstructs a head from eight byte loads and shift/OR operations. `Cell::field`
reads that head, masks a field and reconstructs its bytes on a partial write.
`EngineCell::state_b_value` also invokes `delay_mask`, which reads material;
`set_state_b` does so before another partial update. The inlined World path can
therefore request several head reconstructions for one logical operation.
`update_cell`, `scan_rect`, `move_cell`, `transfer_water`, granular support and
`begin_tick` are compiler-output review targets. Source accessor counts alone
are not dynamic instruction counts: common-subexpression elimination and
inlining depend on context.

P1 retains the accepted 9/10-byte implementation. P2 is the sole recommended
optimized compact mechanism at this checkpoint: an eight-byte `memcpy` head
load/store with the original safe 1/2-byte tail API. P3/P4 retain the accepted
aligned and dense chunk-owned split controls. The candidate lives in
[`candidates.hpp`](../../tools/experiments/mat003_continuation/candidates.hpp);
all World substitutions occur in generated copies through
[`overlay.py`](../../tools/experiments/mat003_continuation/overlay.py).
There are no typed unaligned pointer dereferences, compiler bitfields, extra
overreads or aliasing casts. Little-endian hosts use `memcpy`; other endian
hosts fall back to the accepted explicit little-endian byte reconstruction.

**Diagnostic hypotheses, pending compiler/artifact qualification:** repeated
head reconstruction and read/modify/write work are the strongest source-level
mechanisms. Register pressure, surviving accessor calls and temporary values
must be evaluated in the generated World output. Compact stride changes address
arithmetic and crossing opportunities, but neither source inspection nor elapsed
S2A times establish cache-miss, bandwidth or unaligned-access causality. The
four-worker phase protocol is unchanged; observer-off assembly compiles dispatch
observers out. Worker dispatch and false-sharing costs cannot be attributed
without separate dynamic evidence. Hardware counters/source profiles are absent.

The frozen compiler flags are GCC 13.3.0
`-std=c++20 -O2 -DNDEBUG -Wall -Wextra -Wpedantic -pthread`, matching S2A.
The collector retains both isolated accessor wrappers and full optimized World
assembly. Static instruction counts describe emitted code, not dynamic
frequency, register spills on an executed path, measured latency or speed.
GCC itself notes that optimization choices depend on target/configuration;
see its [13.3 optimization reference](https://gcc.gnu.org/onlinedocs/gcc-13.3.0/gcc/Optimize-Options.html).
No new production performance rankings are admitted.

## Physical storage and cache-footprint accounting

**Derived array arithmetic; ABI observations require their platform qualifier:**

| Carrier | Cell stride / alignment on tested x86-64 ABIs | Default 128² chunk cell arrays | 512² / 1024² / 2048² arrays, MiB |
|---|---|---:|---:|
| C64 word | 8 / 8 | 128 KiB | 2 / 8 / 32 |
| C72 P1/P2 compact | 9 / 1 | 144 KiB | 2.25 / 9 / 36 |
| C80 P1/P2 compact | 10 / 1 | 160 KiB | 2.5 / 10 / 40 |
| C72/C80 aligned | 16 / 8 | 256 KiB | 4 / 16 / 64 |
| C72/C80 split | base 8 / 8, separate tail 1/2 | 128 + 16/32 KiB | 2.25/2.5 / 9/10 / 36/40 |
| C128 U128 | 16 / 16 on local GCC 16.2 Windows | 256 KiB | 4 / 16 / 64 |
| C128 DUAL64 | 16 / 8 on local GCC 16.2 Windows | 256 KiB | 4 / 16 / 64 |

At 4096² these arrays would occupy 128, 144, 160 or 256 MiB respectively;
that optional WCLEAR scale is excluded pending explicit feasibility review.
At 2048² a 16-byte carrier adds 32 MiB over C64, 28 MiB over packed C72 or
24 MiB over packed C80, before any other World resource. Full temperature
allocation adds another 8 MiB there (2 bytes/cell). It is optional and separate.
Activity, descriptors, scratch, snapshots, allocator overhead, tail-vector
descriptors and process RSS must be accounted separately. S1 memory receipts
retain capacity versus used bytes; its legacy aggregate already includes cells,
temperature and activity and must not be added again. Split in these World
controls is eagerly dense at chunk admission, not sparse optional-state evidence.

For a hypothetical 64-byte cache line and a complete residue cycle, a 9-byte
stride visits all 64 start residues: full records cross in 8/64 positions and
eight-byte heads in 7/64. A 10-byte stride has 32 start residues: full records
cross in 4/32 positions for an even base, 5/32 for an odd base; head crossings
are respectively 3/32 and 4/32. These are geometry counts, not observed misses or penalties. Eight-byte
alignment guarantees that an eight-byte head does not cross a 64-byte line;
the actual allocation base, emitted access width, field access subset and
hardware matter. Compiler-visible packed alignment is one byte even when an
allocation happens to begin at a more aligned address.

## WCLEAR-001 exact proposal and correctness boundary

**Current experimental apparatus / Planned admission:**
[`wclear-registration-v2.json`](../../tools/experiments/mat003_continuation/wclear-registration-v2.json)
is the active untimed qualification registration. The original proposal remains
immutable; v2 corrects its inaccurate label-swap description. Formal timing and
execution-authorized fields are both false. The proposed performance matrix is
four widths × three resident sides (512/1024/2048) × two scenes × workers1/4 =
48 contexts. Seven alternating AB/BA fresh-process pairs of ordinary/event
would require 672 processes, with one event per process, at most 120 seconds per
process and a 7200-second total wall budget. Budget feasibility remains an
admission question; a partial campaign would be incomplete. 4096² is excluded.

E8/E16 retain their accepted low-word maps. E24 uses bits40–63 and an actual
32-bit World counter masked to 24 bits; E32 uses bits40–71 across the low word
and first tail byte. Both preserve material16/state_a16/state_b8. E24 can
arithmetically fit C64; E32 requires at least C72. This implementation restricts
wide-cell prototypes to a two-byte tail and tests C80-aligned for every width,
holding stride at16. It does not qualify every width/carrier combination.

Preparation takes place between successful ticks at global tick255. Natural
E8 events keep every raw stamp unchanged. A prepared wide event maps stamps
equal to the previous counter to its new maximum, and all other stamps to zero.
The verifier checks every current predicate and the full independent semantic,
temperature, activity/deadline and granular-support record before and after
preparation. Global tick, RNG schedule, residents, interest exclusion and sleep
metadata do not change. The very next actual `World::tick()` wraps and invokes
the production clear loop. This transformation is valid only under the audited
equality-based stamp consumers and this immediate-event schedule; it is not a
general continuation codec or arbitrary history-restoration proof.

The matched ordinary state uses current128/noncurrent0, so the next129 stamp
cannot alias a stale stamp. A correctness-observed twin counts real clear entry
and checks all resident stamps are zero immediately after the real loop, before
events or simulation restamp cells. The observer-off twin compiles the hook out.
Both retain full post-event records and four interest-reentry ticks. Additional
128² cases run uninterrupted to65535: E16 naturally clears first at65536, while
E8 naturally clears there because `256 + 256×255 = 65536`. Prepared E24/E32
events at that same global clock are compared with those natural controls.
The qualifier has eight builds, 192 large-resident cases and16 small controls;
all208 must pass independent readback. None is a timing observation.

Formal registration must still pin the reviewed source/fixtures, binaries,
compiler/linker, observer qualification, process order, independent verifier,
immutable artifact and readback, then obtain independent admission and explicit
execution authority. No timing workflow exists at this checkpoint. After that
gate, a separately reviewed `workflow_dispatch` workflow must execute only the
registered schedule. Do not infer a dispatch command for a nonexistent admitted
workflow or repurpose S2A's workflow.

**Planned measurement contract:** observer-off nanoseconds around `World::tick`
only; retain startup/input costs separately. Report process-pair clear/ordinary
latency, paired excess and ratio, median/min/max/MAD, and explicitly descriptive
nearest-rank event p50/p95/p99/max across seven independent processes per context.
Retain RSS, resident cells and physical arrays, actual clear counts/completed
tick identities, visits, phase jobs and qualified background participation.
Do not discard spikes or treat events within a process as independent samples.
No actual clear-cost observations are published here.

For a later validated normal cost N and incremental clear cost D, the conditional
steady average is `N + D/(2^E−1)`. The first clear is at2^E; in T ticks the count
is zero below that threshold, otherwise `1 + floor((T−2^E)/(2^E−1))`.
Finite-horizon projected average is `N + D×count/T`. Candidate-specific normal
access and footprint costs must remain in N. Always report the worst observed
clear hitch separately. Wider epochs reduce frequency; individual clear cost
may differ through emitted stores and need not decrease. E24/E32 projections
would not be directly observed natural long-run measurements.

## C128 feasibility and GEN-006 consequences

**Current experimental source / Planned qualification:** U128 uses GCC's
`unsigned __int128` only under `__SIZEOF_INT128__`; DUAL64 has two explicit
`uint64_t` members and is the fallback strategy. Both expose the original low64
E8/E16 semantic maps and a neutral high64 lane. This is128 total logical bits,
not a128-bit epoch. No extra material/solver meaning is assigned. Low-lane
partial writes preserve the whole high lane; whole-record moves copy it and
material replacement resets it. The inherited S1 neutral API observes its low16;
additional independent storage tests and generated World probes exercise the
remaining high48 through movement, swap and forced clear.

The qualifier reuses full S1 serial/phased1/phased4, natural two-wrap E16,
large forced clears, Water ledgers, nonzero Empty/high-state boundaries,
temperature and lifecycle checks. Full semantic traces must match an
independently verified C64-word control. C128 E24/E32 remain separately gated;
the WCLEAR aligned-carrier result cannot qualify them. Native128 availability,
ABI and code generation are target-specific. Neither these source operations
nor a16-byte size establish atomic128-bit updates or a shared ABI with DUAL64.

**Decision:** retain both C128 candidates for untimed qualification and propose
a separate bounded paired-performance registration only after complete readback.
Comparable tick speed, lower total complexity than sidecars and predictable
memory behavior are questions for that registration, not conclusions from
`sizeof`. C128 matches aligned C72/C80 array footprint while offering more
neutral capacity, but doubles C64 dense cell bytes. Portability, larger copies,
register pressure and future schema ownership remain explicit tradeoffs.

MAT-003 may consider P2 and C128 for later performance testing, but no production
carrier or capacity schema is selected. GEN-006 should keep durable semantic
records independent of C++ padding, endian layout and native128 ABI. Epochs
remain scheduling stamps, separate from incarnation/mutation/save/reconcile
receipts. The [existing handoff](mat-003prepass-gen006-handoff.md) remains the
contract proposal; persistence/streaming and physics are unchanged.

## Evidence, confidence and next gate

The [dated audit](../audits/2026-10-23-mat003-continuation.md) owns actual command,
source, platform, artifact and independent-review outcomes. Source mechanisms,
derived physical arithmetic, unregistered local diagnostics and admitted S2A
ratios have deliberately different evidential status. Optimized-packed and C128
World timing, wide clear cost, counters/profile attribution, Windows performance,
Wasm/Godot and production acceptance remain unqualified until separately admitted.
