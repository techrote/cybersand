---
title: Repeatable flyer spawn and compact review controls
status: Current
document-kind: validation
scope: Developer room spawn admission, Burst input and compact UI; no response-law or gameplay acceptance
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [../systems/granular-review-flight-fleet.md, 2026-11-04-flight-review-controls.md]
---

# Repeatable flyer comparisons — 4 November 2026

## Source and authorisation

The owner requests a saved reset position, a Burst shortcut that preserves flyer
control and dense small controls for a1440p display. The isolated
codex/gcr-repeatable-flight-ui-20261104 branch starts at draftPR380 source
`dff9032397900a2c411c6d7b27ac89ef340d7063`; fetched current main remains
`7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1`. The dirty C:/khybersand checkout
and running earlier review projects are preserved. The recoverable committed
checkpoint and final exact-head results are recorded in the successor draft PR.
No PR is merged or promoted and no owner judgement is inferred.

All88 production-native inputs and the retained Windows/Linux runtime artifacts
remain matched to compiled`856c49371b37b3921bf859a67a883336252134ee`. The pinned
engine is Godot4.7.stable.official.5b4e0cb0f, Rapier addon0.35.2/core0.35.1.
Native cells, main-thread Rapier, bridge, worker and response owners are unchanged.
No native rebuild, core/sanitizer execution, friction/load/material/correction
change, sleep or physics efficacy acceptance is claimed by this UI follow-up.

## Changed contracts

- Fleet-only construction accepts a finite saved centre with the complete level
  hull inside the painting-room inner walls. Ordinary actor admission retains
  its old arena. Static hard rectangles used to seed the room are shared with
  the frontend's spawn refusal, preventing duplicated platform geometry.
- X/Y or **Use flyer** saves a centre at0.01-cell authoring precision without
  changing the live pose. R, craft changes and response/property Apply construct
  a fresh upright stationary flyer there. The value survives response Defaults
  and isolated-fixture round trips. **Default spawn** is separate. Persistence
  lasts for the room scene, not a disk save or F2/process restart.
- Invalid points and unsuitable larger hulls refuse construction while retaining
  the old owner. Granular overlap remains available for exploratory setups;
  neither captured position nor relocation proves material resistance.
- B queues one live burst per non-echo key press. It is suppressed during numeric
  editing, OS focus loss and isolated fixtures. Paused requests remain pending
  until an actual owner step. Button clicks outside the game no longer inherit
  the generic scene's unconditional pilot cancellation; editor focus immediately
  cancels and requires neutral rearm. Pause/reset/focus lifetimes remain intact.
- Full-width canvas and wrapping12px/24px toolbars replace the wide inherited
  craft sidebar and long stacked explanations. Details starts collapsed; primary
  fields, source counts and palette remain visible.

The canonical [fleet guide](../systems/granular-review-flight-fleet.md#saved-spawn-burst-key-and-compact-comparison-controls)
owns current controls. Configuration and interfaces document the optional
construction argument and unchanged action/worker ABI. Handover, index, roadmap
and the existing GCRFLIGHT01 query are updated together. No ADR, dependency,
scientific programme or production-default change is needed.

## Original preflight executions and preserved failures

`build/spawn-preflight-01` records actual Windows846 spawn assertions against
parentdff903 plus the identified runtime/arena/test delta. Every flyer, all four
responses, representative positions outside the old arena, reset lifetime and
invalid-owner preservation are covered. It is not relabelled as the later UI run.

`build/agent-repeatable-preflight-03` records Windows and Linux/WSL actual imports
and133 scene/input/layout assertions per platform, at parentdff903 plus its
authenticated local delta. Source hashes, native88, runtime bytes, commands,
300s watchdogs and original log hashes are retained. It predates the subsequent
0.01-cell capture correction and four additional precision regressions. An
independent review also identifies pending SpinBox text being read before editor
commit when Reset or a craft button is clicked. The frontend now explicitly
applies/releases the editor before reading coordinates; five actual LineEdit
regressions cover that path. The resulting142-check UI suite requires the final
exact-head run. The [compact original preflight summary](repeatable-flight-ui-2026-11-04/preflight-summary.json)
retains actual command/log hashes and changed inputs without a large raw corpus.

The first two scene preflights fail one synthetic mouse assertion. The test sent
canvas coordinates through Input.parse_input_event after resizing the window;
the project scale transformed the pointer by0.75 and it missed Burst. A retained
probe identifies the unrelated hovered container and zero button presses. The
corrected fixture uses Viewport.push_input(event,true), exercising the real GUI
dispatch in viewport coordinates. The original failed logs are retained; this
is a test-coordinate failure, not evidence that the actual Burst callback failed.

Both passing layout observations use real Godot containers. At2560×1440 the
canvas is Rect2(8,191,2544,1203); at1280×720 it is Rect2(8,191,1264,483).
Primary controls remain visible and outside the canvas. These measurements
cover scene layout; they are not target-display/GPU or human feel acceptance.
On-screen Windows inspection of the separately labelled preflight project
confirms the dense toolbars and visible map floor. An attempted subsequent
click was stopped by detected user input; no click-result claim follows.

## Final qualification boundary

The first committed-head run at55d52b77 passes all new controls on both platforms,
then exposes a compatibility regression in the expanded retained RFT fleet test:
its four-key options omit optional thrust/torque/boost values. The dense toolbar
used a required dictionary lookup where the previous controls supplied defaults.
An older sampled-port test also omits optional boost. The correction restores
defaulted reads in both places without changing authored defaults or physics.
The two error-stalled test processes are explicitly stopped after preserving
their script-error logs; their receipts are failures, not watchdog passes. The
original run and [compact failure manifest](repeatable-flight-ui-2026-11-04/failed-head-summary.json)
remain retained in build/repeatable-final-head-01. The corrected head requires a
fresh complete run; no successful prefix is relabelled as final qualification.

`python tools/experiments/run_gcr_powder_review.py --output build/repeatable-final-head-02`
runs19 host suites plus one fresh import per platform, including the two new
spawn/UI suites and retained alignment, boost, source, actor arena, review fleet,
crash-room, canned powder, event controls, bridge/freshness and navigation gates.
The committed head, immutable project inputs and actual runtime hashes are
checked before/after; every process has a300s timeout. Final execution receipts
and exact resulting head belong to the draft PR and ignored local run directory,
not an assertion that these later checks had already passed at preflight time.

Run local documentation, historical M11, materialized repository provenance,
frozen/PLAY retrieval and whitespace controls independently. Preserve the
inherited shadow-compatibility failure for world.cpp, world_inertial.inc and
world_pressure.inc; no protected lock/checker is refreshed. Draft-skipped hosted
Native/GDExtension jobs remain skips. Full source/hosted results, limitations and
source-labelled playable instructions must be recorded before handoff.
