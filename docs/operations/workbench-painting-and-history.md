---
title: Workbench painting, selection and history
status: Current
document-kind: guide
scope: Current human painting controls, bounded copy and fill, native completion, cancellation and shared Undo/Redo
canonical-for: [workbench-painting-user-guide]
last-reviewed: 2026-11-24
related-documents: [workbench-first-session.md, workbench-saving.md, workbench-art.md, ../systems/paint-editor-bounded-shapes.md]
---

# Painting and history

Choose **Paint** in the main Workbench tool selector. The painting row uses the
loaded native runtime's supported material palette. Brush and Eraser can work
while simulation runs; pause for shapes, selection, Fill, Copy/Paste and
Undo/Redo.

## Controls

| Tool or action | Control and behavior |
| --- | --- |
| Brush / Eraser | Select the tool; paused shortcuts **B / E**. Right-drag also erases. |
| Line | **L**, then drag endpoints. |
| Filled rectangle / outline | **R / O**, then drag corners. |
| Select | **S**, then drag a rectangle. Selection itself does not change materials. |
| Copy | **Copy** or **Ctrl+C** captures the selected native stored materials. |
| Paste | **Paste**, **V** or **Ctrl+V**; place the preview and release. Empty cells are included. |
| Fill | **G**, then click a connected region of the same stored material. |
| Radius | Numeric field, or **[ / ]** while paused; 0 paints one cell. |
| Undo / Redo | Buttons, **Ctrl+Z / Ctrl+Y**, or **Ctrl+Shift+Z** for Redo. |
| Cancel | Button or **Escape** cancels a preview or requests a bounded stop. |

Tool shortcuts respect text-field focus and the paused painting context. **R**
can mean Rectangle here and actor reset in a different context. Use the named
button when uncertain. Wheel zoom and middle-drag pan use the existing canvas;
camera changes cancel an unfinished gesture.

## A reusable multi-material stamp

1. Pause and paint a small structure with two materials and a clear opening.
2. Select a rectangle around it and **Copy**. Wait for native capture.
3. Choose **Paste** and move the preview to a clear position entirely within
   the canvas. Release to apply and wait for completion.
4. Repeat at another position. Undo reverses the latest acknowledged paste.

The captured stamp includes Empty, so pasting can erase destination cells.
Source and destination may overlap because Copy owns an immutable material
snapshot. World replacement invalidates the clipboard; ordinary edits do not
rewrite it. A protected or off-canvas destination can refuse the operation.
There is no disk-backed stamp library in this editor.

## Fill and capacity

Fill follows four-connected cells with the same native stored material ID.
It begins with a bounded capture and can extend that capture toward unread
connected edges. A selection can provide explicit bounds. The operation must
prove the component within its capacity before writing; a cropped unknown edge
or an oversized region can refuse. A real World boundary is a valid edge.

The editor admits at most **262,144 cells per precise operation**. Its native
work advances in bounded slices. This does not mean a whole 2048-square canvas
can be filled in one operation. Use smaller selections or simpler construction
when a refusal reports capacity. Fragmented edits also face the authored-save
record and byte limits described in [saving](workbench-saving.md).

Large previews can show bounds instead of every cell. A visual outline is not
proof that native writes have occurred. Read the status: planning, queued,
executing, completed, refused and partial are different outcomes.

## Cancel, partial results and protection

Cancel before native writing can leave the canvas untouched. Once a native
slice has written cells, Stop/Cancel may retain a confirmed prefix and report
**partial**. It is not automatic rollback. When possible, the editor records
that prefix for Undo. If it cannot safely reconstruct the result, saving and
new authoring remain blocked until the indicated recovery or Restore start.

The editor refuses covered physical-body cells and protected source regions.
Seeing an Empty colour under a body does not grant permission to edit it.
The [Art work area and protection controls](workbench-art.md) add their own
constraints to model/direct drawing; they do not expand human or native access.

## One chronological Undo/Redo timeline

Manual and Art edits use the same native-confirmed history. If a human stroke
lands between parts of an agent drawing, Undo reaches the latest human edit
first. It cannot skip that edit to undo an older drawing. Stop active Art work
and wait for native results and deferred human strokes before changing history.

History retains up to **32 parts and 1,048,576 edit cells**. A long agent drawing
can span parts; a retained tail is labelled when older parts are evicted. An
outside mutation, simulation tick or World replacement can invalidate history.
Undo restores construction materials, not temperature, quantity, velocity or
actor motion. Saved starts contain the resulting authored scene, not the stacks.

## Source and verification scope

The [PAINT contract](../systems/paint-editor-bounded-shapes.md) owns implementation
details. Controls and capacities come from
[`workbench_paint_editor_controller.gd`](../../godot/scripts/workbench_paint_editor_controller.gd),
with native receipt and history handling in
[`workbench_paint_editor_executor.gd`](../../godot/scripts/workbench_paint_editor_executor.gd)
and [`workbench_paint_editor_history.gd`](../../godot/scripts/workbench_paint_editor_history.gd).
