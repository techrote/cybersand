---
title: Issue 69 Stage 3B validation preregistration
status: Current
document-kind: evidence
scope: Candidate-independent validation apparatus, frozen campaign schema, fixture inventory and qualification evidence for Stage 3B
canonical-for: []
last-reviewed: 2026-09-19
related-documents: [../operations/soliding-stage3b-production-plan.md, ../operations/soliding-stage3-freeze.md, issue-12-2026-09-19/stage3b-parent-decision.md, issue-12-2026-09-19/stage3-exit-review.md, issue-12-2026-09-19/stage3-cost-results.md]
---

# Issue 69 Stage 3B validation preregistration

## Boundary and reconciled source

Issue #69 freezes **how** the Stage-3B candidate will be measured. It does not
execute the final acceptance campaign and does not implement or tune Stage-3B
production semantics.

The implementation branch was created from actual `main`
`910717aac101363ec2b1b89e4041a22bc9a97b97`, after PR #55 / issue #29 merged.
The merged interaction/MicroScenario work therefore no longer has an active branch
ownership conflict, but #69 still does not depend on or edit its workbench,
retrieval-corpus, material-rule or MicroScenario surfaces. MS-001 remains
supplemental later integration evidence.

The historical Stage-3A cost evidence remains tied to its measured source and
artifact identities. It is not relabelled as current-main evidence.

## Apparatus identity

The executable preregistration contract is
`tools/experiments/stage3b_validation.py`.

Frozen schema identities:

- fixture catalogue: `cybersand.stage3b.fixture-catalogue` version 1;
- run plan: `cybersand.stage3b.validation-plan` version 1;
- run result: `cybersand.stage3b.validation-result` version 1;
- reduced report: `cybersand.stage3b.validation-report` version 1;
- shared contract version: `stage3b-validation-v1`;
- deterministic ordering seed:
  `cybersand-stage3b-preregistered-order-v1`.

The apparatus source commit is itself an input to every generated plan. #70 must
freeze the exact apparatus source before execution.

## Fixture inventory

The catalogue contains 168 logical fixtures. Each fixture also carries
`cybersand.stage3b.fixture-protocol/v1`: canonical coordinates/generator
parameters, an ordered operation schedule, service checkpoints and assertions.
The canonicalized protocol is SHA-256 hashed; every generated run row carries that
hash and every result must echo it in authoritative-mutation provenance. #70 may
write an adapter for a frozen candidate interface, but it may not choose new
geometry or mutation schedules after seeing candidate behavior.

The catalogue inventory is:

| Family | Count | Key contract |
|---|---:|---|
| Quiet / initial population | 5 | 512/1024/2048 plus sparse coverage and large-capacity/small-coverage; startup phases are explicit |
| Genuine one-cell edits | 32 | 8 tuple/state cases x 4 boundary positions; intended authoritative changed-cell count is exactly one |
| Retained historical controls | 7 | `local-edit` remains an 8x8 patch and `bridge` remains a whole-column change |
| Connectivity / topology | 12 | Includes true one-cell bridge add/remove, non-split, large/many-child split and port-partition cases |
| Coverage / absence / registration | 12 | Dictionary miss is never global completeness |
| Activity / deadline / no-write | 10 | Future/tied/replaced/cancelled deadlines, re-entry and no-write wake/sleep |
| ABA / fanout | 8 | Tuple, mask, event, inclusion and worker/dependency fanout |
| Progress / churn / fairness | 11 | Near/far progress, cadence, stale work, recovery and reclamation pressure |
| Capacity / failure | 32 | Exact/one-past bounds for 13 classes plus six deterministic failure injections |
| Determinism permutations | 7 | Registration/free-slot/allocation/tie/geometry/hash/scarce-capacity ordering |
| Memory | 32 | Eight independent axes at 64/256/1024/4096 |

The historical labels are deliberately not recycled for the genuine one-cell
fixtures. True one-cell topology fixtures also carry an explicit one-cell mutation
contract. The canonical coordinate model uses 32-cell tile/chunk boundaries;
one-cell positions are frozen at interior `[16,16]`, face `[31,16]`, corner
`[31,31]` and boundary-sensitive `[32,16]`. Topology generators, deadline
ticks, ABA sequences, capacity limits/fault ordinals, determinism permutations and
memory-axis operations are all recorded in the fixture protocol rather than left
to #70.

## Arms and source identity

The run-plan schema defines:

- `current-discovery-disabled`;
- `stage3a-untouched`, a potentially separate historical/reference series;
- `stage3a-runtime-sized`;
- `stage3b-sparse-producer`, optional intermediate attribution arm;
- `stage3b-indexed-graph`, optional intermediate attribution arm;
- `stage3b-candidate`.

Before the candidate freezes, unavailable arms remain explicit in the plan.
#70 supplies an arm manifest with exact source/runtime identities and availability.

Matched observer arms must use one frozen authoritative simulation/material baseline
where possible. If untouched Stage 3A cannot share that authority, #70 must retain
it as a separately identified reference series rather than a matched control.

Intermediate arms are only requested on six preregistered attribution fixtures:
2048 quiet, one-cell material/interior, genuine large split, many deadline changes,
continuous local churn and configured-capacity 4096. They are not prerequisites
for #69 or #70 if the corresponding implementation snapshots do not exist.

## Service, repetitions and ordering

Two service modes are frozen:

1. drain to completion;
2. fixed primitive budgets `1, 8, 64, 256, 1024`.

One primitive means one bounded source read, incidence/index operation, dependency
action, bounded heap/tree operation or reclamation action. A whole-region loop is
never one primitive. These counts are not the historical Stage-3 abstract work-unit
counter.

The full default plan contains 6,488 run records. This is intentionally narrower
than a Cartesian product that would waste runner time without adding evidence:

- paired drain cells use five sequential process repeats;
- interruption-sensitive fixed-budget cells use five sequential process repeats;
- correctness-only drain qualifications use one deterministic process unless an
  amendment is registered before inspecting candidate results;
- Current and untouched historical Stage 3A are not duplicated across new
  fixed-primitive budgets, because those budgets have no matched meaning there;
- workers 1 and 4 are independent dimensions;
- cells use a fixed SHA-256 shuffle;
- odd repeats use normal arm order and even repeats reverse it;
- benchmark processes are sequential/uncontended unless contention is itself the
  registered experiment;
- warm-up/qualification output is separate from final retained data.

More repeats after an inconclusive campaign require an explicit amendment. Original
results remain retained.

## Result and measurement contract

Every planned execution has an explicit state. Supported terminal states include
success, correctness failure, refusal, timeout, source failure, failed-world
quarantine, unavailable and not-applicable. Slow performance remains a measured
outcome on a successful run; there is no threshold-derived performance-failure state. A refusal or timeout is a
result, never a blank row.

Every executed result carries source commit and dirty status; relevant source/input
hashes; compiler executable/version/hash and flags; executable hash; capacity,
worker, fixture/version and seed; authoritative mutation and observer-service
schedules; arm identity; hardware, OS and power mode; run order/repeat; stdout,
stderr and raw-result identities.

Metric groups are preregistered for producer/signal tracking, deadlines/activity,
exact extraction, indexes, retirement/dependency, merge/local fast paths,
reconstruction, publication, reclamation, end-to-end latency/throughput and memory.
Configured/requested, layout-derived, allocator/committed, live, staged, retired,
scratch high-water and process RSS remain distinct. A configured-memory reduction
is never reclassified as an algorithmic performance improvement.

Correctness comparison names material, `state_a`, `state_b`, temperature,
occupancy, masks, events, inclusion, completed ticks, failure/quarantine and
source/sink/quantity ledgers where applicable. `content_hash()` alone is not an
authoritative-equality proof. Observer read-only and simulation-neutral outcomes
are separate fields.

## Reducer contract

The reducer:

- never rewrites raw result records;
- separates correctness failures from performance measurements;
- retains unavailable/refused/failed/timeout outcomes;
- flags missing available runs and insufficient successful samples;
- summarizes every declared numeric metric from successful records while retaining
  partial high-water/refusal evidence from all terminal records;
- reports p50 for non-empty process populations, p95 only from at least 20 samples
  and p99 only from at least 100; per-run distributions may carry their own declared
  statistics;
- never adds separately reported percentiles;
- emits an exact per-record provenance index;
- contains no candidate winner, universal percentage-speedup threshold or Stage-3B
  admission decision.

The supervising parent retains interpretation authority after #70.

## Qualification and CI scope

`tools/experiments/test_stage3b_validation.py` validates fixture definitions,
plan determinism/order, provenance/failure rules, Current N/A semantics and
synthetic reduction.

The repository-native qualification target runs only:

- those standard-library unit tests;
- a synthetic smoke plan/result/reducer pass, explicitly excluded from acceptance
  statistics;
- generation plus validation of the smoke plan;
- the retained native `stage3_cost` build/smoke to prove the source benchmark
  lineage still compiles.

It does **not** launch the 6,488-record final plan. No duplicate benchmark fanout is
added.

## Inputs #70 must freeze

Before execution, #70 still must supply:

- the coherent candidate exact head;
- the authoritative simulation/material baseline exact identity;
- exact source/runtime identity for every available arm;
- final capacities for implemented Stage-3B design classes;
- compiler, flags and executable identities;
- target hardware, OS and power mode;
- arm adapters capable of emitting the preregistered metrics;
- availability of the optional intermediate attribution arms;
- timeout policy and raw-output destination;
- any explicit pre-results amendment needed because a final interface makes one
  registered fixture or metric genuinely inapplicable.

#70 must then execute the exact registered plan against the frozen candidate. It
must not silently add favorable fixtures, drop unfavorable runs, reinterpret old
Stage-3A results as current-main measurements, or self-admit Stage 3B.
