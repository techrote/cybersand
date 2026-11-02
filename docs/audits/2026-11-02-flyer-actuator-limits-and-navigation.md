---
title: Flyer actuator limits, review navigation and burrowing observation
status: Current
document-kind: audit
scope: App-only actuator ceilings and desktop review routing; cropped owner observation remains noncausal evidence
canonical-for: []
last-reviewed: 2026-11-02
related-documents: [../systems/granular-review-flight-fleet.md, ../operations/physical-actor-programme.md, 2026-11-02-flyer-budget-playground.md]
---

# Flyer actuator and navigation follow-up

## Source and implementation

Owner requested thrust/torque limit controls, review-room return paths after F2,
and assessment of a cropped slow-burrowing recording. Application source
d86e4bba8ed759aac6fc7daa3636ab4bbe666531 adds optional thrust_multiplier and
torque_multiplier, each finite0..64 and omitted/default1, while preserving
existing four-key review callers. Exact authored fleet validation precedes
scaling the copied controller profile; ordinary catalogue validation is unchanged.

The developer panel stages both factors until Apply/reset, displays actual copied
controller caps, retains applied factors across craft and restores1. A zero thrust
cap suppresses the combined controller request, including its brake and hoverboard
compensation. Zero torque suppresses steering and leveling. Existing authored
acceleration/speed/effort targets and rig safety guards remain separate; increasing
a ceiling does not itself increase those targets. Per-call impulse limits remain
mass*100 and inertia*4, with extreme-motion safety braking above speed300 or
angular speed24. Gravity, contact response and damping remain independent.

Native source, compiled artifacts, material laws, friction/load/correction,
sample ownership, sleep and ordinary defaults are unchanged. Both platforms reuse
the existing SDK181a8257 with its unchanged88 compiled inputs. This source does
not requalify the historical88-case campaign or resolve its failed rest gates.

The desktop F2 launcher now places GRANULAR OWNER REVIEW / experimental near
the top, with Granular barrel comparison, Structural cut / support tests, and
Flyer playground + painting. They use existing scene replacement/teardown; Web
demo policy hides/refuses these unsupported desktop review routes. Existing
running projects do not hot-reload the new menu.

## Executed checks and owner launch

The [source-bound summary](gcr-rest-2026-11-02/flyer-actuator-summary.json) retains
commands,240-second per-process watchdogs, runtime identities and exact log hashes.
Fresh import plus all four final target tests pass on Windows and Linux:

- Fleet API/control test:1,155 checks per OS, including all seven craft, required
  four-key compatibility, omitted/default/zero/.01/64 limits, finite/bound refusal,
  actual backend zero-actuator delivery at moderate motion, hoverboard/brake/level,
  profile caps, mass/inertia, native budgets and reset retention.
- Seven-flyer UI test: real staged values reach profile caps, restore resets them,
  numeric editing does not select a craft, and retained painting/live tick checks.
- Navigation:23 checks per OS, actual Button signals, target owner readiness, F2
  return, freed old scenes/metadata, and Web policy refusal.
- Existing physical actor rig tests retain ordinary authoring behavior.

All executed application inputs were rehashed before/after against both isolated
projects; required runtime hashes and native inputs match canonical provenance.
The authenticated Windows project build/fleet-limit-final/windows/godot was opened
with source labeld86e4bba. Visual inspection confirms both new fields and actual
caps alongside the existing budget, mass/inertia and painting controls. The prior
painted review instance remains available. No owner acceptance or burrowing fix
is inferred from these mechanical checks or this launch.

## Owner recording

[Compact observation](gcr-rest-2026-11-02/burrowing-owner-observation.json) retains
the ZIP SHA256cd865ec82aa58f9d6ea5e0a39eafe0a1529d7ca4b9500a97fb60671fca9c24ac,
931 lossless frames, target30FPS, actual capture times and selected frame hashes.
Original ZIP and selected images remain local; no image archive is committed.
The owner reports defaults, interpreted as LA/budget20/mass×1/inertia×1; the crop
does not independently verify those settings, craft identity or source/runtime.

Frames301(10.019266s),601(20.024867s) and931(31.028620s) show progressive leftward
burrowing and rotation into a gray bank, which reshapes around the hull. The hull
circle stays near the same vertical level, so this clip primarily demonstrates
lateral burrowing rather than large net sinking. An exhaust-like graphic is
visible; it is not an input or applied-force receipt. The current overlay follows
throttle request, which need not equal delivered force. Frames1..61 are byte
identical; that alone does not prove paused physics.

This supports a real relative-motion symptom beyond outline-only fluctuation,
but cannot isolate jitter, presentation sampling, passive creep, commanded drive,
correction, displacement or sample delivery as its cause. Zero controller caps
provide a bounded future comparison; they do not disable gravity/contact physics
or establish sleep/rest. No material law was changed in response to this recording.

PR351 remains draft and unmerged. Broader physical and subjective qualification,
including the slow-burrowing mechanism, remains open.
