---
title: Articulated Rapier actors and shared physical control
status: Current
document-kind: contract
scope: ACT-004 desktop physical roster, authored mechanics, local scripted control, shared input and usable lifecycle; sampled references and scientific material acceptance remain separate
canonical-for: [physical-actor-rigs, physical-actor-control-v2, physical-actor-usables]
last-reviewed: 2026-10-18
related-documents: [actor-rigs.md, thunderbowl-control-reference.md, ../operations/physical-actor-programme.md, ../architecture/rigid-body-and-cellular-coupling.md, ../reference/configuration-reference.md, ../reference/interfaces-and-message-contracts.md, ../operations/local-build-and-validation.md]
---

# Articulated Rapier actors and shared physical control

## Which actors are physical?

**Current experimental desktop source, ACT-004 / #178:** all 29 existing actor
identities have articulated Rapier definitions, plus twelve examples in SetX.
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

The stable SetV IDs remain `astra`, `claude`, `luna`, `qwen`, `bonsai`, `jev`
and `gemini`. They are fictional interface personas; selecting a name does not
call a corresponding model or make a claim about its abilities.

[`physical_actor_catalog.gd`](../../godot/scripts/physical_actor_catalog.gd)
owns the copied part, joint, profile, mount and script definitions. Each part is
an actual rectangular collider with its own mass, offset and orientation. Filled
polygons use that collider's dimensions and published transform. A part drawn
as a leg, rotor pod, slider or held object is a live body, rather than a cosmetic
articulation over a sampled hull. One through eight total parts are allowed;
the supplied examples use two through seven. Held parts count against the same
limit.

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
N releases a held item and U reattaches a nearby item. Exact ability meaning is
displayed from the selected profile. These map to `tool`, `release_usable` and
`attach_usable` in the shared API. These are bounded gameplay
requests; no command writes a transform or assigns velocity as locomotion.
Focus loss, pause, replacement and input cancellation revoke pending actions.

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

Mount definitions include their owning part, local offset, aiming limits,
clearance, recoil and cooldown. The catalogue includes mounted Sand depositors
and cutters, Vector's off-centre recoiling launcher, and articulated held
examples such as Rocketjumper's tube, the thin blades, Hammerhead and Heavylift's
payload. Release disables the held connection while retaining the physical
object; reattachment requires the runtime's bounded proximity checks.

Recoil is applied by the main-thread physical owner. The cellular owner alone
consumes copied material-effect requests, validates epoch/sequence/source
identity and traces clearance. Wall, foreign body masks, world bounds and
noneditable cells remain protected. Ordinary deposition initially uses Sand.
Rocketjumper's named charge pattern places a Fire centre and a Gunpowder ring
only in permitted empty cells; its propulsion remains an explicitly bounded
actor action. Actual changed-cell receipts are distinct from requested effects.
The desktop's bounded effect queue admits an entire incoming batch or reports a
refusal with copied capacity counters; a saturated queue cannot silently accept
only the first few requests. Queue admission is distinct from actual cell edits.

This is a working mount/effect substrate with a few authored tools. The separate
32-usable artwork request does not imply that 32 functional inventory items,
ballistic projectile systems or arbitrary material processors are implemented.

## What has been qualified?

The [dated ACT-004 record](../audits/2026-10-18-act004-articulated-actors.md)
separates structural/producer tests, real Rapier motion, native material tests,
desktop integration and hosted checks. The physical arena has its own versioned
scope in the [Thunderbowl reference](thunderbowl-control-reference.md#physical-thunderbowl-v2).
Headless fixture success is not owner feel acceptance or a Windows/browser play
result. Generic granular behaviour remains with #83, reversible soliding with
#12, and the Water successor programme retains its independent evidence gates.
