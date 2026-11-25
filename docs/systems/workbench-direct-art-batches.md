---
title: Direct Art batches and native completion
status: Current
document-kind: contract
scope: Accepted desktop drawing, native completion, Stop, shared PAINT ordering, Undo/Redo and authored persistence
canonical-for: [workbench-direct-art-batches]
last-reviewed: 2026-11-24
related-documents: [../architecture/shared-workbench-authoring-data.md, ../reference/status-and-roadmap.md, ../operations/cybersand-codex-development-handover.md]
---

# Direct art batches — WB-ART-002 Stage 1

## Candidate and purpose

This is the accepted direct-drawing path in the ordinary Shared Workbench.
It shares the same World, native mutation boundary and chronological history as
human PAINT. The [provider contract](workbench-art-providers.md) adds model
requests, context, Scanline and session traffic; it grants no wider material
permissions. The [practical guide](../operations/workbench-art.md) introduces
model-free drawing and configured providers.

### Repair checkpoint — 2026-11-11

The original repair established native `stored_material_at` readback and explicit
body-mask exclusion. Native masked Wall is ID 1; UI Hard Wall is 58. Current
receipts use stored IDs rather than rendered masks, colours or requested values.
The original false-success diagnosis was not claimed reproduced at every old
head; its negative evidence is preserved in the
[baseline repair record](https://github.com/techrote/cybersand/blob/00cdb02f103265b6dc5224c68283e9a0c8cb449f/docs/systems/workbench-direct-art-batches.md#repair-checkpoint--2026-11-11).
An API missing from a stale library still refuses before writing. The accepted
matching library already contains it; no old candidate branch is required.

Open **Development workbench** from the launcher, then **Art batches**. The floating, hideable test input
preserves the canvas layout. Draw/Stop sit beside its title, with shared Undo and
Redo controls labelled **Shared edit history · manual and agent edits**. Enter ordered JSON,
select an XYWH work area, optional protected rectangle and enabled materials.
Hard Wall is material 58; erase is 0. No credential, source/Git check, pricing,
mandatory preview or prepare/apply exchange is required to draw.

```json
[
  {"shape":"rectangle","x0":32,"y0":32,"x1":95,"y1":159,"material":58},
  {"shape":"disc","x":64,"y":70,"radius":12,"material":0},
  {"shape":"line","x0":32,"y0":180,"x1":95,"y1":200,"material":58},
  {"shape":"pixels","points":[[40,190],[42,191]],"material":58}
]
```

Rectangle endpoints are inclusive; discs contain exactly the integer points
within squared radius; lines use integer Bresenham endpoints inclusive. Pixels
are explicit integer world coordinates. Shapes must fit the installed finite
canvas; selected work-area and protection intersections are skipped at execution.
Input errors leave the interface available for correction.

## Ownership, capacities and completion

`art_batch_plan.gd` validates geometry and lazily emits points. Rectangle/disc
raster buffers do not grow with the entire drawing. `art_batch_executor.gd`
streams one outstanding chunk to the existing `simulation_worker.gd` owner.
The existing `MAX_BRUSH_FOOTPRINT_CELLS` (4096) is an internal chunk size,
**not** a batch or lifetime edit ceiling. Explicit pixels are not limited to 32.
Input/recipe storage still consumes ordinary process memory; this is not a claim
of unbounded capacity. No new native storage, native locks or physics is added.

The worker applies points with the ordinary native `emit_disc(..., radius=0)`
primitive, alongside ordinary brush execution. On the exclusive World thread it
checks installed canvas, selected area, protected rectangles and source material:
only existing Empty/Hard Wall cells can be overwritten. It reads native material
before and after each eligible point and reports actual checked/changed/excluded
counts plus per-point readback, World generation and tick. Enabled materials are
also checked at queue admission. No main-thread direct World access is added.

Queue acceptance is `queued`, never applied. `executing` means the worker has
claimed a chunk. Completion follows actual receipts for every chunk; failures or
Stop preserve/report a partial prefix. Unchanged points count as checked, not
changed. Excluded cells are distinct from failed writes. Readback is bounded to
one chunk and consumed, not accumulated as an exhaustible receipt store.

## Shared Undo and Redo

The Art batches Undo/Redo buttons and PAINT's buttons and shortcuts operate on
one chronological history. Only confirmed stored-material changes enter it.
Adjacent bounded parts of one direct batch or model drawing submission share
an action: one Undo reverses the retained parts, and Redo reapplies them in
order. A human edit between chunks closes that group and has its own entry.
Undo never jumps over later manual work to target an earlier agent action.

Use Stop and wait for batch execution, native receipts, deferred human edits,
image capture, provider activity and any scheduled follow-up turn to settle.
An idle native chunk boundary alone does not enable Undo. After retirement,
Undo can reverse the confirmed applied prefix of a stopped drawing; cancelled
or unacknowledged suffixes never enter history. The operation uses PAINT's
bounded native preflight and receipt path. Its trusted human inverse can
restore the recorded materials without granting ordinary agent submissions
broader material, source, protected-region or work-area permissions.

History retains at most 32 parts and 1,048,576 edit cells, with at most 262,144
cells per part. The UI labels a partially retained group **Agent drawing
(retained tail)** and explains when its older part is no longer undoable.
No-change agent receipts preserve the existing Redo branch. Simulation, World
replacement or another mutation outside the recorded timeline still invalidate
history through its generation/revision/tick fence. History is session-local.

When the Art panel exists, confirmed history results append a human
canvas-result turn and `native_history_action` event to its current session,
with applied counts and continuation/refusal status. Native history does not
require cross-session Art replay or a durable receipt journal.
They do not rewrite earlier model receipts or automatically request another
model turn. The chosen conversation/context mode still governs future requests.

The existing persistence limits also apply to history replay. Agent streaming
does not preflight the entire authored recipe, so a highly fragmented result
can exceed 32,768 stamps or the 1 MiB save envelope. Save then refuses, and
Undo/Redo can also refuse a target part before writing if its intermediate
authored recipe exceeds those limits, even when the eventual group baseline
would be compact. The UI reports the actual confirmed progress and refusal;
there is no promise of unbounded or atomic rollback for arbitrary agent output.

## Stop, replacement and ordinary painting

Stop increments the worker epoch and cancels a not-started chunk. An executing
chunk can finish; the executor consumes its receipt and reports its actual prefix
before becoming inactive. Old-epoch submissions are refused. No uncertain replay
or rollback is attempted. A new batch is accepted only after retirement.

New/Load/Restore discard stale callbacks from the old authored recipe and use the
existing native replacement transaction. A retained settings/actor transition
while drawing requests Stop and asks for retry after the current acknowledgment;
this prevents transferring live cells without their recorded authored prefix.
Geometry/settings rejection before replacement admission does not interrupt a
batch. A later native-preparation rejection retains the old World and its
confirmed authored prefix after the request-time Stop.
Human strokes during a chunk are delivered before the next chunk and recorded in
that same order with their original brush radius. Their pending queue reuses the
existing worker command capacity; a full queue explicitly refuses further strokes
until the chunk finishes. Ordinary camera/zoom, physics and paint controls remain owned by
the existing workbench.

## Save semantics and existing format boundary

The accepted integration fences Save on the common native mutation slot,
including ordinary brush queues and unconsumed receipts. It refuses without
altering an existing named file or consuming an unowned agent result. A requested
replacement stops old work but keeps its authored recording reference until the
new World is actually installed; rejected native preparation must preserve the
old confirmed prefix in both the live World and its saved start. The
[integrated runbook](../operations/wb-art-paint-integrated-candidate.md#final-hardening-and-evaluation--2026-11-12)
records the demonstrated failure and resulting-source qualification.

Only native-confirmed changed cells enter `Setup.edits`, coalesced into ordered
horizontal/vertical rectangles. Save while art remains queued/executing asks the
user to Stop or wait; it cannot serialize unseen pending work as applied. After
Stop, Save/reopen includes the confirmed prefix and excludes the cancelled tail.
The shared Setup-v2/generated-start format and byte limit remain unchanged.
The integration retains PAINT's current `MAX_STAMPS`/`MAX_RUNS`
capacity corrections. An excessively fragmented authored start can
therefore draw successfully but fail Save with the existing explicit format
error. There is no silent truncation. Accepted GEN-008 provides a separate explicit
[material Flatten operation](../operations/workbench-saving.md#capture-a-changed-material-layout-with-flatten);
Art does not invoke it automatically. Save reconstructs authored start, not
evolved physics state. The integrated manual editor uses PAINT's native-confirmed
recording and recovery rules.

## Qualification and launch

Run from the checked source with its exact pinned Godot/native runtimes.
These are reproduction commands, not claims of new execution:

```powershell
& "C:/Godot47/Godot_v4.7-stable_win64_console.exe" --headless --path godot --script res://tests/test_art_batch_native.gd
& "C:/Godot47/Godot_v4.7-stable_win64_console.exe" --headless --path godot --script res://tests/test_workbench_input.gd
& "C:/Godot47/Godot_v4.7-stable_win64_console.exe" --path godot -- --workbench
```

Linux graphical case: `xvfb-run -a "$GODOT" --path godot --audio-driver Dummy
--rendering-method gl_compatibility --script
res://tests/test_art_batch_native_render.gd`. Set `WB_ART_EVIDENCE_DIR` to an
existing/creatable directory to retain the original post-draw PNG. CI's normal
`CYBERSAND_TEST_ARTIFACT_DIR` is also supported. The `_render` suffix routes the
wrapper through the repository's existing graphical runner; both tests are
automatically discovered. Draft-skipped production CI is not a pass.

Dated execution details and runtime hashes are recorded in the Stage-1 PR/issue
handoff. Windows headless/native checks and Linux rendered checks are distinct
from human Windows graphical acceptance and from later genuine model inference.
The test explicitly uses two native workers, without changing production defaults.
The shared apply seam publishes current frame settings before preparation captures
its revision, fixing first-render construction retirement reproduced in Xvfb.
Use the current release policy for a new candidate; this historical procedure
does not require returning accepted implementation to Draft or reopening old PRs.
