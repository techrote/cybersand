---
title: Shared manual and Art authoring runbook
status: Current
document-kind: runbook
scope: Accepted generator, PAINT and Art workflow; native receipts, shared history, authored save and bounded verification
canonical-for: [integrated-paint-agent-workbench]
last-reviewed: 2026-11-24
related-documents: [workbench-first-session.md, workbench-art.md, workbench-painting-and-history.md, workbench-saving.md, ../systems/paint-editor-bounded-shapes.md, ../systems/workbench-direct-art-batches.md, ../systems/workbench-art-providers.md]
---

# Integrated PAINT and agent Shared Workbench

Human painting and Art drawing use the ordinary accepted Workbench, its native
World and one ordered edit history. Start with [first launch](getting-started.md)
and [first session](workbench-first-session.md). This established path now serves
as a current integration runbook; its filename is retained for existing links.
The original source-matched packages, failures and merge holds remain historical
evidence at the end of this page.

## A small end-to-end authoring exercise

1. Open **Development workbench**. Stay paused and use a blank canvas, or install
   a small completed native preview through **New from generator…**.
2. In Paint mode, choose Hard Wall, draw a short rectangle, then use Eraser to
   open a gap. Select the result, **Copy**, and **Paste** a second instance.
3. Open **Art batches**, select **Direct JSON**, and use the
   [small rectangle/disc example](workbench-art.md#draw-without-a-model). Choose
   a clear work area: ordinary Art overwrites only existing Empty/Hard Wall,
   with body/source/protected-area checks applied separately.
4. Wait for the terminal native result. Inspect actual changed/excluded counts.
   **Queued** alone does not establish that a cell changed.
5. Make another human edit. Use **Undo** twice and **Redo** twice. The latest
   human edit is reached before the preceding Art drawing; the Art panel and
   Paint row address the same timeline.
6. Enter a unique name in the painting row and **Save start [Ctrl+S]**. Exit,
   reopen and **Load start**. For a generated start, wait for the source-verified
   preview and confirm **Install into workbench**. Check the authored geometry
   and spawns, then make a new edit. A reopened start has no old in-memory Undo stack.

This procedure uses no paid model request. It was source-checked for the current
documentation baseline; no fresh interactive graphical execution is claimed.
The [Art guide](workbench-art.md) separately covers provider configuration,
session conversation, Stop versus hiding, and private traffic.

## Shared agent and manual Undo/Redo — current implementation

Native-confirmed changes enter one chronological timeline. Adjacent bounded
parts of a direct batch or model submission form one history action. A human
edit between chunks closes that group and stays separate. Undo cannot skip the
later human work to reverse the earlier agent submission.

After **Stop**, wait for native execution, deferred human gestures, result
recording, image capture and provider/scheduled-turn activity to settle. Undo
then targets the confirmed prefix; the cancelled suffix has no history entry.
History retains at most 32 parts and 1,048,576 cells, with at most 262,144 cells
per part. An evicted prefix is labelled **Agent drawing (retained tail)**.

Native generation/revision/tick and expected stored source materials fence each
operation. Simulation, World replacement and unrecorded mutations invalidate
unsafe history. Undo reconstructs material edits; it does not roll back motion,
temperature or an evolved simulation tick. See the
[PAINT contract](../systems/paint-editor-bounded-shapes.md#undo-and-authored-start-persistence).

## Native authority and shared ordering

Both interfaces require the native `stored_material_at` binding and explicitly
check transient rigid-body occupancy. Stored Empty beneath a body is not editing
permission. Human PAINT admits the loaded native material catalogue; ordinary
Art has its selected destination palette plus the narrower Empty/Hard Wall
source policy. Neither inherits the other's permissions.

The worker's mutation slot stays occupied during pending commands, executing
work and unconsumed receipts. Human gestures deferred between Art chunks retain
their original radius and receive completed, partial, refused or cancelled
outcomes. The next chunk waits until their authored record is settled.

Receipts include actual stored before/after IDs and requested, checked, changed,
unchanged, excluded and refused counts. Source replacement invalidates old
provider replies. Stop keeps confirmed-prefix accounting, not an assumption of
atomic rollback. A PAINT recovery hold also blocks new Art drawing.

## Preserved interfaces and persistence

The native authoring document records completed edits in order. **Save start**
refuses while shared mutation, replacement or receipt work remains unresolved.
These admission refusals occur before writing the named file; queued work cannot
be serialized as applied. Fragmented drawing can still exceed the 32,768-stamp or
1 MiB ordinary save envelope. The UI must report that refusal instead of dropping
history or silently truncating a start.

File replacement has a format-specific boundary. The material-baseline writer
uses native atomic replacement, including preservation of the previous named
file when replacement fails. Ordinary setup and generated-start writers use
Godot's rename operation; they do not establish that same guarantee for every
I/O failure. Use a new name to retain an earlier ordinary or generated start.
The [baseline qualification](gen008-flatten-qualification.md) records the
stronger material-baseline failure tests.

Generated starts retain their resolved recipe plus ordered edits; actors retain
authored settings/spawns and supported equipment. **Flatten / Bake History…** is
an accepted, separate explicit material-baseline operation. It retires previous
construction/Undo history but does not save automatically or capture exact
physical continuation. Use [the saving guide](workbench-saving.md) for recovery
and the distinction between current live World, authored baseline and disk file.

Art conversation is session-local after #727. Hiding the Art window retains the
same session; returning to the launcher ends it. A World Save is not a provider
conversation save. Native history does not require a restored traffic archive.

## Generator discovery and standalone installation

The generator discovers supported native profiles from the source or complete
installed resource layout. A package must carry those resources; a hidden Git
checkout is not a dependency of ordinary evaluator use. A missing profile is a
package/source-layout error, not permission to use a guessed substitute recipe.
The [generator guide](architectural-generator-playtest.md) covers current Genteks,
project controls, preview, installation and fresh-process reopen.

## Source and ownership

The canonical boundaries are
[shared authoring data](../architecture/shared-workbench-authoring-data.md),
[PAINT execution](../systems/paint-editor-bounded-shapes.md),
[direct Art drawing](../systems/workbench-direct-art-batches.md), and
[provider/session lifetime](../systems/workbench-art-providers.md).
This runbook routes their combined use; it does not add a second save format,
World, model controller or material-default policy.

## Qualification and reproducibility

Use the exact pinned Godot, matching native/Rapier libraries and an isolated user
profile. `test_workbench_combined_authoring.gd` exercises ordinary/generated
layout, manual/Art ordering, native material digests, Stop, save and a new-process
reopen. Its graphical mode requires a real framebuffer and refuses a headless
display. Provider fixture tests can use deterministic local HTTP without paid
inference; that establishes protocol/editor behavior, not model quality.

The existing qualification runner remains available for a scoped source-matched
campaign:

```powershell
python tools/ci/run_workbench_qualification.py regressions --godot C:/Godot47/Godot_v4.7-stable_win64_console.exe --project godot --evidence build/wb-integrated-regressions --paint
```

Inspect the [test-selection guide](testing-validation-and-replay.md) before
running a broad campaign. Routine documentation validation does not need a full
native matrix. Commands here are reproduction instructions; the documentation
mission did not execute the original complete hosted campaign again.

## Owner acceptance

For a new evaluator, verify the manifest and runtime identity, open the complete
package, perform the small exercise, test input/focus and Stop, and inspect a
fresh-process reopen. Report package/source, operating system, renderer, display
scale, exact work area and actual result. Hosted headless success, software
rendering, a package build and physical owner acceptance are distinct claims.
New implementation PRs follow current release policy; old candidate HOLD banners
do not change the status of accepted behavior.

### Evaluate the delivered package

A source-matched evaluator keeps its bundled project, executable, resources,
libraries, license notices and provenance together. Use its own supplied
launcher. Do not replace one DLL or copy a historical package's manifest over
another build. [Source recovery](source-checkpoint-and-recovery.md) explains
how to retain the evidence required for a useful report.

## Historical packages and failures

The original [baseline runbook](https://github.com/techrote/cybersand/blob/00cdb02f103265b6dc5224c68283e9a0c8cb449f/docs/operations/wb-art-paint-integrated-candidate.md)
retains every earlier package hash, test count, native digest, source identity,
Actions link and merge hold. In particular, `86d704a2` identifies the later
agent-Undo package; `d33c10e4` predates it; `0025bd94` and `0e73e926` retain earlier
packaging and integration evidence. None is relabelled as a fresh execution of
this documentation head. The
[installed/package audit](../audits/wb-art-paint-2026-11-12/agent-undo-hosted-installed.json),
[Native audit](../audits/wb-art-paint-2026-11-12/agent-undo-hosted-native.json) and
[Godot audit](../audits/wb-art-paint-2026-11-12/agent-undo-hosted-godot.json)
remain unchanged.

<a id="qualified-agent-undoredo-candidate--86d704a2"></a>
<a id="previous-qualified-package--d33c10e4-before-agent-undo"></a>
<a id="earlier-application-checkpoint-and-standalone-packaging-defect--0025bd94"></a>
<a id="final-hardening-and-evaluation--2026-11-12"></a>
<a id="previous-qualified-checkpoint-and-download--historical-0e73e926"></a>

These compatibility anchors lead to the retained historical package record above.
