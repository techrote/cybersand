---
title: Issue 16 source intake and Cell layout evidence
status: Current
document-kind: evidence
scope: Local source review, preparation and first L1 campaign; remaining stages and G-L incomplete
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

**Current checkpoint:** the owner released the first uncontended run after the
preparation commit `b2d8faffa86e472875ba74f7c6b1488bbdd06f8a`. L1 completed on
September10–11; [results below](#l1-results). The original preparation
hold and its evidence are retained as history. This does not close issue16.
The [registration](../operations/cell-layout-experiment.md) precedes candidate code.

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

## Gate disposition and remaining work

| Stage | Disposition after L1 review, September11 |
|---|---|
| L1 stride | Completed196 processes; exact comparisons pass, sleeping p95/wrap-tail costs flagged. |
| L2 packing/ID access | Prepared and correctness-screened; matched-alignment timing remains pending. |
| L3 epoch | Registered; implementation and2048-tick clear-tail measurement pending L2. |
| L4 optional state | Registered neutral control; concrete sidecar implementation/crossover pending. |
| L5 ID inventory | Source review recorded above; larger IDs have capacity headroom but no demonstrated demand. |
| L6 storage geometry | Not admitted: no profiling evidence yet. |
| G-L | OPEN; L1 negative/ambiguous cost evidence retained, no winner or migration approval; issue incomplete. |

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
