---
title: Coherent Workbench Windows acceptance
status: Current
document-kind: runbook
scope: Standalone Draft/HOLD evaluation; physical Windows 11 NVIDIA acceptance remains an owner decision
canonical-for: [camera-stack-coherence-physical-acceptance]
related-documents: [engine-lab-pose-tracing.md, native-pixel-scrolling.md, ../architecture/rendering-and-gameplay-bridges.md]
last-reviewed: 2026-11-15
---

# Evaluate coherent Workbench presentation on Windows

**Physical verdict: FAIL/HOLD.** The owner rejected application `43f46c6e5ec9`
with repeated 100–1000 ms actor/Rapier freezes. Its earlier automated pose checks
did not establish continuous physics. The corrective candidate adds terrain
installation/RID reuse and tests the actual coupled interactive defaults; the
owner's physical acceptance remains required. See the
[freeze investigation](../audits/2026-11-15-workbench-physics-freezes.md).

Extract the complete evaluation ZIP into a fresh writable folder. Everything
needed to run CyberSand and collect the comparison is included. No Godot,
Python, Git or repository installation is needed. Keep the included source and
runtime files together; `CAMERA-STACK-MANIFEST.json` identifies their exact
application source and retained native builds.

## Compare ordinary gameplay

1. Close other CyberSand windows and double-click **Open Workbench.cmd**.
   This opens the corrected Shared Workbench. Use **Engine Lab** to keep the
   FPS, VSync and tick settings visible. Start with your ordinary VSync setting.
2. Select a Needle, play, and fly through open space and near dense terrain.
   Try **Free camera** and **Follow selected**. Turn **Thruster fire** ON, then
   OFF while moving quickly. Watch the actor against fixed terrain edges.
3. Pan and zoom. Check both 1× and a fractional or greater pixel scale. Pause
   and resume; try **Restore start**. Paint a small visible patch, then Undo
   and Redo it. Confirm that the pointer still selects the intended cells.
4. Close CyberSand completely. Open **Open Original Presentation.cmd**, use
   the same setup and settings, and repeat the movement. It restores the
   original guarded actor selection and live camera following. Both launchers
   use the same physics, bounded material scans and repaired material history/ACK
   behavior. The original also retains coarse swept-clearance sampling; the
   corrected version can refine a false near-contact veto conservatively.
   This compares the original temporal-selection/camera policy and coarse guard
   with the correction; it is not a byte-identical historical #593 build.
5. **Open Mask Baseline.cmd** supplies the older material-bound display as an
   additional comparison. Its lower motion cadence is expected when native
   material publication is slow.

Judge whether the corrected version is materially preferable: terrain and
actors should move together; the previous large jumps and immediate reversals
should disappear; camera motion should remain aligned to framebuffer pixels.
Look for flicker, disappearance, long pauses or clipping near dense material,
especially during Fire ON→OFF. A clear regression is a **FAIL** even when the
automated capture completes.

## Collect the reproducible comparison

Double-click **Test It.cmd**. It opens sixteen successive test windows: eight
matched original/corrected pairs, ordinarily a few minutes on a hardware GPU.
Keep other CyberSand instances closed. A slow machine can take longer, and an
unfinished case retains its partial logs instead of being called a pass.

| Pair | Camera | Graphical target | Special condition |
| --- | --- | --- | --- |
| `interactive-follow` | Follow | Ordinary VSync/display default | Coupled native 60 / Rapier 60, Auto workers, Fire ON→OFF |
| `interactive-free` | Free | Ordinary VSync/display default | Coupled native 60 / Rapier 60, Auto workers, Fire ON→OFF |
| `follow60` | Follow | 60 FPS | Fire ON→OFF |
| `free60` | Free | 60 FPS | Fire ON→OFF |
| `follow30` | Follow | 30 FPS | Fire OFF |
| `follow120` | Follow | 120 FPS | Fire OFF |
| `slow-native` | Follow | 60 FPS | 2 Hz native target; Fire OFF |
| `delayed-ack` | Follow | 60 FPS | ACK delayed three rendered frames; Fire ON→OFF |

All pairs use the original 2048×2048 World and the same tick-addressed Needle
movement commands, including the labelled sustained-motion extension. Fire
events are a separate schedule at completed Rapier steps 0 and 60. The usual
targets for the six earlier diagnostic pairs are native 30 Hz, Rapier callbacks
120 Hz and publication 60 Hz, with the native-sample wait disabled. Those six
pairs alone do not exercise ordinary interactive physics. The two interactive
pairs retain the native-sample handshake, automatic worker request, initial VSync
and normal window/view size. Every case records its actual settings. Rapier
still advances 1/60 simulated second per completed step. The runner disables
VSync only for the earlier pacing comparisons; requested rates are not claims
about achieved performance.

For the shorter coupled Follow pair, run `Test It.cmd -Quick`. The previous ACK/history
investigation remains available with:

~~~powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Run-Test-It.ps1 -Cadence
~~~

**Open Original Cadence.cmd** restores that older ACK/history behavior too.
It is a separate diagnostic from **Open Original Presentation.cmd**.

## Read and return the result

Open the new timestamped folder under **Test-It-Results**. **READ-RESULTS.txt**
lists achieved native ticks, Rapier steps and Main overlay submissions per
second, measured frame intervals and presentation CPU time. Actual completed-step
gaps and native-sample/terrain-installation hold counts are reported separately
from visual holds. A continuously selected live pose can still represent stopped
physics; zero visual holds must not be read as smooth physical motion. Median, p95 and
p99 values include their sample count. Main submissions are not measurements
of physical monitor scanout.

**summary.json** and each case's receipt retain CPU, requested/resolved worker,
GPU/driver and Windows identity,
Godot's display DPI/scale/refresh and VSync settings, source and file hashes,
target and achieved clocks, Fire/tape identities, same-step physical trajectory
comparisons, intentional holds, withheld poses and failures. Original JSONL
traces, logs and two untimed reference framebuffers remain alongside them.
The runner also creates a ZIP of these local results; it does not upload it.

Fill in **ACCEPTANCE.md** with **PASS**, **FAIL** or **HOLD**, the settings you
used, and any repeatable visual defect. Return that file and the results ZIP;
if a visible problem remains, a short ordinary-play recording and the relevant
case name are useful. The corrected scripted arms reject a recorded source
rewind or a Follow target that differs from its selected actor pose. An
unexplained visible actor jump still needs investigation even if these checks
passed.

Hosted Windows qualification does not establish physical NVIDIA acceptance.
The owner retains the acceptance and merge gate; the camera PR stack remains
Draft/HOLD and unmerged during this evaluation.
