---
title: PLAY-BUSY-001C rendered framebuffer during real native phase hold
status: Planned
document-kind: audit
canonical-for: []
last-reviewed: 2026-10-29
scope: Graphical source-matched qualification stacked on PLAY-BUSY-001B; no release promotion
related-documents: [2026-10-29-play-busy001b-real-phase-host.md, ../systems/player-control-playground.md, ../architecture/simulation-tick-and-threading.md, ../operations/github-development-and-release.md]
---

# PLAY-BUSY-001C — rendered UI progress under real native phase hold

## Purpose

PLAY-BUSY-001B proves real `World::tick_phased()` jobs can remain outstanding
while Main process/physics/input callbacks continue and that the actual worker
stop fence drains and joins in legal ownership order. That host test is
headless. #270 separately requires UI rendering/response under genuinely slow
native work.

001C is stacked on the exact 001B source hook but leaves the 001B branch
unchanged. It requires actual submitted framebuffer pixels while the **same
selected real native phase dispatch** remains held.

## Protocol

The test uses the ordinary `main.tscn`, authored Player Playground course,
Jet Barrel SetP rig, exclusive `CyberSimulationWorker`, real main-thread
Rapier and the 001B source-matched test runtime.

After ordinary parallel gameplay is established:

1. arm the 001B copied-value gate for the next complete eligible production
   pool dispatch;
2. require at least two distinct real phase callback threads held with zero
   selected task completion;
3. await `RenderingServer.frame_post_draw` and capture the real viewport;
4. submit a D press through `Input.parse_input_event`, run 30 real physics
   frames while the native dispatch stays held, release D, then capture a second
   submitted frame;
5. require Main process/physics/input counters, Rapier manual-step count and the
   actual SetP actor position to advance while the exact retained immutable
   native snapshot object/serial/tick/World generation does not change;
6. require both framebuffers to be nonblank, same-sized and visibly different
   on a fixed four-pixel sampling grid;
7. persist both unaltered PNGs, manually release the native gate before its
   safety deadline, require every selected task to complete and the actual pool
   dispatch to return, then perform ordinary scene shutdown/join.

The pixel-difference threshold is only a liveness/refusal floor. It is not a
quality metric, FPS target or visual-comparison benchmark.

## Execution environments

The stacked workflow reuses the exact special runtime build already required by
001B at the same commit.

- Linux uses Xvfb plus Mesa software OpenGL and Godot
  `gl_compatibility`; the test explicitly refuses a headless DisplayServer.
- Windows invokes the official console binary **without `--headless`**, with
  the compatibility renderer and dummy audio. If the hosted Windows session
  cannot provide a real framebuffer, the test must fail and that limitation is
  retained rather than reclassified.

The reducer uses only Python standard library. It verifies the machine result,
raw log, runtime/Rapier identities, PNG magic/IHDR dimensions and raw PNG
SHA-256 values. Before/after PNG bytes must differ.

## Boundaries

This is actual graphical framebuffer evidence, but it is still scripted CI. It
does not qualify a physical controller, focus-loss behavior on a human desktop,
sustained rendered FPS, subjective feel or release readiness. It does not
modify native solver defaults, Rapier ownership, the production worker script,
or #290/#295/#298 publication work.

The 001C branch is separate so failures or later graphical refinements do not
invalidate 001B's exact-head shutdown evidence.


## Retained first hosted failure and source-only correction — 2026-10-30

Exact-head scoped run
[40975126632](https://github.com/techrote/cybersand/actions/runs/40975126632)
is **FAILED** on both target OS render steps. The preceding 001B real-phase
shutdown fixture passed on both OSes at the same source and special runtime.
The new 001C script did not execute: Godot rejected it at parse time because
the subclass redeclared `assertions` and `failures`, which already exist in
`play_life001_shared_host_case.gd`.

Original Linux artifact `12943030911` (ZIP SHA-256
`efbc8f028aa1cbad64ec42f251821669b9ea89694de6fb7eadd2682b92365b78`)
and Windows artifact `12942850859` (ZIP SHA-256
`af1536114ca74d233e08d48cc152aaf686849f8ea7ffe58c02b58a0f67d67202`)
retain the raw parse logs. Linux reached Xvfb/Mesa llvmpipe compatibility
render setup before parse; Windows reached ANGLE/Microsoft Basic Render Driver
before the same parse refusal. No framebuffer, Main-under-hold, Rapier-under-hold
or PNG result exists for this failed source.

The successor removes only those two redundant member declarations. It does
not change the hold duration, gate, rendering method, input route, pixel
thresholds, native runtime, Rapier ownership, timeout, retry policy or reducer.
Fresh exact-head Linux/Windows 001B+001C execution and artifact review are
required; the failed run is not reclassified as partial 001C success.


## Second hosted failure and bounded graphical-stage correction — 2026-10-30

Successor `dd3d4d7da35f8f4d2822f039dadf0aae78cb8b7c` fixed the
inherited-counter parse error but did **not** qualify 001C.

Linux original artifact `12947820490` has Actions ZIP SHA-256
`e67bd00fdad5de1dd85148f3f84807c4ae75e4db1edf06b6386e01db85b8a4f3`.
Its render log reaches a real X11 compatibility context using Mesa llvmpipe,
then fails the inherited 15-second wait for authored-course acknowledgement.
The native phase gate had not yet been armed, so this is graphical fixture
startup failure, not a slow-native responsiveness result.

Windows original artifact `12946639914` has Actions ZIP SHA-256
`05345655569ecb99e5a8ce1190981e94cce8d04b7872f597817d07ee6c3d2114`.
It reaches an actual ANGLE/Microsoft Basic Render Driver compatibility context
but emits no machine result before the unchanged outer 120-second apparatus
deadline. The old script had no stage receipts and an unbounded direct
`await RenderingServer.frame_post_draw`, so the exact internal stage is not
recoverable from that failed log. Do not infer a native hold, framebuffer or
Rapier result from it.

The next source keeps the 12-second native hold, 30 under-hold physics frames,
pixel-change/nonblank oracles and 120-second process cap unchanged. It makes
three fixture-only corrections:

- explicit 30-second waits for course and actor **setup** instead of inheriting
  LIFE001's 15-second non-rendering lifecycle setup bound; this is not a
  gameplay-frame or native-hold performance threshold;
- stage JSON receipts before/after course, actor, held phase, each capture,
  manual release and dispatch return;
- each framebuffer capture connects to the real `frame_post_draw` signal,
  calls main-thread `RenderingServer.force_draw()`, and requires the signal
  within 2.5 seconds. A missing draw returns a normal test failure instead of
  consuming the outer process deadline.

The Godot 4.7 RenderingServer contract documents `force_draw()` as a
main-thread redraw of all viewports. The test still requires the real
`frame_post_draw` signal and actual viewport pixels; force-draw is not a
mock framebuffer. Fresh source-matched Linux/Windows execution and original
PNG/log review remain mandatory.


## Third hosted failure and current-base diagnostic reconciliation — 2026-10-30

Exact head `01e3eac244cb01363b31a28b829f3eb1be5008ca` still failed
001C on both target OSes in scoped run
[40987311800](https://github.com/techrote/cybersand/actions/runs/40987311800).
The new stage receipts make the failure boundary explicit:

- Linux original artifact `12948460161`, Actions ZIP SHA-256
  `87c5840cbadf0471da8ca66d30abfe2bab25fd5b32191ce37f5d82eb4c622a16`,
  reaches X11/OpenGL3 software rendering, starts the worker, prints
  `course_queued`, then the explicit 30-second graphical setup budget expires
  before course acknowledgement. The actor and native hold are never armed.
- Windows original artifact `12948375107`, Actions ZIP SHA-256
  `e09c9c2c1b45c4c68e12500ce614eeb3dcc3c4f24babd11ed9f4188ef00b380f`,
  reaches ANGLE/OpenGL3 on Microsoft Basic Render Driver, starts the worker and
  prints `course_queued`, then emits no further stage receipt before the
  unchanged 120-second outer apparatus deadline. The actor/native hold and
  framebuffer captures are never reached.

Therefore no prior 001C run proves or disproves framebuffer liveness while
native jobs are held. The current failure is **graphical authored-course
installation**, before the hold.

This successor is reconciled onto #302 exact head
`102f6b5da74bffcf3da0063ca335ba6e8c22ce94`, whose real-phase special runtime
is provenance-safe: ordinary production runtime-source paths remain exact main,
and the phase hook is applied only in the scoped build. The 001C script is
renamed `play_busy001c_render.gd` so ordinary `test_*.gd` discovery cannot
invoke a special-runtime fixture against the retained release DLL.

The graphical script now emits standard `CYBERSAND_PROGRESS` stage markers in
addition to its retained 001C records. The existing external process monitor is
extended only for this explicit apparatus case. It captures diagnostics after
30 seconds without a new stage and fails after 45 seconds idle, while retaining
the absolute 120-second case deadline. A new runner owns process termination and
retains diagnostic state/logs; no extra retry is introduced. The internal
30-second course/actor setup bound, 12-second native gate bound, 30 under-hold
physics frames, 2.5-second real `frame_post_draw` bound and pixel oracles are
unchanged.

This diagnostic change does not convert the current failure into a pass and does
not substitute sandbox rendering for the required authored Player-course host.


## Reconciled diagnostic run and readiness correction — 2026-10-30

Exact head `78881740d7e5701fd716f68cd396cd3008961d63`, scoped run
[40989029439](https://github.com/techrote/cybersand/actions/runs/40989029439),
again **FAILED** 001C on both OSes while the same jobs' 001B controls passed.

Original evidence integrity:
- Linux artifact `12948681559`: ZIP SHA-256
  `f81dddfc1a7153536caf5271763921103ac99c8d7b54a526100db3798a483738`,
  66 CRC-clean unique safe members.
- Windows execution artifact `12947979772`: ZIP SHA-256
  `2a27449393b42b65aa9d0b1a29e0e33dbabeb4be35c23fce8be3a03ab6b347e9`,
  22 CRC-clean unique safe members.
- Windows special-runtime artifact `12948602079` is separately retained by
  Actions. No runtime is published to LFS.

**Windows:** actual ANGLE/Microsoft Basic Render Driver starts; progress reaches
`display_ready` at5264ms, `worker_started`5594ms and `course_queued`5847ms.
At35.983s the external monitor captures the live process with
`course_queued` still the last progress marker; at45.030s stage-idle the
watchdog fails the apparatus, still well inside the unchanged120s absolute
deadline. Diagnostic capture completes successfully and retains two minidumps.
The GUI Godot child had44.39 CPU-seconds at capture; one thread was Running
with33.56 CPU-seconds while most other threads waited. This shows active CPU
work, not a proved lock sleep, but the retained minidump has not been symbolized;
do not invent a source stack from CPU counters. The authored course is not
acknowledged and the native hold is never armed.

**Linux:** X11/llvmpipe reaches `course_installed` at32867ms and
`actor_ready` at40032ms. The next30-second wait fails the stricter
`render_host_ready` predicate before any native gate arm or framebuffer
capture. External diagnostic capture at70.168s retains `actor_ready` as the
last marker. Linux proc stacks are permission-refused and gdb is unavailable in
the hosted image; wait channels are retained rather than represented as
symbolized backtraces.

Comparison with passing 001B found one fixture discrepancy before the readiness
wait: 001B explicitly releases controls and calls
`desktop.publish_actor_keyboard_input()` after unpausing, whereas 001C relied
on later physics callbacks while also requiring `_actor_input_rearm == false`.
The successor adopts the exact qualified 001B neutral-rearm sequence. It also
prints every readiness subcondition on timeout (actor/terrain, pause/rearm,
worker failure, snapshot/native tick, configured workers, completed parallel
phases, Rapier tick, overlay visibility and Main/physics callback counts).

No setup/hold/render timeout, native gate, pixel criterion or production path is
changed. Windows graphical course installation remains a separate unresolved
failure even if this Linux readiness correction succeeds.

## New-eligible-phase wake, not a relaxed hold oracle — 2026-10-30

Fresh source-level diagnosis consumes the original failed 001C evidence at
[40990299227](https://github.com/techrote/cybersand/actions/runs/40990299227):
Linux finished course/actor setup but observed `scheduler_parallel_phases_last_tick=0`
in its *most recent* snapshot even though four worker threads were configured.
A zero in the most recent snapshot does not imply the next dispatch cannot
execute a real parallel phase, and waiting for a historical phase is not the
requested under-hold proof.

This successor changes only the **explicit-only 001C script and this audit**.
It retains actor/course/terrain/rearm/overlay/native-capacity readiness but
does not demand `scheduler_parallel_phases_last_tick>0` in the last packet.
Instead, **after arming** the unchanged copied-value native gate, it submits
four bounded Water brush discs at authored-camera coordinates
(176,188), (240,188), (304,188), (368,188), radius8,
through `Main.queue_brush_mutation`. These are *ordinary admitted* cellular
commands on the production worker ownership route; the test requires all
four admissions and records counts and native tick before waiting for the gate.

The existing gate **must still** observe at least two distinct *actual*
`World::tick_phased` callback workers simultaneously waiting/active, zero
selected-task completion, no safety timeout/release/dispatch return, with the
same real dispatch held across two real frame submissions. All existing
native gate timing, framebuffer, pixel, Rapier/input, immutable-snapshot,
manual-release/drain/join and strict source-matched runtime oracles remain
unchanged. A graphical host that never starts a real eligible pool dispatch
still fails (no synthetic task, no injected thread, no fake pass).

This is a diagnostic/source candidate only until fresh exact-head Linux
and Windows special-runtime builds, execution and original artifact readback
pass. The prior Linux/Windows graphical failures remain negative evidence;
Windows software-renderer course-installation cost is separately unresolved.
No physical gamepad, focus, sustained FPS, subjective feel or release claim.

## Fourth graphical failure, original Windows readback and bounded raster-size successor — 2026-10-30

Exact source `5af7a73273d0f7aaa6fc2d0ccf45fb7e04c52062`,
[scoped run 41001702056](https://github.com/techrote/cybersand/actions/runs/41001702056),
ended **FAILED**. Draft Documentation
[41001707304](https://github.com/techrote/cybersand/actions/runs/41001707304)
passed; standard Native/Godot were draft-skipped, not green.
The real 001B native-hold/shutdown control in the Windows job **passed** at
this same source: 34 assertions/zero failures, five tasks, four distinct
claimed native callbacks, real stop/release/drain/join, original receipt status
`passed`. This is **not** a graphical 001C pass.

Independent readback of original Windows artifact `12953574712` verified
GitHub Actions ZIP SHA-256
`9b266bad33246ac32c1486564dc378f310ef942c287728d95cebfde5f1043028`,
22 CRC-clean, unique and safe ZIP paths, original raw `execution.log`,
`receipt.json`, `render-execution.log`, runtime and instrumented-source
manifests plus retained diagnostic minidumps. The source-matched *special,
unpublished* Windows DLL SHA-256 is
`2d9ed285a4f4c09b7796f282810f78cfcdaab9c524cfef0bc49cbd4a1ca75a66`;
the pinned Rapier SHA-256 is
`b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7`.

**Windows 001C failure:** actual Godot 4.7 compatibility rendering used
ANGLE/Microsoft Basic Render Driver. Markers reached `display_ready` at
3159 ms, `worker_started` at 3359 ms and `course_queued` at 3509 ms.
There was no later course acknowledgement, actor, native gate or framebuffer
marker. An independent process snapshot captured the GUI child with one
actively running thread (33.39 CPU-seconds at capture), many waiting threads,
and two successful minidump files, but no symbolized stacks. The existing
45-second stage-idle watchdog failed before the unmodified 120-second absolute
deadline. **Do not classify CPU use as proven native deadlock or progress.**

**Linux:** its 001B source-matched ordinary real-host control completed, and
the graphical step was still marked `in_progress` when the job concluded
`cancelled`. No complete archived Linux 001C render artifact was published
for this head. This is a missing/negative qualification, not a pass and not
proof of a particular gameplay defect.

**New narrow diagnostic successor:** the project's original
`godot/project.godot` requests a 1920×1080 window and viewport. In CI this
runs on software-rendered ANGLE or Mesa, which plausibly burdens the
graphical-setup stage. The explicit-only 001C runner now requests a
**windowed 960×540 actual framebuffer** using Godot's CLI, preserving the
already-required real non-headless DisplayServer, actual
`RenderingServer.frame_post_draw` signal, raw PNG capture and immutable
native-hold/pixel-difference gates. The script records observed window/content
scale pixels, rather than assuming the CLI request succeeded. A frame smaller
than the existing 640×360 requirement still fails. No production project
configuration, material, owner, native runtime, release artifact, timeout or
retry policy changes.

The same successor additionally releases/drains the selected real native
phase before ordinary scene teardown if either framebuffer capture is missing.
This is a fail-safe refusal: it still returns failure and cannot fabricate a
positive `PLAY_BUSY001C_RENDER_RESULT` or conceal a stalled renderer. The
strict 12-second native safety hold and 120-second outer deadline remain.
Neither this reduction nor the previous failures qualifies a 1920×1080
graphical performance target, sustained FPS, physical controller/focus or
manual human feel. Require fresh exact-head Linux/Windows original logs,
framebuffer dimensions, PNGs and independent custody before acceptance.

## Fifth graphical refusal at 87825aa8 and real canvas-scale diagnostic — 2026-10-30

Source `87825aa831f03196674965226931b565204b38f3`,
[host run 41007034245](https://github.com/techrote/cybersand/actions/runs/41007034245)
is terminal **FAILED** on both graphical 001C jobs.
[Documentation 41007038086](https://github.com/techrote/cybersand/actions/runs/41007038086)
passed; normal Native/Godot PR checks were **draft-skipped**.

Independently downloaded the two **original** 001B/001C run artifacts:

- Linux artifact `12956217694`, ZIP SHA-256
  `899539d7ffc48965958b6152b17a4b4807ea344fb3edfb78ba782df3bf20454a`;
  **68** CRC-clean, unique, safe members. Raw graphical log SHA-256
  `64a19597cae0a147123515c843aebb280954adf61d1a8ee37e2ed6121d87d3ce`.
- Windows artifact `12955434434`, ZIP SHA-256
  `5a6cfefe860471164a1ac5975d84e23933c938b8a8a30bfcbfc8410516ab1fe3`;
  **22** CRC-clean, unique, safe members. Raw graphical log SHA-256
  `a7734225eb049149dbf51cae8cefa70396af74de6e046d788d5eeb505211f3b4`.

Both source-matched 001B real-phase hold/stop controls still pass **34
assertions/zero failures** on this exact source. Raw 001B machine rows match
the archived receipts exactly. Runtime SHA-256 seals, log hashes, identical
source-input manifest SHA-256
`f3795bba4b0c87b10ccfbdcc626a1a654801a3cb86a008137f2fbcc27679f37c`,
and recorded native/Rapier provenance match across each original archive.

The 001C script logs reveal why the earlier **window** size experiment was
insufficient: on BOTH Linux and Windows, the real outer window is
**960x540** while Godot's **canvas content scale remains 1920x1080**.
The former comes from `--resolution`; the latter from
`godot/project.godot`'s viewport configuration. Thus the earlier
assumption that a smaller window request also reduced the logical
rendered course canvas was incorrect.

- Linux: real X11/OpenGL3 Mesa llvmpipe, `course_queued` at 4,692ms;
  after the existing 30s course-setup bound, the authored course is not
  acknowledged. Retained thread snapshot shows the Godot main thread
  running and native pool workers waiting in futex; this does **not**
  determine the main-thread source location.
- Windows: real ANGLE/Microsoft Basic Render Driver, `course_queued`
  at 7,718ms; the unchanged 45s *stage-idle* watchdog fails before
  course acknowledgment. Two raw diagnostic dumps are retained but not
  symbolized. One graphical child thread consumes substantial CPU time;
  CPU occupancy is not proof of a deadlock or a completed scenario.

Neither platform reaches actor/native gate arm, `frame_post_draw` capture,
or a positive 001C machine result. There are **zero raw PNG** artifacts.
The 001B successes cannot be substituted for missing 001C graphics results.

**Narrow successor experiment:** the explicit-only graphical test now sets
`SceneTree.root.content_scale_size` to **960x540 before Main scene
instantiation**, checks the actual value, and logs original/observed canvas
sizes. This changes no production project setting, native worker, Rapier
ownership, solver policy or published LFS runtime. It additionally records
read-only copied course/setup observations at five-second intervals during
the existing **30-second** course wait. These samples do **not** reset
`CYBERSAND_PROGRESS`, hide the stage-idle watchdog or extend any
deadline. The real >=640x360 raw PNG/pixel-change oracles, two submitted
frames, >=2 simultaneously held real native callbacks, 12s safety gate,
30 under-hold physics steps, 2.5s frame signal and 120s absolute process
bounds remain unchanged.

This is a candidate for fresh source-matched execution, not acceptance.
Even a successful 960x540 hosted run would not qualify production 1920x1080
rendering, sustained FPS, physical focus/gamepad or manual human feel.


## Exact d68ea65f failure readback and bounded Main callback trace — 2026-10-30

At literal head `d68ea65f442263fced617b5fa569470a942c16a3`,
[run 41012912026](https://github.com/techrote/cybersand/actions/runs/41012912026)
is terminal **FAILURE** for both graphical 001C steps, while both 001B
actual-host controls pass **34 assertions/zero failures**, holding four
distinct real worker callbacks and correctly draining and joining.

Downloaded the *original* retained execution archives and independently
checked SHA-256 against the Actions digests, ZIP CRC, unique/safe members,
`source-sha.txt`, 001B result-row/receipt equality and original log SHA:
- Linux archive `12958657576`: ZIP SHA-256
  `0bb6510105b0a78b8d1a477ec3221a94fa00290099623df989c0eab082af49e4`,
  68 members, render log SHA-256
  `37eea6f49f8e42cdb2c68346323dbaae6ba8c434ea2b7f9b340992e1a882aa09`.
- Windows archive `12959045194`: ZIP SHA-256
  `14783efa9edfb620955c1482b17949d1c2a5b332286b78f472c80547be350945`,
  22 members, render log SHA-256
  `ceb642e501b3a72d9439475558359f8b648b8e3493b4074da6ce6cdda8f1094b`.

Both exact-001B manifests have identical digest
`08148e4e3a3bea8d3b9a10f8356c8e97c8912ed636a5b6944f52864e1ee69274`.
The 960x540 **logical** canvas setting took effect on both platforms but did
not unlock graphical course installation. Linux logged one completed Main
`_process` callback, 15 `_physics_process` callbacks, native tick 3,
pending course serial 1 and no acknowledgement at its 30-second setup bound.
Windows reached `course_queued` (4324ms), then the existing progress
watchdog captured a heavily CPU-consuming Godot process without a new stage.
The Linux thread snapshot showed the main OS thread runnable, not an
independently identified source stack; `gdb` was absent and kernel stack
reads were denied. Two Windows minidumps were collected, but not symbolized.
There are **zero 001C machine success rows and zero held-frame PNG files**.

The next source-only diagnostic instruments the first three post-course
actual Main `_process` and `_physics_process` callbacks and brackets
the normal Main methods they call, recording monotonic microsecond stamps
and entry/exit edges as `PLAY_BUSY001C_MAIN_TRACE`. Every bracket delegates
to the production implementation via `super`; there is no mocked
World/Rapier owner or changed worker/solver/runtime source. The bounded
markers **never** use `CYBERSAND_PROGRESS`, so they cannot advance the
independent 45-second stage-idle watchdog. They are diagnosis, not a
liveness oracle, and any stage where execution stops is a hypothesis for
further investigation, not a confirmed stack without a real trace.

The same graphical gate still requires real unmodified rendered pixels,
>=2 held phase callbacks, copied snapshot invariance, Viewport input/Rapier
progress, manual release/drain and successful real shutdown, with exactly the
same timeouts and no retries. The old failed artifacts remain immutable.

## Exact efcef38d failure and GDB/MI parent-process diagnostic — 2026-10-30

Current draft source `efcef38d46c12381f2b576d0a650253b51edf137`
failed the dedicated graphical 001C step on both Linux and Windows in
[run 41021089742](https://github.com/techrote/cybersand/actions/runs/41021089742).
The same run's actual 001B real-phase hold/shutdown source-matched controls
**passed 34 assertions/zero failures on each OS**. Documentation
[41021095251](https://github.com/techrote/cybersand/actions/runs/41021095251)
passed; standard Native/Godot were draft-skipped.

I independently fetched and CRC-checked both original 001C execution
archives: Linux artifact `12961448740` (ZIP SHA-256
`6dea31cdb70b2de14a2aae5d6c7fe89cecd3c82b5771e0bff90e7f1e1b66287e`,
68 safe unique members) and Windows artifact `12962130833` (ZIP SHA-256
`ffd22ff59a501539f023f913e6fd891b9df705f66f3f97c6bd4a354cc3021d44`,
22 safe unique members). Both 001C graphical logs stop after a fully
completed first `Main._process` invocation, with source probes showing no
long-running production GDScript method. Linux logs a ~31.6-second gap
until its next Main/physics callbacks and its course-setup timeout; Windows
logs no second callback before the unchanged stage-idle watchdog.
The Windows minidump remains unsymbolized; CPU use and the lack of callback
cannot prove the renderer's exact source stack. Neither produced a successful
rendered-hold result, held-frame PNG, or native gate arm.

**Next bounded forensic step:** if and only if the original Linux graphical
001C step fails, run a *separate* source-matched compatibility-renderer process
under hosted Linux GDB/MI, with GDB the parent of Godot so the diagnostic
does not depend on attaching through restrictive ptrace permissions. Interrupt
that second process after 22 seconds, request bounded all-thread native stacks,
retain the full original GDB/MI transcript, its SHA-256, status/refusal receipt
and source hashes in the same failed run artifact. A 3-minute diagnostic step
cap and a bounded process-group teardown prevent leaving a debugger or Godot
running. A refused or unsymbolized stack is explicitly a diagnostic refusal.

This debugger run is **not** a retry, a success fallback, a representative
frame-time benchmark or an 001C pass. The original Linux/Windows qualification
steps, renderer, 30-second setup bound, 45-second progress watchdog,
120-second absolute deadline, 12-second native hold, pixel/PNG requirements,
Main/Rapier ownership and every production source remain unchanged.

## Current 56adff7c failed-run and POSIX process-group repair — 2026-10-30

Current exact head `56adff7c42f555ed250f45239cc20d634666f403` has
terminal **failed** dedicated run
[41026061055](https://github.com/techrote/cybersand/actions/runs/41026061055).
The source-matched Windows 001B real-phase/shutdown positive control passed
**34 assertions, zero failures**. The Windows 001C graphical host still
reaches `course_queued`, then returns no new progress stage and trips the
existing **45-second idle watchdog**. Its original retained Windows
execution artifact `12963842135` has GitHub ZIP SHA-256
`7a2159a11aa2e7a788021d080096c7b566b08db1a50b7f32257bb0f94240eaa7`;
the original ZIP passed CRC checking, contains 22 members, the exact
`source-sha.txt`, 001B receipt, raw graphical trace and two native minidumps.
The special unpublished Windows runtime SHA-256 is
`22952e98c3d6d748ba4f22c66cc6c8b07821dce3f191733ef076aa5b0814f5be`.
The original graphical log has **no held native phase, frame submission or
qualifying PNG**. This is not rendered-liveness acceptance.

The same run's Linux job concluded **cancelled** with the graphical step
recorded as in progress; no original Linux ZIP/GDB transcript was uploaded
and no Linux graphical result can be inferred. Source inspection identified
a concrete process-ownership hazard in the Linux diagnostic runner:
`run_play_busy001c_render.py` launched Godot without a separate process
group, whereas its existing `godot_timeout_diagnostics.stop_process_tree`
uses `os.killpg(os.getpgid(child.pid), SIGKILL)`. On POSIX a child without
`start_new_session` ordinarily inherits the runner/xvfb-run process group;
at timeout this cleanup can kill the **watchdog runner itself** instead of
returning a recorded failure and allowing artifact upload. That is a
source-level defect. The missing Linux run log prevents a definitive claim
that it alone caused this run's cancellation.

The narrow successor makes the **test-only** Godot child a new POSIX
session before launch, leaving Windows cleanup unchanged. A real-child
regression checks distinct session/process-group identity and exercises the
actual `stop_process_tree` cleanup without killing its supervising test
process. The Linux workflow runs this regression and additionally bounds
the whole Xvfb wrapper to **150 seconds** as a separate fail-closed cleanup
ceiling; the original 001C **120-second absolute** and **45-second progress**
watchdogs, 30-second graphical setup, 12-second native hold, >=2 actually
held callbacks, framebuffer/PNG, input/Rapier, immutable snapshot and
manual release/drain/join gates are **not changed**. The outer 150s bound
is not additional test execution time and cannot convert failure to pass.

Require fresh exact-head Documentation and dedicated Linux/Windows runs,
original retained Linux ZIP and GDB/MI transcript (or explicit refusal),
and independent source/runtime/artifact reduction before accepting
anything. Main remains unchanged; no native solver, release runtime,
physical-device/focus, sustained FPS or manual human-feel gate is promoted.


## Exact 86ca28d6 original artifacts and debugger-inferior exit classification — 2026-10-30

At source `86ca28d6fd7102bf3d2a4cd931b7a40c900d2f1b`,
[run 41039371507](https://github.com/techrote/cybersand/actions/runs/41039371507)
is terminal **FAILED**: both original 001C graphical steps fail **before**
the native gate; both independently source-matched 001B real native-phase
stop controls pass **34 assertions / zero failures each**. Exact-head
[Documentation 41039379311](https://github.com/techrote/cybersand/actions/runs/41039379311)
passes; standard Native/Godot are **draft-skipped**, not qualification.

Original downloaded GitHub Actions ZIPs independently match published digests:
- Linux execution `12969517952`, SHA-256
  `1fc6255b6010b1bb383243f432387c05862cc1e0f8e567547f85fabebaafded5`,
  73 unique safe, CRC-clean members; original 001C log SHA-256
  `66292135b7cfdd0c851d0d7e4c302e8454f3307627a45316bc0522728ba1a6ac`.
- Windows execution `12969268954`, SHA-256
  `5ccb1ed2a6c63ef17e827d01a4dc2c4fb1f46f60b33bd2ca87f916e281f78f72`,
  22 unique safe, CRC-clean members; original 001C log SHA-256
  `7802a462fd8c43c1b98cb3f7bb7ce6bc5712942bf12bab85e19e33e90955584c`.
- Windows source-matched build `12970256399`, SHA-256
  `d74bddd15156d4e74d49964b9ebe6ae7f0de0ff97d17fc0fa1221814b639ceb0`,
  seven unique safe, CRC-clean members. Both 001B receipts identify the
  literal `86ca28d6` source; native runtime hashes are Linux
  `988e3efec285f2940d298e02feac9f12c172cec34643ec4ab26848f469c165b4`
  and Windows
  `a111945758e67d9bc21044594b1be2b51ad937fd966a4c338c8c52deff82074b`.

The unchanged authoritative Linux 001C test reaches `course_queued` at
3155ms, then refuses after the 30s course-acknowledgement wait
(`pending_apply=true`, no actor/gate). Windows reaches `course_queued`
at 5683ms and fails the unchanged 45s stage-idle watchdog. No original
001C run PNGs or `PLAY_BUSY001C_RENDER_RESULT` exist.

The **separate, nonqualifying** GDB child does complete the actual Linux
under-hold sequence: its literal transcript includes a 32/0 machine result,
four distinct real worker callbacks held with zero completion, two real
960×540 framebuffer PNGs, 32 Rapier steps, input and actor progress
(20.779px), immutable snapshot, manual gate release, all five task completions
and actual dispatch return. The two original diagnostic PNG SHA-256s are
`b08dc753aeb5e814b37543ee2acabdc2e3abd09682befa35bcbb8bb2f82184bc`
and
`5d39616861a504ada993efe52d47af7168969586fd655177a03e0be705ce81ec`;
168,399 of 518,400 pixels differ. This is useful repeat-process evidence,
**not** a qualifying first-run result, throughput benchmark, rendered FPS,
physical device/focus test or manual human-feel gate.

A source-level diagnostic defect is also established: the retained original
GDB/MI transcript explicitly records `=thread-group-exited` with exit-code
zero and `*stopped,reason="exited-normally"`, but the old diagnostic JSON
reported `interrupt_refused_or_timed_out` because it attempted to interrupt
an inferior that had already exited. No stack was collected. A narrowly scoped
diagnostic successor classifies the inferior-exit event before asking for
stacks and adds a synthetic normal-exit/refusal regression. It retains
`qualification=false`, `backtrace_completed=false` and refusal to claim
an interrupt stack, and does **not** modify the authoritative 001C test or
its deadlines, 001B control, production worker, native runtime or renderer.
New exact-head CI and any original execution artifacts remain required.
