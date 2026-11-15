---
title: Engine Lab physical actor/camera frame trace
status: Experimental
document-kind: runbook
scope: Opt-in diagnostic instrumentation on top of Draft #606 and #593
last-reviewed: 2026-11-15
---

# Engine Lab: locate Rapier and native-pixel camera divergence

The 14 November owner Windows GPU evaluation of PR #593 **failed** with
large, alternating actor-versus-terrain screen-space jumps. The owner later
observed that lowering some tick/publication rates made the visible freezes
last longer. This does not by itself establish an inverted camera offset,
physics error, or pose-source switching; all remain hypotheses.

This tracer intentionally does **not** repair or change the simulation.
It records what the existing production presentation has already selected.

## Capture an actual physical test

1. Extract the new source-locked Windows artifact into a fresh writable folder.
   Start **Open Guarded Workbench.cmd**, select the same Needle flyer and 2048²
   world as the failed evaluation, and start Play.
2. Click **Engine Lab…** and scroll to **ACTUAL RENDERED-FRAME POSE TRACE**.
   Click **Trace poses: manual**. Reproduce the stuttering for ten seconds.
   The trace stops automatically; **Stop trace** also closes the buffered
   capture immediately.
3. Capture matched **Free camera** and **Follow selected** trials; compare
   **Open Mask Baseline.cmd** to guarded mode using fresh processes.
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

Frames are captured **once per Main overlay callback** after the actual
render_parts() and physical_actor_overlay.present() decisions. This is
not a GPU-present/fence timestamp; any device/driver queuing remains beyond
this trace's observational authority.

An in-memory cap of **12,000 frames** and **32 bodies/frame** prevents
unbounded capture overhead. The footer reports discarded or duplicated
frames; truncated bodies are identified explicitly. The trace writes JSONL
**after stopping**, not during flight.

## Analyze

With Python 3 available:

~~~powershell
python tools/ci/analyze_pose_trace.py "PATH\TO\engine-lab-pose-*.jsonl" --top 25 --output pose-report.json
~~~

The standalone artifact contains the analysis script at
tools/ci/analyze_pose_trace.py.

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

No changes to World bytes, native physics, Rapier step size, collision
clearance or render ACK identity. Neither this investigation nor a hosted
green CI job authorizes merging #606, #593 or #566. The owner-reported
physical acceptance remains **FAIL/HOLD** until independently re-tested.
