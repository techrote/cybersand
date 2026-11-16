---
title: Coherent Workbench Windows acceptance
status: Current
document-kind: runbook
scope: Standalone Draft/HOLD evaluation; physical Windows 11 NVIDIA acceptance remains an owner decision
canonical-for: [camera-stack-coherence-physical-acceptance]
related-documents: [engine-lab-pose-tracing.md, native-pixel-scrolling.md, ../architecture/rendering-and-gameplay-bridges.md]
last-reviewed: 2026-11-16
---

# Evaluate Workbench publication and physical progression on Windows

**Physical acceptance remains HOLD.** The owner rejected source `43f46c6e5ec9`
for repeated100–1000ms freezes. The later `c1ad4910a074` correction still has
long physical completion gaps. PHYSICS-FREEZE-REMEDIATION-002 adds bounded dirty
GPU layers and an early native physics completion mailbox. Its
[engineering record](../audits/2026-11-16-physics-freeze-remediation-002.md)
and the exact-source PR609 artifact ledger distinguish functional qualification,
measured improvement, and the owner's physical Windows11 NVIDIA decision.

Extract the full inner application ZIP into a fresh writable directory.
Godot4.7, native/Rapier and VC runtime dependencies are included. No separate
Godot, Python, Git or repository installation is needed. Keep the payload intact;
`CAMERA-STACK-MANIFEST.json` records its source tree and every packaged file hash.

## Ordinary gameplay acceptance

1. Close other CyberSand instances. Run **Open Workbench.cmd**, keep ordinary
   native/Rapier wait and wake enabled, and start with your usual FPS/VSync.
2. Fly a Needle continuously using Free and Follow cameras. Turn Thruster fire
   ON then OFF. Try dense material, near-terrain flight and actual hard contact.
3. Paint a small patch and a large area during simulation. Check material
   appearance, crossfade, actor/terrain alignment, and actual physical progress.
   Pause/resume, single-step, reset, Undo/Redo, Save, then fully exit and reopen.
4. Close the application and run **Open Publication Control.cmd** with identical
   settings. This uses full texture uploads and combined graphical/physical
   publication within the same reviewed source. Both paths retain coherent
   presentation, fixed-step physics and the normal native-sample safety fence.
5. **Open Full Texture Control.cmd** retains early physical publication while
   forcing whole-texture uploads. Engine Lab also switches texture modes live
   and reports the effective backend and any fallback. This isolates publication
   choices; these launchers do not reconstruct a historical binary.

A stable-looking actor with no actual movement is still a freeze. Look for long
pauses, catch-up, disappearance, material corruption or unsafe contact. A visible
regression is **FAIL** even when all automated captures complete. Full refresh,
initial allocation, dense changes and slow native computation can remain costly.

## Run the local comparison

Double-click **Test It.cmd**. It runs four fresh application processes: control
and candidate in Free and Follow. Both use the original2048² World, matched
Needle input tape, Fire ON→OFF at completed steps0/60, automatic native workers,
native60/Rapier60 targets, normal window/zoom and initial VSync. Native sample
wait/wake stays enabled throughout. The physical step remains fixed1/60 second;
configured targets are not achieved throughput claims.

**Test It.cmd -Quick** runs only the coupled Follow pair. The script is compatible
with Windows PowerShell5.1 and writes only local results. Fresh test profiles do
not change your saved worker preference. An explicit worker setting in ordinary
play may differ from Auto used by the repeatable capture.

The prior visual-policy and cadence investigations remain explicitly available:

~~~powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Run-Test-It.ps1 -Coherence
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Run-Test-It.ps1 -Cadence
~~~

**Open Original Presentation.cmd** retains the earlier temporal source selection
and live Follow policy. It is a separate visual comparison from publication
controls. The older uncoupled cadence cases are not ordinary-play acceptance.

## Read and return the result

Under **Test-It-Results**, **READ-RESULTS.txt** reports measured native and Rapier
completions, Main submissions, median/p95/p99/maximum physical gaps, counts at
50/100/250/1000ms, observed hold reasons, and publication stage durations.
Elapsed call scopes include possible waits and OS descheduling. They do not
isolate GPU execution, transfer bandwidth, or physical monitor scanout.

**summary.json** and raw JSONL retain actual source/runtime/CPU/GPU/driver,
requested/resolved workers, VSync/DPI, publication mode, input tape and Fire
identities. The comparison checks a complete common step prefix and exact
recorded position, orientation, linear velocity and native admission associations.
It does not record every hidden Rapier internal or numeric native force/torque.
Missing completions, changed recorded states or a failed case prevent a complete
comparison. Performance concerns stay visible even when correctness passes.

Return the automatically created results ZIP and **ACCEPTANCE.md**, marked
**PASS**, **FAIL** or **HOLD**. Include settings and reproduction steps, plus an
ordinary-play recording if a visible freeze remains. Successful hosted WARP or
llvmpipe execution is not physical NVIDIA acceptance. All four PRs remain
Draft/HOLD and unmerged until the owner's decision.
