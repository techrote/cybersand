---
title: ObjectShard M4 performance recovery and optional recording
status: Current
document-kind: audit
scope: Recovery of earlier renderer evidence, opt-in instrumentation repair and source-bound development qualification; physical Windows/NVIDIA acceptance remains open
last-reviewed: 2026-11-25
related-documents: [2026-11-24-objectshard-m4-render-decision.md, ../research/objectshard-m4-workbench.md, ../operations/objectshard-workbench-playtest.md]
---

# ObjectShard M4 performance recovery and optional recording

**Physical performance acceptance remains HOLD.** This recovery preserves the
earlier source-bound [render decision](2026-11-24-objectshard-m4-render-decision.md),
including its slow paused control, active-body observations and the invalid
attempts. No earlier failure is relabelled as a successful later run.

## Recovered scope and remaining cost

The accepted recovery intake is application source
`f5b7ac7e651356c9f6d5657dfb0cb9d60111be81`, tree
`fcbb55a7c80a9d1a887e4e0336491e07c3ae01db`. The original local completion tree
is identical at `66365c4c20b4331c004810b4235893315a623525`. The existing
117-entry native input map matches this source exactly. The recovered sealed
Linux development runtime is SHA-256
`0dfe2a63e69062a44a4b7eb01ea65a4aa9c210f096f2413344482b7b051a68ae`, built
originally at `ccdfde97c279d809eafbb6e74b880d14cfb2f60e`. Reuse preserves that
build identity; it is not a new pinned hosted build.

The existing mixed headless profile's 1,080 compact snapshots over 180 ticks
cost 1.533 seconds of a 12.365-second window. That whole stage is a 12.4% upper
bound, not isolated payload-digest cost or an achieved speedup. Fresh shape and
accounting marshalling remain candidates for a separate measured change.
Material-revision-only digest caching is invalid because reaction due times
change independently. Sparse composition, native receipt reuse, unchanged
geometry and readiness suppression are preserved.

The original rendered tower capture was visually inspected: it shows actual
ordinary Workbench controls, coherent mixed Wood/Brick material rotated against
the raised native footing, and the existing reference barrel in the same
canvas. A still image establishes neither motion continuity nor displayed FPS.

## Optional recording correction

Previously, the ordinary ObjectShard flag and Structures enable action started
full bounded event recording automatically. That imposed event construction
and observation callbacks on every evaluator session, contrary to the requested
optional diagnostic mode. The corrected default is recording off. The new
Structures checkbox and separate `--objectshard-diagnostics` flag opt in.

Stopping preserves the last bounded recording for Save diagnostics and removes
its post-draw callback. Starting another recording clears its samples and
advances the recording epoch. Native/Rapier barriers, active body counts,
chemistry, actor effects and publication identity are unchanged. Rich profiles
explicitly enable observation and require nonempty timing/progression evidence.
Light sampling independently omits per-callback physics readback; its default
disables recording, while a matched tower counterpart explicitly enables it.
Every recording-enabled profile must contain actual timing events and native
delivery intervals regardless of its sampling mode.

This is a removal of unnecessary default instrumentation, not a claimed fix for
the owner's severe frame-rate problem. Its cost must be measured using matched
instrumentation-on/off workloads. The prior slow paused window already disabled
the latency probe, so this correction cannot explain that observation.

## Development qualification and retained negatives

The initial ordinary checkbox fixture passed 35 of 36 checks. Its one failure
compared a JSON-decoded dictionary (integral numbers decoded as floating point)
directly with its original GDScript Variant dictionary. The native progression,
disabled-recording, real checkbox, retained capture and saved file checks had
all succeeded. The repaired test compares both values through the same JSON
serialization boundary; it does not loosen a timing or physics requirement.
That replay passed all 36 checks with zero display-identity discrepancies in
340 headless callback observations in the original failed attempt. Subsequent
source-bound results are recorded with their own identities below.

Local graphical execution is unavailable in this recovery environment: there
is no display, the X server cannot create its listening socket under the
execution policy, and the native desktop tool reports runtime unavailable.
The retained original graphical evidence and the required replacement hosted
graphical campaign retain separate source and renderer scopes. A headless
run here is never reported as graphical acceptance.

## Additive comparison inventory

The replacement qualifier preserves all five scenes, overview/zoom profiles,
the original four enabled pause/play renderer controls, and both existing light
profiles. It adds an ordinary tower control launched without the ObjectShard
flag, a matched tower light profile with recording enabled, and checkbox/CLI
recording cases. In the rendered lane, both recording cases use the real
renderer and require actual post-draw observations.

The disabled control authors the same native material rectangles and ordinary
reference actor on the same 512 canvas, with the same overview camera. It
measures paused and running windows for at least 12 seconds each, proves that
no mutable body or native attachment exists, and requires actual ordinary
native/Rapier progression only in the running window. Its report records the
authored rectangle digest and exact view rectangle; the rendered qualifier
requires these inputs to match the enabled control. It does not substitute a
blank scene or label headless callbacks as rendered submissions.

Development executions of the added disabled control passed 21 checks and the
light recording-on tower completed 180 native ticks and 720 real Rapier
segments with 512 retained timing events. The added validator tests reject
missing recording observations, accidental attachment, missing native/physical
progression and headless/renderer scope substitution. These development runs
are preparation for the fresh committed-source hosted campaign, not release
qualification or owner GPU performance acceptance.

## Qualification impact

The repair changes Main, Structures UI, the optional probe and profile/test
scripts. Native source and binaries are unchanged. Focused native-input reuse
is legitimate only after the full map comparison; changed application inputs
require fresh actual Linux and Windows Workbench execution. The registered
inventory is additive: it retains every prior case and adds actual checkbox
and CLI recording executions. Physical NVIDIA/monitor acceptance remains the
owner's gate after the portable package itself passes qualification.
