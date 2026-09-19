---
title: Current ordinary-sleep measurements for issue 12, 2026-09-19
status: Current
document-kind: evidence
scope: Frozen de332ea Windows native baseline for scalable soliding, including rule-work limits, epoch tails, local wake, conservation and retained failed attempts
canonical-for: []
last-reviewed: 2026-09-19
related-documents: [../../operations/soliding-measurement.md, ../../operations/soliding-programme.md, ../../systems/activity-dirty-regions-and-waking.md, ../2026-09-19-issue-12-phase0-reuse.md]
---

# Current ordinary-sleep results

## Result and stage meaning

**Measured control, 2026-09-19:** all 210 registered processes completed successfully.
The independent reduction found no changed frozen inputs, raw-output corruption,
endpoint material-accounting failures, pre-stimulus warmup movement/dirtiness or final
content/state/census disagreement across seven repeats and 1/4 workers. The campaign
contains 430,080 measured ticks and 1,680 epoch-clear samples. No measured tick allocated
chunks or temperature fields. No candidate representation was measured: these are
ordinary Current sleep results, not a soliding speedup or Stage 3/4 admission.

Quiet interiors already run zero eligible material rules. At 2048², ordinary quiet
ticks have a median around 0.010 ms, while epoch-clear ticks have a median around
4.35–4.56 ms and contribute about 62–63% of total quiet tick time. A region manager
that merely removes already-absent material updates cannot claim that cost as saved.
The result motivates measuring discovery overhead and investigating existing epoch /
metadata cost; it does not justify a chosen optimization or region threshold.

The [compact machine record](ordinary-sleep-results.json) contains all 30 groups,
seven process-p95 values per group, source/tool/artifact hashes, configurations,
conservation/parity outcomes and retained failed-smoke identities. Raw per-tick
observations remain outside Git under
`C:/kybersand/validation/local/issue-12-2026-09-19/`.

## Exact inputs and execution

| Input | Identity |
|---|---|
| Frozen native source | `de332eaf8f4e70b25b097bed0c2e2a7b2aac0173` (main after #27/MS-000) |
| Harness SHA-256 | `018fb49334fd0da43b80148a9e1bddf5ccb316259370749bebc6b49d5e3ed77d` |
| Executable SHA-256 | `ae8e07eea80e7f210efb311601928f6255667ea5cf31c26c21c57e79d0353ceb` |
| Artifact manifest | `baseline-artifact-v4/artifact.json`, SHA-256 `486b2bf62238529207abda5e81584076a0f9d66e9d8270da6a8336598feb179d` |
| Complete campaign | `baseline-matrix/completed.json`, SHA-256 `7c4ad7b9ee84ba6af99eab077b5cc64940c0ff94bff7c584713784358256bb47` |
| Independent reduction | `baseline-reduction-v2.json`, SHA-256 `831dc4d56a375d180cd3219ed3d07a5a27f330832cbd9b5de29e36b7a372c023` |
| Compiler | Pinned LLVM-MinGW 20260826 UCRT Clang 23.1.0; C++20, `-O3 -DNDEBUG -flto -pthread -static`; full command/hash in machine record |
| Host | Ryzen 5 2600X, 6 cores/12 logical processors; Windows 11 build 26200; 34,265,985,024 physical-memory bytes; Balanced power plan |
| Campaign interval | 2026-09-19 01:20:00.959–01:22:21.852 UTC |

Native source/header files were copied from the explicit Git commit before compilation;
the separately hashed harness was the only additional native source. Concurrent #12
lifecycle/discovery changes and #26 work did not enter the control. The harness reports
actual Current `PrecisionStorage` size/alignment **8/8 bytes**. Historical 4-byte /
Issue17-only labels do not describe this source and were not rewritten to fit it.

The [preregistered contract](../../operations/soliding-measurement.md) specifies dense
512²/1024²/2048² fixtures, a reserved 128-cell halo, fixed capacities, phased 1/4 workers,
120 settling ticks, initial census/hash, then 120 uninterrupted warmup ticks and 2048
measured ticks. Seven separate processes per tuple ran sequentially. The measured
translation was (0,0); the five-translation supplement is not part of this result.
The per-process timeout was 120 seconds. Total timed `World::tick` duration across
processes was 51.925620 seconds; summed process elapsed duration was 135.100 seconds.
Setup, census, hashing, output and explicit-edit duration are excluded from tick timing;
tick-plus-edit summaries and initial-settling/warmup samples remain in raw evidence.

The cooperating agents stopped builds/tests for the campaign. Before/after process
snapshots found no listed Godot/compiler/benchmark contenders. Ordinary background OS
load, CPU frequency and turbo were not controlled continuously. This is a coordinated
uncontended benchmark session, not proof of an isolated operating system or statistical
significance. Both existing compiler warnings (integer narrowing and unused lambda
capture in frozen World) are retained. All 210 runtime stderr files are empty.

## Timing and work

Values below are **median process p95 tick milliseconds**, written as 1-worker / 4-worker.
All epoch-clear ticks remain included. The machine record retains the full seven-value
distributions, p99, worst tick, totals and failure information.

| Fixture | 512² | 1024² | 2048² |
|---|---:|---:|---:|
| Wall | 0.0011 / 0.0012 | 0.0031 / 0.0031 | 0.0104 / 0.0105 |
| RedBrick | 0.0012 / 0.0012 | 0.0031 / 0.0031 | 0.0106 / 0.0105 |
| Sand at rest | 0.0012 / 0.0012 | 0.0032 / 0.0031 | 0.0104 / 0.0105 |
| Local 8×8 Wall edits | 0.0455 / 0.0456 | 0.0475 / 0.0477 | 0.0555 / 0.0558 |
| Local Sand support removal | 0.2400 / 0.1364 | 1.3081 / 1.3566 | 4.4486 / 4.4165 |

Noise is material. Across all repeats/workers, 512² local-edit process p95 ranged
0.0450–0.1288 ms; 512² granular-release p95 ranged 0.0979–0.8065 ms. The worst measured
tick was 47.3421 ms in the 2048² one-worker release control. These samples remain;
no tail trimming or favorable worker-speedup inference was applied. The larger release
case's one-/four-worker total differences are retained observations of Current worker
execution, not evidence for a new representation.

All quiet Wall/RedBrick/Sand-at-rest runs had **zero eligible rule visits and zero
scheduled cores** during the measured interval. The 8×8 Wall patch toggled 64 times,
changing 4096 cells cumulatively. Every local-edit run scheduled 768 cores in total:
12 cores per edit event, returning to zero active blocks at offset 2 (the third tick
including the edit tick). This work did not grow with the three tested world sizes.
Nevertheless `visited_cells` remained zero. Inspection of frozen `scan_rect` shows why:
it counts calls to `update_cell` **after** epoch and rule-eligibility filters, excluding
scanned but inactive Wall/Empty addresses. It is not a total cell-inspection counter.
A future discovery benchmark needs its own explicit inspection counts.

Sand support removal deletes only a 32-cell Wall shelf segment above an intact floor.
Material remains in the closed basin; this is a granular negative control, with no
rigid body or cohesion. All repeats and workers agreed on these Current counters:

| Area | Eligible rule visits | Scheduled cores | `moved_cells` | First zero-active offset |
|---|---:|---:|---:|---:|
| 512² | 4,218,146 | 1,162 | 463,285 | 99 |
| 1024² | 7,317,824 | 1,919 | 979,639 | 99 |
| 2048² | 13,435,360 | 3,415 | 2,012,763 | 104 |

The growing response reflects current cellular behavior under the same local support
cut and differently sized Sand beds. It is not a measured discovery false invalidation
or evidence that avalanche work should be skipped. No edit window was censored before
its first observed return to zero active blocks in this campaign.

## Epoch tail and resident memory

The epoch first clears at tick 256, then every 255 ticks. Exactly 8 of each process's
2048 measured ticks are clear ticks, about 0.39%. Consequently p95 and even p99 mostly
hide this periodic cost; total and maximum matter. Representative Wall results below
are median process values, again 1-worker / 4-worker. Similar RedBrick/Sand-rest groups
are retained in the machine record.

| Area | Ordinary tick p50 (ms) | Epoch-clear p50 (ms) | Epoch share of total tick time | Worst Wall tick across both worker counts (ms) |
|---|---:|---:|---:|---:|
| 512² | 0.0011 / 0.0011 | 0.1000 / 0.0940 | 30.8% / 33.1% | 0.4520 |
| 1024² | 0.0030 / 0.0031 | 1.3024 / 1.3131 | 62.6% / 62.9% | 1.8762 |
| 2048² | 0.0102 / 0.0102 | 4.3675 / 4.3765 | 62.5% / 62.8% | 5.5331 |

Source inspection establishes that epoch clearing visits every resident Cell; existing
tick metadata passes also visit resident chunks/activity blocks. Their cost is omitted
from `visited_cells`. The size-dependent measurements are consistent with those paths;
precise CPU attribution, cache effects or a safe epoch redesign still need focused
profiling and separate correctness evidence. This report selects none.

| Fixture area | Resident chunks including halo | Existing World bytes estimate | Bytes per fixture cell |
|---|---:|---:|---:|
| 512² | 36 | 4,727,808 | 18.035 |
| 1024² | 100 | 13,132,800 | 12.524 |
| 2048² | 324 | 42,550,272 | 10.145 |

These are the existing cell/temperature/activity-storage estimates, not process RSS or
full World/map/job-pool/queue allocation. Every fixture at a given size used the same
resident area. Halo overhead explains why bytes per fixture cell exceed the 8-byte
Cell size; no compaction or memory saving was attempted.

## Separate translation behavior supplement

A subsequent **50-process** supplement used the same frozen artifact v4/protocol v2,
all five fixtures at side128, workers1/4, and offsets `(0,0)`, `(127,1)`, `(-129,-1)`,
`(65,64)`, `(-257,1)`, with one repeat and 2048 measured ticks per case. Every process
passed endpoint accounting and within-offset worker parity. This probes negative
coordinates and different chunk/core alignments; it does not claim exact equality
between differently aligned phased simulations or supply seven-repeat timing evidence.
The raw `baseline-translations/completed.json` is retained with SHA-256
`c1fed120816ceff8b6b2e7b4b711e848d8a1ac2dd70aba7325773fec38c7c6bd`.
These cases remain outside the 210-process registered performance matrix.

## Retained failures, limits and next evidence

- `baseline-smoke` used protocol v1/artifact v2. Its ten native processes exited zero,
  but all ten driver reductions failed because `cell_storage_bytes` was missing. The
  failed outputs and failure-returning reduction remain; this was harness schema
  failure, not material behavior evidence.
- `baseline-smoke-v2` used artifact v3 and passed all ten cases. Its census/hash followed
  warmup, potentially perturbing caches, so it supplies correctness smoke only.
- `baseline-smoke-v3` used artifact v4/protocol v2 and passed all ten cases. It moved
  census before warmup and required zero warmup movement/dirty chunks. The full campaign
  uses this protocol exclusively. Artifacts v1–v3 were preserved, never overwritten.
- Initial `baseline-reduction.json/.md` remains; `baseline-reduction-v2.json/.md` adds
  independent raw census/warmup/worker checks and clarifies eligible-rule counter meaning.
- A later integrity-hardening reduction, `baseline-reduction-v3.json/.md`, verifies
  complete preregistered case coverage and exact execution/raw identities. It reports
  210/210 attempts with no integrity findings; measured fields match v2 exactly.
  V3 JSON SHA-256 is `fb2809ddaefb8baaeddb7eaddb88cc15e7e8aad83b621a1388fb3e40ae17ba77`.
  Sixteen synthetic corruption regressions pass; all prior reducers/results remain.

Endpoint census with an external-edit ledger and deterministic final state is useful
for these closed nonreactive fixtures. It does not prove per-tick transfer conservation,
Water quantity, heat/reaction behavior, generic payload restoration or arbitrary shapes.
No renderer, Rapier, asynchronous desktop owner, Web runtime, Linux runtime-floor gate,
translated large-world fixture or candidate observer is covered by these timings.

The next comparison must include observer-off neutrality, explicit discovery inspection
and queue/latency/memory counters, and separately measured candidate maintenance cost.
The already-cheap ordinary tick and rare expensive epoch tail must both remain in its
accounting. A baseline alone cannot establish discovery break-even, stationary-tier
savings, dynamic-physics admission or fracture correctness; no such stages are collapsed
or claimed here.
