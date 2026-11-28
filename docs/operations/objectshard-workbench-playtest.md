---
title: Destructible structures in the ordinary Workbench
status: Current
document-kind: guide
scope: Opt-in ObjectShard M4 candidate controls, authored-save scope and physical Windows evaluation
canonical-for: [objectshard-m4-workbench-playtest]
last-reviewed: 2026-11-28
related-documents: [objectshard-m3-preflight-playtest.md, ../research/objectshard-001.md, ../audits/2026-11-24-objectshard-m4-source-recovery.md]
---

# Destructible structures in the ordinary Workbench

This guide covers the **28 November reliability-convergence candidate**.
The [qualified Windows evaluator](https://github.com/techrote/cybersand/actions/runs/46103413203/artifacts/15249152001)
uses application source `b7d889b925ab3244d10e6fe48f487fbe0dc1ce73`.
Its inner `objectshard-workbench-evaluator.zip` is **96,694,450 bytes**, SHA-256
`04308deb50e8044054c624a4adf200a04bc1b7c8034621e0576338b79009d8e7`.
The actual shipped launcher and 32 clean extracted replay cases passed, followed
by independent archive verification. The packaged guide retains its exact
qualified source version; this repository paragraph adds the final download identity.
PR #754 remains **Draft/HOLD** for physical Windows 11/NVIDIA evaluation. The
[convergence evidence](https://github.com/techrote/cybersand/blob/integration/objectshard-m4-mainline-20261122/docs/audits/objectshard-m4-reliability-20261128/presentation-delivery.md)
separates completed qualification from work still pending; the older successful
campaign below does not qualify later source changes. The candidate uses the ordinary
Workbench canvas, painting, Water controls, actors and Rapier space. The
independent ObjectShard Lab and M3 rehearsal remain available as historical
test facilities. Their results do not qualify this integration.
The [physics findings](https://github.com/techrote/cybersand/blob/integration/objectshard-m4-mainline-20261122/docs/audits/objectshard-m4-reliability-20261128/physics.md)
and [controlled timing comparisons](https://github.com/techrote/cybersand/blob/integration/objectshard-m4-mainline-20261122/docs/audits/objectshard-m4-reliability-20261128/throughput.md)
are available for technical review. The physical-machine checks below remain
necessary, including the multi-body rate; the provisional eight-active-body
performance objective has not been declared passed.
Those technical links open the current mission evidence on GitHub. The
packaged manifest identifies this evaluator's exact frozen source and runtime.

## Open the evaluator

The GitHub artifact download is an outer ZIP. Extract it, then extract the
contained **objectshard-workbench-evaluator.zip** into its own directory. Run
**Open Workbench.cmd**. Keep the packaged engine, project, manifest and verifier
together. The launcher verifies the delivered files before starting the
interactive Workbench. The package manifest identifies the exact source,
native runtime and selected Godot/Rapier dependencies.

This evaluator explicitly selects Godot's **ANGLE** compatibility renderer
(`opengl3_angle`). Its ordinary launch and shipped launch self-test use the same
renderer arguments, and the manifest records that choice. Include the actual
renderer and adapter in performance observations. The repository's ordinary
project renderer defaults are preserved.

The launcher exposes the experimental **Structures…** panel in ordinary
Workbench and selects the **Multi-storey tower** start. Select another
demonstration in that panel or choose **Enable on current canvas** for your own
authored scene. Ordinary launches keep their existing defaults.
On the first admission, wait for **Preparing structure materials…** at the start
of the status line below the controls to finish before cutting or pressing Play.
This prepares the additional shared material shader once for this application
process. Later scene changes reuse it. The scene keeps its Pause state. A cold
software renderer can spend tens of seconds here; this preparation time is
separate from the subsequent simulation rate.
The candidate is bounded; an unsupported canvas, roster or exhausted geometry
budget must show a refusal while preserving existing ownership.

For your own construction, use **Details** to set **New width** and **height**
to 512 or 1,024, create the **New blank** canvas, then choose **Enable on current
canvas**. The ordinary 2,048-cell default exceeds this candidate's supported
extent and is visibly refused. Loading any of the five demonstration starts
sets up a supported canvas directly.

In the consolidated candidate, ground actors and their equipment can share
the structural Rapier space. A 4LY flight actor requires one fixed Rapier
step per actor tick. Structures subdivides that interval for material
collisions, so **Enable on current canvas** refuses a roster containing a
4LY aircraft. Placing or replacing a ground actor with a 4LY aircraft also
refuses while Structures is enabled. The current scene remains usable in
both cases. Load a complete authored flight start to leave Structures, or
choose a demonstration in **Structures…** to replace the flight scene.
Ground AMBIENT actors measure the actual completed Rapier duration across
substeps. Paused intervals do not advance their policy clock.

From a qualified source checkout, the equivalent explicit entry is:

```text
Godot_v4.7-stable_win64.exe --rendering-driver opengl3_angle --path godot -- --shared-workbench --objectshard-m4-workbench --object-shard-scene=tower
```

The source checkout still requires a source-matched native extension. The
portable evaluator supplies one; an arbitrary retained DLL is not a substitute.

## Short owner evaluation route

Start with the exact delivered archive and keep recording **off** for the first
pass. The normal **Open Workbench.cmd** opens **Multi-storey tower**. In the top
Workbench toolbar, **Structures…** is between **Art batches** and **Batch Lab…**.
The camera selector is beside **Water Lab…**, with **−** and **+** immediately
after it. The first selector on the next row chooses **Paint**, actor tools or
the moving-material tools. The compact drawing row contains the drawing-tool
selector, material selector, **Radius**, map name, **Save start [Ctrl+S]** and
**Load start**.

| Check | Exact controls and action | Expected visible result |
| --- | --- | --- |
| Tower and reference barrel | Choose **Structures… → Multi-storey tower**. Close the panel if needed. Use **Play / Pause [P]** beside **Pilot**. Keep the next-row mode on **Paint**, choose **Eraser** in the drawing row or press **E**, and remove the two narrow support stems below the tower's bottom floor. | The tower at the left detaches and falls. The separate barrel on the far right should remain on its floor until an actual contact reaches it. A small notch can leave stumps that legitimately support the tower; remove more of the lower stems for a full drop. |
| Repeated small fragments | In the next-row mode selector choose **Cut moving**. Click a visible wooden edge, then hold and move slowly across another edge. Pause for a precise cut if needed. | One visible cell is targeted at a time; the cursor follows that cell. Geometry changes and detached pieces remain physical. Short transaction waits are normal. Ordinary recoverable cuts should not leave the World permanently Held. |
| Active-body speed | Resume with **Play / Pause [P]**, leave the camera fixed and watch a fresh fall with recording off. Repeat the same view with timing recording on. | Visible collapse and ordinary material simulation continue. The status line below the controls reads **structures Running** with the admitted body count. A smooth window alone is not evidence of fast semantic progression; retain a diagnostic comparison if the fall remains slow. |
| Camera during collapse | Over the World, wheel to zoom and middle-drag to pan. Select **Overview** in the top-row camera selector to return to the whole canvas. Resize the window, then repeat while paused. | Terrain, structural textures and actor positions remain aligned. Structures stay inside the aspect-fitted World rectangle. A Held scene, if one occurs, must remain inspectable with the same controls. |
| Detached appearance | Zoom in before cutting, then inspect the same brick and timber after release and rotation. Use **Pause** to compare a stable view. | Detached brick, timber, concrete and metal use the ordinary material finishes. Patterns stay attached to the captured material coordinates as the body rotates, with genuine empty holes. Cuts and burning update the material view after acknowledgement. |
| Eight-body demonstration | Choose **Structures… → Eight-body collapse**, then **Play**. Erase each narrow support underneath the eight frames. | The status body count grows toward eight, the frames fall independently, and camera controls remain usable. The existing 16-body budget still applies; this is not a larger-budget stress mode. |
| Diagnostic recording/export | Open **Structures…**. Below the five scene buttons turn on **Record performance timings (optional)**. Play for about 15 seconds, turn it off, then click **Save diagnostics** immediately below. | The panel's message beneath the buttons displays the saved JSON path. **Open diagnostics folder**, beside **Save diagnostics**, opens it. Save even with recording off after a refusal: the file still includes current ownership and refusal details. |
| Authored save/reopen | Before cutting, choose a distinctive map name in the drawing row and click **Save start [Ctrl+S]** next to it. Close with **Menu [F2]**, reopen the Workbench, enter the same name and click **Load start** beside Save. | The authored construction and ordinary brush edits reopen. Moving poses, moving-cell cuts and evolved chemistry are not a live checkpoint. **Restore start**, next to **Reset selected [R]**, rebuilds the current authored recipe; choose the original Structures scene button to reload an intact demonstration. |

The status line presents **Starting**, **Running**, **Paused/Pausing**,
**Editing / rebuilding**, and an explicit **Waiting for native transaction**
only for a sustained receipt wait. Internal phases remain in the tooltip and
exported diagnostics. **Held** is placed first in the status line, with its
reason and the visible route **Structures → Save diagnostics; Restore start**.
A capacity refusal still preserves the owned material and remains explicit.
If the reason is **MaterialPreparationFailed**, save diagnostics, close the
application and start it again. That preparation failure names the restart
route in the status line; **Restore start** does not restart process-local
shader preparation.

## First collapse

Choose **Multi-storey tower**, start play, and erase the narrow vertical support
stems below its bottom floor. Keep the first mode selector on **Paint**, then
choose **Eraser** in the drawing-tool selector or press **E**. Clear enough of their
height for a full drop. A small notch can let the structure land on the remaining
stumps, which is a valid physical result. The native structural inventory is
transferred into coherent physical bodies only after genuine geometry and
mass installation receipts. The falling material should keep its identity,
interact with the terrain, and remain available for further edits.

In the first mode selector, choose **Cut moving** for a witnessed edit of a
moving structure, or **Ignite moving** to ignite supported combustible
material. These tools mark
one visible cell, and the ordinary paint radius is disabled. Hold and move
slowly to make successive edits; each edit waits for the preceding native and
geometry receipts. Releasing the button or switching tools cancels the held
intent. No interpolated stroke is stored for later replay. Pause for a
deliberate cut when a rapidly moving target is difficult to select. If the
observed target changed before execution, a stale-target refusal is a safe
outcome; it must not erase unrelated native terrain.

Ordinary painting remains available around the moving structures. Use Sand,
Water and Fire to observe coupled behavior. Switching tools or camera modes
must not replace the native World, duplicate the material, or restart a body.
Select **Paint** again to return to the ordinary Brush/Eraser controls.

Choose **Overview** to frame the whole canvas. Over the canvas, use the mouse
wheel to zoom and drag the middle mouse button to pan; the toolbar's **+** and
**−** buttons also change zoom. **Follow selected** tracks the selected ordinary
actor. Free camera, zoom and pan let you inspect the moving structures directly.

For a quiet body lying almost horizontally or vertically, **Pause**, choose
**Settle into canvas**, and select its material. The candidate freezes the real body, checks
the destination cells, transfers its exact inventory back to native terrain,
and removes its physical body only after the corresponding receipts. This
explicit conversion snaps its origin to the nearest cell. A moving, oblique,
overlapping or otherwise busy body is refused and stays physically owned.
You can paint or erase the returned cells with the ordinary tools.

## Five demonstration starts

| Start | What to try | What to observe |
| --- | --- | --- |
| Multi-storey tower | Remove its supports; cut a coherent section again after falling. | Substantial sections detach, topple and collide with the same native terrain. |
| Three-span viaduct | Remove selected piers before the remaining ones. | Separate spans fall in sections and meet the terrain and Water. |
| Burning timber workshop | Ignite timber, release it, and keep playing. | Combustion continues under moving material ownership; products and geometry changes are visible. |
| Wood, brick and liquids | Release the mixed structure into Sand and Water, then introduce Fire. | Structural materials stay in coherent bodies while surrounding materials retain their native simulation. |
| Eight-body collapse | Release the supports and alternate overview/follow camera. | Multiple active bodies, bounded admission, continuing progression and usable authoring. |

These starts are ordinary material-cell recipes. They do not pre-spawn
animated shard bodies or substitute a scripted visual collapse for physics.

## Pause, reset and save

**Play / Pause [P]** and **Step [.]** retain their ordinary Workbench meanings.
Pause must leave the last acknowledged body/material state intact; resuming
must continue that ownership. Use **Restore start** to rebuild the current
authored recipe in a fresh World. Ordinary paint and Erase strokes update that
recipe, including cuts through the original supports. Those cuts remain after
Restore, so the rebuilt structure can detach again when you resume. Select the
named demonstration in **Structures…** again to reload its intact original.
**F2** closes the session and returns to the
launcher. Reset/replacement must retire both the old native and physical owners
before accepting new receipts.

**Save start** saves the current authored Workbench recipe and its ordinary
brush changes. Save before removing supports if you want that uncut custom
construction available later. Reopening it reconstructs the saved recipe; it
does not save moving-body cuts, moving poses, live combustion, inventories or
a physical replay. Operations that would silently omit shard-owned
material from a purported live save or flatten must refuse visibly. A refused
same-World disable or reabsorption must not discard live material.

## Frame rate and actual progression

Assess displayed smoothness and simulation progression separately. A fluid
window can still contain slow physical progress, and rapid native ticks can
still be displayed poorly. The candidate's diagnostics separate:

- Native semantic ticks observed by Main, including coalesced publications.
- Main callback and physics work durations.
- Renderer post-draw callback intervals, grouped by body count, pause state and
  camera mode.
- Native/Rapier ownership, geometry and moving-cell receipt outcomes.

Renderer callbacks establish that the engine submitted work; they do not prove
the exact frame displayed by the NVIDIA driver. Headless runs cannot establish
displayed FPS. The owner's previous diagnostic measured approximately 17–24
native semantic ticks per second before the protective halt. A headless 60 Hz
callback cannot establish that physical-machine performance has improved.

Performance recording is **off by default**, including in the portable
evaluator. Ordinary play retains the full native, Rapier, chemistry and
publication protocol. Open **Structures… → Record performance timings
(optional)** to start a fresh bounded recording. Play the comparison, then turn
recording off and select **Save diagnostics**. Stopping preserves the recorded
timings while normal play continues; starting another recording clears the
previous timing samples. The explicit `--objectshard-diagnostics` launch flag
is an alternative when invoking the packaged Godot engine directly; **Open
Workbench.cmd** uses its fixed qualified launch arguments. The checkbox is the
normal portable-evaluator control.

**Save diagnostics** writes a local JSON snapshot of the current scene, camera,
source identity, renderer and native/physics receipts, together with the
recorded timings when available. Saving while recording is off remains useful
for ownership/refusal diagnosis; an empty timing section means no recording was
made. No files are written automatically. The panel shows the saved path;
**Open diagnostics folder** opens that directory.

For an inexpensive comparison, keep the same window size, renderer and camera.
Record about fifteen seconds with the intact tower paused, fifteen seconds
with it playing, then remove the supports and repeat during the fall and while
paused with the detached body. Save each recording separately. Repeat with the
eight-body scene if ordinary input remains usable. First assess play with
recording off, then compare with recording on; recording changes only
observation and must not change the body population or simulation settings.

Water contact can extinguish moving Wood; Sand can lodge in supported pockets
and contribute to mass. The existing lodging law uses upward-open pockets one
to three cells wide. The independent ordinary Windows witness verified a real
63-Wood pocket carrying one painted grain, with native and actual Rapier mass
increasing to 64 after geometry acknowledgement. The wider architectural gaps
in the Mixed demonstration show conservative Sand displacement; they are not
the narrow-pocket ingestion witness. This candidate does not add buoyancy, fluid drag or
native Sand impact impulses to mutable structures. Dense fluid with no nearby
empty relocation cells can stop the candidate with a refusal. The attached
search is bounded to 64 cells and 1,048,576 destination probes per composition;
the saved diagnostics include those bounds. Restore start
recovers the authored setup without treating that refusal as successful motion.

## Physical Windows/NVIDIA observations

The owner evaluation should use the exact delivered package and record:

1. Whether the tower and viaduct detach and continue to topple after support
   removal, including a small residual offcut near the cut.
2. Whether small moving-cell cuts cause plausible geometry changes without
   sudden extreme angular motion.
3. Whether burning moving timber continues its reaction, responds to Water,
   and can be edited again.
4. Whether ordinary painting, camera changes, pause/resume, restore and
   authored save/reopen remain usable with active bodies.
5. Displayed active-body frame rate and visible freezes, especially in the
   multi-body scene, alongside the separately recorded native progression.

Include the source/runtime manifest, chosen scene and camera, approximate body
count, display resolution, Godot renderer, NVIDIA driver and the exported
diagnostics with an observation. A brief screen recording is useful for
toppling, small-cut rotation and intermittent stalls. Hosted or software-rendered
results do not replace this physical-machine acceptance.

The final qualification record must distinguish passed engineering tests,
remaining implementation failures and owner-pending physical observations.
This guide itself grants no merge, Ready or default-promotion authority.

## Historical evaluator and evidence

The owner evaluated the later [Windows artifact 15176676582](https://github.com/techrote/cybersand/actions/runs/45944204842/artifacts/15176676582),
with application source `efe3bc19c68a9b9e292821ef28b735caec538915` and observed
PR head `1ec3f214662f7d5a0a38ff727b684c15b41c067b`. The physical motion halt,
barrel/camera observations and measured 17–24 semantic ticks/s from that
evaluation motivated this convergence mission. The older completion below is
retained as historical engineering evidence, not as qualification of this fix.

The [frozen November 25 Windows evaluator](https://github.com/techrote/cybersand/actions/runs/45530425519/artifacts/14986488170)
contains **objectshard-workbench-evaluator.zip**, **93,388,322 bytes**, SHA-256
**1c5dd8ac305ab81996767841dfb0bbcf1db319c9a368c31f104df8e2579ec387**.
The GitHub download is an outer archive; extract its inner ZIP, then extract the
complete evaluator before launching.

The tested application, native build and package source is
`5f0722ae231d955a98a83b0fbb9a0e7517ef2d8a`, tree
`51ff1e6a0949dff3b2b17cdca7a40d4943b05f78`.
The full native/Linux/Windows campaign, actual shipped CMD, pristine replay and
independent archive review passed. Additional unchanged-package Windows
witnesses passed authored save/reopen, live moving-cell Cut and positive Sand
cargo transfer. See the
[final engineering decision](https://github.com/techrote/cybersand/blob/integration/objectshard-m4-mainline-20261122/docs/audits/2026-11-25-objectshard-m4-final-decision.md)
and [complete performance analysis](https://github.com/techrote/cybersand/blob/integration/objectshard-m4-mainline-20261122/docs/audits/objectshard-m4-recovery-20261125/final-performance-5f.md).
These results do not establish physical NVIDIA presentation speed.
The packaged guide remains its exact qualified source version; this repository
page records that delivery. For a newer extracted candidate, the included
`objectshard-workbench-manifest.json` identifies its own source, dependencies
and file hashes.
