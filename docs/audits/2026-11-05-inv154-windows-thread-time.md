---
title: INV-004 Windows Rapier calling-thread execution experiment
status: Current
document-kind: audit
scope: PR 449 reproduction and bounded calling-thread CPU versus wall-time discrimination
canonical-for: []
last-reviewed: 2026-11-05
related-documents: [../operations/profiling-observability-and-performance.md, ../reference/validation-evidence.md]
---

# INV-004 Windows Rapier calling-thread execution experiment

## Registered scope

Classify long synchronous `space_step()` intervals in the exact #449 acrobat
course: no brush, 60-frame warmup, four four-second original/timed/timed/original
arms, 60 FPS, unchanged gameplay/physics/rendering/dependencies. Require at least
20 aligned long steps. CPU dominated requires 80% of events at least 80% running;
off-CPU dominated requires 80% at least 60% off CPU. Missing alignment, excessive
perturbation, insufficient events or unresolved attribution means inconclusive.

The fallback measures GetThreadTimes kernel plus user execution on the calling
thread, with QPC and existing monotonic wall brackets. It cannot distinguish
blocked from ready-but-descheduled time. Rapier's parallel build can compute on
other threads while its caller waits. Cycle counters are corroborative only.
100 ns counter units do not guarantee 100 ns effective accounting resolution.

## Source custody and dependency preservation

Intake root `C:/khybersand` was on unrelated `mat/material-fidelity-pass-2`, HEAD
`620826f59fbe248f93a45c45e786a7297f2e5288`, with material/native work and generated
UIDs. Those files stay untouched. The historical companion workspace is not this
actual Git root. The only new scoped branch is
`codex/inv154-windows-thread-time-20261105`, based on inspected current main
`06522e300dcf91efbab0ac8f4f4370af72cf2029`, in
`C:/Users/_/.codex/worktrees/rapier-thread-time-20261105/khybersand`. Main differs
from accepted diagnostic baseline `ba9cbc89029be88b812af59b19e5c59829bbcd90`
only by three README lines; production/settings/runtime source is equivalent.

| PR | Exact base | Exact head | Unique experiment |
|---|---|---|---|
| #436 | `ba9cbc89029be88b812af59b19e5c59829bbcd90` | `8c824de5f08611116758e07ce94310a963288c67` | Baseline then brush callback attribution |
| #440 | `8c824de5f08611116758e07ce94310a963288c67` | `d278a40a56be6a402dce3b23e56093d2d6f30b06` | 60/0/0/60 cap and draw clocks |
| #446 | `d278a40a56be6a402dce3b23e56093d2d6f30b06` | `e2b4dd0f97d03af1a3f50ededb246d824350d942` | Five physics wrappers versus residual |
| #449 | `e2b4dd0f97d03af1a3f50ededb246d824350d942` | `2e937ee37532b06d46fa49205ff2e51c1a9baa2e` | Same-cap ABBA stage and step/flush clocks |

All eleven additive stack files (five fixtures, six workflows) are retained
verbatim. Older workflow branch filters and the offline analyzer's historical
run/source/artifact remain frozen. #449 directly uses the shared host and Main;
predecessor ancestry is not a runtime dependency. **#436/#440/#446 can safely be
superseded as active investigations while retaining branches, unique tests,
failures and artifacts.** They are not duplicate tests. No old branch is
rebased, modified, deleted or merged; no PR is closed or promoted.

## Unchanged original reproduction

[Windows run 42115748865](https://github.com/techrote/cybersand/actions/runs/42115748865)
executes exact #449 head/tree `2e937ee37532b06d46fa49205ff2e51c1a9baa2e` /
`4a9aeb666a590fe4fb18850bcd9a8e0f4c260de3`: 965 callbacks, 22 assertions, zero
failures, positive native/Rapier progress, no overflow and joined shutdown.
Windows Server 2022 ANGLE/D3D11 uses Microsoft Basic Render Driver.

| Arm | Callbacks | Callbacks over 40 ms | Step wall time in those callbacks |
|---|---:|---:|---:|
| Original A1 | 242 | 9 | 361.294 ms |
| Timed B1 | 242 | 16 | 638.168 ms |
| Timed B2 | 241 | 24 | 942.982 ms |
| Original A2 | 240 | 9 | 364.940 ms |

The 40 timed long callbacks contain 1,581.150 ms of step time in 1,584.684 ms
Rapier wrapper time. This reproduces the tail before CPU probes. Original native
pool-worker participation was not separately sampled.
[Raw artifact 13456501103](https://github.com/techrote/cybersand/actions/runs/42115748865/artifacts/13456501103)
is 95,790 bytes, ZIP SHA-256
`248c7aa33719955d85b732d50d6ed6badc9014ffe893c15bcd7ada8b0dcc3f68`.

The unchanged original also passes locally on Windows 11 Pro 26300, Ryzen 5600X
(6 cores/12 logical CPUs), TITAN RTX 32.0.15.8180, Godot 4.7 ANGLE/D3D11. Import
and runtime exit zero, 22 assertions pass and the worker joins. No step exceeds
40 ms in 960 callbacks. This different-host single run is inconclusive and does
not isolate GPU effects. An unrelated existing Godot process remains untouched.

Both use native source/build `acce570e667c7e2cc3ef83ab451e7dff262006a9`, native
SHA-256 `cb675a4cde4317608bb892437af9b9f2b7cddf6a7289a6a028500efab19aae9d`
and Rapier `b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7`.
Main blob is `791ef440efd6edb206c6f1be33989cb62e9213b2`; bridge blob is
`87eea1f36b11375eb40be6a833433871000fbb2e`.

## Capabilities, failures and interpretation

Local WPR 10.0.26100 lists CPU/GeneralProfile, but
`wpr -start GeneralProfile -filemode` fails `0xc5585011`: failed to enable the
policy to profile system performance. Status remains not recording. Preserve
the failure; no privilege/security policy or unrelated session is changed.

The raw-C helper initially crashes on null return-property hint metadata; an
empty Godot String corrects registration. The failed-attempt record is retained.
Subsequent smoke tests pass: 80 ms sleep has zero CPU delta; 80 ms busy work has
78.125 ms, same OS thread and zero API errors. Local CPU accounting is quantized
in 15.625 ms increments. The classifier's 15.625 ms sensitivity allowance is
an explicit assumption, not a Windows API accuracy guarantee.

An enabled graphical smoke exits zero with 960 callbacks, positive native/Rapier
progress and joined shutdown. Maximum step is 0.370 ms. CPU sample-pair span
p50/p95/max is 4.1/5.3/22.2 microseconds. Ten 100 ms busy/sleep calibration pairs
record busy CPU 78.125–109.375 ms and sleep CPU zero. Native sampler capacity is
six, with one task-claiming participant in sampled phases. This is maximum
distinct claimants in one completed phase, not simultaneous utilization. Both
profiling states enable the same existing bounded sampler.

Disabled profiling retains the test bridge subclass's `super()` path. It bounds
incremental probes rather than proving the subclass itself free. The unchanged
original #449 reproduction remains a separate control cohort. Observed frame,
callback and step distributions must all be inspected for perturbation.

Initial successor run 42117415272 at `6eec5d4695d6085440a7768b3d2d5d6c7c1899b6`
was intentionally cancelled during setup to remove two trailing-whitespace lines
from the copied diagnostic. Its cancelled state remains historical. Corrected
source `8924c43a` passes the same source-equivalence guard; runtime semantics and
measurement thresholds are unchanged.

## Reproduction commands and checkpoint mapping

```text
python tools/performance/rapier_thread_probe/build_probe.py --engine <Godot-console.exe>
python tools/performance/rapier_thread_time.py --validate
python tools/performance/rapier_thread_time.py --engine <Godot-console.exe> --output build/inv154-thread-time --trials 3 --etw
python tools/performance/rapier_thread_time.py --analyze <artifact-directory>
python tools/performance/rapier_thread_time.py --self-test <enabled-raw-trace.json>
```

The workflow uses GitHub-hosted Windows-2022 and retains rows, calibration,
source/runtime/compiler identities, exits, WPR failures and successful ETLs for
90 days. Every trial has a 745-second runtime bound. Source guards strip only
enumerated probe lines and compare copied Main dispatch and bridge step to #449.
Six adversarial regressions reject missing calibration, wrong thread, reversed
QPC, API failure, bad nesting and stale step counters.

Production ownership/lifetime, interfaces/invariants, algorithms, capacity,
ADR-009, dependency pins and user controls stay equivalent. The canonical
profiling guide routes here; existing retrieval ownership remains there.
Generate the helper separately; commit no generated header/API dump, DLL,
import, log or trace. Source matching remains distinct from M11 historical
integrity. Final execution and checks are recorded below.

## Local validation checkpoint

Source guards, native helper build and sleep/busy smoke, Godot check-only,
enabled graphical smoke, six adversarial measurement regressions, provider
policy, M11 historical integrity (18 records/28 hashes), repository provenance
and documentation validation pass locally. The initial docs/repository attempts
fail only because the isolated checkout lacks five external companion files
(six question references). Materializing those exact files from the workflow's
pinned companion revision `6a58311982941b75f46e22109a0829e5acb83c7e` in the
experiment's parent directory resolves the missing-input failure. Original
failed logs and the companion hash receipt remain in local evidence. The check
does not require materializing unused platform runtimes for this Windows task.

Frozen retrieval remains 19/32 hit@1, 32/32 hit@5, MRR 0.7536. The separate new
INV154 question is 1/1 at rank one. Existing frozen and supplementary questions
and the corpus manifest remain unchanged. Manual source review confirms the
canonical guide distinguishes caller CPU from wall time, blocked/descheduled
uncertainty and internal-worker computation, and registers sufficient-event,
repeat and perturbation gates. The audit stays outside default retrieval.

Local original and enabled-smoke raw data, WPR failure, exits and commands are
under `build/rapier-thread-time/`; helper build/failure provenance is under
`build/rapier-thread-probe/`. The smoke fixture's LF SHA-256 is
`22d04e6219caac6ff1eb5f9101269544443df38e7df470560a3e2bce195ff95a`
at `6eec5d46`; the successor only removes two whitespace-only lines. The raw
smoke JSON SHA-256 is `e21527230715ce33a8193930497bab69ca60295c823302e55c6e4d2aee3e9ff3`.
Generated Godot UIDs/extension cache and helper DLL remain uncommitted.

## Three repeated hosted comparisons

[Run 42117551171](https://github.com/techrote/cybersand/actions/runs/42117551171)
passes at source `8924c43a2deb22922515ce5a2dbc7891afd06a9a`, tree
`2ad19c2347906548087eb6e1bdbe99b799c93b1a`. Official Godot console/runtime
SHA-256 are `d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c`
and `b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8`.
The unchanged native/Rapier runtime identities above pass source matching.
Host: Windows Server 2022 Datacenter 20348, EPYC 7763 with 2 cores/4 logical
processors, ANGLE/D3D11 Microsoft Basic Render Driver. All six process exits are
zero, progress is positive, lifecycle/state guards pass and all workers join.
Actual native sampled capacity is four, observed task claimants one in every
trial. This remains the bounded phase-participation metric, not CPU utilization.

| Trial | Profiling | Callbacks | Steps over 40 ms | Frame p50 / p95 ms | Step p50 / p95 ms |
|---|---|---:|---:|---:|---:|
| 1 | Disabled | 968 | 55 | 96.006 / 97.468 | 0.124 / 54.603 |
| 2 | CPU + WPR | 975 | 57 | 104.161 / 112.002 | 0.210 / 47.995 |
| 3 | Disabled | 969 | 63 | 96.004 / 97.907 | 0.124 / 63.644 |
| 4 | CPU + WPR | 974 | 56 | 103.565 / 111.124 | 0.214 / 54.088 |
| 5 | Disabled | 968 | 47 | 96.001 / 97.987 | 0.127 / 35.594 |
| 6 | CPU + WPR | 969 | 56 | 103.291 / 111.657 | 0.210 / 49.850 |

**Counter classification: Off-CPU dominated on the calling Windows thread.**
All 169/169 qualified long steps (57/56/56 by enabled trial) meet the registered
at-least-60%-off-CPU threshold, including the explicit 15.625 ms accounting
sensitivity allowance. Zero events are excluded and none meets CPU dominated.
Long steps range 40.753–78.517 ms, median 71.037 ms. Every long event records
zero charged kernel+user CPU delta, which is not a claim of literally zero
instructions under coarse accounting. Maximum conservative CPU occupancy is
38.341%; maximum CPU/QPC bracket excess beyond the inner step is 20.7 µs.
All three sets of ten busy/sleep controls pass (busy 93.750–109.375 ms CPU per
100 ms wall; sleep zero charged CPU). Raw cycle counters are retained.

Original-dispatch A arms contribute 88 long events and timed B arms 81; all
record zero charged CPU. The copied Main dispatcher is not the sole source of
the tail. Enabled long-event rate is 169/2,918 (5.792%) versus disabled
165/2,905 (5.680%). All six trials report 23 assertions and zero failures, and
62–63 distinct native participation samples each.

Profiling has measurable perturbation. Median-of-trial frame p50 rises from
96.004 to 103.565 ms (+7.88%) and p95 from 97.907 to 111.657 ms (+14.04%),
within the preregistered 20% gate. Callback p50 rises 12.63%, while callback p95
falls 8.22%. Step p50 rises 0.086 ms (+69.35%), so do not claim negligible
overhead or use these samples to estimate production microstep cost. Median
step p95 falls 8.70%. The long tail persists in all disabled trials (165 long
steps total), rather than being created only by the profiler. All raw frame,
callback, native-progress and step distributions remain in the artifact.

The separate exact-original reproduction runs on an **EPYC 9V45**, whereas
this six-trial campaign runs on an **EPYC 7763**. Both expose two cores/four
logical CPUs and the same Windows/ANGLE software-renderer versions, but they
are different VMs. The original pooled draw-interval median is about 52.570 ms
(nearest-rank p50 52.652 ms), p95 64.199 ms, materially below this campaign's
disabled distributions. Do not attribute that cross-host difference to the
bridge subclass or profiler, or claim the original distribution is unchanged.
Only the six-trial same-host disabled/enabled comparison estimates profiling
perturbation. The counter conclusion applies to the reproduced long events in
this precisely identified EPYC 7763 cohort.

Independent local replay of all six unmodified raw JSON inputs reproduces
Off-CPU dominated, 169 qualified/169 off-CPU/zero excluded. The six invalid-input
regressions also pass against a hosted enabled trace. The original downloaded
classification remains untouched; reanalysis writes to a separate directory.

[Raw artifact 13456368435](https://github.com/techrote/cybersand/actions/runs/42117551171/artifacts/13456368435)
is 159,056,660 bytes; GitHub reports archive digest
`c119387c749ca2fd4304f49fbcd127d9a03c8067cc72e30f10220d44469166d7`.
It retains complete timing/counter rows and three successful WPR recordings.
WPR start/stop each exits zero on this runner, despite unavailable local access.
Each ETL is 110,100,480 bytes; independently computed SHA-256:

| Enabled trial | ETL SHA-256 |
|---|---|
| 2 | `24c6cfa365d020b8f101502d3a687a7d04b4723c98e86f7b69d425e270c645fd` |
| 4 | `e6d2de79d1664f2957329a41ec9be94f619130febb46856eb809bc64160f60a2` |
| 6 | `1f6c4ab77909e4e7d6346da8ac6476a6b75ee8baf3875d8c76421553ec24fd8a` |

Thread-state and symbol interpretation is separate from the counter verdict.
Do not infer blocked versus ready/descheduled time without ETW event evidence,
or aggregate Rapier worker inactivity from the calling-thread counters.

## Independent ETW thread-state reconstruction

The bounded offline reader uses pinned Microsoft TraceEvent 3.2.8. It compares
native QPC brackets and OS thread IDs directly with CSwitch and ReadyThread
events. Each waiting interval has a Waiting-state switch-out, a matching
ReadyThread and subsequent switch-in. Missing ready evidence becomes unknown,
never assumed blocking. Every long event has complete coverage. Each ETL has
zero lost events; no state anomaly intersects a long event. Small outside-window
ready-while-scheduled anomalies remain in the output.

| Enabled trial | Long events | Scheduled ms | Waiting ms | Ready/descheduled ms |
|---|---:|---:|---:|---:|
| 2 | 57 | 5.1508 | 3,723.1198 | 1.5116 |
| 4 | 56 | 5.1177 | 3,797.2661 | 1.5007 |
| 6 | 56 | 5.2497 | 3,647.8840 | 1.5306 |
| Total | 169 | 15.5182 | 11,168.2699 | 4.5429 |

**ETW confirms waiting dominates: 99.820696% of summed long-event bracket time
is Windows waiting. Every event is at least 99.66210% waiting.** Only 0.040604%
is ready but not scheduled. Scheduled time is 0.138700%; it can include
interrupt/DPC time, rather than pure useful CPU execution. All long waits retain
numeric kernel reason 37. These are guest-OS states, not hypervisor scheduling
or aggregate Rapier worker CPU observations.

Complete ETLs contain 110,769 / 109,949 / 110,311 CPU samples,
142,153 / 138,157 / 134,576 context switches and 39,442 / 37,184 / 37,099 ready
events. The caller has only 2 / 2 / 4 CPU samples inside all long windows.
The reader recovers 338/338 relevant switch/sample stacks with Godot and Rapier
module chains. Full symbol qualification follows separately.

## Resolved wait site and final disposition

Matching Rapier and Microsoft OS symbols resolve the same chain in all 330
switch-out stacks within the 169 long events:

```text
RapierPhysicsServer2D::space_step
  -> RapierSpace::step -> PhysicsWorld::step
  -> rayon_core::registry::Registry::in_worker_cold<ThreadPool::install ...>
  -> rayon_core::latch::LockLatch::wait_and_reset
  -> std::sys::sync::condvar::futex::Condvar::wait
  -> KERNELBASE!WaitOnAddress
  -> ntdll!NtWaitForAlertByThreadId
  -> ntoskrnl!KeWaitForAlertByThreadId
```

161 switch-out stacks also include Rust's contended futex mutex in this waiting
chain. All 338 relevant rows (330 switch-outs/eight CPU samples) have captured
stacks; symbol lookup reports zero exceptions. This is actual blocking in
Rapier's Rayon worker-pool synchronization. The observed caller wall-time tail
is **Off-CPU dominated, specifically waiting**, rather than caller computation
or appreciable guest ready-but-descheduled delay. The minimum per-event waiting
fraction remains 99.662040% after subtracting all enclosing-bracket excess.

The matching PDB comes from [patched artifact 12545054196](https://github.com/techrote/cybersand/actions/runs/40056501226/artifacts/12545054196),
ZIP SHA-256 `138f058fbf8696aaf0bb2492a83b6ae4f7b9e595b55a947a427ece9883991960`.
The ZIP's DLL matches the executed Rapier hash; it is not installed or substituted.
PDB SHA-256 is `4d8a135baf94b65d0870400a4fbbb0da2d39c47b169a26298c74a29eac3a8d4f`.
Godot module/address frames are captured, but official 4.7 Windows binaries have
no PE debug directory/COFF symbols, and the official release lists no Windows
PDB archive. Godot function names remain unresolved; no unmatched rebuild is
used as a substitute. Preserve that capability gap explicitly.

This result does not establish aggregate Rapier worker CPU occupancy, why pool
completion is late, GPU causation, general end-user performance or a production
speedup. No solver, renderer, gameplay, worker-count or dependency optimization
is selected. The local TITAN RTX no-tail observation remains a different-host
inconclusive cohort. #154 remains open; #449 remains draft and unmodified.

The preserved offline analyzer uses .NET 10 and exact TraceEvent 3.2.8
(package SHA-256 `37284f885e75326bbd1858bf19f20c9da2818fec7a3bd49803209209be5fd38d`).
Replay all three retained ETLs with the matching PDB directory:

```text
python tools/performance/analyze_rapier_thread_states.py --traces <artifact-trial-parent> --symbols <PDB-directory> --output <new-derived-output>
```

This wrapper builds the preserved C# sources, bounds each analysis to 180 seconds,
checks the PDB hash and preserves state/stack/source receipts. The independent
offline workflow authenticates the immutable raw and PDB archives before replay;
it executes no game or new benchmark. The source-equivalent branch and retained
raw artifacts form the recoverable checkpoint. Historical branches, failures,
unique tests and artifacts are retained. Record the final hosted receipts below.
