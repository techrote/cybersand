# Bounded Main/render rendezvous — Draft/HOLD experiment

This distinct engine keeps the exact pinned Godot4.7 source, EGL repair, font
Image ownership repair, compiler/dependency flags, public API/ABI and PE gates.
The original engine, readers, failed runs and negative Safe/Separate results are
unchanged. A successful component build is not gameplay qualification.

## What is changed

`CYBERSAND_ENGINE_RENDER_LOOKAHEAD=0|4` registers the controlled engine arm.
Unset preserves the original draw path. Both registered values record the same
bounded, CPU-only draw evidence. With value4, GL Separate rendering and physics
interpolation disabled, Main may defer at most4 sync/draw opportunities while one
actual render-owner draw is outstanding. Each opportunity includes the complete
normal physics/idle/input work. The next Main producer turn executes the original
queue barrier before admitting another real draw. Thus the bound is4 skipped
opportunities and at most5 subsequent Main producer turns before that barrier,
not4 total turns or an absolute memory/command-byte limit.

The actual draw's CPU completion token is release/acquire published only after
`_draw` has returned. An old token neither renews the allowance nor proves newer
material/canvas commands retired. Main's next real draw follows its original
barrier. Manual/forced draws and interpolation transitions also drain the real
queue in selected4 Separate mode. No physics callbacks, native dependency credit,
`frame_pre_draw`, `frame_post_draw`, `frames_drawn`, force-redraw completion, GPU
completion or display scanout are fabricated. Skipped scaled render time is
carried into the next actual rasterizer draw so shader/particle time is conserved.

## Required application transaction

The engine refuses deferral without a current-process immutable prepared
presentation candidate and an actual live owner connected to
`frame_pre_draw` via `_commit_workbench_presentation_submission`. RenderingServer
metadata key `cybersand_actual_submission_v1` contains exact schema
`pubpres-actual-submission-v1`, true booleans `enabled`, `connected`,
`candidate_ready`, nonzero signed64 `owner_instance`,40 lowercase hexadecimal
`source_revision`, and the exact current integer `process_frame`.

The application must stage node/shader/canvas state before Main's existing
message flush. Its pre-draw callback commits bookkeeping only. Skipped process
candidates must not advance visible-pose/Follow/fairness history; pointer picking
must use the last actual submitted mapping. Owner, World, policy, material and
physical-completion changes must reject stale candidates. The transaction must
be enabled in both engine0/4 timing arms. It is not implemented by this engine
component and cannot be waived by setting metadata without the actual callback.

## Evidence and remaining gates

`CYBERSAND_ENGINE_RENDER_LOOKAHEAD_TRACE` names the required trace output in
registered runs. A preallocated32,768-row POD buffer records actual draw serial,
Main process frame, submission/render-owner CPU clocks, actual thread role and
carried/applied render step. Serialization occurs on Main only after render-owner
shutdown. Overflow, missing output, malformed ordering or mismatched draw totals
must invalidate qualification. The shutdown summary's whole-process sync wait
is not a capture-window CPU cost or physical-step metric. Render CPU return and
Main-delivered post-draw notification are not physical display observations.

First qualify source/API/PE and actual Windows startup/font behavior. Then run
application transaction/refusal/first-read framebuffer and material/actor/world
lifecycle gates, using actual Godot4.7, before ordinary Workbench comparisons.
Use matched0/4/4/0 and a stock Safe reference, independently built native runtime,
unchanged real completed-Rapier witnesses, actual frame submission joins, pose
and material wall ages, input response, CPU/memory and retained negative results.
Exercise small/medium/large active fluids, Follow, paint and multiple actors.
Bounded extra producer batches may increase queued resource retention; measure
that cost rather than assuming the integer bound is an absolute memory cap.
Physical NVIDIA execution remains a separate owner acceptance requirement.

## Local checks

The independently compilable `cybersand_frame_budget.h` is embedded byte-for-byte
in the engine patch. `test_frame_budget.cpp` challenges old/completed/duplicate
and out-of-order tokens, disabled ownership, all completion arrival points,
render-time conservation and4,000 real cross-thread release/acquire publications.
Its success is not a GPU or gameplay result. Python readers preserve the frozen
engine payload gates, allowing only independent file ordering between a patch
stack and Git's alphabetic combined diff; every within-file edit remains exact.

The arm also refuses an active engine debugger or render-frame/GPU profiler.
Profiler mode changes drain the real queue before changing the original flag.
Existing direct rendering statistics getters are not made generally thread-safe
by this scoped experiment; no whole-engine race-freedom claim is made.
