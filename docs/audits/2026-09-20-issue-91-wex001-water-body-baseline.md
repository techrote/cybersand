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

### Source and runtime identity

The registered executable fixture was run from PR #102 at branch head
`e4eef48fcc726dfe097993a7784dac53c36340d5`. GitHub's pull-request checkout
materialized synthetic merge commit
`f676f51d92cf1a430d1a9af3c770bfbddcf91ef1`, whose tree
`902719bf653d1adda0d6f036b2ec1f747a82f723` is **identical** to the exact
branch-head tree at `e4eef48f`; its parents are authoritative base
`97b84035d4fd38602ae8e983b6d4d4ae6c60df6b` and that exact branch head.
The execution therefore used byte-identical repository content to the exact PR
head while retaining GitHub's merge-candidate commit identity.

Runtime evidence is GDExtension workflow run `35532203400`, Linux build job
`106134681500`, shard-2 runtime job `106135182155`, and retained shard artifact
`10612435258`:

- Godot: `4.7.stable.official.5b4e0cb0f`;
- Godot archive SHA-256:
  `0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c`;
- godot-cpp: `101ae38034304346a46ea9ea84ae156d3e860496`;
- CyberSand Linux GDExtension SHA-256:
  `6e2cddc8c0cecb9ca7250d9e5d171f9055e4b519b5c529656d9c9a30dbad70d3`;
- Rapier2D Linux runtime SHA-256:
  `147ab5673b9687ccb7a3b12fec07ea55cc674ad8a75f529d1085bf7d61fbd831`;
- Linux runtime artifact `10611666850`, ZIP SHA-256
  `051a6bae33b66b3a772942b11937477588f25900a93cbd5b659a25aef1864b61`;
- GDExtension build runner `grj4ya818fdp6qb2qs2y1w7emy`, machine
  `vmfsmzfx`;
- WEX runtime runner `avrea-exe-01a0c04a3da371c19e52962548e923fb`, machine
  `vrm-01a0c04a3f877b10b524a3d8becc163a`, two logical CPUs;
- native World arms use the registered one- and four-worker configurations.
  Four-worker arms are scheduler/thread-count controls on this two-vCPU CI host,
  not four-physical-core performance measurements.

The WEX regression itself completed in 111.587 s. All 44 discovered Godot
regression cases remained covered across four isolated shards.

### Classification result

The baseline captures both useful current coupling and the known generic boundary
failure.

- **Useful displacement is observed before floor contact.** The deep short-horizon
  Dn case reaches 7,395 integer Water units above the original surface, a
  three-cell maximum surface excursion, and 35 body-driven ejections by tick 60
  while remaining floor-contact-free and forbidden-band-free. The shallow gentle
  Sg case likewise produces 3,060 units above the surface and a two-cell
  excursion without reaching the floor during its 600-tick horizon.
- **Exact Water mass is conserved.** Every registered full-World mass sample in
  every arm equals its initial integer mass: 587,520 for shallow Water and
  2,350,080 for deep Water. The failure below is therefore relocation across a
  forbidden boundary, not Water creation or loss.
- **Hard-floor Water crossing is reproduced independently of Rapier tunnelling.**
  In Sm, Water first enters the below-floor forbidden band at tick 65, peaks at
  17,340 integer units there, and remains present there for 522 observed ticks.
  The Rapier body does not first contact the floor until tick 79 and its maximum
  projected floor penetration is only 0.0015223 cells. H0, the same body falling
  onto hard terrain with no Water, penetrates only 0.0003662 cells and never
  creates a forbidden-band observation.
- The deep Dm/Dl cases reproduce the same ordering: forbidden Water begins at tick
  145, before body floor contact at tick 150. Their later body penetration peaks
  at 0.5464172 cells, still below the retained two-cell characterization
  threshold; this value is evidence, not an accepted nonpenetration budget.
- The observed mechanism is consistent with registration-time source inspection:
  current `find_ejection_target` can accept an empty endpoint without proving
  that the intervening ejection path does not traverse hard terrain. WEX-001 does
  not repair that semantic defect; #81 remains its owner.

### Spatial/surface observations

The no-body shallow Water control remains flat: occupied-Water centroid
`(143.5, 267.5)`, highest Water y=256 and surface span 0. In the body cases the
same bounded snapshots show real free-surface displacement rather than only a
counter increment:

| Arm | Peak tick | Above-surface mass | Highest y | Surface span | occupied-Water centroid at peak |
|---|---:|---:|---:|---:|---|
| Sg | 30 | 3,060 | 254 | 5 | (143.4901, 267.3915) |
| Sm | 60 | 7,395 | 254 | 2 | (143.4401, 267.2849) |
| Dn | 60 | 7,395 | 254 | 2 | (143.4849, 303.3133) |
| M- | 60 | 7,395 | 254 | 2 | (143.2220, 267.2853) |
| M+ | 60 | 7,395 | 254 | 2 | (143.7435, 267.2796) |
| T | 60 | 7,395 | 254 | 2 | (207.4459, 267.2905) |

These are occupied-Water cell centroids from the registered material snapshots;
they are not mislabeled as mass-weighted COM. Exact integer mass is measured
separately. The mirrored cases reproduce the same scalar splash peak while their
lateral centroids shift in the expected opposite directions. The +64 translated
case preserves the useful-splash and boundary-failure classification without a
claim of universal bitwise translation invariance.

### Coupling and parity observations

| Arm | Floor tick | displaced | unresolved | forbidden peak | peak above surface | body penetration | final hash |
|---|---:|---:|---:|---:|---:|---:|---|
| W0 | -1 | 0 | 0 | 0 | 0 | 0 | `1d697f64a4a7850c` |
| W1 | -1 | 0 | 0 | 0 | 0 | 0 | `7c15850dc2c41ab0` |
| H0 | 56 | 0 | 0 | 0 | 0 | 0.0003662 | `f9d9aa90a5c2ee5d` |
| Sg | -1 | 40 | 1,589 | 0 | 3,060 | 0 | `22fb8627593a6eaa` |
| Sm | 79 | 432 | 14,731 | 17,340 | 7,395 | 0.0015223 | `3ea252bf6d9d8c94` |
| Sh | 87 | 866 | 15,534 | 19,125 | 7,905 | 0.0361328 | `ff9c060baf550448` |
| Dn | -1 | 35 | 1,182 | 0 | 7,395 | 0 | `ee95c422e026bff7` |
| Dm | 150 | 313 | 32,290 | 17,595 | 7,395 | 0.5464172 | `61438c3a5286650f` |
| Dl | 150 | 419 | 46,390 | 17,595 | 7,395 | 0.5464172 | `439f8332069a3897` |
| M- | 79 | 784 | 14,531 | 17,595 | 7,395 | 0.0009801 | `4b5007793657a053` |
| M+ | 79 | 631 | 14,792 | 17,595 | 7,395 | 0.0018049 | `93b93bd7cb5c785e` |
| T | 79 | 760 | 14,941 | 18,105 | 7,395 | 0.0023238 | `0dd138518ae5fc16` |
| P1 | 79 | 432 | 14,731 | 17,340 | 7,395 | 0.0015223 | `3ea252bf6d9d8c94` |
| P2 | 150 | 313 | 32,290 | 17,595 | 7,395 | 0.5464172 | `61438c3a5286650f` |
| O0 | 150 | 171 | 21,010 | 17,595 | 7,395 | 0.5464172 | `c00035464a1bf61f` |
| O1 | 150 | 171 | 21,010 | 17,595 | 7,395 | 0.5464172 | `c00035464a1bf61f` |

Sm/P1 and Dm/P2 are exact one-worker/four-worker matches for final state hash,
displaced/unresolved totals, forbidden-band peak and classification. O0/O1 are
also exact state/coupling/body-depth matches, so enabling the retained body
diagnostic observer does not alter the characterized outcome.

The mirrored M-/M+ and translated T arms intentionally retain their differing
ejection/unresolved totals. WEX-001 freezes those observations rather than
rounding them into a stronger symmetry or translation claim.

### Timing observations

Values are microseconds p50/p95/max from the CI host and are retained only as
characterization data:

| Arm | native tick | coupling |
|---|---|---|
| W0 | 11 / 23 / 1,174 | 1 / 1 / 2 |
| H0 | 8 / 30 / 425 | 153 / 262 / 4,222 |
| Sg | 904 / 1,039 / 2,943 | 241 / 378 / 4,257 |
| Sm | 931 / 1,114 / 3,031 | 268 / 445 / 4,647 |
| Dn | 1,178 / 3,800 / 7,621 | 309 / 860 / 2,359 |
| Dm | 3,413 / 6,172 / 25,821 | 376 / 996 / 4,247 |
| P1 | 1,066 / 1,613 / 10,688 | 331 / 675 / 3,984 |
| P2 | 3,439 / 5,220 / 9,827 | 363 / 591 / 3,623 |
| O0 | 3,259 / 6,164 / 11,522 | 376 / 1,292 / 7,152 |
| O1 | 2,968 / 3,691 / 10,001 | 225 / 408 / 3,065 |

The O0/O1 state equality plus lower O1 timing quantifies diagnostic overhead
without converting CI timing into a desktop performance claim.

### Validation

On the registered source tree:

- Documentation/provenance run `35532203281`, job `106134680827`: pass.
- GDExtension/Godot run `35532203400`: exact Linux build pass, all four
  isolated regression shards pass, aggregate Linux gate pass; WEX-001 and
  `test_web_worker_parity` both execute on the two-logical-CPU parity shard.
- Native C++ run `35532203264`, job `106134680908`: pass, including 62 native
  behavioral/integration tests, soliding contracts, Stage-3B apparatus checks,
  ASan+UBSan, sanitized soliding suite, TSan, shared library and benchmark.
  Native compiler identity is GCC/G++ 13.3.0
  (`Ubuntu 13.3.0-6ubuntu2~24.04.1`) with GNU ld 2.42; runner
  `grz71hv61hhp7hqf7pevj0mzva`, machine `vmtmz8jc`.

The GitHub Windows GDExtension fallback is workflow-dispatch-only and therefore
correctly skipped on the PR. No runtime/GDExtension C++ source or binary provenance
was changed by WEX-001.

### Current-truth effect and routing

No canonical physics document needs a semantic rewrite from these measurements:
the repository already classifies body/cellular coupling as provisional and
forbidden hard-boundary crossing as defective. This audit adds a reproducible,
source-matched Water-specific anchor and therefore leaves canonical truth wording
unchanged.

The reproduced hard-floor Water ejection belongs to #81's generic body/cellular
semantic remediation. #49 remains the sole owner of the corrected #26 Water
successor apparatus. WEX-001 neither absorbs nor blocks those owners.

**Baseline status:** captured. The observed useful displacement and the observed
hard-floor defect are both regression anchors; neither is an acceptance decision.
