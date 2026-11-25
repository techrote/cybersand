---
title: 4LY physical free-flight and assisted velocity control
status: Current
document-kind: contract
scope: Shared single-chassis flight plant, strict two-output control, four 4LY-002 handling candidates and ordinary-game selection; measured calibration and downstream flight lab/policy qualification are separate
canonical-for: [physical-free-flight, 4ly-programme, 4ly-assisted-velocity-control]
last-reviewed: 2026-10-23
related-documents: [physical-actor-rigs.md, ../operations/physical-actor-programme.md, ../architecture/rigid-body-and-cellular-coupling.md, ../reference/interfaces-and-message-contracts.md, ../reference/configuration-reference.md, ../operations/local-build-and-validation.md, ../reference/status-and-roadmap.md]
---

# 4LY physical free-flight and assisted velocity control

The separately owned [4LY-003 flight lab and episode contract](physical-flight-lab.md)
extends this unchanged physical plant with an in-game native/Rapier lab,
copied policy observations and an observation-only teacher candidate.
[Its source-bound checkpoint](../audits/2026-10-23-4ly003-checkpoint.md)
is **not** a scored teacher or neural-policy admission. All four
`candidate_4ly002` profile identities remain frozen.

## What does 4LY-001 implement, and which 4LY-002 drone profiles can I select?

**Current experimental source, [4LY-001 / #205](https://github.com/techrote/cybersand/issues/205):**
one shared physical plant and bounded velocity controller for the stable IDs
`4ly_trainer`, `4ly_hauler`, `4ly_drifter` and `4ly_dart`.
**Current 4LY-002 implementation candidate (#206):** these four IDs now have
distinct numerical profiles, each using exactly the same controller and
single rectangular body. F5 has a separately named **set4LY** appended after
the established eight sets. The original 46 entries in `RIG_IDS` and the
original SetP indices are unchanged. Available hosts are the ordinary sandbox
and the existing Play/exploratory maps with a physical F5 actor selector;
protected Benchmark/scientific fixtures still refuse actor replacement.
The physical Skimmer already supplies articulated twin-pod vector flight;
4LY adds a simpler training topology through the same physical owner.

The source owners are the validated
[profile schema](../../godot/scripts/physical_flight_profile.gd), pure
[velocity controller](../../godot/scripts/physical_flight_controller.gd),
[catalogue](../../godot/scripts/physical_actor_catalog.gd) and shared session/rig.

Trainer preserves its validated 4LY-001 physical-conformance defaults.
Hauler, Drifter and Dart are different **candidate** handling plants: the largest
Hauler has lower speed, acceleration and slower response; Drifter has reduced
translation braking and passive drag while retaining upright torque; the
smallest Dart has higher speed, acceleration and braking. No hidden
profile-specific navigation code exists. `calibration = candidate_4ly002` is deliberately retained as part of the
measured source's four profile hashes. The candidates have now **passed**
prospectively registered real Rapier manoeuvre thresholds on both Linux
and Windows at implementation head `f7721a1...`; that result does not
by itself grant owner-feel or learned-policy admission. Exact resolved
values are in the [configuration reference](../reference/configuration-reference.md#physical-free-flight-values).
The [pre-registered numeric thresholds](../../godot/tests/fixtures/4ly002_handling_thresholds.json)
and [actual fixture](../../godot/tests/test_physical_flight_handling.gd)
are supported by the source-bound [qualification record](../audits/2026-10-23-4ly002-measured-handling-qualification.md).

Implementation, measured handling, useful learned navigation and owner feel
acceptance are separate claims. Source presence does not qualify a policy or
certify an unmeasured platform. Focused reproduction commands are in the
[build guide](../operations/local-build-and-validation.md#physical-free-flight-checks).
The [dated conformance audit](../audits/2026-10-22-4ly001-physical-free-flight.md)
records the actual Linux measurements, corrected failures and exact-head hosted
gate handoff separately from the contract.

## What can an ordinary player or external producer do with the new family?

Open **F5 → set4LY → Trainer / Hauler / Drifter / Dart** in the regular
sandbox or an exploratory Play host. Select the keyboard, scripted-demo or
external-policy source and Apply. This resets the authored map and creates a
fresh matching Rapier chassis at that host's spawn; it never converts the
old body's live mass, inertia or collider. **WASD** submits only the admitted
world-frame horizontal/vertical `move` request. Releasing the keys sends
authorized neutral; focus/menu/input cancellation retires authority and
falls back to passive physical behavior. **R** resets the retained selection.
The visible F5 button reports the selected profile, producer, current flight
mode and a tooltip with the lease/fallback and resolved profile hash.
The selection panel shows movement, assistance, reset and empty-loadout
semantics. Equipment choice and equip-only requests are disabled and
independently refused at the host for all four flight profiles.

The same session accepts the demo's current neutral request and the
external policy's already-defined version-2 wire action. A demo source here
is a *neutral conformance producer*, not a qualified navigation teacher.
The four-drone family shares the session controller, force/torque actuator,
contact owner and observation schema. No extra policy steering, training
fast-path, Web ownership change, scientific fixture substitution, or
unmeasured browser/platform qualification is implied. It may be selected
with the ordinary multi-NPC demonstration checkbox, one body per drone.

Collider-aligned rendering uses the real bridge's transform and rectangle
dimensions. A small thrust mark shows the **applied** controller force and
an intent mark shows the requested desired velocity, only while an admitted
lease is live. Neither mark drives a pose, changes the force budget, or
reconstructs a second motion trajectory.

## How are the four handling candidates compared?

A separate deterministic actual-Rapier suite uses a common 60 Hz step,
fresh unsupported body at the same start, identical normalized velocity
commands, equal-speed external impulse/braking comparison (20 cells/s),
passive power-off coasting, a real static wall, and angular recovery.
It records onset, velocity at fixed ticks, neutral stop time/distance,
reverse crossing, ascent/descent, torque response, force saturation, common
speed braking/coast, wall contacts and body penetration. The exact source
of thresholds is
[`4ly002_handling_thresholds.json`](../../godot/tests/fixtures/4ly002_handling_thresholds.json),
committed before running the qualification fixture; the reproduction command
and host gates are listed in the
[local build guide](../operations/local-build-and-validation.md#physical-free-flight-checks).

The proposed numeric criteria require: Hauler speed at 60 equal normalized
steps no more than 85% of Trainer; Dart at least 120% of Trainer; Drifter
common-speed stopping distance at least 125% of Trainer, along with
per-profile hover, manoeuvre, upright and contact limits. These **prospectively registered criteria have passed** at the
measured source/physics identity documented in the
[4LY-002 qualification audit](../audits/2026-10-23-4ly002-measured-handling-qualification.md).
The first Windows attempt's unrelated timeout is retained separately
from the successful rerun. Any future profile/physics edit changes source
identity and requires new qualification. A new hosted graphical
gameplay-capture fixture is being validated for descriptive screenshots;
target-PC owner feel, Web and multi-agent learning remain unmeasured.

## Who owns the chassis, contacts and equipment?

The shared [rig](../../godot/scripts/physical_actor_rig.gd) creates one actual
rectangular `RigidBody2D` with authored mass/inertia, gravity, passive drag and
real contacts. There are no rotor bodies, payload joints, mounts or mandatory
equipment. The explicit empty loadout and no-equipment preparation path prevent
ACT-005 from silently adding its usual held chassis. An empty usable selection
on a legacy actor remains a different contract: it can still retain its physical
equipment chassis.

The existing main-thread [session](../../godot/scripts/physical_actor_session.gd)
and [Rapier bridge](../../godot/scripts/rapier_physics_bridge.gd) retain live-body
ownership, manual stepping, copied rectangular body publication and native
material coupling. Graphics use the same collider dimensions and published
physical transform. There are no per-cell physics bodies, transform-driven
locomotion, position snaps, direct velocity assignments, erased contacts or
ground-clearance forces. Free flight does not depend on a supporting surface.

The [generic coupling contract](../architecture/rigid-body-and-cellular-coupling.md)
still owns occupancy, hard-terrain contact, bounded native material response and
their known limits. 4LY neither changes Water behavior nor closes generic-body,
granular or soliding acceptance.

## How do two policy outputs become bounded flight?

The policy supplies only desired horizontal and vertical velocity through the
existing version-2 `physical_wire_action` envelope. This profile admits exactly
the `move` action field: a `Vector2` or an array of two finite numeric components
in `[-1, 1]`. Components outside that range, unknown fields and nonfinite values
are rejected. An admitted diagonal is normalized to the unit disk, then scaled
by the profile's axis speed limits. World `+x` is right and `+y` is down; one
world pixel is one cell and speed is cells per second. The
[interface reference](../reference/interfaces-and-message-contracts.md#physical-free-flight-actions)
owns exact packet and publication fields.

At each fixed physical step the local controller compares desired and sampled
velocity. It applies declared acceleration or braking limits, includes gravity
compensation in the same requested thrust vector, saturates its total magnitude
and applies bounded response/slew. Attitude correction supplies a separately
bounded torque toward the authored upright attitude. These are authored game
mechanics in adapter units; no calibrated SI propulsion or finite flywheel
momentum model is implied. Exact defaults and limits live in the
[configuration reference](../reference/configuration-reference.md#physical-free-flight-values).

Gravity compensation consumes the available thrust budget. When thrust cannot
support the chassis, an admitted zero-velocity request cannot hold it aloft.
There is no hidden integral state to accumulate unreachable demand. Desired
speed limits constrain requested motion; they do not clip velocity introduced
by collision or an external impulse. The 4LY path does not add the legacy
extreme-motion brake or a second gyro after the declared controller budget.
Passive drag and actual contact/material forces remain physical influences.

## Can the stabilizer see a target or secretly navigate?

The shared stabilizer receives the normalized motion request, sampled linear
velocity, angle and angular velocity, its copied resolved profile and fixed
step duration. It receives no goal, route, obstacle map, ground-clearance query,
reward, evaluator outcome or mutable World access. Its output is force/torque
and copied diagnostics. Identical admitted inputs produce identical assistance
regardless of world position or a producer's private goal.

Human, scripted and policy producers submit through the same session admission
and actuator path. Goal selection and route behavior belong to those producers.
The current 4LY demo supplies an admitted zero-velocity conformance request every
six physical ticks. It is not a flight teacher. A later producer may use its own
copied observations to choose a velocity request; that does not give the local
stabilizer navigation authority. A qualified flight teacher and actual-host
episode interface belong to 4LY-003.

## Who confirms that physics consumed the request?

The rig installs force and torque in its owned constant-force channel for one
manual Rapier step, so sustained thrust participates in the solver's force
integration. The host then calls `Session.complete_step`, which clears the
channel and publishes the resulting motion. A fixture which owns a rig directly
must call `Rig.complete_step` after its bridge step. Cancellation can remove
prepared, unconsumed force without reversing already integrated motion.

A session containing 4LY checks the bridge's actual manual-step counter. It
admits one preparation for the next physical step and only records completion
after that step occurred. Duplicate preparation or completion without physics
is refused without advancing the controller/session clock. Extra or unprepared
physics steps, preparing again before completing an already executed step, or
physics advancing during suspension produce a sticky `flight.step_fault` and
suspend the session until replacement. A normal pause cannot issue command
authority; resume fences same-tick paused views before a fresh observation.

The prepared receipt snapshots the original run, actor, epoch, producer,
generation, sequence, source tick, action and controller response. If
cancellation or takeover follows the physical step but precedes the host's
completion call, that completed receipt retains its original attribution.
Cancelled preparation which physics never consumed creates no completed-step
receipt. The [interface reference](../reference/interfaces-and-message-contracts.md#physical-free-flight-actions)
owns exact receipt fields.

## How do neutral, cancellation, power-off and suspension differ?

| State | Assistance and authority |
|---|---|
| Admitted nonzero `move` | Track desired velocity within bounded force/torque and response limits while the source-observation lease remains valid |
| Admitted zero `move` | Physically brake toward zero velocity and approximately hover while thrust permits; no world-position target is stored |
| No command, cancellation or lease expiry | Passive fallback: discard the request and response state, apply no propulsion/stabilizing torque, and retain physical momentum and gravity |
| Explicit propulsion disabled by the host | Apply no propulsion or stabilizing torque; a fresh command cannot override the host switch |
| Lifecycle suspension | Retire pending command authority and stop further physical steps; a physical step completed just before suspension can still be accounted, and resume requires fresh authority |
| Fault quarantine | Revoke current command and assistance, mark suspension, and preserve the last finite physical sample for diagnosis |
| Reset, close or replacement | Retire the old incarnation, controller response state and command history; old replies cannot act on the replacement |

The fallback mode and lease state are published explicitly. Passive fallback
does not claim a fresh external zero-velocity command. Enabling propulsion is
not a policy output and does not revive a retired lease. Cancellation, reset and
power cutoff immediately clear force/torque response; the ordinary enabled slew
limits do not delay this removal of authority. The initial profile declares no simulated fuel tank or
energy-depletion timer, so stationary authorized hover is not defeated by an
undocumented resource countdown. Power/thrust limits remain effective.

The session retains run, actor, epoch, monotonic sequence, actually issued
observation, control generation, producer and lease fencing. Expiry remains
relative to the source observation's tick, not command arrival. Cancellation
invalidates previously issued observations. The completed tick which reaches a
flight lease's deadline retires it before another reply can reuse that old
observation. Reusing a slot or resuming cannot renew stale authority. Copied
views cannot mutate live tuning or controller state.

## Which identities and observations may a capture claim?

The resolved, versioned profile covers collider dimensions, mass/inertia,
gravity reference, friction/restitution, desired-speed mapping, acceleration/braking/total-thrust
limits, response and slew, passive linear/angular drag, attitude gains/torque
and declared resource semantics. Validation occurs before body allocation.
The copied capability descriptor publishes profile and controller identities
and hashes; retain these with source/runtime identity when exporting evidence.
Matching a profile name alone does not establish compatible tuning or code.

Requested action, admitted normalized action, desired velocity, requested and
applied assistance, saturation/response state and sampled physical motion are
separate publications. Applied assistance describes this actuator's bounded
contribution. It is not a decomposition of Rapier gravity, passive damping,
contacts or delayed native material response; no unavailable passive-force
breakdown or total physical energy accounting is claimed.

`flight.command` identifies the accepted raw/admitted command; `command_live`
states whether it currently has lease authority. `flight.applied` identifies
the sequence and step tick associated with the current actuator receipt. The
separate `flight.last_step` preserves the most recently completed commanded
step's admitted action and controller receipt, including its original producer,
control generation, sequence, source tick, session step tick and physical step.
Cancellation clears current command/assistance publication while retaining that
labelled historical step until replacement or close. Neither a stored history
entry nor a newly accepted command proves that another physical step occurred.
The top-level applied impulse fields account for this actuator's force or
torque multiplied by the admitted step duration; they do not describe a
pre-step impulse motor or the sum of all forces on the body.

The 60 Hz physical cadence and existing six-tick decision interval are
separate from the command lease. A missed fresh decision does not manufacture
neutral input or renew authority: an already-live lease may continue only to its
original deadline, where the completed physical tick retires it into passive
fallback. Any later fresh command still requires a newly issued observation and
sequence; an old observation cannot prolong its command by being submitted late.

## What follows this implementation checkpoint?

| Stage | Owner | Deliverable and dependency |
|---|---|---|
| 4LY-001 | [Cybersand #205](https://github.com/techrote/cybersand/issues/205) | Shared physical chassis/controller, versioned profile/action contract and conformance fixtures |
| 4LY-002 | [Cybersand #206](https://github.com/techrote/cybersand/issues/206) | Author and freeze four distinct handling profiles, expose ordinary-game selection and measure their differences |
| 4LY-003 | [Cybersand #207](https://github.com/techrote/cybersand/issues/207) | Flight lab, actual-host episodes, scripted teacher and physical qualification using 4LY-002's frozen profiles |
| 4LY-004 | [neural-cyber-automata #74](https://github.com/techrote/neural-cyber-automata/issues/74) | Adapter conformance and bounded Trainer-only learning after accepted host/profile/teacher qualification |
| 4LY-005 | [neural-cyber-automata #75](https://github.com/techrote/neural-cyber-automata/issues/75) | Capability-conditioned family policy and per-profile deployment evidence after an independently verified passing Trainer result |

4LY-002 has authored selectable candidate profiles and now has passing
real-Rapier physical envelopes for all four at the measured executable
identity. The [source-bound measurement manifest](../audits/4ly002-2026-10-23/measured-handling.json)
fixes the four observed profile hashes, while human-feel approval, final
revised-head acceptance and later policy admission remain separate.
4LY-003 may use those envelopes for preparatory flight-lab/teacher work;
its *final* host evidence must first verify the actually merged profile,
controller and runtime identities. No learning allocation follows from
this source-level handoff. Neither an
implementation merge nor issue creation authorizes a learning allocation or
substitutes for the Trainer performance gate. Learner implementation and learned
policy evidence belong in the companion repository; its
[training/evaluation contract](https://github.com/techrote/neural-cyber-automata/blob/main/docs/design/TRAINING_AND_EVALUATION.md)
retains its independent authority.

The handoff to 4LY-002/003 is the resolved unit/cadence contract, strict admitted
action, copied publication fields, validated profile schema and hashes, passive
fallback semantics and conformance fixtures. General calibration, broad
traversal, human feel, browser execution, raw-thrust learning, additional brake
outputs, articulation and multi-agent behavior remain outside 4LY-001.
Long-lived representation parent [#132](https://github.com/techrote/cybersand/issues/132)
remains open; this lane does not change Jolt or morphology qualification gates.
