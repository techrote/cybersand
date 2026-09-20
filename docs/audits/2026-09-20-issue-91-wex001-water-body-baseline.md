---
title: WEX-001 generic Rapier-Water baseline
status: Current
document-kind: audit
scope: Preregistered characterization and source-matched evidence for current generic rectangular Rapier-body to Water displacement, conservation and hard-boundary behavior
canonical-for: []
last-reviewed: 2026-09-20
related-documents: [../operations/water-hybrid-pressure-extension-programme.md, ../architecture/rigid-body-and-cellular-coupling.md, ../systems/water-design.md]
---

# WEX-001 generic Rapier-Water baseline

## Registration status

**Preregistered 2026-09-20 before WEX-001 instrumentation changes.**

Issue [#91](https://github.com/techrote/cybersand/issues/91) uses "freeze" to mean a
reproducible, source-matched observational/regression baseline. It does not freeze
implementation semantics, declare observed behavior correct, or accept the defects
recorded here.

Registration source is authoritative `main`
`97b84035d4fd38602ae8e983b6d4d4ae6c60df6b`. At registration there is no #91
implementation PR or branch other than this issue branch. #49 remains the sole
owner of the corrected #26 Water apparatus. #81 remains the generic
body-to-cellular semantic remediation owner; no #81 implementation PR is open.
Stage-3B #63 has a separate active branch and owns sparse discovery witnesses, not
this fixture. WEX-001 will not change the coupling kernel, ejection policy, hard
terrain semantics, Water transfer rules, soliding or #49 apparatus.

Current source inspection confirms that `find_ejection_target` accepts an empty
endpoint without checking the intervening hard-terrain path. This is an observed
mechanism to characterize, not permission to repair it here.

## Question and classifications

The fixture asks four separable questions.

1. Does an ordinary small rectangular Rapier body entering native Water create a
   measurable splash/free-surface displacement relative to a no-body control?
2. Is exact closed-world Water integer mass retained while body overlap/ejection
   occurs?
3. Does Water cross the one-cell hard floor during body reconciliation, and does
   the Rapier body itself penetrate the floor beyond the retained isolated
   hard-floor tolerance?
4. What overlap/ejection, sample-age, body-pose, native-tick and coupling work
   accompanies those observations?

Classifications are descriptive:

- `useful-displacement-observed`: body case has non-zero Water ejection and a
  larger peak mass above the initial free surface or larger surface excursion than
  its matched no-body control.
- `no-useful-displacement-observed`: the preceding condition is not met.
- `water-forbidden-boundary-crossing`: any authoritative Water mass is observed
  in the registered near-floor forbidden band below the hard floor.
- `body-floor-penetration`: projected body bottom exceeds the hard-floor datum by
  more than 2 cells. The 2-cell value is the retained historical characterization
  tolerance, not a statement that 2-cell penetration is physically accepted.
- `mass-conserved`: every registered full-world mass sample equals initial exact
  integer Water mass.
- `mass-mismatch`: any registered full-world mass sample differs.

A later semantic fix may intentionally change one of these classifications. That is
a baseline change requiring explicit evidence reconciliation, not a reason to keep
the defect.

## Fixed runtime and body contract

All primary runtime evidence uses the native phased World through the existing
Godot physics-characterisation owner, pinned Godot
`4.7.stable.official.5b4e0cb0f` and Rapier2D `v0.35.2`.

The reference body is an ordinary rectangle:

- size: 8 x 14 cell/pixel units;
- mass: 1.0 adapter units;
- inertia: backend-derived automatic inertia for that rectangle/mass; no manual
  inertia override;
- rotation: 0 radians;
- initial horizontal velocity: 0;
- initial vertical velocity: 0;
- gravity scale: 0.094;
- linear damping: 0.15;
- angular damping: 0.35;
- friction: 0.78;
- restitution/bounce: existing fixture/backend default, expected zero;
- CCD: cast-shape;
- one body only.

"Barrel" may remain in legacy source identifiers, but no barrel-specific behavior
is introduced or inferred.

## Water/container geometry

The WEX fixture uses a 96-cell-wide one-cell hard-wall tank with open headspace,
one-cell side walls and a one-cell hard floor. Native Water is material 3, filled
at the Current maximum 255 integer mass units/cell with coherence state 0.

Two primary depths are frozen:

- shallow: 24 Water rows;
- deep: 96 Water rows.

The initial free-surface datum is y=256 before optional whole-fixture translation.
The body is horizontally offset from tank centre by the arm value below. The entire
tank/body fixture may be translated without changing relative geometry.

The near-floor forbidden band is the first 16 rows below the hard floor and extends
16 cells beyond both tank side walls. The 16-row depth exceeds the current bounded
ejection distance, so a body-reconciliation crossing must enter this band before
ordinary Water motion can carry it farther away.

## Entry variants and matrix

Drop is the vertical gap between the initial body bottom and the initial Water
surface, expressed in body heights:

| Arm | Depth | Drop | Body x offset | Translation x | Workers | Horizon | Purpose |
|---|---:|---:|---:|---:|---:|---:|---|
| W0 | shallow | none | none | 0 | 1 | 360 | Water-only conservation/surface control |
| W1 | deep | none | none | 0 | 1 | 360 | Water-only deep control |
| H0 | empty | 1.0 | 0 | 0 | 1 | 360 | Rapier hard-floor/no-Water control |
| Sg | shallow | 0.25 | 0 | 0 | 1 | 600 | gentle entry |
| Sm | shallow | 1.0 | 0 | 0 | 1 | 600 | moderate entry / floor-failure reference |
| Sh | shallow | 4.0 | 0 | 0 | 1 | 600 | harder bounded entry |
| Dn | deep | 1.0 | 0 | 0 | 1 | 60 | bounded body+Water control that must end before floor contact |
| Dm | deep | 1.0 | 0 | 0 | 1 | 600 | deep entry with pre-floor and later behavior retained |
| Dl | deep | 1.0 | 0 | 0 | 1 | 900 | delayed/floor-reaching observation |
| M- | shallow | 1.0 | -18 | 0 | 1 | 600 | mirrored left-offset entry |
| M+ | shallow | 1.0 | +18 | 0 | 1 | 600 | mirrored right-offset entry |
| T | shallow | 1.0 | 0 | +64 | 1 | 600 | translated-coordinate control |
| P1 | shallow | 1.0 | 0 | 0 | 4 | 600 | worker-count parity |
| P2 | deep | 1.0 | 0 | 0 | 4 | 600 | deep worker-count parity |
| O0 | deep | 1.0 | 0 | 0 | 1 | 360 | observer/telemetry-on reference |
| O1 | deep | 1.0 | 0 | 0 | 1 | 360 | body diagnostics disabled overhead/neutrality control |

This Dn no-floor arm was added while registration was still documentation-only, before any instrumentation edit. The matrix is deterministic and has no simulation RNG. The fixture seed is fixed
to 0; `translation_x` and `body_offset_x` are the registered spatial variations.
No arm changes Water semantics or coupling gains.

## Measurements and cadence

The instrumentation is observation-only and excluded from the existing measured
native-tick and coupling timing intervals.

Every simulation tick records:

- body centre, projected bottom, linear velocity and rotation when present;
- floor penetration;
- cumulative displaced and unresolved overlap counts;
- accepted/raw body-coupling impulse terms where diagnostics are enabled;
- sample age/stale/duplicate observations;
- exact Water mass in the near-floor forbidden band.

Every 6 ticks, plus tick 0 and final tick, a bounded tank/halo snapshot records:

- exact Water mass in the observation ROI;
- Water cell count and vertical/lateral first moments;
- mass above the initial free-surface datum;
- highest Water cell;
- per-column first-Water surface envelope;
- surface minimum/maximum/span;
- body/Water overlap.

Every 60 ticks, plus tick 0/final, the existing four-quadrant stored-mass observer
records exact **full finite World** Water mass. There are no sources, sinks or
reactions in these fixtures, so a permanent integer-mass loss cannot disappear
between registered samples by a legitimate source/sink. The per-tick forbidden
band independently catches the known floor-crossing path at its boundary.

Timing retained per arm:

- native `simulation_tick` p50/p95/max;
- coupling p50/p95/max covering Rapier step, state sampling and pre-tick
  body/cellular preparation;
- horizon and completed tick count.

Instrumentation overhead/neutrality is checked by the O0/O1 pair and the existing
observer-off contract. Performance values are characterization data only; CI
runner timing is not a desktop frame-time claim.

## Comparison and regression rules

- Full-world Water mass must match exactly within each arm.
- One-worker versus four-worker comparison uses the same registered geometry and
  compares normalized sampled Water/body trajectories and classifications; timing
  is not required to match.
- M-/M+ compare mirrored scalar outcomes and mirrored lateral moments. Tiny
  floating-point body-pose differences are retained rather than rounded into an
  exact-physics claim.
- T checks coordinate translation without claiming universal translation
  invariance beyond this fixture.
- The no-body controls separate ordinary Water settling from body-induced
  displacement.
- H0 separates Rapier hard-floor contact from Water/ejection behavior.
- Dm provides a body+Water interval before floor contact where available; Dl
  extends the same geometry to expose delayed/floor behavior.
- Any runtime failure, malformed result, capacity refusal, incomplete tick count
  or inability to obtain source-matched runtime identity is retained as evidence
  and blocks a trustworthy baseline rather than being converted into a pass.

## Scope guard

WEX-001 will add only bounded characterization/regression apparatus and evidence.
It will not alter `find_ejection_target`, bearing/support, hard colliders, Water
transfer/equalization, #49 successor metrics, soliding/hybrid ownership, Water
sheets, material models or #45 architecture.

## Results

Not yet executed at registration. Results, exact PR-head source identity, runtime
artifact hashes, platform/worker identities, validation runs and classifications
will be appended only after the registered apparatus has run.
