---
title: Direct art batches, WB-ART-002 Stage 1
status: Current
document-kind: contract
scope: Unmerged desktop direct drawing candidate, stored-native completion, Stop, shared PAINT ordering and Undo/Redo, authored-start persistence
canonical-for: [workbench-direct-art-batches]
last-reviewed: 2026-11-12
related-documents: [../architecture/shared-workbench-authoring-data.md, ../reference/status-and-roadmap.md, ../operations/cybersand-codex-development-handover.md]
---

# Direct art batches — WB-ART-002 Stage 1

## Candidate and purpose

**Current candidate, unmerged:** issue #559 Stage 1 on
`codex/agent-art-workbench-v2`, based on main
`d4b18e7f06839b35c8f6a66195206da0f33c5fa3` (includes #542).
#531 is read-only reference; none of its controller/configuration modules is
imported. Physics/material defaults are unchanged. This is a
small direct-drawing interface in the ordinary desktop Shared Workbench, not
another World. The [provider candidate](workbench-art-providers.md) implements
context, conversation, scanlines and multiple turns. The
[integrated Draft candidate](../operations/wb-art-paint-integrated-candidate.md)
preserves these features beside the complete PAINT editor, with a source-built
native readback binding and shared mutation/receipt ordering.
Its current shared Undo/Redo implementation is newer than the qualified
`d33c10e4` package. Earlier direct-drawing and integration passes do not qualify
this new history behavior.

### Repair checkpoint — 2026-11-11

The owner-directed repair branch `codex/wb-art-repair-20261111` preserves #560
head `e5bf2916` and its implemented context, scanline, multiple-turn, provider and
diagnostic features. The repair adds one native read-only binding,
`stored_material_at`, backed by `World::stored_material`; physics, `World::get`,
material IDs and defaults remain unchanged. It requires a rebuilt source-matched
GDExtension and refuses before writing if that API is missing.

The exclusive worker explicitly excludes transient body masks before both paint
and erase, checks source eligibility against stored IDs, and confirms the actual
stored ID after each write. Receipts distinguish requested, checked, changed,
unchanged, excluded, refused and confirmed counts, plus before/after rows and
generation/revision/tick. Failed writes retain the actual prefix and any unexpected
actual material change; no requested-material success is inferred from an overlay.

Diagnosis correction: native masked `Wall` is ID 1, whereas UI Hard Wall is 58.
At the inspected #560 head the existing `[0,58]` source restriction already
excluded a masked cell indirectly. The review's exact false-success example is
not claimed reproduced. The repaired API and explicit mask test remove that
semantic dependency while preserving the human-selected destination palette.

Deferred human strokes are removed only after the replay call returns. A failed
admission or World replacement produces explicit refusal feedback and a durable
traffic event, with pending/admitted/refused human counts. `admitted` means queued,
not native-applied; the original legacy brush admission remains distinct from the
later PAINT integration's confirmed completion path. The original brush radius
and ordering are preserved.

In the integrated branch, accepted deferred gestures use PAINT's existing
planner, native executor and history recorder. The callback runs after recording;
success, partial writes, planner cancellation, stale source, refusal and World
replacement each complete the token explicitly. The next agent chunk waits for
that result. The current integrated history seam records native-confirmed agent
changes in the same chronological timeline as manual gestures; it advances the
shared source fence instead of discarding valid manual history. A PAINT recovery
hold still blocks agent drawing.

Focused repair tests: `test_art_stored_material.gd` covers actual native workers
1/4 and body masks over stored Empty/Wall/Hard Wall, with separately labelled
synthetic rejection fixtures; `test_art_deferred_manual.gd` reproduces refused
replay and replacement; the original mounted art/provider suites remain required.

Open **Shared Workbench → Art batches**. The floating, hideable test input
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

Confirmed history results append a human canvas-result turn and durable
`history_result` event, with applied counts and continuation/refusal status.
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

The final integrated candidate fences Save on the common native mutation slot,
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
The integrated candidate retains PAINT's current `MAX_STAMPS`/`MAX_RUNS`
capacity corrections. An excessively fragmented authored start can
therefore draw successfully but fail Save with the existing explicit format
error. No silent truncation, second save schema or material Flatten is introduced;
#548 separately owns that successor. Save reconstructs authored start, not evolved
physics state. The integrated manual editor uses PAINT's native-confirmed
recording and recovery rules.

## Qualification and launch

Run from the candidate checkout with its pinned Godot 4.7/native runtimes:

```powershell
C:/Godot47/Godot_v4.7-stable_win64_console.exe --headless --path godot --script res://tests/test_art_batch_native.gd
C:/Godot47/Godot_v4.7-stable_win64_console.exe --headless --path godot --script res://tests/test_workbench_input.gd
C:/Godot47/Godot_v4.7-stable_win64_console.exe --path godot -- --workbench
```

Linux graphical case: `xvfb-run -a GODOT --path godot --audio-driver Dummy
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
No merge or Ready promotion is authorized.
