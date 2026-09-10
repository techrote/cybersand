---
title: Issue 16 source intake and preparation
status: Current
document-kind: evidence
scope: Local source review and preparation checkpoint; performance held by owner and G-L incomplete
canonical-for: []
last-reviewed: 2026-09-10
related-documents: [../operations/cell-layout-experiment.md, ../operations/architecture-programme.md]
---

# Issue 16 preparation checkpoint

## Identity and outcome

**Current inspection:** separate branch `codex/issue-16-cell-layout` in
`C:/kybersand/worktrees/issue-16-cell-layout`, from local planning commit
`b16408c28de67e3b30ebb1f0172e78d594296052`. Baseline branch
`codex/architecture-programme` had only the deliberately dirty Windows DLL,
SHA-256 `fc6cb4ee1096219f581bace3df04ee8138e996aaf4c1436f5b2c071ea62dd496`.
It is not the experiment control. Baseline source includes current Water work;
older remote main and published runtime manifests are not substitutes.

**Owner hold:** stop before performance measurements while issue15 may run.
This checkpoint prepares the first staged comparison; it does not close issue16.
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

| Stage | Disposition at preparation |
|---|---|
| L1 stride | Built and correctness-screened; ready for first uncontended timing run, held by owner. |
| L2 packing/ID access | Registered; implementation and measurement pending L1 review. |
| L3 epoch | Registered; implementation and2048-tick clear-tail measurement pending L2. |
| L4 optional state | Registered neutral control; concrete sidecar implementation/crossover pending. |
| L5 ID inventory | Source review recorded above; larger IDs have capacity headroom but no demonstrated demand. |
| L6 storage geometry | Not admitted: no profiling evidence yet. |
| G-L | OPEN; no winner, migration approval, negative timing result or completed issue claimed. |

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

## Ready-to-resume handoff

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
