---
title: EXPLORE-001 Windows desktop candidate playtest
status: Planned
document-kind: guide
scope: Owner acceptance of the source-built generated-map desktop candidate, separate from hosted automation
canonical-for: [explore001-desktop-playtest]
last-reviewed: 2026-11-08
related-documents: [../systems/explore001-generated-playable-maps.md, ../audits/2026-11-08-explore001-integration-qa.md]
---

# Windows candidate launch and acceptance

This is an owner playtest candidate, not a production release. Extract the
complete Actions artifact to a writable directory, then double-click
**Open Workbench.cmd**. Keep the project, executable and addons together. The
launcher imports the project and opens the existing Shared Workbench. No Godot,
Git, Python or separate native installation is needed on the playtest machine.
First import can take a while. The bundled source-built candidate manifest and
`candidate-manifest.json` identify the source tree and SHA-256 of every delivered
payload; the retained-runtime reference describes different historical bytes.

Use a unique named start. Godot stores starts in its ordinary application user
directory, outside the extracted candidate, so they survive closing the process.
Back up valued starts before testing. A start reconstructs authored terrain and
actor spawns; it does not resume the evolved simulation at the exit tick.

## Manual acceptance procedure

1. In Shared Workbench click **New from generator…**, select
   **gen007-deepworks**, seed **19337**, source origin **0,0**, size **1024**.
   Generate a preview, inspect its materials, and explicitly install it.
   On the very first opening, verify both bottom action buttons are on screen.
   Resize the window and scroll the contents; action buttons should stay visible.
2. Select an existing flyer such as **Midge**, place it in clear terrain, select
   it under **Pilot**, then press **Play**. Test the displayed movement controls
   (W/A/S/D for the flyer). Check contact with solid terrain and passage through
   open routes. Record any stuck actor, unexpected collision or movement issue.
3. Switch the existing free/follow/overview camera controls; pan and zoom.
   Check that input remains usable and the flyer stays observable. Hosted
   headless success does not establish camera or movement feel.
4. Pause and use the existing brush to add a solid wall and erase an opening.
   Resume and check the flyer contacts the new wall and passes through the
   erased opening. Paint Water; observe motion and flyer interaction without
   assuming pressure equivalence or a new Water law.
5. Preview another ordinary chunk profile twice, change size, and cancel a
   partial preview. Check that complete previews contain consistent terrain and
   cancellation keeps the installed map. Install a completed preview if desired.
6. In **Details**, enter a unique name and click **Save named start**. Record
   source/seed/region, spawn, selected flyer, paint marks and erased opening.
   Close Godot completely and relaunch **Open Workbench.cmd**.
7. Enter the same name and **Load start**. Let native regeneration finish;
   confirm authored terrain, ordered edits, actor spawn and selection, then
   continue painting and save again. Close/reopen once more if reporting a bug.
8. Repeat a bounded 512 test and, if resources permit, a 2048 test. Large
   preparation temporarily retains old and candidate Worlds plus copied grids;
   measure pauses/memory rather than inferring low cost from bounded size.

Report candidate source commit, Windows/GPU, size/profile/seed/origin, exact steps,
expected/observed behavior, saved start and original screenshot/log where useful.
The owner verdict remains pending until a person performs this procedure.
