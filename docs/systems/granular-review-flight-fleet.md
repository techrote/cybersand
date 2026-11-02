---
title: Lightweight flight fleet for granular owner review
status: Current
document-kind: contract
scope: Developer-only editable flyer room with staged LA budget and mass/inertia controls, retained RFT reference and separate qualification limits
canonical-for: [granular-review-flight-fleet]
last-reviewed: 2026-11-02
related-documents: [../architecture/granular-contact-rest.md, ../architecture/compound-granular-coupling.md, player-control-playground.md, ../operations/gcr-rest-registration.md]
---

# Lightweight flight fleet for granular owner review

## Which craft and materials are available?

**Current experimental desktop source:** `gcr_fleet_playground.tscn` provides the
seven retained flyers in an editable 992×480 room. The original fleet authoring
comes from `f7d611501c18425f7f06f0c874324113da78d8e7`; bringing that authoring
onto the current source does not inherit its old runtime qualification.

| Key | Craft | Intended handling |
| --- | --- | --- |
| 1 | Midge | Tiny nimble microscout |
| 2 | Needle | Fast narrow recon dart |
| 3 | Kestrel | Balanced agile explorer |
| 4 | Afterglow | Hoverboard with strafe and tilt |
| 5 | Surveyor | Broad scientific sampler |
| 6 | Cartographer | Slow-turning terrain scanner |
| 7 | Observatory | Lumbering sensor platform |

Each craft has one actual rectangular Rapier body, no hidden equipment chassis
and default authored mass 0.035..0.32. The collider matches the hull outline;
sensor markings and lift lights add no physical mass. The room contains Sand,
Dust, Rust, Stone, Seed, Salt, Sodium, Gunpowder and Coal banks, stepped entries
and thin upper supports. The palette also offers Water, hard wall and erase.
These are native materials with their existing laws, not special treatment for
yellow Sand alone.

LMB paints, RMB erases and the wheel changes brush radius 2..24. F switches
overview/follow; P pauses. Space remains thrust/lift. Ordinary craft use W/Space
for body-axis thrust, A/D or Q/E to rotate, S for reverse, Shift to brake and C
for upright assistance. Afterglow uses WASD to strafe/rise/descend, Space for a
lift burst and Q/E to tilt. Painting intentionally adds/removes native material;
this room is not a closed conservation fixture.

## How do I compare budgets and physical properties?

The developer panel defaults to **LA, budget 20, mass ×1 and inertia ×1**.
LA admits base budget 5..80, including the requested 20/40/80 comparisons.
The separate **RFT reference** retains the old GCR/R2 response and requires
budget 20. It does not reinterpret an arbitrary budget as the retained reference.

Both multiplier fields admit 0.01..64. For authored mass `m0`, width `w`, height
`h`, mass multiplier `M` and inertia multiplier `I`, construction uses actual mass
`m = m0*M` and actual inertia `m*(w*w+h*h)/12*I`. Inertia therefore scales with
the changed mass before the independent inertia multiplier is applied. These
are visibly experimental actor overrides; they do not rescale detached buildings
or rewrite their payload-derived properties.

Values remain staged until **Apply + reset room**. Applying rebuilds both the
current craft and terrain, discarding painted edits. Keys 1–7, Tab and R also
rebuild the room while retaining the applied comparison values. **Restore flyer
defaults** selects LA/20 and multipliers 1/1. The applied receipt displays actual
mass, inertia, response and budget. Numeric text editing suppresses craft-selection
shortcuts and leased flight input, so typing 40 or 64 cannot select another flyer.
Enter/Escape leaves text editing.

Authored force ceilings 8..28 and torque ceilings 3..82 remain unchanged. The
controller uses the actual physical mass/inertia when forming requests, then
clamps them through those existing limits. Increasing mass can therefore prevent
lift; the panel does not silently increase propulsion to compensate. Neutral
steering still permits passive contact rotation. No collision-only effective mass,
velocity assignment, pose latch or sleeping policy is introduced.

## Who owns the response and reset?

The room retains its synchronous exclusive native owner. Native cells own
material; main-thread Rapier owns the flyer. The existing arena packs one
17-value body sample per intended boundary and applies one accumulated response
through the existing bridge. Painting occurs between owner steps. It does not
add a worker/main-thread ownership path or per-cell physics bodies.

`configure_review_fleet` admits only one human arcadelander carrier and one fixed
fleet index 0..6. The ordinary catalogue mass validator is unchanged. Only the
explicit fleet route can apply the validated developer multipliers, after checking
the exact authored fleet definition and before populating physical properties,
rig mass/inertia caches and the Rapier bridge. Invalid options preserve the
existing live owner. A reset strips copied receipt metadata from the authoring
request and retains the admitted response and options in a fresh owner/epoch.

The LA budget path uses the existing native **GCR-REST/control** token and budget
owner. It supplies no manufactured support/drive context and enables none of
P/R/C/PRC. The RFT reference keeps GCR/R2. A budget is not implemented by multiplying
the final applied impulse. Ordinary gameplay defaults, native material policy,
ejection/correction and sleep remain unchanged.

## What is qualified and what remains open?

This is a playable developer comparison surface, not a new physical acceptance
population. The earlier [88-case qualification](../audits/2026-11-02-gcr-rest-contact-comparison.md)
retains its original source and failures: R/PRC is NO-GO as implemented, P/C never
admits physical quiet contact, and the sweep has no general production winner.
Those rest modes are not exposed here. Painting and varied propulsion do not
convert prior closed-fixture conservation or passive-energy results into claims
about this editable room.

The application extension reuses native SDK source
`181a8257a93f82d64fbeb97e9c413ef52d44f13d`, with its 88 compiled inputs unchanged.
Native runtime SHA256 identities remain Windows
`65c1d2a35134c44aea539a0e8441d66b3b4db92cba7c5477d038b842fe7c889e` and Linux
`8bfe51214643c626dd5800f66ecff86f3348a166b55551e0674d1b4f762cfbf5`.
New GDScript authoring/owner/UI routes require their own source-matched host
checks; old fleet execution is not relabelled as current proof. The focused
controls are `test_gcr_fleet_controls.gd`, `test_gcr_review_fleet.gd` and
`test_gcr_crash_playground.gd`, alongside relevant ordinary actor-host regressions.
Test definitions alone do not establish execution or human feel acceptance.

Launch a source-matched project with
`python tools/experiments/run_gcr_fleet_review.py --project <project>`.
`--identity-only` checks the launcher identity without opening the scene.
PR #351 remains draft and unmerged. Owner acceptance, broad physical qualification,
production/default promotion and sleep remain outside this extension.
