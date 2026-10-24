extends SceneTree

# ACT-IK-001 pure protocol and assembly admission. No physical success is
# inferred from a source-only fixture; actual host tests run separately.
const Session = preload("res://scripts/physical_actor_session.gd")
const Contract = preload("res://scripts/physical_joint_target.gd")
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const Equipment = preload("res://scripts/physical_usable_equipment.gd")
const Loadouts = preload("res://scripts/physical_usable_loadouts.gd")
var assertions: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("ACT_IK_PROTOCOL: " + message)


func packet() -> Dictionary:
	return {"protocol": Contract.PROTOCOL, "operation": "ik_submit", "version": 1,
		"run_id": "run-1", "actor_id": 0, "epoch": 1, "incarnation": 1,
		"control_generation": 2, "source_id": "numerical-reference",
		"policy_sha256": "a".repeat(64),
		"grant_id": "grant-1", "grant_generation": 2,
		"goal_id": "goal-1", "goal_deadline_tick": 18,
		"sequence": 0, "observed_tick": 0, "observation_id": "observation-1",
		"observation_sha256": "b".repeat(64),
		"profile_sha256": Contract.PROFILE_SHA256,
		"topology_sha256": Contract.TOPOLOGY_SHA256,
		"effector_id": "right_sole", "joint_ids": Contract.ACTIVE_JOINT_IDS.duplicate(),
		"joint_values": [0.20, -0.15], "target_mode": "joint_position",
		"lease_ticks": 12, "producer": "policy"}


func run() -> void:
	var normal: Dictionary = Equipment.definition(Catalog.entry(&"runner"), Loadouts.entry(&"runner"))
	var definition: Dictionary = {"model": &"runner", "producer": &"policy",
		"position": Vector2(400, 400), "ik_pilot": true, "usable_index": -1}
	var prepared: Dictionary = Session._prepared_definition(definition)
	expect(normal.parts.size() == 6 and normal.joints.size() == 5
		and str(normal.parts[-1].id) == "equipment"
		and str(normal.joints[-1].id) == "equipment_grip",
		"ordinary Runner retains its permanent equipment body and joint")
	expect(Contract.compatible_assembly(prepared) and prepared.parts.size() == 5
		and prepared.joints.size() == 4 and prepared.mounts.is_empty(),
		"pilot has original five parts, four joints and no equipment body")
	expect(Session.valid_definitions([definition]), "explicit equipment-free pilot admitted")
	var bad_definition: Dictionary = definition.duplicate(true)
	bad_definition.usable_index = 0
	expect(not Session.valid_definitions([bad_definition]),
		"an equipped pilot cannot masquerade as five-part geometry")
	bad_definition = definition.duplicate(true)
	bad_definition.ik_pilot = "true"
	expect(not Session.valid_definitions([bad_definition]),
		"pilot activation must be a typed boolean")
	bad_definition = definition.duplicate(true)
	bad_definition.model = &"4ly_trainer"
	expect(not Session.valid_definitions([bad_definition]),
		"flight family cannot be relabelled as IK pilot")
	bad_definition = definition.duplicate(true)
	bad_definition.erase("ik_pilot")
	expect(Session.valid_definitions([bad_definition]), "legacy runner definition unaffected")
	var tampered: Dictionary = prepared.duplicate(true)
	tampered.parts[3].offset.x += 0.5
	expect(not Contract.compatible_assembly(tampered), "nonmatching part geometry fails closed")
	tampered = prepared.duplicate(true)
	tampered.joints[2].limits.x -= 0.01
	expect(not Contract.compatible_assembly(tampered), "changed joint limit fails closed")
	var untrusted: Dictionary = Contract.capability({}, prepared)
	expect(untrusted.is_empty(), "missing build provenance cannot advertise IK capability")
	var identity: Dictionary = {"source_commit": "a".repeat(40), "runtime_sha256": "b".repeat(64)}
	var cap: Dictionary = Contract.capability(identity, prepared)
	expect(not cap.is_empty() and cap.mode == Contract.MODE and cap.part_capacity == 8
		and cap.joint_capacity == 7 and cap.angle_unit == "radians"
		and cap.max_observation_age_ticks == 12,
		"versioned capability exposes exact units, capacities, and mode")
	expect(cap.profile_sha256 == Contract.PROFILE_SHA256
		and cap.descriptor_file_sha256 == Contract.DESCRIPTOR_SHA256
		and cap.descriptor_source_commit == Contract.HISTORICAL_SOURCE,
		"accepted historical profile identities are never rebased")
	cap.part_ids[0] = "injected"
	expect(Contract.capability(identity, prepared).part_ids[0] == "chassis",
		"capability data is independently copied")
	var valid: Dictionary = packet()
	expect(Contract.validation_error(valid).is_empty(),
		"fully bound position packet passes pure shape validation")
	expect(Contract.resolve_targets(valid, [0.0, 0.0]) == [0.2, -0.15],
		"absolute references are neither transformed nor reinterpreted")
	for change: Dictionary in [
		{"version": 2}, {"operation": "wire_action"}, {"effector_id": "left_sole"},
		{"joint_ids": ["ankle_1", "hip_1"]}, {"joint_ids": ["hip_1"]},
		{"joint_values": [INF, 0.0]}, {"joint_values": [NAN, 0.0]},
		{"joint_values": [true, 0.0]}, {"joint_values": [0.73, 0.0]},
		{"joint_values": [0.1, -0.28]}, {"profile_sha256": "c".repeat(64)},
		{"topology_sha256": "d".repeat(64)}, {"observed_tick": 20},
		{"lease_ticks": 0}, {"lease_ticks": 19}, {"sequence": 0.5},
		{"policy_sha256": "not-a-digest"}, {"target_mode": "joint_torque"}
	]:
		var mutated: Dictionary = valid.duplicate(true)
		mutated.merge(change, true)
		expect(not Contract.validation_error(mutated).is_empty(),
			"strict packet refuses malformed field: " + str(change))
	var extra: Dictionary = valid.duplicate(true)
	extra["privileged_reward"] = true
	expect(not Contract.validation_error(extra).is_empty(),
		"unknown packet field never passes through to physical owner")
	var short_delta: Dictionary = valid.duplicate(true)
	short_delta.target_mode = "joint_delta"
	short_delta.joint_values = [0.25, -0.25]
	expect(Contract.validation_error(short_delta).is_empty()
		and Contract.resolve_targets(short_delta, [0.10, -0.01]) == [0.35, -0.26],
		"bounded deltas resolve only against original measurements")
	expect(Contract.resolve_targets(short_delta, [0.70, 0.0]).is_empty(),
		"a bounded delta exceeding absolute inner bounds is refused, not clamped")
	short_delta.joint_values = [0.251, 0.0]
	expect(not Contract.validation_error(short_delta).is_empty(),
		"delta cannot exceed its original-observation 0.25-radian limit")
	expect(Contract.expiration(0, 18, 30) == 12, "source freshness beats long lease")
	expect(Contract.expiration(0, 6, 30) == 6, "short lease beats freshness")
	expect(Contract.expiration(0, 18, 8) == 8, "earliest goal deadline wins")
	expect(Contract.can_consume(0, 12, 20, 11)
		and not Contract.can_consume(0, 12, 20, 12)
		and not Contract.can_consume(0, 12, 20, -1),
		"tick eleven drives, tick twelve and negative time cannot drive")
	print("ACT_IK_PROTOCOL: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures > 0 else 0)
