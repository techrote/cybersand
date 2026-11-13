---
title: Combined Materials Lab and Workbench Windows evaluation
status: Planned
document-kind: evidence
scope: Acceptance instructions and exact identities for one standalone Windows evaluation prerelease
canonical-for: [mat-workbench-evaluation-20261113]
last-reviewed: 2026-11-13
related-documents: [../audits/2026-11-12-mat-auth-workbench-integration.md, ../operations/materials-lab-authoring.md, ../operations/wb-art-paint-integrated-candidate.md]
---

# CyberSand Materials Lab + Workbench evaluation

**PENDING — this file is a release preparation, not a successful qualification claim.**
Request 5 source `11b809a579ecade05baaeded59461ab8fc3f6c39` passed its complete
Linux and Windows source campaigns in
[run 43402768596](https://github.com/techrote/cybersand/actions/runs/43402768596).
While that campaign was running, #564 added stricter
pointer and brush-anchor test assertions at `00017c65da096c61585f026476ae1e62e1aea256`.
The request-5 original receipts remain historical.
The current request 6 source `fd1d66b18ac80f564f7078b8a0a902297895672f` incorporates
that normal merge; its fresh
[run 43409148541](https://github.com/techrote/cybersand/actions/runs/43409148541)
is still pending. A successful current Windows/Linux campaign, tested standalone
package and exact publication-child gates must replace every pending identity
before these notes can be published. No request-5 result qualifies request 6.

## Build identity and evidence

| Item | Exact identity |
| --- | --- |
| Qualified application source | PENDING |
| Source tree | PENDING |
| Runtime publication child and release tag target | PENDING |
| Accepted main, including #562 and #563 | `63f8b1ba6559906fe85f3ad0269aa296e4141d67` |
| Included latest #564 Workbench | `00017c65da096c61585f026476ae1e62e1aea256` |
| Included reviewed native capability transition | `b432d52d0d9acaa22f93eeb8d1fad48c64b4c087` |
| Complete publisher and packaged execution | PENDING |
| Exact-child Documentation / Native / Godot / Palette gates | PENDING |
| Windows native DLL SHA-256 | PENDING |
| Evaluation ZIP SHA-256 | PENDING |

The release copies the independently reviewed Actions evaluation ZIP and its
original checksum byte for byte. It adds these acceptance notes. Full source
history, Godot, Python, Git, C++ tools and app-local runtime dependencies stay in
the bundle, so Materials Lab can perform its admitted native comparisons without
installing developer tools. This is a prerelease and does not become GitHub's
latest release.

## Open the application

Download the ZIP, its `.zip.sha256` sidecar and these notes from this release.
In PowerShell, run `Get-FileHash .\<downloaded-archive>.zip -Algorithm SHA256`
and compare the complete hexadecimal value with the sidecar and the table above.
Extract the **entire** archive to a writable folder, then double-click
**Open Workbench.cmd**. The first launch imports the project. Keep `source` and
`dependencies` beside the launchers. **Open-Materials-Lab.cmd** opens the same
Materials Lab directly.

## Acceptance procedure

1. **Generate and install terrain.** Open **New from generator…**, then choose
   Profile **gen007-deepworks**, Seed
   **19301**, World X/Y **0/0**, and Size **1024 × 1024**. Click **Generate preview**,
   then **Install into workbench**. Confirm the profile list is populated and
   terrain, camera movement and material selection work. Keep the World paused
   during the history checks below.

2. **Check one manual and agent history.** First clear a small target patch around
   `(180, 40)` through `(203, 63)` using manual **Rectangle** and **Erase · 0**;
   this is the baseline. Agent writes support existing Empty and HardWall cells.
   Make a small manual **Metal · 28** mark outside the patch. Open **Art batches**,
   select **Direct JSON**, material **Hard wall (58)**, Focus X/Y/W/H
   **0/0/1024/1024**, **Protect** off, and enable **Rectangle** under Tools. Click
   **Draw** with these inclusive rectangle coordinates:

   ```json
   [{"shape":"rectangle","x0":180,"y0":40,"x1":203,"y1":63,"material":58}]
   ```

   Wait for completion, then make a second manual Metal mark elsewhere. Use the
   toolbar **Undo** three times: second mark, agent rectangle, first mark must
   disappear in that order, leaving the cleared baseline. **Redo** three times
   restores their chronology. Use the buttons so text-field focus cannot capture
   shortcuts. Wait for native completed/confirmed status after every manual
   gesture, Draw, Undo and Redo. Direct JSON needs no account or model credentials.

3. **Check cancellation and continued editing.** Draw
   `[{"shape":"rectangle","x0":0,"y0":0,"x1":1023,"y1":1023,"material":58}]`.
   Press **Stop** after progress shows changed cells and while work remains;
   wait for the current chunk's acknowledgment, then **Undo** its confirmed
   prefix. If it completes too quickly, undo and repeat with that rectangle
   duplicated in the same array. Leave the prefix undone for the Lab roundtrip.
   Live external models are optional; automated provider checks use local
   fixtures and do not imply a paid cloud inference session.

4. **Compare an isolated material edit.** Open **Materials Lab…**, search **sand**,
   and select **002 / sand**. Under **Inspect**, choose **Make editable copy**.
   Under **Edit copy**, set **Density (larger = heavier)** to **500** and **Base
   colour and transparency** to **#115bcbff** (RGBA 17, 91, 203, 255). In **Compare
   edits**, choose **Start above the other material**, Other material **003 water**,
   **Seed 2**, **Steps 120**, **Simulation threads 4**, then **Build + run comparison**.
   Confirm comparison complete, source unchanged PASS and both native check sets
   PASS; original Sand settles below Water while the blue edited candidate remains
   above. **Save World recipe…**, then **Import World recipe…**. Import restores the
   candidate and scenario and clears the old successful-test claim; run **Build +
   run comparison** again. Close Lab, confirm unchanged Workbench terrain, and
   **Redo/Undo** the retained cancelled prefix. Production Sand is unchanged.

5. **Check equipment and saved starts.** Enter **acceptance-generated** in the
   name field and use **Save start [Ctrl+S]** before changing Worlds. Click
   **Load liquid-lab** for the built-in reservoir, barrel, valve, drain and nozzle.
   Exercise **Valve 1 [V]**, **Drain [G]**, **Nozzle [H]** and **Play/Pause [P]**;
   pause and **Stop all**. Enter **acceptance-liquid** and **Save start [Ctrl+S]**.
   Exit completely, relaunch, enter **acceptance-liquid**, and click **Load start**; check authored
   geometry, actors, settings and closed devices, then continue painting and Undo.
   Enter **acceptance-generated** and **Load start** to open its regenerated
   verified preview; click **Install into workbench** to confirm installation.
   Confirm both saved Metal marks and the small Hard-wall rectangle remain while
   the undone long prefix stays absent. Keep built-in names intact.
   Saves preserve authored construction, not an evolved physics snapshot. Undo
   history is session-local; simulation and World replacement retire unsafe history.

## Qualification and limits

PENDING: add the actual replacement campaign, complete original platform/package
assertions and final four gate URLs after their original evidence is verified.
Earlier Windows failures stay recorded in the integration audit. One same-host
diagnostic established that the mounted combined capture at 5 FPS starved native
compiler work on the software renderer; that private combined capture now uses
1 FPS. Application frame-rate defaults, native work and its assertions remain
unchanged.

The later request-4 failure occurred in the original Lab's initial Workbench
installation wait. Separate unchanged-source controls observed a 43–45 second
installation delay across two process frames, with most of that time in a cold
ANGLE frame and a palette shader cache appearing when it returned. Lowering this
Lab capture's frame rate did not shorten that stall. Request 5 aligned only the
initial Main acknowledgement with the existing 600-second cold-start policy;
request 6 retains that correction and the original Lab capture's 15 FPS. This
does not improve startup latency or establish ordinary-desktop performance.
Dedicated Lab graphical and package cases retain their explicit 1200-second
outer allowance; the source-derived generic headless UI allowance is 3940
seconds. Native compile/execute/service limits remain 180/60/300 seconds, and
the fixed tick counts and experiment windows remain unchanged.

The bundle preserves `source/LICENSE_STATUS.md`, `source/THIRD_PARTY_NOTICES.md`,
Godot notices and the bundled dependencies' own licenses. It does not introduce
a new license grant for CyberSand. Owner desktop acceptance and approval to merge
remain separate from this evaluation release. This publisher never merges main
or changes the feature branches.
