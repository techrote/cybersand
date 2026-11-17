---
title: Workbench Water Lab — consolidated controls
status: Draft / research
document-kind: guide
scope: Stacked UI-only candidate above PR 631
last-reviewed: 2026-11-16
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
| Wave tuning | All 18 bounded Wave controls, presets, Reset, Revert and native values |
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

## Waterwall spill (WAVE-WATERWALL-001, Draft/HOLD)

The **Wave tuning** tab ends with a **Waterwall spill** subsection. It adds no
toolbar control.

| Control | Meaning |
|---|---|
| Waterwall spill | On: exposed Wave faces beside open air discharge quickly, and unsupported Water falls faster. Off: original Wave Flow, for direct comparison |
| Ballistic release | Exposed faces throw Water outward as parcels that arc, land and rejoin the grid. Turning it on also turns on Waterwall spill |
| Fall speed / Pool feed | Cells per round for unsupported Water, and mass units per round a pool may move toward its draining edge |
| Throw speed / Parcels per tick | Outward speed as n/256 of √(2gh), and the per-tick launch budget (ballistic release only) |

As with every Water Lab control, these settings are staged until **Apply solver /
tuning** or **Load / reset scene**. The native readback beside each control and
the spill status line show what is actually running: exposed-face transfer,
falling cells, parcels launched, in flight, landed, refused or deferred, ticks
with a full parcel pool, and launch and flight time. A spill request is only
sent with Wave Flow. Presets and **Reset Wave defaults** do not change it. The
generic **Ballistic Water** switch stays refused under Wave, because the parcel
pool belongs to the release.

To compare, load a start, select **Wave Flow** and press **Apply** with spill
off. Then turn **Waterwall spill** (and optionally **Ballistic release**) on and
press **Apply** again. Apply retains the current cells, so to compare from the
same authored state, reload the start between runs.

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
