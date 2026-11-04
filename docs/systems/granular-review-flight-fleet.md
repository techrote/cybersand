---
title: Lightweight flight fleet for granular owner review
status: Current
document-kind: contract
scope: Developer-only editable flyer room with staged LA budget and actuator controls, bounded material dispensers and optional real Fire; retained RFT reference and separate qualification limits
canonical-for: [granular-review-flight-fleet]
last-reviewed: 2026-11-03
related-documents: [../architecture/granular-contact-rest.md, ../architecture/compound-granular-coupling.md, player-control-playground.md, ../operations/gcr-rest-registration.md]
---

# Lightweight flight fleet for granular owner review

## Granular-only event comparison — November4

The [registered event successor](../operations/gcr-granular-events-registration.md)
adds **LA · events OFF (experimental)** to EXPERIMENTAL RESPONSE. Select it and
use **Apply + reset room**; this discards painted edits. It omits only granular
blocked-attempt impulses/torque/cost before passive recomputation. The legacy
contact gain and material laws remain. LA remains initial/Restore; RFT remains
the fixed20 reference. All existing physical and actuator controls are retained.

The [source-matched qualification](../audits/2026-11-04-gcr-granular-event-successor.md)
finds much less burial in Sand/Salt/Dust and the powered bank, with passing tested
barrel impact guards. Falling grains produce no measured translation/rotation
in the candidate control, and some late motion increases. The panel tooltip
flags this loading/torque gap, shows verified native source/binary and a room
script fingerprint, and refuses event-off construction on an old runtime that
cannot acknowledge the selector. Owner review remains pending. This is an
independent-flyer comparison; current Astra compound response is separately owned.

The [dated host qualification](../audits/2026-11-02-flyer-budget-playground.md)
records the current tested application checkpoint, retained failures and native
SDK reuse separately from earlier physical qualification.
The [actuator/navigation follow-up](../audits/2026-11-02-flyer-actuator-limits-and-navigation.md)
records thrust/torque controls, F2 return routes and the cropped burrowing evidence.
The [November3 host record](../audits/2026-11-03-paired-material-plan-and-fleet-emissions.md)
binds side-thruster, dispenser and Fire controls to the tested application source.

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
for body-axis thrust, A/D to rotate, S for reverse, Shift to brake and C for
upright assistance, with the Kestrel S exception below. Afterglow uses WASD to
strafe/rise/descend, Space for a lift burst and Q/E to tilt. Painting and
dispensers intentionally add/remove native material; this room is not a closed
conservation fixture.

## What do Q/E, Kestrel S and the Fire toggle do?

**Current experimental desktop source, 2026-11-03:** the room adds these
craft-specific controls. Left/right are relative to the craft's body axes, so
the ports rotate with the hull.

| Craft | Q | E | S |
|---|---|---|---|
| Midge | Left Acid dispenser | Right Lava dispenser | Reverse thrust |
| Needle | Left side thrust | Right side thrust | Reverse thrust |
| Kestrel | Left side thrust | Right side thrust | Gunpowder dispenser |
| Afterglow | Retained deck tilt | Retained deck tilt | Descend |
| Surveyor | Left side thrust | Right side thrust | Reverse thrust |
| Cartographer | Left Water dispenser | Right Water dispenser | Reverse thrust |
| Observatory | Left Lava dispenser | Right Lava dispenser | Reverse thrust |

Needle, Kestrel and Surveyor request lateral acceleration at 0.65 of the selected
craft's authored acceleration. Main thrust, side thrust, drag and brake requests
share the existing combined force ceiling; side thrust does not add another
impulse budget. A/D still supplies yaw. Kestrel S no longer requests reverse
thrust; W+S can fly forward while dropping Gunpowder. Both Q and E dispenser
ports can be held together without cancellation by the signed steering axis.

**Thrusters emit real Fire** is a live developer checkbox, initially off. Its
selection survives room reset and craft selection. It adds ordinary native Fire
from active main/side thrusters when the controller has nonzero applied force,
positive effort and a nonzero thrust ceiling. It does not change force or torque,
create new chemistry, or enable Fire merely because brake/hover assistance is on.
Turning the option off stops new emission; existing Fire follows its normal law.

Dispensers are bounded native material sources without added recoil: at most
three one-cell, radius-zero emissions every six simulation ticks. Blocked or
missed opportunities do not accumulate into a later burst. A bounded direct ray
must be clear after leaving the source body's mask; foreign masks, occupied cells
and terrain block the nozzle. The target must still be Empty and unmasked at the
write boundary. There is no relocation search, overwrite or excavation to clear
a nozzle. These checks do not turn an actor emitter into a material-law owner.

Emission ports inherit the accepted actor command's epoch, sequence, generation
and lease. Cancellation, expiry, focus loss, numeric editing, pause and room
replacement stop emission through the existing input lifetime. Held dispenser
keys must be released before rearming after focus/edit/pause cancellation. This
room-only port path does not extend the ordinary actor action ABI or equipment
catalogue. Sources: [controller](../../godot/scripts/gcr_review_fleet_controller.gd),
[emitter](../../godot/scripts/gcr_review_fleet_emitter.gd),
[arena admission](../../godot/scripts/physical_actor_arena.gd) and
[room input](../../godot/scripts/gcr_fleet_playground.gd).

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
defaults** selects LA/20 and all multipliers 1. The applied receipt displays actual
mass, inertia, response, budget and controller caps. Numeric text editing suppresses craft-selection
shortcuts and leased flight input, so typing 40 or 64 cannot select another flyer.
Enter/Escape leaves text editing.

The **Thrust limit × authored** and **Torque limit × authored** fields independently
admit 0..64, default1. They multiply each selected craft's authored force ceiling
8..28 and torque ceiling3..82; omitted options retain1 for API compatibility.
Zero thrust disables the controller's combined linear request, including braking
and hoverboard gravity compensation. Zero torque disables its turning/leveling
request. Gravity, material reactions and existing extreme-motion safeguards remain.
The controller uses actual mass/inertia to form requests before applying these
caps. Acceleration, angular acceleration, speed and effort targets stay authored;
raising a ceiling alone does not raise those targets. The rig's existing per-call
impulse guards remain `mass*100` and `inertia*4`, with separate extreme-motion
safety braking above speed300 or angular speed24. These are not material laws.
Increasing mass can prevent lift until sufficient propulsion is available. Neutral
steering still permits passive contact rotation. No collision-only effective mass,
velocity assignment, pose latch or sleeping policy is introduced.

## How do I return after F2?

In the updated desktop launcher, choose **GRANULAR OWNER REVIEW / experimental**
near the top, then **Granular barrel comparison**, **Structural cut / support
tests**, or **Flyer playground + painting**. Each replaces the old scene through
the existing owner teardown path. These source-matched developer routes are
hidden/refused in Web demo policy. Older running builds must be reopened to gain
the new menu entries.

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

The [focused creep investigation](../operations/gcr-creep-registration.md)
separates neutral controller input, zero actuator ceilings and powered movement.
Neutral input can still request drag. Controller force and rig impulse telemetry
describe bounded requests; `_apply_rig_impulse` can record a request before the
per-part tiny-impulse guard suppresses backend delivery. Do not infer actual
force delivery from exhaust, controller requests or that rig accumulator alone.
The investigation's single-hull same-phase velocity difference measures delivery
before the native wrench and Rapier integration, with rig safety participation
reported separately. Its dynamic-bank and quiet flat-bed results have distinct
scope; neither is a general sleep or friction acceptance result.

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
The new side-thrust/emitter/input paths likewise require their own dated
source-matched execution; the 2026-11-02 records do not attest the 2026-11-03
extension.

Launch a source-matched project with
`python tools/experiments/run_gcr_fleet_review.py --project <project>`.
`--identity-only` checks the launcher identity without opening the scene.
PR #351 remains draft and unmerged. Owner acceptance, broad physical qualification,
production/default promotion and sleep remain outside this extension.
