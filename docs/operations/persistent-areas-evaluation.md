---
title: Persistent areas desktop evaluation
status: Current
document-kind: runbook
scope: Opt-in GEN-006 three-area controls, Windows evaluation, isolated profiles, expected observations and failure capture
canonical-for: [persistent-areas-owner-evaluation]
last-reviewed: 2026-11-27
related-documents: [../systems/persistent-authored-areas.md, ../audits/2026-11-21-gen006-persistent-areas.md, ../reference/level-saves-and-replay.md]
---

# Persistent areas desktop evaluation

This guide covers the original experimental three-area implementation of [#591](https://github.com/techrote/cybersand/issues/591).
It keeps three authored native areas and their completed game time. General
streaming, arbitrary chunk eviction, cross-area fluids and universal actor
persistence in [#194](https://github.com/techrote/cybersand/issues/194) remain
outside this milestone. The [qualification ledger](../audits/2026-11-21-gen006-persistent-areas.md)
records actual tested source, platform and package identities; this procedure
does not itself establish a platform PASS.

For the integrated Workbench launcher or the standalone RAMCACHE evaluator from [#745](https://github.com/techrote/cybersand/pull/745),
use the [RAM cache owner guide](persistent-area-ramcache-evaluation.md). It covers profile locations, cache budgets,
strict and deferred durability, predictive preparation and failed-area recovery. The November 21 ledger records the original #725 measurements.

## Launch and profile isolation

Extract the complete Windows evaluator into a writable folder. Double-click
**Open Persistent Areas.cmd**. The package includes its pinned Godot 4.7,
source-matched native DLL, Rapier and required runtime files. Its own
`userdata/persistent-profile` holds the three areas. **Open Workbench.cmd** opens
the ordinary interactive Workbench separately. Do not copy an old profile into
a different evaluator: this first version binds the profile to its native
runtime digest and refuses incompatible state.

From a qualified source checkout, launch the normal application with
`godot --path godot -- --persistent-areas`, or select **Persistent areas ·
experimental** in the launcher. `--persistent-profile=/absolute/path` selects
an isolated profile. `--persistent-start-paused` is available for controlled
qualification; normal interactive startup runs the area.

## Owner walkthrough

1. Start **A · Industrial fire**. Observe actual native Fire/Smoke and changing
   combustible material. Pause with **Play / Pause [P]**, erase a recognisable
   part of the timber or paint a firebreak, then resume.
2. Select **B · Waterworks**. Watch Water and Sand change. Pause, erase part of
   the wooden gate or a terrace, paint a durable marker, and resume.
3. Select **C · Foundry gallery**. Make a distinctive edit in the metal/glass
   structure. Allow its Sand to settle.
4. Return to A, then B. Confirm that destructive edits stay absent and placed
   material remains. The native worlds resume from their retained state;
   previously completed inactive intervals are not simulated twice.
5. Select a 5-, 30- or 120-second request and press **Simulate Ahead**. The
   operation first pays existing area debt, then credits actual completed future
   native ticks. Try **Cancel safely**. Read the completed amount and remainder.
6. Press **Save all areas**, close the application, and relaunch the same
   evaluator. Visit all three areas again. Their independent identities, edits,
   native continuation and accounted game time should remain.

The editor/camera is the traveller in this version. Actor creation, controller
transfer, host sources/equipment, and solver replacement are unsupported in the
persistent profile. The ordinary Workbench remains available for those tasks.
Existing Paint, Art, erasing and material-start Flatten retain their meanings in
the admitted actor-free profile. Undo history is visit-scoped; persistent native
state and explicit Empty edits are retained separately.

## Read time and progress accurately

**Game** is total completed game time; **Area** is this area's accounted time;
**Debt** is their difference. Real wall-clock absence adds no time. Travel and
Ahead have a 600-tick operation cap and a three-second native-work budget checked
between slices. Native slices admit at most 32 ticks and 100 ms checked between
complete ticks. A single native tick, storage, capture and restoration can add
latency; these are measured independently. A large request can complete only
partially. Remaining debt stays visible and can be paid by another bounded
operation. Unperformed requested future duration is not elapsed game time.

The loading overlay names capture, durable publication, restore, catch-up and
activation. Essential cancellation and details-close actions remain reachable
at the qualified 720p and 1080p window sizes. **Details / limits** shows profile,
session, per-area time, durable generation and supported-domain information.

**Save start** remains an authored starting-map save. **Save all areas** saves
the persistent native profile. **Save & Menu**, F2 and the window close action
attempt the same safe departure; a failed save leaves an explicit error and
retains the current World.

Crash recovery restores the last durably acknowledged checkpoint. Active edits
or ticks after it can be lost if the application is forcibly killed before
capture/publication completes. This prototype uses checkpoints, without an
always-on edit journal. Save before deliberately terminating the process.

The qualified Windows evaluator has a known responsiveness limitation: routine
travel took roughly 16 seconds on the hosted software-rendered runner, and its
first open recorded a 40.743-second maximum main-frame gap with no identified
cause. These measurements are not NVIDIA timings. Keep the initial launch
and transition delays in mind during owner evaluation; the qualification ledger
retains the complete performance evidence.

## Failure recovery and evidence

If a save, restore or identity check refuses, read the status and Details.
**Retry saved profile** reopens and validates the committed profile. A corrupt
current generation may offer **Recover previous save**; this is an explicit
rollback to the retained valid generation. The application does not silently
regenerate an area from its recipe. Keep a refused profile intact for diagnosis.

Close the application before moving or backing up its profile. Run
**Capture Failure Evidence.cmd** to collect the isolated saves, logs, package
identity and Windows/display-driver information into a local archive. Include
the selected area, action, visible clock/debt, and whether this was the first
launch or a restart when reporting an issue. The script does not upload files.

**Run Automated Smoke.cmd** performs real graphical creation and a new-process
reopen in a separate `smoke` profile. It preserves the interactive profile and
retains logs, JSON and PNG captures. `evaluation-manifest.json` binds original
package files; generated caches and new saves are additional files. A passing
software-rendered Windows runner does not establish physical Windows 11/NVIDIA
playfeel or display acceptance.
