---
title: ObjectShard live-edit measured performance and unresolved limits
status: Historical record
document-kind: audit
scope: Exact-source native batch comparison and forty matched inactive-edit progression windows
canonical-for: []
last-reviewed: 2026-11-28
related-documents: [performance-method.md, ../../research/objectshard-m4-workbench.md]
---

# Live-edit performance results

The native batch experiment demonstrates that a substantial cut no longer
requires an independent parent reconstruction for every removed cell. The
matched whole-application comparison also finds a lower moving-tower median in
this campaign. These are separate findings; faster editing does not establish
zero overhead when editing is inactive.

## Native removal and reconstruction

The [complete native record](native-batch-performance-final.json),
[compact summary](native-batch-performance-summary.json) and
[final-source continuity review](native-benchmark-final-candidate-continuity.json)
bind this experiment to the final candidate's identical 96 native inputs.
The measured source was `ace52bc6e9b3b958ed164f3328d02b07cf2d5c50`; the final
application is `ba6d8de45bd4d38717d92bdece7153bff115c0f0`. This is an explicitly
source-equivalent native measurement, not a claim that the earlier application
campaign passed.

Each arm acquires current targets, removes the same cells and acknowledges the
native geometry. The 15 matched pairs (three replicates for each footprint)
pass 585 checks, including final material, collider digest, mass, centre of mass
and inertia equality. The compiler is local GCC 14.2 with optimization; fixture
creation, worker transport, Main Rapier installation and rendering are outside
the timed region. The carrier has 2,500 slots and starts with 2,304 material cells.

| Footprint | Removed cells | Individual-cell median | Batched median | Parent rebuilds, individual → batch |
|---|---:|---:|---:|---:|
| Circle, radius 1 | 5 | 1.569 ms | 0.333 ms | 5 → 1 |
| Circle, radius 4 | 49 | 15.222 ms | 0.341 ms | 49 → 1 |
| Circle, radius 8 | 197 | 60.480 ms | 0.381 ms | 197 → 1 |
| Circle, radius 16 | 797 | 226.401 ms | 0.473 ms | 797 → 1 |
| Thin slice | 48 | 14.934 ms | 0.340 ms | 48 → 1 |

This comparison isolates removal of per-cell reconstruction amplification. It
does not establish a whole-application speedup or an exhaustive scaling law
over carrier area, fragmentation, collision complexity and owner population.
The [method](performance-method.md) explains those cost terms and the limits of
the internal phase counters. The native regression and budget gates separately
exercise sparse material, capacity pressure, no-ops and complete removal.

## Matched progression with editing inactive

The [forty-window result](matched-idle-throughput.json),
[runtime/source custody](matched-idle-custody.json),
[host description](matched-idle-host.json), [raw records](performance-raw/summary.json)
and [independent review](final-throughput-independent-review.json) retain every
sample and its identity. Both applications use their official GCC 13.3 runtime,
the same pinned Godot and Rapier, and byte-identical observation fixtures,
camera settings and authored rectangles. Before/after source and runtime
custody is equal.

Baseline application: `b7d889b925ab3244d10e6fe48f487fbe0dc1ce73`, native SHA-256
`059c5880234a4d5349e6e78527187b13e3b205b039b5f3baf3e033cdaff53fe4`.
Candidate application: `ba6d8de45bd4d38717d92bdece7153bff115c0f0`, native SHA-256
`ab72a2fa2fd973e784ab6adf962bad6a9a4ec4a92e6975c45ab4490b4331ee8e`.
The machine is a shared Linux AMD EPYC 9V74 environment with nine visible logical
CPUs. These are headless measurements, not the owner's Ryzen 5600X/TITAN RTX or
hosted Windows renderer measurements.

The design is five workloads × recording off/on × two replicates × two sources,
six seconds per window. Only one process runs at a time and source order
alternates by replicate. All 40 windows pass their workload, material, ownership
and physical invariants. Rates below are median native semantic ticks/s; process
callbacks and renderer frames are separate quantities.

| Workload | Recording off: baseline → candidate | Change | Recording on: baseline → candidate | Change |
|---|---:|---:|---:|---:|
| ObjectShard disabled | 59.646 → 59.726 | +0.13% | 59.510 → 59.336 | −0.29% |
| Enabled, zero owned bodies | 59.620 → 59.950 | +0.55% | 59.909 → 59.888 | −0.04% |
| Moving tower, one owned/one awake | 52.026 → 49.633 | **−4.60%** | 52.712 → 49.311 | **−6.45%** |
| Eight-owned-body stress construction | 29.213 → 29.085 | −0.44% | 29.049 → 29.035 | −0.05% |
| Sleeping body, one owned/zero awake | 60.010 → 59.851 | −0.27% | 59.850 → 59.406 | −0.74% |

Owned-body count is not awake-body count. The stress records retain their actual
owned/awake cohorts; a whole-window rate can include changing awake counts.
The headless experiment records zero renderer callbacks and makes no display
FPS claim.

### Unresolved moving-tower decline

The tower median declines are retained as an unresolved limitation. Individual
pairs vary substantially and change sign:

| Recording / replicate | Baseline ticks/s | Candidate ticks/s | Change |
|---|---:|---:|---:|
| Off / 1 | 48.808 | 50.936 | +4.36% |
| Off / 2, reversed order | 55.244 | 48.331 | −12.51% |
| On / 1 | 54.603 | 47.329 | −13.32% |
| On / 2, reversed order | 50.820 | 51.294 | +0.93% |

Independent counter/source review found one owned/awake body, geometry revision
1 and 23 collision shapes in all eight tower windows, with approximately four
Rapier segments, three native snapshots, one full motion publication and three
compact receipts per semantic tick. Two baseline recording-on windows finish
with one physical interval ahead of the semantic boundary; the review retains
those exact boundary terms. Several windows in both source populations record
a transient motion-permit refusal after the bounded OwnerBusy retry window;
all finish with a successful last permit and no persistent Held error.

Slower samples show broader native service, Main capture/physics and pump-wait
variation. No edit mutation or collision reconstruction ran in these windows.
The candidate does add seven native metric fields and a small inactive edit
service/diagnostic check. Their independent cost was not isolated. Scheduling
variation and evolving physical state over equal wall-time windows are plausible
contributors, not an established explanation. This small descriptive campaign
proves neither statistical equivalence nor a causal performance regression.
It does not justify dismissing the decline as noise or claiming no inactive
editing overhead. Physical owner measurement remains necessary.

## Input, worker and Main installation timing

The final delivery ledger links action-bound stage summaries for Linux,
Windows source execution and both actual extracted-package runs. They distinguish
input-to-admission, queueing, native owner service, native phase counters,
receipt delivery and coherent Main presentation. The separate geometry-install
reviews join a changed native revision to the actual installed Rapier geometry.
Whole fixture durations include scene setup and deliberate waits and are not
reported as edit latency. Nested phase spans are not added as independent costs.

Continued freehand service is throttled near 30 admissions/s; fresh presses and
explicit Slice commits can request immediate service. Every route still allows
only one outstanding transaction. The footprint caps bound requested work but
do not guarantee a fixed wall-clock latency on every machine. The exact stage
and instrumentation limits are in [performance-method.md](performance-method.md).

## Recomputing the retained idle summary

From the repository root, the portable summary reader validates all 40 retained
raw hashes, source/runtime custody, workload controls and rate calculations:

```sh
python3 docs/audits/objectshard-m4-live-edit-20261128/performance-observers/summarize_matched_throughput.py \
  docs/audits/objectshard-m4-live-edit-20261128/performance-raw \
  /tmp/objectshard-live-edit-throughput-review.json \
  --custody docs/audits/objectshard-m4-live-edit-20261128/matched-idle-custody.json
```

The new review timestamp changes its output hash; the comparisons and validated
raw identities must agree. The independently retained `review_final_throughput.py`
is the exact historical reader used for the source/counter review and contains
the original execution-environment paths. It is retained for auditability, not
presented as a portable one-command rerun of the application experiment.
