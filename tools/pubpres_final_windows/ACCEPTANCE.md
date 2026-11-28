# PUBPRES final owner test

**Draft / HOLD.** Record PASS, FAIL or NOT RUN. A hosted software renderer cannot
certify your Windows 11 NVIDIA device. The package does not promote or merge code.

1. Extract into a new writable folder and open **Open Workbench.cmd**. Confirm
   the printed source, official 4.7, Safe rendering and Full two-slot selection.
   Check Water Lab's active readback, not just a staged setting.
2. Open **Open Wave 512.cmd**, press **P**, pilot the Needle and test **Follow
   selected** plus Free camera. Fly and paint for at least five minutes. Record
   repeated pauses, stale poses, trails, lost edits and input delay even when
   render FPS is high.
3. Repeat with **Open Wave 1024.cmd** and **Open Wave 2048.cmd**. Use the same
   authored start when comparing controls. Include fluid contacts, large fills
   followed by small edits, erase, camera zoom and rotation.
4. Use **Open Mixed 2048.cmd** for multiple actors and Water/Sand contacts.
   Confirm the correct actor receives control and picking stays aligned with
   the rendered canvas. Pause, Step, resume, reset selected, and Restore start.
5. Save a named authored start, close the process, reopen the same command, and
   **Load start**. Verify materials, actors, equipment and settings. Evolved
   Water and live velocities are not part of Save start.
6. Repeat a longer session at your preferred display resolution. Note whether
   stalls, memory growth or incorrect histories accumulate. Optional Engine Lab
   reports and pose traces help locate a problem; they do not override what you
   observe in play.
7. Close Workbench. Add your results and shortest reproduction steps to
   `Runs/OWNER-ACCEPTANCE.md`; put screenshots/video stills in `Runs/Screenshots`.
   Run **Collect Results.cmd** and retain any files named as omitted by its index.

Return the collected ZIP and checksum, Windows version, NVIDIA model and driver,
display resolution/refresh rate, canvas, source/engine/slot selection, camera mode,
duration and observed freezes. Report whether each optional experiment was
actually run. Three-slot or patched-engine behavior is a separate result; keep
the ordinary control intact. Physical display-frame timing and input-to-visible
response remain owner observations unless independently instrumented on-device.

## Required physical NVIDIA evidence

Use the ordinary official-4.7 / Safe / Full-two-slot control for this matrix.
Record the full package/source identity and actual startup adapter/driver, then
the NVIDIA model and driver, Windows build, resolution, refresh rate and window
mode. The shipped standard evaluator uses the native OpenGL path by default;
an ANGLE run must be labelled separately. A hosted Basic Render Driver or
software-rendered result does not fill a physical-device row.

| Required row | What must actually be exercised | Evidence to retain |
| --- | --- | --- |
| Small canvas | Five minutes of Wave512 flight with active Water, Follow and Free camera, live paint and erase. | Duration, exact scene/profile, each visible freeze and approximate duration, input/control failures, stale pose or trail observations. |
| Medium canvas | Wave1024 with all four actors, fluid contact, picking, zoom and camera rotation. | Which actor was controlled, input response, material/pose alignment and observed gaps under interaction. |
| Large canvas | Wave2048 for at least five minutes with active Water, flight, Follow and repeated small edits after a large fill. | Native/physical progression observations, material freshness, any repeated long stalls, responsiveness before and after edits. |
| Mixed workload | Mixed2048 with Water, Sand, four actors and obstacles; pause, Step, resume, reset and restore. | Correct material and collision behavior, actor ownership, camera alignment, no stale histories after each transition. |
| Persistence | Save an authored start, close, reopen the same profile and Load start. | Restored material/actor/equipment/settings state and any mismatch; do not compare evolved fluid/velocity as saved state. |
| Sustained session | Continue the preferred ordinary workload beyond the initial five minutes, recording elapsed time. | Whether freezes, memory use or stale histories accumulate; close logs and collector index, including omissions. |

Mark each row PASS, FAIL or NOT RUN and describe the observation. A high FPS
counter, small upload duration, clean log or rising publication serial cannot
replace an actual physical-progress or responsiveness observation. When an
Engine Lab report or optional pose trace is captured, retain it with the manual
result and its instrumentation selection. Process CPU/memory observations cover
the recorded process lifetime; do not label them capture-window costs unless
their boundaries were actually joined.

For visible-display latency or stutter, retain an on-device capture with a time
reference and the associated input sequence. State whether it records submitted
frames, compositor delivery or the physical display. Input-to-visible delay
needs the input event and visible response on a common clock; a Main completion
timestamp or deferred draw notification alone cannot establish that delay. No
unmeasured scanout or input-latency number should be inferred from the collector.

If comparing optional frozen donor D, use the same authored scene, hardware,
graphics owner, resolution, observer selection and interaction sequence. Retain
both outcomes, including regressions. Three slots are an intentionally retained
adverse control after the matched hosted Windows regression; they are not part
of the required acceptance matrix and are not recommended for ordinary play.
The original EGL Separate engine is also outside the standard evaluator after
its ordinary startup failure. Physical NVIDIA acceptance remains HOLD until
these required ordinary-device rows are actually completed and reviewed.
