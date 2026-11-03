---
title: PLAY desktop physical and human qualification packet
status: Current
document-kind: guide
scope: Source-pinned preparation and manual recording for the shared desktop host; preparation is not physical, graphical or human acceptance
canonical-for: []
last-reviewed: 2026-10-31
related-documents: [local-build-and-validation.md, github-development-and-release.md, ../systems/player-control-playground.md]
---

# PLAY desktop physical and human qualification

Use this packet for [#270](https://github.com/techrote/cybersand/issues/270) on
the actual Windows or Linux desktop. Its generator checks identity and writes
a checklist; it never launches Godot, probes its version, imports the project,
injects input or records a physical pass. The five mechanical rigs use the
existing shared `main.tscn`, native worker and main-thread Rapier.

## Prepare the exact source

Use a dedicated clean checkout at the full commit SHA recorded by the reviewed
candidate. Preserve local changes before switching. Materialize all retained
runtime objects with the existing `git lfs pull` / `git lfs fsck` procedure.
Keep the official pinned Godot archive and its extracted executable available.
The [desktop build guide](local-build-and-validation.md#shared-play-session-and-owner-qualification)
owns acquisition and import; this packet does not rebuild or replace runtimes.

On Windows PowerShell, replace the source and local paths:

```powershell
$Expected = 'FULL_40_CHARACTER_REVIEWED_COMMIT_SHA'
python tools/play/create_manual_packet.py --expected-sha $Expected `
  --godot 'C:\Godot47\Godot_v4.7-stable_win64.exe' `
  --godot-archive 'C:\Downloads\Godot_v4.7-stable_win64.exe.zip' `
  --output 'C:\CyberSand-evidence\play-manual-first'
```

On Linux:

```bash
python3 tools/play/create_manual_packet.py \
  --expected-sha FULL_40_CHARACTER_REVIEWED_COMMIT_SHA \
  --godot /opt/godot/Godot_v4.7-stable_linux.x86_64 \
  --godot-archive /tmp/Godot_v4.7-stable_linux.x86_64.zip \
  --output /tmp/cybersand-play-manual-first
```

The generator refuses the wrong or dirty source, untracked files, an existing
output directory, incomplete native source inventory, stale/unmaterialized
runtime bytes, or an unpinned/mismatched engine. It runs the existing full
`check_repository.py --require-materialized` logic unchanged. Official archive
hashes authenticate the executable bytes; Windows also checks the console
companion used by the existing launcher. No weaker provenance mode is provided.

Output belongs outside the checkout and contains local paths/host information.
`IDENTITY.json` pins commit/tree, engine and selected native/Rapier identities;
`PRECHECK.json` retains the repository gate; `CHECKLIST.md` explains the route;
`RESULTS.csv` starts with **51 untested cases**. The immutable-file manifest
protects the checklist and launch instructions while permitting human edits to
the result sheet. Preserve each attempt separately.

Complete feasible rig checks within the same engine process. A later preflight
deliberately refuses newly generated untracked metadata, including `.gd.uid`
files. Retain the first launch/import log and `git status` output; preserve that
checkout as evidence and prepare a fresh dedicated checkout and packet at the
same reviewed SHA. If an editor import is required, record it separately under
the [source execution policy](ci-execution-and-performance.md) import watchdog
(1,200 seconds at the default scale) and reconcile its generated files before claiming a clean
source. This packet does not delete metadata, ignore changes or promise an
automatic relaunch after import.

## Launch the shared session

Run the generated `launch.ps1` in PowerShell, or `bash launch.sh` on Linux.
The script rechecks exact source/engine/runtime identity before the user-requested
launch and retains a new console log. It uses the existing Windows desktop
launcher or Linux `Godot --path godot` route. Select **Play session — shared
desktop course, five mechanical players and solver choices**. The separate
**Player playground** button and `--player-playground` argument open a different
scene and do not qualify this asynchronous shared host.

Choose **Player Playground**, a player, **Keyboard + standard gamepad**,
**Four-checkpoint lap**, **Close follow** and **Current** policy. Click **Build
selected session**, wait for the actual applied actor/policy, release controls,
then **Play / resume**. Use the in-host **Play session** button to change rigs.
Unsubmitted choices do not become applied state.

| Player dropdown / rig | Primary keyboard sequence |
|---|---|
| Loose Cannon / `stuntbuggy` | W/S drive/reverse; A/D or Q/E lean; Space hops on support; Shift brakes; hold C for recovery. |
| Trials Rat / `trialsbike` | W/S throttle/reverse; A/D or Q/E lean; hold Space on support, release to hop; Shift brakes; hold C for recovery. |
| Afterimage / `acrobat` | A/D run; Space jump/double jump; hold Shift to slide, tap to roll; Shift+Space bullet jump with mouse aim; Space jump-cancels a roll; C brakes, hold airborne to glide. |
| Vector Rush / `arcadelander` | W/Space body-axis thrust; A/D or Q/E rotate; S reverse thrust; Shift airbrakes; tap C toggles damped/coast flight. |
| Barrel Rocket / `jetbarrel` | W/Space body-axis jet; A/D or Q/E rotate; S reverse thrust; Shift brakes; hold C for upright assistance. |

Arrows duplicate WASD. The first connected standard gamepad supplies left-stick
movement, A/Space, B/Shift, X/C and shoulders/Q/E. **P**, **Escape**, or the
selected pad's **Start** pause/resume,
**R** resets the applied session and **F** (the letter) changes camera. Open
**Play session** and click **Return to launcher**; F2 remains an optional shortcut.
The same panel provides visible **Play / resume** and **Restart applied session**
buttons. No function key is required for pause, camera, reset or launcher return.
Checkpoint rings show the next target, future gates and completed gates. Optional
F3 details distinguish requested worker capacity, sampled task participants,
sample age and publication coalescing; they do not measure displayed FPS.
The shared selector does not use standalone 1–7/Tab switching.
Exercise each pause route separately; a UI modal must consume these controls
instead of changing gameplay state.

## Execute the physical and human checks

For every rig, the result sheet covers actual actor/terrain pixels, natural
keyboard and gamepad action sequences, pause with held-input release/rearm,
real OS focus loss/recovery, modal ownership, selected-controller unplug/replug,
follow/overview, actual ordered checkpoint/lap traversal, repeated reset and
return to the launcher. It also covers keyboard-only/free-play selection,
supported policy reconstruction and the UI's disabled unsupported-family entries,
an unrelated second
controller, observed fault/recovery and human responsiveness.

Focus loss cancels input; momentum and native materials may continue. Pause
must stop stepping. A paused or replaced generation must never resume a held
old action. Record missed/repeated actions and stalls without homogenizing
the rigs' deliberate mechanical differences. Screenshot requested family/variant
and applied text; copy the **applied native policy_hash** and **construction
receipt_hash** from the tooltip. There is no requested-policy hash in that UI.
Select Oil and inspect the disabled pressure-family entry and its refusal reason;
do not inject an unsupported request. Actual native transactional refusal is
separately exercised by UI005/LIFE002 automation. Do not manufacture faults
or use pose/input injection to complete this manual checklist.

Keep the **30s Main acknowledgement, 180s graphical case, 240s import and
applicable 15s operation/150s fixture limits**. Record the first late/failed
startup as failed, including on the owner-deferred Windows shader path.
Record launch-to-launcher and launcher-to-Main visibility separately. Time
**Build selected session** to visible applied actor/terrain readiness separately
as a manual display observation. The automated construction acknowledgement
starts at Build and ends at the first completed production Main callback with
the selected actor/native identity, body and terrain ready; its30s bound is not
launcher reading time or a delayed coroutine poll. Manual display timing does
not replace that source-bound callback receipt.
Later interaction is a separately labelled observation; it does not erase
that failure or justify a relaxed deadline. This packet launches no import,
warmup, shader investigation or automatic retry.

## Record and report

Set each executed CSV row to `pass` or `fail`; unavailable hardware, incomplete
traversal or unperformed work remains `untested`. Enter operator, UTC time,
observations and relative evidence filenames. Record keyboard/controller model,
mapping and connection, plus GPU/driver and display resolution/refresh locally.
Keep console logs and representative screenshots/video, exact fault text and
the shortest reproduction. Preserve first failures when attempting recovery.

Review local host details before sharing a copy of the packet and evidence.
Do not commit machine-specific results. The generator does not interpret human
results or close issues. Native ticks, submission cadence, actual displayed
performance, physical-device compatibility and subjective feel remain separate
claims; [#270](https://github.com/techrote/cybersand/issues/270) and the
[PLAY epic](https://github.com/techrote/cybersand/issues/263) require their
remaining acceptance evidence and review.
