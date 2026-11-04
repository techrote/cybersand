---
title: Flyer controls, live powder sources and edge alignment
status: Current
document-kind: validation
scope: Windows/Linux owner-review controls, live source and alignment validation; no new response law or physical efficacy acceptance
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

The [six-image hash manifest](gcr-flight-review-2026-11-04/owner-image-manifest.json) binds the supplied crops. Six cropped images illustrate the reported inward graphical offset on the left
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
are unchanged. All88 native inputs and both actual runtime byte hashes match
compiled856c49371b37b3921bf859a67a883336252134ee before/after host execution.
No old execution is relabelled as a new run. Feature sourcef9566fd5 has the first
combined platform run; layout correction893bca93b204b5ac8fe8c25fdc91322b073b55c4
has the second complete platform run. Later gamepad help/test/doc edits retain
source distinctions; final-head host receipts are separately recorded in the PR.

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

## Completed actual-host controls

The [host summary](gcr-flight-review-2026-11-04/host-summary.json) records all28
Windows/Linux suites plus two imports at893bca93 with source/runtime, command,
300s watchdog and original log hashes. Per platform, the new suites pass:

- 597 alignment assertions across36 actual Control/shader/camera/aspect cases.
- 211 boost assertions: allseven profiles, actual delivery, torque invariance,
  hover/coast/brake, bounds, zero force, release/cancel, expiry and pause.
- 1578 source assertions: seven flyers × LA/E/S, allnine materials, ordinary
  gravity and pilot response, guarded writes, exact counts, cutoff/ring capacity,
  owner replacement refusal and explicit reconfiguration.
- 117 integrated scene assertions: real Shift/Ctrl event sampling, rearm,
  applied profile settings, no reset on source placement/burst, pause/stop/focus,
  palette capture/refusal, canned-test isolation and bounded layout height.

The retained canned comparison still passes6605 checks per platform; old selective
and event/UI, fleet controls/emissions/side-thrusters, actor, bridge/freshness and
navigation suites remain green. No native rebuild/core rerun is claimed because
the88 native inputs are unchanged. There is no new physical efficacy score.

The historical mapping negative replaces only the crash-room mapping file with
parent7c2c source in the isolated actual Windows host; the new aspect assertions
fail with exit1 as expected. Its original receipts remain in
build/alignment-old-mapping-01. This is a regression-control failure, not a
candidate physics failure. The first integrated input test used synthetic
modifier events without modifier flags; it failed. Adding actual event modifier
state/flush corrects the fixture before combined qualification. Original
room-controls-preflight-01 and successful02 logs are retained.

## On-screen review and layout correction

Visual review off9566fd5 exposed the long sidebar forcing the lower map beyond
the visible window despite host controls passing.893bca93 makes the roster/help
scroll within available height; it does not move bodies or alter rendering laws.
The subsequent layout assertion measures actual combined minimum height rather
than checking only the container class. Source9d4a1b2ab22db4805695c59a48fb2a58b5ab9d03
also corrects the gamepad help equivalence and is opened in a source-labelled
Windows review window. The controls and map floor are visible. Runtime logs
build/flight-visual-02.log/.err retain the actual OpenGL/Rapier identity and no
engine errors. This is a layout smoke check, not GPU pixel or owner feel acceptance.
Existing terrain anisotropy, nearest sampling and project window scaling remain.

Local documentation/M11/materialized provenance/retrieval/whitespace checks pass.
Inherited exact-source shadow compatibility remains blocked by the same three
protected source drifts; original locks/checker are not refreshed. Hosted failure
and draft skips remain distinct from local executed controls. Final exact-head
results and source identity are recorded in the PR/local final receipt.

No broader physical efficacy, simultaneous multi-job race, GPU visual acceptance,
exact coupled save/replay, sleep, production default, issue closure or merge is
accepted by this source-only follow-up.
