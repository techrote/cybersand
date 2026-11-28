---
title: ObjectShard live-edit performance method and limits
status: Historical record
document-kind: audit
scope: Source-bound native batching, action timing and matched idle comparison interpretation
canonical-for: []
last-reviewed: 2026-11-28
related-documents: [../../research/objectshard-m4-workbench.md]
---

# Live-edit performance interpretation

Application inputs: `ba6d8de45bd4d38717d92bdece7153bff115c0f0`.

## Native transaction cost

The matched native experiment compares the existing exact-cell operation with
one batch that removes the same cells. Both paths acquire current witnesses and
acknowledge native geometry. They must finish with identical surviving material,
collider digest, mass, centre of mass and inertia. Fixture construction is outside
the timed region. The experiment does not measure worker queueing, Main Rapier
installation, rendering or the physical owner's machine.

At the validated native boundary, N requested witnesses are checked before
selection, sorted by cell, deduplicated and filtered. The sorting term is
O(N log N), with N bounded to 4,096. Each owner whose structural cells are removed
preflights one exact rectangle cover and rebuilds connectivity, mass, centre of mass, inertia
and geometry once. The cover and material scans are linear in the carrier's
bounding-box area; connectivity visits surviving structural cells and their four
neighbours. This matters for sparse, widely eroded carriers: low occupied count
does not by itself make a large carrier cheap. Collider installation depends on
the retained rectangle count; shape capacity is checked before mutation.
Visible target acquisition and ordinary terrain ownership checks also depend on
the bounded owner population. Later child reservations and transfers add work
when disconnected islands become separate physical owners; their costs remain
distinct from the single affected parent's immediate reconstruction.

The matched benchmark records fixed 2,304-cell material and 2,500-slot carrier
bounds while varying requested/removed cells and cut geometry. It demonstrates
removal of per-cell reconstruction amplification; it is not an exhaustive
empirical scaling law over all carrier dimensions, fragmentation patterns or
owner populations. The complete regression/budget gates cover sparse and
capacity cases separately. A cut can report several disconnected islands before
the retained child-transfer protocol turns them into separate physical owners;
those two counts must not be conflated.

One batch targets one owner. Cross-owner freehand strokes make a bounded sequence
of transactions and reacquire visible ownership between them. Main permits at
most one outstanding edit. Continued strokes are throttled to approximately 30
admissions/s; fresh presses and explicit Slice commits can bypass that interval.
Every route retains the one-outstanding-edit bound, a radius cap of 24,
4,096 unique cells, 65,536 footprint probes and 2,048 sweep steps. A no-op does
not rebuild geometry; ignition changes combustion state without rebuilding the
collider. These limits bound work; they do not promise a particular
wall-clock latency on every machine.

## Editing latency and physical installation

The final per-action ledgers join authentic admitted, receipt and presented
events by action/session identity. They report input-to-admission, worker queue,
native owner service, native target/mutation/combined geometry, Main receipt
delivery and admission-to-publication spans separately. Nested and overlapping
spans must not be summed. Native target, mutation and geometry counters measure
selected coordinator and registry regions. They exclude facade normalization,
visible target projection, marshalling, request fingerprinting and some
post-debit bookkeeping; broader owner-service and end-to-end spans must be
consulted for those costs. Native geometry timing includes exact-cover preflight,
connectivity, mass and shape reconstruction; it does not isolate each component.
A separate owner/body-generation/geometry-revision join establishes the measured
Main Rapier installation event and the actual installed shape/mass state.

Whole-fixture runtime includes scene preparation, prolonged simulation,
settling and observation waits. It is not edit latency. Main publication means
the coherent authoritative result was installed for presentation; it does not
measure a physical monitor's display completion. Hosted ANGLE/software-renderer
results are not TITAN RTX performance.

## Idle comparison

The pinned idle comparison alternates baseline and candidate execution on the
same host, one process at a time, with the same Godot/Rapier, authored rectangles,
common throughput fixture, camera and callback limit. It has five workloads,
recording off/on and two six-second samples per source and workload: 40 windows.
Source/native identities are captured before and after, and every actual raw
receipt must pass its material, physical, ownership and requested cohort checks.
Owned and simultaneously awake bodies are retained separately in every window.

These short windows are descriptive. Their medians and individual samples do
not establish statistical equivalence, long-session tails or physical owner
performance. Recording overhead is observable as its own arm; it is not hidden
by mixing recording-on and recording-off results. The earlier development
comparison remains historical and is not substituted for this pinned run.
