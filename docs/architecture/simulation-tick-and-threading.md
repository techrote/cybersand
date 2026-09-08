---
title: Simulation tick and threading
status: Approved design
scope: Current loop and rigid-body bridge, four-phase in-place backend, retained buffered backend, worker restrictions, bounded approximate overload, deterministic coordination, and reconfiguration boundary
keywords: [fixed timestep, worker pool, rigid body mask, phased in-place, four barriers, buffered backend, overload, temporal sampling]
related-documents: [data-ownership-and-lifetimes.md, determinism-and-boundary-transfers.md, rigid-body-and-cellular-coupling.md, ../operations/profiling-observability-and-performance.md]
last-reviewed: 2026-09-08
implementation-state: Desktop uses an asynchronous Godot pacing owner and main-thread Rapier; Web synchronously owns ticks on the main thread. Native World dispatches eligible phases to persistent workers; compatibility Web is serial.
---

# Simulation tick and threading

Evidence scope (2026-09-08): **Current** below describes inspected source in the
reconstructed local snapshot, not a verified Git HEAD or an all-platform test pass.
See the [documentation audit](../audits/2026-09-08-documentation-audit.md) for
source identity and dated validation; [M11 audit records](../audits/m11/README.md)
retain historical scope. **Approved design** means Approved direction; Planned,
Deferred, and Rejected statements do not claim implementation.

## At a glance

- Purpose: define when data may change and where parallelism is allowed.
- **Current**: Desktop CyberSimulationWorker advances the selected world at a nominal fixed interval on one Godot Thread while rendering consumes the newest immutable snapshot independently.
- **Current**: packed RigidBody2D samples are rasterized into a separate worker obstacle mask before character and cellular work.
- **Current**: the main thread manually steps Rapier2D once per Godot physics callback and reads active transforms in a batch before copying body state to the worker.
- **Current**: desktop native and Web adapters call native World, which runs four deterministic parity phases through a persistent worker pool.
- **Current**: a barrier separates every native in-place phase.
- **Current**: worker completion order does not change tested authoritative state hashes.
- **Current**: accepted explosion commands commit before active-work gathering, and immutable snapshots can be published after a completed tick.
- **Planned**: active-only buffered jobs remain a comparison/fallback and field-specific backend.
- **Current**: eligible native transport runs each tick; secondary interactions use fixed spatially staggered 2/4/8/120-tick lanes. Sleeping and interest rejection eliminate work; shader interpolation is presentation-only.
- Unresolved: native/gameplay fidelity controls, queue pressure, and missed-deadline thresholds are not approved.

## Search anchors

fixed tick sequence, thread owns simulation, worker stage, barrier, overload policy, tick-boundary command, safe reconfiguration

## Current desktop worker loop

Repository evidence: [desktop worker](../../godot/scripts/simulation_worker.gd),
[native adapter](../../godot/native_extension/cyber_native_cell_world.cpp), and
[Web controller](../../godot/scripts/web_demo_controller.gd).

- CyberSimulationWorker owns one Thread and one Mutex.
- TICK_INTERVAL_USEC is 16667.
- MAX_BACKLOG_TICKS is 3.
- Frame inputs and generic material-emission commands are copied or drained under the mutex; the prototype paint UI is one producer.
- Character movement and the selected world's `simulation_tick` execute serially on the pacing owner; native `simulation_tick` internally dispatches phased cell jobs.
- The native bridge rebuilds a separate rectangle occupancy field from packed body samples, reconciles moved-body overlaps, and publishes impulses without accessing live physics objects.
- Native publication accumulates dirty RG8 patches and deep-copies each changed publication generation; full copies are explicit recovery or GDScript fallback paths.
- Godot main.gd consumes the latest snapshot and uploads changed data.

The desktop pacing thread is separate from native cellular workers: World can
parallelize eligible phase jobs while the main thread renders. When lateness
exceeds three tick intervals, the desktop loop increments its overrun counter
and resets the next wall-clock deadline; it does not skip World tick indices.
The desktop loop currently ignores the boolean returned by native
`simulation_tick()` (its snapshot exposes failure telemetry), whereas the Web
controller pauses and reports failure.
That failure-policy difference remains unresolved for foundational work.

### Current Web owner

`web_demo_controller.gd::_physics_process` owns native calls synchronously on
Godot's main thread. Compatibility uses one cellular worker; threaded Web uses
the same native phase pool and Auto 2/4/6 policy as the desktop adapter. The
callback waits for native completion. Publication has a separate cadence but
long ticks can block rendering; asynchronous desktop ownership is not present.

Web first checks menu/focus/pause and pending terrain colliders, applies the
previous cellular result, steps Rapier, packs body samples and builds the mask,
then ticks cells and advances the sampled character at 1/60 s. Desktop advances
the character before its cellular tick. The two controller schedules are not
claimed equivalent. Paused Web still permits painting before the pause guard.
Web native-load failure is fatal; it does not select the GDScript fallback.

### Current Godot rigid-body stage

The runnable proof does not remove and restore rigid-body material pixels. A
body is an independent Rapier-backed RigidBody2D. On each unpaused physics
callback, the main-thread bridge applies the newest cellular response, calls
Rapier `space_step`, batch-reads active transforms, flushes once, and copies
authoritative body state to the worker. The worker reconciles a bounded swept
rectangle for displacement, then retains only the newest endpoint in
`rigid_body_occupancy`. Material and the sampled character read that mask as
solid; impact, boundary pressure, correction, and diagnostics publish in the
next immutable worker snapshot.

This desktop stage remains intentionally asynchronous and a cellular result can be one
or more body samples old under load. Sample serials prevent duplicate application;
the bounded sweep covers ordinary skipped translations without blocking the
render thread on the cellular worker.

## Current native scheduler

Repository evidence: [World scheduler](../../native/src/world.cpp),
[geometry](../../native/src/scheduler_geometry.cpp), and
[regression fixtures](../../native/tests/test_world.cpp).

- WorldConfig selects SerialInPlace or PhasedInPlace and a worker count.
- The default hierarchy is 128×128 chunks, 32×32 activity blocks, and 64×64 scheduling cores.
- Global core-coordinate parity assigns each core to one of four phases.
- The first phase rotates by tick; a complete barrier separates passes.
- Each worker scans bottom-up with deterministic alternating horizontal order.
- Job-local dirty/activity/non-empty effects merge after the barrier in sorted core order.
- No worker allocates chunks; the coordinator prepares the write domain before dispatch.
- The coordinator applies accepted external explosions in enqueue order after resetting per-tick flags and before gathering active work.
- Single/four-worker complete-material fixtures compare exact state hashes. Passing sanitizer runs belong to the dated historical M11 evidence, not an unexecuted current Windows/Web sanitizer run.

## Approved tick sequence

The sequence is a design contract. Exact function names and C++ signatures are undecided.

| Stage | Coordinator action | Reads | Writes | Required barrier |
|---|---|---|---|---|
| 1. Tick boundary | Establish the next fixed tick and latch eligible commands/configuration requests | Queued inputs and committed metadata | Tick-local input state | All prior tick work complete |
| 2. Reconfiguration check | If approved and required, enter safe capacity/interest reconfiguration | Requested region, current capacities, memory observations | Bounded resources and configuration only while drained | No worker holds affected views |
| 3. Activity and work planning | Select active work and construct deterministic jobs for the selected backend | Committed metadata, activity, interest region | Bounded task/deferred/buffer assignments | Plan complete before dispatch |
| 4A. Phased cellular execution | For phases 0–3, dispatch non-overlapping in-place jobs and wait at a barrier after each phase | Authoritative cells, immutable MaterialRules, tick inputs | Phase-owned cells and local observations | Every job in a phase completes before the next |
| 4B. Buffered execution | When selected for a backend or field, dispatch isolated-output jobs, then deterministically merge transfers | Immutable current state and neighbourhood views | Active next/output state, transfers, observations | Execution and merge complete before commit |
| 5. Deferred event resolution | Apply bounded long-range or structural events in canonical order | Completed cell/field stages and deferred records | Authoritative structural state, wake/dirty observations | No worker retains invalidated views |
| 6. Authoritative completion | Validate invariants and finalize activity, wake, dirty, and result state | Selected backend result | Committed metadata and immutable result staging | Tick state is whole before publication |
| 7. Publication | Prepare immutable gameplay results and dirty render snapshots | Committed state and dirty metadata | Bounded publication storage only | Publication data frozen before exposure |
| 8. Tick accounting | Record timing, counts, utilization, memory, high-water, overflow, and replay hash | Stage observations | Metrics only | None beyond completed tick |

## Stage-specific write restrictions

Current `World::tick` implements a specialized part of stage 1: pending
ExplosionCommands commit in enqueue order before active work is gathered.
Their writes carry the new update epoch, so generated Fire/Stone begin ordinary
material execution on the following tick. Current snapshot publication is an
explicit post-tick caller operation rather than automatic work inside
`World::tick`.

- Phased jobs may write authoritative cells only inside their current exclusive write domain.
- Two phased jobs in the same phase never have overlapping write domains.
- Buffered jobs never write committed current state or another job's output.
- Ordinary local movement is not forced through transfer storage in the phased backend.
- Long-range and structural effects do not bypass deferred-event resolution.
- Structural WorldStorage changes do not occur while worker views exist.
- RenderBridge and GameplayBridge never run authoritative material rules.

## Worker pool requirements

### Current runnable native implementation

- Workers persist across ticks; no thread-per-tick or thread-per-material creation.
- Activity granularity is 32×32 and scheduling cores are 64×64 by default.
- Jobs execute World methods through internal World/job-effect pointers with runtime write-domain checks; a type-enforced restricted RuleContext is Planned.
- Jobs do not depend on Godot runtime objects.
- Workers write metrics into bounded scheduler-provided observations or counters that do not alter simulation ordering.
- Phase job counts are observable; per-worker utilization and barrier wait are still **Planned**.

### Unresolved

- Broader platform binaries and minimum-spec tuning. Current Auto chooses 2/4/6
  workers at reported logical-processor thresholds 4 and 12, per owner direction
  on 2026-09-08. This startup heuristic is not runtime adaptation or CPU affinity.
- The Current pool distributes jobs using an atomic next-job index; whether to replace that scheduling policy after profiling is unresolved.
- CPU-affinity or NUMA policy.

These may be selected during implementation only with deterministic tests and documented capacity behavior.

## Fixed-timestep requirements

- Simulation ticks are independent of render frames.
- A gameplay command is applied only at an identified tick boundary.
- Interest-region and capacity changes are not applied halfway through a tick.
- Replay uses the same command sequence, configuration, material definitions, initial state, and tick count.
- Wall-clock timestamps do not influence authoritative rules.

The current runnable sandbox uses 60 Hz pacing; a future serialized tick-rate policy remains a separate decision.

## Overload policy

### Current

CyberSimulationWorker has a maximum backlog constant. The preferred native
runtime keeps eligible local transport at full cadence and eliminates work by
sleeping quiet 32×32 activity blocks and excluding scheduling cores outside the
configured camera margin. Rendering may interpolate the two latest immutable
snapshots, but that does not skip collision or material ticks. The older script
world retains a serial sparse-flight fallback for unsupported native platforms.

The native snapshot exchange has a narrower Current pressure rule: publication
never blocks; it returns Backpressure when every slot is leased or
CapacityExceeded when one snapshot cannot fit, and it leaves dirty state intact.
This does not define command/backlog or live-reconfiguration policy.

### Approved constraints

An eventual policy must:

- keep authoritative ticks whole;
- report measured tick time and backlog;
- never clip the interest region silently;
- never allocate hidden capacity in the hot path;
- never skip an authoritative transfer silently;
- preserve race-free ownership and strict-mode replay for a fixed strict policy;
- identify any gameplay approximation policy and fidelity tier explicitly;
- distinguish temporary CPU overload from capacity exhaustion.

### Ambiguous decisions

The project has approved bounded temporal approximation in principle through
ADR-008. Exact native thresholds, hysteresis, whether overloaded gameplay slows
simulation wall-clock time, and command-pressure responses remain unresolved.
Rendering must not pause merely because a worker misses its interval; it may
repeat the newest immutable snapshot and expose its age.

## Safe reconfiguration transition

**Approved design**: capacity growth occurs only at a tick boundary or loading transition.

Required transition properties:

1. Requested interest region and derived capacity need are measured.
2. Existing work completes or is prevented from starting.
3. No worker retains a view into resources being replaced.
4. New capacity is allocated explicitly.
5. current/next and optional-field mappings are rebuilt consistently.
6. diagnostics record old capacity, requested capacity, new capacity, time, and memory effect.
7. simulation resumes on the next whole tick.

The exact state names, API, and failure result are not yet approved.

## Strict and gameplay consistency boundaries

Parallel execution may change:

- when a worker finishes;
- per-worker busy/idle measurements;
- wall-clock stage duration.

Approved strict validation requirements must not change:

- job membership and phase assignment for the same tick inputs;
- selected backend semantics, phase order, scan order, and deterministic random inputs;
- transfer/deferred-event contents and resolution where applicable;
- committed authoritative state;
- wake/dirty decisions derived from that state;
- deterministic replay hash.

No general strict/gameplay mode switch exists in WorldConfig. Existing exact
fixtures exercise the compiled native policy, including its staggered secondary
lanes; see [hash and replay limits](determinism-and-boundary-transfers.md#replay-state-coverage).

An Approved future gameplay policy may change fine distant timing and stochastic choices according
to an explicit fidelity policy. It still may not make memory races, worker
completion order, silent loss, or known collision occupancy part of the result.

## Related decisions

- [ADR-002](../decisions/ADR-002-double-buffered-tile-jobs.md)
- [ADR-004](../decisions/ADR-004-interest-region-and-reconfiguration.md)
- [Testing and replay](../operations/testing-validation-and-replay.md)
- [ADR-007](../decisions/ADR-007-rigid-body-cellular-coupling.md)
- [ADR-008](../decisions/ADR-008-bounded-approximate-fidelity.md)
