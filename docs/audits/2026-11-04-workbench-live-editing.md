---
title: WORKBENCH-001 pilot switching, reset and live liquid conversion
status: Current
document-kind: audit
scope: Owner feedback, workbench-only liquid and placement admission, actual desktop controls and recovery
canonical-for: [workbench-live-edit-evidence]
last-reviewed: 2026-11-04
related-documents: [../systems/player-control-playground.md, 2026-11-04-workbench-consolidation.md]
---

# Pilot switching, reset and live liquid conversion

The owner reproduced a pilot selector that left the current flyer unchanged, a reset that appeared to do nothing in play, and a refusal when switching away from PressureFlow with evolved overfill. At `a8bbca6e`, the only model dropdown staged a placement model. R required a paused, selected actor and the pressure preparer rejected any retained overfill or sealed gas. The [earlier consolidation report](2026-11-04-workbench-consolidation.md) remains evidence for that older build.

## Updated behavior

- **Pilot** switches immediately. Selecting an existing instance transfers the controls without rebuilding. Selecting a missing flyer replaces the selected flyer at its saved spawn. From observer mode or a passive barrel it places a new flyer at the entered coordinates. **Place model** still supports independent placement of duplicates. Keyboard 1–8 uses the same pilot path.
- **Reset selected [R]** works while playing or paused. An acknowledged owner replacement restores the saved pose upright with neutral motion, reveals the target if it is offscreen, and resumes if the simulation was playing. The status names the accepted craft, position and session. Ordinary edits preserve the unaffected live bodies, terrain and current solver. Intentional body/body and body/hard-terrain overlaps are admitted developer experiments.
- **Apply liquid selection** authorizes the requested solver change in the development application. The preparer preserves visible cells and compatible pressure and inertial state. A target that cannot represent pressure overfill, trapped gas or motion sidecars can discard them. A whole-cell Water target rounds fractional cells through the native rule. An explicit one-Apply rounding choice is scoped to that liquid edit. Changing only Brine or resetting a flyer preserves fractional Water. The applied receipt and UI show actual quantities. Scientific setup, saves and non-workbench hosts retain their own admission rules.
- **Failed experiments** retain the failed tick and reason. Reset or Restore start can rebuild the authored setup on a fresh worker after the failed worker and its Rapier graph retire. This recovery starts paused, with no held input. Invalid setup data is rejected before teardown.

## Source and execution

Base `a8bbca6e2c1eb79fe550182a4892414344717087`. Packaged code and runtime commit
`05087ee2b34c9688525e6f30c36f69a8822e242f`, tree `091a109caa6a257a352a3e0d0c1c533c1137fe6b`.
The native source is `49c7e7d6ed12f468128ac007684740cc40dac36c`, built using the existing Godot 4.7 / godot-cpp 101ae380 pins, LLVM-MinGW 20260826 on Windows, and GCC 13.3.0 / binutils 2.42 on WSL Ubuntu 24.04. The native library SHA-256 values are:

| Windows x86-64 DLL | Linux x86-64 SO |
|---|---|
| `156a6cd8c47d4df0debe0d467268ff9b7ed81ec2f9ee8ba6d34dff915bc30400` | `ad2202f68fb25e2ae9740d12a61e2981700c8fbba2b50260edf7c6d5cedadd1c` |

| Executed case | Observation |
|---|---|
| Actual popup, button and R input | Windows graphical 47/47 and Linux headless 45/45. The test places Scooper from blank, selects an existing remote Needle, resets the moving pilot and replaces it with Kestrel while preserving Needle and the distant paint. Move, settings, save, remove and load were exercised during play. |
| Native retained-state test | Both platforms inherited real overfill and a sealed 20-unit gas volume across an unchanged pressure policy. Fractional Water cells at 75 and 180 units survived a Brine-only change and PF → FreeMass. PF → CY/IN accounted for rounding and dropped incompatible state. Source/target policy hashes and the quantity equation came from the native receipt. |
| Shared owner conversion | With two overlapping flyers and hard cells present, actor insertion and a Brine switch retained fractional Water and pressure overfill. On each OS PF → CY changed 102,255 Water units to 102,000. It discarded 254 overfill units and two pressure-flow cells' motion, consumed one visible unit in rounding, and resumed play. |
| Failed-session recovery | A real native active-core capacity failure was observed. Reset re-created the authored Midge, source and paint, retired the old graph, and advanced one native/physical step on the fresh owner. A bad policy request did not retire the failed owner's authored recovery setup. |
| Other checks | Hard-placement tests now admit embedded/rotated starting hulls. The 2048 canvas authoring and three-body interest checks passed on both platforms. The Linux targeted pressure-preparation test passed 50 checks and the arrival/reservation test passed 196. |

Run the Godot fixtures with `--path godot --script res://tests/test_workbench_pilot_ui.gd` (graphical) or add `--headless`. The related targets are `test_workbench_live_liquid_edit.gd`, `test_workbench_retained_pressure.gd`, `test_workbench_hard_placement.gd` and `test_workbench_failure_recovery.gd`. Local process bounds were 150–182 seconds. Raw logs remain under `build/wb`. Build the owner package with `python tools/package_workbench_review.py --engine <Godot4.7.exe> --output <new-directory>`.

Intermediate fixtures retained a bad oracle for an unpowered hovering Scooper's vertical motion, a C++ template deduction build failure and an out-of-range IN test velocity. The corrected tests check authoritative pose, actual ticks and admissible IN state. No production controller or coefficient was changed to satisfy those tests.

Independent read-only assessment at 05087ee2 is **GO for owner review on Draft #394**. The review covers live controls, explicit conversions, unaffected inventory, recovery and loss reporting. Human gameplay acceptance and the MAT protected-source transition remain outstanding. The current protected `native/src/world_pressure.inc` digest is `a9c64afdffed2f08d350483a88ee31317ce89f93e960e47a7c2ac688fa44a6d6`. No historical lock was refreshed.

The full Linux core suite passed 165/165 with the corrected IN fixture, and the focused quantity/IN test passed both normally and with ASan/UBSan. Documentation, materialized repository provenance, M11 historical integrity, retrieval and whitespace checks passed. The unmodified protected-source checker still stops at the inherited World.cpp transition. The new package's own engine also ran the live pilot and liquid tests successfully.
