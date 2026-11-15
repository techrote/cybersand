---
title: Camera stack accepted-main reconciliation evidence
status: Current
document-kind: audit
scope: CAMERA-STACK-RECON-001 source audit, isolated implementation and source-bound platform qualification
canonical-for: []
last-reviewed: 2026-11-15
related-documents: [../operations/camera-stack-reconciliation.md, 2026-11-15-camera-stack-source-inventory.json, 2026-11-13-native-pixel-final-integration.md]
---

# CAMERA-STACK-RECON-001 — reconciliation evidence

**Recommendation: CONDITIONAL; no production merge.** This record is specific to the independent
accepted-main reconciliation. Historical component passes are not resulting-source
qualification and the owner's Windows stuttering verdict remains unaccepted.

## Intake and source ownership

GitHub live inspection on 15 November 2026 found default branch `main` at
`018bd09503d7f079ddac52e225c2f7daf8d678bf`, tree
`dd4eed8f95cfe21197a98fdc7ef663bee873dc94`. Its parents are
`dea4e53dd71d6e0af71775593fdc9197a7633e3e` and
`9bcfde77b9ac4fc2e2fac225cc8873936d5579e5`. It is the owner-merged #582 result.
The camera stack's common main merge-base is
`ac0d9fb944cb5a81369d03c0c3bc5eab50ab6742`.

The [machine-readable audit](2026-11-15-camera-stack-source-inventory.json)
records exact heads/trees/parents, all independent and cumulative paths,
intervening commits and overlap. None of the independent component changed paths
was already byte-identical to accepted main at intake. A subsequent independent
patch-ID check also found no already-equivalent non-merge commits on accepted
main: 16 camera commits, 38 guard commits, 16 Lab commits and 32 trace commits
were checked against their actual independent bases. The camera's complete
18-commit ancestry additionally contains two merge commits. Patch equivalence is
not substituted for semantic source review. GitHub still reports #566 base SHA
`ac0d9fb9` although the actual `main` ref is `018bd095`; that stale PR metadata
is recorded separately and does not define the accepted-main integration base.

| Independent layer | Files | Paths shared with #582 delta | Paths shared with all accepted-main changes since fork |
| --- | ---: | ---: | ---: |
| #566 camera | 65 | 6 | 9 |
| #593 receipt/guard | 15 | 0 | 1 |
| #606 Engine Lab | 8 | 0 | 3 |
| #609 diagnostics | 14 | 0 | 1 |

`git merge-tree --write-tree main 214de85a` identifies only five textual conflicts:
documentation index, development handover, configuration reference, retrieval
corpus and status/roadmap. The sixth shared documentation path (retrieval index)
auto-merges. Main/shared Workbench/PAINT camera hunks also auto-merge with Flatten;
this is not a semantic test. Review preserves full-canvas material capture,
authoring-generation fences, baseline installation and _poll_flatten ordering.

The native inputs and published libraries come from accepted #582, not from the
older camera package. They retain original build provenance `6d6e2cd6`; no runtime
is relabelled as newly compiled from the application integration SHA.

The isolated composition retains accepted main as its first parent and the
inspected #566 head as its second parent. Its selected tree excludes the obsolete
campaign orchestration; the parent preserves the original qualified camera and
palette-transition ancestry rather than rewriting a provenance gate. This is a
two-parent composition commit on the isolated branch. No main or component
branch ref is moved, no history is rewritten and no GitHub PR is merged.
The [per-path source map](2026-11-15-camera-stack-source-map.json) binds every
retained application and qualification change to its origins and content hash.

## Design choices

| Choice | Technical reason | Reversal or future admission |
| --- | --- | --- |
| Retain #566 coordinate/shader/recording algorithms | Existing exact sampling, native picking and graphical evidence; no native cadence dependency in spatial mapping | Any algorithm change needs the same framebuffer/picking/effects/recording controls |
| Retain only strict #593 receipts; use uploaded-mask pose | Avoid importing owner-rejected guarded-live presentation, while preventing absent/stale receipts from leaking live RID geometry | Admit the worker's proven temporal selector through the one overlay submission function |
| Keep useful #606 rates/FPS/VSync, narrow telemetry | Independently useful experiment controls; requested cadence differs from completed work | Keep fixed-step/time-dilation warning and achieved-rate evidence |
| Keep ACK immediate | Original countdown can be repeatedly restarted by uploads; active worker owns fixed-deadline correction | Review worker's ACK/history transaction and its deadline/reset tests together |
| Replace old package/workflow pins | Old builders would require pre-#582 native inputs and guarded defaults | Reconciliation package retains accepted native identity and tests the extracted payload |
| Preserve #609 ownership | Its original PR is diagnostic-only and newer repair evidence still includes a real coherence failure | Refresh worker head, review root cause, then import the minimum proven delta |

## Qualification record

The [machine-readable qualification ledger](2026-11-15-camera-stack-qualification.json)
binds results, raw-evidence hashes and remaining limits to actual source/runtime
identities. Application composition is `9a3546836fbdecf7c97e13395428ad147eb59f71`,
tree `7c646e85163716bc9e244b2d145058a1ededb77b`. Its parents are accepted main
and inspected #566. Follow-up `049cdd31fb1b5b74b4f7285a995f6e09bcb11b36`, tree
`fa7e336300e0c509bb6b81b54ef15888d3613b72`, changes only the Windows runner,
its workflow and source map. All application, native and test fixtures are
byte-identical between these two commits.

[Source-bound run 43697168212](https://github.com/techrote/cybersand/actions/runs/43697168212)
passed its Linux native/real-X11 job on `9a354683`. It used actual Godot 4.7 and
Mesa llvmpipe LLVM 20.1.2, not a hardware GPU. The complete Linux artifact is
`14154779339`, SHA-256
`351d623b9ee40df76abbb54342c9d35379f54103bcefed31bed658f3dd458a72`.

| Resulting-source coverage | Actual outcome and scope |
| --- | --- |
| Camera and coordinate consumers | Nine invocations passed: coordinate/picking 1,687 checks; recorder 178; exact framebuffer 339; physical effects 66; vapour 26; palette crossfade 1,274; additional actual material/water framebuffer controls |
| Receipt, recording, Lab and clocks | Native receipts 27; graphical native recording 80; graphical Lab 82; mismatched actual clocks 59 |
| GEN-007 architecture | 21 qualification rows passed, including five styles, actual UI installation, native material identity/readback, v1 reconstruction, v2 architecture and separate-process reopen |
| Existing generator regressions | Contract 1,952; native generation 812; UI 56; author/reopen 73/22; multistyle author/reopen 79/31; canvas 164; edit ordering 144; all five legacy profiles retained |
| GEN-008 Flatten | 512-square / one worker: format 102; author/reopen 195/43; owner failure/recovery 53/44; genuine Linux partial-write/SIGXFSZ negative controls retained |
| Combined PAINT / Agent Art | Real graphical author/reopen at 512-square with one and four workers; each 197/51 checks; 14 framebuffer captures |
| Downstream overlays and shutdown | Independent local application `9a354683`: actor prototype 157, rig 694, Blacksite 261, five graphical PLAY-UI007 navigation fixtures 71 each; all 1,467 checks passed; actual pointer Return navigation retires sessions and joins workers |
| Moving low-rate lifecycle | Actual running pilot at Pixel target 1 Hz: native tick 2→4, Rapier 121→243, 127.49-cell actor motion; 16 checks passed; synchronous native/Rapier shutdown 1,022.869 ms and fresh owner restart. This is a measured headless lifecycle, not a hard-real-time guarantee. |

An independent local graphical repetition of architecture, Flatten and combined
authoring also passed on `9a354683`; a separate raw-evidence inventory covers
127 logs/images, with its filename and SHA-256 recorded in the ledger.
Local graphics used Mesa 25.0.7 llvmpipe LLVM 19.1.7. Linux legacy fixtures use
the retained historical same-platform reference plus portable material equality;
the Windows package separately captures a fresh complete accepted-main reference.
Neither is represented as hardware-DPI or owner-motion approval.

Local prerequisites: actual Godot `4.7.stable.official.5b4e0cb0f`, accepted Linux
native SO `0cbef228d1ce28772ac3f4d6f3dcc2cc7778775abe631bd39e71239eda404d7b`,
selected Rapier SO `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a`.
The environment's default `godot` points to 4.6.3 and was not used for qualification.
The ordinary documentation fixtures additionally require the exact pinned
companion `6a58311982941b75f46e22109a0829e5acb83c7e`, as in repository CI.

The first local Xvfb attempt failed to bind Unix sockets; elevated display
startup was rejected by environment approval policy. A subsequent supported
route used an already permitted loopback TCP display port, without changing the
policy. Actual Godot X11/GL compatibility execution on Mesa 25.0.7 llvmpipe then
passed the development Engine Lab graphical check (82 assertions). Headless
development checks passed the receipt fixture (27), independent clocks with
positive upload/ACK observations (59), Engine Lab (80), native recording (59)
and recorder unit/negative controls (178). These are development-tree findings,
not final-commit acceptance; resulting-source receipts follow separately.

The actual recording fixture exposed a retained startup defect: after Main ACKs
a publication, an owner status snapshot retains its render serial without patch
bytes. A new recorder mistook that receipt for a new publication and aborted
before its requested full refresh arrived. The original `ingest_snapshot`
function is identical on main and all four historical heads (SHA-256
`b4d804c3f0c0f426d6449b91da696059e6c7935d6110ec437b621a3562b7cbf4`). The candidate
adds seven lines that wait only for an unprimed, non-full, completely empty
status receipt. Malformed full refreshes and genuinely newer empty publications
after priming still fail. The original failed manifest is retained. The native
positive test writes at least three BMP/IDs/JSON frames (six in the qualified
initial 9a Linux graphical run and eight in the 049 Windows run), checks all 12,513 ROI cells against
native readback and independently decodes BMPs; it does not claim exact physics
replay. No worker, publication or ACK logic changed to fix this defect.


## Performance and cross-clock findings

The completed local controlled comparison used detached accepted main
`018bd095` and application `9a354683`, identical retained native/Rapier bytes,
Godot 4.7, one software-rendered host and serial ABBA order. Each of four cases
has four phases, 32 warm-up frames and 240 measured frames per phase: 480 measured
frames per application per case. Complete raw capture is preserved separately;
the qualification ledger retains its SHA-256 and reduced source-bound results.

| Workload | Main p50 / p95 frame ms | Candidate p50 / p95 frame ms | Candidate p50 change | Achieved observation FPS, main → candidate |
| --- | ---: | ---: | ---: | ---: |
| Paused slow pan, 512-square | 53.135 / 75.150 | 57.665 / 80.013 | +8.53% | 17.67 → 16.15 |
| Active sand/water, 2048-square, four workers | 77.243 / 136.835 | 78.052 / 101.457 | +1.05% | 11.98 → 12.54 |
| Manual editing, 2048-square | 60.041 / 90.802 | 63.430 / 95.575 | +5.64% | 15.35 → 14.60 |
| Actor Follow with effects, 1024-square | 127.989 / 186.435 | 135.049 / 191.612 | +5.52% | 7.26 → 7.00 |

**All four pooled median frame times worsen.** Active 2048-square p95/p99 improve
25.85%/38.77%, while Follow p95/p99 worsen 2.78%/4.52%. The historical same-source
shader control remains separate: pooled legacy/native-coordinate medians
130.798/133.282 ms, a 1.90% increase; pooled p95 220.342/200.245 ms. The original
first-pair `median_frame_ratio` must not be substituted for the four-arm result.
PASS on the runner means complete validated capture, not non-regression.

Manual authoring also regresses in observed response latency: native receipt
p50 144.909→176.453 ms and presented-result p50 145.007→176.519 ms; their p95
values rise 250.835→261.179 ms and 250.863→261.192 ms respectively. There is
substantial repeat variation (candidate manual medians 78.395 and 55.670 ms),
so these remain measured adverse results without a statistical-certainty claim
or attribution to one algorithm. The Follow case has no material uploads or
moving native material during measurement; it does not reproduce the principal
actor-versus-changing-terrain publication defect.

The host was a Linux x86-64 Xeon Platinum 8370C / Mesa llvmpipe software renderer.
FPS above is measured frame observations divided by their elapsed interval,
not monitor scanout. Active workloads have equal initial conditions but can
complete different numbers of asynchronous ticks. Samples are bounded and p99
is descriptive. Native tick timings are deduplicated Main-observed completed-tick samples,
not timings for every native tick. Main and shader timers overlap. CPU/RSS observations include
setup and must not be presented as steady-state frame cost. These measurements
retain the software-renderer penalty; they do not establish an NVIDIA outcome.

The hosted graphical clock fixture also preserves actual overload. Requested
Pixel/Rapier/publication rates of 60/60/60 achieved roughly 6.89 native ticks,
5.91 completed actor-session steps after Rapier and 4.92 successful uploads per second. Uncoupled
15/120/15 achieved 6.56/48.72/6.56; uncoupled 120/30/60 achieved
6.98/29.91/6.48. Those are independent-fixture measurements, not main/candidate
performance ratios. They demonstrate honest target/achievement separation and
valid upload/ACK ordering, not smoothness or fulfilled requested rates.

The original #566 performance apparatus lacks completed-Rapier and immutable
snapshot/current-uploaded-material age counters across both applications. An
apparatus-only extension adds those observations through common interfaces and
rejects identity changes/counter resets. It never selects an actor pose or alters
clock operation. Worker wait duration, backlog depth, GPU-present timestamps and
previous crossfade texture age remain explicitly unmeasured.


The independently verified hosted ABBA on `049cdd31` also completed all 16 phases
against exact accepted main. Its application source manifest matches `9a354683`.
[Job 132771765531](https://github.com/techrote/cybersand/actions/runs/43699476503/job/132771765531)
used a GitHub-hosted AMD EPYC 7763 / four logical CPUs / Ubuntu 24 / Mesa 25.2.8
llvmpipe LLVM 20.1.2, with the same retained native library and original #566
apparatus. Both candidate repeat medians exceeded both main repeat medians in
every case; bounded repetitions still do not establish a causal confidence bound.

| Hosted workload | Main p50 / p95 frame ms | Candidate p50 / p95 frame ms | Candidate p50 change | Observed FPS, main → candidate |
| --- | ---: | ---: | ---: | ---: |
| Slow pan, 512-square | 42.116 / 52.177 | 42.490 / 52.724 | +0.89% | 22.93 → 22.61 |
| Active 2048-square / four workers | 107.895 / 140.708 | 111.053 / 139.907 | +2.93% | 9.16 → 8.94 |
| Manual authoring, 2048-square | 42.441 / 54.835 | 43.099 / 53.732 | +1.55% | 22.64 → 22.33 |
| Actor Follow, 1024-square | 103.571 / 117.240 | 105.274 / 118.530 | +1.64% | 9.44 → 9.30 |

All four hosted p99 values are higher. The separate hosted shader control's pooled
median increases 96.971→100.865 ms (+4.02%), p95 102.220→106.941 ms and p99
106.509→112.888 ms. This confirms a measured software-renderer cost. No performance
acceptance threshold was asserted or silently cleared by the green capture job.

The enhanced external apparatus was then qualified separately on the unchanged
`018bd095` / `9a354683` application pair and later committed at `7e494a37`.
It passed 19 reducer/custody controls, actual paused/moving smoke cohorts and a
complete four-case ABBA (16 phases / 3,840 measured frames / historical control).
Its original moving smoke failed because the new diagnostic declared a Node2D
session as RefCounted; that failed apparatus and raw log remain preserved. Only
the test-local type was corrected before the complete campaign.

| Enhanced local observation | Main | Candidate |
| --- | ---: | ---: |
| Active 2048-square native ticks/s | 6.584 | 7.670 |
| Active 2048-square successful uploads/s | 6.560 | 7.645 |
| Active snapshot age p50 / p95 | 159.406 / 255.095 ms | 143.479 / 213.601 ms |
| Active current-uploaded-texture age p50 / p95 | 170.514 / 268.432 ms | 156.200 / 230.264 ms |
| Actor Follow completed Rapier and actor steps/s | 14.933 | 16.491 |
| Actor Follow frame observations/s | 5.929 | 6.737 |

Paused manual authoring has zero native/Rapier progress but 20 successful uploads
per subject. Static slow-pan and actor materials have zero uploads, so their
texture age naturally grows; age alone does not demonstrate withheld content.
The enhanced run still contains adverse values: manual p50 frame time increases
58.057→61.403 ms (+5.76%), p99 129.950→144.192 ms (+10.96%), and presentation
latency p50 170.976→185.377 ms. Follow improves in that local repeat. All original
local and hosted measurements remain separate; favorable later repetitions do
not erase adverse ones or establish hardware-GPU acceptance.

The final enhanced hosted campaign at `5b7cd745` also completed and was reduced
independently from all 16 raw process/runtime receipts and 3,840 measured frames.
[Job 132783393364](https://github.com/techrote/cybersand/actions/runs/43703292501/job/132783393364)
used a four-logical-CPU AMD EPYC 9V74 VM with the same Godot/native runtime and
Mesa llvmpipe backend. This differs from the original hosted EPYC 7763 and local
Xeon hosts; these cohorts are not pooled. The candidate application remains
identical to `9a354683`; the enhanced apparatus was committed at `7e494a37`.

| Final hosted workload | Main p50 / p95 frame ms | Candidate p50 / p95 frame ms | Candidate p50 change | Observed FPS, main → candidate |
| --- | ---: | ---: | ---: | ---: |
| Slow pan, 512-square | 33.075 / 40.154 | 32.263 / 40.877 | −2.46% | 29.435 → 29.967 |
| Active 2048-square / four workers | 78.270 / 100.238 | 78.966 / 105.223 | +0.89% | 12.678 → 12.555 |
| Manual authoring, 2048-square | 32.613 / 38.015 | 32.974 / 38.769 | +1.11% | 29.813 → 29.524 |
| Actor Follow, 1024-square | 78.221 / 89.208 | 79.271 / 90.461 | +1.34% | 12.501 → 12.348 |

The active case's p95 frame time worsens 4.97%; Follow p99 worsens 4.43%.
Main callback medians are 6.014→6.067 ms active, 0.317→0.381 ms manual and
0.565→0.639 ms Follow. Manual presented-result median is 101.551→104.951 ms,
although its p95 improves 137.358→119.437 ms. These remain measured changes with
two independent processes per subject/case, without a causal-confidence claim.
The historical same-process shader control's median remains worse by 3.34%
(73.464→75.918 ms); p95 rises 80.338→82.697 ms.

Active native throughput and successful uploads are 7.237→7.219 per second.
Main-observed native tick-duration median is 128.081→129.225 ms. Snapshot age
p95 rises 209.558→212.404 ms; current uploaded-material age p95 rises
219.072→221.179 ms. Actual low-level Rapier and actor completion counters in
Follow both measure 12.970→13.094 steps/s, while uploads remain zero. No age
samples are missing. The independent review validates source-time subtraction,
stable session/World/bridge identities, monotonic counters and elapsed-weighted
pooling. It does not measure worker wait/backlog, previous-texture age, hardware
present times or actual actor/terrain relative-motion traces. Original negative
and favorable repetitions remain available with their own sources and hosts.

The Lab-derived clock tables below use completed actor-session ticks after
Rapier; the enhanced external apparatus above independently measures bridge
`manual_step_count()`. Aggregate `valid=true` certifies capture identity/settings
continuity, not absence of actor-step faults or equality of those two counters.
The [operational handoff](../operations/camera-stack-reconciliation.md#engine-lab-scope-and-clock-semantics)
records the explicit fault-path limitation and future negative-control gate.

## Windows package qualification

The first actual extracted `Test It.cmd` run on application `9a354683` completed
23 of 24 cases successfully. Cross-clocks returned exit 1. A later console/global
exit-status engine probe also reported a version mismatch, and the artifact
upload incorrectly combined installed C: and workspace D: paths. The full raw
case ZIP was created but could not be recovered after that upload failed. The
original job log and its SHA-256 are preserved; the detailed clock assertion is
**unknown**, not inferred or reconstructed.

The follow-up `049cdd31` changes infrastructure only: bounded direct GUI-engine
version probes with raw stdout/stderr and process exit codes, separate evidence
uploads, and an early installed cross-clock gate before the unchanged full
24-case plan. The focused gate passed with application and clock fixture
unchanged. [Run 43699476503](https://github.com/techrote/cybersand/actions/runs/43699476503)
then passed all 24 actual installed cases in 946.796 seconds. Both direct version
probes returned exact `4.7.stable.official.5b4e0cb0f`, exit 0 and empty stderr;
all 1,027 payloads matched before/after, and the independent package verifier
passed. The full cross-clock test separately passed 59 checks with zero failures.
All evidence uploads succeeded, with 188 case-evidence hashes independently
verified after retrieval. These passes cannot identify the original lost
assertion or erase the failed run.

The [qualified owner evaluation](https://github.com/techrote/cybersand/actions/runs/43699476503/artifacts/14156073947)
contains `CyberSand-Camera-Stack-Windows-049cdd31fb1b.zip`, 92,418,247 bytes,
SHA-256 `5d2eadbfe74644b2838cd6f181e76aa9011903f343c0721a108284051b1eae90`.
It binds package source `049cdd31` and tree `fa7e3363`; the application and
functional fixtures are byte-identical to `9a354683`. Hosted execution used
Windows Server 2022 build 20348 and ANGLE 2.1.1 / Microsoft Basic Render Driver /
Direct3D 11 software rendering. This is a runnable evaluation artifact,
not production release or physical acceptance.

| Requested Pixel / Rapier / publication Hz | Native achieved Hz | Completed actor-session Hz | Render callbacks/s | Successful uploads/s | Snapshot / displayed-material age p95 ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| 60 / 60 / 60 | 12.73 | 12.24 | 12.24 | 12.73 | 87.98 / 154.19 |
| 15 / 120 / 15 | 14.89 | 89.36 | 12.91 | 8.44 | 117.18 / 128.77 |
| 120 / 30 / 60 | 15.13 | 29.28 | 12.20 | 12.69 | 81.81 / 152.68 |

All three Windows cohorts retained valid ordering and immediate ACK catch-up
at all 26/26, 27/27 and 26/26 sampled ordering observations. Actual successful
upload counts and ACK advances were 26, 17 and 26 respectively. Actual actor/camera motion
and material publication occurred together. The Windows 1-Hz shutdown observation
was 94.395 ms, with the worker stopped; this does not replace the independent
moving-pilot lifecycle measurement or establish a shutdown timing guarantee.

The package exports exact Git source, verifies accepted native inputs and original
build provenance, includes pinned Godot 4.7 and the required licensed runtime dependencies,
and contains `Test It.cmd`, its PowerShell runner and `Open Workbench.cmd`.
Qualification executes the actual CMD from an extracted directory containing
spaces, uses bounded child processes, checks source hashes before/after, and
retains original failures. A package is released for owner evaluation only after
its installed full-run gate passes. Hosted Windows ANGLE is not the owner's
NVIDIA hardware, actual Windows scaling acceptance or a stuttering repair.


The next apparatus-only checkpoint, `7e494a370015374c4975a9abe1d957cedd00bdfa`,
retains identical application, clock fixture and Windows runner bytes. Its
[run 43702108209](https://github.com/techrote/cybersand/actions/runs/43702108209)
passed every Linux functional lane but failed the focused Windows gate on the
first `real Workbench mounted` predicate, before any clock cohort. Import, package
integrity, native hashes and normal graphical startup passed; the original
fixture did not record whether the wait ended by its 45-second deadline or a
worker failure. The Windows package and performance jobs were correctly not
admitted. Its raw setup artifact `14156902770` and job log are retained. This
failure is **unexplained**, not described as a renderer repair or proven
integration regression. It cannot retrospectively identify the first run's lost
clock assertion either.

Diagnostic-only checkpoint `5b7cd745c98ef5354f2f6043d34c91cbe127a893` adds bounded
startup load/instantiate/add-child times, read-only scalar state and the actual
wait terminal reason to the clock fixture. The original 45,000-ms deadline,
predicates and all 59 checks remain unchanged. Production source, native binaries,
clocks, pose selection and ACK behavior remain byte-identical to `9a354683`.
The original graphical path passed locally with the recorded test hash, then
[run 43703292501](https://github.com/techrote/cybersand/actions/runs/43703292501)
passed the complete Linux functional lanes, the installed Windows focused clock
gate and all 24 installed Windows cases. The full Windows suite took 907.614
seconds. Both direct Godot version probes returned the exact pinned version,
exit 0 and empty stderr. All 1,027 payload hashes matched before/after; 185
retained case-evidence hashes and 27 executed script fingerprints were
independently verified after retrieval. Native recording wrote seven frames
across two material publications with zero drops and 87 checks. These counts
are specific to this execution, separate from the earlier 049 result.

The latest [qualified Windows evaluation](https://github.com/techrote/cybersand/actions/runs/43703292501/artifacts/14157901449)
is `CyberSand-Camera-Stack-Windows-5b7cd745c98e.zip`, 92,420,821 bytes,
SHA-256 `7532af6949e3225c706def61f7f163b5d108cfb5a44a9db873f0ebe5c3150c83`.
Its copied source is exactly `5b7cd745`, tree
`43d8ed2985beff970e48c7c9724b81f64d84b38d`. Later documentation/evidence updates
do not relabel this package or alter its qualified application. Actual extracted
`Test It.cmd -Automated -RenderingDriver opengl3_angle` ran from
`C:\Camera Stack Evaluation`; the ordinary owner double-click uses the same
24-case plan with `opengl3` and a final acknowledgement pause. Default-driver
physical NVIDIA execution remains an owner gate.

| Latest Windows requested Pixel / Rapier / publication Hz | Native Hz | Completed actor-session Hz | Render callbacks/s | Successful uploads/s | Snapshot / current-material age p95 ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| 60 / 60 / 60 | 15.776 | 15.283 | 12.325 | 9.367 | 150.829 / 150.958 |
| 15 / 120 / 15 | 14.330 | 96.851 | 12.848 | 9.389 | 127.660 / 135.743 |
| 120 / 30 / 60 | 16.021 | 29.130 | 12.137 | 12.623 | 84.117 / 152.381 |

Ordering observations were 26/26, 27/27 and 26/26; actual uploads and ACK advances
were 19, 19 and 26. The same run's 1-Hz shutdown took 1,045.558 ms with the thread
stopped. These measurements must not be replaced by the earlier run's shorter
94.395-ms shutdown or attributed to monitor presentation.

**Startup reliability remains unresolved.** The successful focused and full
Windows initial mounts waited 35,732 and 38,745 ms, while restarts took 1,843 and
2,011 ms. The first two observations were 35.092 and 38.102 seconds apart while
process frame counts advanced only 0→1. Native publication serials advanced
45→2097 and 47→2283. At the second sample the worker already held an applied blank
World at generation 2 / install serial 1, without a recorded native failure;
Main still held its earlier generation-1 snapshot (consumed serial 54 or 57).
Both successful predicates completed at process frame 2. This records an early
frame/consumer delay; it does not identify the blocked operation, shader/driver
cause or the first native-install completion time.

A separate source audit found 19 admission/default-construction functions
byte-identical to accepted main. Initial blank-2048 installation has no actor
candidate or physical session to wait for; Lab handlers are connected after
initial UI values and do not alter startup pacing. Those facts narrow the
boundary but prove neither consistent startup reliability nor the causes of
the two earlier Windows failures. Their original evidence remains retained.

## Independent worker evidence

Original #609 remains at `01a8416761ba3477a2587d7b07a854945b0f0286`.
Its separate published repair continuation was
`fix/render-cadence-001-20261115` at
`d5397a7d2a1285bf6d2ade5f76e0e89e00e85c70` at audit.
[Run 43691622727](https://github.com/techrote/cybersand/actions/runs/43691622727)
retains the 2-Hz fixed-camera negative control: 1.9963 native ticks/s,
120.811 completed Rapier steps/s, identical motion at 995 common completed steps,
yet 364.009 ms displayed hold followed by 88.2936 px catch-up. Conservative swept
padding can reject endpoint-clear poses after texture crossfade expiry.

Those are worker-source results, not this candidate's measurements. They support
excluding the disputed selector; they do not demonstrate a complete repair. The
worker's complete presentation disposition remained FAIL/HOLD.

At the final read-only refresh on 15 November 2026, 10:45:33 UTC, accepted main and
all four original open Draft PR heads remained unchanged. The worker had advanced
to `7c85b348f7077adbc7dbbf338f92683ac0df08f4` with only a workflow timeout increase.
[Run 43692913495](https://github.com/techrote/cybersand/actions/runs/43692913495)
retained three successful Linux shards but failed Windows at its 85-minute
installed-matrix deadline after 17 complete pairs / 34 trace-case receipts;
the final native2/free pair was incomplete. This is not a whole-matrix pass.
Its replacement [run 43700256160](https://github.com/techrote/cybersand/actions/runs/43700256160)
had three successful Linux shards and Windows still running at refresh.
The [worker's current audit](https://github.com/techrote/cybersand/blob/7c85b348f7077adbc7dbbf338f92683ac0df08f4/docs/audits/2026-11-15-render-cadence-001.md)
retains the same measured coherence failure and explicitly unimplemented,
unaccepted independent-clock follow-on. No worker source was imported and no
new owner physical acceptance was observed.

## Remaining admission

`CyberSand-Camera-Stack-Raw-Evidence-20261115.zip` retains 1,834 evidence files
with a per-file SHA-256/length manifest and verified ZIP CRC. Its size is
46,857,909 bytes and SHA-256 is
`06240d3f4b3df36f087f3884f28d36472cc1149de60f84ab1c8223051c64d674`.
It includes the original failures, source/runtime receipts, complete performance
samples, independent reductions and screenshots. The Windows evaluation is a
separate runnable package; this evidence archive is not a second repository copy.

The [operational handoff](../operations/camera-stack-reconciliation.md#downstream-609-handoff)
defines the future selector/receipt/ACK/trace boundaries. The original stack must
not be merged wholesale after this selective reconciliation. The shortest safe
composition is accepted main plus this candidate plus one reviewed final #609
delta, then affected source/runtime/graphical/physical gates and owner approval.

Physical Windows NVIDIA motion, actual OS DPI, VSync and representative long
moving-contact workloads remain distinct from hosted software rendering. No
merge, Ready promotion, auto-merge or native runtime publication is authorized.
The final documentation/evidence commit leaves all production code and all
executed apparatus byte-identical to checkpoint `5b7cd745`. The isolated branch
is ready for review of this bounded preparation, while whole-stack acceptance
remains conditional on the worker result, unresolved startup reliability,
performance disposition, affected regressions and owner approval.
