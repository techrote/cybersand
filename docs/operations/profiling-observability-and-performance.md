---
title: Profiling, observability, and performance
document-kind: runbook
canonical-for: [performance-measurement, metric-interpretation]
status: Current
scope: Current native/Godot observations, benchmark procedure, metric boundaries, and unimplemented production telemetry
last-reviewed: 2026-10-31
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

## PLAY-PACE-003 full-resolution correction — 2026-10-31

The [current cold-start audit](../audits/2026-10-30-play-pace003-cold-startup.md#full-resolution-readiness-correction-and-current-qualification-boundary--2026-10-31)
preserves281's Linux Main passes and separate LIFE008 failure, Windows timeouts,
and a complete source-matched local control/unified contrast. At the actual
palette program, link plus first-draw wall time falls13.915902→6.674986s;
initial actor readiness changes from deadline failure to11.518824s within the
unchanged15-second operation. The unified process completes62assertions/0failures,
three real fault/navigation orderings and six hosts, with full source/runtime/cache
custody. Its32 original-versus-candidate native/PNG pairs remain exact. The local
probe stays NONQUALIFYING, with zero /proc samples and retained clock/observer/
resolver limits. The original v1 runtime-custody failure is not erased.

Production shader62a41329ce96 is token-identical to tested10ed except two comments;
its resulting-head hosted graphical/ordinary/Native/Docs matrix and actual emitted
GLSL remain required in the [qualification ledger](https://github.com/techrote/cybersand/pull/310#issuecomment-6536644006).
Windows is still uncorrected. Native/renderer/runtime/training semantics and
30/180-second Main/case limits stay fixed. The separately authorized
[CI parallelism integration](https://github.com/techrote/cybersand/issues/305#issuecomment-6537154140)
preserves coverage and all original command bounds; it cannot waive these gates
or authorize #308/#309/PLAY completion.

## Current observations and their limits

### Shared PLAY host pacing campaign

[`tools/play/run_pace003_campaign.py`](../../tools/play/run_pace003_campaign.py)
measures the actual integrated Main/native-worker/Rapier course in fresh
one-worker/Auto processes. Each fixed15–30-second window preserves consecutive
owner-side native completion timings, observed task participation/phases,
actual graphical `frame_post_draw` intervals, Main/physics callback costs,
snapshot/render age, serial coalescing, deadline overruns, snapshot-lock wait
and construction/reset/stop-join latencies. Raw owner rows transfer to Main
only after join. The test-only copied-statistics cost is separately measured
and included in observed wall pacing.

Construction acknowledgement and the test's later polling time are separate
observations. The apparatus latches the unchanged course/actor/terrain
predicate after an actual Main callback and checks that timestamp against the
original 30-second request deadline. A late poll cannot excuse a late or absent
acknowledgement. Bounded startup Main/physics/render timestamps remain in each
row, including successful rows; long first-frame and subsequent rendering gaps
are reported separately from the fixed measurement window. Build is not moved
after a hidden graphical warm-up, and the whole process remains bounded at
180 seconds. Timing inside Main callbacks does not attribute time spent in
engine rendering, driver compilation, scheduling or other uninstrumented work.

Graphical submissions are not physical scanout. Headless callbacks are never
rendered FPS. The WAIT001-derived lock probe measures only snapshot acquisition,
not all Main waits. Deadline overruns do not reveal an unmeasured queue depth.
Identical authored geometry/policy/viewport and intended Rapier-tick input
script do not fix asynchronous native/Rapier admission skew; ratios are not
deterministic replay or causal worker-speedup proof. One worker still uses the
asynchronous owner. Existing synchronous native reference measurements retain
their original workloads; no equivalent synchronous composed host is claimed.

The [dated audit](../audits/2026-10-30-play-life006-stress-and-recovery.md)
owns source/runtime/platform outcomes and failures. The
[invocation guide](local-build-and-validation.md#integrated-play-lifecycle-and-pacing)
describes local/hosted commands. Keep software-renderer, focus-injection and
physical-device/human limitations with every result. Do not infer stable FPS
from the worker's existence or hide long frames and negative scaling.

### Cold graphical startup and compiler attribution

The [#309 record](../audits/2026-10-30-play-pace003-cold-startup.md) separates
scene load/instantiation, Main readiness/callbacks, native candidate readiness,
actual accepted terrain/actor, shader linking and first draw. A long callback
gap alone establishes neither a deadlock nor a shader identity. Original
Windows module snapshots and Linux driver-call traces retain their different
attribution limits. CPU time and wall time must be reported together where
observed, with sampled lower bounds distinguished from exact calling-thread
accounting.

Each PACE003 process now isolates project and actual Godot user shader caches.
Linux uses private XDG cache/config/data and Mesa directories; Windows uses
private AppData/LocalAppData. The engine-reported user-data path is bound to
that row's retained empty-at-launch inventory. Driver caches outside these
named controls remain uncontrolled. A first failure cannot be replaced by a
warm run, retry, a successful later worker row or an isolated shader result.
The first historical passing local Auto process shared a user cache and is
explicitly excluded from independently empty-user-cache cold acceptance.

Attached shader resource/code/file hashes authenticate the real visual route.
Keep the pre-Build 30-second acknowledgement, 180-second case and 240-second
import bounds. The separate NONQUALIFYING shader diagnostic uses original and
candidate bytes, real draws and retained CPU/thread samples; it never reports
a PACE003 pass. Its original timeout remains a failed diagnostic job even if
the candidate finishes.

Adjacent-frame quantiles describe only intervals between observed events.
The additional window-cadence fields retain leading and trailing silence,
maximum gaps including those boundaries, and event count divided by the entire
measured duration. A boundary gap is a lower bound on a possible crossing stall.
Report these together so two early frames followed by a frozen window cannot
appear smooth; headless graphical event rates remain null.

#### Exact-head hosted and diagnostic readback

At PR #310 head 62d3f6cf, [PACE
41136597969](https://github.com/techrote/cybersand/actions/runs/41136597969)
passes Linux cold one-worker/Auto Main acknowledgement at 10.517283/12.672816s
and all seven graphical fixtures; both Windows Main rows time out at 180s. Linux
full-window submission rates are 15.438784/15.296248 events/s versus
60.024928/59.987895 completed native ticks/s, with only one actual native task
participant in either row. Startup, adjacent quantiles, window boundaries,
snapshot age, render-payload age and coalescing retain separate meanings. The
[source/artifact ledger](../audits/2026-10-30-play-pace003-cold-startup.md)
records exact numbers and does not claim parallel scaling or physical scanout.
The roughly 17-second maximum terrain render-payload age includes reuse of the
same `render_tick = 5` and render-generation timestamp throughout both windows;
worker snapshot metadata and native ticks continue advancing. The worker updates
render generation only for a newer terrain packet, and Main uploads a greater
accepted render serial. This observed reuse is consistent with unchanged terrain;
it does not alone establish stale simulation or a new rendered image per native
tick. Keep the fresh snapshot-age statistic and older payload age separate.

The independent phase 1 [Windows
diagnostic](https://github.com/techrote/cybersand/actions/runs/41139717684) at
3b986726 retains actual palette `D3DCompile` HLSL, `ps_5_0`/`main` and flags
`0xc000`, beyond the earlier module-offset-only observation. All five cold cases
time out; the ordinary-flair exclusion first returns `E_FAIL` after 145.5123312s
wall/145.421875s thread CPU, then starts a byte-identical-source fallback at
flags `0xc002` which remains open. A failed API return, unfinished fallback,
isolated shader draw or warmed follow-up cannot qualify Main. The internal
compiler pass is not symbolized. The final phase 2 receipt at f20ae3ab also
confirms five 180-second timeouts: each retains 43 completed calls and an open
palette call 44. No atlas, warm execution or completed candidate is available.
Both phases remain nonqualifying; the attempted variants' failures do not prove
fundamental renderer incapability.

Available trace/source/runtime identities do not erase the retained 3b/f20
diagnostic workflow/source-copy omission. Keep the failed source-copy check
distinct from verified HLSL bytes and authentic compiler passthrough.

Phase-3 diagnostic source 512dbb9e / tree 4fb6655e preserves those negatives and
tests single-exit helpers at frozen shader hashes `0e462ec7...`, `06a0c122...`
and `cbad4e5b...`. Actual-emitted-source review and 96 exact local Linux atlas
comparisons support their bounded source/visual equivalence, not Main pacing
or Windows acceptance. Original Windows run 41144657058 is now terminal FAIL:
all four first cold rows time out at 180s. Artifact 13020549731 verifies all 791
inputs and ten copied diagnostic sources. Actual HLSL preserves the intended
single-exit transformation—50/51/3/19 returns become one—and the unified flair
call-site reduction. Catalogue-only/all-helper HLSL is unchanged outside the
intended two/four functions. All four palette call-44 APIs remain open after
43 successful preceding compiles; no returned palette error, fallback, bytecode,
atlas or warm run exists. Last same-thread CPU since begin at samples within
180s is 175.796875/175.953125/175.984375/176.093750s. These are censored CPU
observations, not completed-call timings or an internal-pass diagnosis.

The separate source-512 generic original/hoist diagnostic 41144657056 passes
Linux but fails both Windows cold rows at 180s, retained in artifact 13020508845.
It does not execute a single-exit candidate or Main. The approximately 15-minute
runner queue is preserved separately from actual case budgets. The audit binds
the original source/HLSL/log/artifact hashes, paired API events, prior source-copy
failures and 30-run ledger through 512. Seventy-five skipped jobs provide no
qualification or performance evidence.

The three actual local Main previews retain source 62d plus five declared local
shader/readback paths. Warning-helper and unified pairs bind their original
terminal hashes to the retained final reports; the catalogue pair does not,
and its whole-campaign custody is rejected even though both raw rows verify.
Unified cold acknowledgements are 8.183386/8.567439 seconds versus the clean 62d
local reference's 15.325078/14.794823 seconds. Its one-worker submission rate is
3.93% lower and Auto 3.38% higher in single uncontrolled-load samples. The
all-helper one-worker p99 is 115.327 ms versus reference 101.244 ms. Report this
mixed steady-state evidence alongside the startup improvement; it supplies
neither a statistical regression finding nor a guarantee of no regression.
All six rows observe one actual native participant and no steady gap over
250 ms. Input injection, initial resume, reset and teardown are exercised;
healthy automatic pause/resume, physical focus/devices and per-input displacement
remain outside this Main apparatus's direct assertions. Full hashes, raw quantiles
and custody negatives belong to the dated audit. Production shader selection
and resulting-head graphical/lifecycle qualification remain pending.

The exact-62d requirements review distinguishes existing assertions from two
measured-route gaps. UI005/UI003 already assert input admission, ordered edges,
neutral rearm and manual physics pause; LIFE007/008 assert real failure recovery,
stale-epoch refusal and joined retirement across the five-rig/navigation cases.
PACE records `raw.input_tape`, but its verifier does not require or validate it.
A future responsiveness claim must authenticate that existing ordered tape and
observe a non-neutral admitted command followed by its completed Rapier step;
neutral-command totals alone cannot prove response. After the unchanged sample
window/capture, add one healthy pause/acknowledge/resume round trip on the same
owner through automatic Main/physics callbacks, with clock quiescence while
paused and real clock/submission recovery after neutral rearm. Ordinary LIFE001
already covers healthy Rapier pause/resume separately; it does not supply this
measured graphical route's observation. Preserve the seven fixtures and all
30/180-second bounds. These are continuation requirements, not additional engine
work before resolving Windows startup, and introduce no invented FPS threshold.

#### Exact-HLSL compiler-only contrast

Diagnostic source `5de468478c37c8ae9e2d446ba348d4e3ecf54bd6` / tree
`8957ae44174226758069a534f8a4c03edce79e51`, parent 512, executed in
[41149030607](https://github.com/techrote/cybersand/actions/runs/41149030607)
on 2026-10-31 and is terminal FAIL. Two fresh compiler-only
processes reuse original call-44 HLSL and arguments at `0xc000` versus `0xc004`,
changing only skip optimization with validation enabled and a 180s cap each.
No Godot/device, production renderer setting or graphical acceptance cache is
changed. `compile-return.json` retains the actual API return/HRESULT and call
wall/thread/process CPU before blob capture/disassembly, allowing later
diagnostic timeouts to remain distinct from unfinished compilation.

Original artifact 13022287635 retains successful tiny preflights but two
full-HLSL timeouts, observed at 180.0135896/180.0126130s, with no immediate API
return, bytecode or final record. Total process CPU at timeout is
179.859375/179.984375s; the sole compiler-thread samples are
179.859375/179.968750s. These include setup and the small observation overshoot,
not exact completed-call durations or samples within180s. The final report's
`experiment_completed` labels a completed diagnostic matrix, not successful
compilation; both rows and the workflow remain red.

The exact source reproduces CPU-heavy bounded failure without Godot, an
executing ANGLE renderer, a graphics device or native World. Adding only skip
optimization did not complete this input, so the contrast does not establish
an O2-only or named internal-pass diagnosis. There is no completed-duration
ranking. Preserve the bounded reproduction for an owner/upstream compiler
decision; no tested variant or replay establishes fundamental renderer
incapability, visual correctness, Main acceptance or permission to change flags.

#### Separate automatic-matrix completion at the same source

Source-5de automatic matrix
[41149030614](https://github.com/techrote/cybersand/actions/runs/41149030614)
retains three cold timeouts and a late unified `cbad4e5b...` atlas completion in
artifact 13021809621. Actual palette call 44 receives the exact 179,152-byte
HLSL from the source-512 candidate that previously timed out, and returns
HRESULT 0 at original O2 flags `0xc000`: 170.0066407s wall / 169.984375s
same-thread CPU, with 1,213,964-byte DXBC. Call 45 is a small `gs_5_0` geometry
compile, not a palette fallback. The cold process completes in 175.903s;
its first submission is at 172.361599s. Preserve both original outcomes.

The subsequent copied-cache fresh process takes 4.160s, first submission
0.604374s, and all 16 PNG/native-framebuffer pairs exactly match its cold
candidate with finite channels and material coverage. Original Windows shader
frames remain unavailable, so this does not prove original-versus-candidate
Windows parity. Private application caches are isolated; OS/driver caches are
uncontrolled. These atlas timings are not Main acknowledgement, steady-state
FPS or native throughput; neither late cold submission nor warmed execution
satisfies the original 30s Main gate. No candidate/flag is adopted. The two
compiler-only failures above use the different 175,942-byte hoist-control HLSL.

The original ZIP SHA-256 is
`be79727df88f84eaeb9a53a72afc2fa60ecc54ed262e900d29bb1971a802a259`;
independent matrix/pixel receipts are
`c82e4efcdff3750fc564b770d96801b9dca9cc60197793d22d2d6d460e8d1307` and
`c85e66667f1efcd88c9c2e23f8ea09630a3d197b825683bd66b52f97bae5cf3d`.
The complete #312 ledger through 5de retains 37 runs, 112 jobs, 22 executed
logs and 21 ZIPs, index SHA-256
`3152fe21fe64a3573db8d1e14964834848efd5b0eed74ada772b03279dcdf50b`.

The [proposed owner continuation](../audits/2026-10-30-play-pace003-cold-startup.md#proposed-bounded-owner-decision-and-continuation)
keeps the Linux-validated hoist and offers separately registered palette-program
decomposition with exact HDR/PNG/compositing preservation, or an upstream
compiler/runtime investigation with a newly authenticated engine pin before
acceptance. Neither architecture is implemented or shown feasible. Proposed
changes stay in Godot shader/presentation, apparatus and docs, with any engine
pin/provenance addition explicitly registered and native/training excluded.
Keep original Main/pixel/one-worker/Auto gates and 30/180/240s limits; no hidden
warm-up, hardware/provider/renderer-flag switch or optional O0 matrix follows.

#### Offline artifact readback

For offline artifact readback, upload may omit an empty directory that existed
in the original in-job inventory. The prepared successor includes explicit
`offline_archive_readback=True`, which accepts this only for a generated directory
whose expected files are exactly empty; default verification and at-launch
cache/receipt/path checks stay strict. Required PNG/EXR and nonempty cache bytes
remain mandatory. Preserve the frozen verifier's original rejection, create no
replacement directories, and label successor readback separately from process
execution. Original Linux bytes pass that narrow readback; Windows still fails
on its actual timeout. This implementation has candidate-preview validation,
has not been accepted here, and is not part of tested 62d.

Published successor 28192d146d7b3d7475a92c1703d52bc94d155dd2 / tree
2f7884e656bce936862aaa64125517ce23d4919a fails ordinary Godot
[41150430766](https://github.com/techrote/cybersand/actions/runs/41150430766)
before engine-suite execution: two old sharding-test cleanup observers reject
the `owned_pgid` keyword. Retain that first failed log. The bounded correction
updates only those two test callbacks to accept/forward/assert the captured
group and clean up through `finally`, preserving existing assertions.
Corrected-head gates remain pending; no runtime, shader, deadline or graphical
measurement is changed or retroactively qualified by this apparatus correction.

#### Prepared completion-observation boundary

The shared monitor successor rejects completion first observed after the fixed
case deadline, including exit zero; it does not claim to know the earlier OS
exit instant. In-bound/exact-bound observations remain accepted, and subsequent
capture cleanup cannot retime them. The retained original monitor fails the
new adverse control; eleven monitor tests pass normally and optimized. Prepared
outer-runner guards avoid dead-leader live capture and Windows dead-wrapper
`taskkill`, retain the observed code/reason, and preserve POSIX descendant cleanup
using process groups captured at launch. Ten local Linux timeout tests pass
normally/optimized; the Linux-only group fixture explicitly skips on Windows.
Independent final review has no actionable findings. This is not a Windows test
pass, and the apparatus correction needs new exact-head qualification,
changes no deadline, and cannot relabel original 62d or phase-4 results.

### Existing measurement surfaces

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

The 2026-10-25 [worker activity repair](../audits/2026-10-25-water-inertial-native.md#worker-activity-publication-repair--2026-10-25)
adds geometry-bounded per-job signal grids, flag clearing and serial reduction.
Its [capacity accounting](../reference/configuration-reference.md) includes real
setup storage and work even for jobs that emit no activity signal. Earlier
pressure/cache/dormancy timings retain their original source and do not qualify
this scheduler's total cost. The follow-up contiguous layout preserves the same
payload and clear/reduction work while reducing grid ownership to two buffers
per World; its constructor-allocation counts and failure-sweep timings are
source-bound correctness evidence, not controlled speedup ratios. The earlier
unpacked pressure campaign keeps its own source. The
[fresh packed-source repeat](../audits/2026-10-25-water-inertial-native.md#fresh-packed-source-total-cost-repeat)
has its own prospective registration, complete total-cost accounting and
independent reduction; it retains faster awake warm medians and slower disturbed
churn/forced-head intervals, rather than implying a universal improvement.
`TickStats` chunk/temperature allocation counters
also do not count all ordinary heap allocations; explicit probes and source
inspection have their own recorded boundary.

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

## MS-001 apparatus cost boundaries

The [reference pack](microscenario-reference-pack.md) retains native tick timing
separately from before/after-host observation timing and CLI advance-loop wall time.
Actual native work/capacity counters are copied after successful completed ticks;
quarantined partial-tick results are not exported as successful measurements.
Queue occupancy/high-water, all heap allocations, per-worker utilization and
per-cell sleeping state remain unavailable. Phase-job counts are not utilization.
None of these measurements substitutes for renderer, Rapier or whole-frame timing,
or certifies a contended hosted runner as the user's target PC. The MS-001 Stress
profiles use these counters only as comparable bounded workload telemetry: observer-off
runs omit optional work/timing records and must retain identical authoritative outcomes.
