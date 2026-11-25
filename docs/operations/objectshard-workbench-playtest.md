---
title: Destructible structures in the ordinary Workbench
status: Current
document-kind: guide
scope: Opt-in ObjectShard M4 candidate controls, authored-save scope and physical Windows evaluation
canonical-for: [objectshard-m4-workbench-playtest]
last-reviewed: 2026-11-25
related-documents: [objectshard-m3-preflight-playtest.md, ../research/objectshard-001.md, ../audits/2026-11-24-objectshard-m4-source-recovery.md]
---

# Destructible structures in the ordinary Workbench

This is the **Draft/HOLD ObjectShard M4 candidate**. It uses the ordinary
Workbench canvas, painting, Water controls, actors and Rapier space. The
independent ObjectShard Lab and M3 rehearsal remain available as historical
test facilities. Their results do not qualify this integration.

## Open the evaluator

Extract the complete portable Windows package into its own directory and run
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
Workbench. Select a demonstration or choose **Enable on current canvas** for
your own authored scene. Ordinary launches keep their existing defaults.
The candidate is bounded; an unsupported canvas, roster or exhausted geometry
budget must show a refusal while preserving existing ownership.

For your own construction, use **Details** to set **New width** and **height**
to 512 or 1,024, create the **New blank** canvas, then choose **Enable on current
canvas**. The ordinary 2,048-cell default exceeds this candidate's supported
extent and is visibly refused. Loading any of the five demonstration starts
sets up a supported canvas directly.

From a qualified source checkout, the equivalent explicit entry is:

```text
Godot_v4.7-stable_win64.exe --rendering-driver opengl3_angle --path godot -- --shared-workbench --objectshard-m4-workbench --object-shard-scene=tower
```

The source checkout still requires a source-matched native extension. The
portable evaluator supplies one; an arbitrary retained DLL is not a substitute.

## First collapse

Choose **Multi-storey tower**, start play, and erase the narrow vertical support
stems below its bottom floor with the ordinary Erase tool. Clear enough of their
height for a full drop. A small notch can let the structure land on the remaining
stumps, which is a valid physical result. The native structural inventory is
transferred into coherent physical bodies only after genuine geometry and
mass installation receipts. The falling material should keep its identity,
interact with the terrain, and remain available for further edits.

Use **Cut moving** for a witnessed edit of a moving structure, and
**Ignite moving** to ignite supported combustible material. These tools mark
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
displayed FPS. Do not use a headless 60 Hz callback as acceptance of the earlier
owner-observed active-body rate below 10 FPS.

Performance recording is **off by default**, including in the portable
evaluator. Ordinary play retains the full native, Rapier, chemistry and
publication protocol. Open **Structures… → Record performance timings
(optional)** to start a fresh bounded recording. Play the comparison, then turn
recording off and select **Save diagnostics**. Stopping preserves the recorded
timings while normal play continues; starting another recording clears the
previous timing samples. The explicit `--objectshard-diagnostics` launch flag
is an alternative to the checkbox.

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
and contribute to mass. This candidate does not add buoyancy, fluid drag or
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
