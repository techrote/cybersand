extends SceneTree

# ACT-IK-001 actual Godot/Rapier owner, motor, lifecycle and receipt conformance.
# The dummy host identity here is explicitly fixture provenance, NOT a
# qualified published native/GDExtension build or NCA physical acceptance.
const Session = preload("res://scripts/physical_actor_session.gd")
const Joint = preload("res://scripts/physical_joint_target.gd")
const DT: float = 1.0 / 60.0
const PLACE := Vector2(400, 400)
var assertions: int = 0
var failures: int = 0
var owner: Node2D
var session: CyberPhysicalActorSession


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("ACT_IK_HOST: " + message)


func create(producer: StringName = &"policy", identity: bool = true, incarnation: int = 1) -> bool:
	session = Session.new()
	owner.add_child(session)
	var stamp: Dictionary = {"source_commit": "a".repeat(40),
		"runtime_sha256": "b".repeat(64)} if identity else {}
	return session.configure([{"model": &"runner", "producer": producer,
		"position": PLACE, "ik_pilot": true, "usable_index": -1}],
		owner.get_world_2d().space, incarnation, stamp)


func close_fixture() -> void:
	if is_instance_valid(session):
		session.close()
		expect(not session.active() and session.bodies().is_empty(),
			"close releases the actual Rapier owner")
		session.free()
		session = null
		await process_frame


func step() -> void:
	session.advance(DT)
	session.bridge.step()
	session.complete_step()


func packet(grant: Dictionary, observed: Dictionary, sequence: int,
		references: Array = [0.24, -0.12], lease: int = 12) -> Dictionary:
	return {"protocol": Joint.PROTOCOL, "operation": "ik_submit", "version": 1,
		"run_id": observed.run_id, "actor_id": observed.actor_id,
		"epoch": observed.epoch, "incarnation": observed.incarnation,
		"control_generation": observed.control_generation,
		"source_id": grant.source_id, "policy_sha256": grant.policy_sha256,
		"grant_id": grant.grant_id, "grant_generation": grant.grant_generation,
		"goal_id": grant.goal_id, "goal_deadline_tick": grant.goal_deadline_tick,
		"sequence": sequence, "observed_tick": observed.observed_tick,
		"observation_id": observed.observation_id,
		"observation_sha256": observed.observation_sha256,
		"profile_sha256": observed.profile_sha256, "topology_sha256": observed.topology_sha256,
		"effector_id": "right_sole", "joint_ids": Joint.ACTIVE_JOINT_IDS.duplicate(),
		"joint_values": references.duplicate(), "target_mode": "joint_position",
		"lease_ticks": lease, "producer": str(grant.producer)}


func grant(source: String = "numerical-reference", deadline: int = 40) -> Dictionary:
	return session.ik_grant(0, StringName(str(session._definitions[0].producer)),
		source, "c".repeat(64), "sole-goal", deadline)


func check_motor_receipt(record: Dictionary, original: Dictionary) -> void:
	expect(record.get("operation") == "ik_receipt"
		and record.requested.observation_id == original.observation_id
		and record.integrity.requested_observed_tick == original.observed_tick,
		"each consumed base-tick retains original root/observation identity")
	expect(bool(record.motion.available) and int(record.integrity.actual_physics_step) >= 1
		and record.integrity.terminal_boundary == "completed",
		"each receipt binds actual completed bridge step and sampled physics")
	expect(record.motor.commanded_joint_ids == ["hip_1", "ankle_1"]
		and record.motor.passive_joint_ids == ["hip_-1", "ankle_-1"],
		"exclusive chain and passive motor owner are explicit")
	expect(record.motor.motors.size() == 2,
		"two motor requests, not a synthetic third foot-orientation actuator")
	for row: Dictionary in record.motor.motors:
		expect(absf(float(row.submitted_motor_velocity_radians_per_second)) <= 7.000001
			and absf(float(row.submitted_motor_velocity_radians_per_second)
				- float(row.previous_request_radians_per_second)) <= 20.0 * DT + 0.000001,
			"actual submitted motor velocity respects speed and 20 rad/s2 request slew")
		expect(row.measured_motor_torque == null and row.passive_force_decomposition == null
			and float(row.effort) == 1.0 and float(row.joint_max_force_parameter) == 100.0,
			"fixed effort and unmeasured torque are represented truthfully")
	expect(record.motion.joint_angles_radians.size() == 2
		and record.motion.tracking_error_radians.size() == 2
		and record.motion.part_motion.size() == 5 and record.motion.joint_motion.size() == 4,
		"real resulting whole-body motion is separate from joint reference")
	expect(record.motion.per_joint_force_telemetry == null
		and record.motion.passive_force_decomposition == null,
		"contact and joint motion never masquerade as per-joint torque telemetry")


func test_no_provenance() -> void:
	expect(create(&"policy", false), "pilot can be constructed without claiming an accepted build")
	expect(session.bodies().size() == 5, "actual pilot has five Rapier bodies")
	expect(session.ik_capabilities(0).is_empty(), "no identity cannot advertise a build-bound lane")
	expect(grant().is_empty(), "unadvertised joint lane refuses any controller grant")
	await close_fixture()


func test_live_chain() -> void:
	expect(create(), "Runner IK physical pilot configures")
	if not session.active():
		await close_fixture()
		return
	expect(session.bodies().size() == 5
		and session.observation(0).equipment.get("preparation") == "none"
		and not bool(session.observation(0).equipment.get("available", true)),
		"actual assembled Runner excludes sixth equipment and all usable authority")
	var capability: Dictionary = session.ik_capabilities(0)
	expect(not capability.is_empty() and capability.capability == Joint.CAPABILITY
		and capability.mode == "exclusive_joint_targets"
		and capability.host_runtime_sha256 == "b".repeat(64),
		"capability requires trusted explicit host provenance")
	var before: Dictionary = session.observation(0)
	var legacy: Dictionary = Session.make_command(before, 0, {"primary": true, "move": [1, 0]})
	expect(not session.submit(legacy), "existing v2 semantic wire cannot control the IK assembly")
	var issued_grant: Dictionary = grant()
	expect(not issued_grant.is_empty() and issued_grant.source_id == "numerical-reference"
		and int(issued_grant.control_generation) > int(before.control_generation),
		"trusted owner issues new generation and exclusive source grant")
	var observed: Dictionary = session.ik_observe(0, issued_grant.grant_id)
	expect(not observed.is_empty() and observed.part_present == [true, true, true, true, true, false, false, false]
		and observed.joint_active == [false, false, true, true, false, false, false],
		"issued root, presence and commanded-joint masks match accepted profile")
	var input: Dictionary = packet(issued_grant, observed, 0)
	expect(bool(session.ik_submit(input).accepted), "strict first source-bound decision admitted")
	expect(session.accepted_commands == 1, "admission is counted once")
	var repeated: Dictionary = session.ik_submit(input)
	expect(bool(repeated.accepted) and bool(repeated.get("duplicate_lookup", false))
		and session.accepted_commands == 1, "duplicate returns read-only original admission; does not reapply")
	for t: int in range(3):
		step()
	var records: Array = session.ik_receipts(0, issued_grant.grant_id, 0)
	expect(records.size() == 4, "initial admission plus exactly one trace per three consumed ticks")
	for i: int in range(1, records.size()):
		check_motor_receipt(records[i], observed)
		expect(int(records[i].integrity.consumed_base_tick) == i - 1
			and int(records[i].integrity.completed_base_tick) == i,
			"receipt ticks follow 60Hz physics one step at a time")
	var view: Dictionary = session.observation(0)
	var angles: Array = Joint.observed_chain(view)
	expect(angles.size() == 2 and is_finite(float(angles[0])) and is_finite(float(angles[1])),
		"real rotary readback remains finite while moving under requested motor references")
	var old_grant_id: String = str(issued_grant.grant_id)
	var cancelled: Dictionary = session.ik_cancel(0, old_grant_id, "numerical-reference")
	expect(bool(cancelled.confirmed) and int(cancelled.new_generation) > int(cancelled.revoked_generation),
		"confirmed owner cancellation advances generation")
	expect(session.ik_capabilities(0).control_generation == cancelled.new_generation,
		"new owner generation is independently visible")
	var before_motion: Vector2 = PhysicsServer2D.body_get_state(
		session.bodies()[0].get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
	expect(session._rigs[0]._joints[2].node.motor_enabled == false
		and session._rigs[0]._joints[3].node.motor_enabled == false,
		"cancellation disables both motor owners rather than leaving stale targets")
	expect(PhysicsServer2D.body_get_state(session.bodies()[0].get_rid(),
		PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY).distance_to(before_motion) < 0.0001,
		"owner revocation does not zero existing Rapier momentum")
	expect(session.ik_observe(0, old_grant_id).is_empty(),
		"cancelled grant cannot issue a fresh observation")
	expect(not bool(session.ik_submit(input).accepted), "old packet cannot revive through a fresh client")
	var final_receipts: Array = session.ik_receipts(0, old_grant_id, 0)
	expect(final_receipts.size() == 5 and final_receipts[-1].operation == "ik_terminal"
		and final_receipts[-1].integrity.terminal_boundary == "owner_cancelled"
		and bool(final_receipts[-1].integrity.cancel_confirmed),
		"original consumption remains traceable with an explicit confirmed no-step terminal")
	step()
	expect(session._rigs[0]._joints[2].node.motor_enabled == false
		and session._rigs[0]._joints[3].node.motor_enabled == false,
		"passive post-cancel host step cannot revive the motor request")
	await close_fixture()


func test_authority_fences() -> void:
	expect(create(), "separate generation-fence fixture starts")
	var issued_grant: Dictionary = grant("learned-model", 18)
	var original: Dictionary = session.ik_observe(0, issued_grant.grant_id)
	var good: Dictionary = packet(issued_grant, original, 0)
	for mutation: Dictionary in [
		{"source_id": "another-source"}, {"grant_id": "foreign-grant"},
		{"policy_sha256": "f".repeat(64)}, {"control_generation": 99},
		{"epoch": 9}, {"incarnation": 44},
		{"producer": "human"}, {"run_id": "foreign-run"}]:
		var bad: Dictionary = good.duplicate(true)
		bad.merge(mutation, true)
		expect(not bool(session.ik_submit(bad).get("accepted", false)),
			"foreign identity cannot consume or revoke the real owner: " + str(mutation.keys()))
	expect(session.accepted_commands == 0 and not session._joint_grants[0].is_empty(),
		"untrusted foreign packets do not create action or revoke a legitimate source")
	expect(bool(session.ik_submit(good).accepted),
		"valid original packet remains admissible after foreign attempts")
	var future: Dictionary = good.duplicate(true)
	future.sequence = 1
	future.observed_tick = 1
	expect(not bool(session.ik_submit(future).accepted),
		"fresh generation cannot be forged by stamping a new observed tick")
	expect(session._joint_grants[0].is_empty()
		and session._joint_targets[0].is_empty(),
		"malformed current-owner packet fail-closes its outstanding motor lease")
	expect(not bool(session.ik_submit(good).get("accepted", false)),
		"old owner cannot reclaim a malformed-target cancellation")
	var old_observation: Dictionary = original.duplicate(true)
	var replacements: Dictionary = grant("numerical-reference", 35)
	expect(not replacements.is_empty() and replacements.grant_id != issued_grant.grant_id,
		"goal/source takeover invalidates old grant in same physical incarnation")
	expect(session.ik_observe(0, issued_grant.grant_id).is_empty(),
		"old source grant cannot obtain any new observation")
	expect(not bool(session.ik_submit(packet(issued_grant, old_observation, 1)).accepted),
		"new source cannot resurrect old pending target")
	expect(session.ik_observe(0, replacements.grant_id).control_generation
		== replacements.control_generation, "new source issues a fresh original observation")
	var revoked: Dictionary = session.ik_cancel(0, replacements.grant_id, "numerical-reference")
	expect(bool(revoked.confirmed), "ambiguous transport may be closed by an authoritative cancellation")
	expect(session.ik_capabilities(0).control_generation == revoked.new_generation,
		"confirmed ambiguous-close fences every old invocation")
	await close_fixture()


func test_expiry() -> void:
	expect(create(), "exclusive-expiry fixture starts")
	var issued_grant: Dictionary = grant("reference", 20)
	var observed: Dictionary = session.ik_observe(0, issued_grant.grant_id)
	var action: Dictionary = packet(issued_grant, observed, 0, [0.3, -0.2], 18)
	expect(bool(session.ik_submit(action).accepted), "lease 18 admitted but not a freshness extension")
	for t: int in range(12):
		step()
	expect(session.ik_receipts(0, issued_grant.grant_id, 0).size() == 13,
		"original tick zero drives exactly intervals 0-1 through 11-12")
	step()
	expect(session._joint_targets[0].is_empty() and session._joint_grants[0].is_empty()
		and session._rigs[0]._joints[2].node.motor_enabled == false,
		"tick twelve may never start interval 12-13; old generation revoked")
	var terminal: Array = session.ik_receipts(0, issued_grant.grant_id, 0)
	expect(terminal.size() == 14 and terminal[-1].operation == "ik_terminal"
		and bool(terminal[-1].integrity.cancel_confirmed),
		"earliest-exclusive expiry emits an explicit terminal no-physics-consumption boundary")
	expect(not bool(session.ik_submit(action).get("accepted", false)),
		"old observation never becomes eligible through lookup or delayed arrival")
	await close_fixture()


func run() -> void:
	owner = Node2D.new()
	root.add_child(owner)
	expect(ClassDB.class_exists("RapierPhysicsServer2D"),
		"real GDExtension/Rapier must be present; no mocked pass")
	if failures > 0:
		quit(1)
		return
	await test_no_provenance()
	await test_live_chain()
	await test_authority_fences()
	await test_expiry()
	print("ACT_IK_HOST: %d assertions, %d failures" % [assertions, failures])
	owner.free()
	quit(1 if failures > 0 else 0)
