---
title: Direct art batches, WB-ART-002 Stage 1
status: Current
document-kind: contract
scope: Unmerged desktop direct drawing candidate, native completion, Stop and authored-start persistence; provider collaboration is a separate unmerged candidate
canonical-for: [workbench-direct-art-batches]
last-reviewed: 2026-11-10
related-documents: [../architecture/shared-workbench-authoring-data.md, ../reference/status-and-roadmap.md, ../operations/cybersand-codex-development-handover.md]
---

# Direct art batches — WB-ART-002 Stage 1

## Candidate and purpose

**Current candidate, unmerged:** issue #559 Stage 1 on
`codex/agent-art-workbench-v2`, based on main
`d4b18e7f06839b35c8f6a66195206da0f33c5fa3` (includes #542).
#531 is read-only reference; none of its controller/configuration modules is
imported. Native C++ and physics/material defaults are unchanged. This is a
small direct-drawing interface in the ordinary desktop Shared Workbench, not
another World or editor. The [Stage-2 provider candidate](workbench-art-providers.md) now adds provider inference, retained conversation and separate scanline mode on this branch. These remain unmerged candidate behavior.

Open **Shared Workbench → Art batches**. The floating, hideable test input
preserves the canvas layout. Draw/Stop sit beside its title. Enter ordered JSON,
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

## Stop, replacement and ordinary painting

Stop increments the worker epoch and cancels a not-started chunk. An executing
chunk can finish; the executor consumes its receipt and reports its actual prefix
before becoming inactive. Old-epoch submissions are refused. No uncertain replay
or rollback is attempted. A new batch is accepted only after retirement.

New/Load/Restore discard stale callbacks from the old authored recipe and use the
existing native replacement transaction. A retained settings/actor transition
while drawing requests Stop and asks for retry after the current acknowledgment;
this prevents transferring live cells without their recorded authored prefix.
Rejected geometry/settings validation does not otherwise interrupt a batch.
Human strokes during a chunk are delivered before the next chunk and recorded in
that same order with their original brush radius. Their pending queue reuses the
existing worker command capacity; a full queue explicitly refuses further strokes
until the chunk finishes. Ordinary camera/zoom, physics and paint controls remain owned by
the existing workbench.

## Save semantics and existing format boundary

Only native-confirmed changed cells enter `Setup.edits`, coalesced into ordered
horizontal/vertical rectangles. Save while art remains queued/executing asks the
user to Stop or wait; it cannot serialize unseen pending work as applied. After
Stop, Save/reopen includes the confirmed prefix and excludes the cancelled tail.
The shared Setup-v2/generated-start format and existing `MAX_STAMPS`, `MAX_RUNS`
and byte limits remain unchanged. An excessively fragmented authored start can
therefore draw successfully but fail Save with the existing explicit format
error. No silent truncation, second save schema or material Flatten is introduced;
#548 separately owns that successor. Save reconstructs authored start, not evolved
physics state. Ordinary brush recording semantics outside art remain unchanged.

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
