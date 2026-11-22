---
title: ObjectShard 001R native admission and editing investigation
status: Planned
document-kind: audit
scope: Draft/HOLD implementation iteration evidence; final committed-source qualification is recorded separately
last-reviewed: 2026-11-22
related-documents: [../research/objectshard-001.md, 2026-11-22-objectshard-final-acceptance.md]
---

# ObjectShard 001R: native admission, bounded discovery and owned editing

This record preserves the negative M2 control and the subsequent native repair
experiments. It does not establish physical Windows acceptance or replace the
historical native performance matrix with its **10 failures among 74 timing
limits**. Runtime source inputs below identify frozen working-tree iterations;
the final committed-source receipt must be consulted for the delivered package.

## Forensic ledger

| Category | Finding and evidential limit |
| --- | --- |
| Owner observation | Scenario B at tick 1,999 has three owners with 4, 17 and 69 structural cells and 215 retained `Capacity` events. The owner reports a larger unsupported block still floating. |
| Demonstrated source mechanism | M2 `prepare_next()` returns on its first discovered component, before considering other eligible components. All three owner slots can therefore be allocated to early small components. Full slots cause another whole-component search on subsequent calls. |
| Controlled reproduction | A source-compatible independent connectivity fixture containing detached components of 1, 4, 9 and 400 cells admits `[1,4,9]` on M2; the 400-cell component remains World-owned. Another 128 unchanged full-slot calls rediscover 51,200 cells. |
| Second demonstrated mechanism | A 400-cell component with a 32-work discovery budget never completes on M2: every search restarts and ends in `Capacity`. The control retained 2,048 unsuccessful calls. |
| Missing original evidence | The owner exports do not contain a complete World image or complete input history. They cannot establish the original large component's exact connectivity, area or shape count, or form a deterministic input replay. |
| Repair experiment | Retain complete derived component membership, resume bounded search, separate structural eligibility from resource admission, rank complete candidates, and cache typed refusals. Compare against an independent row-major image/deque connectivity oracle. |
| Lead review finding | A transiently obstructed largest candidate could repeatedly be retried ahead of a smaller candidate. Add bounded live-admission deferral and test both source obstruction and pending accepted work. |

The unchanged owner ZIP and six original exports are primary observations. The
new synthetic fixtures reproduce mechanisms; they are not reconstructions of
the user's incomplete action history.

The negative control ran against historical M2 documentation HEAD
`dc4282e5f5f9b886315e8450613740d265f5fbc3`, with its native input hashes captured
in [the control manifest](objectshard-001r-20261122/native-admission/baseline-manifest.json).
Its [original oracle fixture](objectshard-001r-20261122/native-admission/baseline-oracle-fixture.cpp)
and [negative result](objectshard-001r-20261122/native-admission/baseline-negative-result.txt)
retain **826 checks, four failures against the desired behaviour**.

## Implemented mechanism and resource boundaries

`object_shard_discovery.hpp` is one bounded resident-Lab component catalogue.
It is a derived cache; World continues owning all stationary inventory until
the existing promotion transaction commits. Per-cell labels include a search
generation, so stale membership cannot become current after a label slot is
reused. Same-material Wood and RedBrick components retain the established
four-connected cohesion and explicit Wall-anchor policy. A component touching
the resident boundary remains unknown and is not promoted.

Ordinary committed mutations still update exact payload/ABA witnesses. Only a
change among Wood, RedBrick, Wall and noncohesive material classes invalidates
connectivity. Fire, Smoke and Sand movement cannot silently remove a payload
witness, but no longer restart an unchanged structural search. An affected
component is invalidated through the changed coordinate and its four neighbours.
A partially visited component restarts only when the edit touches its visited
frontier; edits ahead of the frontier can be incorporated without losing work.

Both dirty-seed consumption and BFS traversal are charged against the per-call
discovery work budget. A complete component is never truncated at that budget,
at a storage-area limit or at a shape limit. The independent membership census
finishes before scarce slots are selected. Derived summaries and candidate
selection are additionally bounded by the resident-area-sized catalogue; the
reported work count is the seed/BFS budget, not a claim that every instruction
in summary publication or promotion is included in that count.

Three admissions prefer largest complete eligible components; the fourth
prefers the oldest eligible candidate. This uses completed admission count,
not frame rate. Stable small candidates cannot be indefinitely displaced by
new large candidates when slots continue becoming available. Existing active
owners are never discarded or demoted to make space. If the owner already used
all slots before a larger structure became eligible, that structure remains
World-owned with an explicit `BodySlots` reason until resources change.

Complete geometry refusals distinguish component cells, padded bounding-box
area and exact rectangle count. Owner slots and total retained area are
separate resource reasons. Unchanged capacity holds reuse cached membership
and avoid repeated flood fill. Transient payload/occupancy or pending-event
refusals defer that candidate for eight discovery calls, allowing another
complete candidate to progress, then retry live admission without requiring
a topology edit. Staging is acquired only after live source admission passes.

The promotion prepare and final validation checks use the same conservative
intersection between a candidate's padded bounds and pending explosion bounds.
Relevant accepted work remains a refusal. Unrelated queued work stays owned by
World and cannot produce a prepared transaction that is impossible to commit
solely because the whole Lab is paused.

## Authoritative moving-shard edits and session diagnostics

`erase_shard(ShardEditRequest)` admits only an existing structural cell. The
request binds session/shard generation, monotonic transaction, body generation,
applied geometry revision, pose serial, material revision, cell incarnation,
exact material/state/temperature tuple and capability version. It is an authored
destructive edit under the shard owner, not a World paint operation or transfer.

The registry constructs the exact proposed rectangle cover before debiting
inventory. A cut that would exceed shape capacity leaves material, scheduling,
geometry revision and accounting unchanged. A successful cut updates geometry,
mass and topology at the stable local lattice origin, records authored
destruction once, and enters the existing geometry-installation barrier. A
duplicate request returns its terminal receipt; altered or evicted requests
cannot execute again. Removing the final structural cell retains any products
or cargo under the existing draining lifecycle. No fracture capability is
advertised.

Snapshots expose a bounded candidate list and complete census/resource counts,
including exact non-admission reasons and pending discovery work. A snapshot
taken immediately after an edit marks the old catalogue incomplete even before
the next discovery call. Session metrics reset on scenario reset. Explicit
`lifetime_metrics` sum counters and take maxima across sessions; current
allocation measurements remain current. The existing accounting ledger is
intentionally cumulative, including explicit reset disposal.

## Native experiment results

| Frozen input | Scope | Result |
| --- | --- | --- |
| `ffc785c1c6c85bb65676c344952a2936ee8e4d9077d4636f3066b95055635b2a` | Existing coordinator and storage regressions | 11,145 checks, zero failures |
| `ec2ed9eac06197e1522a5af21933fdb891500cfa56cba1f78040c1958e9d266b` | First expanded independent oracle | 26,945 checks, one experimental assertion failure: the cut was ahead of the frontier, so no restart was required; all exact membership checks passed |
| Same production input, corrected test input | Explicitly remove the visited root before the far cut | 26,946 checks, zero failures |
| `6e99069998b89b7006e6d569cd24bcd612c6748363543eee0fc47fa0f9ff3ea5` | Admission, coordinator and storage | 38,527 checks, zero failures |
| `7ad0cd16be190e7b4b0579592c429e7f92c7e1ebe92836450a8c8cff04c096ce` | Six native suites with ASan and UBSan, including external Fire and unchanged chemistry controls | 90,694 checks, zero failures; leak sanitizer disabled by the established runner |
| `76f97638957c09ba3ba3551096c89945e5f3de1ee2c76667b37907ad64de71ca` | Transient-candidate fairness and relevant/unrelated pending-work delta plus existing coordinator suite | 31,112 checks, zero failures |

The repaired ordering is `[400,9,4]`. Another 128 unchanged full-slot calls
rediscover **zero** cells. The 400-cell/32-work component completes exactly.
The oracle campaign also exercises repeated irregular edits, true and near
anchors, resident-edge refusal, distinct cohesion materials, interrupted
searches, full trunk removal, horizontal cuts at multiple heights, a two-cell
diagonal staircase separator, slot release, age fairness, shape refusal,
exact owned cuts and receipt/reset adversaries. These are native tests; actual
Rapier and owner-rendered scenarios are separate qualification gates.

## Matched admission cost, with limits

The [matched cost record](objectshard-001r-20261122/native-admission/matched-cost.json)
uses six alternating process pairs on one shared Linux host. Both binaries
have the same three one-cell owners and the same 400-cell World candidate,
with the same source-compatible benchmark and `-O1` compiler flags. Each run
warms 128 calls and measures 4,096 calls. The candidate is frozen native input
`7ad0cd16…`, before the later transient-retry record fields; it is an iteration
measurement, not the final package's performance receipt.

| Metric: median across six per-process results | M2 control | Repair iteration |
| --- | ---: | ---: |
| Construction | 1.343 ms | 1.500 ms |
| First prepare after adding the large candidate | 34.280 µs | 49.489 µs |
| Cached repeated admission p50 | 27.215 µs | 0.116 µs |
| Cached repeated admission p95 | 44.882 µs | 0.123 µs |
| Cached repeated admission p99 | 94.224 µs | 0.132 µs |
| Median of each process's maximum | 440.342 µs | 19.253 µs |
| Rediscovered cells across 4,096 measured calls | 1,638,400 | 0 |
| Reported retained bytes | 3,584,489 | 4,258,513 |

The cache trades 674,024 additional retained bytes in this fixture for the
elimination of repeated searches. The first census costs more than M2's first
fit search because it completes the candidate set. These figures concern only
native admission under an unchanged full-slot condition. They do not measure
Windows gameplay, presentation, actual Rapier settling, the full Lab frame or
the complete historical timing matrix. The host was shared and not CPU-pinned;
the raw runs are retained rather than presenting a single favourable sample.
