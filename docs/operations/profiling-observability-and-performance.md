---
title: Profiling, observability, and performance
status: Current
scope: Current counters and benchmarks, adaptive gameplay fidelity, required production observations, fixtures, interpretation, acceptance policy, and non-authoritative timing
keywords: [tick time, active chunks, adaptive stride, rigid body contacts, worker utilization, transfer high-water, snapshot high-water, dirty upload bytes, allocation count, memory]
related-documents: [configuration-and-capacity-budgets.md, testing-validation-and-replay.md, ../reference/status-and-roadmap.md]
last-reviewed: 2026-09-08
implementation-state: Native/Godot counters and local native/Web worker-reference fixtures exist. Historical hosted benchmarks and retained Windows/Chromium measurements are scoped below; representative GPU timing and production thresholds remain unverified.
---

# Profiling, observability, and performance

## At a glance

- Purpose: reveal where time and memory go before enlarging the simulation window.
- Scope: Current names refer to inspected source; every timing is limited to its dated fixture/platform. See [current source/validation audit](../audits/2026-09-08-documentation-audit.md), not the historical M11 identity, for this local snapshot.
- **Current**: the native benchmark compares serial/phased backends, worker counts, dense/sparse fixtures, and preallocated/lazy storage.
- **Current**: Godot displays FPS, worker/simulation/snapshot/upload timings, activity counts, and overruns.
- **Current**: Godot reports eligible/run/deferred blocks, adaptive stride, and rigid-body contact/displacement/unresolved counts.
- **Current**: Godot reports Rapier manual-step time, query-flush time, active body count, and cellular results applied in the status line.
- **Current**: Godot reports copied dirty render patch count and KiB separately from total texture-update time.
- **Current**: native TickStats exposes work, phase jobs, active/dirty chunks, and owned tick allocation events.
- **Current**: snapshot publication exposes required dirty patches/bytes, patch/byte high-water, backpressure, and capacity-failure counts.
- **Historical validation**: the m8 dense eight-worker benchmark median was 5.91 ms/tick versus m7's 7.06 ms/tick in five interleaved hosted runs; contention was high, so this is directional evidence rather than a portable guarantee.
- **Planned**: expose per-stage time, per-worker utilization/barrier wait, and high-water reset intervals.
- **Current**, source-accounted: m9 adds four common RG8 neighbour reads, increases the low-resolution emission kernel from 9 to 13 positions, and increases the additive composite from 1 to 13 filtered taps without another image or CPU payload.
- **Planned**: visually inspect and GPU-profile the expanded effects on representative target hardware.
- **Approved design**: strict validation keeps measurements out of outcomes; gameplay mode may select an explicit bounded fidelity policy without making thread timing a write owner.
- **Approved design**: acceptance criteria are set from reproducible current and 2× fixtures.
- Unresolved: production metric names, aggregation windows, reset behavior, thresholds, and export format.

## Search anchors

why FPS low, simulation stage timing, one core used, worker imbalance, high-water mark, allocator counter, memory use, dirty upload bytes

## Current native observations

[native/bench/benchmark.cpp](../../native/bench/benchmark.cpp) accepts dimensions, ticks, chunk size, dense/sparse
scenario, serial/phased backend, worker count, and preallocated/lazy allocation
mode. It reports mean tick time, visited/moved cells, scheduled cores, per-phase
jobs, resident cell bytes, tick allocations, committed deferred events, active
chunks, and both state/content hashes.

native World::tick returns TickStats with aggregate behavior. It does not yet
separate planning, domain preparation, job execution, barrier/merge, completion,
or publication timing and does not expose per-worker utilization.

The **Current** [worker_benchmark.gd](../../godot/scripts/worker_benchmark.gd)
fixture also backs the Web Performance menu and local `dev.cmd benchmark` /
`stress-test` commands. It compares 480²/960² Sand/Water level hashes and reports
native tick mean/p95/max, with ten warmup and 120 measured ticks per benchmark
case or 600 measured stress ticks. [Web threading](web-threading.md) owns the
dated Windows/Chromium results and limits; this is not a full rendering/coupling
stress benchmark or an exact scheduler/Rapier replay test. The retained 960²
Auto Web stress mean was 21.23 ms, so those results do not establish a 60 FPS
budget. Current Auto is a fixed 2/4/6 policy, not a benchmark-driven tuner.

Historical performance sections below preserve earlier comparisons. Their
primary context is the [M11 evidence index](../audits/m11/README.md); they are
not measurements rerun against today's DLL or source snapshot.

### 2026-08-27 hosted-container observations

These are checkpoint observations, not portable performance promises because
the hosted CPU identity and contention are not a frozen reference platform.
Every row used 512×512 dense cells or the named 1024×544 sparse fixture for 120
ticks with 128-cell chunks and an optimized LTO build.

| Fixture | Backend/workers | Allocation mode | Mean tick | Authoritative hash relation |
|---|---|---|---:|---|
| Dense 512×512 | Serial / 1 | preallocated | 13.40 ms | Behavioral comparison only; scan semantics differ |
| Dense 512×512 | Phased / 1 | preallocated | 12.87 ms | Same phased semantics |
| Dense 512×512 | Phased / 4 | preallocated | 5.05 ms | Exact state/content match with phased / 1 |
| Dense 512×512 | Phased / 8 | preallocated | 3.74 ms | Exact state/content match with phased / 1 |
| Sparse 1024×544 | Phased / 4 | preallocated | 0.86 ms | Four jobs per phase; below parallel threshold |

All preallocated rows reported zero tick-time chunk and temperature allocations.
The dense fixture exposed 18, 18, 17, and 17 jobs across its four phases. Eight
workers won this particular hosted run, unlike an earlier run in the same environment; that
variance reinforces that these numbers are observations rather than a worker
selection policy. The sparse fixture averaged four jobs per phase, below the
default dispatch threshold of eight, and intentionally stayed sequential.

### 2026-08-28 m6/m7 checkpoint comparison

Three interleaved default native benchmark runs compared the m6 checkpoint with
the m7 themed-material catalogue on the same hosted container. Both checkpoints
produced authoritative state hash `0x31407faccd6020d7` in every run.

| Checkpoint | Observed mean-tick range | Interpretation |
|---|---:|---|
| m6 rollback baseline | 17.79–18.90 ms | Hosted reference only |
| m7 themed materials | 17.90–18.56 ms | No measurable native simulation regression |

The ranges overlap and are smaller than ordinary hosted contention variance, so
they do not establish a speedup or a portable budget. The 41 inert themed solids
have radius-zero rule kernels; Oak Timber and Thatch reuse the existing bounded
combustion kernel. Their analytic surface detail runs in the presentation shader
and therefore does not add authoritative simulation work. A target-GPU profile
of mixed flair branches, HDR emission, and the half-resolution glow pass remains
required before setting a rendering acceptance threshold.

### 2026-08-28 m7/m8 temporal-fidelity comparison

Five interleaved 512×512 dense, 120-tick, phased/eight-worker runs compared the
m7 rollback archive with m8. Observed m8 means were 4.98, 5.40, 5.91, 6.02,
and 8.20 ms; m7 means were 6.17, 6.48, 7.06, 7.14, and 7.65 ms. The medians are
5.91 and 7.06 ms/tick respectively (about 16% lower for m8), though the ranges
overlap under hosted contention. State hashes differ by design because Smoke
now ages and culls.

The m7 Windows profile supplied with this checkpoint showed Process Time
65.26 ms alongside a 64.49 ms hard-collider peak, while Rapier itself reported
only about 0.06 ms. m8 changes collision extraction from 128×128 to 64×64
packets, reducing the indivisible rebuild area to one quarter. The budget still
stops only between packets, so this is a bounded-work design improvement, not a
claim that the target peak is eliminated. Repeat the same fragmented-hard-solid
scene on Windows and compare `collider peak` before accepting the fix.

### 2026-08-28 m8/m9 GPU-only presentation expansion

m9 does not change native simulation source, cell layout, render snapshot size,
palette size, four-texel program rows, or glow texture count. It binds the
already-current RG8 texture under one named sampler so helper functions can read
four nearest neighbours. The normal palette path therefore grows from six to
approximately ten texture fetches per displayed fragment; a snapshot transition
can evaluate old and new colour/relief paths. Selected material branches add
arithmetic/hash work but no sampler access.

The half-logical-resolution emission source grows from 9 to 13 positions, each
reading the existing world/program textures. The full-resolution additive glow
composite grows from 1 to 13 filtered reads. `G` remains the useful full glow
A/B control. These are deliberately GPU-biased costs, but the headless hosted
driver supplies shader compilation rather than representative GPU time. Record
GPU frame time at 1920×1080 with m8/m9 and `G` on/off before defining tiers.

`F3` hides the debug statistics label and causes `update_status()` to return
before building its formatted strings. Counters still update so restoring the
readout presents current data.

## Current Godot observations

[main.gd](../../godot/scripts/main.gd) and
[simulation_worker.gd](../../godot/scripts/simulation_worker.gd) expose desktop
proof metrics including:

- rendered FPS;
- total worker step time;
- age of the newest consumed worker snapshot;
- cellular simulation time;
- snapshot copy time;
- texture upload time;
- scanned, dormant, and moved cell counts;
- blocks run, frozen, or deferred;
- eligible blocks and the adaptive temporal stride;
- rigid-body contacts, displaced cells, and unresolved overlaps;
- Rapier manual-step time, query-flush time, active body count, and cellular result applications;
- worker overruns.

These are useful prototype evidence but are not a stable telemetry schema.
Web uses a synchronous controller and reports native tick/upload timings rather
than the desktop's asynchronous worker snapshot age; compare like measurements.

### Current wake-spike mitigation

The GDScript proof now addresses the observed single-digit slowdown in three
places:

1. Excess active 16×16 blocks are distributed across later worker ticks with a soft target of 12.
2. The 3×3 block area around gameplay interest remains full cadence.
3. Long-range liquid pressure checks perform eight changing deep samples rather than a deep sample for every candidate column, while still checking the traversed row for obstacles.

Long lateral moves wake only source/destination neighbourhoods. These changes
preserve the full material grid and avoid the topology cost of local 2×2 voxel
grouping. They are **Current** fallback behavior with dated Godot coverage in
[testing](testing-validation-and-replay.md). Their target-hardware frame-time behavior remains
**Ambiguous** because this checkpoint did not run a user-facing GPU profile.

The native `World::resident_cell_bytes()` and C API
`cybersand_world_resident_cell_bytes()` now expose material, temperature, and
activity metadata capacity bytes. This is a **Current** resident-payload metric;
it deliberately does not claim container/node overhead, task/transfer/snapshot
capacity, or total process memory.

`RenderSnapshotExchange` exposes configured slot/patch/byte capacities, patch
and byte high-water, Backpressure count, CapacityExceeded count, and every
publication's exact required patches/bytes. Required bytes are the packed
material/condition payload copied through the Current Godot adapter. Godot also
reports texture-update time, but `ImageTexture.update()` still submits the full
1024×1024 RG8 backing image; copied dirty bytes and GPU upload bytes must not be
conflated.

## Required production observations

Exact names and storage formats are intentionally undecided.

### Tick timing

- total simulation tick time;
- input/tick-latch time;
- work-planning time;
- TileJob execution time;
- deterministic transfer-merge time;
- authoritative commit time;
- snapshot preparation/publication time.

Timings are wall-clock observations and do not enter authoritative state.

### Work volume

- active storage chunk count;
- active worker tile count;
- active/scanned cell count where meaningful.

### Worker behavior

- worker utilization.

The utilization formula and aggregation window are not approved.

### Capacity and memory

- active-chunk use, capacity, and high-water;
- task-buffer use, capacity, and high-water;
- transfer-buffer use, capacity, and high-water;
- immutable snapshot slots/bytes use, capacity, and high-water;
- allocation count, including a hot-path allocation counter;
- total memory use, with enough separation to identify authoritative storage, active buffers, and snapshot/buffer reservations.

### Rendering

- dirty native/GDScript bridge bytes;
- CPU patch count and reconstruction time;
- actual GPU texture-upload bytes;
- palette/program/glow GPU time and downsample configuration.

### Correctness correlation

- deterministic replay hash for the completed tick or configured interval.

## High-water semantics

**Approved design**: a high-water mark is the maximum observed use within a clearly identified run or reset interval.

Every high-water report must be paired with:

- capacity;
- unit;
- observation interval;
- fixture/configuration identity.

Reset API and persistence are **Ambiguous**.

## Allocation observations

The allocation counter must distinguish normal tick hot-stage allocation from allocation performed during explicit loading or safe reconfiguration.

`reserve_region` and `reserve_temperature_region` perform explicit preparation.
The preallocated cross-chunk test and benchmark assert/report zero World-owned
chunk and temperature allocation events during normal ticks. This is not a
process-wide allocator hook, so standard-library or caller allocations require
separate profiling.

## Benchmark fixtures

| Fixture | Status | Purpose |
|---|---|---|
| Current interest region | **Approved design** | Baseline using the initial visible area plus 10%/20% simulation margin |
| 2× target interest region | **Approved design** | Exercise intended future dimensions and initial reservation planning |
| Dense water | **Current** behavioral fixture | Conservation, settling, heap prevention, activity, worker parity |
| Dense smoke | **Planned** dedicated fixture | Occupancy and wake stress |
| Mixed moving materials | **Current** complete-material replay; benchmark is **Planned** | Rule dispatch and interaction stress |
| Scheduling-edge and chunk-edge | **Current**, partial | Scheduler crossing, geometry overlap, Sand and optional temperature chunk crossing |
| Sustained spawn/paint | **Current** concept; fixture is **Approved design** | Command pressure, activity growth, dirty uploads |
| Mostly sleeping large world | **Approved design** | Verify stored scale does not imply simulation work |

Fixture seeds, dimensions, durations, hardware baselines, and acceptance thresholds must be versioned when approved.

## Interpreting common patterns

| Observation | Likely area |
|---|---|
| One worker saturated; other cores idle | Current serial worker or insufficient parallel job availability |
| TileJob stage scales poorly while workers are busy | Rule kernel, memory bandwidth, false sharing, or job granularity |
| Low utilization plus long barrier wait | Work imbalance or dependency/halo preparation |
| Transfer high-water near capacity | Excess cross-boundary activity, too-small reservation, or unstable material rule |
| Snapshot high-water near capacity | Render consumer lag or dirty payload pressure |
| Dirty bridge bytes near full region every tick | Dirty tracking, visual-state projection, or authoritative shimmer |
| Dirty bridge bytes small but render FPS low | Full GPU texture update, LUT/glow cost, synchronization, or unrelated presentation work |
| Active tiles remain high after settling | Wake feedback, equivalent-state changes, or sleep defect |
| Tick time stable but FPS low | Snapshot upload, Godot rendering, or unrelated presentation work |
| Memory grows during stable fixture | Hidden allocation, retained snapshots, or chunk/field lifecycle leak |
| Eligible blocks spike and adaptive stride rises | Region wake-up is being temporally distributed; inspect snapshot age and immediate-interest behavior |
| Alternating empty rows trail falling material | Movement epoch/source-vacancy rule, not a need for spatial coarsening |
| Body unresolved count remains high | Pixel ejection radius exhausted, stale/high-speed sample, or dense closed material around a body |

## Acceptance policy

Before each checkpoint:

1. freeze fixture and configuration;
2. record correctness invariants;
3. record required observations;
4. set an explicit acceptance criterion based on measured baseline and target hardware;
5. compare against the rollback checkpoint;
6. preserve exact fixture comparisons and all required conservation/collision invariants; define separate strict-mode measurements when that Planned runtime mode exists;
7. for gameplay approximation, record fidelity policy, snapshot age, visible artifacts, and rollback result.

This documentation does not invent numerical thresholds.

## Related decisions

- [ADR-002](../decisions/ADR-002-double-buffered-tile-jobs.md)
- [ADR-004](../decisions/ADR-004-interest-region-and-reconfiguration.md)
- [ADR-006](../decisions/ADR-006-gpu-compute-deferral.md)
- [ADR-007](../decisions/ADR-007-rigid-body-cellular-coupling.md)
- [ADR-008](../decisions/ADR-008-bounded-approximate-fidelity.md)
