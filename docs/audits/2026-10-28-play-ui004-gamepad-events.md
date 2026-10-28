---
title: PLAY-UI-004 shared-course gamepad event candidate
status: Planned
document-kind: evidence
scope: Course-only button event forwarding, bounded physical-session edge regression, source identities and explicit hardware/full-host exclusions
canonical-for: []
last-reviewed: 2026-10-28
related-documents: [../systems/player-control-playground.md, ../architecture/rendering-and-gameplay-bridges.md, ../architecture/data-ownership-and-lifetimes.md, ../operations/local-build-and-validation.md]
---

# PLAY-UI-004 gamepad event candidate — 2026-10-28

This is an implementation and test candidate for #268, not an executed pass or
closure of the PLAY epic #263. It is based on accepted main
`c9ebe39c6cab086b7f7207ee3d80a6de2cb21f59` and deliberately does not mutate the
already-tested lap/HUD PR #280 or the stacked lifecycle PR #284. Branch:
`play-268-gamepad-event-edges-20261028`.

## Source-discovered gap

The standalone [playground](../../godot/scripts/player_playground.gd) submits
both key and gamepad button events before a physical sample. In accepted main,
the [shared desktop](../../godot/scripts/main.gd) polls the same
[local sampler](../../godot/scripts/player_playground_input.gd), and explicitly
forwards key events, but has no `InputEventJoypadButton` forwarding callback.
A gamepad press and release between two physical polls can therefore leave only
neutral state at the next poll. A session capable of retaining edges cannot
retain events never submitted to it. This is source reasoning, not a claim
that a physical controller was tested in this authoring environment.

## Small ownership-preserving correction

The new [event bridge](../../godot/scripts/playable_course_gamepad_events.gd)
is one ordinary main-thread Node attached to
[the existing desktop scene](../../godot/main.tscn). It owns no World, actor,
Rapier object, timer, simulation clock, lease, queue or worker. It forwards only
unhandled A/B/X events from the first connected joypad and only while the
parent's existing `_playable_course_controls_active()` predicate is true.

Every admitted event invokes the original `publish_actor_keyboard_input()`.
That original path remains responsible for the course sampler, focus/pause/
terrain/reset/fault refusal, neutral rearm, equipment/pointer identity, producer
and actor epoch, sequence and bounded button FIFO. UI Controls retain their
normal opportunity to consume events before gameplay. Other devices, unmapped
buttons, generic maps, nonhuman producers and specialist configurations are
not redirected. Analog movement/trim polling and gamepad Start are outside
this patch; standalone controls retain their existing behavior.

Source checkpoints:

- bridge implementation: `823a2d9bf3845089103afb17f5895ac4821e8c2a`;
- normal scene wiring: `616d43b0a70547522065b1727cff3eccb3704dd9`;
- focused regression: `e521f4a54a23c74ba06c01902fee586bd316330f`;
- canonical gamepad section and exact unrelated-text restoration:
  `1c642e243c2605ec0fd7bed36b31b7c4783d6546` then
  `f8d7c82fbd34417127451942cf6ad70c6b74d147`.

The canonical [player control contract](../systems/player-control-playground.md)
labels this slice as a candidate. Its previous source-bound camera/lap status
is left to PR #280's separate qualification update rather than overwriting that
branch's independently reviewed claims. When both slices land, preserve both
scene additions and both documentation sections in a normal integration.

## Focused fixture and honest boundaries

[`test_play_ui004_gamepad_events.gd`](../../godot/tests/test_play_ui004_gamepad_events.gd)
uses the real SceneTree/Viewport `Input.parse_input_event` route, real Input
button state, the production event bridge and `CyberPlayerPlaygroundInput`
action mapping, and a real human Acrobat `CyberPhysicalActorSession` with actual
Rapier steps. The fixture checks the ordinary scene includes exactly one bridge.

Two apparatus seams are explicit: a selected-device override for a synthetic,
unconnected device index, and a small test host publisher replacing desktop
hardware enumeration/focus setup. It does not pretend the host seam is the
production `main.gd` publisher. It cannot qualify real USB/Bluetooth controllers,
complete desktop GUI focus routing, disconnect/reconnect, all five rigs' gamepad
feel, rendered FPS, async responsiveness or native performance.

For each mapped A/B/X action, the fixture requires the actual session FIFO to
contain exactly an ordered press/release pair before any physics tick. Two real
Rapier/session steps must consume press then release separately. The fixture
also checks another device and unmapped button do not publish; an inactive
course does not intercept; a host refusal cancels real queued edges and advances
the control generation; held input cannot bypass neutral rearm; and pause
cancellation leaves no queued intent. No command-counter-only substitute is
accepted for edge preservation.

A matched negative subclass overrides only event forwarding. The same press/
release pair followed by polling then yields no queued edge, demonstrating the
specific loss addressed by the adapter. Cleanup releases synthetic button state
and closes all physical bodies. No native cellular World is constructed by this
focused fixture; full desktop composition remains covered by the unchanged
actual-host regressions in the complete Windows/Linux matrix.

## Qualification gates and preserved work

At source publication, no local Godot binary or complete repository checkout
was available; a source archive retrieval attempt was unsuccessful. No parser,
engine, hardware or assertion pass is claimed. Required before merge:

1. independent exact-head review of the bridge, Viewport test path, explicit
   apparatus limits and scene attachment;
2. exact-head Documentation/provenance and applicable Native/GDExtension/Godot
   Windows/Linux workflows, with no diagnostic, timeout or checkout drift;
3. `PLAY_UI004_RESULT` readback with both real queued-edge consumption and the
   poll-only negative control, plus unchanged existing course/liquid fixtures;
4. final accepted-main integration and a fresh review of any combined source.

The existing automatic `test_*.gd` discovery supplies the ordinary finite case
budget. No CI-provider routing, timeout, skip, retry policy or assertion filter
changes. No native implementation/ABI/runtime publication, material law, solver
default or construction-time per-material policy is modified. Requested/applied
liquid receipts, Water `pressure_flow_v1` and unsupported-route refusal remain
inherited unchanged. Scientific physics, 4LY and NPC-training fixtures remain
independent. #271 stays deferred and #265 stays closed. #266 performance, #269
full lifecycle/stall campaigns and #270 manual release qualification stay open.
