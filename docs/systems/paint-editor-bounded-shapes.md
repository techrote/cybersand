---
title: PAINT-001 native-backed Workbench painting editor
status: Current
document-kind: design
scope: Mounted Draft PAINT-001 candidate on the shared Workbench; bounded native painting and reconstructible authored starts, not evolved simulation checkpoints
canonical-for: []
last-reviewed: 2026-11-11
related-documents: [player-control-playground.md, procedural-world-generation.md, ../operations/github-development-and-release.md]
---

# PAINT-001 — bounded painting editor

[Issue #543](https://github.com/techrote/cybersand/issues/543) is implemented in the
existing **Draft [PR #544](https://github.com/techrote/cybersand/pull/544)**. This is a
mounted, executable candidate, not accepted main. It retains the original
canonical geometry implementation and reconciles it with accepted main
`d4b18e7f06839b35c8f6a66195206da0f33c5fa3`, including merged GEN-007 / #542.

The [qualification record](../audits/paint001-2026-11-11/qualification.json) includes
source hashes, original failures and actual logs. These are native framebuffer
captures of the [mounted editor](../audits/paint001-2026-11-11/screenshots/paint001-mounted-editor.png),
[mixed-material preview](../audits/paint001-2026-11-11/screenshots/paint001-mixed-stamp-preview.png)
and [generated start after reopening](../audits/paint001-2026-11-11/screenshots/paint001-generated-reopened.png).

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

The lifecycle and consumed-receipt pattern were reviewed against agent-art #560
at `293dde66efbf5451dacb117080713cca2ac97449`. No provider/controller architecture,
agent branch or agent-only Empty/Hard Wall policy is imported. Human material
admission comes from the loaded native bridge's `inspect_interaction` authority.
At this source identity it admits 131 IDs: 0–131 excluding reserved slot 10.
MAT-AUTH definitions, material IDs, native physics and Rapier behaviour are unchanged.
The later #560 head `36d7686dff5beef35e04d009677665618f6ef920` was also inspected;
its worker seam is unchanged from that reviewed source.

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

Native `material_at` supplies material identity. Because it reports body masks as
Wall, every covered rigid-body cell is refused before capture or editing; admitted
reads therefore equal stored material IDs. This also works beyond the diagnostic
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
No write occurs until the complete component has been planned. Capture, planning
and native application are separate, cancellable stages with identity checks.

## Undo and authored-start persistence

Only acknowledged edits enter history. One gesture is one history record,
including all native chunks. Up to 32 records and 1,048,576 retained edit cells
are kept, with exact native before/after IDs. Undo/redo preflights expected source
IDs and uses the same native execution path. A simulation tick, another editor's
revision or World replacement invalidates history. This is paused construction
undo, not physics rewind or restoration of temperature/velocity state.

Before native writes, `workbench_paint_editor_history.gd` checks that the complete
operation can be reconstructed through existing Setup-v2 or GEN-007 start formats.
It coalesces exact material row runs into boxes, preserving Empty. The Workbench-only constructor now admits **32,768** authored rectangles/
stamps (previously 4,096), subject to the unchanged **1 MiB** save envelope
and native construction-area checks. Other MicroScenario recipes retain
their 4,096-record limit. This source change requires a rebuilt GDExtension
before Windows qualification.
Simple large rectangles fit efficiently. Highly fragmented pastes may explicitly
refuse before any write. Ordinary blank starts may compact equivalent construction;
generated starts retain their ordered overlays and original generator provenance.
The narrow Setup material check uses compiled native authority for edit stamps,
without broadening source-emitter policy or changing the format version.

Save waits for native completion and records the start recipe. It does not snapshot
an evolved simulation. Actors, selected instance, solver settings and generated-map
identity retain the existing #542 contracts. Flatten / #548 remains separate.

## Executed qualification

All runtime results below use official Godot **4.7.stable.official.5b4e0cb0f** and
source-matched retained native libraries. The Linux CyberSand library SHA-256 is
`46a9c61d3540cfecbe38f9301bd08a7b69efa4865115a7ecb5bea029a5452361`;
all 87 fingerprinted native source inputs match its manifest. Rapier is 0.35.2.
No new C++ build or Windows execution is claimed.

| Regression | Actual result |
| --- | --- |
| Original canonical shape/native test after main reconciliation | 119 checks, zero failures |
| Expanded geometry, caps and existing native worker path | 157 checks, zero failures |
| Native execution, material capture, ordering, refusals, cancellation, source fences | 109 checks each with 1 and 4 native workers, zero failures |
| Direct executor protections | 21 checks, zero failures |
| Interrupted native recovery | 5 checks, zero failures |
| Ordinary mounted Workbench, actual OpenGL | 59 checks; separate fresh process 12 checks, zero failures |
| Authored-history encoding and native reconstruction | 981 checks; fresh process 961 checks, zero failures |
| Generated Workbench authoring | Headless 39; actual OpenGL 40 checks, zero failures |
| Generated Workbench fresh-process reopen | Headless 19; actual OpenGL 20 checks, zero failures |

The mounted ordinary-Workbench script additionally exercises all tools, overlapping
native multi-material paste, Undo/Redo, fill refusal, pan/zoom, Escape, a 4,416-cell
Water rectangle, larger reusable stamp, simulation invalidation and fresh-process
reopen. The final qualification record and logs accompany the PR; counts there
include the final retained-World recovery regression.

Generated qualification creates a real 512² source through 64 native generation
receipts, retains a real Midge and solver choices, records 20 edit stamps, exits,
then loads in a separate process. The complete reconstructed stored-material digest
is `1242e14d217c86835673aa13e9158fcb4605faef1c6fcb1e53b7be28268d868b`,
matching the independently captured authored start. The original source digest
`0acd772d421b04131dac13917883ca15e6a1fdce55cb028b93b5fbf49b7f17b4`
is preserved. Continued editing after reopening is checked.

Representative native apply time for 65,536 cells was 0.52–0.53 s on 512², 1,024²
and 2,048² Worlds; 262,144 cells took 2.13 s. Maximum measured worker slice was
18.3 ms with one worker and 13.3 ms with four. Eight authoritative material captures
matched between worker counts (combined witness
`5a11f2271d53ed3634936619fa67d019d2413905708f0b28ccb61b7596ad8154`).
These are paused-edit material comparisons, not full-physics determinism claims.
A maximum rectangle plans in approximately 11–15 ms; the maximum bounded fill
measured approximately 815 ms, which is why planning runs off the UI thread.
Linux graphical evidence uses Mesa llvmpipe OpenGL 4.5; it is not Windows/GPU
performance qualification or a manual usability sign-off.

## Reproduce and finish owner acceptance

Use the pinned Godot and source-matched native assets, then import the project:

```sh
git lfs pull
godot --headless --path godot --editor --quit
godot --path godot -- --workbench
```

Focused scripts run with `godot --headless --path godot --script res://tests/NAME.gd`:
`test_paint_editor_shapes`, `test_paint_editor_native`, `test_paint_editor_executor`,
`test_paint_editor_recovery`, `test_paint_editor_history`,
`test_paint_editor_workbench` and `test_paint_editor_generated_workbench`.
For history's second process set `CYBERSAND_PAINT_HISTORY_REOPEN=1`; for ordinary
Workbench use `PAINT_REOPEN=1`; for generated Workbench use
`PAINT_GENERATED_REOPEN=1`. Keep the same user-data location for each pair.
`PAINT_CAPTURE_DIR` enables actual framebuffer evidence in a graphical run.

Owner acceptance should draw a line and both rectangle types, change materials,
copy a Water/solid/Empty structure, overlap-paste it, Undo/Redo, fill a closed pocket,
then save/exit/reopen both blank and generated starts. Exercise pan/zoom and Stop.
Run this on Windows with the pinned 4.7 runtime before promoting the Draft.
Further priorities are Windows graphical feel/latency, coordination of the generic
worker seam with agent-art #560, and larger fragmented-stamp persistence plus a
reusable on-disk stamp library. None requires adopting Flatten semantics.

## Preserved failure history and integration boundary

The original 8 November documentation run
[42482388310](https://github.com/techrote/cybersand/actions/runs/42482388310)
failed because this focused document lacked corpus registration. The 11 November
candidate changes its unsupported `document-kind: system` to `design` and consumes
the existing #550 registration delta unchanged from
`9e4a25596e4c810d037ffb5f54f9bd98c108e7eb`. It does not independently redesign the
Integration-owned retrieval manifest.

The original static Python reverse-drag mirror was useful but not execution proof.
The original GDScript regression now genuinely passes. Initial development logs
are retained for the accidentally selected Godot 4.6 runtime, missing toolbar
parenting, stale test helper names, capture conversion and JSON integer/float test
comparisons. They are superseded only by identified corrected runs. Draft-skipped
hosted native jobs are not passes. Windows, owner-human acceptance and merge
remain outstanding; this document does not authorize promotion or merging.
