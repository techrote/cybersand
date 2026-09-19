---
title: Issue 12 Stage 3 execution freeze
status: Approved design
document-kind: runbook
scope: Frozen execution contract for completing scalable settled-region discovery after PR #43; read-only discovery only, no acceleration or material ownership transfer
canonical-for: [soliding-stage3-execution-freeze]
last-reviewed: 2026-09-19
related-documents: [soliding-programme.md, soliding-measurement.md, ../systems/settled-region-discovery.md, ../architecture/soliding-lifecycle.md, ../audits/issue-12-2026-09-19/producer-hook-review.md]
---

# Issue 12 Stage 3 execution freeze

## Authority, checkpoint and purpose

This page freezes the dependency-ready implementation contract for issue #12 Stage 3
after PR #43 head `90903355f5880e8f141ee6caea34840ad8b4990c`.
PR #43 remains a foundation checkpoint: lifecycle, bounded tile journal, producer
audit, ordinary-sleep control and synthetic journal-cost evidence exist, but
production World notifications and cross-block connected-region discovery do not.

Before executing this packet, re-read actual main, PR #43 CI/merge state and #12.
If main or PR #43 has advanced, reconcile source identity without silently changing
the architecture below. A runner/CI update alone does not invalidate the frozen
native design, but implementation must still target the actual source being changed.

This freeze exists so a supervising Sol parent can delegate bounded implementation
to Spark workers without asking those workers to make architecture decisions.

**Stage 3 remains read-only discovery. Cells are the sole material owner.**
No scheduler skip, stationary proxy, compact payload, cohesion, Rapier aggregate,
fracture, persistence migration or material-rule change is admitted here.

## Frozen Stage 3 outcome

Stage 3 must produce a bounded, deterministic, owner-serialized discovery system
that can:

- observe every relevant World mutation/activity/event/inclusion source without
  relying on render dirtiness;
- classify bounded canonical discovery tiles with immutable revisions;
- construct complete face-connected regions across tile/chunk seams;
- preserve holes, seams and exact material/state/temperature boundaries;
- invalidate stale tile and region snapshots promptly under edits, worker writes,
  body masks, pending events, activity, exclusion and failure;
- defer/refuse under finite capacity without changing authoritative simulation;
- measure complete producer, scan, connectivity, invalidation, memory and latency
  costs against the frozen ordinary-sleep control.

A Stage 3 region is an immutable **observation candidate**, not permission to
accelerate or solidify anything.

## Frozen discovery geometry

### Canonical tile rule

Discovery tiles are **not semantic scheduler activity blocks**, even when the
default geometry makes them coincide.

For Stage 3 integration, each resident World activity block is subdivided into
canonical non-overlapping discovery subtiles of at most **32 x 32 cells**:

- tile bounds are derived deterministically from chunk coordinates, activity-block
  local bounds and 32-cell subtile offsets;
- a tile never crosses an activity-block or chunk boundary;
- partial chunk/activity-block edges produce smaller tiles;
- every tile contains at most 1024 cells, matching the current bounded journal
  cell budget;
- activity blocks larger than 32 are represented by multiple independent
  discovery tiles sharing their parent activity/deadline signal;
- activity blocks smaller than 32 remain one tile per activity block;
- if configured tracking capacity cannot represent all required subtiles, tracking
  refuses those tiles explicitly while simulation continues unchanged.

The producer must maintain a canonical tile key independent of allocation order.
Suggested logical identity:

`{world_incarnation, chunk_y, chunk_x, activity_block_y, activity_block_x, subtile_y, subtile_x}`.

Slot numbers are implementation handles, not semantic ordering.

### Why this geometry is frozen

It keeps each scan bounded, makes no assumption that World activity size will
always remain 32, avoids a tile spanning multiple activity owners, and keeps
cross-chunk connectivity explicit rather than hiding it inside a large observer.

Do not switch to a world-global 32x32 raster or make region identity equal to
activity-block identity without parent review.

## Frozen producer architecture

### Serialized coordinator

Add an opt-in World-owned discovery coordinator/bridge. It may own journal and
producer metadata, but it owns **no material**.

Native worker jobs must never mutate the shared discovery manager. Worker effects
are reduced only after the existing deterministic phase barrier. All external
publication/region work runs under the serialized World owner.

Feature-disabled behavior must remain source-semantically identical to Current.
Tracking capacity failure disables/degrades **tracking only**, never simulation.

### Durable witness rule

Render dirty state is not a discovery witness. Discovery requires its own local
monotonic revision/invalidation events. Change-and-restore must invalidate even
when final bytes equal the original value.

A single tile revision may conservatively represent material/state/temperature,
mask and event invalidations; separate counters are allowed for diagnosis but are
not required for correctness. Rare global changes use world-level fences.

Local revision exhaustion must refuse/halt discovery rather than wrap.

### Required producer routes

Every route below must either produce the frozen signal or leave affected coverage
`witness_complete=false`. Omitting a route to gain apparent progress is forbidden.

1. Direct material edits: `set`, `paint_disc`.
2. Direct state/material writes: `set_cell_state` / no-effects `write_cell`.
3. Temperature writes, including nonambient Empty temperature.
4. Direct and body-displacement movement/swap: both source and destination.
5. Water quantity/coherence transfer and follow-on movement writes.
6. Reaction/state-progress tuple writes.
7. Worker tuple writes via post-barrier `merge_job_effects`; never worker->journal.
8. No-write activity via existing activity-block metadata.
9. Deferred interaction deadlines / wake scheduling.
10. Deadline consumption and ordinary sleep/wake transitions.
11. Transient obstacle add.
12. Transient obstacle remove/clear/reconfigure, including set-clear ABA.
13. Body-contact eligibility remains conservatively blocked by occupancy/mask
    coverage in Stage 3; do not invent a new Rapier/contact owner.
14. Accepted deferred explosions: mark the declared affected radius plus dependency
    halo pending at acceptance, not only when writes later execute.
15. Requested simulation-region/inclusion change.
16. Applied re-entry/inclusion and fresh-observation restart.
17. New resident chunk/activity-block/subtile registration.
18. Reservation-created resident coverage.
19. Live semantic policy changes that can change material behavior.
20. World clear/reset/replacement.
21. Failed tick/global quarantine.
22. Render dirty consumption explicitly has no discovery-acknowledgement meaning.
23. Epoch wrap/epoch-byte clearing is scheduling metadata and does not dirty
    discovery payload by itself.
24. Any new source mutation/event path introduced while this stage is active must
    be added to this matrix before Stage 3 can pass.

### Direct writes and worker writes

For direct owner-side tuple/temperature mutations, a central hook adjacent to
the existing actual-change dirty/write path is preferred. Same-value no-ops do not
need a revision. Multi-cell movement must invalidate both endpoints before a new
summary may publish.

**Payload locality rule:** tuple/temperature mutation dirties the tile(s) containing
the actually changed cells. Cross-tile connectivity is responsible for invalidating
facing-neighbor region completeness when a dirty tile could gain/lose a bridge.
Do not inflate every payload write by `maximum_rule_radius` merely for connectivity.

A dependency halo is used only where the observed semantic itself has wider
influence, for example accepted events, occupancy/contact conservatism or another
explicitly documented rule dependency. Such halos use the actual configured
`maximum_rule_radius` and must be counted as producer fanout.

For phased workers, existing `JobEffects` rectangles are the first bounded
producer. After each phase barrier, `merge_job_effects` invalidates every canonical
discovery tile intersecting each conservative effect rectangle. Connectivity then
invalidates the required facing-neighbor region completeness. Quantify false
invalidation caused by rectangle coarseness separately from explicit semantic halos.

Do not append discovery work from `write_cell`, `move_cell`,
`transfer_water`, `keep_cell_active` or `schedule_interaction_wake` when they
are executing inside worker jobs.

### Activity/deadline signal

Each discovery subtile inherits conservative activity/deadline state from its
parent World activity block.

The initial integration may piggyback on the existing begin/finish metadata passes.
Its O(resident activity blocks + mapped subtiles) overhead is real and must be
measured. Do not add a second full-world **cell** scan.

If activity/deadline feed cannot be made complete for a configuration, those tiles
remain witness-incomplete. Later sparse signal optimization is not a Stage 3
prerequisite.

### Body masks

Transient obstacle mutations have a local independent witness.

- add: invalidate/map the written coordinate immediately;
- clear/reconfigure: invalidate every old occupied coordinate before old coverage
  is discarded;
- set then clear between observations must still advance local revision;
- tiles with body occupancy, and the declared conservative rule-radius dependency
  halo where required, are noninspectable/blocked;
- unrelated far-away body masks must not globally reset all quiet regions.

Stage 3 does not add a contact-force semantic. Endpoint/occupancy conservatism is
the admitted first policy.

### Pending events

Explosion acceptance marks intersecting discovery tiles plus
`maximum_rule_radius` dependency halo as pending before execution.

If bounded local mapping capacity is unavailable, the safe fallback is to make
discovery globally nonconsumable until the event drains; do not reject or alter the
authoritative event merely because discovery cannot track it.

Deferred interaction deadlines are supplied from existing activity-block metadata.

### Inclusion, reset and policy fences

Requested simulation-region changes, World clear/replacement and semantic policy
changes are rare global observation events. Use a world-level incarnation/semantic/
coverage fence rather than pretending a local render dirty rectangle is sufficient.

A requested region change makes old summaries nonconsumable immediately.
Re-entry earns no prior quiet age and requires fresh complete observations.

`World::clear` retires the previous discovery incarnation. A moved World may
transfer its coordinator and incarnation with the World object; replacement of an
old World retires the replaced coordinator. No old external observation handle may
become valid for unrelated replacement storage.

A failed tick globally halts discovery publication immediately after worker drain.
There is no discovery rollback or in-place retry.

## Frozen exact cell sampling

A discovery scan reads authoritative stored tuple values, not public values modified
by transient occupancy:

- `stored_material`;
- stored `state_a`;
- stored `state_b`;
- stored temperature (a new serialized internal accessor may be required because
  public `temperature()` masks occupied cells);
- occupancy supplied separately from transient-obstacle state.

Do not use `get()`, public masked state helpers, render bytes or `content_hash()`
as the exact discovery tuple oracle.

Canonical Empty with state_a=0, state_b=0 and ambient temperature is a hole.
Empty carrying nondefault hidden state/temperature is **not** silently treated as
ordinary disposable hole membership; it blocks representation candidacy until an
explicit later policy handles it.

## Frozen cross-tile connectivity architecture

### Layering

Connectivity is a separate bounded layer over immutable, complete tile revisions.
Do not put World/Rapier ownership inside the connectivity implementation.

The preferred structure is:

1. bounded per-tile local component extraction;
2. revisioned boundary adjacency between components of neighboring tiles;
3. bounded resumable component-graph traversal;
4. immutable complete region publication.

A conventional union-find/disjoint-set may be used as temporary analysis scratch,
but must **not** be the sole persistent region representation: arbitrary local
edits, deletions and splits are first-class operations.

### Local components

For each inspectable complete tile revision:

- use four-neighbor/face connectivity only;
- canonical component key is the exact nonempty discovery tuple
  `{material, state_a, state_b, temperature}`;
- differing material/state/temperature never merge in Stage 3;
- diagonal-only touch does not connect;
- canonical Empty is absence/hole;
- noncanonical Empty is blocking/special and cannot be swallowed as a hole;
- occupancy or incomplete signals block component publication.

Use fixed reusable scratch bounded by tile cell count. Published component
descriptors must have explicit finite capacity. A pathological tile that exceeds
component/descriptor capacity becomes connectivity-unavailable; it never publishes
a truncated component set.

Row spans and boundary-port masks are preferred compact descriptors, but the
worker may choose an equivalent bounded representation if it preserves every
frozen property and the parent approves before merge.

### Boundary adjacency

Neighbor tiles connect only across a shared face and only where facing boundary
cells belong to components with exactly equal component keys.

Every boundary decision is revision-bound. If either tile revision changes, all
derived adjacency using that revision is stale immediately.

Holes and seams remain holes/seams; no bbox/occupancy filling is permitted.

### Region construction

A region traversal:

- starts from the lexicographically smallest unassigned component seed by world
  coordinate, with a fixed exact-key tie break;
- traverses neighboring component edges in a fixed canonical direction/order;
- uses bounded resumable frontier/scratch;
- may span ticks/service calls;
- publishes nothing until the traversal is complete and every dependency revision
  still matches;
- records area, bbox, tile/component count, exact key, dependency/revision witness,
  and deterministic member/shape digest sufficient for test comparison;
- does not create material membership ownership.

If frontier/component/region-slot capacity is exhausted, mark the candidate
incomplete/capacity-refused and retain cells. Never publish the visited prefix.

### Region identity

Stage 3 does **not** promise semantic identity continuity through arbitrary topology
changes.

A published region handle is generation-bearing:

`{world_incarnation, region_slot, region_generation}`.

It identifies one immutable complete region generation only. Any relevant tile
revision invalidates that generation. Rediscovery after a split/merge/change may
receive new region generations.

Continuity heuristics belong to later representation/persistence work, not Stage 3.

### Split/merge invalidation

Tile invalidation must immediately retire:

- region generations referenced by the tile's previous local components; and
- region generations on neighboring tile components whose facing boundary could
  gain/lose connectivity because this tile changed.

This bounded neighbor invalidation is required even if the old tiles did not
previously connect: a changed tile can create a new bridge, making a neighbor's
previously "complete" maximal region incomplete.

No global region flood-fill is required merely to make old snapshots unusable.

Untracked, blocked or connectivity-capacity-refused tiles are unknown boundaries.
A region touching an unknown boundary cannot be published as globally complete.

## Frozen deterministic ordering

Correctness must not depend on:

- native worker completion order;
- unordered_map iteration;
- branch allocation timing;
- benchmark process timing.

Tile coordinates/keys provide canonical ordering. Region seed selection and
neighbor traversal use fixed lexicographic/world-coordinate order.

Producer invalidations may be coalesced when coalescing cannot lose revision
meaning. Region-handle allocation and scarce region capacity are awarded in
canonical seed order, not "first worker to finish" order.

Repeat and workers1/4 fixtures must produce equivalent tile/region summaries and
deterministic digests for the same authoritative state.

## Frozen capacity semantics

The following capacities are explicit, separately measured resources:

- tracked discovery tiles;
- dirty/signal queue;
- local component descriptors/scratch;
- boundary adjacency records;
- region build slots;
- traversal frontier;
- published region slots;
- event-to-tile mapping scratch;
- optional tile-key lookup/index.

Rules:

- full capacity never changes World material/simulation;
- no hidden unbounded overflow vector/list;
- no truncation presented as complete;
- incomplete work may lag and resume;
- unsupported/untracked coverage is explicitly unknown;
- local capacity refusal should remain local where integrity is preserved;
- revision exhaustion, source-read failure or failed World globally disables
  consumption until reconstruction/replacement;
- setup/registration complexity is measured. PR #43 already demonstrated that
  quadratic duplicate-bound registration is a negative scaling result; World
  integration must not silently make O(N^2) global registration the normal path.

Canonical producer identity should permit direct/keyed registration rather than
rescanning every prior registered bounds record. Any API extension needed for this
must preserve bounded allocation and existing standalone tests.

## Spark work-package boundaries

The detailed packets live beside this freeze:

- [Producer / World witness integration](soliding-stage3-spark-producer.md)
- [Cross-tile connectivity](soliding-stage3-spark-connectivity.md)
- [Adversarial verification](soliding-stage3-spark-verification.md)
- [Integrated measurement](soliding-stage3-spark-measurement.md)

Packages A and B may begin in parallel after the parent confirms this freeze
against actual source. C and D consume the integrated A+B result and normally run
after their first coherent merge checkpoint.

Do not let two write workers own `world.cpp`, `world.hpp` or the same discovery
header simultaneously.

## Parent integration order

1. Re-check PR #43 final-head CI and exact main.
2. If PR #43 is green and review-clean, merge it or deliberately retain its exact
   head as the successor base. Do not recreate its completed work.
3. Run Producer and Connectivity Spark packages on isolated branches/worktrees.
4. Parent independently inspects both diffs and reconciles shared interfaces.
5. Integrate A+B into one Stage-3 candidate branch.
6. Run focused ordinary native tests plus package tests before broad benchmarks.
7. Run independent Verification Spark packet against the integrated diff.
8. Repair confirmed defects under parent control.
9. Run Measurement packet and the registered whole-system campaign.
10. Parent performs Stage-3 exit review. Only then may Stage 4 be entered.

## Stage 3 exit checklist

Stage 3 is complete only when all items below have passing evidence or an explicit
evidence-backed refusal that keeps affected coverage nonconsumable:

- [ ] PR #43 foundation/reconciliation state is incorporated without rewriting evidence.
- [ ] Complete World producer matrix is implemented or affected tiles stay witness-incomplete.
- [ ] No worker mutates the shared discovery manager.
- [ ] Direct tuple/state/temperature ABA invalidates independently of render dirty state.
- [ ] Worker writes invalidate after deterministic barriers with workers1/4 parity.
- [ ] No-write activity and interaction deadlines prevent false settled evidence.
- [ ] Mask add/remove/reconfigure ABA has local revisions; far masks do not cause global reset.
- [ ] Accepted pending events invalidate/block before execution.
- [ ] Requested/applied inclusion, exclusion/re-entry and fresh-observation semantics pass.
- [ ] Chunk creation/reservation and tracking-capacity refusal never alter simulation.
- [ ] Clear/replacement/move identity and failed-world quarantine are explicit and tested.
- [ ] Epoch-wrap bookkeeping does not masquerade as discovery mutation.
- [ ] Canonical bounded subtiles handle default and declared custom geometry/refusal cases.
- [ ] Exact stored tuple sampling includes temperature beneath occupancy.
- [ ] Local component extraction preserves holes/seams/state boundaries and rejects truncation.
- [ ] Cross-tile face connectivity works across activity/chunk seams and negative coordinates.
- [ ] Diagonal contact does not merge; narrow face necks connect only as discovery, never cohesion.
- [ ] Tile invalidation retires both old connected regions and facing-neighbor completeness.
- [ ] Region traversal is bounded/resumable and publishes only complete revision-matched results.
- [ ] Region identity/generation, split/merge invalidation and capacity refusal are deterministic.
- [ ] Untracked/blocked/capacity boundaries prevent false globally-complete regions.
- [ ] Feature-disabled authoritative behavior and work counters remain equivalent.
- [ ] 1/4-worker deterministic state plus discovery summaries/digests match where required.
- [ ] ASan/UBSan and feasible TSan/failure tests pass.
- [ ] Whole-system producer+journal+connectivity CPU/memory/latency costs are measured.
- [ ] Large-world region count/area, churn, invalidation fanout and wake/rebuild amplification are retained.
- [ ] No stationary acceleration, ownership transfer or Rapier behavior is claimed by Stage 3.
- [ ] Canonical docs, evidence, retrieval routes and exact source/artifact identities are synchronized.

## Parent-only decisions

The supervising parent must retain these decisions; Spark workers may report
alternatives but must not silently change them:

- Stage-3/Stage-4 admission.
- Cells-only material ownership during Stage 3.
- Discovery tile geometry or semantic identity.
- Exact component key broadening/narrowing.
- Global versus local fence policy.
- Any omission/substitution in the producer matrix.
- Capacity values that turn unknown coverage into accepted coverage.
- Material eligibility, cohesion or support semantics.
- Any Rapier, persistence, motion or fracture admission.
- Changes to accepted ADR boundaries.
- Interpretation of performance evidence and break-even claims.
- Merge decisions and issue/PR closure.

## Stop and escalate conditions

A Spark worker stops its package and reports rather than improvising if it needs to:

- change material/reaction/Water/granular semantics;
- introduce cell velocity, cohesion or structural-strength state;
- access shared discovery state from native workers;
- call Godot/Rapier from native workers;
- use an unbounded flood-fill, queue or hot-resize path;
- truncate a tile/region and label it complete;
- make simulation success depend on discovery capacity;
- infer mutation from render acknowledgment;
- invent rollback after failed/postcommit work;
- change #26 or another experiment's control;
- broaden Stage 3 into acceleration or dynamics;
- weaken provenance, GLIBC/runtime or required CI gates;
- choose a new architecture because a packet is inconvenient.

## Compact overnight parent handoff

Use this block verbatim if useful:

> Continue issue #12 from PR #43 and the canonical Stage-3 freeze in
> `docs/operations/soliding-stage3-freeze.md`. You are the supervising
> architect/integrator. Do not repeat PR #43 foundation work.
>
> Delegate dependency-ready implementation to the named GPT-5.3-Codex-Spark
> packets for producer integration and cross-tile connectivity, using separate
> worktrees/branches. Retain all parent-only architecture and stage-gate decisions.
> Review actual diffs before integration.
>
> Finish Stage 3 only against its frozen exit checklist: complete World witnesses,
> bounded cross-tile face connectivity, immediate stale-region invalidation,
> deterministic capacity/refusal, no partial publication, workers1/4 parity and
> whole-system cost evidence versus ordinary sleep. Cells remain the sole material
> owner; no Stage-4 acceleration or Rapier admission is implied.
>
> After A+B integration, commission the independent verification packet, repair
> confirmed defects, then execute the measurement packet on the Ryzen 2600X where
> useful. Retain negative/ambiguous evidence. Enter Stage 4 only after an explicit
> parent review says every Stage-3 gate is satisfied.
