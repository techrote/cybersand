---
title: Synthetic settled-discovery journal costs, 2026-09-19
status: Current
document-kind: evidence
scope: Isolated journal cost decomposition on Ryzen 2600X with exact frozen inputs; no World producer, connectivity, acceleration or Stage 3 exit claim
canonical-for: []
last-reviewed: 2026-09-19
related-documents: [../../systems/settled-region-discovery.md, ../../operations/soliding-measurement.md, ordinary-sleep-results.md, producer-hook-review.md]
---

# Synthetic journal cost results

## Result and evidence boundary

**Measured, 2026-09-19:** all 63 registered processes passed. Independent reduction
verified copied input and executable hashes, every raw stdout/stderr/execution
record, analytical work totals, exact final synthetic tuples, fairness, capacity
refusal and identical nontiming counters across seven repeats per case. This is a
short isolated cost decomposition of the journal and contiguous array reader.
It does not measure World hooks, real activity/rest, connected regions, collision,
rendering or a saving against [ordinary Current sleep](ordinary-sleep-results.md).
Stage 3 remains partial.

A 2048-square array requires 4,202,496 initial work units and approximately 29 ms
of journal service in this harness. The 128 repeated local ABA/drain operations
require 131,328 work units regardless of total area, with medians 0.815–0.840 ms
across the matrix. Idle service performs zero inspections/work but still costs
approximately 0.57–0.58 ms per 100,000 calls. These are synthetic-array costs;
producer notification completeness, World lookup and metadata-pass costs remain
unmeasured. The fixed journal uses 491,672 bytes at every registered area.

The [machine record](journal-cost-results.json) retains all nine timing ranges,
phase counters, source/tool/artifact/output hashes and exact working-delta scope.
No slow repeat or unfinished churning tile was removed.

## Exact inputs and execution

| Input | Identity |
|---|---|
| Working Git HEAD at freeze | `d69df4628ca0055636e9a0ee192c91411b76d6c6` plus the hashed benchmark/driver/protocol delta |
| Journal header SHA-256 | `63125dd6cb70188c563c938c974ad4dddc6c22a6120ad0fac06a58aeef62b123` |
| Benchmark SHA-256 | `39e069e1d45cb3e49c0b3b0e04cf243d99cea594a0c85cbf5d1ae88b6f1b00e7` |
| Driver SHA-256 | `0bcfd35c781f87d9442c6ca8c3764b9cfd3e1b9f5491276bbf4dbc1b1f6c1b01` |
| Executable SHA-256 | `415e0fd14a375018997f6d08e808b8a6a8358c8f3c248bae3e8e807d9858e412` |
| Artifact-manifest SHA-256 | `68d173bee87c88553cb55c2c938aba2e95b80b9d10ef91aca9e661958f36d508` |
| Run-plan SHA-256 | `ef6975969782fad9e3ffbe6babd37263a8626d001b7fe6df9d1c53c69eaa1c11` |
| Raw-results SHA-256 | `1023381916342bfb26dfc803cfc772a9aecfb4403d9dd77dae0f686c57d3a8b1` |
| Compiler | LLVM-MinGW 20260826 UCRT Clang 23.1.0; C++20, `-O3 -DNDEBUG -static`, all listed warnings plus `-Werror`; no LTO |
| Host | Ryzen 5 2600X, 6 cores/12 logical processors; Windows 11 build 26200; Balanced power plan; 34,265,985,024 physical-memory bytes |
| Interval | 2026-09-19 01:33:16.755–01:33:21.520 UTC; summed process elapsed time 3.907 seconds |

Only the benchmark and journal header enter the native executable. The header and
shared driver helper match the recorded Git HEAD after CRLF normalization; their
exact on-disk byte hashes remain above/in the machine record. The benchmark and
specialized driver were new uncommitted inputs at freeze, and the protocol page
contained its preregistration delta. The recorded HEAD alone is therefore not the
complete executable identity. Unrelated working-document changes listed in intake
were not compiled. No World source, #26 experimental material program or #27 runtime
was linked into this binary.
Final source staging removes a trailing blank line from the benchmark only; the
frozen copied benchmark above remains the exact measured input. No measured
algorithm, compile flags or result was changed.

Copied build inputs and artifact metadata remain under
`C:/kybersand/validation/local/2026-09-19-issue12-journal-build/`; full raw runs remain
under `C:/kybersand/validation/local/issue-12-2026-09-19/journal-matrix/`.
The independent reducer is retained there as `../reduce-journal-cost.py`, with its
hash in the machine record. The earlier explicitly labeled one-case smoke remains
under `C:/kybersand/validation/local/2026-09-19-issue12-journal-smoke/`; it is excluded
from the 63-process campaign. Build and campaign had no failed attempts. Other
lifecycle/core baseline failures remain in their separate evidence.

The [preregistered matrix](../../systems/settled-region-discovery.md#synthetic-journal-cost-preregistration-2026-09-19)
uses fixed 4096-slot capacity, 32-square tiles, sides 128/512/2048, budgets 64/1024/8192,
100,000 idle calls, 128 local ABA/drain repetitions and the declared churn schedule.
Seven sequential processes per case use reversed case order on alternating repeats,
with a 60-second timeout each. CPU reservation was coordinated; the retained process
snapshot found no matching test/compiler contender. This is not an OS-wide proof of
zero interference, fixed frequency or pinned affinity.

## Timing and memory decomposition

All numbers below are **median milliseconds per complete phase**, seven repeats.
Registration is separate from initial service. Local ABA includes all 128 edits/
restores and drains; churn uses the preregistered budget-dependent workload.

| Side | Budget | Registration | Initial service | 100,000 idle calls | 128 local ABA/drains | Churn |
|---:|---:|---:|---:|---:|---:|---:|
| 128 | 64 | 0.0025 | 0.1071 | 0.5733 | 0.8401 | 2.0219 |
| 128 | 1024 | 0.0026 | 0.1040 | 0.5767 | 0.8198 | 26.0939 |
| 128 | 8192 | 0.0026 | 0.1043 | 0.5829 | 0.8276 | 27.4559 |
| 512 | 64 | 0.0199 | 1.7936 | 0.5768 | 0.8376 | 3.9249 |
| 512 | 1024 | 0.0199 | 1.7436 | 0.5767 | 0.8339 | 28.8273 |
| 512 | 8192 | 0.0194 | 1.7773 | 0.5768 | 0.8154 | 28.3767 |
| 2048 | 64 | 5.0925 | 29.5449 | 0.5732 | 0.8369 | 36.7906 |
| 2048 | 1024 | 5.3122 | 29.2389 | 0.5815 | 0.8202 | 56.9143 |
| 2048 | 8192 | 5.3580 | 29.6571 | 0.5821 | 0.8243 | 57.3122 |

The fixed 491,672-byte journal costs **30.0093**, **1.87558** and **0.117224 bytes per
tracked cell** at sides 128,512,2048 respectively. This exposes fixed-capacity waste
at small occupancy; it does not select a production capacity. The separate synthetic
cell carrier is 10 bytes, not Current World cell storage. Source/journal allocation
and initialization are measured separately in the machine record and excluded from
registration/service columns.

The current duplicate-bounds registration loop is quadratic over all registrations.
Its cost must remain visible if setup moves to runtime chunk creation. At 2048²,
budget 8192, registration ranged 5.0549–11.7824 ms and initial service ranged
28.5491–44.3118 ms; the slow repeats remain. Recovery measurements at large budgets
are often 0.0001–0.0002 ms and sit at timer/harness scale; they do not establish a
meaningful submicrosecond runtime latency guarantee.

## Bounded work, churn and negative results

Initial classification always reads exactly the registered area and publishes one
summary per tile. At 2048², budgets 64/1024/8192 need **65,664 / 4,104 / 513 service
epochs** respectively. These epochs are calls, not simulation ticks, frames or
rest duration. Idle phases inspect zero cells. Each local ABA/drain reads exactly
1024 cells and charges 1026 work units; all 128 rounds finish without a restart.

Churn deliberately invalidates the same tile before every service call. At small
budgets that tile cannot finish while changes continue, but the queue rotation
lets all unaffected tiles finish. At 2048² the deterministic outcomes are:

| Budget | Churn work units | Churn cell inspections | Restarts | Publications | Pending after churn |
|---:|---:|---:|---:|---:|---:|
| 64 | 4,464,640 | 4,452,337 | 4,112 | 4,095 | 1 |
| 1024 | 8,396,800 | 8,384,512 | 4,097 | 4,095 | 1 |
| 8192 | 8,404,992 | 8,388,608 | 0 | 8,192 | 0 |

The larger budget can repeatedly complete and then invalidate the same tile;
completing more publications is not automatically useful work. Lower budgets
have lower elapsed churn time partly because they inspect fewer cells: this is
**not an equal-work speed comparison**. The protocol intentionally retains that
tradeoff. All remaining work drains when edits stop, exact source tuples remain,
and every unaffected tile succeeds. The maximum lifetime dirty-to-classified
latency at 2048² reaches 69,776 service epochs for budget 64; hiding the first dirty
age would conceal this cost. Queue high-water equals the registered tile count,
never exceeds 4096, and the extra full-registry registration refuses in all 21
2048² processes. Smaller cases did not run a full-capacity refusal probe.

**Disposition:** bounded local notification/scan work and idle neutrality are
supported for the isolated journal. Initial enumeration, registration scaling,
repeated invalidation, incomplete churn and fixed-capacity memory cost remain
measured liabilities. Real producer hooks, region connectivity, latency distributions
under actual activity and end-to-end cost comparison are still prerequisites; no
acceleration threshold, material admission, runtime integration or Stage 3 exit is
established here.
