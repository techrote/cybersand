---
title: PLAY Auto worker-matrix candidate and qualification plan
status: Current
document-kind: evidence
scope: Per-World 1/2/4/6/Auto reference construction, requested/resolved/actual readback, fixed-input parity, actual pool participation and explicit performance nonclaims
canonical-for: []
last-reviewed: 2026-10-27
related-documents: [../architecture/simulation-tick-and-threading.md, ../reference/configuration-reference.md, ../operations/local-build-and-validation.md, ../systems/player-control-playground.md]
---

# PLAY-AUTO-002 worker matrix — source candidate, 2026-10-27

This record supports [PLAY-COMP-AUTO #266](https://github.com/techrote/cybersand/issues/266)
and the parent [PLAY epic #263](https://github.com/techrote/cybersand/issues/263).
It is a source and qualification plan, not execution evidence, a speedup claim or
release acceptance.

## Accepted prerequisite and remaining question

[PR #277](https://github.com/techrote/cybersand/pull/277) is accepted on main
`c9ebe39c6cab086b7f7207ee3d80a6de2cb21f59`. Its actual Windows and Linux
shared-course fixture passed 15 assertions with zero failures on each platform.
Both reported requested Auto `0`, four logical processors and four actual worker
slots, but only one scheduler job and zero parallel phases. That result qualifies
production startup policy/capacity readback. It does **not** show that a workload
was eligible for parallel work, that multiple pool workers claimed tasks, or that
additional workers improved elapsed time.

The next bounded question is therefore narrower than final performance
qualification: on the existing native phased backend, can independently
constructed reference Worlds preserve fixed-input parity across requested
1/2/4/6/Auto policies, report the complete requested → resolved → actual chain,
and demonstrate at least one genuinely participating multiworker workload?

## Source defect removed from the reference apparatus

Before this candidate, `CyberWorkerBenchmark.sample()` temporarily rewrote
`ProjectSettings["cybersand/native_worker_threads"]`, instantiated a World and
then restored the setting. Even though the mutation was short-lived, it was a
process-wide control channel and was unsuitable evidence for independently
owned Worlds that may coexist. It also collapsed requested and resolved counts
before execution, omitted Auto from the normal matrix and reduced scheduler
activity to one aggregate phase count.

Code commit
[`6c5ce74f77088a1d3dc0827ff5240114529bca95`](https://github.com/techrote/cybersand/commit/6c5ce74f77088a1d3dc0827ff5240114529bca95)
replaces that path with a fresh reference World per row:

1. Read the native logical-processor count and exact static Auto resolver.
2. Resolve an explicit 1/2/4/6 request with the same logical-processor and
   32-worker ceiling used by normal native construction; resolve `0` with the
   native Auto policy. A non-threaded Web runtime truthfully resolves to one.
3. Instantiate an otherwise unshared native World and call its explicit
   `diagnostic_reset({"workers": resolved, "telemetry": false})` construction
   boundary. Disabling body telemetry keeps the measured material workload
   aligned with ordinary phased construction.
4. Rebuild the ordinary deterministic Sand/Water fixture through
   `CyberDemoBridge.build_world()`, which copies the World configuration while
   restoring ordinary default material and liquid policies.
5. Run fixed warm-up and measured ticks, stop the timing interval, separately
   export/hash the terminal level, discard the World and its persistent pool,
   then proceed to the next row.

The project setting is read before and after every sample and the complete
matrix. It is never written by this apparatus. No player World, worker-owned
native object, Rapier owner or specialist fixture is borrowed or retuned.

## Independent review findings and corrections

The first exact source review of draft
[PR #285](https://github.com/techrote/cybersand/pull/285) correctly rejected two
parts of the initial candidate.

### Scheduled work was not actual worker participation

[Review finding P1](https://github.com/techrote/cybersand/pull/285#discussion_r4395390599)
noted that a phase with multiple jobs is only eligibility/dispatch evidence. A
single pool worker may claim every job. `TickStats::worker_threads_observed`,
which is populated by `PersistentWorkerPool::participating_workers()`, is the
actual maximum distinct task-claiming participant count for one dispatch in a
completed tick.

Commit
[`50cf90e1e4e0e64abcdc56e88d323d1a0ee95fe3`](https://github.com/techrote/cybersand/commit/50cf90e1e4e0e64abcdc56e88d323d1a0ee95fe3)
adds that already-existing native value to the copied exclusive-owner
`CyberDemoBridge.inspect_statistics()` result. It remains explicitly bounded:
this is a participant count, not per-worker utilization, time share or CPU
occupancy. No mutable World storage or pool object crosses the boundary.

Commit
[`2d39d2ba0eed97098577af190da26c79f23667e9`](https://github.com/techrote/cybersand/commit/2d39d2ba0eed97098577af190da26c79f23667e9)
then samples that copied count after each measured tick and records both the
maximum observed participants and the number of measured ticks with more than
one participant. Multiple jobs and parallel phases remain useful supporting
facts, but they no longer satisfy the participation gate by themselves.

### Terminal serialization contaminated the measured interval

[Review finding P2](https://github.com/techrote/cybersand/pull/285#discussion_r4395390605)
noted that the initial wall interval ended only after full-level export and
SHA-256. The export allocates and copies a complete finite level, adding a fixed
postprocessing cost to throughput comparisons.

The same `2d39d2b` correction captures the measured ending timestamp
immediately after the final tick/readback and before export. Terminal
export-plus-hash time is now a separate `terminal_export_hash_ms` field.
`completed_hz` excludes terminal serialization. Its wall interval still
includes the deliberately copied per-tick statistics query and headless test
scheduling, so it is not native-only time and not gameplay FPS.

Test commit
[`be628b8b2a9c51a8a7082223f7fe8d914d1dc8e7`](https://github.com/techrote/cybersand/commit/be628b8b2a9c51a8a7082223f7fe8d914d1dc8e7)
requires the one-worker control to report exactly one observed participant,
bounds every participant count by the actual pool size, and requires at least
one supported multiworker row to report **more than one actual task-claiming
worker**. It also preserves a truthful `parity=null` result on a platform where
all requests resolve to one actual count.

None of these review corrections has been executed while publishing this
record. The original review findings remain part of the PR history.

## Recorded values and acceptance contract

Each row records:

- requested workers (`1`, `2`, `4`, `6` or Auto `0`);
- resolved workers and resolution source;
- actual native pool readback, logical processors and Auto result;
- backend identity and process-setting before/after values;
- fixed side/tick/warm-up dimensions;
- native tick mean/p95/max and test-frame interval mean/p95/max;
- measured wall interval and completed ticks per second, ending before terminal
  serialization;
- separate terminal export-plus-hash duration;
- moves, active and eligible blocks;
- scheduler jobs, maximum jobs, parallel phases and phase-bearing ticks;
- maximum actual task-claiming pool participants and participation-bearing
  ticks; and
- terminal level SHA-256.

The normal matrix contains both 480² and 960² fixtures for every request. It
keeps distinct requested rows even when a constrained host resolves two
requests to the same actual count. `workers` remains as a compatibility alias
for the existing benchmark presentation, while the evidence uses explicit
`requested_workers`, `resolved_workers` and `actual_workers` fields.

The bounded regression retains the former statistics, cancellation, movement,
timing and fixed-input hash checks and requires:

- all five requested policies at both sizes;
- actual worker count equal to the source-derived resolved count;
- every row to leave the process-wide setting unchanged;
- finite native work and eligible scheduler work;
- terminal level hashes to match for each size across worker policies;
- observed participant counts to be at least one and no greater than the actual
  pool; and
- when the runtime has an actual pool larger than one, at least one row to show
  more than one task-claiming pool worker on one or more measured ticks.

The last gate is participation evidence only. It does not prove positive
scaling. A source-bound result can legitimately show that a tiny row is slower
with more workers, or that only the larger row enters parallel work.

## Isolation and policy preservation

This candidate changes the reference benchmark helper, its automatically
discovered regression, one copied native statistics field and this audit.
Production `SimulationCore`, `CyberSimulationWorker`, native Auto policy,
player course, main-thread Rapier, worker defaults and browser threading modes
are unchanged.

`CyberDemoBridge.build_world()` constructs the ordinary default liquid policy.
The selectable per-material liquid families, prepared construction/commit
transaction, requested-versus-applied receipts, Water `pressure_flow_v1`
option and unsupported-route refusal remain untouched. This apparatus does not
claim parity for every liquid family; that requires explicitly matched policy
rows in later #266/#270 evidence.

Specialist scientific, physical-characterisation, 4LY and NPC-training
fixtures remain independent. Material swarms #271 remain deferred. The closed
redundant dedicated-owner approach #265 is not revived.

## Required execution and review

No Godot or native execution was performed while publishing this source. Before
acceptance, require a fresh exact-head independent source review and the normal
Documentation/provenance, Native and complete Windows/Linux Godot/GDExtension
workflows. Read back `PLAY_AUTO002_RESULT` and the per-test manifest/log hashes,
not merely a green workflow summary. The receipt must show:

- zero test or engine-diagnostic failures;
- the complete ten-row 1/2/4/6/Auto × 480/960 matrix;
- unchanged project-setting values;
- fixed-input hash parity where more than one actual count exists;
- exact requested/resolved/actual worker identities; and
- at least one row with more than one actual task-claiming pool participant on
  each supported multiworker desktop platform, or an explicit supported-
  platform refusal instead of fabricated concurrency.

Timing values remain observations from separate reference Worlds. Test-frame
intervals and measured wall/HZ include headless test scheduling and copied
statistics reads; they are not rendered gameplay FPS. Native tick time is
reported separately. No causal speedup, per-worker utilization, desktop
frame-pacing, hardware gamepad, human-feel or release claim follows.
Equivalent composable-course native/publication/presentation measurements and
fair timing comparisons remain required under #266 and #270.
