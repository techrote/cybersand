---
title: PLAY Auto worker-matrix candidate and qualification plan
status: Current
document-kind: evidence
scope: Per-World 1/2/4/6/Auto reference construction, requested/resolved/actual readback, fixed-input parity, scheduler participation and explicit performance nonclaims
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
was eligible for parallel work or that additional workers improved elapsed time.

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
participation to one aggregate phase count.

Code commit
[`6c5ce74f77088a1d3dc0827ff5240114529bca95`](https://github.com/techrote/cybersand/commit/6c5ce74f77088a1d3dc0827ff5240114529bca95)
replaces that path with a fresh reference World per row:

1. Read the native logical-processor count and exact static Auto resolver.
2. Resolve an explicit 1/2/4/6 request with the same logical-processor and
   32-worker ceiling used by normal native construction; resolve `0` with the
   native Auto policy. A non-threaded Web runtime truthfully resolves to one.
3. Instantiate an otherwise unshared native World and call its explicit
   `diagnostic_reset({"workers": resolved})` construction boundary.
4. Rebuild the ordinary deterministic Sand/Water fixture through
   `CyberDemoBridge.build_world()`, which copies the World configuration while
   restoring ordinary default material and liquid policies.
5. Run the fixed warm-up and measured ticks, export the terminal level, discard
   the World and its persistent pool, then proceed to the next row.

The project setting is read before and after every sample and the complete
matrix. It is never written by this apparatus. No player World, worker-owned
native object, Rapier owner or specialist fixture is borrowed or retuned.

## Recorded values and acceptance contract

Each row records:

- requested workers (`1`, `2`, `4`, `6` or Auto `0`);
- resolved workers and resolution source;
- actual native pool readback, logical processors and Auto result;
- backend identity and process-setting before/after values;
- fixed side/tick/warm-up dimensions;
- native tick mean/p95/max and test-frame interval mean/p95/max;
- measured wall interval and completed ticks per second;
- moves, active and eligible blocks;
- scheduler jobs, maximum jobs, parallel phases and the count of measured ticks
  that actually entered a parallel phase; and
- terminal level SHA-256.

The normal matrix contains both 480² and 960² fixtures for every request. It
keeps distinct requested rows even when a constrained host resolves two
requests to the same actual count. `workers` remains as a compatibility alias
for the existing benchmark presentation, while the evidence uses explicit
`requested_workers`, `resolved_workers` and `actual_workers` fields.

Test commit
[`0c010f895f98d5e3c14b834419ef165ebe0eab85`](https://github.com/techrote/cybersand/commit/0c010f895f98d5e3c14b834419ef165ebe0eab85)
retains the former statistics, cancellation, movement, timing and fixed-input
hash checks and adds these gates:

- all five requested policies occur at both sizes;
- actual worker count equals the source-derived resolved count;
- every row leaves the process-wide setting unchanged;
- each row performs finite native work and reports eligible scheduler work;
- terminal level hashes match for each size across worker policies; and
- when the runtime supports an actual pool larger than one, at least one row
  must report both multiple scheduler jobs and one or more measured parallel
  phase ticks.

The last gate is participation evidence only. It does not prove positive
scaling. A source-bound result can legitimately show that a tiny row is slower
with more workers, or that only the larger row enters parallel phases.

## Isolation and policy preservation

This candidate changes only the reference benchmark helper, its automatically
discovered regression and this audit. Production `SimulationCore`,
`CyberSimulationWorker`, native Auto policy, player course, main-thread Rapier,
worker defaults and browser threading modes are unchanged.

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
acceptance, require an exact-head independent source review and the normal
Documentation/provenance, Native and complete Windows/Linux Godot/GDExtension
workflows. Read back `PLAY_AUTO002_RESULT` and the per-test manifest/log hashes,
not merely a green workflow summary. The receipt must show:

- zero test or engine-diagnostic failures;
- the complete ten-row 1/2/4/6/Auto × 480/960 matrix;
- unchanged project-setting values;
- fixed-input hash parity;
- exact requested/resolved/actual worker identities; and
- at least one real participating multiworker row on each supported desktop
  platform, or an explicit supported-platform refusal instead of fabricated
  concurrency.

Timing values remain observations from separate reference Worlds. Test-frame
intervals include headless test scheduling and are not rendered gameplay FPS.
No causal speedup, desktop frame-pacing, hardware gamepad, human-feel or release
claim follows. Equivalent composable-course native/publication/presentation
measurements and fair timing comparisons remain required under #266 and #270.
