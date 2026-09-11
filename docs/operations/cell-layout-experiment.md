---
title: Cell layout experiment registration and execution
status: Planned
document-kind: runbook
scope: Issue 16 staged native representation research, preregistered before candidate code; no production migration
canonical-for: [cell-layout-experiment]
last-reviewed: 2026-09-11
related-documents: [architecture-programme.md, architecture-programme-prompts/cell-layout.md, ../audits/2026-09-10-issue-16-cell-layout.md]
---

# Cell layout experiment

## Status and boundaries

**Current research checkpoint:** L1 completed its first owner-released campaign
on September10–11; see the [dated results](../audits/2026-09-10-issue-16-cell-layout.md#l1-results).
Execute [issue 16's full charter](architecture-programme-prompts/cell-layout.md)
in staged order. The original owner timing hold was released with “Ready for the
first uncontended run. Start.” Do not overlap measurements with issue15 or builds.
L1 completion is not issue completion or G-L acceptance; L2–L4 remain mandatory.
No merge, deployment, remote mutation, production layout choice or loaded DLL replacement.

Editing/build root: `C:/kybersand/worktrees/issue-16-cell-layout`, branch
`codex/issue-16-cell-layout`, base `b16408c28de67e3b30ebb1f0172e78d594296052`.
The baseline checkout `C:/kybersand/source` is read-only. All generated files go
in the experiment worktree's ignored `build/issue-16` and `validation/local/issue-16`.
Use the configured pinned workspace Python/LLVM environment via `tools/dev.py`;
its default source path must be overridden in the experiment driver, never invoke
its build actions against the baseline. Native and Web bindings stay distinct.

## Registered comparisons

This registration precedes candidate implementation and measured results.
Use fresh worlds and distinct executables. Low bits are listed first; encode
semantic records with explicit little-endian integer bytes, never raw structs or
compiler bitfields. All unused bits are zero and carry no behavior.

| Stage | Control / candidate | Exact mapping and disposition |
|---|---|---|
| L1 | Original4 / padded8 | material:u8, a:u8, b:u8, epoch:u8 at byte offsets 0/1/2/3; candidate adds four unused bytes, alignment remains 1. Completed: exact comparisons pass; sleeping p95 and wrap-tick excess trigger cost review. |
| L2a | Original4 / packed8/16/8 | uint32: material[0:7], a[8:15], b[16:23], epoch[24:31]. Masks/shifts; keep all legacy values. L2 completed; exact parity and costs are in the audit. |
| L2b | Padded8 / packed16/40/8 | uint64: material[0:15], a[16:23], b[24:31], unused[32:55], epoch[56:63]. Only IDs 0..80; extraction cost is not catalogue expansion. Natural integer alignment must be reported as an access-layout confound; add an alignment-matched padded control if needed. |
| L3 | packed8/16/8 / packed8/18/6 | uint32: material[0:7], a[8:15], b[16:23], unused[24:25], epoch[26:31]. Keep all legacy state precision; only epoch width changes. |
| L4 | Original4 plus optional / inline neutral payload | Bounded chunk SoA and sparse indexed sidecars; neutral uint32 payload explicitly has no solver meaning. Separate absent, allocated/unread, accessed. Register concrete ownership and operation fixture before this code. |
| L5 | Compatibility inventory | Inspection now; no new materials, profile widening, saves or render changes. |
| L6 | Optional 64-square storage | Not admitted without profiling justification and a new registration. Keep activity32/core64/radius2; repeat both layouts if admitted. |

Stages L3-L4 are mandatory remaining research, pending preceding stage evidence,
not rejected/skipped. A failed equivalence gate rejects that candidate and records
the failure; cost regressions trigger review, not automatic omission of other stages.
G-L stays open until every intended stage has evidence or a supported gate disposition.

## Primary metrics and rejection criteria

Fixed geometry 128 storage / 32 activity / 64 scheduling / radius 2, phased solver,
sleep 3, default Baseline transport, Mercury period 30, horizontal2/cadence1,
current three-quarter Water relaxation, temperature200. Worker counts 1 and 4;
keep parallel threshold8, capacities chunk/core/active-chunk4096, events1024.
Initial reservation policy and external input schedule must match within each pair.

Primary timing: p50/p95/p99/max/total tick nanoseconds and total ns / total visited
cells (undefined when visits are zero). Nearest-rank quantiles, paired candidate /
control ratios; retain each pair and median paired ratio, not pooled pseudo-replicates.
Flag paired p95 regression >15% and extra epoch-clear excess >1ms for review.
Never infer significance or an accepted production limit from those screens.

Seven interleaved independent process pairs for every timing comparison, AB/BA
alternating by pair index. First 120 measured ticks are separately reported as
initial settling/warmup; next 1800 ticks are the steady window for L1/L2. Cold
process/world construction is reported separately. Warmup is excluded from steady
statistics, never discarded from raw evidence. L3 runs 2048 total ticks minimum
and includes all clear events in a separate table, including warmup clears.
Primary timing has physics observers and semantic traversal disabled. Identical
observer-enabled runs establish work/event/semantic parity separately; seven
off/on pairs per layout quantify instrumentation cost before using observed timings.

No parallel builds, builds during timing, or concurrent experiment measurements.
Per-process timeout 1800s, build timeout1200s; retain failures/timeouts/outliers.
No automatic retry or expansion of samples. Register revised budgets before results.
Hardware/OS/compiler/binary/input hashes and run order accompany raw evidence.
Record power configuration and competing-process observations at release of the
owner hold; absence of a process in one snapshot is not proof of an uncontended run.

## Fixtures and budget

L1/L2 timing: existing dense/sparse native benchmark initialization, extents512
and1024, workers1/4, plus retained sleeping allocation extent4096 with the existing
small active patch and a selected small region. No arbitrary new solver workload.
This is ten scenario/extent/worker combinations, 140 processes per two-layout
comparison, plus declared observer-neutrality pairs. Save final content/state and
work records outside timed sections; whole-world exact correctness is a separate run.

Behavior screen: five explicitly paired seed/translation settings
`(0,0,0), (1,-129,-65), (2,127,63), (3,-257,129), (4,65,-129)`;
seed changes only initial arrangement, not native RNG/policy. One/four workers,
1800 ticks, repeated identical runs; 2048 ticks for wrap fixtures. Compare each
setting to itself across layouts, never assume translations preserve trajectories.
Use a compact closed Water/Sand basin and separate reactive catalogue fixture;
run the existing full native regression suite for failure/region/temperature,
movement, reactions, immutable snapshots, capacity and opt-in transport coverage.
First-stage source preparation may run these correctness checks without collecting
tick timings. Dense/sparse benchmark-sized A/B remains behind the owner hold.

L3 must cover signed seams, sleeping and region-excluded resident cells, re-entry,
movement and prewritten explosion destinations across every wrap. Clear timeline:
8-bit ticks `256 + 255*k`; 6-bit `64 + 63*k`. Capture clear identity/duration/cell
count and neighbor-tick excess (clear time minus median of up to two ordinary ticks
on each side). Moves and swaps mark both endpoints; partial Water transfers mark
both; event writes happen after clearing and suppress ordinary work until next tick.

L4 densities0/1/5/15/50/100%, clustered/dispersed. Neutral payload slots belong to
exactly one coordinate, move/swap with a transaction, split by an explicit synthetic
rule, discard/reinitialize on reaction, return capacity on reclaim. Preflight
destination allocation before source removal; saturation refuses the operation,
never silently drops payload/material. Bound each chunk to16384 slots and sparse
capacity to the registered density; count lookup index, occupancy/free-list,
allocation count/peak/refusal and allocator overhead. Compare equivalent operation
streams with an inline neutral payload control; this is not useful motion-state evidence.

## Semantic and memory records

The lossless oracle emits sorted signed coordinate records containing u16 material,
u8 a, u8 b, i16 resolved temperature. It must retain nonzero empty-cell state and
temperature, omit representation padding/epoch only, and compare exact bytes.
Epoch is checked separately. Compare matching-tick state_hash only for identical
schema/ABI; use content_hash for rest, never as a complete replay proof. Every-tick
Water integer mass and nonreactive species totals are exact; chemistry changes
are separate source/sink ledgers and open ROI escape is not world loss.
Capture all TickStats work counters and diagnostic event entries/overflow; keep
observer-off repeat checks. A digest is an index, not the lossless comparator.

Memory: report actual sizeof/alignment/array stride and offsets, cell capacity
bytes, temperature capacity bytes, activity bytes, chunk/vector/map/scratch/job
metadata and process working-set/private/peak memory where available. Existing
`resident_cell_bytes()` already includes temperature and activity vectors; label
it as the legacy aggregate and never add it again to component totals. Allocator
bookkeeping/fragmentation not directly observable must be a gap, not zero.
Capture representative optimized scan/write/move/clear disassembly for control
and candidate with identical flags. PMU/cache/bandwidth counters are optional
hardware evidence; unavailable counters preclude cache-causality claims.

## L2 implementation registration, September11

Registered after L1 review and before packing code: retain both L1 executables.
Give every newly built cell the same inline material/state/epoch getter/setter
interface. Controls preserve original byte offsets0/1/2/3 and sizes4/8. Primary
comparisons use explicit alignment4 for both byte4 and packed8/16/8, alignment8
for both byte8 and packed16/40/8. Thus type alignment matches within each primary
pair; it differs from the alignment1 L1 controls and is not silently attributed
to packing. Array stride remains4 or8. Default unselected builds remain4 bytes
and alignment1. Inspect optimized access/clear/constructor code for all variants.

The16-bit material field uses only current IDs; the public/internal `Material`
enum and every adapter remain8-bit. Getters return the legacy enum. Its upper
material bits remain zero and the compiler may narrow reads. Report that generated
access explicitly: this measures a16/40/8 carrier with legacy values, not the cost
of an end-to-end16-bit catalogue/API migration. Unused24 state bits stay zero.

Build four primary variants: byte4-a4, packed4-a4, byte8-a8, packed8-a8. Full55-test
native suites and the five-setting1800-tick,1/4-worker,two-repeat exact behavior
screen run for each; compare against retained L1 semantic streams as well. Add a
storage round-trip check over all accepted IDs, all65,536 a/b combinations and
epochs0/1/63/64/255 without executing invalid Rocket headings. Verify mask
non-overlap, exact mapping, unused bits and copy/set isolation. A C11 header check
and benchmark setup/capacity checks remain required. No solver or epoch changes.

Primary timing keeps the L1 ten cases,1920 ticks,120 warmup,seven AB/BA pairs for
each of the two packing comparisons:280 processes. Observer off/on remains
sparse1024 at1/4 workers, now for all four variants:112 processes. A separately
labeled control-bridge screen compares each retained L1 binary with its rebuilt
aligned byte control: dense512/workers4 and sleeping4096/workers1,seven AB/BA
pairs each,56 processes. Total448 processes, sequential, with the existing timeouts
and cost screens. This representative bridge measures combined accessor/alignment
control changes; it is not a replacement for the primary packing contrasts or a
full-workload proof of control neutrality. Any bridge regression is retained as a
scope limitation and reviewed before interpreting primary results. No adaptive
retry, sample removal or optimizer tuning. Record source/flags/binary identities
and restore neither old raw Cell bytes nor a loaded runtime into new layouts.

## L3 registration: epoch width and direct clear observation

Registered after complete L2 review, before candidate code. Compare packed32 with
8-bit epochs against6-bit epochs: material0:7,a8:15,b16:23,unused24:25,epoch26:31.
The8-bit mapping remains0:7/8:15/16:23/24:31. Size/stride/alignment4; all legacy
precision, geometry, solver order/profiles and capacities remain fixed. Advance
modulo256/64, reserve zero, clear all resident cells then reset1. First clear256/64,
then intervals255/63. Extra state bits stay zero; no production selection.

Proposed new modules: native/bench/cell_epoch.cpp, native/tests/test_cell_epoch.cpp,
tools/experiments/cell_epoch.py and corresponding reducer/tests. Storage and World
research hooks gain the selected epoch width and optional owner-only recorder.
Allocate64 clear summaries and4096 chunk identities per summary before ticks;
preflight overflow before clearing and quarantine failure. No worker observer writes,
tick allocation or mutable cell exposure. Record tick, direct duration, every resident
chunk coordinate/cell count, activity and none/partial/full selected-core overlap.
Metadata collection is outside the direct clear clock but inside whole-tick time;
direct time encloses only the clear loop and epoch reset. Sort/serialize after ticks.
Off mode has no observer clock calls. Count recorder allocation and test overflow.

Correctness: default and both variants' full native suites; storage mapping/isolation
including6-bit boundaries; original five seed/translations,1/4 workers,two repeats,
2048 ticks with every-tick closed Water/Sand and lossless reactive/state/temperature/
work records. Compare8-bit prefixes with retained1800-tick behavior. Omit raw
state_hash only across epoch schemas; retain same-schema checks and observer-off
neutrality. Add a2048-tick movement/event fixture with the same settings/workers/
repeats:16 separated Foam columns cross64/128 seams; explicit32-tick reinjection/
reclaim and exactly one upward move/lifetime decrement per eligible tick. Pause at
samples60–129 and240–299, then re-enter without catch-up. An isolated event chamber
receives explosions at the union of both wrap schedules; new Fire retains initial
lifetime on the event tick. Keep reinjection and event ledgers separate. Test sleeping/
excluded sentinel epoch resets and complete resident identity capture.

Timing: unchanged ten dense/sparse/sleeping cases,2048 ticks,first120 warmup,seven
AB/BA pairs,140 primary observer-off processes. Retained L2 packed4 versus rebuilt
8-bit bridge: dense512/workers4 and sleeping4096/workers1,28 processes. Direct-recorder
off/on pairs for sparse1024 and sleeping4096 at1/4 workers for both widths:112 processes.
Total280 sequential processes,1800-second timeouts,no adaptive retries/removal.
Physics diagnostics are off during primary/direct timing and covered in correctness.

Recheck exact state/work across pairs/repeats/workers and final whole-world Water/
Sand. Report settling, all tails, memory and worker dispatch; observed clear schedules/
direct duration separately from ordinary-neighbor whole-tick excess and amortized
cost. Sparse/sleeping setup advances four ticks; use actual World tick numbers.
Retain >15% paired p95 and >1ms extra clear/excess review screens.

## Run and review

**L3 review, September11:** all280 processes and70 epoch/14 bridge/56 observer
pairs pass exact normalized state/work and final quantities. Six-bit epochs clear
32 times versus8 over2048 ticks. Sleeping p95 is similar, but p99 rises3.81–3.99x
and total time4.85–5.67%. Direct sleeping clears remain about8.4ms. Shorter epochs
make the hitch more frequent; no width is selected. This admits the bounded L4
neutral carrier below. Hardware-cache attribution remains unmeasured.

## L4 concrete preregistration, September11

New standalone modules `native/bench/cell_sidecar.cpp` and
`tools/experiments/cell_sidecar.py` will compare a neutral uint32 tag, zero absent,
with all32 nonzero bits preserved. This is a synthetic transaction carrier, not
World physics or a solver-speed prediction. Existing World correctness evidence
is retained, not relabelled as a fresh L4 run. No adapter/render change is admitted.

Sixteen128-square chunks hold262144 legacy slots on a512-square grid. Legacy
material/state_a/state_b/epoch remain byte4 with alignment4 and epoch0, plus a
separate i16 temperature array. Inline control adds tag32 (stride8, alignment4).
SoA uses optional u32[16384]. Sparse uses optional u16[16384] indices (65535 absent)
and bounded8-byte slots containing value32/owner16/next-free16. Slot handles never
escape their owner. Include descriptor/vector/free-head bytes and actual capacities,
process working/private/peak memory and measurement buffers; allocator/PMC gaps
remain explicit. All carriers enforce the same per-chunk logical capacity:
min(16384,initial present+64), or0 for unprepared chunks. No measured growth.

Density0/1/5/15/50/100% means floor(262144*density/100) tags. Clustered uses the first
slots in chunk-major order; dispersed uses the bijection (rank*65537+131*seed)
mod262144. Report per-chunk occupancy and allocated chunk count. Absent mode uses
density0/unprepared arrays. Allocated-unread scans only legacy bytes; density0 in
this mode deliberately prepares every chunk with cap64. Accessed mode performs
transactions and reads absence at density0. Initial legacy states cycle current
Water mass1..255/delay0..12, Sand17/23 and Fire48/0; temperature200..216. These are
state carriers; synthetic reaction sources/sinks are not chemistry predictions.

Eight pairs of horizontally adjacent chunks are exclusive worker domains. Each
accessed batch attempts64 operations per pair, cycling move/swap/Water split/
Water merge/reaction clear/reaction create/reclaim/read. Deterministic adjacent
endpoints include chunk seams; writes stay distance1 within their pair. Moves and
swaps transfer legacy, temperature and tag; split explicitly clones a tag, merge
prefers the destination tag and accounts drops. Reactions/reclaim have explicit
Water and tag source/sink ledgers. Creation tags follow the initial density mask.
Preflight post-operation counts before mutation, erase both endpoints then assign
replacements. Unprepared/full destination refusal preserves both records. No global
free list, worker allocation, per-cell lock, external mutable view or rollback claim.

Unread/absent batches perform8192 legacy reads over a cycling resident cursor;
payload validation occurs after timing. Accessed batches attempt512 transactions.
One/four workers execute identical pair streams, with three persistent child
threads plus the caller and two barriers per batch. Report dispatch overhead rather
than tuning batch size. All buffers are prepared first, followed by100 empty pool
barrier cycles. Benchmark-only C++ new counters screen allocations during batches;
this does not observe arbitrary malloc/OS allocations. Exceptions must join safely.

Correctness:1800 batches, five existing seeds/translations,1/4 workers,two repeats,
all12 accessed density/pattern cases and three carriers:720 processes. A flat
reference is independently initialized from declared inputs, compares outcomes and
touched endpoints every operation, and full state/free-list ownership every64 batches
and at completion. Shared pure transaction semantics are a common-mode limitation;
hand-expected focused checks cover successful operations, capacity refusal unchanged,
unprepared/prepared seam moves, saturation, reclaim/reuse and high-bit tags. Check
exact Water and neutral source/sink accounting every batch. Final lossless records
encode all cells as little-endian x64/y64/material16/a8/b8/temp16/tag32; every batch
retains32 u64 work/ledger fields. Compare repeats/workers/carriers byte-for-byte.

Timing: seven interleaved AB/BA pairs for each SoA/sparse versus inline control,
both unread/accessed modes,12 cases and1/4 workers:1344 processes. Add56 absent
density0/clustered processes:1400 total,1920 batches each,120 warmup and1800 steady,
1800-second process timeout. Retain all samples/failures; no adaptive retry/tuning.
Primary p95 candidate/control, plus p50/p99/max/total and ns/read or ns/attempt,
startup and memory. Flag >15% paired p95 for review. Exact work/final-state parity
is mandatory. Serialize after timing and losslessly gzip each completed record
outside process clocks before launching the next process. No concurrent builds,
tests or full reduction. Freeze source/compiler/executable hashes before release.

**L2 review, September11:** all448 processes completed with140 packing,28 bridge and56
observer pairs passing. No primary median p95 exceeds15%, but three individual pairs
do; sparse one-worker costs reach11.86%. Bridge medians span0.9859–1.0076. Observer
cost remains measurable. Packed sleeping wrap proxies improve roughly2–3ms; direct
clear time remains unobserved. This admits L3 with those limits retained, not migration.
The audit owns full identities, cost tables, quantity ledgers and unresolved gaps.

**L1 review, September11:** all196 registered processes completed,70 width pairs
and28 observer pairs passed exact state/work comparisons, and final whole-world
Water/Sand accounting passed. Dense median paired p95 ratios span0.9960–1.0223;
sleeping4096/one-worker is1.1504 and crosses the15% research screen. Every sleeping
paired wrap-tick excess exceeds1ms; medians9.11/8.43ms for workers1/4. These are
source-scheduled whole-tick proxies, not directly observed clear durations.
Cell storage doubles in every case; sleeping72.25 to144.5MiB. Observer cost is
measurable, so primary timings retain observers off. No layout is selected.
This supports proceeding to the registered packing comparison while retaining
the negative cost screens for later direct epoch measurements. G-L remains open.

The first-stage driver is `tools/experiments/cell_layout.py`. `prepare` builds
isolated original4/padded8 executables and runs correctness only; `plan` writes
the ordered process manifest without execution. `measure` is a separate explicit
action and requires the owner to release the uncontended-run hold in this task.
Do not invoke it during preparation. It must refuse reused output paths, mismatched
source/binary identities or failed prerequisites. Review L1 before implementing L2.
`tools/experiments/summarize_cell_layout.py` accepts only the complete196-process
campaign, rechecks raw samples/records and produces the scoped timing, footprint,
worker-dispatch and wrap-tick tables. It never runs or selects benchmark samples.

The [dated checkpoint](../audits/2026-09-10-issue-16-cell-layout.md) owns actual
executed checks, compatibility findings, gaps and G-L disposition. Retained #9,
#10, #13 and Water evidence establish baseline facts only. No desktop/Web result
is inferred from a native executable; adapter/render changes would require fresh
desktop async and real compat/threaded Web coverage.
