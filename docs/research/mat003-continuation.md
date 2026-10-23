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

**Current GCC13.3 compiler-output diagnosis:** the [source-bound assembly summary](../audits/mat003-continuation-2026-10-23/s2p-assembly-summary.json) retains actual instruction sequences and hashes from the first hosted attempt. WCLEAR failed in that attempt; its failure does not turn these compiler-output diagnostics into timing evidence.

| Emitted wrapper, including entry/return | P1 packed9/10 static instructions | P2 compact9/10 | C64 word |
|---|---:|---:|---:|
| material getter | 12 | 3 | 3 |
| state_a getter | 12 | 4 | 4 |
| state_a setter | 26 | 9 | 9 |
| epoch clear | 21 | 4 | 4 |
| whole-cell copy | 6 | 6 | 4 |
| whole-cell swap | 19 | 19 | 6 |

P1 state_a getter retains an eight-iteration `movzbl`, variable shift, OR and loop branch. Its setter retains that reconstruction plus a second eight-iteration byte-scatter loop. P2 state_a reads emit `movq (%rdi), %rax; shrl $16, %eax` and its partial setter matches the word control's load/mask/store sequence. These are ordinary x86-64 word instructions emitted from defined `memcpy`, even though P2's compiler-visible alignment remains1. P1's head getters use byte loads rather than a misaligned 64-bit load; its whole-cell copies/swaps can still contain unaligned word accesses.

Full generated World code supports the same mechanism: for C72 E8, hot `update_cell` is 107 static instructions for P1 versus 80 for P2; `scan_rect`291 versus 246; `transfer_water`862 versus 621; `move_cell`732 versus 662. These whole-function static counts include branches that may not execute and omit dynamic call frequency. They are not tick-time ratios. P1/P2 `tick_phased` coordinator counts are both 368, and their worker trampolines both 40; that narrows the changed code to cell work without measuring barrier/cache effects.

**Ranked explanation:** (1) surviving byte reconstruction/scatter loops and repeated read/modify/write are directly demonstrated and avoidable; (2) increased live loop temporaries/register demand is visible in wrappers, but World spill/runtime share remains unmeasured; (3) 9/10-byte stride and compact whole-record copy costs persist in P2 and may impose residual costs; (4) cache misses, false sharing, vectorization limits and actual unaligned penalties remain unquantified. There are no hardware counters or source profiles from which to assign fractions of the accepted 50% overhead. The implementation-specific instruction penalty is established; the size of the residual intrinsic compact-layout penalty remains unresolved until separately admitted P2 timing.

Repeated head reconstruction and read/modify/write work are the strongest observed mechanisms. Register pressure, surviving accessor calls and temporary values
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
| C128 U128 | 16 / 16 on GCC13.3 Linux and GCC16.2 Windows | 256 KiB | 4 / 16 / 64 |
| C128 DUAL64 | 16 / 8 on GCC13.3 Linux and GCC16.2 Windows | 256 KiB | 4 / 16 / 64 |

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
[`wclear-registration-v3.json`](../../tools/experiments/mat003_continuation/wclear-registration-v3.json)
is the active timing-capable apparatus qualification registration. The original
proposals remain immutable: v2 corrects the inaccurate label-swap description;
v3 freezes the optional measure path and its explicit memory precondition. Formal timing and
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
holding stride at 16. It does not qualify every width/carrier combination.

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
128² cases run uninterrupted to 65535: E16 naturally clears first at 65536, while
E8 naturally clears there because `256 + 256×255 = 65536`. Prepared E24/E32
events at that same global clock are compared with those natural controls.
The qualifier has eight builds, 192 large-resident cases and 16 small controls;
all 208 must pass independent readback. None is a timing observation.

Formal registration must still pin the reviewed source/fixtures, binaries,
compiler/linker, observer qualification, process order, independent verifier,
immutable artifact and readback, then obtain independent admission and explicit
execution authority. The observer-off binary has an optional `--measure` path, but qualifiers never invoke it and emit no timing observations. `timing.py` rejects before clocks/subprocesses unless a separately admitted registration and exact owner authority are supplied. `verify_timing.py` checks the complete 672-process matrix, immutable apparatus, every measured semantic stream against its qualified twin, and descriptive statistics. No timing workflow exists at this checkpoint. After that
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
With seven event values, nearest-rank p95 and p99 both equal the observed maximum;
these are descriptive extrema, not reliable population-tail estimates. Pre-scans
and stamp rewriting establish a specific warm-resident/memory-ownership condition.
Natural E8 and prepared wide events differ in prior stamp writes; independent
admission must approve that scope or amend conditioning before timing. No general
cold-gameplay hitch bound is implied. RNG is the frozen stateless coordinate,
global-tick and stream mix in `World::deterministic_random`, not a rebased seed.
No actual clear-cost observations are published here.

For a later validated normal cost N and incremental clear cost D, the conditional
steady average is `N + D/(2^E−1)`. The first clear is at 2^E; in T ticks the count
is zero below that threshold, otherwise `1 + floor((T−2^E)/(2^E−1))`.
Finite-horizon projected average is `N + D×count/T`. Candidate-specific normal
access and footprint costs must remain in N. Always report the worst observed
clear hitch separately. Wider epochs reduce frequency; individual clear cost
may differ through emitted stores and need not decrease. E24/E32 projections
would not be directly observed natural long-run measurements. A wider candidate
only wins the conditional steady model when its added normal cost is below the
measured narrow-clear maintenance minus wide-clear maintenance; each width needs
its own measured D and the footprint tradeoff remains separate.

## C128 feasibility and GEN-006 consequences

**Current untimed-qualified experimental source:** U128 uses GCC's
`unsigned __int128` only under `__SIZEOF_INT128__`; DUAL64 has two explicit
`uint64_t` members and is the fallback strategy. Both expose the original low64
E8/E16 semantic maps and a neutral high64 lane. This is 128 total logical bits,
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
ABI and code generation are target-specific; GCC documents the target integer-mode
requirement in its [128-bit integer reference](https://gcc.gnu.org/onlinedocs/gcc/_005f_005fint128.html). Neither these source operations
nor a16-byte size establish atomic128-bit updates or a shared ABI with DUAL64.

**Inspected GCC13.3 lowering:** the [C128 assembly summary](../audits/mat003-continuation-2026-10-23/c128-assembly-summary.json) shows current U128 partial state_a writes at 15 static instructions versus 9 for DUAL64, and epoch clears at 11 versus 4; whole-copy wrappers are4 for both. The current native wrapper's low64 abstraction lowers through extra high-lane/register work. The raw 16-bit span crossing bit64 lowers to 15 instructions for U128 (including shifts/`shldq` and two lane stores) versus 13 for DUAL64 (a SIMD mask/merge sequence). No library call occurs in those wrappers. This span is a storage diagnostic overlapping epoch bits, never a World/material field. These observations establish neither a hardware128-bit instruction guarantee nor tick superiority. An alternative direct native field mask may optimize differently and would require its own qualification.

Compared with the existing split World arm, either C128 representation keeps neutral extension in the cell value: no second chunk-owned allocation/index and no separate tail-transfer patches are required. That is a concrete ownership/surface-area simplification, not a measured total complexity or speed result. DUAL64 also avoids the native scalar extension. If a 16-byte stride were chosen independently, C128 would turn the aligned C72/C80 control's otherwise nonsemantic 56/48 padding bits into neutral storage without additional cell-array bytes. This does not justify doubling C64 arrays or assigning future material semantics before a schema proposal.

**Decision:** retain both untimed-qualified C128 candidates and propose
a separate bounded paired-performance registration; tick comparability remains open.
The unadmitted [C128 proposal](mat003-continuation-proposals/c128.json) has five
E8 contrasts and 70 primary processes; the [S2P proposal](mat003-continuation-proposals/s2p.json)
has four contrasts and 56 processes. Both require new actual-workload observer/off
qualification, sealed inputs and independent admission; they are proposals, not
frozen timing registrations or authority to dispatch.
The completed registered results below address tick speed only for two E8 neutral-capacity profiles. Lower total complexity than sidecars and predictable memory behavior under future state schemas remain separate questions; neither follows from `sizeof`. C128 matches aligned C72/C80 array footprint while offering more
neutral capacity, but doubles C64 dense cell bytes. Portability, larger copies,
register pressure and future schema ownership remain explicit tradeoffs.

MAT-003 may consider P2 and C128 for later performance testing, but no production
carrier or capacity schema is selected. GEN-006 should keep durable semantic
records independent of C++ padding, endian layout and native128 ABI. Epochs
remain scheduling stamps, separate from incarnation/mutation/save/reconcile
receipts. The [existing handoff](mat-003prepass-gen006-handoff.md) remains the
contract proposal; persistence/streaming and physics are unchanged.

## Evidence, confidence and next gate

| Claim | Confidence and practical limit |
|---|---|
| Accepted packed ~1.50× S2A ratios | Accepted evidence for the exact registered Linux active-512-w4 workload; unchanged. |
| Avoidable reconstruction/scatter work | High confidence from inspected GCC13.3 P1/P2 wrappers and generated World assembly; no dynamic share of slowdown assigned. |
| Cache/unaligned/vectorization causality | Unresolved without counters/profiles or controlled admitted timing; geometry alone is insufficient. |
| P2 and C128 correctness | Source review and untimed fixtures; exact-current immutable readback is owned by the dated audit. Full new-World sanitizers are a gap; storage UBSan is separate. |
| Wide prepared-event equivalence | Bounded to the frozen scenes, populations, current predicates, equality-only consumers and immediate-clear schedule; natural E24/E32 history is unobserved. |
| Actual wide clear cost and amortized benefit | Complete authorized WCLEAR run now measures prepared-resident event latency and paired excess; conditional projections retain cache/preparation limitations. See the results audit below; no production ranking. |
| C128 versus aligned tick cost | Measured in the exact E8 neutral-capacity two-anchor campaign: active medians near aligned; quiet U128 clear-inclusive penalty. No equivalence/production winner; see final results below. |
| Physical arrays and state capacity | Exact arithmetic/tested ABI within stated platforms; allocator/World/process totals require component accounting. |
| Other platforms and future state semantics | Windows diagnostics, Wasm/Godot, durable state and future high64 schema are separately unqualified. |


The complete [GCC13.3 untimed run](https://github.com/techrote/cybersand/actions/runs/39885505290) passed S2P5, WCLEAR208 and C1284 fixture arms on hosted checkout `f7c80a47da8bd1c87ac84b2f7281120a4fcc0796`, from experimental source `c7d7bf6f3c085f68332c30384c9742dd0ca55f93`. The [immutable artifact summary](../audits/mat003-continuation-2026-10-23/hosted-qualification-summary.json) binds the downloaded archive, registrations, binaries, verifier and complete raw records. No event latency was collected.

The [dated audit](../audits/2026-10-23-mat003-continuation.md) owns actual command,
source, platform, artifact and independent-review outcomes. Source mechanisms,
derived physical arithmetic, unregistered local diagnostics and admitted S2A
ratios have deliberately different evidential status. The later result sections record separately admitted optimized-packed, C128 and wide-clear evidence. Counters/profile causality, Windows performance, Wasm/Godot, future state schemas and production acceptance remain unqualified.

## WCLEAR timing admission checkpoint

**Approved admission checkpoint; execution subsequently completed below:** the [independent admission](../audits/2026-10-23-wclear-admission.md) admits only the exact 672-process prepared-resident WCLEAR protocol. Its separately sealed registration sets formal timing admission true while execution authority remains false. The manual-only workflow requires an owner-established receipt for the exact registration hash and execution commit. At that admission checkpoint no dispatch or timing had occurred. This supersedes the earlier WCLEAR admission-pending checkpoint; packed/C128 timing and performance acceptance remain held.

## Complete authorized WCLEAR evidence

**Current measured conditional protocol:** [run39889832605 results](../audits/2026-10-23-wclear-results.md) supersede the earlier WCLEAR execution-pending/unmeasured checkpoint. All672 processes across48 contexts are retained with raw hashes and independent readback. Quiet w1 event medians rise from roughly0.062–0.098ms at512² to2.385–2.510ms at2048²; the maximum event tick is4.739428ms in E32/2048²/active/w1. All spikes and the negative paired excess are retained. Width reduces rollover frequency, not the existence of an individual hitch. Prepared-state/store/cache histories constrain comparisons; no isolated-loop, natural E24/E32 long-run, carrier break-even or C128 speed claim follows. The dated results audit owns final independent disposition and exact evidence identities.

## S2P actual-workload qualification and timing admission

**Approved admission checkpoint; execution subsequently completed below:** the [S2P independent admission](../audits/2026-10-23-s2p-admission.md) supersedes the earlier56-process proposal-pending state only. [Untimed run39919157903](https://github.com/techrote/cybersand/actions/runs/39919157903) qualified ten actual-workload observed/off builds for five E8 arms on active512w4. Independent readback checks419 sealed files and all ten cases; the [artifact summary](../audits/mat003-continuation-2026-10-23/s2p-qualification-summary.json) pins the complete source/binaries. Actual E8 transition255→1 at tick256 is retained. All twins match final content/state hashes, ledgers and per-tick visits/phase work; participation counts cover warmup plus samples. The workload uses the accepted diagnostics-disabled S2A fixture semantics; full S1 carrier-state evidence remains the separate correctness prerequisite. No full per-tick semantic-byte trace is claimed for this actual workload.

Only four contrasts × seven fresh-process AB/BA pairs =56 processes are admitted: original packed versus safe memcpy for C72 and C80, plus C64-word versus each safe compact arm. Each process has120 warmup and256 sampled ticks at seed204, including E8 clear tick256. Seven B/A mean-tick ratios are the primary observations; all raw samples and spikes must be retained. This is prospective reuse of S2A definitions, with no dataset merge or repetition of S2A. P3/aligned and P4/split remain preserved controls in the accepted evidence/compiler diagnosis; no new performance contrast for them is admitted here. Independent timing admission does not authorize dispatch or establish an optimized-packed performance result. Both PRs stay draft; C128 timing and production migration remain held.

## Complete independently verified S2P timing evidence

**Current measured E8 active512w4 results:** [run39920964814 results](../audits/2026-10-23-s2p-results.md) supersede the earlier S2P execution-pending/unmeasured checkpoint. All56 processes,28 fresh-process pairs and14,336 tick samples are retained and independently verified. Median P2/P1 B/A mean-tick ratios are0.65775129(C72) and0.66364571(C80); median P2/C64-word ratios are0.99622354 and1.00885236. All raw ratios, spread, per-process percentiles/startup/input/RSS and extrema are retained. One local Git-context reader refusal and its byte-identical successful readback are recorded without rerunning measurements.

These paired observations plus the GCC13.3 assembly support a substantial avoidable implementation cost in original packed head reconstruction/scatter. The new near-one medians against C64 are not equivalence guarantees or a universal intrinsic-cost conclusion. No cache/unaligned/vectorization causal share is assigned. Accepted S2A ratios remain unchanged and are not merged into this new dataset. Both compact candidates remain architecture options; production schema/carrier selection, C128 timing and GEN-006 changes remain separate. The results audit owns exact identities and scoped independent performance-evidence acceptance. PR211/221 remain draft.

## C128 actual-workload qualification and timing admission

**Approved admission checkpoint; execution subsequently completed below:** the [C128 independent admission](../audits/2026-10-23-c128-admission.md) supersedes the earlier70-process proposal-pending state only. [Untimed run39923189244](https://github.com/techrote/cybersand/actions/runs/39923189244) qualified six observed/off builds and twelve arm/workload cases. Fresh external readback checked306 sealed files and all cases, with the308-file archive unchanged. The [artifact summary](../audits/mat003-continuation-2026-10-23/c128-qualification-summary.json) pins exact source, candidate selection, binaries and registration. Generated aliases/header hashes verify the distinct aligned/U128/DUAL64 representations; matching neutral-zero workload results alone cannot prove their selection.

The five E8 contrasts compare C80-aligned with U128 and DUAL64 on active512w4 and quiet2048w1, plus DUAL64 with U128 on active512w4. Seven alternating AB/BA fresh-process pairs per contrast give70 processes. Every process has120warmup and256sample ticks at seed204, including natural E8clear256. All three carriers have16-byte stride; alignments are8/16/8. Physical cell arrays are4MiB and64MiB at the two resident sizes, separate from World scratch, temperature, descriptors, allocator overhead and processRSS. No C64/compact paired contrast or epoch-width benefit is admitted.

All twelve cases agree within each workload on final content/state hashes, ledgers and complete per-tick visits/phase work. The active observed builds record22405 worker tasks over warmup plus samples; quiet cases and all observer-off counters are zero. The fixture retains S2A diagnostics-disabled semantics. Full S1 high-lane and E16 correctness remain separate prerequisites; this actual-workload contract is not a full semantic-byte trace. Extra C128 capacity remains neutral zero, so this campaign cannot measure an undefined future high64 authoritative state schema or its access cost. No formal C128 timing or performance acceptance follows from admission. At that admission checkpoint, owner authorization was still required; the subsequent exact authorized execution is recorded below. Both PRs remain draft.

## Complete independently verified C128 timing evidence

**Current measured E8 neutral-capacity results:** [run39926130011 results](../audits/2026-10-23-c128-results.md) supersede the C128 execution-pending checkpoint. All70 processes,35 pairs,17,920 tick samples and17,920 input samples are retained and independently verified. Median B/A process-mean ratios are0.991539(U128/aligned,active),1.002677(DUAL64/aligned,active),1.234276(U128/aligned,quiet),1.009461(DUAL64/aligned,quiet), and1.005942(U128/DUAL64,active). These are descriptive results for the registered profiles, not equivalence tests or cross-campaign rankings.

The quiet U128 sample-duration difference is concentrated in the genuine clear-inclusive frame at tick256: median6.016458ms aligned versus8.097801ms U128. This supplementary retained-event partition does not replace the full256-tick registered primary metric, isolate the clear loop or identify cache/instruction causality. Overall maximum8.345338ms is retained. The differently prepared WCLEAR dataset remains separate; C128 wide-epoch timing and long-run maintenance conclusions are not admitted.

All three arrays use16-byte stride; native U128 alignment16 differs from DUAL64/aligned alignment8. Extra capacity remains neutralzero, so no future authoritative high-state access performance or production schema is established. DUAL64 remains a practical portable sixteen-byte option with descriptive timings near aligned on both registered workloads; native U128 has no established active advantage and exhibits the quiet clear-frame disadvantage. Selecting sixteen-byte cells still doubles dense C64 array bytes, and no paired compact/C128 performance comparison exists here. MAT-003 should combine these separately qualified constraints with a state-schema proposal rather than promote a layout from one ratio. GEN-006 durable semantic records stay independent of C++ ABI, padding and endian layout. Neither production carrier/physics nor persistence/streaming changed. Both PRs remain draft.

## Schema and decision continuation

The [state-schema proposal](mat003-state-schema-proposal.md) owns proposed logical fields, extension/lifecycle rules and exact capacity accounting; [ADR-015](../decisions/ADR-015-material-state-schema-and-carrier-gates.md) owns the proposed shortlist and adoption gates. These Planned documents consume the three separate campaigns without promoting production or assigning new solver semantics. Optimized compact and DUAL64 lead the expansion options; C64 stays the baseline, and owner memory/hitch/schema requirements must precede adoption. No new timing is started.

The [semantics and owner-budget review](../research/mat003-semantics-budget-review.md) records the documentation-only technical disposition, default-cap memory gap and unresolved owner worksheet. It preserves the shortlist and blocks adoption or new timing pending explicit decisions.

The [concrete owner offer](mat003-concrete-owner-offer.md) proposes R16-T1 semantics, a256-chunk residency envelope, memory sublimits and prospective native latency/platform gates for explicit review. Its values are Planned recommendations, not owner-approved requirements, measured compliance, production changes or new timing authority.

The owner accepted numeric residency/memory and latency/platform limits in the [concrete offer](mat003-concrete-owner-offer.md) as qualification targets only. R16-T1 remains conditional. The [bounded correctness-only plan](mat003-correctness-only-plan.md) proposes152 cases per platform without implementation, execution or timing authority. Existing production and both draft PRs remain unchanged.

The [exact eight-arm maps and independent oracle contract](mat003-correctness-only-plan.md#exact-eight-arm-mapping-contracts) close the plan review at document level: E8 mapping is retained, expanded E16 uses epoch40–55/R56–71, and C64/E16 is a capability-refusal control. Full endpoint datasets and raw/schema-valid modes are explicit. Independent document review is separate from any future apparatus admission; R16-T1 and execution remain conditional/unapproved.

The [independent mapping/oracle review closure](../audits/2026-10-23-mat003-mapping-oracle-review.md) records all four document findings closed and the exact reviewed document hashes. Apparatus implementation/admission/execution remains a separate gate.

## Eight-map correctness apparatus source completion and execution boundary

The [earlier unexecuted apparatus review](../audits/2026-10-23-mat003-apparatus-held-review.md) retains the failed partial implementation assessment. Its remaining-implementation status was superseded by the [source-completion/review closure checkpoint](../audits/2026-10-23-mat003-apparatus-source-closure.md): full World/oracle coverage, owner inventory, refusal/lifecycle fixtures and staged sealed collector/readback are implemented. Independent source review found no remaining definite implementation blocker. At that source-review checkpoint no build, qualification, sanitizer or timing had run; that historical preparation status is superseded only by the build-only attempt below. Separate toolchain/build authority, independent binary admission and exact owner qualification-execution authority remain distinct gates before cases may execute. R16-T1 remains conditional; production is unchanged and both PRs remain draft. Accepted campaign evidence is preserved.

## Build-only qualification and refused binary admission at5380c76

The later owner-authorized [native Windows build-only checkpoint](../audits/2026-10-23-mat003-build-only-admission.md) supersedes the earlier no-build preparation status only. Independent LLVM-MinGW23.1.0/UCRT and psutil7.0.0 toolchain preflight passed after retaining an external probe-instrumentation failure. The exact apparatus build at5380c76 stopped after two compiler attempts: one clean storage build and one World executable whose compiler exit0 still emitted two warnings. The frozen no-diagnostics gate correctly rejected it and left the32-binary/eight-arm build incomplete. Independent binary admission was **refused**; neither physical executable is admitted or executed. Full raw inputs, probes, binaries, diagnostics and inventories are retained. No source fix, flag suppression, retry, qualification case or timing occurred. Linux was not executed. R16-T1 remains conditional, production unchanged and PR211/221 draft. A new reviewed source/contract and separately authorized bounded build are required before any replacement attempt.

## Reviewed warning correction and replacement build-only gate

The owner subsequently authorized two isolated warning repairs and a new build-only attempt. The [replacement checkpoint](../audits/2026-10-23-mat003-warning-fix-build.md) freezes source6e85fe680b20fc9e67e4572d5d60502be8615524: const-reference role iteration and an exact checked removal of unused capture in generated World copies. Production and accepted baseline sources remain unchanged; no warning flag or diagnostic gate is weakened. All32 Windows compilations completed with status built-execution-held; independent binary review is separately recorded in that audit. The failed5380c76 attempt remains retained. No candidate executable, qualification case or timing is authorized or run; Linux remains unexecuted and R16-T1 conditional.

## Windows correctness-only execution registration

The [exact Windows execution registration and independent admission](../audits/2026-10-23-mat003-windows-execution-admission.md) bind the admitted6e85fe6 source/binaries to152 ordered correctness cases, immutable tooling/verifier identities, resource/retention limits and independent raw readback. Preparation/admission does not grant execution authority: owner authorization of the final registration hash is still required, followed by the explicitly constrained derived authority. No cases or timing ran; Linux remains outside scope, R16-T1 conditional, production unchanged and both PRs draft.

## Authorized Windows correctness attempt stopped incomplete

Owner authorized registration6d5011004ad4fbde2b26348db44483cb4fc4942ad6b71d8caf18347ce5ae09b0. The [retained execution audit](../audits/2026-10-23-mat003-windows-correctness-attempt.md) records one completed storage process followed by small-001 failure: maximum chunk capacity exhausted. Frozen stop rules prevented the remaining150 cases and any retry. Independent frozen readback ran once:15 rejection fixtures and decoder cross-check passed, then incomplete-campaign rejection. No152-case correctness acceptance or timing result follows. Existing source/build admissions remain historical scoped records; runtime qualification is incomplete. R16-T1 remains conditional, Linux unexecuted, both PRs draft and production unchanged.

## Isolated containment repair and blocked replacement

The [containment repair review](../audits/2026-10-23-mat003-containment-replacement.md) freezes sourcea3f4e371d8c01bd97c5f44c598036b1a083676f6: a small-only two-cell inactive Wall band inside the existing256²/four-chunk grid prevents serial outward writes and phased radius-two halo demand by source argument. Full independent endpoint checks and future negative fixtures cover all four sides/corners. The exact prior failed coordinate remains unknown; no physics cause or successful runtime correction is claimed. Replacement preparation retains152 cases/limits and changes48 small fixtures. It is blocked pending new authorized builds, independent binary admission and a complete new execution registration; old binary certificates cannot admit changed source. No generator, build, probe, case or timing was run. R16-T1 conditional, PRs draft, production and all failures unchanged.
