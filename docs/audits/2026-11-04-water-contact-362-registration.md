---
title: WATER-CONTACT #362 impact experiment registration
status: Current
document-kind: audit
scope: Pre-result registration of water_contact.impact.v1, the four-family Rapier impact discrimination fixture for issue 362 Phase A; apparatus, matrix, invariants, discriminators and stop rules; no results
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [2026-11-04-water-contact-362-phase-a.md, 2026-11-03-lcb-reassessment.md, 2026-09-20-issue-91-wex001-water-body-baseline.md, ../architecture/liquid-solver-family-policy.md, ../architecture/inertial-cellular-v1.md, ../architecture/pressure-flow-v1.md]
---

# WATER-CONTACT #362 — registration of `water_contact.impact.v1`

Registered on 2026-11-04 against accepted main
`3da7e7be4a6af4c85e03a7d8a0ed57229e5db33d` before any primary result was
collected. The executable registration is
[`water_contact.impact.v1.json`](../../godot/tests/fixtures/water_contact/water_contact.impact.v1.json);
this page explains it. Results are in the
[Phase A report](2026-11-04-water-contact-362-phase-a.md).

## Scope and write set

Observation of the **current** generic Rapier↔Water coupling only. The task owns
new files: the fixture manifest, the apparatus
[`support/water_contact_impact.gd`](../../godot/tests/support/water_contact_impact.gd),
the campaign runner [`run_water_contact_campaign.gd`](../../godot/tests/run_water_contact_campaign.gd),
the focused regression [`test_water_contact_impact.gd`](../../godot/tests/test_water_contact_impact.gd),
[`tools/water_contact/`](../../tools/water_contact/) and these audits. It does not
modify `world.cpp`, the native adapter, `rapier_physics_bridge.gd`, structural
detachment (#281/PR #347), the #370 comparison panel or its recorder, WEX-001,
REM-002, #20 gates or any default. Every observation uses already-bound public
adapter values on the owner thread.

## Apparatus

- **World:** 1024² native World built by `CyberDemoBridge.build_liquid_policy_world`
  with an explicit per-arm policy request and explicit radius. Basin interior
  x 192–287, floor row 600, walls from row 300. Whole-cell Water is constructed
  by rectangle (255 units per cell) identically in every arm, so no
  normalization rule is needed; the reducer rejects any arm whose construction
  quantity differs from `width × depth × 255`.
- **Body:** WEX-001 barrel parameters (8×14, mass 1, gravity scale 0.094,
  damping 0.15/0.35, friction 0.78, CCD cast shape) in an independent,
  manually stepped Rapier2D space: one Rapier step, one coupling, one native
  tick, one `apply_cellular_results(tick+1)` per tick through the unchanged
  bridge. The body starts two cells above the surface with a registered
  initial velocity. After contact its trajectory is an outcome, not a control.
- **Arms:** `freemass_v1`, `cellular_yield_v1`, `pressure_flow_v1`,
  `inertial_cellular_v1` (all `reference`, radius 3), plus original-radius
  FreeMass radius 2 as a control, not a fifth family. PF cache variants are excluded.
- **Workers:** configured 1 and 4; actual `worker_threads_observed` (maximum
  distinct task claimants per dispatch) and per-phase job counts are recorded.
  Four configured workers are not reported as four participants.

### Two observations per tick

`A` follows `prepare_rigid_body_coupling` and precedes `simulation_tick`.
`B` follows the tick. Coupling changes stored material only by relocation,
so above-surface or spray-band quantity changes decompose exactly. `B[t-1]→A[t]`
is **relocation** and `A[t]→B[t]` is **liquid transport**. Relocation destinations
and sources are the Empty↔Water differences of copied ROI stored bytes. They
are cross-checked against the coupling `displaced` count and the native
`BodyDisplacement` physics-histogram events, keyed by sign(dx, dy).
`material_at()` is occupancy-masked and is not used to find stored Water under a body.

### Kinematic forcing probe

The probe is separately labelled and uses prescribed body records with no Rapier.
A single Water cell falls freely for six ticks to acquire real state. A body
record then puts that cell five rows inside the top face. That is repeated with
body velocities of 0, 600 px/s up and 600 px/s sideways. A 20-cell upward sweep
that passes the cell is the fourth mode. The complete stored state is compared
before and after coupling, before the next tick, and the next tick is then
observed. The probe isolates the relocation law. It does not replace dynamic coupling.

## Matrix

| Case | Depth | Initial vy (px/s) | Other | Stage |
|---|---:|---:|---|---|
| S-L-C | 24 | 15 | centre | 2 |
| S-H-C | 24 | 180 | centre; duplicate/stale probe | 1 |
| D-L-C | 72 | 15 | centre | 2 |
| D-H-C | 72 | 180 | centre | 2 |
| S-H-O | 24 | 180 | offset +24 | 2 |
| D-H-R | 72 | 180 | rotation 0.6 rad, ω 3 rad/s | 2 |
| S-H-W | 24 | 180 | body face one cell from the wall | 2 |
| N-H-C | 8 | 180 | must reach the floor | 2 |
| C0S / C0D | 24 / 72 | — | no body | 1 / 2 |
| C1 | 0 | 180 | no Water, hard floor | 1 |

The horizon is 300 ticks. Stage 1 is the fixture-correctness gate. Stage 2 runs only if
every stage-1 row passes every invariant. That gives 11 cases × 5 arms × 2 worker
counts = 110 dynamic rows per OS, plus 20 probe rows.

## Invariants and discriminators

Invariants I1–I11 (quantity, containment, identity, health, relocation census,
carried state, IN domain, mask, worker parity, duplicate/stale rejection,
reported body floor penetration) and discriminators D1–D5 are defined in the
manifest. The [reducer](../../tools/water_contact/reduce_impact_evidence.py) checks them,
and its [negative controls](../../tools/water_contact/test_reduce_impact_evidence.py)
show that each failure class is rejected. Body floor penetration is reported against the retained
WEX-001 two-cell characterization tolerance and is not a new threshold.

A **true ballistic launch** would need signed upward retained velocity
(IN `vy < 0`) or a flight carrier. Spray-band Water is classified by D1–D3,
never by its pixels alone.

## Stop rules

Stop at the first authority, quantity or boundary violation and preserve the packet.
Do not retry, extend the horizon after seeing results, change a threshold, fall back or
re-run unrelated PLAY/LCB/structural suites. Failed and refused rows are written and reduced, not dropped.
