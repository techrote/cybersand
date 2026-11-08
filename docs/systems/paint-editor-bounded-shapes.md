---
title: PAINT-001 bounded shape planner and integration seam
status: Planned
document-kind: system
scope: New isolated editor geometry modules at PAINT-001 Draft; ordinary workbench mounting and native-ACKed authored persistence remain Planned
canonical-for: []
last-reviewed: 2026-11-08
related-documents: [player-control-playground.md, procedural-world-generation.md, ../operations/github-development-and-release.md]
---

# PAINT-001 — bounded painting editor

Parent: [issue #543](https://github.com/techrote/cybersand/issues/543). This page records
an additive **Draft candidate**, not a working mounted painting editor or an
accepted-main implementation.

## Accepted-main baseline and duplicated functionality avoided

At accepted main `1f82dac1cebc9b38a319153354e4bcc774289417`:

- `shared_workbench.gd` already mounts paint/erase, a small 18-material
  construction palette, a 2–24-radius brush, zoom, camera drag, bodies, pilot,
  native World setup and named authored-start save/reopen.
- `main.gd` has three distinct **single-stamp** brush shapes (circle, square,
  rectangle), native-facing material IDs, and the one authoritative aspect-fit
  screen-to-world transform. Do not replace them with another renderer.
- `workbench_setup.gd` records native construction paint discs and boxes; its
  deterministic rectangle-coalescing path caps authored construction at 4096
  rectangles and file size at 1 MiB. A queued brush is *not* an ACKed native
  mutation receipt. Do not call a saved authored start a live-physics checkpoint.
- `simulation_worker.gd` admits `queue_emit_cells` with at most 4096 exact
  world-space cell coordinates per command and eight pending commands. It is the
  exclusive worker owner; production client code must obey the ordinary
  `_microscenario_tool_allowed`/water/physical-owner/protection gates.
- Experimental #542 provides GEN-007 play-plane import and separate-process
  generated-map replay; experimental #531 supplies bounded model-authored edits
  and protected overlays. Neither belongs to PAINT-001.

The user-visible gap is **multi-cell drag authoring as one bounded operation**:
straight lines, filled rectangles and outlines, eventually reusable selections,
copy/stamps and safe authored undo/redo. One-off rectangle footprints already
exist; this work is not another single-stamp implementation.

## Current isolated implementation (A: shape planning)

`res://scripts/workbench_paint_editor_shapes.gd` exposes:

- `line(from_cell, to_cell, radius, extent)`: Bresenham integer centreline
  unioned with a matching native integer-radius disc lattice; one-cell radius
  zero is supported.
- `rectangle(from_cell, to_cell, filled, extent)`: inclusive bounds,
  drag-direction independent; outlines walk only the perimeter, never the
  whole filled area.
- Successful results include `accepted`, `cells: PackedInt32Array`
  interleaved `x,y`, `count` and an explicit `clipped` flag. IDs are row-major
  sorted, no duplicates, no out-of-world emission, 4096-cell absolute cap.
  Invalid endpoints/radii/extents or oversized shapes refuse **without a partial
  plan**. Accepted extents are 512–2048, multiple of 64, matching Setup-v2.
  Clipped line *radii* are labelled; endpoints themselves must be inside.

This module does **not** own a World or a UI control. A geometry PASS is neither
a worker admission nor a material readback. The dedicated GDScript test:
`godot --headless --path godot --script res://tests/test_paint_editor_shapes.gd`
checks bounds/caps/reversed corners and passes the accepted line and rectangle
plans to the **existing** `CyberSimulationWorker.queue_emit_cells`. It waits for
an actual worker snapshot, joins the owner and reads every submitted cell back
through the native World, including an untouched outline interior. Run against
source-built native + Godot on Linux and Windows; retained binaries must be
identified, not silently mistaken for the tested source. The test has not yet
been executed in this authoring environment; its result is **NOT RUN**.

## Integrator handoff — missing public host seam

Only the independent cross-lane Integration owner may edit/mount
`shared_workbench.gd`, `main.gd`, `simulation_worker.gd` and cross-branch
persistence. After #542 and #531 release their shared-workbench source, supply
a narrow ordinary host operation (name provisional):

`queue_workbench_paint_cells(cells, material_id, source_generation, expected_revision)`

The operation must check authoring state, full coordinate/size bounds, material
capability, active water/physical-owner and agent/protected scope, pause/focus,
generation/revision fencing and shared native owner exclusivity. It must return
a distinguishable **queued** response and an eventual **applied/refused** native
result; *only the latter* may update an authored-start recipe. Do not expose raw
`simulation_worker.queue_emit_cells` as an unrestricted model/editor API or
retry an ambiguous already-applied mutation. Plan previews are invalidated on
camera/source/world generation change; mapping from local pointer to world-space
continues to use `main.gd`'s authoritative transform.

Use existing Setup-v2 rectangle stamps only where their original material
identity and reconstruction budgets are faithfully preserved. Erasure, Water
and generated-start overlays must have exact acknowledged effects, not a guessed
record. If acknowledgement or undo history cannot be made authoritative,
explicitly disable that UI affordance.

## Remaining work and acceptance

1. Run the exact GDScript/native test and correct any actual RED.
2. Integrator admits the public host operation and scene mounting with
   non-overlapping #531/#542 source ownership and interactive preview.
3. Extend selection/stamps/bounded fill; benchmark 512²/1024²/2048² planning.
4. Authoring-only undo/redo with captured old values, native ACK and safe
   invalidation after ticks/revisions/agent edits.
5. Exact generated-map and legacy setup save, close, reopen, compare material
   IDs/Water/actors; independent Windows graphical feel acceptance.

**Evidence boundary (8 November 2026):** static source review and planned
standalone actual-native regression. No local Godot binary, source-matched DLL
or executable checkout is available in this task environment; no PASS is
claimed. All usual production Native, Windows/Linux GDExtension/Godot,
Documentation/provenance, source-admission, owner-human and merge gates remain
unexecuted for this new candidate.
