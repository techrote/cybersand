---
title: Soliding measurement contract
status: Planned
document-kind: runbook
scope: Stage 3 discovery and Stage 4 acceleration measurements, beginning with immutable Current ordinary-sleep controls
canonical-for: [soliding-measurement-contract]
last-reviewed: 2026-09-19
related-documents: [architecture-programme.md, ../systems/activity-dirty-regions-and-waking.md, ../architecture/data-ownership-and-lifetimes.md, local-build-and-validation.md]
---

# Soliding measurement contract

## Admission and control identity

**Planned measurements, registered 2026-09-19:** issue [#12](https://github.com/techrote/cybersand/issues/12)
compares its discovery cost and later stationary acceleration against **Current ordinary
sleep**. This contract does not admit an acceleration implementation or infer cohesion
from sleeping. Stage 3 must establish a bounded discovery cost model before Stage 4's
bake-off. The historical Phase 0 observer is neither the scalable candidate nor the
performance control. Stages 6/7 retain macro-dynamics and coherent child fracture as
first-class goals; a native timing control proves neither.

The first control is main `de332ea`, after the #27/MS-000 merge. The runner resolves this
abbreviation to a full commit and copies native source/header blobs from that commit
into its unique evidence directory before compiling. The standalone harness is an
explicit additional input, hashed separately. Subsequent dirty discovery/lifecycle edits
cannot contaminate that control. Do not replace #26's Water control or rewrite Phase 0
identities. A later control at another revision requires a new named artifact and an
explicit comparison scope.

**Current tooling:** [native harness](../../native/bench/soliding_baseline.cpp) and
[sequential driver](../../tools/experiments/run_soliding_baseline.py) use unmodified
World APIs. No material, World, adapter, Rapier, renderer or default runtime behavior is
changed by compiling this harness. The default compiler is the workspace's pinned
LLVM-MinGW 20260826 UCRT Clang 23.1.0; the runner refuses a different reported version.
Exact compiler, input and executable SHA-256 values accompany every prepared artifact.

## Registered control matrix

| Variable | Initial registration |
|---|---|
| Host | Local Ryzen 5 2600X, 6 cores / 12 logical processors; record actual OS, CPU, memory and power plan |
| Backend / workers | Phased, 1 and 4 native workers; ordinary quiet3 |
| Geometry | Current 128 storage / 32 activity / 64 scheduling / radius2 |
| Resident area | Dense 512Ã‚Â², 1024Ã‚Â² and 2048Ã‚Â² fixtures, plus one reserved 128-cell halo on all sides |
| Repetitions | 7 separate processes per fixture/size/worker tuple; sequential, no overlapping build or benchmark |
| Startup / warmup | 120 initial-settling ticks plus 120 further warmup ticks, both retained separately from measured ticks |
| Measurement | 2048 ticks per process, including at least eight epoch-clear opportunities |
| Translation | Timing at (0,0); behavior supplement uses (0,0), (127,1), (-129,-1), (65,64), (-257,1) |
| Capacities | Fixed maximum/reserved-active chunks 1600, active cores 9216, deferred events 1024; no adaptive resize |
| Rendering / body coupling | Absent; no DLL or Web export is produced by this control |
| Physics instrumentation | Existing TickStats only; optional event diagnostics disabled |

The runner records the complete process schedule before execution. Timing repeats are
interleaved across fixture/size/worker configurations to expose run-order drift. The
Current-only matrix is **not** an A/B comparison. A later candidate needs seven
interleaved source-matched baseline/candidate process pairs, unchanged fixture inputs,
and a separately registered observer-off neutrality check. Preserve every sample,
nonzero exit, malformed output and timeout; never silently trim tails or retry over an
old evidence directory. A failed process remains a result while subsequent independent
configurations may continue. Smoke runs use explicitly smaller arguments and are
labelled outside the registered timing campaign.

## Fixtures and protected behavior

| Fixture | Construction and stimulus | Required control behavior |
|---|---|---|
| `wall` | Solid Wall square | No measured movement or content change |
| `redbrick` | Solid RedBrick square | No measured movement or content change |
| `local-edit` | Solid Wall; centered 8Ãƒâ€”8 patch alternates Empty/Wall every 32 measured ticks | Exact edit ledger; local scheduler wake and return-to-sleep work is retained |
| `granular-rest` | Closed Wall basin, shelf 32 cells above floor; lower-half Sand rests on shelf | No measured movement or content change; rest never supplies rigid eligibility |
| `granular-release` | Same Sand basin; remove centered 32-cell shelf segment at first measured tick | Sand moves under Current rules and remains contained/conserved; no body or cohesion exists |

The basin has side walls and an intact lower floor. Initial/final material census covers
the fixture plus its complete reserved halo. External edits have a signed per-material
ledger. Census, content/state hashing, setup, vector allocation and JSON output occur
outside tick timing. **Measurement protocol v2:** initial census/hash occurs after
settling and before warmup, so the measured block immediately follows the warmup
ticks without a global scan perturbing caches. All registered fixtures must show no
warmup movement or dirty chunks before their measured stimulus; otherwise the run
fails. Previous v1 smoke/artifact attempts remain retained and are not pooled with v2
timings. These closed nonreactive fixtures check material-cell counts; they
do not establish Water quantity, heat/reaction conservation or transfer correctness.
Repeated runs and 1/4-worker results must match final content hash, material census
and full `state_hash` for the same fixture/offset/tick count. These frozen controls
share a schema and Current phased worker contract. This is not a universal platform
or cross-schema state identity. Endpoint census cannot detect a hypothetical transient
loss later recreated; these nonreactive controls do not certify transfer conservation.

## Timing, work and memory meaning

Each measured sample retains `World::tick` elapsed milliseconds, separately timed
explicit edits, attempted/completed successful tick identity via TickStats, scheduled
cores and phase jobs, visited/moved cells, active blocks/chunks, dirty chunks, allocations
and deferred events. Report p50/p95/p99/max/total using nearest-rank quantiles per
process. Report process distributions, not merely pooled medians; the driver preserves
per-process values and gives median process p95/p99 and worst maximum as conveniences.

**Current instrumentation limit:** `visited_cells` counts rule scanning. It does not
count the resident metadata passes in `begin_tick`/`finish_tick`, active-core gathering,
or epoch-byte clearing. Zero visited cells is not zero work. The current compact epoch
first clears at tick 256, then every 255 ticks; these samples are explicitly tagged and
remain in all primary timing statistics. Separate ordinary/epoch summaries explain the
tail without removing it. Root-cause profiling is still necessary before proposing a
metadata or epoch optimization.

`dirty_chunks` means outstanding render dirtiness, not newly mutated chunks. The
harness clears initialization dirtiness once, then performs no render publication or
dirty draining. A future observer may not steal render dirty state to manufacture its
own change stream. `resident_cell_bytes` is World's existing cell/temperature/activity
storage estimate, not process RSS, allocated-map overhead or queue/scratch total.
**Source-scoped correction:** at `de332ea`, World aliases its Cell to
`detail::PrecisionStorage`, whose actual size/alignment are 8/8 bytes. The harness
reports both directly; historical Current4 or Issue17-only comments do not establish
this checkout's representation. No experimental baseline is rewritten. Record
resident chunks and bytes alongside area. CPU frequency/turbo, OS scheduling,
cache effects and external contention are not fixed by this script: preserve the host
exclusivity note and before/after possible-contender snapshots and avoid claiming an
uncontended result when other work ran.

## Discovery and later break-even contract

**Required for the Stage 3 candidate:** add separate cells/blocks/chunks inspected,
queue/scratch capacity and high-water, overflow/defer/refusal counts, tracked region
area/count distribution, actual mutation-to-reclassification latency, revision-stale
restarts, candidate churn and false invalidations. Include excluded/re-entered work,
ABA writes, boundary/seam/holes and long quiet intervals. Publish no partial candidate
on saturation. Report changed-area/halo wake amplification, candidate CPU time,
metadata bytes per tracked cell/region and bounded queue drain latency. The Current
control has no discovery manager: these counters are **not applicable**, never invented
as zero discovery overhead to suggest a candidate benefit.

Stage 3 acceptance requires useful bounded measurements, not a net speedup. Stage 4
must include discovery, region maintenance, boundary work, invalidation/rebuild,
publication/coupling, compaction and reactivation in the candidate cost. Derive
break-even curves against ordinary sleep for region area, quiet duration, boundary
activity and edit churn; do not choose thresholds from intuition. Flag more than 15%
paired p95 regression or more than 1 ms added epoch-clear excess for review, following
the retained programme research screen. These are review triggers, not permission to
change physics or accepted product performance limits. Negative/ambiguous results may
reject a tier while leaving other dependency-ready work open.

## Reproduction and interpretation

Run from the dedicated issue #12 worktree using the workspace Python. Evidence and
build outputs stay under `C:/kybersand/validation/local/issue-12-2026-09-19/`; use a new
child name for every attempt. First prepare immutable input:

```powershell
C:/kybersand/.local/python/Scripts/python.exe tools/experiments/run_soliding_baseline.py prepare --source-ref de332ea --out C:/kybersand/validation/local/issue-12-2026-09-19/baseline-artifact
```

After all independent compilation has stopped, run the registered matrix:

```powershell
C:/kybersand/.local/python/Scripts/python.exe tools/experiments/run_soliding_baseline.py run --artifact C:/kybersand/validation/local/issue-12-2026-09-19/baseline-artifact/artifact.json --out C:/kybersand/validation/local/issue-12-2026-09-19/baseline-matrix --uncontended-note "Owner checked no concurrent build, Godot or benchmark; local host reserved for this campaign"
```

For a short correctness smoke, use a new output directory and add
`--sizes 128 --repeats 1 --settle 4 --warmup 4 --ticks 8`. For a behavior-only
translation supplement use `--sizes 128 --repeats 1 --ticks 2048
--offsets 0:0,127:1,-129:-1,65:64,-257:1`; its single repetition is not a timing claim.

The artifact manifest pins inputs and compile command; registration pins configurations;
each attempt has separate stdout/stderr and execution metadata; `completed.json` retains
all results and failure counts. Evidence summaries must identify the actual full source
commit, harness delta, executable, host and limitations. Windows native evidence does
not satisfy Linux/runtime-floor, desktop asynchronous ownership or Web compatibility /
threaded browser gates. No broader acceptance follows from this control alone.

## Offline reduction

The [read-only reducer](../../tools/experiments/summarize_soliding_baseline.py)
verifies frozen input/executable and raw stdout/stderr hashes before reporting
per-process distributions, ordinary versus epoch timing, memory per fixture area,
rule/scheduler work and edit-window wake amplification. Its outputs are separate
files; it refuses overwrite and never edits raw attempts. Failed results remain
included and produce a nonzero reducer exit, even if other configurations pass.

```powershell
C:/kybersand/.local/python/Scripts/python.exe tools/experiments/summarize_soliding_baseline.py C:/kybersand/validation/local/issue-12-2026-09-19/baseline-matrix/completed.json --out C:/kybersand/validation/local/issue-12-2026-09-19/baseline-matrix/reduction.json --markdown C:/kybersand/validation/local/issue-12-2026-09-19/baseline-matrix/reduction.md
```

Bytes per fixture cell include the reserved halo. Edit-window visit ratios count
Current scheduler scans, not future discovery rebuilds. Sleep latency is the tick
index offset from the edit to the first observed zero active-block count; zero
means the edit tick itself. An edit window that ends before sleeping is explicitly
right-censored. All raw tails remain in the p95/p99/max summaries, and process p95
ranges remain visible without an assumed significance/noise model. Interpret a
quiet area with zero rule visits and nonzero time as an investigation lead for
existing metadata/epoch work; finer causal attribution still needs profiling.
