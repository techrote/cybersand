---
title: PLAY-LIFE-009 automatic same-owner pause and input qualification
status: Planned
document-kind: audit
scope: Bounded headless native and Rapier behavior, not graphical startup or physical-device acceptance
canonical-for: []
last-reviewed: 2026-10-31
related-documents: [../systems/player-control-playground.md, ../operations/cybersand-codex-development-handover.md, ../reference/status-and-roadmap.md]
---

# PLAY-LIFE-009 automatic same-owner pause and input

## Authority and independent scope

The owner deferred Windows shader/compiler/cache/decomposition work pending major
shader reworks and requested continued PLAY engineering. The
[manual ownership registration](https://github.com/techrote/cybersand/issues/305#issuecomment-6538946653)
and [shader deferral](https://github.com/techrote/cybersand/issues/309#issuecomment-6538949034)
preserve all existing failures, acceptance contracts and merge holds.

This branch begins directly at accepted main
`0bf28d5760aed989a79386de03ef4fc6171fef42`, not at held #308 or #310. It changes
no production scene, shader, native code, physics/solver default, runtime pin,
scientific fixture or training input. #312 stays frozen, #316 remains draft,
and Scheduswarm remains paused. No existing mandatory workflow is changed.

## Registered behavior contract

Five independent processes exercise the original authored course and actual
SetP rigs: stuntbuggy, trialsbike, acrobat, arcadelander and jetbarrel. Each uses
`main.tscn`, the existing exclusive `CyberSimulationWorker`, native World and
main-thread Rapier. Only OS focus is substituted in the positive path; keyboard
events are injected through production Input dispatch. Rendering and physical
devices are not qualified by this headless fixture.

The original Main `_process` and `_physics_process` run automatically. An observer
records the admitted command immediately before the real production Rapier step
and its resulting copied action, completed tick and bridge step afterward. No
manual `_physics_process`, bridge step or pose injection is used. The negative
phase suppresses only input publication while actual bodies keep ticking; that
phase must remain neutral and cannot qualify input application.

The positive sequence admits nonneutral input, populates real press/release
edges, toggles P, observes a new native paused publication, and then verifies at
least 350 milliseconds and eight automatic physics callbacks of quiescence.
Native tick, Rapier tick/step, body pose and lap tick remain unchanged; Main
callbacks continue. Worker/session/bridge/run/actor epoch/World generation remain
identical. Resume while the old movement key remains held must stay neutral and
require release-to-rearm. A still-in-lease pre-pause command is rejected with
`observation_not_issued`, not simply expiry. A fresh post-release command must
then reach a completed step and native ticks must resume. Shutdown must destroy
the actor session and join the worker.

Each operation is bounded at 15 seconds, each fixture at 150 seconds, each
external case at the existing 180 seconds, and import at 240 seconds. All five
first attempts are retained, even after a case fails. No automatic retry or
skipped-row success is permitted. The capture has a 512-observation maximum.

## Source and evidence contracts

The scoped [workflow](../../.github/workflows/play-life009.yml) executes actual
GitHub-hosted Windows Server 2022 and Ubuntu 24.04. It checks out the exact PR
head, uses the pinned official Godot 4.7 archive and authentic LFS native/Rapier
runtimes, and rejects production-path drift from its registered base. Full
execution-input hashes and runtime identities are checked before and after.
The original process result is written before JSON parsing and postflight.
Original logs, reports, source archive and SHA-256 file inventory are retained.
The original source archive contains only `git archive HEAD`, never credentials,
`.git` state, generated cache files or rewritten evidence.

The [strict reducer](../../tools/play/life009_contract.py) recomputes identity,
clock, input, pause and teardown checks from original observations. Its
[adverse tests](../../tools/play/test_life009_contract.py) cover missing/duplicate
rigs and markers, silent input loss, false clock-only success, owner replacement,
paused drift, invalid old authority, held input, capture overflow, late deadlines,
failed cleanup and unsupported graphical qualification claims. Synthetic unit
fixtures are explicitly not engine evidence.

## Current checkpoint

**Implemented but awaiting actual hosted execution:** fixture, verifier, original
process retention and branch-scoped workflow. Eight local verifier test methods,
including multiple adverse subcases, pass normally and with Python optimization.
This does not establish a Godot parser pass, native/Rapier execution, Windows or
Linux runtime acceptance. Exact-head first results, any corrections, artifact
identities and residual limitations must be recorded before claiming completion.

This slice does not close #268/#269/#270/#263, the complete PACE input-tape gap,
physical devices or human feel. The deferred Windows startup gate remains red;
no accepted outcome here authorizes merging #308/#310.
