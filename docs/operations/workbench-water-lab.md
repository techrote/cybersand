---
title: Workbench Water Lab — consolidated controls
status: Draft / research
document-kind: guide
scope: Stacked UI-only candidate above PR 631
last-reviewed: 2026-11-18
related-documents: [wave-flow-evaluation.md, ../architecture/wave-flow-v1.md]
---

# Workbench Water Lab

The owner's evaluation found the top Workbench toolbar had become a stack of
Water solver, comparison, live status, equipment and apparatus rows. Wave Flow was
also absent from the older liquid-policy presets menu, making the correct
selection hard to discover. This change consolidates those *existing* controls;
it deliberately does **not** add another Water solver or native authority.

## Entry and navigation

The Workbench has **one** permanent **Water Lab…** entry in the top toolbar.
Open it to access a resizable, scrollable, non-modal five-tab Water Lab:

| Tab | Controls |
|---|---|
| Solvers & scenes | One Water-law selector for FreeMass, Wave Flow, PressureFlow reference/cached/dormant and Inertial; four authored comparison scenes and pool workers |
| Wave tuning | All 18 bounded Wave controls, Body push (Water force on Rapier actors), presets, Reset, Revert and native values |
| Transport & spray | Ballistic, IN signed, face release and tuning, PF gas/capacity, fine cores, impact spray, jet tuning |
| Equipment | Valves, drains, nozzles, aiming, pumps, supply, placement and built-in equipment starts |
| Advanced policy | Full native-backed liquid policy assignment editor, original presets, geometry and one-shot normalization |

The native **Applied/Requested/STAGED/REFUSED** report and **Apply solver /
tuning** action stay fixed below the tabs. No secondary Wave/spray popups are
created by Shared Workbench. The older per-material policy dropdown is retained
only in **Advanced policy** and remains semantically distinct from Wave Flow's
FreeMass-carrier overlay.

**Wave Flow is disabled by default.** Enabling it stages Wave and automatically
requests its FreeMass carrier; native activation requires **Apply solver /
tuning** or **Load / reset scene**, then a positive native readback. Returning
to PF/Inertial/FreeMass restores law-specific requests. It never silently changes
the production Water default.

## Body push (Water force on actors)

**Bodies (Rapier actors)** on the Wave tab sets how hard Wave Water pushes
actors and bodies. It changes only the force offered to Rapier, never the Water.

- **Body push** is n/256 of the original push. 256 means unchanged, and 0 means
  Water never pushes a body.
- **Push by amount** = 1 scales each wet cell's push by the Water it holds. A
  faint trickle (a few units) then presses about 1% as hard as a full cell. In
  original Wave, a trickle across a flyer's top pressed as hard as a solid sheet
  and could pin even large flyers. 0 keeps original Wave.

The Water Lab stages Push by amount = 1. A World constructed without the option
keeps the original per-cell push.

Body push and Push by amount cover every path by which Water pushes a body:
- Wave contact with resting or leaning Water;
- the Workbench boundary pressure of Water touching a body face (the strongest
  term, 0.19 per cell per tick);
- displacement when a body moves into Water;
- ballistic parcel splash (Body push only, since a parcel carries its own
  quantity).

In the impact comparison scene, after 150 ticks the first body sank 131.5 cells
at Body push 256 and 143.0 at 0, where Water offers no resistance.

## Waterwall spill (WAVE-WATERWALL-001, Draft/HOLD)

The **Wave tuning** tab ends with a **Waterwall spill** subsection. It adds no
toolbar control.

| Control | Meaning |
|---|---|
| Waterwall spill | On: exposed Wave faces beside open air discharge quickly, and unsupported Water falls faster. Off: original Wave Flow, for direct comparison |
| Ballistic release | Exposed faces throw Water outward as parcels that arc, land and rejoin the grid. It throws through the Ballistic Water parcels, so turning it on also turns on Waterwall spill and Ballistic Water; turning Ballistic Water off turns it off |
| Fall speed / Pool feed | Cells per round for unsupported Water, and mass units per round a pool may move toward its draining edge |
| Throw speed / Parcels per tick | Outward speed as n/256 of √(2gh), and the per-tick launch budget (ballistic release only) |
| Blobs / Stream share | Blobs (1, the default) clumps thrown water into blobs where it meets falling water. Stream share keeps part of each throw pouring straight down (0, the default, is off). Both apply to ballistic release only |
| Stream draw | Adds a vertical stream poured straight down from each throwing face, on top of the full throw. The pool behind the face refills it, unlike Stream share, which takes the stream out of the throw. 0 (the default) is off. Ballistic release only |

As with every Water Lab control, these settings are staged until **Apply solver /
tuning** or **Load / reset scene**. The native readback beside each control and
the spill status line show what is actually running: exposed-face transfer,
falling cells, parcels launched, in flight, landed, refused or deferred, ticks
with a full parcel pool, and launch and flight time. A spill request is only
sent with Wave Flow. Presets and **Reset Wave defaults** do not change it.

**Ballistic Water** (Transport & spray tab) works with Wave Flow, with or
without spill: impact spray, jets, nozzles and Water thrown by bodies fly as
ballistic parcels and rejoin the Wave grid. Choosing Wave keeps its setting.
With spill on but Ballistic release off, the native release budget reads 0 by
design. **Face release** is available under Wave only while Waterwall spill is
off, because spill owns exposed faces.

To compare, load a start, select **Wave Flow** and press **Apply** with spill
off. Then turn **Waterwall spill** (and optionally **Ballistic release**) on and
press **Apply** again. Apply retains the current cells, so to compare from the
same authored state, reload the start between runs.

## Native failure and recovery (Waterwall branch)

If a native operation fails, Workbench pauses and keeps its last valid view.
The message begins `Native tick … stopped:` and retains the first native error.
For body-occupancy preparation it also identifies the failing stage, body/proxy,
source cell and intended destination. Copy the full message before resetting.
The error is retained through later reads and refused edits. Reset or Restore
start rebuilds the authored setup; it does not resume a partially failed World.

Body push = 0 disables the force offered to Rapier, but overlap reconciliation
still moves Water out of the body. Thus zero push does not disable relocation
or ballistic launch and does not rule out an occupancy-preparation fault.

The provisional protection covers native exceptions during editing, coupling
and copied observations, including a fault discovered during publication.
The original underwater surface-crest trigger remains unconfirmed. The native
boundary stress suite and the focused Godot failure/recovery tests are separate
from physical Windows/NVIDIA owner acceptance. Source-matched execution results
and the current evaluation package belong in the Draft PR ledger.

## Acceptance and retained boundary

All existing controls and their signal handlers are the original objects, now
mounted inside Water Lab. No native files, material IDs, producer/generation
services, scenario schemas, physics tick functions or numerical constants change.
Editor Save/Load remains a starting-canvas recipe, not a physical Wave snapshot.
Changing Wave settings preserves compatible cells/actors but resets Wave's
retained flux; illegal conversion or configuration still refuses atomically.

Regression added to the real Shared Workbench Wave test verifies all five tabs,
the exact original control objects and always-visible native readback, no extra
Wave/spray popup, and tab switching. Existing native Wave and Workbench tests
remain required. Physical Windows 11/NVIDIA GUI acceptance, including low-height
displays and pointer interaction, remains owner-gated.

Branch: `experiment/waterlab-631-consolidated-ui`, stacked on the frozen
source of Draft PR #631. **Draft / HOLD, do not merge.**
