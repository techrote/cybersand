---
title: Incremental settled-block discovery
status: Current
document-kind: design
scope: Stage 3 first read-only discovery substrate and admission limits; connected regions and acceleration remain separate
canonical-for: [settled-region-discovery]
last-reviewed: 2026-09-19
related-documents: [../architecture/soliding-lifecycle.md, ../operations/soliding-programme.md, activity-dirty-regions-and-waking.md, ../operations/soliding-measurement.md]
---

# Incremental settled-block discovery

## First increment and limits

**Current standalone native substrate:** [SettledDiscovery](../../native/include/cybersand/settled_discovery.hpp)
consumes explicitly supplied owner-side dirty/activity signals and classifies complete
registered blocks. It is not wired into World or any ordinary runtime controller. Cells remain the only material owner;
no scheduler skip, proxy, compaction, material rule or Rapier change is admitted.
A uniform tile is not a face-connected region and not a cohesion certificate.
Mixed states, holes and material boundaries must be explicit refusals of the
uniform-summary classification, never silently filled or averaged.

The Stage 2 lifecycle received an independent review and focused transition tests
before this substrate was written. **Current:** fixed template-bounded records
and a deduplicated FIFO have equal capacity; no hot allocation, periodic scan or
overflow list exists. Registration is setup work and rejects zero/oversized/overflowing
bounds, duplicate bounds and full capacity. Handles contain an externally unique
nonzero incarnation plus slot; there is no slot reuse or live reset. New registry
construction requires a fresh incarnation. This is a block observation ID, not
production region identity. Copy/move cloning is forbidden.

**Planned producer integration:** register blocks during chunk creation; feed all
relevant mutation and activity changes after deterministic owner barriers. Existing
resident metadata passes may feed changes, but their added inspections/time must
be measured rather than described as free. A missing mutation witness makes the
producer unsafe: this standalone API cannot detect notifications a caller omits.
No runtime promotion may consume it before the complete producer audit/tests.
There is no rest-age or observation-gap detector in this journal: a producer must
clear `witness_complete` on gaps; unchanged flags across elapsed time prove nothing.
Registration rejects exact duplicate bounds but permits overlaps. A World producer
must register canonical nonoverlapping tiles before reporting region area/counts,
or supply separately admitted overlap accounting.

## Mutation and activity contract

Use an independent nonwrapping block revision, not render dirty rectangles that
publication can clear. Direct material/state/temperature edits and deterministic
post-barrier job effects invalidate summaries. Change-and-restore must still
change the witness. Conservative effect rectangles may cause false invalidation;
measure that cost. Active, pending-deadline, occupied, excluded and failed-world
states cannot gain discovery rest. Re-entry must revalidate through ordinary
activity. No sleeping flag alone authorizes representation replacement.

A resumable scan retains its starting revision and scratch only. Relevant edits
invalidate any old summary immediately; no partial result is publicly eligible.
Complete results publish only after the same revision and activity/exclusion
conditions survive final validation. Each scan/start/dequeue/finalization in `advance` consumes its declared budget.
Dirty/signal notifications perform constant work outside that budget, and setup
registration checks duplicates in O(registered slots). Producer event volume,
registration and metadata feed cost must be measured separately. Work saturation may lag safely;
dropped invalidations may never leave an apparently valid summary.

## Capacity, identity and failure

Current block identity is caller-supplied unique incarnation plus a never-reused
slot. The substrate refuses revision exhaustion; it does not allocate/check a
global incarnation or slot generation. Production region generation allocation
and explicit exhaustion remain the lifecycle contract for future integration. Registration/queue capacity
outcomes preserve cell authority. No hot resize or hidden unbounded overflow
list. If observation integrity is lost, disable consumption of summaries and
report the reason until explicit observer/world reconstruction. **Current substrate:** explicit producer failure, source-read exception, backwards
valid clock or revision exhaustion disables every snapshot; the first failure
reason is retained. Stale handles and refused setup cannot advance the clock.
No in-place retry/reset exists. **Planned World integration:** failed-world
quarantine must call the observer failure boundary, and replacement must invalidate
old observation handles. A block-local unhealthy signal alone is not a substitute
for notifying a failed World.

## What remains before Stage 3 can exit?

The follow-up must join complete summaries and explicit nonuniform membership
across block/chunk seams with bounded resumable face connectivity, stable region
identity, holes and material/state boundaries. No global flood-fill is admitted.
It must quantify cell/block/chunk inspections, queue/scratch high water/refusal,
latency distribution, churn/false invalidation, region count/area, CPU and memory
per tracked area, and local edit wake/rebuild amplification on large worlds.
An explicit mixed-block refusal is safe but is not world-scale region discovery.

The first baseline/control and later A/B procedure belong to the
[measurement contract](../operations/soliding-measurement.md). Missing metrics
remain gaps; an observer's overhead is not evidence of an acceleration benefit.

## Bounded work, fairness and metrics

**Current:** one budget unit covers starting/dequeuing a block, reading one cell,
or final revision/condition validation and publication. A 32-square uniform block
requires 1026 units. Empty/mixed blocks are fully inspected; holes, state differences
and temperature differences produce explicit classifications. Occupancy produces
Blocked. Noninspectable signals produce Blocked in one unit without a cell scan.
Only completed classifications are published as value copies; dirty work immediately
returns to Invalid, including ABA writes that restore the original tuple. The source
callback must be bounded, read-only, owner-serialized and non-reentrant.

Repeated invalidation of a partially scanned head rotates it to the tail in constant
work, so local churn cannot indefinitely starve untouched queued blocks. The first
outstanding dirty tick survives restarts. Queue high-water counts distinct registered
blocks and cannot exceed slot capacity. Full registration refuses only the new block;
there is no existing-summary eviction or lost invalidation.

Metrics distinguish signal observations, inspected cells, started blocks, budget work,
invalidations, restarts, all completed classifications (including Blocked), mixed/blocked
counts, registration refusals, queue high-water and first-dirty-to-classified maximum/
total tick latency. Counters saturate; identity/revision counters refuse exhaustion.
`storage_bytes()` includes the fixed records/queue, not a World or native heap estimate.
No connected-region/chunk distribution or real-hook CPU cost is inferred from these
metrics. Those remain required for Stage 3 completion.

The [focused tests](../../native/tests/test_settled_discovery.cpp) exercise budgets,
partial publication, ABA, exact state/temperature boundaries, exclusion, pending events,
occupancy, capacity, failure, coordinates, fairness and copied-snapshot lifetime.
Paired World fixtures test that an explicitly signalled read-only observer leaves
content/state and tick-work identical with one/four workers. They do not prove
production mutation-hook completeness or desktop/Web runtime integration.

## Synthetic journal cost preregistration (2026-09-19)

**Planned measurement, frozen before execution:** the standalone
[`settled_discovery.cpp`](../../native/bench/settled_discovery.cpp) cost decomposition
uses contiguous synthetic `DiscoveryCell` arrays, with explicitly supplied constant
inspectable signals. These are artificial input contracts, not observations of a
World, material stability or scheduler sleep. The reader only indexes immutable
source tuples during each service call; notified ABA edits occur between calls.

The matrix is sides **128, 512, 2048** cells, complete nonoverlapping **32x32** tiles,
fixed **4096** journal slots in every case, budgets **64, 1024, 8192** work units per
service epoch, and **7 sequential repeats**. A service epoch is one invocation of
`advance()`, not a simulation tick, frame, or duration of earned rest. Report actual
`sizeof(DiscoveryCell)`, fixed journal bytes and bytes per registered source cell.
The partially occupied registry intentionally exposes fixed-capacity memory cost.

Each run separately times source initialization, journal allocation/initialization
and all registration (including the current linear duplicate-bounds lookup, hence
quadratic total registration). It then records these fixed phases:

1. Initial full classification: drain the initial queue under the chosen budget.
2. Idle: **100000** service calls with no dirty notifications.
3. Local ABA: **128** repetitions of mutating and restoring one source tuple in the
   centre tile, notifying both changes, then draining that tile completely.
4. Churn/fairness: enqueue every tile, repeatedly notify centre-tile ABA before
   service, for `ceil(tile_count * 1026 / budget) + 4096` service epochs. Confirm
   every unaffected tile eventually publishes; preserve incomplete churning work.
5. Recovery: stop edits and drain the remaining queue under the same budget.

Report phase elapsed time and producer-call time separately, service epochs,
inspected cells, started blocks, work units, publications, invalidations, restarts,
first-dirty-to-classified total latency, lifetime maximum latency/queue high-water,
and pending queue counts. Producer timing includes clock sampling overhead and
source mutation/restore. Idle timing includes the harness service call. An explicit
extra registration at full4096 capacity must refuse; smaller cases do not pretend
to measure a full-registry refusal. Source tuples must finish exact, and initial
classification/idle/local work totals have deterministic analytical checks.

The driver [`run_settled_discovery.py`](../../tools/experiments/run_settled_discovery.py)
freezes copied source/header/driver inputs, tool and binary hashes, Git HEAD/local
status, hardware and this protocol before compilation/runs. It writes the complete
run plan before the first timed case, runs only sequential children, retains every
stdout/stderr/timeout/failure with hashes, and summarizes raw successful values
without dropping negative or ambiguous arms. Smoke overrides are labeled separately.

**Interpretation limits:** this measures the journal and synthetic array reader,
not real World hash lookups, native mutation hooks, activity/metadata passes,
component/connectivity work, collision rebuilds, Rapier or rendering. `advance()`
work excludes producer calls and registration. Low idle cost or bounded synthetic
latency cannot establish net savings versus Current sleep, a promotion threshold,
or Stage 3 completion. Churn overhead and fixed-capacity memory inefficiency are
results to retain, not reasons to enlarge fixtures until they disappear.

`Empty` means uniform material ID zero; it retains the exact state/temperature
tuple and does not authorize dropping hidden state or thermal storage. Direct
tuple tests cover this because Current content hashes alone omit some Empty state.

**Measured standalone outcome:** the [63-process journal cost record](../audits/issue-12-2026-09-19/journal-cost-results.md)
verifies initial/idle/local work and fair progress under repeated ABA notifications.
At 2048-square area it records roughly 29 ms initial synthetic scanning and a 491672-byte
fixed journal. Registration scaling, repeated churn work and incomplete churning
classification remain explicit negative results. The measured array reader excludes
real World producer/lookup/connectivity costs and does not satisfy the Stage 3 exit.
