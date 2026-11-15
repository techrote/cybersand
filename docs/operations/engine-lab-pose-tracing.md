---
title: Engine Lab physical actor/camera frame trace
status: Current
document-kind: runbook
scope: Draft/HOLD coherent actor, terrain and camera candidate with retained cadence controls; physical NVIDIA acceptance pending
canonical-for: [render-cadence-investigation]
related-documents: [../audits/2026-11-15-render-cadence-001.md, ../architecture/rendering-and-gameplay-bridges.md, native-pixel-scrolling.md]
last-reviewed: 2026-11-15
---

# Engine Lab: locate Rapier and native-pixel camera divergence

The 14 November owner Windows GPU evaluation of PR #593 **failed** with
large, alternating actor-versus-terrain screen-space jumps. The owner later
observed that lowering some tick/publication rates made the visible freezes
last longer. This does not by itself establish an inverted camera offset,
physics error, or pose-source switching. The later inspected owner trace does
confirm backward selected-pose transitions while Rapier moves forward, with
negligible spatial projection error; it is not a time-aligned explanation of
each earlier video spike.

The corrected presentation contract is owned by
[rendering and gameplay bridges](../architecture/rendering-and-gameplay-bridges.md#coherent-workbench-presentation-frame).
The [camera-stack audit](../audits/2026-11-15-camera-stack-coherence.md) records
the original evidence and real production-path counterexample. The original
#609 tracer records what presentation has selected. Its separate
`fix/render-cadence-001-20261115` continuation repairs exact previous-texture
history and delayed-ACK deadlines while preserving simulation law and collision
gates. The [causal audit](../audits/2026-11-15-render-cadence-001.md) separates the
bounded repair from the remaining coupled-physics architecture. Keep Draft/HOLD.

## Default coherent presentation comparison

Extract the exact-source Windows package into a fresh writable directory, close
other CyberSand instances, and double-click **Test It.cmd**. It calls the bundled
PowerShell 5.1 runner with `-Coherence`; no Python, Git, Godot installation or
network download is needed. Six matched original/coherent pairs cover Free and
Follow, 30/60/120 FPS targets, Fire ON→OFF, deliberately slow native publication
and delayed ACK. Both arms use repaired ACK/history behavior and the same
movement tape. `Test It.cmd -Quick` selects one central pair. Use the
[practical guide](camera-stack-coherence-acceptance.md) for ordinary gameplay
comparison and the physical acceptance record.

The corrected arms require measured known selected steps, no recorded source
time reversal, and an aligned Follow target. Unknown visible timestamps remain
explicit in the report. These automated contracts do not establish smooth
physical display. `READ-RESULTS.txt` reports actual Main intervals and resolver
CPU median/p95/p99 with counts; JSONL retains holds, withholding and missed Main
presentation opportunities. Tracing remains opt-in for ordinary gameplay.

## Retained source-matched cadence campaign

For the earlier ACK/history investigation, explicitly run:

~~~powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Run-Test-It.ps1 -Cadence
~~~

This separate matrix retains original guarded actor presentation in both arms.
It makes 18 original/repaired cadence pairs (36 arms) in separate processes for
Pixel 30/60/120, Rapier callbacks 60/120, graphical FPS 30/60/120/uncapped,
material publication 30/60/120, Free/Follow, guarded/mask, ACK delay 0/3,
ordinary/gated publication, material crossfade and the original sample handshake.
The additional `native2` and `native2-free` counterfactuals request Pixel 2 Hz
with responsive Rapier 120 callbacks in Follow and Free cameras. This deliberately
low throughput uses the existing worker pacing control on the unchanged original
World, below measured native capacity, without changing the native step law or
adding artificial work. It supplements the required Pixel 30/60/120 targets,
which can all achieve similar rates when native execution is capacity limited.
Each row specifies all axes; this is an orthogonal causal matrix, not every
possible combination. `-FullCadence` explicitly requests the larger factorial.
`-Cadence -Quick` runs only the principal slow-native/responsive-Rapier pair.
The preserved `-Compare`, `-Quick`, no-flag and `-Full` modes retain the original
eight-action source-fenced test and Water-family modes.

Cadence arms preserve all eight original Needle commands at completed ticks
0,2,4,6,8,10,12,14 and append a labelled sustained-motion extension at 30,90,120.
They retain the original 2048-square JSON, 256 native generator receipts and
generated material hash. Capture lasts at least ten wall seconds and 144
completed Rapier steps, with an explicit deadline. A case that misses its
deadline reports failure and keeps its partial evidence.

Results are in `Test-It-Results/<timestamp>.zip`: exact payload/source identity,
hardware/driver identity, raw per-case receipts and JSONL, before/after
framebuffers, process exits, frame measurements and paired completed-step
physical trajectories. Captures happen outside the timed interval. A clean
runner exit means the experiment completed; it does not mean the motion passed
human acceptance. Inspect the actual rates and physical differences.

### What the rates mean

**Pixel Hz** paces completed discrete native steps. **Rapier Hz** currently
requests Godot physics callbacks while each actual physical step remains
1/60 simulated second. **FPS** controls graphical callbacks. **Publication Hz**
limits copied material snapshots. These clocks are reported separately.
120 Rapier callbacks with fixed 1/60 steps can run at twice real time; that is
not a validated real-time 1/120 integrator. Compare the same completed physical
step and input tape, and report simulated seconds separately from wall seconds.

The normal Workbench waits for the preceding native body sample. The explicitly
uncoupled diagnostic arm keeps its existing stale-wrench and terrain-install
refusals. A responsive air-flight result does not qualify asynchronous material
contact. Changing a callback target does not prove the requested rate was met.

The new default-off ACK gate holds material publication only. Native steps and
status can continue; explicit resync and accepted World replacement bypass the
gate. The ordinary policy is unchanged. ACK means successful CPU/Godot upload
submission, not GPU completion. Each delayed ACK now retains its original
process-frame deadline. `CYBERSAND_DIAG_RENDER_CADENCE=legacy` restores the two
old presentation defects for same-source controls; it never changes physics.

## Capture an actual physical test

1. Extract the new source-locked Windows artifact into a fresh writable folder.
   Start **Open Workbench.cmd**, select the same Needle flyer and 2048²
   world as the failed evaluation, and start Play.
2. Click **Engine Lab…** and scroll to **ACTUAL RENDERED-FRAME POSE TRACE**.
   Click **Trace poses: manual**. Reproduce the stuttering for ten seconds.
   The trace stops automatically; **Stop trace** also closes the buffered
   capture immediately.
3. Capture matched **Free camera** and **Follow selected** trials; compare
   **Open Original Presentation.cmd** to the corrected mode using fresh processes.
   **Open Mask Baseline.cmd** is an additional material-bound control.
   Vary Pixel tick Hz and material publication Hz separately, then restore
   60Hz baseline before varying Rapier callback Hz. Non-60Hz Rapier deliberately
   changes physical wall-clock speed, not the constant 1/60 simulated timestep.
4. The panel displays the saved JSONL path, in the local Godot user-data
   directory. No data is uploaded automatically. Preserve the file and
   optionally your MP4, driver info and exact Engine Lab clock settings.
   **Trace poses: scripted** runs the same four-direction, 60-Rapier-step
   per leg pattern to compare settings, but is not a substitute for the actual
   owner flight trajectory.

Recording is opt-in. Normal gameplay does no per-frame JSON allocation or
file IO for the trace.

## What one recorded Main frame contains

- Resolved presentation policy, selected/desired Rapier steps, explicit source
  reasons and holds, selected Follow target, resolver CPU cost and the exact
  frozen texture blend used by the shader. Negative/unknown steps are not evidence
  of temporal order. Known history survives hidden frames until identity/reset changes.
- Monotonic timestamp, process/physics frame indices, rendered frame delta,
  completed native tick, Rapier step and native/uploaded snapshot serials
- Requested floating-point camera origin, actually presented pixel-snapped
  camera origin, screen phase offset, physical window transform and shader
  world-to-screen mapping basis
- Selected follow-camera pilot ID and separately sampled authoritative
  Rapier/PhysicsServer2D pilot position
- For every body up to 32: live and mask-bound rigid transforms, source
  actually selected for the overlay (live, mask_bound, hidden), exact
  physical part transform submitted, per-body clearance veto reason,
  world-to-physical-screen projections and overlay/shader residual
- Mask session/epoch/generation/revision validity, previous-texture blend
  active flag, global guard summary, body/visible-part counts and source
  transitions with screen displacement
- Actual native completion/start, worker handoff, Main receipt, render-byte
  generation, upload return and issued/observed ACK timestamps; pending payload
  sizes, offered/consumed body serials and scheduler lateness. A latest-value
  body mailbox has sample distance, not an invented queue depth.
- Separate event rows for every completed Rapier step (pose, velocity, fixed
  delta, native-response acceptance), native completion, material publication,
  ACK and `RenderingServer.frame_post_draw`. Neither submission nor post-draw
  is a physical monitor scanout timestamp.

Frames are captured **once per Main overlay callback** after the actual
render_parts() and physical_actor_overlay.present() decisions. This is
not a GPU-present/fence timestamp; any device/driver queuing remains beyond
this trace's observational authority.

An in-memory cap of **12,000 frames** and **32 bodies/frame** prevents
unbounded capture overhead. The footer reports discarded or duplicated
frames; truncated bodies are identified explicitly. The trace writes JSONL
**after stopping**, not during flight.
Additional bounded logs retain 32,768 Main events and 16,384 worker events;
separate dropped counters forbid silently treating overflow as complete data.

## Analyze

With Python 3 available:

~~~powershell
python tools/ci/analyze_pose_trace.py "PATH\TO\engine-lab-pose-*.jsonl" --top 25 --output pose-report.json
~~~

The standalone artifact contains the analysis script at
tools/ci/analyze_pose_trace.py.
The offline Windows runner already reduces the key measurements using bundled
PowerShell. Python is optional for the deeper independent analysis, including
`--compare other-original.jsonl` and `--timeline-csv timeline.csv`.

The tool flags:

- **spatial_projection_mismatch** — the two independent world-to-screen
  formulae disagree for the *same* chosen pose by over one pixel. This
  implicates applied transform/zoom/rounding rather than stale data.
- **live_vs_bound_source_switch** — the source changes between two displayed
  frames; a visible screen-position jump directly measures the transition.
- **camera_screen_phase_jump** — the camera's physical-screen phase moves
  unexpectedly by more than two pixels.
- **stale_mask_bound_pose** — the bound source remains selected while the
  bound-versus-live actor separation is already large.
- **not_attributed** — an observed jump not explained by these readbacks.

These categories are diagnostic classifications, **not a verified root-cause
determination**. If actor and terrain differ only in timing while both
projections agree, repairing the snapped camera's sign will not cure the
problem. If the independent projection residual is large, investigate the
shader/native-pixel screen transformation itself.

## Guardrails

No changes to authoritative World bytes, native physics, Rapier step size,
collision clearance or render ACK identity. The repaired history retains one
extra World-sized CPU image (8 MiB for 2048-square RG8) and queries it only inside
the existing bounded swept region. This cost is measured; it is not an
unbounded per-pixel scan or a new smoothing delay. Neither this investigation nor a hosted
green CI job authorizes merging #606, #593 or #566. The owner-reported
physical acceptance remains **FAIL/HOLD** until independently re-tested.
