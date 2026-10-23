---
title: Articulated Rapier actors and shared physical control
status: Current
document-kind: contract
scope: Articulated desktop roster with ACT-005 physical equipment and SetP human movement presets, authored mechanics, local scripted control and leased input; sampled references and scientific material acceptance remain separate
canonical-for: [physical-actor-rigs, physical-actor-control-v2, physical-actor-usables]
last-reviewed: 2026-10-22
related-documents: [physical-free-flight.md, actor-usables.md, actor-rigs.md, thunderbowl-control-reference.md, ../operations/physical-actor-programme.md, ../architecture/rigid-body-and-cellular-coupling.md, ../reference/configuration-reference.md, ../reference/interfaces-and-message-contracts.md, ../operations/local-build-and-validation.md, ../audits/2026-10-19-act005-physical-usables.md]
---

# Articulated Rapier actors and shared physical control

## Which actors are physical?

**Current experimental desktop source:** all 29 original actor identities have
articulated Rapier definitions, plus twelve ACT-004 examples in SetX and five
human movement presets in SetP: 46 rigs across eight sets.
The old sampled motors remain explicit reference choices with their original
contracts. Physical actors use the following independent catalogue:

| Set | Physical examples | Principal mechanisms |
|---|---|---|
| SetA | Runner, Skimmer, Crawler | Five-part planted runner; twin-pod vector flight; hinged crawl shoes |
| SetB | Scout, Scrabbler, Ripper, GroundEffect, Digger | Light articulated legs; seven-part tripod; sprung track bogies; cushion skids; rocket boring head |
| SetF | Copter, Pouncer, Dropbot, Lineshank | Teetering rotor; coiling paws and glide fins; wall acrobat; thin blade with weighted grip and bungee |
| SetY | Walljumper, Clamberer, Swinger, Rocketjumper | Contact leaps; folding shoes; hinged hook arm; articulated recoiling blast tube |
| SetU | Springjack, Gyrocrate, Bellows, Winchbug, Magpie, Skatesail | Guided pogo piston; flywheel; sliding bellows plate; winch; clamp; two-hinge sail |
| SetV | Astra / Vector, Claude / Contour, Luna / Pulse, Qwen / Switchboard, Bonsai / Root, Jev / Jolt, Gemini / Duet | Vector bursts; contour motion; brief pulses; ground/flight modes; compact coil; rebound pads; independent thruster pods |
| SetX | Monowheel, Inchworm, Pendulum, Rocker, Hammerhead, Rocketblade, Tandem, Tricopter, Tiltrotor, Heavylift, Needlejet, Gyrosled | Eccentric cab, concertina spine, moving counterweight, rocker feet, held hammer, propelled blade, four distinct multirotor layouts, fast dart and tall gyro sled |
| SetP | Loose Cannon, Trials Rat, Afterimage, Vector Rush, Barrel Rocket | Sprung stunt buggy, trials bike, momentum acrobat with folding joints, arcade lander and jetpack barrel |

The stable SetV IDs remain `astra`, `claude`, `luna`, `qwen`, `bonsai`, `jev`
and `gemini`. They are fictional interface personas; selecting a name does not
call a corresponding model or make a claim about its abilities.

[`physical_actor_catalog.gd`](../../godot/scripts/physical_actor_catalog.gd)
owns the copied part, joint, profile, mount and script definitions, with SetP
authored in [the player catalogue](../../godot/scripts/player_actor_catalog.gd).
Each part has an actual rectangular or declared circular collider with its own
mass, offset and orientation. Graphics use its shape, dimensions and published
transform. Circular wheels retain conservative circumscribed rectangular native
material masks; they do not change the body-sample ABI. A part drawn
as a leg, rotor pod, slider or held object is a live body, rather than a cosmetic
articulation over a sampled hull. One through eight total parts are allowed;
the current authored definitions use one through seven. ACT-005 reuses each
existing held part or adds one permanent jointed equipment chassis during session
preparation, still within eight parts. Held and released equipment keeps its
coupling slot for the lifetime of the actor session.

The [4LY free-flight family](physical-free-flight.md) now adds an ordinary
**F5 → set4LY** selection family with four candidate profiles: Trainer, Hauler,
Drifter and Dart. Original `RIG_IDS` remains exactly 46 and SetP keeps its
existing index; this ninth selection set is additive. All drones share one
physical single-rectangle controller/actuator, with no joints, mounts or
equipment. Explicit no-equipment preparation bypasses ACT-005's usual held
chassis. They differ in authored numeric handling parameters, **not** controller
logic. The 4LY velocity profile strictly admits two world-frame move outputs,
with neutral braking/hover while a lease is live; this does not alter legacy
physical controls, actor IDs or sampled reference meanings. Measured acceptance
is distinct from selectable candidate source.

## How do I select and control them?

F5 in the ordinary sandbox, Blacksite Nine and the four showcase districts
selects a representation, set, actor and keyboard, scripted-demo or external
policy producer. Physical Rapier choices are the default actor route. Applying
rebuilds the selected map at its initial spawn and starts paused. R retains the
selection; changing district uses that district's spawn. Registered scientific
fixtures and Benchmark mode retain their own actors.
The new assembly remains suspended until its matching native reset and initial
hard-terrain colliders are installed, including when Play is requested early.

Physical wire controls are WASD movement, mouse aim, brackets for effort, Q/E
trim, Z/X reel, Space primary, Shift secondary and C auxiliary. M uses the tool,
N releases a held item and U requests nearby pickup. Left/right pointer buttons
use equipment primary/alternate; its aim and power are independent of locomotion.
F5 equipment selection changes a held chassis through the same admitted action.
Exact ability meaning is
displayed from the selected profile. These map to `tool`, `release_usable` and
`attach_usable` in the shared API. These are bounded gameplay
requests; no command writes a transform or assigns velocity as locomotion.
Focus loss, pause, replacement and input cancellation revoke pending actions.

SetP supplies five distinct human movement controllers through the same action
path. Its buggy/bike use vertical movement for throttle and horizontal movement
for lean; the acrobat supplies slides, rolls, bullet/double jumps, cancels and
glide. Full controls and the separate seven-preset keyboard/gamepad course are in
the [player control playground](player-control-playground.md). Its dry/liquid
presets are native material fields and are not members of the Rapier roster.

The retained single-body barrel/Ripper comparison is described separately in
the [physical programme](../operations/physical-actor-programme.md). The current
articulated Ripper is the five-part sprung crawler, not that historical hull arm.
Desktop integration does not migrate the synchronous Web control owner.

## What does plausible physical behaviour mean here?

The owner explicitly chose gameplay emulation: bounded assistance, approximate
connections and controlled flex/play are legitimate mechanics. There is no
requirement to track finite gyro momentum or represent a perfect mechanical
joint. Rapier still resolves actual body motion and contacts.

The [rig runtime](../../godot/scripts/physical_actor_rig.gd) provides:

- Rotary pin joints with optional angle limits, bounded motor targets and
  continuous wheel rotation where declared.
- Endstop-constrained pin-in-slot slides with compliant angular alignment;
  spring variants also use a damped spring. Their residual angular play is
  intentional, rather than a promise of exact prismatic kinematics.
- Damped, bounded gyro assistance with a settled-angle band; command slewing
  avoids abrupt microcorrections without eliminating deliberate bursts.
- Support-conditioned ground propulsion, reactive joint gait, aimed impulses,
  rotor or vector thrust, hover clearance, speed-dependent sail lift and recovery.
- Bounded grip and one straight terrain rope; released bodies preserve motion.
  Ropes have no wrapping or general object-to-object rope simulation.

Ripper is fast and low with slip and strong reversals. Scrabbler uses a three-foot
rhythm and compliant knees. Pouncer deliberately holds a coil before releasing
its leap and unfolds its actual fin joints. Vector and Pulse steer their actual
pod gimbals through bounded joint targets. Digger aims bounded excavation through horizontal or vertical burrows.
Copter retains recoverable instability. Lineshank and Rocketblade concentrate
mass near the grip of a thin blade. Tandem, Tricopter, Tiltrotor and Heavylift
vary lever arms, articulation and mass distribution; Heavylift carries a
suspended payload.

The resource reserve is authored gameplay state. Ordinary powered movement can
replenish a reserve while bursts, gripping and tools consume it. This does not
claim a calibrated energy model. Units, caps and publication capacity belong in
the [configuration reference](../reference/configuration-reference.md#physical-actor-values).

## How do the scripted examples behave?

Every physical entry has a deterministic local feedback producer in
[`physical_actor_script.gd`](../../godot/scripts/physical_actor_script.gd).
It consumes the same copied pose, velocity, contact, local-ray, resource and
attachment observations available to a policy. It cannot read native World,
teleport a body, replenish resources or bypass command admission.

The scripts patrol relative to their starting location, reverse before a target
becomes an asymptotic stopping point, and use actual contact and progress towards
the route to decide when to vault or recover. Vertical bouncing against a wall
and backward shoves do not disguise a stall; intended climbing, winching and
drilling retain their relevant progress directions. A stalled actor gets a
debounced escape attempt. Flyers use
altitude, velocity, ceiling and attitude feedback; Duet pulse-width modulates its
two buttons with collective off periods and an inverted-thrust cutoff. Heavylift
reads its connected payload's pose and velocity, reduces acceleration while it
swings, and applies a bounded correction beneath an outward-moving load. Rope
pilots take up slack from a floor start, pump the observed swing and release during
a useful ascent, while Winchbug favours hauling and damping. Charge actions have
explicit hold/release phases. A resource hysteresis band suppresses expensive
bursts while the reserve recovers.

These are energetic demonstration controllers and useful baselines. They are
not global route planners. A difficult enclosure can still defeat a local
controller; reported obstruction and recovery state allow later policies to
make a different decision. No neural training or live LLM inference is supplied
by ACT-004.

## How do humans and external policies share authority?

[`CyberPhysicalActorSession`](../../godot/scripts/physical_actor_session.gd)
owns the rigs and scripts on the main thread. Its version-2
`physical_wire_action` envelope binds each request to a run, actor, epoch,
monotonic sequence and actually issued observation. Lease expiry is measured
from that observation's simulation tick. Reusing a slot, resuming after a reset,
or receiving a late response does not renew old authority.

Human, demonstration and policy producers use the same normalized action and
actuator path. The session validates producer ownership, numeric types,
finiteness, known fields and source freshness. The API publishes copied parts,
joints, capabilities, actuator response and lifecycle state. This is a distinct
physical interface; the sampled v1/v2 rows and four-channel metal experiment are
not silently reinterpreted as arbitrary articulated actions.
Faulted rigs report suspension and refuse new commands explicitly.

Cancellation clears stored launch intent, pending effects, ropes and temporary
grips through the owner. It is not a deliberate charged release and does
not erase physical velocity. Reset/close retires the bodies and joint graph.
Long-latency decision models should issue tasks through fresh local feedback;
ACT-004 provides a bounded action consumer, rather than an asynchronous model
service. Exact envelope and step boundaries are linked from
[interfaces](../reference/interfaces-and-message-contracts.md#physical-actor-control-and-effects).

## Which usable examples exist?

**Current experimental ACT-005 source:** the entire
[U01-U32 catalogue](actor-usables.md) is selectable on physical equipment. Every
rig has a defined default loadout in
[`physical_usable_loadouts.gd`](../../godot/scripts/physical_usable_loadouts.gd).
Each loadout names its usable, power, strategy and purpose; no physical actor
is left with an unspecified equipment policy. SetP explicitly starts with an
empty mount and human movement strategy; F5 can still select ordinary equipment.

Mount definitions bind a specific host/held part, grip, joint, aiming limits and
clearance. The equipment owner aims the actual configured joint when it supports
aiming. The shot direction comes from the current held body's pose; a limited
joint cannot acquire an unlimited virtual muzzle. The suspended payload, hammer
and blade preserve their authored mechanical roles. A selection change retools
the existing held chassis without allocating another body.

Release clears the held connection and retains the same object, pose, velocity
and body ID. A short collision grace ages with physical time even after input
cancellation. Pickup checks the owning grip's proximity and terrain clearance;
it does not teleport the object or reset its velocity. An already held, remote,
occluded or ambiguously owned item is refused. A released chassis must return
before it can select another usable.

Processors are deployed by dropping that real body, waiting for supported
settling, and fixing it at its current pose. A worker receipt admits processing;
blocked output leaves recipe inputs and stock unchanged. The body and its
rotated intake/output ports remain visible while it works, jams or exhausts.
Physical pickup retires processing authority. See the
[processor contract](actor-usables.md#u23u32-fixed-functional-objects).

The main-thread owner applies recoil once for the matching admitted use. Native
material effects use copied physical source/part information under worker
ownership. Protected cells, foreign part occupancy, bounds and source clearance
remain checked. The physical command, worker admission and changed-cell receipt
are separate results; a valid command does not guarantee an unobstructed effect.
Late receipts are fenced by run, actor, control generation, equipment epoch and
request identity. The older ACT-004 direct mount/effect fixtures retain their
bounded deposit/cut/rocket-charge substrate for regression; it is not a second
unleased policy API for the full catalogue.

### How do the scripted actors use their loadouts?

[`physical_usable_script.gd`](../../godot/scripts/physical_usable_script.gd)
adds a copied-observation equipment policy to the existing movement controller.
It waits for current readiness, aims at local material targets, spaces shots,
uses flight/stability windows, and handles deployment/recovery through ordinary
actions. Its diagnostics expose use attempts, deployment/pickup observations,
refusals and the current phase. They do not stand in for actual result receipts.

| Representative actors | Default equipment | Demonstration |
|---|---|---|
| Digger / Scrabbler | Rotary Borer | Near-contact excavation during route obstruction |
| Crawler | Powder Vacuum | Selective local powder removal |
| Ripper / Hammerhead | Borer Round / Sticky Delay Charge | Penetrating or delayed breaching |
| Copter / Tricopter / Tiltrotor | Sticky Delay Charge / Timer Airburst / Oil Igniter | Downward payloads during a controlled flight pass |
| Heavylift / Winchbug | Stone Grinder / Brine Splitter | Carry, lower, deploy, inspect and recover processor equipment |
| Vector / Jolt | Timer Airburst / Ricochet Pellet | Vigorous motion with distinct firing and recovery intervals |
| Gyrocrate / Magpie | Stone Grinder / Metal Reclaimer | Ground delivery and processor servicing |
| Runner / Monowheel | Brick Stamper / Sand Scatter | Short deposition bursts along a moving route |

These remain local demonstration policies. They cannot create recipe inputs,
clear a jam by directly editing cells, refill charge/stock, or guarantee delivery
in every enclosure. The usable course supplies observable material conditions
for automation and human inspection; a global planner remains separate work.

## What has been qualified?

The [dated ACT-004 record](../audits/2026-10-18-act004-articulated-actors.md)
separates structural/producer tests, real Rapier motion, native material tests,
desktop integration and hosted checks. The physical arena has its own versioned
scope in the [Thunderbowl reference](thunderbowl-control-reference.md#physical-thunderbowl-v2).
The [ACT-005 checkpoint](../audits/2026-10-19-act005-physical-usables.md) separately
records full-catalogue integration, lifecycle/controller tests and its acceptance
status; ACT-004's earlier results do not certify changed equipment code.
The [player playground record](../audits/2026-10-20-player-control-playground.md)
separately scopes the five added rigs, controllers, circle approximation and
native material fields; earlier 41-rig evidence does not qualify those additions.
Headless fixture success is not owner feel acceptance or a Windows/browser play
result. Generic granular behaviour remains with #83, reversible soliding with
#12, and the Water successor programme retains its independent evidence gates.
