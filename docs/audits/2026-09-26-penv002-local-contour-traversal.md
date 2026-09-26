---
title: PENV-002 local-contour traversal remediation
status: Current
document-kind: evidence
scope: Issue #147 replacement of rejected whole-box step/knee/clamber traversal classification with leading-foot local-contour classification; not owner gameplay acceptance
canonical-for: []
last-reviewed: 2026-09-26
related-documents: [../systems/player-environment-profiles-and-traversal.md, 2026-09-25-rem003-player-granular-acceptance.md]
---

# PENV-002 local-contour traversal remediation — 2026-09-26

## Owner rejection

The first PENV-001 traversal model is rejected as a gameplay model.

During the #139 desktop review, separated **2 / 4 / 6 px** step/knee/clamber
thresholds still felt poor/sluggish. Source review confirmed that the implementation
classified traversal by searching for the first height at which the **entire
8×14 sampled-player box** cleared an obstacle. It then multiplied horizontal
progress by the knee/clamber factor and moved the actor vertically by the complete
clearance height in the same traversal call.

The old PENV regression encoded that behavior directly: a two-pixel knee obstacle
was expected to end at half horizontal progress and a complete two-pixel upward
correction; the clamber test did the same with four pixels. Those assertions are
not retained as an acceptance oracle.

## Replacement model

PENV-002 keeps the existing profile fields but changes traversal classification:

1. horizontal movement first detects the ordinary side collision;
2. a bounded one-cell-wide probe at the **leading foot edge** measures the local
   contiguous rise relative to the actor's current foot height;
3. that local rise selects step, knee, clamber, or blocked;
4. the selected band determines horizontal progress;
5. whole-body clearance and support are then checked separately as a safety gate.

This distinction matters on shoulders/stairs. An eight-pixel-wide actor may need
several pixels of total body clearance while traversing a long staircase even when
the next local rise is only one pixel. PENV-001 could therefore classify a smooth
one-pixel shoulder as knee/clamber and slow it down. PENV-002 keeps that local
one-pixel rise in the step band when the configured threshold admits it.

A slowdown can stop short of the actual edge during a tick. In that case the
actor moves only the admitted horizontal distance and does **not** pre-emptively
teleport upward. Upward clearance is applied only once the slowed movement itself
still intersects the obstacle.

## Diagnostics

The sampled character retains, and the worker snapshot publishes:

- last traversal band;
- local ledge height;
- required full-body clearance height;
- admitted horizontal progress.

The compact desktop HUD shows the band as `trav <band> L<ledge> C<clearance>`
when a traversal collision occurred. This is diagnosis, not a gameplay score.

## Regression replacement

The PENV regression now uses a floor-contour fixture instead of the old synthetic
"clear if y <= -height" oracle. It covers:

- historical 1px control;
- owner-used 2/4/6 thresholds;
- isolated step/knee/clamber ledges;
- above-clamber rejection;
- a repeated 1px staircase/shoulder;
- a repeated 2px staircase;
- a floating head/overhang obstruction.

The repeated one- and two-pixel staircases must retain full horizontal progress
under a 2/4/6 profile and must never enter knee/clamber merely because the full
body spans several stair columns.

## Scope

This remediation changes only sampled-character traversal classification and
diagnostics. It does not change Water, liquid sensitivity, granular support,
landing disturbance, PCHAR barrel control, generic body coupling or soliding.

Runtime/CI success will establish engineering integration only. The replacement
requires a later owner feel review before it can be described as gameplay-acceptable.
