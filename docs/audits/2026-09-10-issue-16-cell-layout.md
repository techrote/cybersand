---
title: Issue 16 source intake and Cell layout evidence
status: Current
document-kind: evidence
scope: Completed local L1–L5 representation evidence and supported L6 non-admission; no production migration
canonical-for: []
last-reviewed: 2026-09-11
related-documents: [../operations/cell-layout-experiment.md, ../operations/architecture-programme.md]
---

# Issue 16 Cell layout evidence

## Identity and outcome

**Current inspection:** separate branch `codex/issue-16-cell-layout` in
`C:/kybersand/worktrees/issue-16-cell-layout`, from local planning commit
`b16408c28de67e3b30ebb1f0172e78d594296052`. Baseline branch
`codex/architecture-programme` had only the deliberately dirty Windows DLL,
SHA-256 `fc6cb4ee1096219f581bace3df04ee8138e996aaf4c1436f5b2c071ea62dd496`.
It is not the experiment control. Baseline source includes current Water work;
older remote main and published runtime manifests are not substitutes.

**Current checkpoint:** issue16 research is complete locally. L1/L2/L3/L4 execute
2324 registered timing processes in total; exact comparisons and scoped validation
pass, with negative and ambiguous cost evidence retained. L5 records compatibility
and demand limits; L6 is not admitted for the supported reasons below. G-L establishes
experimental carriers, not a production layout/epoch/ID decision. No merge,
deployment or remote issue mutation occurred. The original preparation hold and
stage checkpoints remain historical evidence below.

## State range audit before accessors

Source: `native/src/world.cpp::update_rule_kernel`, `write_cell`, `set_cell_state`,
`transfer_water`, `move_cell`; definitions in `native/include/cybersand/material.hpp`.

| State family | Current generated semantic values | Compatibility consequence |
|---|---|---|
| Water | a mass1..255, b coherent delay normally0..12; max on merge, decrement before suppression | Preserve full mass and countdown; zero mass normalizes to Empty. |
| Smoke/Fire/Steam/Foam/Spark | a lifetimes, descriptor starts240/240/180/120/12; reactions can set other byte lifetimes | No global smaller a field; some full-byte values remain legitimate external states. |
| Combustible/Oil/Coal/Plant/Fungus | b burns, ignition240/48, Oil64, Coal160; Plant/Fungus a energy32, recursively split | b is not a universal calm flag; a and b can both be meaningful. |
| Acid/Cement/MoltenGlass | a strength255/cure180/cooling180; decrements and conversions | Full-byte a preserved. |
| Metal | b charge24 from Spark, halved propagation/decrement | Byte state remains accepted externally. |
| Cloner/Rocket | b captured material ID up to80; Rocket a0 or heading1..8 | Widening IDs must also address IDs embedded inside legacy state. |
| Mite/Seed/Stone | Mite a1 or255 heading; Seed a8..0/b1; event Stone b1 distinguishes granular state | Signed heading encoding is a byte value, not negative integer storage. |
| Inert/powder/other yielding cells | state normally zero; movement/swap carries both bytes and temperature | Do not erase apparently unused stored state. |
| Public state setter | accepts a,b independently0..255 for valid materials; no generic 14-bit validation | Wall with (255,255) is a direct lossless-storage counterexample to generic10/14/8. Rocket arbitrary heading is accepted by setter but unsafe to execute outside1..8; range tests must not step invalid semantic states. |

**Inspection result:** 10/14/8 is not admitted as an equivalent generic encoding.
Per-material compression would need a separately proved mapping/refusal policy;
this is not a proof that all possible typed encodings are impossible. No truncation
or state reinterpretation is authorized. No live runtime range maxima are claimed.

## Narrow ID inventory

| Surface | Current source fact | Cost of real16-bit ID migration |
|---|---|---|
| Material/descriptor | enum uint8,81 entries including invalid10; highest80 | 175 unused numeric codes81..255 already exist; no demonstrated catalogue demand beyond255. Change enum/assertion/validation and audit every cast. |
| C ABI | Several ID parameters and queries already uint16; cell copies are byte buffers, state/visual values narrow | Wider function arguments alone do not widen internal Material or packet schema; version affected buffers and consumers. |
| Profiles | TransportPolicy materials81 and81x81 pair table; GDScript packing loops81 | Decide sparse/dense growth, memory/capacity, schema and hash migration; width is not a reason to allocate65536 squared pairs. |
| Diagnostics | Byte material fields in packed event keys and81-bin adapter counts | Update event key and histogram schema/capacity before wider catalogue observations. |
| Adapter | emit_disc rejects ID>255; casts to Material; compact snapshot copies | Validate full domain, version affected messages; retain immutable ownership. |
| Rendering | RG8 R=material byte, G=visual byte; shader decodes R*255 and appearance program has256 rows | Explicit new ID encoding/lookup or stable render ID mapping required; no render widening in this experiment. |
| CYSD1 | Fixed5-byte material/a/b/int16-temperature level records with byte IDs; flags are in the header, no epoch/replay continuation | Version/converter/refusal needed for IDs>255; never serialize experimental Cell structs. |
| State-carried IDs | Cloner/Rocket b is uint8 | ID width also affects typed state capacity and payload validation. |
| Hashes | Fieldwise hashes omit padding, include bookkeeping in state_hash, size_t is ABI dependent | Width/epoch changes require normalized semantic records; no Windows/Wasm raw-hash promise. |

## Memory and epoch inspection

Original Cell has four byte fields. Padded candidate must preserve alignment1 and
offsets0/1/2/3, adding four unused bytes. Packed uint32/uint64 candidates have
different natural alignment; report that instead of attributing everything to masks.
`resident_cell_bytes()` includes cell capacity, optional int16 temperature capacity
and activity-block capacity. It excludes chunk object, map buckets/nodes, job/scratch,
allocator overhead, snapshots and process memory. Its benchmark label is incomplete.

`begin_tick` increments byte epoch; zero triggers a clear across **all resident
cells**, including sleeping/excluded chunks, then sets epoch1. Clear ticks are
256,511,766,1021,1276,1531,1786,2041 over2048 attempts. Comparable6-bit ticks start64
and recur63, giving32 clears through2017. Moves/swaps and Water transfers mark both
endpoints; event writes follow the clear. These are source predictions, not timings.

## Gate disposition, September11

| Stage | Local research disposition after L4 review, September11 |
|---|---|
| L1 stride | Completed196 processes; exact comparisons pass, sleeping p95/wrap-tail costs flagged. |
| L2 packing/ID access | Completed448 processes; exact pairs pass, individual cost flags retained. |
| L3 epoch | Complete:280 processes; exact parity, sleeping tail penalty and direct clear cost retained. |
| L4 optional state | Complete:1400 timing processes/700 exact pairs; allocation crossover and active-access costs retained. |
| L5 ID inventory | Source review recorded above; larger IDs have capacity headroom but no demonstrated demand. |
| L6 storage geometry | Not admitted: direct clear cost follows resident cells; no geometry/locality evidence, and the retained large reservation exceeds4096 chunks at64-square storage. |
| G-L | EVIDENCE COMPLETE: equivalent experimental carriers established; no production width, epoch, larger-ID or scheduler approval. |

## Documentation checkpoint map

Registration/audit own experimental methods and evidence; programme, roadmap,
validation ledger and retrieval routes link here. Storage documentation qualifies
the experiment-only layout switch. ADRs, production ownership, C ABI, snapshots,
profiles, save formats, controls and renderer stay unchanged. Build tooling is
experiment-specific. Historical audits/M11 hashes and published provenance remain
unchanged; current-source provenance failures must be reported separately.

Executed validation, artifacts and recoverable local commit are recorded at the
completed preparation checkpoint below.

## Completed preparation, September10

**Executed Windows x86_64 native correctness, not performance:** workspace pinned
Python3.12.14 and LLVM-MinGW Clang23.1.0/UCRT. Builds use identical C++20 warning
flags, `-pthread -static`, O3/NDEBUG/LTO for the harness and O0/g3 for native tests.
No shared bindings or DLL were rebuilt. The two core test executables each passed
all55 tests; the C11 header check passed. The original test executable has no
experimental macro; padded tests use the8-byte selection.

Forty1800-tick behavior processes passed: five seed/translation settings, widths4/8,
workers1/4, two repeats. Every serialized frame matched **exact bytes**, including
material/state/temperature, all15 work counters, matching-schema state_hash and
sorted diagnostic event totals. Four additional1800-tick observer-off processes
(both widths/workers, first seed) matched all cell/work/state frames after omitting
only event observations. Exact Water integer mass and Sand count were asserted
every tick in the closed basin. The separate reactive chamber, region exclusion
at sample256, re-entry511 and queued explosion765 were included. No runtime was
timed in these44 processes. This is not the later2048-tick epoch/sidecar acceptance.
The compact harness keeps threshold8, so a configured four-worker process need
not dispatch a pool for a small phase. The existing full suite includes forced
threshold1 worker regressions; do not present the small fixture as worker scaling.

The driver records full semantic snapshots in canonical sorted chunk-coordinate
order, then local row-major order;22 explicit little-endian bytes per retained cell.
Epoch is excluded from those records but included in L1's separate state_hash.
Only Empty cells with zero state and ambient temperature are omitted. Raw frames
are retained as lossless gzip files after byte comparison, alongside SHA-256 indexes.
Observer events are aggregates, not a complete serialized replay of reactions.

**Actual layout checks:** sizes/strides4 and8, alignment1, offsets0/1/2/3.
For the first closed/reactive fixture, five resident chunks use cell capacities
327,680/655,360 bytes, temperature163,840 bytes and activity1,280 bytes in both.
Legacy aggregate492,800/820,480 therefore differs by327,680 exactly. These are
capacity observations; they are not timing or sparse-density crossover results.
The observer-enabled fixture also reserves20,086,864 bytes in parallel result/
diagnostic vectors; excluding this overhead would materially misstate total memory.
Process counters include the harness, serialization and allocator retention and
are not attributed solely to World. Map bucket bytes are an estimate; map nodes,
allocator headers/fragmentation, worker stacks/pool internals and process baselines
remain explicit accounting gaps before final G-L conclusions.

Optimized assembly and actual LTO PE disassembly are retained. Inspected
`write_cell` and `scan_rect` address shifts change2 to3; `begin_tick`'s epoch clear
increments addresses4 versus8. Movement code is also retained. The compiler has
not collapsed candidate stride to4. These accesses establish layout, not cache
misses, bandwidth or throughput. No PMU data or epoch-clear duration was collected.
Build logs retain two inherited warnings and three experiment conversion warnings
(positive configured chunk size and bounded fixture mass); no compiler errors.

| Artifact | SHA-256 |
|---|---|
| Original4 O3 harness | `820d03a66d6cb339e8468c594d45fe5ca5e2f32c4fc91ec01ade3c8a7f23a93a` |
| Padded8 O3 harness | `8dc731df1181aea98d4461ec263bb3b9e0f07de0d1913a8b67ae499a4e0d0247` |
| Original unselected Debug tests | `789618a70a04b933992d1322d89af8f8933871865eba4e838f8c7f4aeebfa7f0` |
| Padded8 Debug tests | `4d0bea6037fca4ba2b21e590f2d841bacd0a288f1e293f2c1e811ae307da2857` |

Recoverable source: this preparation commit on `codex/issue-16-cell-layout`,
subject **Prepare issue16 stride experiment and pause before timing**. Generated
artifacts are under `build/issue-16/prepare-20260910-212247/{4,8}`. Raw evidence
prefix is `validation/local/issue-16/prepare-20260910-212247` in the worktree.
`prepared.json` records actual base HEAD plus per-file local-delta hashes, compiler
identity, artifacts and command/result logs; `source-before.json` preserves intake.
The initial registration hash was retained in `validation/local/issue-16/intake`
before candidate edits. All local evidence is ignored and kept out of the commit.

## Documentation and evidence checks

- `check_docs.py`: direct worktree invocation retained six missing companion-path
  failures. A byte-copy validation snapshot under this worktree's
  `validation/local/issue-16/docs-workspace/source`, with five read-only copied
  companion inputs, passed. Source links/historical fixtures were not rewritten
  to accommodate worktree depth. Git read context uses the experiment index.
- `check_m11_consistency.py`: passed,28 historical source hashes and18 retained
  records; no M11 hashes changed.
- `check_repository.py`: baseline read-only check still fails16 inherited
  publication/LFS items. The materialized experiment snapshot fails14 published
  source-input attestations (seven Windows/seven Linux). This is not a current
  runtime release; the dirty baseline DLL is intentionally absent from candidates.
- Frozen32 retrieval: hit@1=23/32, hit@5=32/32, MRR0.8385. Existing16 challenges:
  12/16 and16/16, MRR0.8562. Programme5:3/5 and5/5, MRR0.8. New issue16 questions:
  1/3 and3/3, MRR0.6667. No frozen wording was changed or tuned to improve scores.
  Manual review confirms timing hold/open G-L, exact comparison and aggregate-byte
  qualifiers in canonical contexts; first-hit retrieval for the footprint question
  misleadingly prefers the save page. Top-five retrieval remains necessary.
- Four driver failure-path tests pass: timing hold before file/process access,
  exact same-length corruption rejection, event-only exclusion and truncated-record
  refusal. `git diff --check` passes. No generated runtimes/logs are committed.

The known release failures, worktree topology failure and compiler warnings remain
in raw evidence. Native correctness is not desktop async, Web compatibility/threaded,
sanitizer, PMU, new hardware or performance acceptance. No adapter/render behavior
changed, so no new Godot/export package was installed or launched.

## Preparation handoff before owner release

Additional preparation screen registered before execution: one **untimed** tick
for each dense/sparse512/1024 and sleeping4096 fixture at widths4/8 and workers1/4
(20 processes). This checks setup/capacity and exact initial/final records for the
actual timing inputs; it cannot replace the registered1800-tick behavior or timing
campaign. In particular, sleeping4096 must fit the unchanged default core capacity.
**Result:** all20 processes passed exact byte parity and capacity checks. Raw logs,
full state/work records and footprints are retained in the preparation prefix's
`setup-smoke` directory. No tick-duration files were generated.

The first-stage process plan has196 entries, **none executed**:140 primary width
processes (ten fixture/extent/worker cases times seven pairs times two layouts),
plus56 observer off/on processes (sparse1024, both layouts/workers, seven pairs).
The latter is the declared representative neutrality screen; do not extrapolate
its overhead to every workload without evidence. Every timing process has120
warmup and1800 steady samples. World construction/fixture startup is recorded
separately; process launch overhead is not isolated by this harness. OS/power/
hardware identity and process contention must be captured when the owner releases
the hold; existing issue15 correctness activity does not certify future availability.

Preparation command, from the issue worktree:

```text
C:/kybersand/.local/python/Scripts/python.exe tools/experiments/cell_layout.py prepare
C:/kybersand/.local/python/Scripts/python.exe tools/experiments/cell_layout.py plan --manifest validation/local/issue-16/prepare-20260910-212247/prepared.json
```

`measure` requires explicit owner release in this task and `--owner-released`.
Do not run it until the uncontended window is arranged. The driver validates source/
binary identity, refuses reused run directories, writes command/timeouts and keeps
failed/partial results. Width pairs check final exact state and every-tick work;
initial-settling/steady summaries remain separate. Review paired statistics and
observer cost before L2; fill the per-clear, sidecar/crossover and full G-L evidence
in their registered later stages. This is a pause requested by the owner, not a
negative result, a skipped mandatory stage or issue completion.

## L1 results

**Executed September10–11, 22:25–00:14 BST:** owner release was “Ready for the
first uncontended run. Start.” The196-entry preregistered plan completed without
failure, retry, sample exclusion or budget change. Measured source is preparation
commit `b2d8faffa86e472875ba74f7c6b1488bbdd06f8a`; original/padded O3 binaries and
compiler hashes remain those listed above. No measured source or binary changed
during the campaign. All196 processes ran sequentially with1920 ticks each:
120 initial-settling samples, then1800 samples in the declared steady window.
This window does not assert physical equilibrium. Sparse/sleeping fixtures have
four setup ticks, so their measured world ticks are5–1924 rather than1–1920.

Host: Windows11 Pro10.0.26200, AMD Ryzen5 2600X,6 cores/12 logical processors,
approximately31.9GiB visible RAM; existing Balanced power plan unchanged.
Host/process/power snapshots and release text are retained. No competing experiment
was observed at release; no builds, suites or evidence reduction overlapped timing.
Occasional status/file reads and small analysis-helper edits occurred; background
OS activity and clock/thermal variation were not eliminated or continuously measured.
An owner-arranged desktop window is not proof of a noise-free or fixed-frequency host.

Raw prefix: `validation/local/issue-16/timing-20260910-222504`. `plan.json`,
`identity.json`, `run-context.json`, all196 command/exit/timeout records, logs,
tick CSVs, exact binary records, `results.json`, `reduced.json`, `summary.md`,
host/PMU queries and completion time are retained in this worktree. Native process
timeout remained1800s. Reduction records hashes for raw records, CSVs, logs and
execution files. Its helper was developed during the campaign after partial results;
it uses the registered windows/metrics and all samples, without sample selection.

```text
C:/kybersand/.local/python/Scripts/python.exe tools/experiments/cell_layout.py measure --manifest validation/local/issue-16/prepare-20260910-212247/prepared.json --owner-released
C:/kybersand/.local/python/Scripts/python.exe -m unittest discover -s tools/experiments -p test_cell_layout*.py
C:/kybersand/.local/python/Scripts/python.exe tools/experiments/summarize_cell_layout.py validation/local/issue-16/timing-20260910-222504
```

### Exact comparisons and quantities

All70 width pairs pass exact final semantic records and every-tick work equality;
all28 observer pairs preserve the same state/work after excluding observer entries.
Across repeats and workers, full records also match within each layout/observer
setting. CSV tick/visited values agree with binary work records; phase-job sums
agree with scheduled cores. There are no process failures or diagnostic overflows.
The nine driver/reducer tests pass, including truncation/corruption, incomplete
campaign refusal, nearest-rank quantiles, source-defined wrap offsets, dispatch
threshold and CSV/work mismatch checks. The55+55 native tests and every-tick
five-setting behavior/event/quantity checks remain the preparation results, not
newly rerun suites. Timed runs contain final semantic/event frames and every-tick
work; they do not provide every-tick large-world quantity/event ledgers.

Final whole-world accounting passes in all196 processes. Quantities are integers:

| Fixture | Sand initial = final | Water mass initial = final | Smoke initial → final |
|---|---:|---:|---:|
| dense512 | 70,578 | 7,713,240 | 10,082 → 4,992 |
| dense1024 | 282,309 | 30,852,450 | 40,330 → 19,729 |
| sparse512 | 4,411 | 481,950 | 630 → 298 |
| sparse1024 | 4,412 | 481,950 | 630 → 312 |
| sleeping4096 | 4,410 | 482,205 | 630 → 210 |

Smoke lifecycle loss is recorded separately; it is not a Water/Sand conservation
failure. Active worlds can grow beyond initial extents. Dense512/1024 allocate
140/190 additional chunks during timing; sparse512/1024 allocate51/43, sleeping0.
Final quantities cover the whole World, including cells outside the initial extent.
No zero-mass stored Water was found. No new reaction/solver policy was introduced.

### Timing and cost screens

The table gives medians of seven **paired padded/control ratios**, with nearest-rank
quantiles computed separately per process after warmup. These are descriptive
results, not confidence intervals or accepted production limits. Absolute values,
warmup/startup, p50/p95/p99/max/total, ns/visited and all individual ratios remain
in `reduced.json`. `visited_cells` counts eligible updates after epoch/rule checks,
not every memory slot scanned. Exact work makes its paired ratio equal to total's.

| Fixture | Workers | p50 | p95 | p99 | Total | Pairs above15% p95 |
|---|---:|---:|---:|---:|---:|---:|
| dense512 | 1 | 1.0235 | 1.0223 | 1.0149 | 1.0205 | 0/7 |
| dense512 | 4 | 1.0134 | 1.0087 | 1.0133 | 1.0146 | 0/7 |
| dense1024 | 1 | 1.0233 | 1.0161 | 1.0067 | 1.0253 | 0/7 |
| dense1024 | 4 | 0.9838 | 0.9960 | 0.9951 | 0.9851 | 0/7 |
| sparse512 | 1 | 1.0212 | 1.0598 | 1.1109 | 1.0427 | 1/7 |
| sparse512 | 4 | 1.0144 | 0.9981 | 1.0094 | 1.0072 | 0/7 |
| sparse1024 | 1 | 1.0227 | 1.0979 | 1.0678 | 1.0457 | 1/7 |
| sparse1024 | 4 | 1.0224 | 1.0096 | 1.0382 | 1.0269 | 0/7 |
| sleeping4096 | 1 | 1.0156 | 1.1504 | 1.1256 | 1.0456 | 4/7 |
| sleeping4096 | 4 | 1.0105 | 1.0031 | 1.0498 | 1.0250 | 1/7 |

Sleeping/one-worker median p95 crosses the15% review screen narrowly, at15.04%;
seven individual primary pairs cross it across four groups. The differing sleeping
worker-series p95 results are ambiguous host/tail observations, not proof of worker
benefit: the four-worker sleeping run never dispatches pool jobs. Retain all pairs.

Observer off/on sparse1024 medians (on/off):

| Cell bytes | Workers | p95 ratio | Total ratio | Pairs above15% p95 |
|---|---:|---:|---:|---:|
| 4 | 1 | 1.0284 | 1.0326 | 2/7 |
| 4 | 4 | 1.1103 | 1.0775 | 1/7 |
| 8 | 1 | 1.0660 | 1.0505 | 0/7 |
| 8 | 4 | 1.0632 | 1.0608 | 0/7 |

The observer is semantically neutral in checked records but has measurable cost;
primary timings therefore use observer-off binaries/runs. Its measured overhead
is representative of sparse1024 only. Do not subtract it from unrelated workloads.

### Footprint, worker use and wrap tails

Final cell capacity doubles exactly in all cases; temperature bytes are0 here,
and measured activity/chunk/vector/map-bucket components match within width pairs.
The total footprint still has the allocator/map-node/pool/stack gaps listed above.
Process private/working-set/peak counters include the harness and final serialization.

| Fixture | Cell MiB 4 / 8 | Private MiB 4 / 8, one-worker median | Descriptive total speedup 1→4 workers, 4 / 8 bytes |
|---|---:|---:|---:|
| dense512 | 11 / 22 | 16.36 / 27.57 | 2.43 / 2.47 |
| dense1024 | 18.125 / 36.25 | 23.55 / 41.91 | 2.81 / 2.87 |
| sparse512 | 5.4375 / 10.875 | 10.29 / 15.86 | 1.87 / 1.90 |
| sparse1024 | 8.9375 / 17.875 | 13.82 / 22.96 | 1.95 / 1.98 |
| sleeping4096 | 72.25 / 144.5 | 77.77 / 150.61 | 1.00 / 1.02 |

Worker speedups are ratios of seven-run median totals from separate worker blocks,
not interleaved worker comparisons. From exact phase-job records and the unchanged
threshold8, four-worker pool dispatch counts across1920 ticks are7680 for each
dense case,6766/6831 for sparse512/1024 and0 for sleeping. Source chooses dispatch
exactly at that threshold; these counts are inferred from work, not added timers.

For each source-defined8-bit wrap tick, calculate whole-tick duration minus the
median of two ordinary neighboring ticks on each side, then candidate excess minus
its paired control excess. These are **proxies**, not direct observations of clear
calls/durations. Each case has49 comparisons (seven wraps times seven pairs).

| Fixture | Workers | Median extra ms | Min / max extra ms | Above1ms |
|---|---:|---:|---:|---:|
| dense512 | 1 | 0.916 | -5.500 / 6.227 | 21/49 |
| dense512 | 4 | 0.564 | -2.220 / 3.940 | 17/49 |
| dense1024 | 1 | 2.701 | -33.117 / 25.960 | 30/49 |
| dense1024 | 4 | 1.605 | -4.331 / 7.294 | 30/49 |
| sparse512 | 1 | 0.221 | -1.867 / 2.225 | 4/49 |
| sparse512 | 4 | 0.298 | -0.170 / 0.899 | 0/49 |
| sparse1024 | 1 | 0.894 | -0.002 / 2.230 | 21/49 |
| sparse1024 | 4 | 0.789 | -0.139 / 1.829 | 12/49 |
| sleeping4096 | 1 | 9.107 | 4.887 / 14.004 | 49/49 |
| sleeping4096 | 4 | 8.434 | 5.360 / 13.027 | 49/49 |

Every sleeping comparison exceeds the1ms research screen. Dense proxy ranges also
show why whole-tick tails cannot be assigned entirely to clearing; negative values
are retained. Direct clear identity/duration and shortened-epoch behavior remain L3.

### G-L review and remaining scope

L1 equivalence passes for its checked scopes; memory growth and sleeping cost
screens are negative evidence for a universal stride increase in these fixtures.
Near-unity dense medians do not establish that8-byte cells are free. No candidate
is selected for production. L2 is admitted for the registered packing comparisons;
L3/L4 remain mandatory and G-L stays OPEN. L5's compatibility inventory remains
source evidence. L6 is not admitted: these fixed-geometry results do not establish
that halving storage dimensions helps, and no cache-causality profile was acquired.

WPR read-only queries advertise PMU sources including cache misses, cycles and
retired instructions; do not call the hardware counters unavailable. No PMC session
or WPR recording was active, the session is not elevated, and this campaign acquired
no PMU/cache/bandwidth trace. These remain explicit evidence gaps. There is no new
desktop/Web, sanitizer, other-hardware, migration or deployment acceptance.

The baseline remains at its original checkpoint with the same dirty DLL hash after
the campaign. No shared runtime, branch, policy, dependency or historical M11 hash
was changed.

### L1 documentation checkpoint

Byte-copy snapshot checks under `validation/local/issue-16/l1-review-checks` pass
documentation links/claims and M11's28 historical source hashes/18 records.
Repository validation retains exactly the same14 published source-input attestation
failures as preparation, seven Windows and seven Linux; all18 required runtime
files are materialized. This is not an all-green runtime release. The baseline's
earlier16 failures remain retained and were not rewritten.

Frozen retrieval remains23/32 hit@1,32/32 hit@5, MRR0.8385; challenges12/16,16/16,
0.8562. Programme is3/5,5/5,0.7667 (previously0.8 MRR); layout questions2/3,3/3,
0.8333. Query wording and frozen fixtures were not tuned. Layout expected facts
were updated for the owner release and completed L1 stage. Context review finds
the current stage, comparison methods and memory qualifiers; the footprint query
still prefers the save page first and needs its second-ranked canonical context.

`git diff --check` passes. The recoverable local results commit has subject
**Record issue16 L1 stride results and cost review** on
`codex/issue-16-cell-layout`; its exact ID is retained with the local campaign's
post-commit identity. It adds the reducer and scoped evidence, without changing
the measured native implementation or integrating the experiment.

## L2 preparation, September11

The owner explicitly continued the uncontended window for the remaining stages.
The [L2 registration](../operations/cell-layout-experiment.md#l2-implementation-registration-september11)
was retained before candidate code at `validation/local/issue-16/l2-registration`,
SHA-256 `64c43aa911be21acad84270102e998105e513e60bdac1f5c21a4b3cadb4b7738`.
It defines matched-alignment primary controls and representative comparisons
against both retained L1 executables. No L2 timing result is claimed here.

New modules are `native/include/cybersand/cell_layout_storage.hpp`,
`native/tests/test_cell_layout_storage.cpp`, `tools/experiments/cell_packing.py`,
its Python tests and `summarize_cell_packing.py`. World uses the same inline
material/state/epoch accessors for all new variants. Default unselected builds
remain byte fields, size4/alignment1; primary byte4/packed4 use size/stride/alignment4,
byte8/packed8 size/stride/alignment8. Byte controls retain offsets0/1/2/3. Packed
fields use the registered integer masks/shifts; no compiler bitfields, raw-struct
serialization, epoch-width change, new material, solver change or shared DLL edit.

Prepared artifacts are in `build/issue-16/prepare-l2-20260911-003219`, raw evidence
in `validation/local/issue-16/prepare-l2-20260911-003219`. Source is results commit
`ed7719199f0ef36335f3f1ad798ab58037501d83` plus the hashed candidate delta, recoverable
in the local preparation commit **Prepare issue16 matched-alignment packing campaign**.
Compiler/pins and warning/optimization flags are unchanged from L1; each executable
has explicit width/alignment/packing defines in `prepared.json` and command records.

| New O3/LTO executable | SHA-256 |
|---|---|
| byte4 | `57c675ae0252bb90ebb169e3c763a2407446979bbf61592d5be3f70884de9c96` |
| packed4 | `b3b19ee0221fef67d20199747950a3aa2b207d5c176f7dc0078800363e13d60b` |
| byte8 | `fea1bfac12ab68102020f119fe6c82e5543aff85456e579e7f512d337faff677` |
| packed8 | `b31101df39d1266e085a6c0cc3ed9b797c394a885f905e46fa11c90b74cc54fe` |

**Executed correctness:** the unselected build and four variants each pass55 native
tests,275 total. Each variant passes26,214,400 storage mappings (80 accepted IDs,
65,536 state-byte pairs and five epochs),104,857,600 total, including exact word
mapping, unused-zero, copy and setter isolation. Invalid Rocket headings are never
stepped by this storage-only check. All80 full1800-tick behavior processes match
retained L1 exact streams across five settings, variants,1/4 workers and repeats;
eight observer-off streams also preserve state/work. These contain every-tick
closed Water/Sand checks and reactive event/state/temperature comparisons. All40
one-tick dense/sparse/sleeping setup checks match retained L1 records and fit
unchanged capacities. C11 header validation passes. Python plan/hold/reducer checks
pass, with a regression for lossless comparison against compressed retained records.

**Retained preparation failure:** after all builds/storage/behavior checks and the
first successful native setup process, the new driver tried opening an uncompressed
L1 setup record; the retained file is `.records.gz`. It exited with FileNotFoundError.
The reader now compares gzip content in bounded blocks. Before finishing setup,
recovery verified every native/benchmark input and binary hash plus all88 compressed
behavior/observer records. Only the Python reader changed. The first completed
setup process was reused and the39 remaining setup processes ran once. No build or
behavior result was relabeled as newly rerun. Failure, driver before/after hashes,
resume command/log and completed manifest are retained; this was a harness-path
failure, not a layout mismatch or a performance sample. Five inherited/experiment
conversion/capture warnings remain; no new storage compiler warnings or errors.

**Generated-code findings:** actual LTO write/move/scan/clear extracts are retained
for the old controls and four variants. The packed4 and packed8 clear loops contain
SSE loads, masks and stores, with scalar tails at epoch offsets3 and7 respectively;
aligned byte controls still use scalar byte stores. Identical O3/LTO flags generated
this difference; no variant-specific optimizer tuning was applied. Shared accessors
also change some control code generation, so the registered control-bridge screen
remains necessary and is not assumed neutral.

The packed8 `stored_material` assembly uses an8-bit load; its actual LTO `write_cell`
loads a whole64-bit word but compares the low material byte and extracts state at
bits16/24. There is no standalone retained LTO getter symbol. This confirms the
registration's limit: the16-bit field is a carrier for legacy8-bit IDs, with its
upper byte zero, not an end-to-end16-bit ID access-cost result. Full wider-ID
interfaces/render/save/profile costs and demand remain L5's inventory and future
migration questions, outside this legacy-value timing comparison.

The next campaign has448 sequential processes:56 retained-control bridge processes,
280 primary packing processes and112 observer processes, seven pairs per series.
Both variants in each primary pair have equal size/stride/type alignment. The bridge
covers dense512/workers4 and sleeping4096/workers1 only and combines accessor and
alignment changes. All run lengths, metrics, thresholds and timeouts are registered;
no sample tuning follows these code-generation observations. G-L remains open.

L2 preparation documentation checks pass for docs and historical M11 using the
byte-exact companion-path snapshot in `l2-preparation-checks`. Repository validation
retains14 published-source attestation failures (seven each Windows/Linux), with
all18 runtime files materialized; this is not fresh platform acceptance. Retrieval
hit@1/hit@5/MRR is23/32,32/32,0.8385 frozen;12/16,16/16,0.8562 challenge;
3/5,5/5,0.7667 programme;2/3,3/3,0.7778 layout. Layout MRR regresses from0.8333:
the resident-byte question's canonical answer moves to rank3, still in the top5
with correct temperature/activity scope. This limitation is retained without
altering the frozen timing registration. Diff whitespace checks pass.

## L2 measured results, September11

All448 registered processes completed00:58–04:31 BST in the owner-released window.
Measured preparation commit: `b97c7c19c6c50fe13c6730d8c4e4004000732801`; evidence:
`validation/local/issue-16/timing-l2-20260911-005825`. Full reduction passed140 packing,
28 bridge and56 observer pairs, exact worker/repeat records, raw CSV/work consistency
and final whole-world Water/Sand accounting. No timing failures, retries or discarded
outliers. Frozen sources, six binaries, compiler and original dirty DLL were verified
unchanged after timing (`post-measurement-identity.json`). Reduced SHA-256:
`9eed000e629cf30c9ab033b400b1429e90f06dca3393d0ba8d06e0e52045346c`.

| Carrier | Fixture | Extent | Workers | Median p95 ratio | Median total ratio | Individual >15% pairs |
|---|---|---:|---:|---:|---:|---|
| packing4 | dense | 512 | 1 | 1.0151 | 1.0190 | [] |
| packing4 | dense | 512 | 4 | 1.0094 | 1.0109 | [] |
| packing4 | dense | 1024 | 1 | 1.0171 | 1.0140 | [] |
| packing4 | dense | 1024 | 4 | 1.0030 | 1.0046 | [] |
| packing4 | sparse | 512 | 1 | 1.0450 | 1.0544 | [3] |
| packing4 | sparse | 512 | 4 | 1.0229 | 1.0291 | [] |
| packing4 | sparse | 1024 | 1 | 1.0824 | 1.0675 | [1] |
| packing4 | sparse | 1024 | 4 | 1.0171 | 1.0353 | [] |
| packing4 | sleeping | 4096 | 1 | 1.0290 | 1.0080 | [] |
| packing4 | sleeping | 4096 | 4 | 0.9993 | 1.0093 | [] |
| packing8 | dense | 512 | 1 | 1.0054 | 1.0040 | [] |
| packing8 | dense | 512 | 4 | 0.9950 | 1.0068 | [] |
| packing8 | dense | 1024 | 1 | 1.0070 | 1.0058 | [] |
| packing8 | dense | 1024 | 4 | 1.0086 | 1.0089 | [] |
| packing8 | sparse | 512 | 1 | 1.1186 | 1.0683 | [4] |
| packing8 | sparse | 512 | 4 | 1.0230 | 1.0298 | [] |
| packing8 | sparse | 1024 | 1 | 1.0583 | 1.0587 | [] |
| packing8 | sparse | 1024 | 4 | 1.0306 | 1.0284 | [] |
| packing8 | sleeping | 4096 | 1 | 1.0247 | 1.0102 | [] |
| packing8 | sleeping | 4096 | 4 | 0.9877 | 1.0044 | [] |

No primary median exceeds15%; three individual pairs do, as retained above. Dense
packing cost is small here; sparse one-worker cost reaches11.86% median p95. The four
representative bridge medians span0.9859–1.0076 with no individual15% flags. This
supports matched primary interpretation, not universal control neutrality. Observer
p95 on/off medians span1.0464–1.0964; primary timings remain observer-off.

Cell capacities match within every primary pair.4-byte dense512/1024=11/18.125MiB,
sparse512/1024=5.4375/8.9375MiB,sleeping4096=72.25MiB;8-byte equivalents double these.
All component/metadata estimates and process memory remain in raw JSON. Allocator
bookkeeping is still a gap and process peaks include harness storage.

Sleeping paired wrap-neighbor proxy changes are−2.3287/−2.3069ms for packed4 at1/4
workers and−2.97665/−2.8592ms for packed8. These are whole-tick proxies, not direct
clear durations. Dense proxy outliers extend to−95.68385/+18.4977ms; ordinary work
noise cannot be attributed to clearing. Individual >1ms flags remain in the reduction.
Generated vector clear loops distinguish the carriers, without establishing cache
causality. No PMU trace was collected; the advertised-counter/access gap remains.
Sleeping dispatches no parallel phases; dense7680 and sparse6766/6831 dispatches are
inferred from unchanged threshold8. Worker total ratios remain descriptive across
separate case blocks, not interleaved worker-pair experiments.

Final whole-world Sand/Water match their initial values in all448 runs; Smoke changes
remain separate lifecycle ledgers. Timed semantic/events are final-only, with full
every-tick work; every-tick quantity/reactive parity belongs to prepared correctness.
No fresh desktop/Web acceptance or source-release attestation is claimed.

**Disposition:** L2 passes semantic compatibility with these cost flags and limits.
The16/40/8 carrier retains an8-bit enum and compiler-narrowed ID reads; it demonstrates
neither wider-ID demand nor end-to-end16-bit access cost. Proceed to epoch isolation;
L3/L4 remain mandatory and G-L stays open. A documentation helper initially failed
to decode existing UTF-8 through the Windows default code page; no timing or source
artifact changed. The corrected helper uses explicit UTF-8 mode.

L2 result checkpoint checks (`l2-results-final`) pass docs and M11; repository retains
14 source-release attestation failures and18 materialized runtime files. Retrieval
hit@1/hit@5/MRR: frozen22/32,32/32,0.8229; challenge12/16,16/16,0.8562;
programme3/5,5/5,0.7500; layout2/3,3/3,0.7778. Frozen/programme ranking regressions
from preparation are retained; all canonical answers remain in the top5. No fixture
or evaluator was tuned. Thirteen driver/reducer tests passed before measurement.
The L3 registration was retained before candidate code with SHA-256
`49437950aac0321015872f7360d987a87005697ef4ea53f7d182bdcf6f01606c`.

## L3 preparation, September11

Source is `925799d` plus the hashed candidate delta, to be retained in local commit
**Prepare issue16 epoch-width and clear-observer campaign**. Complete preparation:
`validation/local/issue-16/prepare-l3-20260911-045006`; binaries share that suffix
under `build/issue-16`. Toolchain, optimization and warning flags remain pinned.
Default epochs stay8-bit; only packed32 admits6-bit epochs, with two unused state
bits kept zero. Both candidates have size/stride/alignment4.

The default and both candidate suites pass55 checks each,165 total. Focused tests
pass26,214,400 storage mappings per candidate (52,428,800 total), all expected8/32
clears through2048 ticks, sleeping/excluded/partial selection and recorder-capacity
failure/quarantine/clear recovery.80 full2048-tick behavior/movement runs across
five settings,1/4 workers and repeats pass; eight observer-off runs preserve state/
work. Twenty setup/capacity trajectories match retained L1 records. The8-bit behavior
prefix matches retained1800-tick records. Physics diagnostics and lossless state/
temperature/work/event records remain correctness oracles, with hash omitted only
across epoch schemas. Additional retained-record verification checks same-schema
raw hashes and sorted per-chunk clear identities across repeats/workers.

Each movement run explicitly accounts for1024 Foam injections,1008 reclaims,16 final
Foam cells,30688 single-step moves (130 paused ticks) and40 event writes at the union
of the wrap schedules. New Fire retains initial lifetime on the event tick. These
are separate source/sink and event ledgers, not closed-Water conservation claims.
Observer durations collected during correctness are not performance samples.

The first preparation attempt (`prepare-l3-20260911-044403`) failed because the new
negative test caught runtime_error for a quarantined retry; the existing contract
correctly throws logic_error. Source-location diagnostics confirmed it. Only the
expectation/diagnostic changed, with no World behavior fix; fresh preparation reran
the registered checks. Failed logs and disposition remain retained. Nineteen build
warnings remain: five inherited/previous conversion warnings and fourteen bounded0..15
array-index signedness warnings in the correctness-only MotionCheck fixture. None
is a truncating Cell conversion; both variants use identical flags and code.

Generated assembly retains vector mask/store clear loops for both widths;6-bit
advance has the expected AND63. Actual LTO disassembly is retained. This is code
shape evidence, not hardware-cache attribution. Direct metadata collection occurs
before its clock, and per-clear identities are serialized after ticks. The recorder
has64 summaries and64×4096 chunk slots,8,390,728 heap bytes when enabled. A separately
retained pinned-compiler sizeof probe reports World39,984 bytes with recorder support
versus39,968 without, including WorldConfig39,640 bytes (do not add config twice).
Thus support adds16 object bytes even when off; the enabled buffers are separate
from hot cells and existing metadata estimates. Allocator/process gaps remain.

| Optimized executable | SHA-256 |
|---|---|
| e8 | `2e4cf6730741db16c08795a23e35d947efc27c44966129474a5ab216f2159a39` |
| e6 | `7c83089b179576957002028760a3e6e5fb8c882b67c5a2ecacf62a8d82859381` |

L3 timing is not yet started at this checkpoint. The registered280 processes retain
all samples and the existing review screens. Direct on-mode widths occupy separate
observer blocks; primary epoch-width pairs have recorders off. This limits direct
cross-width causal claims. No production layout, epoch width, merge or deployment
is approved. L4 and the final G-L disposition remain outstanding.

The additional verifier passes60 same-schema raw-hash/repeat/worker comparisons with
exact sorted clear identities and eight observer hash/state/work comparisons. All20
Python tests pass. The first L3 doc check passes docs/M11 and retains14 release
attestation failures/18 materialized runtime files. Its retrieval scores were frozen
23/32,32/32,0.8385; challenge12/16,16/16,0.8562; programme3/5,4/5,0.7000;
layout2/3,3/3,0.8333. AP04's master-programme baseline fell outside top5 as new
preparation pages outranked it. The master checkpoint now explicitly distinguishes
the preserved current baseline from the prepared6-bit research variant; the fixed
retrieval fixture/evaluator is unchanged and both results are retained.

Final preparation doc checks (`l3-preparation-final`) again pass docs/M11 and retain
the same14/18 release/materialization scope. Retrieval hit@1/hit@5/MRR: frozen 22/32,32/32,0.8229; challenges 12/16,16/16,0.8562; programme 3/5,5/5,0.75; layout 2/3,3/3,0.8333.

## L3 measured results, September11

Frozen source `6e89398dbfc776d9b93bfc9f94a37e0f07c83ac8`; timing directory
`validation/local/issue-16/timing-l3-20260911-052112`,05:21–07:13 BST. All280
processes exit0, no retries or exclusions. Full reducer passes70 epoch,14 bridge,
56 observer pairs, same-schema raw records, worker/repeat and final Water/Sand.
Reduced JSON SHA-256:
`0615608359b2d41b362ae191be90fa7b3d1553c2e1ad069f15dab7d447d39819`.
All samples, direct chunk identities, commands/timeouts and frozen identities remain
retained. Original checkout HEAD/dirty DLL hash remain unchanged.

| Fixture | Workers | Median p95 six/eight | Median p99 | Median total |
|---|---:|---:|---:|---:|
| dense512 |1|1.0007|1.0174|0.9992|
| dense512 |4|1.0202|1.0476|1.0131|
| dense1024 |1|1.0007|0.9998|0.9989|
| dense1024 |4|1.0050|1.0139|1.0001|
| sparse512 |1|0.9905|0.9718|0.9945|
| sparse512 |4|0.9986|0.9903|1.0010|
| sparse1024 |1|0.9963|1.0181|1.0093|
| sparse1024 |4|1.0304|1.0349|1.0038|
| sleeping4096 |1|1.0068|3.9931|1.0567|
| sleeping4096 |4|0.9916|3.8090|1.0485|

No primary median p95 exceeds15%; sleeping one-worker pair5 does individually.
Bridge p95 medians1.0116/0.9981 and observer medians0.9969–1.0324 have no individual
15% flags. Direct observer-on widths occupy separate blocks, limiting direct
cross-width causal comparisons. Primary epoch pairs have observers off.

| Recorder | Workers | Clears over7 runs | Direct p50/p95/max ms |
|---|---:|---:|---|
| eight-bit sparse1024 |1|56|0.5672 /0.8423 /0.9104|
| eight-bit sparse1024 |4|56|0.6907 /1.0681 /1.3176|
| eight-bit sleeping4096 |1|56|8.3709 /8.8028 /8.8980|
| eight-bit sleeping4096 |4|56|8.3476 /9.0699 /10.0437|
| six-bit sparse1024 |1|224|0.5336 /0.8239 /1.4991|
| six-bit sparse1024 |4|224|0.6479 /0.8958 /1.1093|
| six-bit sleeping4096 |1|224|8.3816 /9.1622 /10.7900|
| six-bit sleeping4096 |4|224|8.4052 /9.4697 /10.5031|

The2048-tick run has8 versus32 clears, with8 versus31 in the1928-tick steady
window; the first six-bit clear is retained in warmup. Long-run cadence is255/63,
not exactly4. Whole-tick neighbor proxies remain distinct from direct duration.
Sleeping clears still cost about8.4ms while their frequency increases. Sleeping
p99 rises3.81–3.99x and total time4.85–5.67%. This is a sound negative shorter-epoch
result at unchanged semantics, with no benefit from the unused extra two bits.
No production width or epoch is selected. PMU/cache attribution, other hardware
and fresh desktop/Web acceptance remain gaps. L4's concrete neutral-payload
registration now precedes candidate code; G-L remains open until its result.

L3's whole-tick neighbor proxy subtracts the eight-bit neighbor excess at the same
World tick as each six-bit wrap, rather than pairing unrelated wrap indices. It
includes all224 candidate wraps per fixture/worker. Counts over1ms for workers1/4:
dense51237/77,dense1024125/130,sparse5120/5,sparse102412/32,sleeping224/224.
Median proxies (ms,workers1/4) are0.481/0.671,1.056/1.563,0.189/0.344,
0.606/0.693 and8.596/8.534 respectively. Dense extrema span−11.275 to13.584ms;
these noisy whole-tick differences are retained, not relabelled direct clear costs.

## L4 preparation and coverage review, September11

Concrete registration preceded code, retained as
`validation/local/issue-16/l4-registration/cell-layout-experiment.md`, SHA-256
`f29583c4372443a33962acb95242d9fa77acf0d74c90c2b2b1bb9b34c2fe2e86`.
The first720-run preparation (`prepare-l4-20260911-073030`) passes exact carrier/
worker/repeat records but fails accepted-operation coverage: advancing endpoints
on each operation leaves zero successful moves/splits/creates in long runs.
Focused hand-expected operations pass, which does not cure that workload gap.
No performance measurements were launched from it. Partial independent replay was
deliberately stopped after coverage rejection; logs, exit and all720 records remain.

The revised cycle was registered before its build, retained as
`l4-registration/revised-cell-layout-experiment.md`, SHA-256
`b4f7a5a6cd776adb5a02b1479717e8d21c2ea349e9e134b0315f47c92070d57c`.
It performs a complete clear/reclaim/create/split/merge/move/swap/read cycle at
one adjacent pair, then advances. Geometry, capacities, density, sample and timing
budgets remain unchanged. Fresh preparation is `prepare-l4-20260911-073748`.
The independent Python replay uses a flat tuple store and separately implemented
transactions; it retains every-batch Sand/Water-cell/Fire source/sink ledgers as well
as Water mass and neutral tags. Four offline replay processes may run concurrently
before timing; they are excluded from the performance campaign.

L3-result documentation checks pass docs/M11, with the same14 published source
attestation failures and18 materialized runtime files. Retrieval hit@1/hit@5/MRR:
frozen22/32,32/32,0.8229; challenge12/16,16/16,0.8594; programme3/5,5/5,0.7400;
layout2/3,3/3,0.8333. No historical hashes or retrieval fixtures changed.

Fresh L4 preparation completes720 accessed runs plus12 absent/unread smoke runs;
all carrier/repeat/worker records match. All eight operation kinds succeed:
move/swap/split/merge each113697–115200 accepted attempts per run; the other four
each115200. Half the runs exercise capacity refusal, up to4509 total refused
attempts per run. Refusals preserve endpoints and remain part of work comparisons.
No C++ new calls occur inside any batch. Three native self-test executions cover
seams, state/temperature transfer, high-bit tags, actual unprepared arrays,
saturation/refusal, full-capacity moves and reclaimed slot reuse. All23 Python
tests pass. These new standalone files do not change World or adapter behavior;
the retained L3 native tests are not claimed as fresh L4 executions.

| Revised optimized executable | SHA-256 |
|---|---|
| inline | `d354c9a259bec1589383283fc6db2b9887798c0e353e058bc850ea1c19bdb0ca` |
| soa | `de82f289273543a4cf0f31a1c9a1c633e9268148abe3581975b68985ad581407` |
| sparse | `acbfd12cc00e1ebdb6173dc9ab60fb0118cbefb71ae5fdf3f06b146095a20b40` |

All three builds have zero warnings with the pinned Clang flags, and their LTO
disassemblies are retained. Inline/SoA/sparse hot strides are8/4/4, all alignment4.
Their sixteen Chunk objects occupy1024/1408/1792 bytes, already included in Fixture
sizes5760/6144/6528; do not add them twice. Pool object160 and timing buffers506880
bytes are separate (correctness buffers475200). Process counters include committed
runtime/allocator/thread memory; allocator headers, stack residency, thread-library
allocations and PMU/cache traffic are not individually attributed. Batch C++ new
screening does not prove absence of arbitrary malloc or OS allocations.

The rejected fixture source was recovered exactly from the revised source and its
registered schedule, retained as `prepare-l4-20260911-073030/original-cell_sidecar.cpp`
with SHA-256 `0bb3f010e0f8770936c8929198669826b11801969b4f6e2d1c427b662c6b1ec4`,
matching the original source identity. The revised build manifest is retained
unchanged as `prepared-build.json`; `validation-source-update.json` records only
the later offline reducer change (periodic unread checksum and four-process replay).
No benchmark, compiler, driver preparation function or native input changed in that
validation update. Timing still requires completed independent replay and frozen
source/executable identities.

### Prepared optional-state footprint

Observed resident arrays in MiB, including legacy cells and temperature; descriptor,
worker/buffer and process memory are separate. These allocated capacities do not
grow during batches. Density is initial global density, not final active density.

|Initial density|Pattern|Prepared chunks|Inline|SoA|Sparse|
|---:|---|---:|---:|---:|---:|
|0%|clustered|0|2.5000|1.5000|1.5000|
|0%|dispersed|0|2.5000|1.5000|1.5000|
|1%|clustered|1|2.5000|1.5625|1.5517|
|1%|dispersed|4|2.5000|1.7500|1.6469|
|5%|clustered|1|2.5000|1.5625|1.6317|
|5%|dispersed|4|2.5000|1.7500|1.7270|
|15%|clustered|3|2.5000|1.6875|1.8942|
|15%|dispersed|12|2.5000|2.2500|2.1809|
|50%|clustered|8|2.5000|2.0000|2.7500|
|50%|dispersed|16|2.5000|2.5000|3.0078|
|100%|clustered|16|2.5000|2.5000|4.0000|
|100%|dispersed|16|2.5000|2.5000|4.0000|

Zero-density allocated-unread deliberately prepares all16 chunks with cap64:
SoA2.5000MiB and sparse2.0078MiB versus inline2.5000MiB. Absent/accessed zero-density
sidecars remain unallocated,1.5000MiB versus inline2.5000MiB. Sparse includes its
per-cell indices and8-byte capacity slots. For this neutral4-byte payload, the
observed sparse/SoA allocation crossover lies between1% and5% clustered density,
and between15% and50% dispersed density. This depends on payload size, distribution
and the declared64-slot headroom; it is not a universal crossover or speed result.


The registered dispersed pattern is strided, not uniform random placement. At1%
and5% it prepares four chunks, and at15% twelve; the exact per-chunk occupancies
are retained. Uniform random scatter and other payload sizes are unmeasured.

All60 independent input replays pass every-batch work and complete final state,
including separate Sand/Water-cell/Fire sources/sinks, Water mass and tag ledgers.
Twelve absent/unread smoke records also match exact replay. `verified.json` binds
these results to the preparation, comparison and smoke manifests. The measure
entry point refuses missing/mismatched verification, source, compiler or binaries.
This completes L4 preparation; the registered1400-process campaign remains to run.


The first L4 preparation documentation check passes docs/M11 with14/18 retained
release/materialization scope. Retrieval scores: frozen22/32,32/32,0.8229;
challenge12/16,16/16,0.8594; programme3/5,4/5,0.7000; layout2/3,3/3,0.7778.
AP04's baseline owner fell outside top5. The programme checkpoint now gives the
preserved Cell/epoch/recent-Water baseline its own clear explanation, separate from
execution progress. Questions and evaluator remain fixed; both checks are retained.

Final L4 preparation docs/M11 pass, with unchanged14 release errors and18 materialized
runtime files. Retrieval hit@1/hit@5/MRR: frozen 23/32,32/32,0.8385; challenges 12/16,16/16,0.8594; programme 4/5,5/5,0.9; layout 2/3,3/3,0.8333.

## L4 measured results and final G-L, September11

Frozen timing commit `d71c9342ccf37b0fda7d34d5b083d243091f7fde`; campaign
`validation/local/issue-16/timing-l4-20260911-074955`,07:49:55–07:58:06 BST.
Prepared-file hashes are identical to the committed release source; release identity
resolves the preparation manifest's earlier HEAD plus local delta. All1400 registered
processes exit0, with no retries, failures or sample exclusions. Builds/tests/full
reductions do not overlap the campaign. The pre-run process snapshot is empty for
benchmark/build/Godot executables; Balanced power remains unchanged. The owner
released this window for the remaining stages. No claim of zero OS/background noise.

Full reduction passes700 interleaved pairs and exact records across all carriers,
repeats and worker counts. Twenty-five independent1920-batch input replays verify
work, complete state and explicit species/Water/tag ledgers. A separate checker
verifies every one of1400 metadata records against independently computed initial
occupancy/capacity/final occupancy and footprint. Binaries/compiler/source hashes
and original checkout/DLL remain unchanged after timing. Reduced JSON SHA-256:
`ed950977ba0aba06e39102fe6bd433fb3c9be650f0e49f5d43edc15b20fab648`.

Six supplemental observer-off/on semantic checks run **after** timing at15% strided
density,1800 batches, all carriers and1/4 workers. Their work and full final state
match preparation exactly; clocks are excluded from the1400-process campaign.
The common transaction/work-counter cost is included in timings, not subtracted.
No separate estimate of an uninstrumented transaction kernel is claimed.

### Active access cost

Median of seven paired steady p95 candidate/inline ratios. Density is initial
payload density; workloads and capacity refusals match exactly within every pair.
Batch units are512 attempted transactions, including invalid/refused operations.

|Initial density|Pattern|SoA1 worker|SoA4 workers|Sparse1 worker|Sparse4 workers|
|---:|---|---:|---:|---:|---:|
|0%|clustered|1.1886|0.8659|1.0833|1.2083|
|0%|dispersed|1.1989|1.1304|1.0578|1.0345|
|1%|clustered|1.1421|1.1068|1.0533|1.1467|
|1%|dispersed|1.1751|0.8718|1.0909|0.8632|
|5%|clustered|1.1022|1.1333|1.0267|0.9398|
|5%|dispersed|1.1739|1.2375|1.1486|1.1429|
|15%|clustered|1.1714|1.0400|1.1044|1.0779|
|15%|dispersed|1.2527|1.2410|1.1685|1.2537|
|50%|clustered|1.1348|1.2025|1.2184|1.4595|
|50%|dispersed|1.2083|1.4578|1.2609|1.4157|
|100%|clustered|1.2158|1.6286|1.3913|1.5256|
|100%|dispersed|1.2614|1.2317|1.4477|1.4815|

Of100 comparison series,27 median p95 ratios exceed the15% research screen;
231 of700 individual pairs do. Twenty-six flagged medians are actively accessed
cases; one is sparse allocated-unread/four-worker. These are research review flags,
not production limits. All individual pairs/outliers remain in reduced.json and
summary.md. No candidate is tuned or selected from these results.

One-worker allocated-unread medians range0.9815–1.0000 for both sidecars. Absent
one-worker ratios are0.9818 SoA and1.0000 sparse. Four-worker unread ratios vary
0.7931–1.1304 SoA and0.7500–1.2069 sparse; absent ratios1.0000/1.1290. Tiny batches,
barriers and host timing variability limit interpretation of apparent wins and tails.

|Active carrier/workers|Median-pair p50 range|p99 range|max range|total range|
|---|---|---|---|---|
|soa/1|1.1678–1.2313|1.0850–1.2649|0.6871–1.6754|1.1265–1.2572|
|soa/4|1.0179–1.7407|0.4973–2.2458|0.7422–2.6295|0.9422–1.6482|
|sparse/1|1.0604–1.4510|1.0102–1.4205|0.7598–1.5889|1.0617–1.3864|
|sparse/4|1.0000–1.5556|0.7742–2.2609|0.4249–3.8008|0.9268–1.5584|

### Batch scale, worker scope and memory

These descriptive medians pool the registered cases/replicates within each row.
Worker blocks are not interleaved worker-count A/B trials; do not infer scheduler
scaling in World. One/four workers execute the same eight exclusive chunk-pair
streams. Pool/barrier cost is included. Absent/unread units are8192 legacy reads;
active units are512 attempts. Startup and all120 warmup samples remain separate
from1800 steady samples; full p50/p95/p99/max/total and process memory are retained.

|Mode/carrier|Median p95 µs,1/4 workers|Mean ns/unit median,1/4 workers|
|---|---|---|
|absent/inline|5.400 /2.800|0.656 /0.303|
|absent/soa|5.400 /3.200|0.648 /0.312|
|absent/sparse|5.400 /3.300|0.652 /0.307|
|unread/inline|5.400 /2.800|0.654 /0.305|
|unread/soa|5.400 /2.700|0.650 /0.292|
|unread/sparse|5.400 /2.700|0.651 /0.300|
|active/inline|18.050 /8.050|30.432 /11.840|
|active/soa|21.300 /9.100|35.781 /14.227|
|active/sparse|20.400 /9.050|34.383 /14.070|

The prepared footprint table above is verified unchanged during timing. At full
initial density sparse arrays occupy4.0000MiB versus2.5000MiB inline/SoA, and sparse
one-worker p95 rises39.1–44.8%. At zero absent density both sidecars save1MiB of
resident arrays. Sparse/SoA capacity crossover lies between1–5% clustered and15–50%
strided initial density. Metadata/address lookup/refusal work is included; these
results apply only to this4-byte neutral tag and declared capacity policy.

Across active runs, process private memory ranges3.672–3.863MiB for inline,
2.613–3.863MiB for SoA, and2.625–5.355MiB sparse. Working set/peak counters and every
per-chunk high-water/capacity value are retained, not treated as allocator-exact
accounting. Median startup across active cases is2.754/3.986ms inline,2.596/3.871ms
SoA,5.108/6.310ms sparse (workers1/4), including preparation and100 empty pool cycles.

Active tag counts evolve through the declared source/sink transactions. For both
patterns initial counts0/2621/13107/39321/131072/262144 end at
0/2500/12484/37384/124552/249104. Initial100% therefore ends about95.0%; this is not
a constant-density access curve. Initial placement is fixed strided dispersion,
not uniform random scattering. No real material payload demand, World integration,
liquid/physics improvement or full-world streaming bandwidth follows from this carrier.

### Final gate and remaining uncertainties

L1 establishes a width tax without added semantics, including a15.04% median
sleeping/one-worker p95 flag and doubled Cell arrays. L2 establishes lossless packing
controls with modest or adverse costs and no production winner. Its wide getter
still returns the legacy8-bit enum, so it does not measure a real16-bit catalogue.
L3 establishes safe shortened bookkeeping in the tested fixtures, but four times
as many clears over2048 ticks and much worse sleeping tails. L4 establishes bounded,
lossless neutral carriers with a distribution-dependent memory crossover and active
access costs; it does not authorize a sidecar API in World. L5 finds175 unused byte
IDs, no demonstrated larger-ID demand, and explicit ABI/profile/render/save/state-ID
migration costs. Generic10/14/8 is non-equivalent for accepted byte states.

**L6 not admitted:** direct measurements identify all-resident clearing cost, whose
cell count is not reduced simply by halving storage edge. No PMC/locality evidence
supports a64-square storage comparison. The retained4352-square large reservation
would require68²=4624 storage chunks at64, above the fixed4096 cap, requiring a new
capacity charter. This is a supported non-admission, not proof that64 could never
help another workload. Keep storage/activity/core/radius128/32/64/2 unchanged.

**G-L evidence is complete locally.** Valid equivalent experimental carriers can
support later P/M questions. No production4-byte retention,8-byte migration, shorter
epoch, larger-ID catalogue, extra velocity/history, lossful encoding or scheduler
resize is approved. No merge, deployment, push or remote issue closure is performed.

Remaining gaps: one Windows host and pinned compiler; no fresh Linux/Wasm/desktop
or Web acceptance; no PMU trace/cache/bandwidth attribution (WPR advertises sources,
but no elevated PMC capture was collected); allocator/OS allocation detail and common
instrumentation cost; real sidecar payload/ownership integration; constant-density
and uniform-random access; larger-ID execution beyond legacy values. Retained #9/#10/
#13/Water evidence supplies baseline facts only. Correctness/footprint results are
stronger than causal performance conclusions for tiny four-worker batches.


### Final local validation and recoverability

`validation/local/issue-16/final-results` passes check_docs and historical M11.
Repository checking retains14 published-runtime source-attestation errors and18
materialized runtime files; this is not an all-green release or a reason to replace
the deliberately dirty DLL. Frozen retrieval hit@1/hit@5/MRR23/32,32/32,0.8385;
challenge12/16,16/16,0.8594; programme4/5,5/5,0.9000; layout2/3,3/3,0.8333.
Fixed questions/evaluator remain unchanged. Manual route review distinguishes
completed experimental evidence from production approval and preserves baseline
Cell, recent Water, ownership, pause/quarantine and issue11 caveats. Diff checks pass.

The final results checkpoint is the local commit named **Complete issue16 Cell
layout research and record G-L evidence** on `codex/issue-16-cell-layout`, following
preparation `d71c9342ccf37b0fda7d34d5b083d243091f7fde`. Its resolved hash is returned
to the owner and retained in local completion metadata. Source/build/evidence remain
in this issue worktree. Original HEAD remains b16408c and its only dirty DLL retains
SHA-256 `fc6cb4ee1096219f581bace3df04ee8138e996aaf4c1436f5b2c071ea62dd496`.
No merge, deployment or remote mutation was performed.
