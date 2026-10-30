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
