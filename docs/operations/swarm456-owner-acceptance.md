---
title: Unified Swarm Windows owner acceptance
status: Current
document-kind: guide
scope: Launch and physical Windows NVIDIA acceptance of the exact consolidated SWARM-004/005/006 evaluator
canonical-for: [swarm456-windows-launch, swarm456-physical-acceptance]
last-reviewed: 2026-11-24
related-documents: [swarm456-unified-mainline.md, swarm006-workbench-playtest.md]
---

# Unified Swarm Windows owner acceptance

**Draft / HOLD.** This is the combined SWARM-004/005/006 evaluator from
[PR #729](https://github.com/techrote/cybersand/pull/729). Use the exact archive and
SHA-256 published with that candidate. Hosted Linux/Windows qualification is
separate from your physical Windows 11 / NVIDIA acceptance. No automatic merge
or change of the three experimental defaults is authorized.

## Launch

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

Preserve your original saved map. Use a copy and a new save name for this test.
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

First report whether the result is **useful, visually convincing and responsive**,
with **PASS** or **FAIL**, the full source SHA from `candidate-manifest.json` and
the archive SHA-256. On failure, reproduction steps, expression/seed/crop/options,
Windows/GPU/driver details and whether recovery OFF also fails help diagnosis.
Screenshots and locally collected logs are optional; inspect them before sharing.
Private authored maps are not required and must remain local unless you explicitly
choose to share them. The launcher and comparison helper upload nothing.

A failed candidate is repaired and requalified before another acceptance request.
Physical acceptance is the remaining owner decision only after the PR's autonomous
engineering gates pass.
