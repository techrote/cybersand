---
title: Scooper carried-material leakage diagnosis
status: Approved design
document-kind: design
scope: Bounded copied-cell and hull-side observations with unchanged actor and response laws
canonical-for: [gcr-scooper-leak-diagnosis]
last-reviewed: 2026-11-04
related-documents: [gcr-authored-compound-registration.md, ../systems/granular-review-flight-fleet.md, ../architecture/compound-granular-coupling.md]
---

# GCR-CARRY-002 — registered before new captures or candidate changes

## Authority and retained evidence

The owner reports that selective-arrival Scooper feels very good but loses
carried powder through/out of its hull above very slow movement. Preserve the
authored controls, all seven earlier flyers, existing response/material laws,
native cell authority, one physical body/budget and unmerged PRs. Sleep and
structural payload integration remain excluded.

An isolated codex/gcr-scooper-leak-investigation-20261104 worktree starts from
PR385 source `5e79f2be994b652f9aef658e2075650631581427`. Freshly fetched main
is `7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1`, tree
`36ce5a01e754a141c321f41cac7f1c6b6059c371`, unchanged from the earlier review.
PR347 remains independently owned at957ce67d, draft/unmerged, with its existing
physical NO-GO. The dirty main workspace and reviewer checkout/imports and
running review build are preserved. Native89/compiled0206 and both matched
SDKs are the initial controls; native edits require new builds before execution.

Prior observations are retained: the carry demonstration meets its literal
lift/spill limits in E/S but has primary cavity count zero at180. Read-only
reconciliation finds that at180 all16 grain centres lie inside the *post-Rapier*
deck while remaining above the sampled deck; the next preparation displaces16.
That one-boundary overlap is not proof of persistent escape. At normal full
speed95cells/s the body can advance1.58cells per tick across a2-cell deck.
Nearest-current-face ejection, raster topology, sequential pose sampling and
ordinary escape over the open nose/rim are separate hypotheses.

## Frozen diagnostic population

Use the ordinary synchronous one-worker Runtime and the frozen Scooper JSON,
mass0.18, inertia/default multipliers1, budget20, gravity38, dt1/60. Seed exactly
16 Sand grains at(504,249), width16 height1, body spawn(512,250), the prior
closed hard fixture boundaries, no stream and no further material authoring.
Do not set pose/velocity after construction. No inventory, pinning, stop,
sleep, material binding, friction/load tuning or extra native/Rapier ticks.

Each case lasts450 ticks. Neutral hover/stabilization is an active motor, not
an unactuated control. Ticks0..119 neutral,120..239 requested movement,240..329
Ctrl brake,330..449 neutral. Q/E trim stays zero. Primary selective cases:

| Case | Move x/y | Shift |
| --- | --- | --- |
| stationary |0,0|false|
| rise-slow |0,-0.1|false|
| rise-moderate |0,-0.5|false|
| rise-full |0,-1|false|
| rise-boost |0,-1|true|
| closed-end |1,0|false|
| open-end |-1,0|false|
| diagonal |1,-1|false|

Also repeat rise-full with LA and events off, total10 cases per OS. Record
actual velocities/displacements rather than treating command fractions as
measured speeds. First acquire Windows, reproduce the complete bounded set
on Linux if apparatus is stable. No additional Cartesian material population.

## Observations, correctness and decisions

Observe copied authoritative grain coordinate sets immediately before and after
the ordinary owner step. For every grain, retain local coordinates relative to
both the actual pre-step sample and post-Rapier hull: open cavity, inside each
real rectangle, below the closed deck, beyond the closed stop, beyond the open
nose and above the rim. No persistent cell identities are invented. Record
actual mask membership, ejection attempts/outcomes/endpoint counters, aggregate
one-wrench/budget/energy/work receipts, clocks, commands/actuation and poses.
Per-proxy event counters are not aggregate force accounting.

A bounded128-cell ROI may follow the hull and preceding cloud. If it contains
fewer than16 grains, fall back to a whole-fixture observation that phase, within
the native512-column snapshot limit. Outside-ROI count is null until measured,
never an assumed zero. Exact whole-world material/Water quantity is checked at
start/end and periodic observations. Diagnostics add no physics ticks.

One cavity-count dip does not establish leakage. Separate transient overlap
that clears toward the cavity at the next preparation from persistent material
on the far side of a closed hull piece. A credible closed-deck crossing witness
must retain the before/after coordinate sets, keep the relevant cloud inside
the deck's horizontal interior, and show below-deck material surviving the
following preparation. Escape through an open side or over the rim is reported
separately. Unobserved internal relocation stages remain unproven unless an
additional explicitly observational hook is registered before use.

Compare measured maximum displacement normal to the thin wall and first
persistent closed-side escape, with clear no-motion/slow controls. Preserve all
refusals and conservation failures. Do not widen ejection search or tune friction
to hide a geometric transport defect. If runtime evidence identifies wrong-side
ejection, first register the smallest history/entry-side admission repair and
its no-stale-side, concave/seam, hard/foreign-mask, conservation and barrel gates.
If evidence instead shows open-rim spill or only presentation phase, retain that
result and propose the corresponding bounded authoring/presentation follow-up.
No production, loaded-rest, uninterrupted-carry or owner acceptance follows.
