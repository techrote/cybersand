---
title: Issue 12 Stage 3B Astra architecture review packet
status: Planned
document-kind: runbook
scope: Read-only GPT-6 Astra review of Stage-3 discovery locality and scalability; no implementation, Stage-4 admission or ownership change
canonical-for: []
last-reviewed: 2026-09-19
related-documents: [soliding-programme.md, soliding-stage3-freeze.md, ../systems/settled-region-discovery.md, ../audits/issue-12-2026-09-19/stage3-exit-review.md, ../audits/issue-12-2026-09-19/stage3-cost-results.md]
---

# Stage 3B Astra architecture review packet

## Dispatch and model-identity gate

This is the next issue #12 review after the Stage-3A bounded reference merged in
PR #47. It is an architecture-analysis packet, not an implementation packet.

Run it only against the actual current `main` at or after merge
`fc299c11f3bfe322796605c4feb04ac027706357`. Record the inspected commit and diff
from that merge before drawing conclusions. The dispatched reviewer must report an
exact runtime identity of `gpt-6-astra` and the requested reasoning level. If that
identity cannot be confirmed, or the service substitutes another model, stop before
substantive review. Do not present a substituted review as Astra evidence.

The reviewer is read-only. It may inspect source, docs, tests and retained raw
evidence and may run non-mutating analysis. It must not edit source, create an
implementation branch, tune thresholds, or admit Stage 3B/Stage 4. Return the review
to the supervising parent, who retains architecture, evidence and stage-gate decisions.

## Authority and evidence order

Use these sources in order rather than reconstructing the programme from comments:

1. [`soliding-programme.md`](soliding-programme.md) for stage boundaries;
2. [`soliding-stage3-freeze.md`](soliding-stage3-freeze.md) for the immutable
   Stage-3 correctness contract;
3. [the Stage-3 exit review](../audits/issue-12-2026-09-19/stage3-exit-review.md)
   for the Stage-3A checklist disposition and Stage-3B hold;
4. [the corrected cost record](../audits/issue-12-2026-09-19/stage3-cost-results.md)
   for measured CPU, memory, latency, refusal and amplification evidence;
5. [the discovery system page](../systems/settled-region-discovery.md) and actual
   merged source for current interfaces and implementation.

PR #23 remains retained Phase-0 evidence, not the implementation base. Do not absorb
issue #26 Water semantics, #29 interaction semantics, #18 compact-motion semantics or
#20 sparse-motion semantics into #12. Later macro-dynamics, reversible Rapier handoff
and coherent-child fracture remain first-class #12 goals, but they are not Stage-3B
design variables.

## Objective

Recommend a bounded Stage-3B architecture that makes common producer/lookup work
change-proportional, sizes memory to configured or represented coverage, and treats
exceptional split reconstruction as explicit bounded deferred work, while preserving
the complete Stage-3A safety contract. Address all of:

- sparse/change-driven activity, deadline, mutation, mask and event signals;
- canonical keyed or spatial discovery-tile and face-neighbour lookup;
- storage sized by configured/represented capacity rather than compiled maxima;
- reverse tile/component/region dependency indexes for local retirement;
- an incremental merge path and bounded deferred reconstruction after splits;
- an explicit complete local/subregion candidate contract that a later Stage 4 could
  consume without mislabeling it globally complete.

Produce a recommendation, rejected alternatives, staged implementation slices and a
measurement plan. Do not produce code.

## Invariants that may not move

Any acceptable recommendation must preserve these properties exactly:

- authoritative material remains in cells; discovery is opt-in and read-only;
- producer observation is owner-serialized, and native workers never mutate shared
  discovery state;
- render dirty consumption is not a discovery witness;
- canonical discovery subtiles remain bounded to at most 32x32 source cells and are
  not redefined as scheduler semantic identity;
- exact component keys remain `{material,state_a,state_b,temperature}`;
- canonical Empty is a hole; noncanonical Empty state/heat is never silently dropped;
- connectivity remains four-neighbour only, with revision-bound face adjacency;
- no result is published until every declared dependency is complete and still at
  the validated revision; no prefix/partial publication is allowed;
- unknown, excluded, masked, failed or capacity-refused coverage prevents a false
  globally complete result;
- capacity/refusal changes observation only and never authoritative simulation;
- region observations are immutable and generation-bearing; arbitrary split/merge
  does not promise topology-continuous identity;
- invalidating one tile retires old connected publications and any facing-neighbour
  completeness that a new bridge could invalidate;
- deterministic results cannot depend on worker order, unordered-container order,
  allocation timing or benchmark scheduling;
- no stationary acceleration, cohesion inference, scheduler skip, Rapier ownership
  transfer, fracture or Stage-4 performance claim is introduced.

A union-find structure may be scratch or an addition accelerator, but cannot be the
only persistent representation because deletion and split remain first-class.

## Measured problem statement

Treat these as retained facts, not targets to massage:

| Observation | Retained evidence | Architectural question |
|---|---:|---|
| Producer/journal reported storage | 3,058,080 bytes | Which allocations scale with configured or represented tiles? |
| Connectivity object size | 67,703,136 bytes | How can compiled-maximum arrays become capacity-sized without unbounded allocation or hidden refusal? |
| 2048 quiet Current p95 | 0.0626 ms | This is the ordinary-sleep control, not zero discovery cost. |
| 2048 quiet producer p95 | 0.5395 ms | How can signal refresh become change/deadline driven? |
| 2048 initial exact journal scan | 74.6033 ms | Which copy/local-component work is necessary and how is it budgeted? |
| 2048 connectivity setup | 961.7359 ms | Which initialization/lookup costs are coverage proportional and resumable? |
| 2048 sparse-edit complete p95 | 39.3214 ms versus Current 0.0754 ms | How is a local edit prevented from forcing whole-region rediscovery? |
| Sparse-edit connectivity work | 1,351,685 work units | What reverse dependency and split strategy bounds affected reconstruction? |

The corrected campaign passed 276/276 with no retry/drop/cohort mismatch. These
numbers establish a cost model and negative scalability result, not a Stage-4 win or
an accepted production limit.

## Source hot paths to inspect

At minimum inspect and explain the complexity, storage and invalidation semantics of:

- `World::refresh_discovery_signals`, which currently visits every tracked tile each
  tick to refresh activity/deadline state;
- `World::dirty_discovery_world_rect` and `World::observe_discovery_event`, which map
  global rectangles/events by scanning tracked tiles;
- `SettledWorldDiscoveryCoordinator::Impl::find_record` and its bounded index;
- `SettledRegions::find_tile`, `link_faces` and registration paths,
  including tile-wide neighbour searches;
- `SettledRegions::seek_one`, which scans the tile-by-component address space for a
  canonical unassigned seed;
- traversal frontier ordering, dependency validation and `retire_for_tile_and_faces`;
- fixed arrays in `SettledRegions` for tiles, components, frontier, seen members,
  dependencies and published regions;
- the coordinator's copied tile payload and local-component feed in
  `SettledWorldDiscoveryCoordinator::advance`.

Do not assume a name or container implies the desired asymptotic behavior. Derive it
from the current loops, capacity bounds and failure paths.

## Required architecture analysis

### 1. Sparse producer and signal ownership

Define how mutation, activity transition, deadline insertion/consumption, mask ABA,
pending events, inclusion, policy fences, chunk/reservation creation and failed-world
quarantine enter a bounded owner-side change stream. Explain coalescing, generations,
overflow/refusal, same-tick ordering and deterministic worker-barrier reduction.

Account explicitly for a future deadline becoming relevant without a material write.
A design that stops polling must still have a bounded deterministic wake/deadline
index. Global reset/replacement/policy fences may remain rare global operations, but
their cost and invalidation semantics must be explicit.

### 2. Canonical spatial lookup

Compare at least a capacity-sized canonical sorted index and a deterministic keyed or
spatial index for tile lookup and four face neighbours. State worst-case and expected
lookup/update work, allocation behavior, signed-coordinate safety, iteration order and
how deterministic canonical traversal is recovered without relying on hash order.

### 3. Capacity-sized storage and refusal

Give byte formulas in terms of configured tiles, local components, active build
frontier, dependency count and published regions. Separate persistent per-tile data
from per-build scratch. Define preflight/allocation-failure behavior and whether
storage is fixed at World construction, grows within a declared cap, or uses bounded
pools. No allocation failure may alter World material or expose a partial result.

### 4. Reverse dependencies and invalidation

Specify the minimum reverse maps needed to retire publications/components affected by
a tile or facing edge without scanning unrelated regions. Preserve new-bridge
invalidation: a changed or newly known tile can invalidate completeness on both sides
even before its replacement payload is available. Show how stale generations and
revision mismatches are rejected.

### 5. Incremental merge and split reconstruction

Separate addition/bridge handling from deletion/split handling. Evaluate an
incremental merge accelerator, but retain exact deletion semantics. Propose a bounded
deferred split reconstruction strategy for a genuinely large old region, including
fairness under repeated local churn, remote progress, restart rules and refusal when
scratch/frontier capacity is insufficient.

Explain when old publications retire, when new complete publications may appear, and
why no temporary fragment is consumer-visible as complete.

### 6. Local/subregion consumer contract

Define the smallest observation a later Stage 4 could safely consume. Distinguish:

- complete within a declared closed dependency boundary;
- blocked/unknown at an external boundary;
- a complete globally closed connected region.

Name the revision/generation/dependency witnesses a consumer must retain and the event
that invalidates each class. A local candidate must never be advertised as a global
region merely to obtain better timings. This packet does not decide stationary
eligibility or a representation threshold.

## Alternatives and trade-off matrix

Compare, at minimum:

1. the Stage-3A fixed-capacity/global-scan reference;
2. sparse dirty/change sets plus a deterministic deadline heap/wheel;
3. canonical sorted lattice/index versus deterministic hash/spatial lookup;
4. capacity-sized contiguous storage versus bounded slab/pool storage;
5. reverse dependency lists with incremental bridge merge;
6. bounded deferred split reconstruction with optional local closed-subregion output.

For each, report asymptotic and bounded worst-case work, memory formula, determinism
mechanism, split/delete behavior, capacity/refusal behavior, migration complexity and
which Stage-3A tests could detect a regression. Reject alternatives explicitly rather
than selecting by elegance.

## Required measurement and validation plan

Preregister how a future implementation would compare against the unchanged Stage-3A
reference and Current ordinary sleep. Require separate producer, journal/local
component, lookup/invalidation and region reconstruction metrics. Include:

- quiet 512/1024/2048 worlds and initial population;
- one-cell tuple/temperature edits in a large connected region;
- bridge add/remove, split/merge and new-facing-tile discovery;
- activity/deadline churn with no writes;
- mask/event/inclusion ABA and far-change locality;
- repeated local churn plus guaranteed remote progress;
- tile/component/frontier/region/dependency capacity saturation;
- workers 1/4 and insertion/allocation-order deterministic digests;
- peak/steady memory versus configured and represented coverage;
- failure after partial work, ASan/UBSan and feasible TSan.

Require exact source, compiler, executable, configuration, worker, fixture, schedule,
hardware and raw-output identities. Do not set a Stage-4 threshold in this review.
Propose Stage-3B exit screens in change-proportional work units and memory formulas;
the parent will decide whether they are sufficient.

## Parent-only decisions and escalation

The reviewer may recommend alternatives but must not decide or silently redefine:

- canonical tile geometry or exact component keys;
- material authority or producer completeness;
- global versus local region semantics and handle identity;
- component/dependency/capacity/refusal policy;
- accepted determinism or failure boundaries;
- Stage-3B completion or Stage-4 admission;
- cohesion, Rapier handoff, fracture or any accepted ADR.

If the preferred design needs one of those decisions, present bounded alternatives,
evidence and the exact decision required, then stop at the parent gate.

## Deliverable

Return one architecture review containing:

- confirmed model/runtime identity and exact inspected source head;
- current hot-path and memory map with source symbols;
- invariant-preservation matrix;
- quantified trade-off matrix and recommended architecture;
- rejected alternatives and evidence-backed reasons;
- ordered implementation slices with file ownership and rollback/checkpoint boundaries;
- adversarial test additions required per slice;
- preregistered measurement plan and proposed Stage-3B exit screens;
- unresolved questions and explicit parent decisions.

The review is incomplete if it proposes only faster containers, omits split/delete
semantics, hides unknown coverage, relies on average-case unbounded work, or lacks a
credible memory formula.

## Stop conditions

Stop without implementation if model identity is unconfirmed, current main no longer
contains the Stage-3A reference, evidence/source conflict, a proposal requires an ADR
change, or the local/subregion completeness boundary cannot be stated without a false
claim. Preserve negative and ambiguous findings. The next transition is a parent
architecture decision, not an automatic coding dispatch.
