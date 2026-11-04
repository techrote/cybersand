---
title: Flyer controls, live powder sources and edge alignment
status: Current
document-kind: validation
scope: Source-inspected owner-review follow-up and scoped Windows checks; integrated final-head platform validation pending
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [../systems/granular-review-flight-fleet.md, 2026-11-04-repeatable-powder-review.md, 2026-11-04-gcr-selective-events.md]
---

# Flyer controls and representative painting-room review — 4 November 2026

## Owner feedback and unresolved mechanism

The owner explicitly identifies the reviewed response as **LA/A1**, not selective
arrivals. The owner reports substantially improved play, realistic reactive torque
while thrusting and rotating, safe ordinary landings and safe burial in Dust.
Afterglow can still tunnel under power; the owner considers that compatible with
its shape/mechanics and potentially useful as a gameplay mechanic. Burial with
Sand, Rust or Coal still starts sinking. Relative flyer/material mass or overhead
loading is the owner's hypothesis, not an established cause or a calibrated law.

Six cropped images illustrate the reported inward graphical offset on the left
and right piles. They do not show the selector or a complete source/runtime
receipt. Preserve the actual user judgement as qualitative LA/A1 feedback; do not
relabel it as exact-head measurement or acceptance of the selective candidate.
Positive play feedback does not close REM-004 while burial and production-envelope
gates remain open. The earlier selective registered NO-GO remains unchanged.

## Source and ownership boundary

The isolated codex/gcr-flight-review-controls-20261104 branch starts at
7c2c5fe3c92137eb6ab55768d3bec6ae4b33db63. Accepted main remains
7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1. Running review checkouts and the dirty
C:/khybersand worktree are preserved. This work changes developer input,
presentation and explicit sources; it does not tune material, friction, load,
granular-response, correction or sleep laws. Native source, bridge and worker
are unchanged by the intended write set. Source-matched reuse of compiled
856c49371b37b3921bf859a67a883336252134ee must retain all88 native input and runtime
byte checks before final handoff; no old execution is relabelled as a new run.

Astra's aggregate/handoff/quarantine route remains separately owned. These tools
add no second response, per-cell rigid body, erased/restored body representation
or worker call into live Godot/Rapier. All PRs remain draft/unmerged. No gameplay
acceptance or material-law change is inferred merely from shipping review controls.

## Implemented controls and source limits

The canonical [fleet guide](../systems/granular-review-flight-fleet.md#shift-thrust-multiplier-ctrl-brake-and-painting-room-powder-sources)
owns exact current controls. Shift becomes a staged configurable propulsion and
force-ceiling multiplier(default2, range1..8); Ctrl retains the previous brake.
Brake wins if both modifiers are held. Torque, hoverboard gravity compensation,
passive drag/speed damping and no-Shift behavior remain controls. Main and applicable
Q/E side propulsion share the scaled ceiling; zero authored force stays zero.
Gamepad B braking is retained. This is a room-scoped binding, not a global change
to every player/actor preset.

Boost level is validated beside q/e/s review ports before command admission and
inherits accepted epoch/generation/sequence/lease. Shared Session ACTION_KEYS is
not widened. Cancellation, expiry, focus/pause and owner replacement retire it.
The controller consumes copied intent; no native/worker/controller Input polling
or hidden pose/velocity setter is added.

The normal painting room now has toggleable palette powder sources for allseven
flyers, with gravity38 and pilot control retained. Placement captures one of nine
granular materials and a fixed origin48 cells above the rotated hull's top.
The source does not follow response-dependent actor motion. Burst requests4×24
cells, coalescing repeated clicks into one pending request. Stream requests4×1
cells per simulation tick for at most600ticks; another interval requires explicit
renewal. Pause freezes it; focus loss and reset/Apply/craft replacement disarm it.

Source checks preserve existing occupied material, current hulls, foreign/native
masks, hard terrain and room bounds. They record actual external additions and
blocked attempts, not intended quantity. A256-row recent ring reports dropped
rows while cumulative attempted/inserted/blocked counters remain exact. Sources
do not grant arrival provenance or add recoil. The fixed-Kestrel zero-body-gravity
comparisons from PR375 remain separate and retain their prior scope and settings.

## Alignment cause and bounded repair

The terrain TextureRect fits the actual992×480 output texture, while follow mode
samples a512×256 world view in its shader. Overlay/painting used the sampled
view's2:1 aspect instead of the texture's approximately2.0667:1 footprint. This
produced the inward horizontal error toward both edges, about3.3% in the relevant
fit. Camera clamps made the offset especially visible on the outer piles.

The minimal repair fits overlay/painting coordinates to the actual texture's
displayed rectangle. It moves no physics body and edits no native material.
The retained slight anisotropy and non-integer sampling are not silently called
pixel-perfect or GPU-qualified rendering. Full renderer redesign is outside scope.

## Scoped checks and final qualification still required

Before integrated qualification, separately scoped Windows checks report:

- 597 alignment checks over36 camera/aspect cases, including a historical formula
 negative that must fail; this is presentation mapping evidence, not contact physics.
- 211 boost checks: allseven actual profiles/impulse delivery, torque invariance,
 hover/coast/brake behavior, multiplier bounds, zero authored force, held release,
 lease expiry and pause. Original boost logs are in build/boost-preflight-01.
- 1574 live-source checks: guarded source behavior and bounded ledgers. These remain
 scoped helper/host evidence until the integrated scene and both platforms pass.

The final source checkpoint must record actual command, watchdog, engine/native/
Rapier hashes, original logs, all native input identities and platform results for
the integrated controls, alignment, full roster, live sources and retained canned
tests. Run current document/M11/materialized provenance/retrieval/whitespace gates.
Inherited source-lock incompatibility remains: original shadow locks/checker must
not be refreshed to hide the three protected drifts. Hosted failure/skips and local
passing checks remain distinct. Root will append exact final source and results.

No broader physical efficacy, simultaneous multi-job race, GPU visual acceptance,
exact coupled save/replay, sleep, production default, issue closure or merge is
accepted by this source-only follow-up.
