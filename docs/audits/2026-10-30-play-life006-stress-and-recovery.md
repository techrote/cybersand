---
title: PLAY integrated lifecycle churn, stopped-session recovery and pacing
status: Current
document-kind: audit
scope: Fresh b55ce690 reconciliation; source-bound LIFE006–008 implementation and PACE003 measurement, retained failures and remaining qualification
canonical-for: []
last-reviewed: 2026-10-30
related-documents: [../systems/player-control-playground.md, ../architecture/data-ownership-and-lifetimes.md, ../operations/local-build-and-validation.md, ../operations/profiling-observability-and-performance.md, ../reference/status-and-roadmap.md]
---

# PLAY integrated lifecycle churn, stopped-session recovery and pacing

## Authority and reconciled baseline

This is manual implementation/qualification for [#269](https://github.com/techrote/cybersand/issues/269)
on branch `codex/play-life006-integrated-stress-20261030`, based on main
`b55ce690f9a3d2ca3026674a2e9c6a7635966f59`, tree
`9b2ec54912235d354c17f21c4ebc2a1524ad55ec`. PR #307 merged that baseline.
AGENTS, SCHEDUSWARM, handover, roadmap, ownership/threading, ADR-003/010,
CI/release/current-provenance and retained M11 contracts were reconciled with
live issues, branches, PRs, reviews, jobs and original artifacts.
Scheduswarm remains paused with automatic dispatch false. No queue dispatch,
successor automation or competing branch is created. The #290/#295/#298/#301
publisher stack and #272 fallback remain separate ownership.

The [owner decision](https://github.com/techrote/cybersand/issues/263#issuecomment-6522029843)
already accepts merged #302 for genuine outstanding native jobs, Main/input
responsiveness and stop/drain/join resource ordering. #304 is optional,
non-blocking and retains its failed graphical result. Nothing in this work
debugs, reruns or makes #304 a prerequisite. #266/#267/#273 remain closed;
#268/#269/#270/#263 remain open.

| Exact b55ce690 post-merge gate | Original run | Outcome |
|---|---|---|
| Documentation/provenance | [41103287221](https://github.com/techrote/cybersand/actions/runs/41103287221) | Passed, attempt 1 |
| Native | [41103287295](https://github.com/techrote/cybersand/actions/runs/41103287295) | Failed, attempt 1; TSan suite reached its 15-minute execution limit, exit 124 |
| Windows/Linux Godot | [41103287549](https://github.com/techrote/cybersand/actions/runs/41103287549) | Passed, attempt 1; 201 Windows and 213 Linux applicable test processes |

The Native failure is not erased by PR #307's passing corrected-head
[Native run 41079264911](https://github.com/techrote/cybersand/actions/runs/41079264911).
The main log contains 153 successful cases in the same order as the passing
164-case PR run, no TSan diagnostic before timeout, and broadly 1.25–1.28 times
longer major-case intervals. Native sources, Makefile and workflow are unchanged
between those sources. This supports cumulative suite-budget exhaustion;
without a captured interrupted stack it does not establish the exact stopped
state or disprove a hang. Later ordinary and ASan/UBSan steps did not execute.
Neither timeout inflation nor an unchanged-head retry is used here.
The two original job-log SHA-256 values are
`43a392e73e05b629b94b076a70053754b7de02a80b27c576c8969f3dce1f6691`
(failed main) and
`8fb0797420b0d4767529aa1dd84c3bbb8570ff6de1a0b7865263f5c74443f32d`
(passing PR).

All nine original Godot artifact archives were downloaded and checked against
provider size/digest, ZIP CRC and safe member paths (530 members).
Windows log hashes and the 80 native inputs per shard matched the receipts;
760 tested inputs comprised 634 exact Git bytes, 124 explained CRLF
transformations and two materialized LFS payloads, with no unexplained mismatch.
Optional physical-stress and serial-equivalence jobs are skipped, not passing.
The prior #307 mouse-layout failure at run41074846660 remains negative evidence.
Its corrected 55/0 mouse regression and UI005 90/0 subsequently passed.

## Coverage matrix and evidence classes

The following reused results are exact-b55 execution, except #302's separately
accepted special-runtime evidence. They are not execution claims for this
branch. New results require their own source/input/runtime receipts.

| Requirement | Existing demonstrated boundary | This slice and remaining boundary |
|---|---|---|
| Fifty real scene lifetimes per OS | LIFE001: 50 actual Main/worker/Rapier lifetimes, 1165/0 per OS; original F5 course route | LIFE006 adds 50 integrated-selector lifetimes, alternating rigs/options/policies, Build/Reset and actual F2/re-entry. The historical 50-cycle target is retained, not reduced. |
| Native policy reconstruction/refusal | LIFE002 335/0 per OS; actual native refusal retains old accepted World/actor and closes candidate | LIFE006 repeats accepted Current/pressure reconstruction. No solver coercion/default changes. |
| Outstanding preparation and shutdown | LIFE003 150/0 per OS, real native candidate/physical graph with explicitly synthetic precommit barrier | LIFE007 retires a real pending candidate belonging to a failed composed owner. #302 already supplies the mandatory native-busy boundary. |
| Populated input/lap retirement | LIFE004 335/0 per OS, old admitted command, queued edges and lap; forced placement and retained-snapshot reinjection are test instrumentation | LIFE007 rejects an old accepted typed command at the fresh run/epoch fence. Local counter reuse cannot confer authority. |
| Actual native failure and recovery | LIFE005 30/0 per OS covers ordinary three-reference-body reset, not prepared SetP recovery | LIFE007 reproduces actual capacity failure for all five composed rigs and exercises explicit fresh-scene recovery through normal construction. |
| Input/device lifecycle | UI005 90/0 per OS; keyboard-only, selected/unselected device events, focus cancellation and neutral rearm | Focus predicate/device enumeration and controller events are synthetic. Physical devices and OS event delivery remain #270; these are not passed by counter assertions. |
| Rendering/terrain/stale effects | Existing render-generation/transaction/effect-admission tests cover serial/epoch refusal, failed terrain, queued and already-copied effect cancellation; some use stopped workers or doubles | Keep model-only and stopped-worker proof separate. This slice does not claim a full arbitrary delayed/missing/out-of-order live delivery campaign or all equipment interleavings. |
| Native-busy responsiveness and resource ordering | Owner-accepted #302, 34/0 on each OS with real claimed native phase jobs outstanding | Reused without repeating optional #304 or claiming changing-framebuffer evidence from it. |
| Pacing and wait attribution | PACE001 100/0, PACE002 490/0, WAIT001 80/0 per OS: headless progression and one snapshot handoff mutex | PACE003 records actual graphical submissions separately, consecutive native completions, packet age/coalescing and narrow Main waits; no stable FPS, scanout or complete lock attribution claim. |

## Demonstrated defect and implementation

The original actual-native capacity-one probe installed Stuntbuggy, then
failed the first native tick. The selector disabled Restart; direct R/reset
left a real pending prepared candidate with the old failed actor and no
recovery. A prepared replacement intentionally requires a healthy retained
World. Reusing that route after quarantine cannot repair a failed composed
World. The original negative probe completed 7 assertions with one failure
and is retained with its source, log and baseline input hashes.

The fix keeps the native healthy-World guard. In
[`main.gd`](../../godot/scripts/main.gd), explicit Restart of an accepted
exploratory five-rig course copies its exact accepted definition, liquid setup,
policy, actor/options, gameplay environment profile and host quality settings.
It schedules one whole-scene reload. Old Main exits, closes pending/accepted
Rapier graphs and joins its worker before the fresh Main starts a live owner.
The fresh scene consumes the one-shot copied-value envelope and performs one
ordinary prepared construction, paused. No partial failed cells, event queue,
lap history, live node/RID/native pointer or old command is transferred.
Unsubmitted selector choices are ignored. Failure remains visible; no automatic
retry, native fallback, live solver mutation or automatic resume is added.
Review also found that `microscenario_mode` changes when a request queues,
before acceptance. Recovery therefore reads the completed worker context's
mode. LIFE007 stages a real pending Inspect candidate while the accepted
course remains Play and requires the recovered mode to stay Play.

F2 cancels both a still-deferred restart and a pending recovery replacement.
The navigation path clears the envelope even in SceneTree's intermediate
no-current-scene state. Review found this necessary: a second deferred scene
change can replace a not-yet-entered scene. LIFE008 exercises both immediate
orderings and deferred supersession; a later Play entry must open ordinary
selection without resurrecting the abandoned session.

The first navigation regression also exposed a popup input-routing gap:
the selection PopupPanel is a Window with its own Viewport, so its F2 event
does not reach the root autoload's input group. The panel now forwards its
`window_input` event to the same FeatureNavigation handler. The test keeps
the popup visible and uses actual injected InputEventKey routing; it does
not hide the popup or replace navigation with a direct synthetic callback.
This is automated engine-event evidence, not a physical keyboard/OS-focus test.
The first failed navigation run is retained rather than relabeled.
The corrected LIFE008 campaign passed62/0 in7.643 seconds: all three
orderings, exactly six ready Main hosts, maximum one observed live owner,
accepted/pending graph retirement, old worker/adapter destruction and normal
selector re-entry. A second developmental failure retained a test-local worker
reference in the fault predicate; a named Node-bound predicate removed that
instrumentation reference while preserving the destruction assertion.

The panel now offers Restart for recoverable stopped sessions and displays
stopped status ahead of a stranded pending-build message. Protected/blind
fixtures and non-course recovery retain their original routes. The same
exclusive asynchronous worker, native phased pool, immutable packets and
main-thread Rapier remain the owners. No native source, runtime, solver default,
thread policy, scientific fixture or release gate is changed.

## New fixtures, bounds and local development evidence

LIFE006 uses actual `main.tscn`, launcher button signals, F2 input, the original
worker/native World and real Rapier. Five separately bounded wrappers each
perform ten lifetimes. Each lifetime builds, immediately rejects a duplicate
Build, replaces with another rig/configuration, resets while pending form values
differ, and exits to the launcher. Assertions inspect retained immutable packets,
epochs/terrain receipts, old bodies/private viewports/RIDs/colliders, worker
join and worker/native-adapter destruction after retained references drop.
This is 100 Builds, 50 Resets, 150 accepted graph retirements and 50 F2 joins.
No process-wide allocator/leak-freedom claim follows from these object fences.

The initial local b55 plus six LIFE006-file campaign passed **403/0 per wrapper,
2015/0 total**, in 43.124, 39.148, 41.771, 38.366 and 36.421 seconds.
It predates the recovery production patch and is preserved as that source slice.
Each wrapper has a 160-second internal total, 15-second operation bound and
180-second external limit. CI discovers all five unchanged.
Initial local operation distributions (50 samples each) were:

| Operation | p50 ms | p95 ms | p99 ms |
|---|---:|---:|---:|
| Initial Build | 1138.846 | 1285.950 | 1567.696 |
| Replacement Build | 1104.960 | 1444.652 | 1764.523 |
| Applied Reset | 1127.424 | 1400.876 | 1584.621 |
| F2 plus observed join | 58.371 | 84.106 | 89.944 |
| Complete lifetime | 3921 | 4437 | 5144 |

LIFE007 sets native construction capacity to one and restores the project
setting before the initial scene enters; thus the fault is real but its
construction-only injection does not poison the fresh recovery host.
It does not claim recovery from an unchanged impossible capacity.
The first corrected test passed **147/0** across all five rigs, with recovery
1.273–1.446 seconds and complete fault/recovery/exit cycles 2.778–3.328 seconds.
Three rigs additionally retained a real pending graph at recovery.
The test-only Main subclass counts completed calls after `super`; it supplies
no fake World/failure. Actual Rapier and the last valid image remain frozen,
Main/physics callbacks continue, emission admission refuses and native failure
count stays one. After restart both native and Rapier clocks advance.
LIFE007/LIFE008 use 150-second internal and 180-second external limits.

After the accepted-mode review correction, LIFE007 passed **150/0 in15.996
seconds** with all three real pending Inspect requests rejected as recovery
authority. The final local input fence covered773 execution files; no input
changed during that run. The immediately preceding production/navigation
regression batch passed LIFE007147/0, UI00590/0 and LIFE006 Stuntbuggy403/0,
also with a complete unchanged-input fence. These are distinct local source
slices, not claimed Windows or final hosted executions.

| Final recovery input | SHA-256 |
|---|---|
| Main | `6b4bedb5dbc48dc6562e4d5599196194cf0bcb7254c9d4c6447456e7d497ba34` |
| Session panel | `104fe4dd52bc4e4eaecd14eaadb0737662f71e42e9150379db4ddc59c083e086` |
| Feature navigation | `fb8357f636d918762852fa804df55275046c2d38f47bd52888a6d77cda68694c` |
| LIFE007 | `f5df4e4c7eee4b85bb39bd1912148f8878bdf886843267619f241ce908e3df6d` |
| LIFE008 | `8210c58df1756d9c8138380f0993fbc0275289bd589e6db5e8817f6139cd7bfd` |

Retained development negatives include the original production reproduction;
a first LIFE007 31-assertion/three-failure run caused by two wrong test oracles
(observation requested while suspended; expecting failed snapshot serials to
continue), an isolated parse error, and a launch without writable XDG paths
that failed before test execution. The corrected assertions require a
post-unsuspend issued observation and measured actual Main callbacks, without
weakening native quarantine or retirement. These failures are not deleted or
included in passing counts. Final source/head execution is separately recorded.

## Performance apparatus and interpretation

[`run_pace003_campaign.py`](../../tools/play/run_pace003_campaign.py) runs
fresh-process one-worker/Auto pairs with the same authored rig, policy,
960×540 viewport and Rapier-tick-indexed intended input tape.
One worker is still asynchronous. Native/Rapier admission skew is observed,
so this is not exact replay-equivalent action-at-native-tick comparison.
The existing synchronous native references remain their own workloads; no
equivalent synchronous composed Main host is invented for this campaign.

Every 15–30-second measured window retains raw Main/physics callback durations,
actual `frame_post_draw` submission intervals when graphical, native tick
timings/participants/phases, snapshot ages/serial coalescing and deadline
overruns. Owner-only instrumentation copies each distinct native completion;
Main reads those arrays only after worker stop/join. Its query/copy cost is
recorded separately, included in wall pacing and excluded from the native timer.
Main wait measurement is the equivalent WAIT001 snapshot-lock acquisition,
not all UI/renderer/driver or command locks. Overruns are deadline-reset
counters, not an invented queue-depth measurement.

Headless rows contain no rendered frames. Graphical rows retain a normal
post-window PNG, dimensions, nonblank check and digest without forcing a
render. Actual image inspection, software rendering, frame submission and
physical display scanout are distinct. There is no held-native experiment,
human feel, physical focus or controller qualification. Long frames and
negative scaling remain evidence rather than failed performance thresholds.
The new hosted workflow uses literal GitHub-hosted Windows/Linux jobs,
original retained runtimes, pinned Godot and unconditional raw artifact upload.
Each measurement process is limited to 180 seconds, import to 240, with no retry.

### Executed local pacing result and graphical negative

Both first campaigns used the same773 execution inputs and retained runtimes;
post-run source/runtime fences and offline headless-log readback passed.
The workload was Jet Barrel, Current preset0, keyboard-only, free play,
overview,960×540 and a two-second warm-up before each15-second window.

| Headless measurement | One worker | Auto |
|---|---:|---:|
| Consecutive native samples | 900 | 897 |
| Completed native ticks/s | 59.989 | 59.792 |
| Native p50/p95/p99, ms | 0.055093 / 0.125309 / 0.284600 | 0.060160 / 0.207933 / 0.459234 |
| Rapier completed ticks/s | 60.056 | 59.925 |
| Allocated capacity / observed maximum participants | 1 / 1 | 4 / 1 |
| Parallel-dispatch ticks | 0 | 0 |
| Snapshot publication age p95/p99, ms | 16.765 / 17.833 | 17.422 / 18.913 |
| Snapshot mutex wait p99/max, microseconds | 34 / 378 | 184 / 1226 |
| Serial coalescing / deadline-reset overruns | 0 / 0 | 0 / 0 |
| Initial Build / Reset, seconds | 1.027 / 1.185 | 1.223 / 1.219 |
| Worker stop/join, ms | 8.678 | 17.625 |
| Scene retirement, ms | 51.541 | 102.645 |

There were15/0 assertions per row and zero owner/Main tick-boundary difference.
These results are headless progression, not rendered FPS or parallel scaling.
Auto allocated four workers but exercised only one participant and zero parallel
phases. The retained static-terrain render payload can stay old; its timestamp
and tick gap are not automatically queue backlog. The headless campaign
report SHA-256 is
`bee1de5fdf11deb465876873066a9cbb159946edab0bed7edf97e76d59c8cfa2`.

The first graphical process used Xvfb, OpenGL4.5 Compatibility, Mesa25.2.8
llvmpipe/LLVM20.1.2. It **failed** the30-second actual course/actor/terrain
installation assertion and exited1 after66.349 seconds. It never entered the
measurement window and produced no PNG or rendered interval statistics.
The campaign stopped on that failure; Auto graphical was unexecuted, not a
passing skip. The180-second external bound was unchanged and no retry occurred.
The failed report SHA-256 is
`7dd0fec989da86622a984f2851f669398b501ad5de74d8bd8ef8a13c37657c3b`.

The local graphics environment lacked the hosted workflow's explicit
`LP_NUM_THREADS=2`, `GALLIVM_PERF=nopt` and software-render selection.
That is a recorded condition, not grounds to discard the failure. Its cause
is unresolved; do not label it a proven native hang, renderer defect or stable
frame-rate result. The first exact-head hosted graphical runs are required
new platform evidence, not reruns that replace this local negative.

## Runtime custody, review and acceptance gate

| Runtime | SHA-256 |
|---|---|
| Godot Linux executable 4.7.stable.official.5b4e0cb0f | `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75` |
| Linux CyberSand | `496bf3df06be2c6bf47b2e5e4ea525ed4d969c3a34cf1a97d71e4668cdc250e6` |
| Linux Rapier | `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a` |
| Windows CyberSand | `e66b9b04b546b09cb4feea204373faf12a7248abf1701da88fc6ecf87b666ecb` |
| Windows Rapier | `b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7` |

Local Linux: kernel6.18.57, glibc2.39, AMD EPYC9V74, nine exposed logical CPUs,
cgroup quota eight CPUs, approximately10GB RAM. Shared-host load is uncontrolled.
The exact execution manifest records source SHA/tree, every consumed file,
local deltas where present, runtime/provenance hashes, OS/hardware,
command, settings, duration, raw samples and log/PNG digests. Source/runtime
inputs are fenced before and after each campaign. Materialized LFS was checked;
historical M11 records are not edited.
The initial documentation/current-repository checks failed because five
companion-workspace reference files were absent. They were restored exactly
from the same pinned `6a58311982941b75f46e22109a0829e5acb83c7e` commit used by
Documentation CI, outside the source checkout, with Git blob/SHA-256 receipts.
Both checks then passed. M11 passed its original18 records/28 source hashes.
The frozen32-query retrieval evaluation hit19 at rank1 and32 at rank5;
the separate12 PLAY questions hit11 at rank1 and12 at rank5. The three new
questions retrieved their canonical sections first, and their expected
ownership/evidence qualifiers were read against source. These lexical results
are not a claim of general answer correctness or a modified frozen benchmark.

Root performs substantive source/ownership/concurrency/evidence review in this
run; supporting agents separately inspected the navigation race and provenance.
Any GitHub owner-account COMMENT is engineering review, not independent-account
approval. Final PR/#269 receipts must name the actual tested head, base, all
required Documentation/Native/Windows+Linux Godot/PACE003 outcomes and original
artifact identities. A failed required gate blocks merge; no baseline green or
local subset substitutes for it.

The canonical changes are the player contract, ownership lifetime note,
profiling interpretation, local invocation, roadmap, handover and retrieval
routes/questions. ADR-003/010 semantics, native interfaces/capacity/defaults and
scientific fixtures are unchanged; no new architectural decision is implied.
Keep #269 open until the remaining live-delivery/effect adversarial dispositions,
mandatory exact-source gates and reviewed acceptance matrix justify completion.
#268 is not automatically complete: its source/display/status and device/focus
acceptance must be reconciled with #270's explicit physical/human checklist.
In particular, Main's current debug status exposes publication frequency/age,
native tick/overruns and configured thread capacity, but not a separate actual
task-participant readout or skipped/coalesced-publication counter. PACE003's
offline measurement does not implement that in-product status requirement.
Complete it or obtain an explicit issue disposition before treating #268 as done.
No PLAY promotion or #270/#263 closure follows from this implementation.
