---
title: ULTIMA product lane independent intake
status: Historical
document-kind: audit
scope: Fresh reader observations before cross-lane conclusions or patch proposals, pinned to predecessor 20170bd6
canonical-for: []
last-reviewed: 2026-11-25
related-documents: []
---

# Product lane independent intake

Reviewer: Specialist B. Source: `20170bd6259498c3d2774ab274567febb043fc1d`.
These observations preceded reading the other lanes' conclusions and proposed
changes. They are investigation questions, not claims that tests passed.

## Initial reader assessment

The README, portal and six practical manuals form a coherent reader journey.
They already distinguish authored reconstruction, live simulation, retained
captures, unmerged successors and physical acceptance. Preserve this structure.
The source launcher identifies an exact Godot revision and separately explains
source/runtime provenance; the GUI attempt must respect that distinction.

The first-session tutorial's apparent route to painting depends on several
toolbar controls whose visibility at normal and narrow window sizes requires
actual observation. Its suggested Hard Wall container, Sand, Undo/Redo, named
Save and reopen are a useful small test with observable outcomes. The Art example
requires a blank admitted work area; existing body/source exclusions must not be
mistaken for a failed JSON tutorial.

Save guidance explicitly exposes the existing replacement weakness. A revision
must follow the implemented and tested persistence contract rather than claiming
universal atomic or crash-safe behavior. Generated loading also needs a separate
installation step; the first-session close/reopen instructions should be checked
against the actual save representation and runtime dispatch.

## Fresh environment observations

The default executable is Godot `4.7.2.stable.official.ed1daf0bf`, which is not the
candidate's pinned `4.7.stable.official.5b4e0cb0f`. A separately retained exact
executable reports the required revision and SHA-256
`f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`;
the lock must still be checked before use.

The permitted CUA Linux desktop can launch a terminal and the installed Godot
project manager. The desktop and execution tools share the source workspace.
The first Sky pointer actions reported an unavailable AT-SPI provider for the
Godot 4.7.2 manager. A window-bound CUA terminal input worked. No CyberSand
Workbench or physical-platform acceptance had occurred at this checkpoint.

## Initial test plan

1. Verify exact engine and native/Rapier bytes against the pinned source.
2. Launch the ordinary Workbench using an isolated disposable application profile.
3. Execute first-session, painting/history, generated install/reopen, Direct JSON,
   Save/Restore/Flatten and representative laboratory navigation.
4. Render README, portal and practical guides at desktop/narrow widths; compare
   screenshots and control labels with source, then correct demonstrated friction.
5. Record per-document review depth and per-workflow outcome, including genuine
   external limits and failures. A source check is not a graphical pass.
