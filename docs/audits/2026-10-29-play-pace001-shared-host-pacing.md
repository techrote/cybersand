---
title: PLAY-PACE-001 shared-host pacing candidate
status: Planned
document-kind: evidence
scope: Unexecuted source candidate for fixed-configuration pacing measurements on the accepted composable desktop gameplay host
canonical-for: []
last-reviewed: 2026-10-29
related-documents: [../systems/player-control-playground.md, ../architecture/simulation-tick-and-threading.md, ../PERFORMANCE.md, ../operations/local-build-and-validation.md]
---

# PLAY-PACE-001 shared-host pacing candidate

## Status and source identity

This is an **unexecuted candidate**, not performance evidence and not a release
acceptance. It starts from accepted `main`
`aac0feb65e2268b74975892ce1df81e04e1a7e40`, tree
`a2ddee9e54a570d56e6e9b68285281c1921b8f0f`.

The candidate adds one shared Godot test helper and five automatically discovered
rig wrappers. It changes no native source, GDExtension runtime, material law,
solver-family admission/default, gameplay owner, Rapier ownership, CI policy or
specialist fixture. This avoids overlapping the separate source-sensitive native
copy work in PRs #290/#295.

## Question

For each accepted mechanical SetP rig on the exact authored
`playground/player-course`, what distributions are observed for:

- Main process and physics callback intervals and callback duration;
- completed native and main-thread Rapier rates over the same wall interval;
- immutable worker-publication and retained render-packet age;
- full `consume_worker_snapshot()` callback duration;
- worker step and snapshot-copy duration from source-bound publications;
- snapshot coalescing, scheduler jobs/phases, worker capacity and overruns?

The result is descriptive. No timing threshold is converted into a pass/fail
criterion.

## Fixture

`godot/tests/play_pace001_shared_host_case.gd` constructs the real
`main.tscn`, existing `CyberSimulationWorker`, authored course and one actual
main-thread Rapier SetP session. The five wrappers select:

1. `stuntbuggy`;
2. `trialsbike`;
3. `acrobat`;
4. `arcadelander`;
5. `jetbarrel`.

Each fresh process:

1. admits the course through the ordinary MicroScenario selector;
2. constructs the human rig through the ordinary F5 SetP API;
3. waits for actor, terrain and neutral-input readiness;
4. retains actor epoch, World generation, course recipe hash and applied liquid
   policy/receipt;
5. samples until at least 120 completed native ticks and 120 completed Rapier
   steps, under held W+D input, one D→A reversal and periodic real Space
   press/release edges delivered through `Input.parse_input_event`;
6. emits one `PLAY_PACE001_RESULT` JSON line containing summaries and raw arrays;
7. closes the actual scene and requires the exclusive worker to join and the
   Rapier session to retire.

The harness subclasses Main only for observation. `super._process`,
`super._physics_process` and `super.consume_worker_snapshot` execute unchanged.
No World reference, mutable cell storage or Rapier object crosses to the
simulation worker or native pool.

## Measurement definitions

- **Process/physics interval:** wall time between successive actual callback
  entries while measurement is active.
- **Callback duration:** wall time around the unchanged inherited callback.
- **Snapshot age:** callback completion time minus the copied snapshot's
  `published_usec`.
- **Render snapshot age:** callback completion time minus the immutable retained
  render packet's `render_generated_usec`.
- **Snapshot consume callback:** total inherited
  `consume_worker_snapshot()` duration, including its ordinary presentation
  work. It is **not** an isolated mutex-wait measurement.
- **Native/Rapier completed Hz:** completed tick/step delta divided by the same
  measured wall interval.
- **Coalesced native ticks:** positive completed-tick gaps between worker
  publications. This does not imply loss of authoritative native ticks.

Raw values remain in the result line for independent reduction. Reported
scheduler job/phase maxima and configured worker capacity do not establish
concurrent execution or causal speedup.

## Assertions

The candidate asserts only fixture integrity and bounded completion:

- both native and Rapier clocks reach the 120-tick target;
- process, physics, snapshot-age, worker-step and consume distributions are
  populated;
- actor epoch, World generation, selected rig, authored map, liquid policy and
  construction receipt remain unchanged;
- the worker does not enter failure quarantine;
- scene exit joins the worker and retires Rapier.

There is no FPS, latency, p95/p99, snapshot-age or worker-count acceptance
threshold.

## Explicit exclusions

This candidate does **not** establish:

- interactive or rendered desktop FPS;
- human-perceived control/camera/contact quality;
- physical gamepad, device disconnect/reconnect or complete focus behavior;
- isolated main-thread mutex wait attribution;
- a deliberately slow native tick;
- shutdown while native phase jobs are demonstrably outstanding;
- pool-thread creation, simultaneous execution or per-worker utilization;
- ordinary Linux desktop equivalence from a hosted/headless result;
- Web behavior;
- #266, #268, #269, #270 or parent #263 completion.

The operator checklist in issue #270 remains unexecuted. The next distinct
lifecycle slice still needs source-bound slow-native progress and resource
retirement during directly observed outstanding native phase jobs, coordinated
with current native-source ownership.

## Required qualification

Before any acceptance or merge claim:

1. run exact-head Documentation/provenance, Native and Windows/Linux
   GDExtension/Godot workflows;
2. verify five `PLAY_PACE001_RESULT` records per OS with zero fixture failures,
   original raw logs and exact tested checkout/tree/runtime identities;
3. retain any parse, timeout, import, runtime or measurement failure without
   retry masking;
4. independently review source, artifacts and reductions;
5. reconcile the result into #266/#270 and canonical performance/player docs
   only at its actual evidence scope.

No local Godot, native build, documentation checker or hosted execution is
claimed by this source publication.
