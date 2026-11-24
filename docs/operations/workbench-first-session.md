---
title: Your first Shared Workbench session
status: Current
document-kind: guide
scope: A small paused material authoring tutorial with simulation, saving and fresh-session reconstruction
canonical-for: [workbench-first-session]
last-reviewed: 2026-11-24
related-documents: [getting-started.md, workbench-painting-and-history.md, workbench-saving.md, architectural-generator-playtest.md, workbench-water-lab.md]
---

# Your first Workbench session

This exercise builds a small container, fills it with material, runs the
simulation and reopens the authored layout. No model provider or external map is
needed. Start through [Getting started](getting-started.md), then choose
**Development workbench**.

## Make room to work

1. Choose **Pilot → Observer / no human pilot** so actor movement does not
   distract from editing.
2. Pause with **Play / Pause [P]**. Use the visible button if a text field has
   focus. Precise shapes, Fill and Undo/Redo require a paused scene.
3. Select **Overview** to locate your work, then zoom in with the mouse wheel.
   Middle-drag pans. Use an empty part of the canvas away from bodies and sources.
4. In the main tool selector choose **Paint**. The smaller painting row provides
   Brush, Eraser, Line, Rectangle, Outline, Select, Fill and Paste.

The initial canvas is finite. The coordinate controls and status help you stay
inside it. There is no need to populate the whole canvas for this exercise.

## Build a container

1. Choose **Hard Wall** in the material picker. Set a modest radius such as 2.
2. Choose **Line** and drag a horizontal floor. Draw one short wall upward at
   each end, leaving the top open. Wait for the native completion status after
   each gesture.
3. Choose **Sand**, switch to **Brush**, and draw a small patch above the floor.
4. Press **Undo**, then **Redo** while still paused. The last acknowledged edit
   should disappear and return.
5. Enter a unique name such as `first-container` beside **Save start [Ctrl+S]**,
   then save. A success message matters; queued or refused work is not a save.

This saves your construction. It is a useful checkpoint before running physics.

## Set the materials in motion

Press **Play / Pause [P]**. Sand should fall into the container. Pause again
after observing it. A simulation tick invalidates construction Undo/Redo when
the old native state is no longer safe to restore; Undo is not physics rewind.

For a Water variation, restore the authored start, pause, select **Water** and
paint a small patch. Fresh Workbench sessions select the Wave gameplay profile.
Open **Water Lab… → Solvers & scenes** to inspect the requested and applied law.
Changing a control stages a request; **Apply solver / tuning** and its native
readback establish what actually runs. The [Water Lab guide](workbench-water-lab.md)
explains fair comparisons and law-specific limits.

## Save what you mean

Choose the appropriate action:

| You want to retain… | Action |
| --- | --- |
| The authored container and original material placement | **Save start**; later simulation is not folded into ordinary Save. |
| The material arrangement you can see after simulation | **Flatten / Bake History…**, confirm the history discard, then **Save start**. |
| Exact velocities, temperatures, tick and actor motion | Ordinary authored saving does not provide this. |

Flatten preserves the live World while replacing the authored material baseline.
It clears earlier construction and Undo/Redo history, and **does not save by
itself**. See [Saving authored worlds](workbench-saving.md) before using it on
valuable work.

## Close and reopen

1. Wait for all drawing and saving to finish.
2. Use **Menu [F2]** or close Godot. Returning to the launcher closes the session.
3. Open Development workbench again, enter `first-container` and click
   **Load start**.
4. Wait for reconstruction. Check the material layout and authored actors, then
   paint a small new mark to confirm the scene is editable.

Undo/Redo stacks and the Art conversation are session-local. They are not
restored by loading the authored start. A flattened save rebuilds initial
material state from stored IDs; it does not resume the previous tick.

## Try architecture next

Save your work, choose **New from generator… → Architectural Generator…**, choose
a style and generate a preview. Inspect it before **Install into workbench**,
which replaces the installed map. Follow the
[Architectural Generator walkthrough](architectural-generator-playtest.md) for
Genteks, presets, apertures and project files.

## Source and verification scope

Controls and transitions are implemented by
[`shared_workbench.gd`](../../godot/scripts/shared_workbench.gd) and
[`workbench_paint_editor_controller.gd`](../../godot/scripts/workbench_paint_editor_controller.gd).
This tutorial is checked against accepted source. It intentionally uses a small
construction; it is not a performance or physical acceptance benchmark.
