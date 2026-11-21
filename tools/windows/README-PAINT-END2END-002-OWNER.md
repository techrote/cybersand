# PAINT-END2END-002 — physical Windows/NVIDIA evaluator

This is an **experimental, source-pinned, isolated** owner qualification for the
[CyberSand PAINT #703](https://github.com/techrote/cybersand/pull/703) follow-on.
It does **not** modify a production installation, push a compiled binary into Git
LFS, promote a Workbench default, mark Ready, or merge anything.

## Exact-source bundle

Download the **`paint-end2end-002-owner-evaluator-<SHA>-<run>.zip`** artifact
from the evaluator's GitHub Actions workflow. Extract it to a new folder.
The ZIP contains `source-sha.txt`, a source-matched
`windows-candidate/` (native DLL, custody manifest, hashes), this README
and `RUN-PAINT-END2END-002-OWNER.ps1`.

Prerequisites: physical Windows 11/NVIDIA GPU; interactive desktop; Git for
Windows with Git LFS; Python 3.9+; official Godot 4.7 stable console executable;
and network access to the GitHub repository for the pinned source and Rapier
DLL. It works independently of the owner's installed Workbench.

From PowerShell, inside the extracted bundle:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\RUN-PAINT-END2END-002-OWNER.ps1 -Scenario 262k -Godot "C:\Godot_v4.7-stable_win64_console.exe"
```

Choose `-Scenario 16k`, `65k`, `262k`, or `all`. The `all` option runs
24 independent rendered Godot trials: four control and four candidate trials
for each canvas size. Do not launch this evaluator while other heavy GPU
workloads are active if you want useful timing evidence.

The launcher clones **one exact immutable source commit** to a newly named
`isolated-<SHA>` checkout beneath the extracted folder, fetches only the
source-pinned Windows Rapier LFS dependency, then validates the package's DLL
provenance. A special disposable marker permits the runner to install that DLL
**only in the disposable checkout**, never in an existing CyberSand installation.
No source changes, hidden release fallback or production DLL publication.

## What is compared

- Control: `CYBERSAND_PAINT_BULK_CAPTURE=0`,
  `CYBERSAND_PAINT_BURST_SLICES=1`.
- Candidate: `CYBERSAND_PAINT_BULK_CAPTURE=1`,
  `CYBERSAND_PAINT_BURST_SLICES=4`.
- Both: `CYBERSAND_PAINT_BURST_BUDGET_USEC=6000` and wall-profile enabled.
- Order per fixture: control, candidate, candidate, control, candidate,
  control, control, candidate — balanced, independently restored native World.

A real Workbench **Fill** is initiated through `editor.fill_at`. The harness
requires all affected stored material IDs, matching render revision, changed
uploaded material image and at least 32 changed pixel samples in the **actual
post-draw WorldView framebuffer**. It logs actual Godot renderer adapter, real
Windows display server, p95/p99/max frame gaps and request-to-first-visible-
post-draw duration. A post-draw frame is **not physical monitor scanout**.

Per-trial logs and a source-identified `qualification.json` are written to
`evidence-<SHA>-<scenario>`, with a sibling evidence ZIP. Preserve negative
outcomes and any failure screenshots. The JSON declares
`preliminary_performance_goal_met` only when the **median full-fill gain is
at least 25%** with **p95/p99 median regression no greater than 10%**. This is
advisory only; owner judgment and independent review still govern promotion.
A significant p99/max stall or changed gameplay feel is a HOLD even if the
headline latency ratio is favorable.

The benchmark adapts the visible-frame evidence technique from experimental
[#699](https://github.com/techrote/cybersand/pull/699), without importing its
unmerged controller timestamp instrumentation. Accordingly, the source capture
and planning stages are *included in total Fill wall time but not claimed as
separately instrumented sub-stages*. The dedicated #703 Linux profiling suite
continues to provide those stage-level experimental measurements.

**Acceptance remains Draft/HOLD; no automatic merge or production change.**
