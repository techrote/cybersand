---
title: WATER-CONTACT #362 submerged-overlap study registration
status: Current
document-kind: audit
scope: Pre-result registration of water_contact.submerged.v1, the owner-chosen read-only characterization of stored Water left under a submerged Rapier body; classifier design, shakeout failure and correction, matrix and predictions; no results
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [2026-11-04-water-contact-362-phase-a.md, 2026-11-04-water-contact-362-registration.md]
---

# `water_contact.submerged.v1` — registration

On 2026-11-04 the owner chose a read-only study of the submerged-body gap found
in [Phase A](2026-11-04-water-contact-362-phase-a.md) over spray work. The
executable registration is
[`water_contact.submerged.v1.json`](../../godot/tests/fixtures/water_contact/water_contact.submerged.v1.json),
registered against main `7ef4856e` before stage-2 results.

## Relation to #347

[PR #347](https://github.com/techrote/cybersand/pull/347) at head `957ce67d`
(draft, physical NO-GO) adds `World::conservative_displace_cells`. It is a
2–5-position, at most four-move vacancy chain for Sand and Water, enabled only by the
opt-in `conservative_displacement` diagnostic option while a structural
detachment aggregate is Active. It refuses PressureFlow, IN and CellularYield
Worlds (`UnsupportedPolicy`). Generic Rapier↔Water impacts never reach it.
This study therefore needs no #347 change and does not depend on its merge,
and it edits no shared adapter, bridge or World file.

## Apparatus

- Unchanged `water_contact.impact.v1` dynamic run (`Apparatus.run_case`)
  with a new **optional, default-off read-only observer hook**. With no
  observer, v1 behavior is unchanged (`test_water_contact_impact.gd` still
  108/0).
- [`water_contact_submerged.gd`](../../godot/tests/support/water_contact_submerged.gd)
  works on every stored Water cell under the current mask after coupling. It
  replays `overlap_normal`, `find_ejection_target` and `ejection_path_reachable`
  on copied stored bytes, and records why no target exists:
  `no_empty_within_reach`, `empty_only_under_mask`, `empty_path_blocked` or
  `hard_or_bounds_only`. It also records the cell's overlap-normal kind, the
  straight reach the probe fan would need, and the shortest four-connected
  chain through unmasked Water to unmasked Empty.
- **Kinematic descents** (prescribed body records, no Rapier) move the body
  down at 1, 3 or 8 cells per step, with and without liquid ticks, to locate
  the depth at which relocation stops. They are forcing experiments only.
- A **positive control** requires the classifier to predict exactly the
  adapter's destination for a cell it relocates.

## Shakeout failure and correction (retained)

The first stage-1 shakeout **failed**. FM3 G-D24-V180 recorded 5 cell-samples
where the classifier found an admissible target that the adapter had not used
(IN3 recorded 0). The cells sat at the top face at tick 9 with targets three
rows up. The cause was the classifier, not the adapter.

During `reconcile_overlap` the adapter excludes the whole swept raster from
targets, then re-rasterizes only the final pose. Swept-trail cells can
therefore be unmasked Empty after coupling. The corrected classifier replays the
sweep (`rasterize_body_sweep`: 32-cell limit, 1-cell spacing, at most 24 steps)
as the exclusion mask and classifies trail cells separately. After the
correction, the stage-1 rerun passed with zero disagreements in all six rows,
and the positive control passed for all four families (predicted = actual
`(240, 397)`). Nothing else changed before stage 2.

## Matrix and questions

Twelve dynamic cases (depth 12–96, entry speed 15–360 px/s, reference/wide/tall
bodies). FM3 and IN3 run everywhere; CY3 and PF3 join at the four depth/speed
corners. Two cases repeat at configured workers 1 and 4. Seven kinematic descents
complete the matrix. Questions Q1–Q6 and predictions P1–P3 are in the manifest.
P1 (zero disagreement) is an apparatus gate. P2 and P3 are recorded and not
asserted. All `water_contact.impact.v1` invariants apply to the dynamic rows.
