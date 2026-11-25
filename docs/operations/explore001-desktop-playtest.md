---
title: Generated-map desktop playtest
status: Current
document-kind: guide
scope: Accepted generated-map Workbench workflow and manual desktop validation, separate from hosted automation
canonical-for: [explore001-desktop-playtest]
last-reviewed: 2026-11-24
related-documents: [../systems/explore001-generated-playable-maps.md, ../audits/2026-11-08-explore001-integration-qa.md]
---

# Generated-map desktop playtest

Generated maps can be installed, edited and played in the ordinary accepted
Workbench. Use [first launch](getting-started.md) to open **Development workbench**
from a source checkout or a complete evaluator. The
[Architectural Generator walkthrough](architectural-generator-playtest.md)
introduces the richer 80-Gentek chooser; this page exercises the existing native
recipe profile workflow and its save/reopen boundary.

A portable evaluator may provide **Open Workbench.cmd**. Keep its project,
executable, addons, native libraries and source manifest together. Its original
source-built candidate manifest identifies that package; it does not attest a
different checkout or later binary. A current source checkout is not required
to find an old Actions artifact before using the accepted feature.

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
6. In the painting row, enter a unique name and click **Save start [Ctrl+S]**. Record
   source/seed/region, spawn, selected flyer, paint marks and erased opening.
   Close Godot completely and relaunch through the same checked launcher.
7. Enter the same name and **Load start**. Let native regeneration and source
   verification finish, then click **Install into workbench** on the verified
   preview. Confirm authored terrain, ordered edits, actor spawn and selection, then
   continue painting and save again. Close/reopen once more if reporting a bug.
8. Repeat a bounded 512 test and, if resources permit, a 2048 test. Large
   preparation temporarily retains old and candidate Worlds plus copied grids;
   measure pauses/memory rather than inferring low cost from bounded size.

Report candidate source commit, Windows/GPU, size/profile/seed/origin, exact steps,
expected/observed behavior, saved start and original screenshot/log where useful.
Report whether the steps were performed by a person, automation or source
inspection. Accepted implementation and package qualification do not assert
that a particular owner has performed this physical playtest. Original
[8 November candidate evidence](../audits/2026-11-08-explore001-integration-qa.md)
retains its dated source/runtime scope.

<a id="windows-candidate-launch-and-acceptance"></a>

The original launch heading remains a compatibility destination. Use the current
procedure above; [baseline candidate text](https://github.com/techrote/cybersand/blob/00cdb02f103265b6dc5224c68283e9a0c8cb449f/docs/operations/explore001-desktop-playtest.md)
preserves the earlier package-specific instructions.
