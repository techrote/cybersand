---
title: PAINT-001 native-backed Workbench painting editor
status: Current
document-kind: contract
scope: Accepted native Workbench painting, bounded execution, shared history and reconstructible authored starts
canonical-for: []
last-reviewed: 2026-11-24
related-documents: [player-control-playground.md, procedural-world-generation.md, ../operations/github-development-and-release.md]
---

# PAINT-001 — bounded painting editor

The ordinary Workbench includes PAINT's bounded native editor and shared
manual/Art Undo/Redo. The accepted integration supersedes the original independent
#544/#560 candidate instructions. For a practical walkthrough, use
[painting and history](../operations/workbench-painting-and-history.md); this page
owns the execution and persistence boundaries.

Original qualification identities, failures and screenshots remain in the
[11 November record](../audits/paint001-2026-11-11/qualification.json) and
[baseline document](https://github.com/techrote/cybersand/blob/00cdb02f103265b6dc5224c68283e9a0c8cb449f/docs/systems/paint-editor-bounded-shapes.md).
Those results are scoped to their tested sources, not fresh execution claims.

## Using the editor

Open the ordinary Workbench and pause. Its existing material picker now contains
the loaded native runtime's supported materials. The additional compact tool row
provides Brush, Eraser, Line, Rectangle, Outline, Select, Fill and Paste, with
Copy, Undo, Redo, Cancel, named Save start and Load start beside it. A gesture
queues and completes one operation; the status distinguishes planning, queued,
native execution, completion, refusal and partial completion.

| Action | Control |
| --- | --- |
| Freehand / erase | B / E; right-drag also erases |
| Straight line / filled rectangle / outline | L / R / O, then drag |
| Select a rectangle | S, then drag |
| Capture exact selected native materials | Ctrl+C |
| Paste the captured stamp | Ctrl+V or V, position preview, click or drag and release |
| Four-connected fill | G, then click; a containing selection defines the capture bounds |
| Brush radius 0–24 | Existing radius field; `[` / `]` |
| Undo / redo | Ctrl+Z / Ctrl+Y or Ctrl+Shift+Z |
| Save named authored start | Ctrl+S or Save start |
| Cancel preview / stop native operation | Escape or Cancel |

Undo/Redo follows the latest edit in the shared manual/agent timeline. The
**Art batches** panel exposes the same Undo and Redo actions. Stop an active
agent run and wait for its native result, deferred human strokes and provider
activity to settle before using either panel's history controls or shortcuts.

Tool keys apply to paused painting and respect focused text fields. Existing
playing/actor controls retain their input paths. Pan and zoom use the existing
host mapping: aspect-fit local coordinates plus the floored camera origin. A
camera-button press cancels an unfinished gesture. Leaving the canvas or Escape
cancels without committing. There is no second viewport or simulation controller.

The overlay shows selection, canonical brush/line/rectangle footprints and
multi-material paste, including Empty. Up to 16,384 preview cells/spans are shown
exactly; larger previews explicitly show bounds. A copied selection can be pasted
repeatedly during the session. There is no disk-backed stamp library yet.

## Ownership and native execution

PAINT owns `workbench_paint_editor_{shapes,controller,overlay,executor,history}.gd`
and its tests. The coordinated shared integration adds a small mount/input seam
to `shared_workbench.gd` and a bounded operation seam to `simulation_worker.gd`.
The existing worker remains the only live native World owner. Planning uses a
separate value-only GDScript thread; that thread never accesses the World.

Human material admission comes from the loaded native bridge's
`inspect_interaction` authority. At this source, 131 valid IDs include Empty 0;
130 nonempty materials are paintable, while reserved slot 10 is invalid. Art's
ordinary source-cell restriction to Empty/Hard Wall is not a restriction on
human painting. The native material catalogue remains authoritative.

`paint_queue` accepts one bounded edit or capture. Admission reports `queued`,
not success. An edit contains unique row-major integer x/y/material triples;
a capture contains a bounded rectangle. There is one pending operation and one
unconsumed result slot, not an unbounded chain of old brush commands. The
legacy `queue_emit_cells` 4,096-cell/eight-command limit remains intact.

Every request carries generation, revision and tick. The worker rechecks those
identities, pause, settings, current scenario tool permission, native bounds,
material authority, protected source rectangles and optional caller source-ID
policy. It preflights the entire operation before writing. Applying and capture
advance in slices of at most 4,096 cells, with a 262,144-cell operation limit.
Existing brush queue admission cannot interleave with these operations.

Native `stored_material_at` supplies stored material identity in the accepted
integration. Every covered rigid-body cell is still explicitly refused before
capture or editing; stored Empty beneath a body grants no editing permission.
The source-matched API is required before any write. This also works beyond the diagnostic
bridge's 1,024-coordinate limit. RG8 colour, Water dithering and ballistic overlays
are never interpreted as stored IDs.

Each written cell is read back. The immutable result reports operation ID,
requested/applied counts, actual applied prefix, prior and resulting material IDs,
source identity and recovery possibility. Stop, source replacement, revision
change or a native mismatch cannot become a false completed acknowledgement.
A cancelled operation with writes reports `partial`; it is not an atomic rollback.
The UI records a representable acknowledged prefix and offers Undo when its source
is still valid. If that prefix exceeds persistence limits, Save and new authoring
remain held until recovery or Restore start. A retained-World actor/settings
change cannot clear that hold. Stopping recovery also keeps Save blocked.

## Geometry, selection and bounded fill

The original Bresenham/disc line, filled/outline rectangle, translation and
four-neighbour fill planners remain canonical. Endpoint normalization preserves
reverse-drag parity; output is unique row-major order. Shapes default to the
original 4,096-cell limit for existing callers. An explicit bounded capacity allows
the editor to plan up to 262,144 cells. A rejected operation returns no partial plan.
Rectangles produce row-major output directly; freehand gestures are bounded by
4,096 pointer samples and 16 million estimated lattice visits.

Copy captures a quiescent native rectangle and records its World generation.
Paste translates its immutable snapshot, preserving every material ID and Empty.
Source/destination overlap is therefore safe. Any off-canvas destination,
unsupported material or protected cell refuses the complete operation during
preflight. World replacement invalidates the clipboard; ordinary edits do not
rewrite a captured stamp.

Fill captures a 256×256 window by default. A containing selection may enlarge the
sample to 262,144 cells. Four-connected membership compares exact material IDs.
A component touching an unknown cropped edge is refused; the real World boundary
is a valid stopping edge. There is no global scan of a 1,024² or 2,048² World.
The maximum explicit sample is bounded even on a 512² World. Cropped fills
now automatically extend their native capture toward an unread connected edge,
repeating within the same 262,144-cell limit and current World revision.
The planner finishes inspecting each existing sample before extending it. It
keeps every reached cell and its known one-cell boundary, freeing disconnected
margins before the next capture so known walls do not waste the growth budget.
No write occurs until the complete component has been planned. Capture, planning
and native application are separate, cancellable stages with identity checks.
Cancellation also retires an already-completed capture's continuation: consuming
its native receipt cannot launch a Fill planner after Cancel. Confirmed native
edit prefixes still enter the ordinary partial-result recording/recovery path.

## Undo and authored-start persistence

Only native-confirmed edits enter the shared chronological history. A manual
gesture remains one record, including its native chunks. Agent receipts retain
the first stored material before a cell changes and its latest stored material
afterward. A direct batch or one model drawing submission can span bounded
history parts of at most 262,144 cells; one Undo or Redo traverses adjacent
retained parts of that submission in order. A human edit between agent chunks
closes the preceding agent group and remains a separate history entry. Undo
therefore reaches the most recent edit first and cannot skip later human work
to reverse an earlier agent drawing.

Up to 32 parts and 1,048,576 retained edit cells are kept. If those limits evict
an older part of an agent drawing, the surviving entry is labelled **Agent
drawing (retained tail)** and the UI reports that the older part is no longer
undoable. A no-change agent receipt preserves existing Undo and Redo. A captured
part that returns every cell to its original material contributes no history
record and removes its redundant authored stamps.

Undo/Redo preflights expected stored source IDs and uses PAINT's existing native
mutation and acknowledgement path. Both interfaces share the generation,
revision and tick fence. Confirmed agent edits recorded through this seam
advance the fence instead of invalidating manual history. An outside edit not
recorded in this timeline, a simulation tick or World replacement still
invalidates unsafe history. Undo is paused construction editing; it does not
restore temperature, velocity or evolved physics state. Its trusted human
inverse does not expand the agent's ordinary material, source or scope policy.

When the Art panel exists, history completion appends a new human canvas
result to its current-session conversation and a `native_history_action` event.
Without an Art panel, native Undo/Redo does not require one or restore an old
conversation. It preserves historical model
receipts and does not automatically issue another model request. The existing
context-mode rules still govern later requests. Undo/Redo stacks remain
session-local; saving persists the resulting authored start, not those stacks.

Before native writes, `workbench_paint_editor_history.gd` checks that the complete
operation can be reconstructed through existing Setup-v2 or GEN-007 start formats.
It coalesces exact material row runs into boxes, preserving Empty. The Workbench-only constructor now admits **32,768** authored rectangles/
stamps (previously 4,096), subject to the unchanged **1 MiB** save envelope
and native construction-area checks. Generated-map replay also has a
conservative maximum of 64 world areas, capped at 32 million touched cells,
validated before save and in the native prepared constructor. Other MicroScenario recipes retain
their 4,096-record limit. A runtime predating that native capacity needs a rebuild before it can supply
that capacity; the accepted matching runtime already includes it. The editor queries a native capability handshake
and retains the old 4,096-rectangle refusal if the user has not rebuilt the
GDExtension, rather than recording a start that cannot be reopened.
Simple large rectangles fit efficiently. Highly fragmented pastes may explicitly
refuse before any write. Ordinary blank starts may compact equivalent construction;
generated starts retain their ordered overlays and original generator provenance.
The narrow Setup material check uses compiled native authority for edit stamps,
without broadening source-emitter policy or changing the format version.

Agent drawing retains its existing streaming admission: it can produce a recipe
too fragmented for the 32,768-stamp or 1 MiB persistence envelope. Save then
refuses explicitly. Each part of Undo/Redo also preflights its target authored
recipe, so a grouped history action can refuse an intermediate recipe before
that part writes, even if the eventual group baseline would be compact. The UI
reports confirmed progress or refusal; arbitrary agent output is not promised
an unlimited or atomic rollback. No persistence limit is relaxed for history.

Save refuses while any shared mutation slot or unconsumed receipt remains,
including agent drawing, ordinary brush commands and World transitions. Retry
after they settle to record the start recipe. It does not snapshot an evolved
simulation. Actors, selected instance, solver settings and generated-map
identity retain the existing #542 contracts. Accepted GEN-008 supplies
[material-only Flatten](../architecture/shared-workbench-authoring-data.md#flatten-and-storage-compatibility).
PAINT overlays and their Undo/Redo preserve Empty over that baseline. Successful
Flatten retires previous history and advances an authoring-generation fence even
when the paused native generation/revision/tick stay unchanged. It does not Save.

## Reproduce and finish owner acceptance

Use the exact pinned Godot and source-matched native assets in an isolated test
profile. Set `GODOT` to the verified executable; do not rely on a different
`godot` found earlier on PATH.

```sh
python3 tools/ci/check_repository.py --require-materialized
"$GODOT" --headless --path godot --editor --import --quit
"$GODOT" --headless --path godot --script res://tests/test_paint_editor_shapes.gd
"$GODOT" --path godot -- --workbench
```

Further focused scripts include `test_paint_editor_native`,
`test_paint_editor_executor`, `test_paint_editor_recovery`,
`test_paint_editor_history`, `test_paint_editor_workbench` and
`test_paint_editor_generated_workbench`. For history's second process set
`CYBERSAND_PAINT_HISTORY_REOPEN=1`; ordinary Workbench uses `PAINT_REOPEN=1`,
and generated Workbench uses `PAINT_GENERATED_REOPEN=1`. Keep the same isolated
user-data location for each author/reopen pair. `PAINT_CAPTURE_DIR` requests
actual framebuffer evidence in a graphical run. See
[testing guidance](../operations/testing-validation-and-replay.md) for test
selection and evidence scope.

A manual evaluation should draw each shape, change material, copy a mixture of
Water/solid/Empty, overlap-paste it, Undo/Redo, fill a closed pocket and
save/exit/reopen an authored start. Exercise pan/zoom and Stop. Report physical
GUI behavior separately from native/headless test results. A reusable disk stamp
library and arbitrary evolved-state Undo are not provided by this contract.

<a id="exact-source-native-and-desktop-qualification--11-november-2026"></a>
<a id="previous-retained-runtime-qualification-baseline--11-november-2026"></a>

## Preserved failure history and integration boundary

The original source-matched Linux/Windows runs, hashes, frame captures, performance
observations, failed workflow-marker check and earlier retained-runtime baseline
remain in the [immutable baseline qualification sections](https://github.com/techrote/cybersand/blob/00cdb02f103265b6dc5224c68283e9a0c8cb449f/docs/systems/paint-editor-bounded-shapes.md#exact-source-native-and-desktop-qualification--11-november-2026).
The [integrated runbook](../operations/wb-art-paint-integrated-candidate.md)
explains the current authoring flow and directs historical readers to the
combined evidence. Earlier cross-branch conflicts and pending merge instructions
are not present-tense policy. Draft-skipped CI remains distinct from PASS, and
new implementation still needs the applicable source-bound gates.
