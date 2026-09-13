---
title: Profiling, observability, and performance
document-kind: runbook
canonical-for: [performance-measurement, metric-interpretation]
status: Current
scope: Current native/Godot observations, benchmark procedure, metric boundaries, and unimplemented production telemetry
last-reviewed: 2026-09-09
related-documents: [configuration-and-capacity-budgets.md, web-threading.md, testing-validation-and-replay.md, ../reference/validation-evidence.md, ../audits/2026-09-08-performance-history.md]
---

# Profiling, observability, and performance

**Current:** native/Godot counters and isolated worker benchmarks exist.
Their numbers must be attributed to the actual fixture, revision/artifact,
platform, profile, and measurement boundary. No universal 60 FPS, production
worker optimum, representative GPU timing, or complete per-stage profiler is
established.

This is the measurement/interpretation procedure. Current evidence belongs to
the [validation ledger](../reference/validation-evidence.md). Original hosted
2026-08-27/28 and local 2026-09-08 timing tables are preserved verbatim in the
[historical performance archive](../audits/2026-09-08-performance-history.md),
excluded from ordinary Current-behavior retrieval.

## Current observations and their limits

| Observation/source | What it measures | What it does not establish |
|---|---|---|
| [World::TickStats](../../native/include/cybersand/world.hpp) | Visited/moved cells, activity, scheduled cores, per-phase jobs, deferred events, owned chunk/temperature allocation counts | Per-worker utilization, barrier time, all process allocations |
| [World::resident_cell_bytes](../../native/src/world.cpp) | Cell, optional-temperature, and activity capacity bytes | Hash-map/node overhead, all scheduler/snapshot buffers, total RSS |
| [RenderSnapshotExchange](../../native/include/cybersand/render_snapshot.hpp) | Required/capacity/high-water patch and byte counts; pressure/failure counts | GPU upload bytes or renderer memory |
| [Desktop worker](../../godot/scripts/simulation_worker.gd) | Worker/cellular/snapshot-copy timing, snapshot age, overruns | Synchronous Web timing semantics |
| [Desktop controller](../../godot/scripts/main.gd) | FPS, texture update, dirty patch count/KiB, collider timing, body observations, Rapier step/flush | Stable telemetry schema, isolated GPU frame time |
| [Web controller](../../godot/scripts/web_demo_controller.gd) | Native tick/upload and profile observations | Independent asynchronous simulation/render owner |

“Moved cells” counts successful updates and can include reactions/state changes;
it is not a conserved quantity or physical mass. Native facade counters with
fallback-like names are not automatically equivalent to fallback activity
metrics.

## Current benchmark entry points

[native/bench/benchmark.cpp](../../native/bench/benchmark.cpp) accepts dimensions,
ticks, chunk size, dense/sparse scenario, backend, worker count and preallocated/
lazy mode. It reports aggregate means/work/memory and state/content hashes.
Serial and phased backends can differ in traversal and interest semantics;
compare behavior deliberately rather than requiring accidental cross-backend
byte equality.

[CyberWorkerBenchmark](../../godot/scripts/worker_benchmark.gd) powers the Web
Performance menu and local `dev.cmd benchmark` / `stress-test`. The
[Web runbook](web-threading.md#reference-benchmark-and-parity-checks) owns exact
fixture sizes, counts, warmup, cancellation, and report paths.

These temporary Sand/Water worlds measure native tick work. Test frame
intervals include menu/scheduling overhead and are not gameplay FPS. Their
exported-level hashes do not cover complete scheduler or Rapier replay.

## Run a useful comparison

1. Record [source/artifact identity](source-checkpoint-and-recovery.md), platform,
   tool versions, profile, logical-thread report, actual worker count, and whether
   the tested binary was rebuilt.
2. Freeze the geometry, material/input sequence, tick count, warmup, cadence,
   view/margins, preallocation and presentation options. Define exactly what
   current and 2× fixtures mean.
3. Establish correctness first: the relevant hash at matching ticks, exact
   conserved quantities, and required collision/lifetime checks.
4. Repeat comparable runs, preferably interleaved with the known baseline.
   Keep mean, p95, maximum, work counts, memory/pressure, and environment caveats.
5. Profile simulation, bridge copies, collider extraction/processing, texture
   update, and shader/glow cost separately. Set acceptance thresholds from
   representative hardware and preserve raw failures/outliers.

Timings are observations, not hidden authoritative inputs. Auto is a fixed
policy; benchmark results do not retune it. No selectable strict runtime
fidelity mode exists.

## Avoid common misreadings

| Pattern | Next investigation |
|---|---|
| One core busy, others idle | Phase job count versus dispatch threshold; a persistent pool can intentionally run sparse phases serially |
| Small dirty patch KiB but low FPS | Full GPU texture update, synchronization, palette/glow, or unrelated presentation work |
| Large collider peak, small Rapier step | Separate geometry extraction, packet copy/validation, and indivisible collider rebuild |
| High snapshot pressure/age | Consumer lag and retained dirty payload |
| Material appears still after camera return | Check failure status and selected cores against the [pause/re-entry contract](../systems/world-storage-and-interest-region.md#interest-filtering-and-re-entry); retained offscreen activity is not selected work |
| Active work never settles | Equivalent state changes, wake feedback, or genuine lifecycle work |
| Persistent unresolved body pixels | Bounded ejection exhausted, stale samples, or dense surroundings |
| Visually moving surface with stable content | Presentation-time shader motion; inspect authority before changing simulation |

The collider consumer's 32-chunk/750 µs limits are checked between chunks and
exclude extraction/packet handling; one chunk may exceed the time budget.
`ImageTexture.update` still uploads the full 2,097,152-byte RG8 image for a
changed native publication. Dirty bridge bytes cannot substitute for that cost.

## Planned observability and acceptance

**Planned:** planning/preparation/execution/barrier/merge/publication stage time,
per-worker utilization, comprehensive allocator profiling, process memory
breakdown, actual GPU upload bytes and shader/glow GPU time, stable aggregation
and reset/export APIs.

**Approved:** pair each high-water mark with capacity, units, interval, and
fixture identity. Preserve exact fixture/conservation/collision comparisons
under any bounded gameplay approximation. A full mixed-material rendering/
coupling load and target-hardware GPU inspection remain distinct from the
isolated worker reference test.

## Where are interaction-specific measurements?

Use the opt-in [physics measurement runbook](physics-characterisation.md) and
[dated baseline](../audits/2026-09-09-physics-characterisation.md) for bounded
ordered material counters, Water mass, body impulses, sample ages and depth plots.
Tick and pre-tick coupling p50/p95/max have explicitly different scopes; snapshots
and result application are outside the latter interval. Concurrent development
workload and instrumented timings are not production frame-time acceptance.
