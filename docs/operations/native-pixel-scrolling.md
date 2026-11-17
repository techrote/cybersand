---
title: Native-resolution pixel scrolling candidate and acceptance
status: Current
document-kind: runbook
scope: Unmerged camera candidate, standalone Windows controls, focused runtime qualification and owner acceptance
canonical-for: [native-pixel-scrolling-acceptance]
last-reviewed: 2026-11-13
related-documents: [../systems/material-appearance-and-rendering.md, ../reference/interfaces-and-message-contracts.md, wb-art-paint-integrated-candidate.md, ../audits/2026-11-13-native-pixel-scrolling.md, local-build-and-validation.md]
---

# Native-resolution pixel scrolling

**Current implementation candidate; Draft / HOLD until owner acceptance.**
The camera keeps fractional world-cell positions and moves the displayed world
in final framebuffer-pixel increments. At 4 display pixels per cell, one
display-pixel movement no longer waits for a whole 4-pixel cell jump. Material
cells retain nearest-neighbour edges and their existing native state.

The final integration preserves the original camera branch and accepted main
`ac0d9fb944cb5a81369d03c0c3bc5eab50ab6742` through normal merge
`b1e2e9b1ce0a93d9eda54cbc35d04257eba9dfa7`. Accepted #565 includes Materials
Lab, native capability consumption, PAINT, agent authoring and chronological
shared Undo/Redo. The palette and recording implementation is unchanged by that
reconciliation. Final qualification adds a narrow correction for the actual
root Window's framebuffer stretch and stationary pointer tracking; the camera's
continuous state and pixel-sampling design are preserved. The
[final integration record](../audits/2026-11-13-native-pixel-final-integration.md)
separates the resulting-source campaign from the earlier stacked qualification.
The camera branch does not modify either upstream branch. The
[dated qualification ledger](../audits/2026-11-13-native-pixel-scrolling.md)
owns the actual tested source, runtime/package identities, compatibility result
and remaining gates. Earlier Workbench packages do not contain this camera fix.

## Open the Windows candidate

The earlier [qualified Windows evaluation archive](https://github.com/techrote/cybersand/actions/runs/43403189531/artifacts/14029270531)
is for application source **`005124c5cd9a`**: 92,938,556 bytes from successful
run 43403189531. It includes the fractional-camera recording correction, but
predates accepted #565. The current combined download and exact qualification
are published in the [PR #566 delivery ledger](https://github.com/techrote/cybersand/pull/566).
Do not treat the earlier archive as the final combined application.
Extract the complete archive into a new writable folder, then double-click
**Open Workbench.cmd**. Keep the bundled files together. The launcher imports
the included project and opens the Workbench using its bundled Godot 4.7 and
source-built native extension. The
[dated ledger](../audits/2026-11-13-native-pixel-scrolling.md#refreshed-windows-installed-qualification-and-evaluation-build)
records the verified ZIP checksum, full source/installation qualification and
remaining physical acceptance gates. The earlier `a8f27357` camera archive
predates this recording correction.

An archive is deliverable only after the workflow has successfully tested the
same source and the copied Windows installation. A pending workflow or an older
Workbench artifact is not a qualified camera package.

## Owner acceptance

1. Pause the simulation and choose **Free camera**. Use a map with a clear,
   stationary wall or paint a small solid rectangle so movement is easy to see.
2. Use the mouse wheel or **+** button until cells occupy roughly 2–4 display
   pixels. Hold the middle mouse button and drag very slowly, then at medium
   and rapid speeds, horizontally and diagonally. The sharp image should slide
   in smaller display-pixel steps without jumping a whole enlarged cell.
3. Stop dragging. Edges and material grain should remain still. Pan across
   chunk joins and to all map edges; check for seams, uncovered strips, or
   glow/vapour edges moving separately from their materials.
4. Place the pointer over a distinctive interior cell and wheel in and out
   repeatedly. The continuous world anchor should return without accumulating
   drift. Display rounding can shift the point previously under the pointer
   by up to 1.5 physical pixels per axis for a 2x zoom-in. The continuous
   anchor itself is preserved; zooming in and back out returns to the same
   camera position within floating-point precision. World-edge clamping can
   deliberately move the anchor farther when the view would leave the map.
5. With the camera left between whole-cell positions, paint and erase a single
   cell; draw a line and rectangle; fill a bounded area; Select, Copy and Paste
   mixed materials; then Undo and Redo. Each operation and preview must target
   the cell under the displayed pointer. Open **Art batches** and use **Select**
   to check that Focus X/Y/W/H still matches the inclusive selected cells.
6. Try **Follow selected** with a moving actor, then return to Free camera.
   Resize the window and repeat slow panning at the Windows display scale you
   use, and at **125%, 150% and 200%** where practical. Save, close and reopen
   an authored setup to confirm its contents remain correct. Record the
   candidate SHA, display scale, window size and any defect.

The existing camera modes, middle-button pan, wheel and **−/+** controls remain.
Wheel zoom uses the pointer position; the toolbar zoom buttons use the view
centre. No camera-easing control or change to simulation resolution is required.

## Reproduce the automated camera campaign

After the ordinary source build and Godot import prerequisites described in
[local build and validation](local-build-and-validation.md), run the focused
entry point from the repository root. Supply an actual Godot 4.7 executable:

```text
python tools/ci/run_workbench_qualification.py camera --godot /path/to/Godot_v4.7-stable_linux.x86_64 --project godot --evidence build/native-pixel-scrolling/camera
```

On Windows, use the console executable with the same command arguments. On
Linux, the command needs an X11 display; hosted execution supplies Xvfb. The
runner imports the project, executes coordinate/native editing assertions, then
runs the actual gameplay recorder at fractional camera positions, framebuffer
scrolling, production glow/vapour fixtures and the
existing material, water, vapour-history and crossfade preservation cases. It
requires completion markers and retains source hashes, logs and frames.
Headless parsing cannot satisfy either graphical fixture.
Mounted root-window cases additionally exercise 960×720, 1280×960 and
1920×1080 geometry, using an independent renderer transform for phase, picking
and stationary-hover checks. The scrolling fixture renders actual stretched
root windows and retains the previous transform as a negative control.
The existing matrices include 1x, 2x, 2.5x, 4x and 8x motion. At 1x, an actual
rendered sequence accumulates fractional requests, holds or advances physical
pixels, reverses both axes and returns to the original image. A mounted 1x
root-window case separately checks the measured physical basis, framebuffer
cells and real integer/fractional GUI input.
Native-mapped partial Water and the actual PAINT fill raster are also checked
at fractional camera positions. Independent cases continue after a failure to
retain their diagnostics; the overall camera/package gate still fails.
The recorder case checks the retained material bytes at partially visible
right/bottom cells, fixed-session bounds and actual-world
clamping. The camera campaign has nine invocations including import; older
eight-invocation results retain their original source scope in the audit.

The [integrated camera workflow](../../.github/workflows/native-pixel-integrated-qualification.yml)
is the camera branch's source-built qualification entry point. It rebuilds Linux
and Windows native runtimes, preserves complete Materials Lab and Workbench
coverage, runs source/installed camera cases, and packages the standalone
combined application. It also executes the recorder's separate CLI override
mode. Admission dispatches the unchanged full Documentation, Native, Godot and
Palette workflows on the exact branch head while the PR remains Draft. A
dispatch receipt proves only that execution was requested; inspect the actual
resulting jobs. Performance uses independent same-host ABBA jobs and cannot
withhold an otherwise valid Windows package solely because research apparatus
fails. The final technical decision still records every failure or missing gate.

## Scope and limitations

The [rendering contract](../systems/material-appearance-and-rendering.md#native-resolution-pixel-scrolling)
owns the coordinate and sampling design. The native simulation, material IDs,
cell physics, snapshot format and authored setup format are unchanged. Rendering
still consumes immutable snapshots. Fractional zoom can give adjacent cells
different integer screen widths; stable common translation and nearest sampling
preserve sharpness without promising equal widths at a non-integer scale.

Actual Windows DPI/compositor behaviour and perceived camera feel require the
owner's desktop check. Automated scaling transforms are useful evidence but do
not substitute for that check. GPU throughput and frame pacing are qualified
only to the extent recorded in the dated ledger; no merge is authorized here.
