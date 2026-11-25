# CyberSand PUBPRES Completion — Windows owner acceptance

**Draft / HOLD.** This package is an engineering evaluation candidate. Hosted
software-renderer results do not establish acceptance on your Windows 11 NVIDIA
machine. Record what you observe; leave an unperformed test as **NOT RUN**.

## Start with the ordinary Workbench

Extract the complete evaluation ZIP into a new writable folder. Double-click
**Open Workbench.cmd** and leave its console available. The launcher verifies
the package and opens the candidate with the supplied Godot 4.7 runtime, Safe
rendering, full material publication and continuation Off. It prints the source,
graphics mode and persistent profile directory. A second open window cannot use
the same profile.

Open **Water Lab…** and confirm the active readback says **Wave Flow (FreeMass
carrier)**. A staged choice is not an applied native configuration. Keep the
ordinary settings for the first run. In **Details**, set **New width** and
**height** for a fresh canvas, then use **New blank**. Start at 512 square or
1024 square, then repeat the important tests at 2048×1024 and 2048 square.

Use **Paint** to make a solid floor and a Water basin. Select **Place body**,
choose a flyer under **Place model**, and click inside the canvas; the **Pilot**
selector chooses which actor you control. A Needle plus a barrel provides a
simple moving-actor and contact case. Use **Play / Pause [P]** to begin.

## Practical checks

Record PASS, FAIL or NOT RUN for each row, with canvas size, camera mode and the
elapsed time of any problem. Keep the same authored start for comparisons.

| Check | Procedure | Observable acceptance |
| --- | --- | --- |
| 1. Startup | Launch the shipped command; open Water Lab and inspect the active readback. | The ordinary Workbench opens, native Wave is ready, and no missing DLL, script or graphics error appears. |
| 2. Sustained physical play | Run Water and real actors for at least five minutes, including movement and terrain contacts. | Actors and Water continue advancing; controls remain responsive. Report freezes or repeated substantial pauses even if the FPS counter looks healthy. |
| 3. Follow and effects | Select **Follow selected**, move and rotate the flyer, and enable **Thruster fire** where the model supports it. | Camera, material and actor remain aligned, with no duplicate body, persistent stale trail or sudden unexplained camera jump. |
| 4. Free view and large changes | Select **Free camera**, pan and use **− / +**; make a large material edit, then small edits while play continues. | Picking stays aligned with the visible canvas. New material appears in order; smaller later edits are not lost or replaced by old history. |
| 5. Authoring | Paint, erase, select/move a body, and exercise ordinary Undo/Redo for supported edits. | Each accepted operation affects the intended location; rejected operations remain visible as refusals. Authoring stays usable during playback. |
| 6. Pause and reset | Pause, use **Step [.]**, resume, then **Reset selected [R]** and **Restore start**. | Pause stops physical advancement; one step produces one intended step. Resume and resets leave no frozen, duplicate or retired actor. |
| 7. Save and reopen | Give the authored map a name, choose **Save start [Ctrl+S]**, close the application, reopen the same command and choose **Load start**. | The authored material start, actor setup and settings reconstruct correctly in the same isolated profile. **Save start does not save evolved Water, current velocities or a complete live simulation checkpoint.** |
| 8. Longer transition session | Repeat large-to-small edits and camera changes during another five-minute playback at a larger canvas. | No growing stall pattern, runaway memory, missing history, recurring source-integrity error or stuck input develops. |

Small settling motion is not a failure by itself. Lost material, broken contact,
repeated long freezes, disappearing accepted edits, corrupt saves and persistent
visual misalignment are failures. Record a short video or screenshots when useful.

## Capture useful measurements

Open **Engine Lab… → Measure while I fly** for a ten-second actual-clock report.
It records separate native, Rapier and render rates and prints the saved path.
**Trace poses: manual** captures a bounded camera/actor trace. These controls are
optional; do not change coupling or advanced rate overrides to make a counter
look faster. A render FPS value is not a count of completed physics steps.

Keep notes in the sibling **Runs/OWNER-ACCEPTANCE.md**, and place screenshots in
**Runs/Screenshots**. Do not edit this shipped document or other package files:
they are covered by the package's integrity manifest.

Close Workbench, then double-click **Collect Results.cmd**. It verifies the
package and creates a new timestamped ZIP plus SHA-256 sidecar in
**Runs/Reports**. It collects matching launch receipts, bounded logs, Engine Lab
reports, saved authored starts and your notes/screenshots. It does not copy
engine binaries or development caches. The ZIP's `INDEX.json` lists every included
file and explicit file or directory-traversal omissions. Original profiles
and saves remain in place. If collection is partial, retain the named omitted
files for follow-up.

## Result to return

Include the collected ZIP and its checksum, your eight PASS/FAIL/NOT RUN results,
Windows version, NVIDIA model and driver version, display resolution, canvas
size, selected source/renderer, and the shortest steps that reproduce a problem.
The launcher receipts carry exact source and runtime identities. Use separate
profiles for Main, Integration, Donor or explicit experimental modes described
in `READ-ME.md`; do not move binaries between their source folders.

The owner decides physical acceptance and merge. This evaluator never merges,
marks a PR Ready, changes the installed production application or automatically
turns successful code tests into an owner gameplay PASS.
