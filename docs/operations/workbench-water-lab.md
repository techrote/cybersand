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
| Solvers & scenes | FreeMass, Wave Flow, PressureFlow cached/dormant, Inertial, four authored comparison scenes, pool workers |
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
