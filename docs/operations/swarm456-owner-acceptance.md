---
title: Unified Swarm Windows owner acceptance
status: Current
document-kind: guide
scope: Ordinary Workbench access, historical standalone launch and physical Windows NVIDIA evaluation of SWARM-004/005/006
canonical-for: [swarm456-windows-launch, swarm456-physical-acceptance]
last-reviewed: 2026-11-27
related-documents: [swarm456-unified-mainline.md, swarm006-workbench-playtest.md]
---

# Unified Swarm Windows owner acceptance

## Integrated Windows Workbench

Extract the complete integrated evaluator ZIP and use its ordinary Workbench
launcher. Pause the World and open **Reciprocal assembly…**. The three
experimental controls start OFF. To evaluate an existing map, follow
[Saved maps](#saved-maps) before drawing an activation dab. For repeatable
comparisons, use the settings below. The integrated source includes native
admission checks, shared authoring interlocks and a fresh-process Save/Reopen
exercise. Physical Windows 11 / NVIDIA evaluation remains owner-scoped.
[Integrated source](https://github.com/techrote/cybersand/commit/466d34506feb62132d5b1badd4a0f9ab4fbb6886)
and [source-matched qualification](https://github.com/techrote/cybersand/actions/runs/45923903582).

## Historical standalone evaluator

The original feature-specific evaluator from [PR #729](https://github.com/techrote/cybersand/pull/729)
was delivered as Draft/HOLD for physical owner review. To reproduce that
historical delivery, use its exact archive and published SHA-256.

Keep the inner `CyberSand-SWARM456-Draft-HOLD-Windows-<source>.zip`, its `.sha256`
sidecar and `CyberSand-SWARM456-Windows-Owner-Acceptance.ps1` together. The source
suffix is the first 12 characters of the build commit. In Windows PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\CyberSand-SWARM456-Windows-Owner-Acceptance.ps1 -Archive .\CyberSand-SWARM456-Draft-HOLD-Windows-<source>.zip
```

Substitute the actual source suffix. The launcher verifies this particular
archive, extracts into a fresh folder, validates its file/runtime manifest and
opens ordinary Shared Workbench. `-VerifyOnly` performs the same checks without
launching. After verification, use **Open Workbench.cmd** inside that folder.
The bundled engine is Godot 4.7. Developer environment overrides are unnecessary.

## Saved maps

The normal Windows saved-map folder is
`%APPDATA%\Godot\app_userdata\Cyber Sand Reference Sandbox\workbench`.
Before testing, copy the original `setup-<name>.json` and any matching
`.swarm004.json` and `.swarm004-evidence.json` sidecars to a separate local backup
folder. Keep those original bytes unchanged.

Open **Details**, enter the existing map's name without `setup-` or `.json`, and
choose **Load start**. After the map finishes loading, enter a new name such as
`swarm456-owner-copy` and choose **Save start [Ctrl+S]** before making changes.
Names allow 1–48 letters, digits, underscores or hyphens. Continue the acceptance
test and later saves under this new name; the original stays available.

Pause the World, open **Reciprocal assembly…**, and draw an activation dab in the
intended empty crop. Native source material and protected passages constrain the
result; a seed and crop alone do not reproduce a populated owner map.

## Paired generation and inspection

All three controls start OFF: **Source-feasible terminal parts**, **Source-bound
MOSAIC receptors**, and **Bounded reciprocal recovery**. For a SWARM-006 comparison,
enable the first two, run with recovery OFF, then change only recovery to ON.
Retain both results and settings. Editing a control correctly retires old Apply
authority, so regenerate before applying.

For the qualified synthetic comparison settings, use a blank native canvas,
seed **605**, **2 rounds**, crop **192 × 112**, **interface reach 13**, **clear
border 4**, **Balanced** orientation, **Optional negotiation ON**, **sharing ON**,
**FRAME left / MOSAIC right**, **destruction 0**, and independent overrides OFF.
A dab at native `(64,48)` gives crop origin `(0,0)` for these blank cases.

| Expression | Variation | Irregularity | Decoration | Branching | Environment affinity | Cohesion |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Industrial | 0.65 | 0.15 | 0 | 0.75 | 1.0 | 0.15 |
| Viaduct-like | 0.65 | 0.05 | 0.15 | 0.55 | 0.25 | 0.35 |
| Irregular megastructure | 0.65 | 0.95 | 0.25 | 1.0 | 0.7 | 0.2 |

Also try the irregular expression at **128 × 128**, other seeds and different
ownership/orientation settings. Keep those exploratory observations distinct from
the fixed comparison. The registered synthetic success rates are not a guarantee
for your saved map. A blocked result can contain useful visible architecture;
its diagnostics remain available and its World must remain unchanged.

Select **Final composition**, then each proposal round. Final must display the
actual final native cells. Inspect **Joints**, **Unresolved**, **Clearance** and
**Revisions** at Final; provisional selections must show their own proposal.
A source-time local termination is separate from a qualified foreign joint.

## Acceptance checklist

- Generate both OFF/ON members under identical source/settings. Check the complete
  control surface, readable geometry, source/material details and honest failures.
- Apply a valid result, **Undo construction**, regenerate and Apply again. Verify
  the installed native geometry and preservation of content outside the patch.
- Save with a new name, close the application, launch a fresh process and reopen.
  **Inspect saved evidence** should show the original native history while Apply
  and construction Undo remain disabled until a successful fresh generation.
- Start generation, change an input or press **Cancel**, and confirm stale Apply
  is unavailable. Ordinary Paint and shared Undo/Redo should work after retirement.
- On a copy of the original map, check Paint, Water/Wave, Art, Flatten, actors and
  equipment; play through collision, presentation and useful traversal. Note any
  responsiveness or NVIDIA rendering issue.

Before ordinary painting or live editing, turn **Paint territory** OFF or choose
**Close** in the reciprocal dock. While it is ON, canvas strokes edit activation
or protected-passage marks. Wait for cancellation or native work to retire before
using ordinary Paint and history controls.

**Save start** preserves authored edits and the retained generation recipe or
previously adopted material baseline; it does not capture the current live
simulation frame. Fresh **Load start** should restore that authored start. If you
also want to retain the current simulated material state, finish the construction
Undo/history checks first, then use **Flatten / Bake History…** and save under
another name. Flatten adopts a new baseline and clears earlier Undo/Redo history.

First report whether the result is **useful, visually convincing and responsive**,
with **PASS** or **FAIL**, the full source SHA from the package manifest and the
archive SHA-256. The historical standalone uses `candidate-manifest.json`.
On failure, reproduction steps, expression/seed/crop/options,
Windows/GPU/driver details and whether recovery OFF also fails help diagnosis.
Screenshots and locally collected logs are optional; inspect them before sharing.
Private authored maps are not required and must remain local unless you explicitly
choose to share them. The launcher and comparison helper upload nothing.

A failed candidate is repaired and requalified before another acceptance request.
Physical acceptance is the remaining owner decision only after the PR's autonomous
engineering gates pass.
