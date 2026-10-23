---
title: Runner IK physical joint-target pilot
status: Current
document-kind: contract
scope: ACT-IK-001 opt-in five-part physical Runner, strict source-bound joint reference owner and actual Rapier receipts; no accepted NCA learned model, published build, or physical performance qualification
canonical-for: [physical-runner-ik-host]
last-reviewed: 2026-10-23
related-documents: [physical-actor-rigs.md, physical-free-flight.md, ../reference/interfaces-and-message-contracts.md, ../reference/configuration-reference.md, ../architecture/data-ownership-and-lifetimes.md, ../operations/local-build-and-validation.md, ../audits/2026-10-23-act-ik-001-development-admission.md]
---

# Runner IK physical joint-target pilot

## Which Runner is controlled?

**Current experimental source, not yet qualified on a published host:** ACT-IK-001
[#210](https://github.com/techrote/cybersand/issues/210) adds a separate
opt-in `ik_pilot: true` admission to
[`CyberPhysicalActorSession`](../../godot/scripts/physical_actor_session.gd).
The only supported model is `runner`, with explicit `usable_index: -1`.
The ordinary Runner continues to have its permanent ACT-005 equipment body,
its equipment-grip joint, its abilities and `physical_wire_action/v2`.
The IK pilot instead reuses the physical Runner's original **five** parts and
**four** Rapier rotary joints, retains their original mass, geometry,
collisions, limits, grounding and momentum, and never constructs an equipment
body or mount. This is not a freeze, a new morphology, a render-only skeleton
or replacement of the legacy controls.

The immutable external target is
[NCA's `runner-right-sole@1` descriptor](https://github.com/techrote/neural-cyber-automata/blob/main/src/nca/ik/runner_right_sole_v1.json),
historically derived from Cybersand source
`f2e34cf9b6fbaa5d9dedf9aa2cbc721a87472497`. Its descriptor file
SHA-256 is
`76fd5e0a481e628f30fe2fb55d62eb5cc66014be07c13a5b7720d30e792d2c65`;
its NCA profile semantic SHA-256 is
`6cb15832e240f82f4bcd582d2c26015ef986e44f335da683abaf9746e31503c4`.
Current Cybersand source must not silently rebase that historical descriptor:
the prepared equipment-free host assembly is independently checked for all
five part identities, initial poses, masses and four joint anchors, limits and
motor parameters. Mismatch refuses the pilot.

The part order is `chassis, leg_-1, foot_-1, leg_1, foot_1`; joint order is
`hip_-1, ankle_-1, hip_1, ankle_1`. Only `hip_1, ankle_1` receive externally
requested positions. The left joints are passive **as motors** under this
owner, not frozen bodies; they still exchange contact and constraint forces.
The point effector is `right_sole` at `foot_1` local point `(0,1)` cells.
Its orientation is diagnostic, not an independent control axis. Source
comparisons must use the wrapped rest-relative rotary angle, not absolute
body rotation or a world-space toe target.

## Who owns each reference?

**Current source interfaces:** the main-thread
[`CyberPhysicalActorSession`](../../godot/scripts/physical_actor_session.gd)
owns assembly, observation issuance, provenance-gated capabilities, source
grants, original snapshot cache, absolute deadlines, command ordering,
cancellation and consumed receipts. The
[`CyberPhysicalActorRig`](../../godot/scripts/physical_actor_rig.gd)
owns only the admitted joint motor and gyro request applied to real Rapier
body/joint objects. The native cell worker sees no joint nodes or mutable
physical bodies.

The host advertises `nca-host/1` and `physical_joint_target/v1` **only**
when the explicit pilot topology matches and the caller supplies both a
40-hex-character *trusted actual host source revision* and a
64-hex-character *trusted actual runtime build hash* to the owner at
installation. An unbound/default identity does not advertise the lane.
These fields are not inferred from the historical NCA descriptor. Synthetic
identity strings in tests prove the guard shape, not provenance of a
published binary. Establishing an authenticated build identity, exact runtime
pin and independent NCA admission remains mandatory before physical acceptance.

`ik_grant` is a trusted host operation, not a client-submitted authority
claim: it cancels and retires earlier controls, increments
`control_generation`, and issues a new random grant bound to actor/run/
epoch/incarnation, current producer, source ID, immutable policy SHA-256,
goal ID/deadline, NCA profile and joint ordering. A source takeover creates
another generation. `ik_observe` records and returns an immutable root pose
and joint measurement from an actually issued session observation, with
part/joint presence, measured-vs-active masks and the original tick. No
client-supplied root, grant or current-tick oracle is authoritative.

The strict `ik_submit` dictionary has exact, closed keys and requires:
protocol/version, operation, all of the above identities, a strictly
increasing sequence, original observation ID/hash/tick, original
goal deadline, exact profile/topology hashes, `right_sole`, ordered
`[hip_1, ankle_1]`, exact `joint_position` or `joint_delta` request and an
original-observation-relative lease. The host resolves a delta against
**that issued observation's** actual joint values, not a fresher state.
It rejects nonfinite, boolean-number, unknown or foreign fields and wrong
units/orders/limits instead of clamping or projecting targets.

The NCA `IKObservation.sha256` semantic-record hash and the present
Cybersand host's opaque `observation_sha256` cache binding are **different
identifiers**. The latter hashes the issued session root/joint tuple with
the original observation ID and generation; it must not be mislabelled as
NCA canonical JSON. NCA #55 must explicitly qualify the adapter's mapping
and packet wire encoding against the accepted host revision before either
repository claims an interoperable, source-bound physical protocol.

## How does a target move the actual joints?

The pilot bypasses scripted movement, legacy effort/buttons/mounts and player
joint-target dictionaries. Each admitted physical 60 Hz step uses the
original Runner's natural contact, damping and compliant revolute limits.
The two right pins interpret the requested **absolute rest-relative angle**
as a setpoint, not as a `PinJoint2D.motor_target_velocity` directly.
The host computes angle error minus the authored 0.055 radian play, subtracts
a quarter of relative angular speed, multiplies remaining angle error by
9, clips requested motor speed to ±7 radians/second, and slews the submitted
velocity by at most 20 radians/second squared. Effort is fixed at 1.0;
the joint's 100 `JOINT_PARAM_MAX_FORCE` limit is an authored physical solver
parameter, **not measured joint torque**.

The neutral Runner gyro keeps its original controller constants, slope
correction when grounded and reduced 0.65 gain in air. The IK lane never adds
hidden hover, contact magic, stepwise velocity reset or additional global
stabilization. Existing extreme-motion safety caps still operate on the
physical assembly and are reported rather than interpreted as IK work.
Non-commanded joint motors are disabled; their physical pin constraints
stay installed.

References must already lie within hip
`[-0.72,+0.72]` and ankle `[-0.27,+0.27]` radians. A delta request is
bounded to ±0.25 radians per selected joint **and** its resolved absolute
target must be within the inner joint bounds. There is no interpolation,
continuous joint-angle wrapping around hard limits or hidden target
projection. Active corrections operate on physically measured current
angles and bounded motor velocity; results may lag under contact, soft
constraints and actual solver iterations.

## Exactly when does the target stop?

The current trusted owner must still match run/actor/epoch/incarnation,
producer, source/policy/goal/grant, generation, original observation
ID/hash, topology and unfaulted pilot. Before each physics consumption,
the owner requires:

`current_tick < min(observed_tick + lease_ticks, observed_tick + 12, goal_deadline_tick)`.

Lease is one to eighteen original ticks; accepted helper dispatch uses at
most twelve. The source observation is never refreshed by a late result or
extended by admission time. Stale, mismatched or expired input refuses;
cancellation, takeover, suspension, restart, close and fault disarm motor
targets and invalidate issued grants. Physical momentum, contacts and
rig topology are not reconstructed on revocation. A read-only duplicate
lookup must not reapply or extend authority. An ambiguous transport close
requires owner-confirmed `ik_cancel`; a lost reply cannot be treated as
authorization for an implicit retry.

Every actual physical step must match the session's manual Rapier
prepare/bridge-step/complete protocol. Unexpected steps fault the IK owner.
Single-use, same-source continuous tracking across packets and exception/fault
boundaries need the exact-head hosted execution evidence listed below;
source-code reasoning alone is not such evidence.

## What constitutes an actual receipt?

The `ik_submit` admission records requested original fields, resolved joint
positions and the exclusive deadline. Each consumed physics interval adds a
separate immutable-friendly copied
`requested/admitted/limited/motor/motion/integrity` record with the original
source stamp, actor generation, expected and actual physics-step counts,
actual motor velocity, speed/slew/limit details, full-body pose and joint
readback, grounded/contact state, tracking residual and terminal reason.
Admissions, per-tick consumptions, cancellations and no-step refusals are
distinct. Ticks without a live target are passive physics, not learned
tracking receipts.

Per-joint torque, per-pin effective force, Rapier passive contact-force
decomposition, and independent GPU/CPU learner timing are **unavailable**.
The host explicitly returns null or an unavailable reason rather than
estimating them from angle error. A successful schema fixture or measured
joint motion proves neither learned IK accuracy nor NCA's physical 0.75-cell
tracking gate.

## Which gates are still required?

The source-only protocol and actual-host test scripts are
[`test_physical_joint_target.gd`](../../godot/tests/test_physical_joint_target.gd)
and [`test_physical_joint_session.gd`](../../godot/tests/test_physical_joint_session.gd).
Use the exact-head, pinned Godot 4.7 and Rapier2D 0.35.2 CI matrix; execute
all relevant existing ACT-004, ACT-005 and 4LY controls as well. Inspect
requested-versus-submitted motor velocities, lost/stale/cross-owner
packets, source changes, dual-actor isolation, physical geometry,
collision response, support/loss of support, and per-tick receipt
completeness on the actual host. The dated
[admission ledger](../audits/2026-10-23-act-ik-001-development-admission.md)
separates source implementation from executed verification.

**Unqualified at this source checkpoint:** accepted NCA #55 wire/client
revision, authenticated exact executable/build identity, actual-host GitHub
CI, independent source-bound review and acceptance against the NCA physical
criteria. Issue #210 and NCA #55 must remain open until those gates have
source-matched green evidence. No CUDA training, model selection or
experiment allocation is authorized by this pilot.
