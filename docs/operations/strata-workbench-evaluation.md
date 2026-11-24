---
title: Evaluate Strata Theatre in the ordinary Workbench
status: Current
document-kind: guide
scope: Owner controls, three native layered scenes, authored Save and platform acceptance boundary for STRATA-THEATRE-WORKBENCH-001
canonical-for: [strata-workbench-owner-evaluation]
last-reviewed: 2026-11-24
related-documents: [../systems/strata-workbench.md, github-development-and-release.md, ../architecture/shared-workbench-authoring-data.md]
---

# Evaluate Strata Theatre in the ordinary Workbench

**Draft/HOLD.** This candidate adds an optional four-plane authoring view to the
ordinary Workbench. The [contract](../systems/strata-workbench.md) defines ownership,
bounds, persistence and the deliberately static decorative planes. This guide
does not imply that an unexecuted platform or the owner's physical GPU passed.

## Open and inspect

Extract the complete verified Windows evaluator into a writable directory and
run **Open Workbench.cmd**. It opens ordinary Workbench with Strata initially off.
No separate Godot installation is required. Runtime identities, checksum and
complete payload manifest accompany the qualified package when published.

1. Open **Strata Theatre…** in the ordinary toolbar.
2. Load **Industrial assembly hall**, **Science-fiction arcology** or
   **Organic / industrial cavern**. These replace the authored scene through
   ordinary Workbench admission. Save your current scene first if wanted.
3. Examples open in **Overview** after admission. Use the existing camera picker,
   zoom and middle-mouse pan controls to inspect details.
4. Compare **Stack**, **Flat active plane**, individual visibility and Solo.
   Disable Strata and enable it again while observing the same active actors.

The scenes use native materials and true straight-on side elevation. The play
routes and voids remain distinct from rear trusses, distant structures and
atmospheric decoration. They introduce no asset corpus or generator programme.

## Author and play

Choose the edit target in the Strata panel. **EDIT: PLAY / SCRIPTED / EFFECTS /
BACKGROUND** in the ordinary paint toolbar identifies where a human edit goes.
Use the ordinary material picker, radius and tool selector. Play keeps its normal
editor. Static planes support Brush, Eraser, Line, Rectangle, Outline and bounded
Select/Copy/Paste; right mouse erases. Each operation is limited to 16,384 cells,
and Fill remains a Play-only tool.

Ctrl+C copies the visible selected plane's native materials, including Empty;
Ctrl+V selects Paste. Ctrl+Z/Ctrl+Y and the panel's Undo/Redo act on the selected
plane. Play history still has its normal simulation restrictions. Nonplay history
is independent because those Worlds remain static. A hidden, locked or solo-
excluded plane refuses edits. A locked visible plane may still be copied.

Actors, collisions, sources and physical tools belong to **Play**. Add or select
an ordinary actor, then use the usual Play/Pause and pilot controls. Rear beams
are visual architecture and do not collide with an actor merely because they
overlap it on screen. The effects plane is static in this milestone. Its clock
label states that limit; there is no independent weather simulation or transfer.

Opacity, relative depth, parallax and haze adjust appearance. **Reset presentation**
restores visual settings while keeping every material layout, history and active
play World. Play depth stays zero to preserve the normal camera/actor alignment.

## Save and reopen

Use the ordinary named **Save start / Ctrl+S**, including while Strata is disabled.
The saved envelope includes all four authored layouts and presentation settings.
Exit completely, open a fresh Workbench process and use **Load start** with that
name. Verify each plane separately, then continue editing.

Save is an authored-layout operation. Evolved play liquids, fire and actor motion
are not exact continuation state. Explicit **Flatten / Bake History** can make
current play material occupancy its new authored baseline before Save; it never
merges visual planes. Saving alone leaves this session's Undo intact. Undo stacks
are not promised across restart. Ordinary old Setup/generated/Flatten saves keep
their existing nonlayered readers.

Select an editable **Play** plane before Flatten or model-assisted Art authoring;
both retain their Play-only authority. Disabling Strata restores ordinary Play
editing while retaining the saved layered locks/visibility for the next enable.

## Owner appearance and interaction gate

On the physical Windows 11/NVIDIA machine, record the actual GPU/driver, display
resolution/scaling and source/package identity. Check all three scenes at useful
zoom levels and at the intended larger canvas size:

- Judge whether rear architecture and haze improve depth while routes, actors and
  material edges remain easy to read. Adjust parallax/opacity and report settings.
- Paint one unmistakable mark in each plane, pan/zoom/resize, then inspect that
  plane alone. Confirm hidden/locked targets refuse input and Undo affects only
  the intended layer.
- Pilot an actor while repeatedly disabling/enabling the view. Confirm no spawn
  reset, duplicate actor, lost control or unexplained simulation pause.
- Save, exit and reopen. Check all layers, settings, actor spawn definitions and
  any explicit flattened play baseline; continue painting after reopen.
- Compare ordinary flat and layered responsiveness under the same scene and
  camera. Record visible stalls and input feel; a frame counter is not sufficient.

Hosted Linux/Windows graphics and a pristine package test provide engineering
evidence. They do not replace this physical appearance/performance decision.
