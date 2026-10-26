---
title: PLAY-ASYNC-001 source-bound desktop baseline and qualification ledger
status: Current
document-kind: evidence
scope: Source inspection and existing exact-main Windows/Linux CI readback; separate unmeasured interactive pacing gaps
canonical-for: [play-async-001-baseline-and-evidence-gaps]
keywords: [PLAY-ASYNC-001, Windows, Linux, synchronous playground, asynchronous sandbox, frame pacing, evidence]
last-reviewed: 2026-10-26
related-documents: [../decisions/ADR-015-player-playground-asynchronous-owner.md, ../architecture/player-playground-asynchronous-contract.md, ../operations/local-build-and-validation.md, 2026-10-24-issue-234-physical-hang-repair.md, 2026-10-21-player-playground-pr189-completion.md]
---

# PLAY-ASYNC-001 — dated baseline and evidence gaps (2026-10-26)

## Evidence identity and classification

**Inspected exact repository main:** `9e53a5b1b501e0667037b8502d3c1d15089211f5`
(commit subject: merge of the current LCB work). The source-bound CI runs
from 2026-10-25/26 are **actual GitHub-hosted execution on that same SHA**,
not execution of this documentation branch or the future asynchronous
playground implementation. The connector's logs, source-qualified issue
evidence and actual GDScript/native implementations were inspected. No
fresh local binary build, target-device input test, dedicated benchmark
invocation, camera capture, interactive FPS/p95/p99 recording or test of the
proposed player-cell owner was run during #264's architectural inspection.
The caller had no source-matched executable/desktop display in this
environment. Avoid treating a historical benchmark, clean CI result or
GitHub step wall-clock as a new gameplay-pacing measurement.

### Source-bound actual Windows/Linux CI

| Evidence | Platform, actual result | Source/run and limitations |
|---|---|---|
| Current Player Playground runtime | Linux shard 2: **1,329 assertions, 0 failures**, all seven native/Rapier presets | [GDExtension/Godot run 40246630501](https://github.com/techrote/cybersand/actions/runs/40246630501), job `121331264054`, SHA `9e53a5b1`. Current synchronous five-mechanical/synchronous two-swarm code; headless, not wall-paced rendering |
| Same Player Playground runtime | Windows: **1,329 assertions, 0 failures** | Same run, job `121329459844`, actual Windows pinned Godot `4.7`, retained exact-source/provenance-verified Windows native/Rapier; headless |
| Existing asynchronous sandbox physics integration | Linux: **120 completed native ticks, zero worker overruns**; recorded feedback age histogram `[117,1,0,0,0,0,0,0,1,0]` | Same run, Linux shard 3 job `121331264084`; `PHYSICS_ASYNC` fixture uses `diagnostic_reset({"workers":1})` and a value-only body exchange; **not** Player Playground |
| Same sandbox integration | Windows: **120 completed native ticks, zero worker overruns**; feedback age histogram `[99,1,0,0,0,0,1,0,0,0]` | Same run, Windows job `121329459844`; different scheduling/timing, so compare completion/shape, **not** per-bin equivalence |
| Current documentation/provenance and mandatory native/Godot matrices | All three workflow runs **success** at `9e53a5b1` | [Documentation 40246630498](https://github.com/techrote/cybersand/actions/runs/40246630498), [Native 40246631211](https://github.com/techrote/cybersand/actions/runs/40246631211), [Godot 40246630501](https://github.com/techrote/cybersand/actions/runs/40246630501). These are pre-change gates, not new #264 PR gates |

These are **measured test and simulation-completion counts** only.
A `120/120` result or zero worker-deadline resets does not provide
end-to-end desktop simulation Hz or frame-time distributions. The
Player Playground test runs scripted physics ticks as fast as its fixture,
not as real-time manually played frames. The asynchronous fixture verifies
the sandbox architecture at one native worker, not Auto pool participation.

### Prior relevant evidence: historical, not a new baseline

- [#149](https://github.com/techrote/cybersand/issues/149):
  a snapshot period gate comparing elapsed time against 16,667 µs on
  a 60-Hz render loop can effectively halve publication to ~30 Hz because
  timer jitter regularly misses its threshold. The 2026-09-20 investigation
  measured this behavior in an earlier workload; the selected design uses
  independent monotonic deadlines, not a claim this was remeasured at
  `9e53a5b1`.
- [#232–#234](https://github.com/techrote/cybersand/issues/234):
  the native/Rapier deferred-BVH hang repair on accepted source
  `13b8e631f3e8fbaa2176ed41afc02c434b11e558` qualified **600/600
  physical executions** and **20/20 import preflights** with no timeouts in
  [stress run 40129364630](https://github.com/techrote/cybersand/actions/runs/40129364630).
  The source-bound median/p95/maximum for **whole test-process wall time**,
  not a frame or tick, in the *serial* actor-arena stratum were Linux
  `10.4935/17.012/17.040 s` and Windows
  `18.7750/19.814/20.363 s`. These characterize CI stability and host
  contention, not the proposed asynchronous schedule. The underlying
  scheduler race was not proven and the worker count was not varied in this
  qualification.
- [PR #189 player completion](2026-10-21-player-playground-pr189-completion.md)
  ran actual pinned Godot 4.7/Rapier on both desktops, but its accepted
  source and runtime identity differ from `9e53a5b1`; do not transplant
  its historical binary hashes or test totals to this revision.

## Reproduction commands and controlled comparison

All commands below are **prescribed, not claimed newly executed** for #264.
Use the repo's pinned Godot 4.7/Rapier 0.35.2, source-matched native
extension, relevant Git LFS binaries and the existing CI runner/binary
provenance manifests; record absolute SHA-256 of executable and LFS runtime,
`git rev-parse HEAD`, dirty paths, OS version, CPU/logical cores, GPU/display
driver, power mode, requested/actual workers, world/scene and camera, fixture
seed, startup phase, repetitions and exact command. A headless CI import
does not qualify a human-visible renderer.

```sh
# From repository root, on Windows and Linux using equivalent pinned runtimes:
git rev-parse HEAD
git status --short
git lfs fsck
make build/tests
./build/tests "player material field"
godot --headless --path godot --script res://tests/test_player_playground_runtime.gd
godot --headless --path godot --script res://tests/test_player_playground_course.gd
godot --headless --path godot --script res://tests/test_physics_async.gd
godot --headless --path godot --script res://tests/test_auto_worker_policy.gd
# Additional existing native workload independent of the player World:
# godot/scripts/worker_benchmark.gd -> CyberWorkerBenchmark.sample(tree, workers, side, ticks, ...)
# For actual Linux real-renderer capture, not headless:
xvfb-run -a godot --path godot --rendering-method gl_compatibility \
  --script res://tools/capture_player_playground.gd -- \
  --player-capture-output=/absolute/output
```

For **synchronous baseline** run the unmodified `9e53a5b1` Player
Playground: each of the five mechanical presets (`stuntbuggy`, `trialsbike`,
`acrobat`, `arcadelander`, `jetbarrel` as actually named by the
course catalogue), course with authored fixture and unchanged
`diagnostic_reset(workers=1)`; 60-Hz `_physics_process` calls
`runtime.step` synchronously and terrain may process all 256 chunks
immediately. Capture 300 warm frames + 1,800 measurement frames per
preset on the same Windows/Linux desktop and driver, scripted neutral/actuated
pass with the identical fixed input/event trace. On a second identical
host run the ordinary async sandbox using its existing
`CyberSimulationWorker` with exact recorded default World/demo fixture,
Auto native workers (`cybersand/native_worker_threads=0`) and equivalent
fixed viewport/resolution, and also optional explicit1 control. **Different
scene/layout/gameplay modes are not an apples-to-apples throughput comparison**;
record them separately as reference ownership baselines.

Use existing per-tick timing properties/worker benchmark statistics, Rapier's
`last_step_time_ms`/`last_flush_time_ms`, existing worker overrun data and
monotonic `Time.get_ticks_usec` around actual `_physics_process`,
`_process`, packet upload and draw, with compact diagnostic accumulator
that does not alter sim scheduling. A minimal #264 instrumentation-only
change is permissible if indispensable; this checkpoint deliberately does
**not** modify gameplay code. Record mean, p50/p95/p99/max native tick
duration, total synchronous `advance_frame` main hold, frame-present
interval, input-to-physical-step latency, render snapshot age, collider
time, true completed cell/physical Hz, native scheduler parallel phase/job
counts and observed dropped/stale publications. Compare on identical
renderer settings and capture cadence; never infer 60FPS from simulated
ticks. `CyberWorkerBenchmark.sample` is one native tick **per UI frame**
and is *not* a substitute for this gameplay comparison.

Once #265/#266 exist, reproduce with identical authored course,
actor control trace, simulation window and #265 mailbox bounds on
`requested_workers=0/Auto`, explicit1, and an admitted multicore count.
Report worker count **actually read back** and phases that actually ran,
not only requested values; check timing distributions plus changed gameplay
trajectory/feel without claiming asynchronous execution is lockstep
equivalent to the synchronous arena.

## Gaps, gates and measured-versus-predicted distinction

**Known gaps at this source checkpoint:** no fresh Windows/Linux
per-frame Player Playground `sync` vs sandbox `async` time series
with controlled hardware/viewport; no measured native1/Auto Player
Playground multicore speedup or frame-pacing delta; no live human
gamepad/keyboard/target-GPU feel; no experimental owner protocol/failure
qualification; no Android/Web or Web regression change (deferred).
The expected reduced **main-thread** native-tick stall and possible
multicore throughput gains are **design predictions**, not results.

**Acceptance policy:** #265/#266 can implement this source-derived
contract independently; do not mark #264's **performance baseline
measurement** acceptance satisfied without the missing controlled runs
or a clearly documented external-blocker disposition approved in the
issue. #270 may not promote the new desktop default without exact
tested source/runtime identities, credible Windows/Linux pacing,
overload and teardown evidence and green mandatory CI. Retain both
failed and passing experiments unchanged; #234's timeout guard is
not weakened.
